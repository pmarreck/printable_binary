# Filesystem adapter for verified build products. Callers serialize a build's
# selection/publication transaction; products remain available for rollback.

pb_safe_directory() {
	local root="$1" relative="$2" component current="$1" parts=()
	if [[ ! -d "$root" || -L "$root" || "$relative" == /* ]]; then
		printf 'Expected a real project directory and a relative output path\n' >&2
		return 1
	fi
	IFS='/' read -r -a parts <<< "$relative"
	for component in "${parts[@]}"; do
		case "$component" in ''|.|..) printf 'Unsafe output directory component\n' >&2; return 1 ;; esac
		current+="/$component"
		if [[ -L "$current" || ( -e "$current" && ! -d "$current" ) ]]; then
			printf 'Refusing redirected or non-directory output path: %s\n' "$current" >&2
			return 1
		fi
		mkdir -p -- "$current" || return 1
	done
}

pb_atomic_link() {
	local target="$1" destination="$2" temporary
	if [[ -L "$destination" && "$(readlink "$destination")" == "$target" ]]; then return 0; fi
	temporary="$(mktemp -d "$(dirname "$destination")/.publish.XXXXXXXX")" || return 1
	# GNU mv -T does not follow an existing directory symlink. The build shell
	# supplies coreutils on every Nix build host, including macOS.
	if ln -s -- "$target" "$temporary/link" && mv -fT -- "$temporary/link" "$destination"; then
		rmdir -- "$temporary"
		return 0
	fi
	rm -f -- "$temporary/link"
	rmdir -- "$temporary"
	return 1
}

pb_select_product() {
	local root="$1" impl="$2" pf="$3" variant="$4" profile="$5" product="$6" path target
	path="$(pb_product_path "$impl" "$pf" "$variant" "$profile")" || return 1
	[[ -d "$root/$product" ]] || { printf 'Missing complete product: %s\n' "$product" >&2; return 1; }
	pb_safe_directory "$root" "$(dirname "$path")" || return 1
	if [[ -e "$root/$path" || -L "$root/$path" ]]; then
		if [[ ! -L "$root/$path" ]]; then
			printf 'Refusing to replace an unmanaged product directory: %s\n' "$path" >&2
			return 1
		fi
		target="$(readlink "$root/$path")" || return 1
		case "$target" in *'.nix-out/'*|*'.generation-'*) ;; *) printf 'Unmanaged product selection: %s\n' "$path" >&2; return 1 ;; esac
	fi
	target="$(realpath --no-symlinks --relative-to="$(dirname "$root/$path")" "$root/$product")" || return 1
	pb_atomic_link "$target" "$root/$path"
}

pb_atomic_text() {
	local destination="$1" content="$2" temporary
	if [[ -f "$destination" ]] && cmp -s "$destination" <(printf '%s\n' "$content"); then return 0; fi
	temporary="$(mktemp "$(dirname "$destination")/.record.XXXXXXXX")" || return 1
	if printf '%s\n' "$content" > "$temporary" && mv -fT -- "$temporary" "$destination"; then
		return 0
	fi
	rm -f -- "$temporary"
	return 1
}

pb_atomic_copy() {
	local source="$1" destination="$2" temporary
	temporary="$(mktemp "$(dirname "$destination")/.command.XXXXXXXX")" || return 1
	if cp -- "$source" "$temporary" && chmod 755 "$temporary" && mv -fT -- "$temporary" "$destination"; then return 0; fi
	rm -f -- "$temporary"
	return 1
}

pb_publish() {
	local root="$1" host="$2" pf="$3" impl="$4" product="$5" entry="$6"
	local io="${7:-pb}" directory command target previous marker old_hash='' new_hash accepted
	[[ "$pf" == "$host" ]] || return 0
	pb_valid_platform "$pf" || return 1
	if [[ ! "$entry" =~ ^[a-zA-Z0-9._-]+$ || "$product" == /* || "$product" == *'..'* ]]; then
		printf 'Unsafe product or command path\n' >&2
		return 1
	fi
	if [[ ! -x "$root/$product/bin/$entry" || ! -f "$root/$product/bin/$entry" ]]; then
		printf 'Missing required canonical command: %s/bin/%s\n' "$product" "$entry" >&2
		return 1
	fi
	pb_safe_directory "$root" "bin/$pf" || return 1
	directory="$root/bin/$pf"
	command="$directory/printable-binary"
	case "$pf" in
		mswin-*)
			case "$impl" in zig|ape) ;; *) printf 'No standalone Windows publication adapter for %s\n' "$impl" >&2; return 1 ;; esac
			command+='.exe'
			marker="$directory/.printable-binary.sha256"
			if [[ -L "$command" || -L "$marker" || ( -e "$command" && ! -f "$command" ) ]]; then
				printf 'Refusing an unmanaged Windows command or ownership record\n' >&2
				return 1
			fi
			if [[ -f "$command" ]]; then
				old_hash="$(sha256sum < "$command")" || return 1
				old_hash="${old_hash%% *}"
				if [[ ! -f "$marker" ]] || ! grep -Fxq -- "$old_hash" "$marker"; then
					printf 'Refusing to overwrite an unmanaged Windows command\n' >&2
					return 1
				fi
			fi
			new_hash="$(sha256sum < "$root/$product/bin/$entry")" || return 1
			new_hash="${new_hash%% *}"
			if [[ "$new_hash" == "$old_hash" ]]; then
				if cmp -s "$marker" <(printf '%s\n' "$new_hash"); then return 0; fi
				"${io}_atomic_text" "$marker" "$new_hash"
				return "$?"
			fi
			accepted="${old_hash:+$old_hash$'\n'}$new_hash"
			# Accept both sides before the atomic copy. A retry after either
			# boundary recognizes the current command without losing rollback.
			"${io}_atomic_text" "$marker" "$accepted" || return 1
			"${io}_atomic_copy" "$root/$product/bin/$entry" "$command" || return 1
			"${io}_atomic_text" "$marker" "$new_hash"
			;;
		*)
			if [[ -e "$command" || -L "$command" ]]; then
				if [[ ! -L "$command" ]]; then
					printf 'Refusing to overwrite an unmanaged public command: %s\n' "$command" >&2
					return 1
				fi
				previous="$(readlink "$command")" || return 1
				case "$previous" in '../../.nix-out/'*|'../../'*'-out/'*) ;; *) printf 'Unmanaged public command link: %s\n' "$command" >&2; return 1 ;; esac
			fi
			target="../../$product/bin/$entry"
			[[ "${previous:-}" != "$target" ]] || return 0
			"${io}_atomic_link" "$target" "$command"
			;;
	esac
}

pb_acquire_build_lock() {
	local root="$1"
	pb_safe_directory "$root" .build-work || return 1
	if ! mkdir -- "$root/.build-work/publication.lock" 2>/dev/null; then
		printf 'Another build/publication owns .build-work/publication.lock; retry after it finishes. A stale lock requires inspection.\n' >&2
		return 1
	fi
	printf '%s/.build-work/publication.lock\n' "$root"
}
