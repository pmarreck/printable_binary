# Thin orchestration over declared Nix products and verified publication.

pb_build_usage() {
	printf '%s\n' \
		'Usage: ./build [--impl=IMPL] [--platform=PF] [--debug|--test]' \
		'       ./build canonize IMPL' \
		'       ./build [--all-impls|--all-implementations] [--all-plats|--all-platforms]' \
		'       ./build --all' \
		'Default: canonical implementation, current platform, ReleaseFast. Nix is required.' \
		'Canonization only records intent. A successful build publishes the canonical host command.' \
		'--debug selects Debug; --test selects ReleaseSafe.'
}

pb_prepare_nix_source() {
	local metadata
	metadata="$(nix flake metadata --json "$1")" || return 1
	jq -er '.path' <<< "$metadata"
}

pb_nix_build() {
	local source="$1" builder="$2" package="$3" link="$4"
	nix build "$source#packages.$builder.$package" --out-link "$link" --print-build-logs
}

pb_verify_native_file() {
	local binary="$1" pf="$2" variant="$3" header machine offset pe description
	header="$(od -An -v -tx1 -N20 "$binary" | tr -d ' \n')" || return 1
	case "$pf" in
		linux-*)
			[[ "${header:0:12}" == 7f454c460201 ]] || return 1
			machine="${header:36:4}"
			case "$pf:$machine" in linux-amd64:3e00|linux-arm64:b700) ;; *) return 1 ;; esac
			if [[ "$variant" == musl ]]; then
				description="$(file -Lb "$binary")" || return 1
				case "$description" in *'statically linked'*|*'static-pie linked'*) ;; *) return 1 ;; esac
			fi
			;;
		macos-arm64) [[ "${header:0:16}" == cffaedfe0c000001 ]] || return 1 ;;
		mswin-*)
			[[ "${header:0:4}" == 4d5a ]] || return 1
			offset="$(od -An -tu4 -j60 -N4 "$binary")" || return 1
			offset="${offset//[[:space:]]/}"
			[[ "$offset" =~ ^[0-9]+$ && "$offset" -le 1048576 ]] || return 1
			pe="$(od -An -v -tx1 -j "$offset" -N6 "$binary" | tr -d ' \n')" || return 1
			case "$pf:$pe" in mswin-amd64:504500006486|mswin-arm64:5045000064aa) ;; *) return 1 ;; esac
			;;
		*) return 1 ;;
	esac
}

