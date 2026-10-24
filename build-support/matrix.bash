# Planning over declared implementations. Compiler/Nix spellings stay at the
# adapter boundary; project output paths use canonical PF and optional VARIANT.

pb_valid_platform() {
	case "$1" in
		linux-amd64|linux-arm64|macos-arm64|mswin-amd64|mswin-arm64) return 0 ;;
		*) printf 'Unsupported platform: %s\n' "$1" >&2; return 1 ;;
	esac
}

pb_matrix_rows() {
	local matrix="$1" impl pf variant target builder package command format extra pairs='' rows=()
	if [[ ! -f "$matrix" ]]; then
		printf 'Missing implementation matrix: %s\n' "$matrix" >&2
		return 1
	fi
	while IFS='|' read -r impl pf variant target builder package command format extra; do
		case "$impl" in ''|'#'*) continue ;; esac
		if [[ ! "$impl" =~ ^[a-z][a-z0-9-]*$ ]] || ! pb_valid_platform "$pf" ||
			[[ -z "$target" || -z "$builder" || -z "$package" || -z "$command" || -n "$extra" ]]; then
			printf 'Invalid implementation matrix row: %s/%s\n' "$impl" "$pf" >&2
			return 1
		fi
		case "$variant" in -|gnu|musl) ;; *) printf 'Invalid matrix variant: %s\n' "$variant" >&2; return 1 ;; esac
		case "$format" in native|script|ape|wasm) ;; *) printf 'Invalid matrix format: %s\n' "$format" >&2; return 1 ;; esac
		case "$builder" in host|linux|x86_64-linux|aarch64-linux|aarch64-darwin) ;; *) printf 'Invalid Nix builder: %s\n' "$builder" >&2; return 1 ;; esac
		if [[ ! "$target" =~ ^[a-zA-Z0-9._-]+$ || ! "$package" =~ ^[a-zA-Z0-9._-]+$ || ! "$command" =~ ^[a-zA-Z0-9._-]+$ ]]; then
			printf 'Invalid matrix target/package/command token\n' >&2
			return 1
		fi
		case ";$pairs" in *";$impl,$pf;"*) printf 'Duplicate matrix combination: %s/%s\n' "$impl" "$pf" >&2; return 1 ;; esac
		pairs+="$impl,$pf;"
		rows+=("$impl|$pf|$variant|$target|$builder|$package|$command|$format")
	done < "$matrix"
	if [[ "${#rows[@]}" == 0 ]]; then
		printf 'Implementation matrix is empty\n' >&2
		return 1
	fi
	printf '%s\n' "${rows[@]}"
}

pb_matrix_registry() {
	local rows impl rest seen=''
	rows="$(pb_matrix_rows "$1")" || return 1
	while IFS='|' read -r impl rest; do
		case " $seen " in *" $impl "*) continue ;; esac
		seen+=" $impl"
		printf '%s\n' "$impl"
	done <<< "$rows"
}

pb_build_plan() {
	local matrix="$1" selected="$2" host="$3" implementations="$4" platforms="$5"
	local rows impl pf rest registered=0 selected_on_host=0 result=()
	rows="$(pb_matrix_rows "$matrix")" || return 1
	pb_valid_platform "$host" || return 1
	case "$implementations:$platforms" in canonical:host|canonical:all|all:host|all:all) ;; *) printf 'Invalid build scope\n' >&2; return 1 ;; esac
	while IFS='|' read -r impl pf rest; do
		if [[ "$impl" == "$selected" ]]; then
			registered=1
			[[ "$pf" == "$host" ]] && selected_on_host=1
		fi
		[[ "$implementations" == all || "$impl" == "$selected" ]] || continue
		[[ "$platforms" == all || "$pf" == "$host" ]] || continue
		result+=("$impl|$pf|$rest")
	done <<< "$rows"
	if [[ "$registered" != 1 || ( "$platforms" == host && "$selected_on_host" != 1 ) || "${#result[@]}" == 0 ]]; then
		printf 'No declared build for implementation %s on %s with the requested scope\n' "$selected" "$host" >&2
		return 1
	fi
	printf '%s\n' "${result[@]}"
}

pb_product_path() {
	local impl="$1" platform="$2" variant="$3" profile="$4"
	if [[ ! "$impl" =~ ^[a-z][a-z0-9-]*$ ]]; then
		printf 'Invalid implementation identifier\n' >&2
		return 1
	fi
	pb_valid_platform "$platform" || return 1
	case "$profile" in ReleaseFast|ReleaseSafe|Debug) ;; *) printf 'Invalid build profile\n' >&2; return 1 ;; esac
	case "$variant" in
		-) printf '%s-out/%s/%s\n' "$impl" "$platform" "$profile" ;;
		gnu|musl) printf '%s-out/%s/%s/%s\n' "$impl" "$platform" "$variant" "$profile" ;;
		*) printf 'Invalid ABI variant\n' >&2; return 1 ;;
	esac
}

pb_nix_system() {
	case "$1" in
		linux-amd64) printf 'x86_64-linux\n' ;;
		linux-arm64) printf 'aarch64-linux\n' ;;
		macos-arm64) printf 'aarch64-darwin\n' ;;
		*) printf 'No native Nix builder for %s; build through Nix on WSL or a supported remote/cross builder\n' "$1" >&2; return 1 ;;
	esac
}