pb_verify_product() {
	local product="$1" impl="$2" pf="$3" variant="$4" target="$5" profile="$6" entry="$7" format="$8" backend="$9"
	local manifest="$product/share/printable-binary/build.json" interpreter rest magic
	if [[ ! -f "$product/bin/$entry" || ! -x "$product/bin/$entry" ]] ||
		! jq -e --arg impl "$impl" --arg pf "$pf" --arg variant "$variant" --arg target "$target" \
			--arg profile "$profile" --arg entry "$entry" --arg format "$format" --arg backend "$backend" \
			'.implementation == $impl and .PF == $pf and (.VARIANT // "-") == $variant and .target == $target and .profile == $profile and .executable == $entry and .format == $format and .backend == $backend' \
			"$manifest" >/dev/null; then
		printf 'Missing command or mismatched product metadata: %s/%s\n' "$impl" "$pf" >&2
		return 1
	fi
	case "$format" in
		native)
			if ! pb_verify_native_file "$product/bin/$entry" "$pf" "$variant"; then
				printf 'Executable header or loader requirements do not match %s/%s\n' "$pf" "$variant" >&2
				return 1
			fi
			;;
		script|wasm)
			IFS=' ' read -r interpreter rest < "$product/bin/$entry"
			interpreter="${interpreter#\#!}"
			if [[ -z "$interpreter" ]]; then read -r interpreter rest <<< "$rest"; fi
			case "$interpreter" in /nix/store/*) ;; *) printf 'Unpinned runtime interpreter\n' >&2; return 1 ;; esac
			pb_verify_native_file "$interpreter" "$pf" - || return 1
			if [[ "$format" == wasm ]]; then
				magic="$(od -An -v -tx1 -N8 "$product/bin/printable-binary.wasm" | tr -d ' \n')" || return 1
				[[ "$magic" == 0061736d01000000 ]] || return 1
			fi
			;;
		ape)
			[[ "$(head -c 2 "$product/bin/$entry")" == MZ ]] || return 1
			# Consume the producer's full output when the caller enables pipefail.
			strings -a "$product/bin/$entry" | grep -F '.aarch64.elf' >/dev/null || return 1
			;;
	esac
}

pb_build_main() (
	set -u
	set -o pipefail
	local root="$1" host="$2" matrix="$1/build-support/implementations"
	shift 2
	local registry_text canonical selected explicit='' target_pf='' profile=ReleaseFast
	local scopes=() registry=() impl_scope platform_scope flag plan source='' lock row_impl pf variant target builder package entry format product relative
	local products=() planned_rows=() current_selection index
	registry_text="$(pb_matrix_registry "$matrix")" || return 1
	while IFS= read -r row_impl; do registry+=("$row_impl"); done <<< "$registry_text"
	if [[ "${1:-}" == canonize ]]; then
		if [[ "$#" != 2 ]]; then printf 'Usage: ./build canonize IMPL (no build flags)\n' >&2; return 1; fi
		pb_canonize "$root/CANONICAL_IMPL" "$2" "${registry[@]}"
		return "$?"
	fi
	for flag in "$@"; do
		case "$flag" in
			-h|--help|help) pb_build_usage; return 0 ;;
			--all-impls|--all-implementations|--all-plats|--all-platforms|--all) scopes+=("$flag") ;;
			all) scopes+=(--all-impls) ;;
			--impl=*) explicit="${flag#--impl=}"; [[ -n "$explicit" ]] || { printf 'Missing implementation\n' >&2; return 1; } ;;
			--platform=*) target_pf="${flag#--platform=}"; [[ -n "$target_pf" ]] || { printf 'Missing platform\n' >&2; return 1; } ;;
			--debug) profile=Debug ;;
			--test) profile=ReleaseSafe ;;
			--profile=*) profile="${flag#--profile=}" ;;
			native) explicit=c ;;
			zig|c|ffi|rust|roc|luajit|node|ape|wasm) explicit="$flag" ;;
			*) printf 'Unknown build argument: %s\n' "$flag" >&2; return 1 ;;
		esac
	done
	case "$profile" in ReleaseFast|ReleaseSafe|Debug) ;; *) printf 'Unknown build profile\n' >&2; return 1 ;; esac
	canonical="$(pb_read_canonical "$root/CANONICAL_IMPL" "${registry[@]}")" || return 1
	selected="${explicit:-$canonical}"
	read -r impl_scope platform_scope <<< "$(pb_build_scope "${scopes[@]}")"
	if [[ ( -n "$explicit" && "$impl_scope" == all ) || ( -n "$target_pf" && "$platform_scope" == all ) ]]; then
		printf 'Choose an explicit implementation/platform or its all-scope flag, not both\n' >&2
		return 1
	fi
	plan="$(pb_build_plan "$matrix" "$selected" "${target_pf:-$host}" "$impl_scope" "$platform_scope")" || return 1
	lock="$(pb_acquire_build_lock "$root")" || return 1
	trap 'rmdir -- "$lock"' EXIT
	source="$(pb_prepare_nix_source "$root")" || return 1
	while IFS='|' read -r row_impl pf variant target builder package entry format; do
		printf 'Building %s for %s (%s, Nix)\n' "$row_impl" "$pf" "$profile" >&2
		case "$builder" in
			host) builder="$(pb_nix_system "$host")" || return 1 ;;
			linux) case "$host" in linux-*) builder="$(pb_nix_system "$host")" ;; *) builder=x86_64-linux ;; esac ;;
		esac
		pb_safe_directory "$root" ".nix-out/$pf/$profile" || return 1
		product="$(mktemp -d "$root/.nix-out/$pf/$profile/$row_impl.XXXXXXXX")/product" || return 1
		pb_nix_build "$source" "$builder" "$package-$profile" "$product" || return 1
		pb_verify_product "$product" "$row_impl" "$pf" "$variant" "$target" "$profile" "$entry" "$format" nix || return 1
		products+=("${product#"$root/"}")
		planned_rows+=("$row_impl|$pf|$variant|$target|$builder|$package|$entry|$format")
	done <<< "$plan"
	current_selection="$(pb_read_canonical "$root/CANONICAL_IMPL" "${registry[@]}")" || return 1
	if [[ "$current_selection" != "$canonical" ]]; then
		printf 'CANONICAL_IMPL changed during this build; products are retained, but commands were not switched. Rerun ./build.\n' >&2
		return 1
	fi
	for ((index=0; index<${#products[@]}; index++)); do
		IFS='|' read -r row_impl pf variant target builder package entry format <<< "${planned_rows[$index]}"
		relative="${products[$index]}"
		pb_select_product "$root" "$row_impl" "$pf" "$variant" "$profile" "$relative" || return 1
	done
	for ((index=0; index<${#products[@]}; index++)); do
		IFS='|' read -r row_impl pf variant target builder package entry format <<< "${planned_rows[$index]}"
		if [[ "$row_impl" == "$canonical" && "$pf" == "$host" ]]; then
			pb_publish "$root" "$host" "$pf" "$row_impl" "${products[$index]}" "$entry" || return 1
			printf 'Published %s in bin/%s/\n' "$canonical" "$host" >&2
		fi
	done
)
