# Build configuration core. The caller supplies its declared implementation
# registry; this module never evaluates a selector or invokes a build adapter.

pb_registered_impl() {
	local candidate="$1" registered
	shift
	for registered in "$@"; do
		[[ "$candidate" == "$registered" ]] && return 0
	done
	return 1
}

pb_read_canonical() {
	local selector="$1" selected=''
	shift
	if [[ ! -f "$selector" || -L "$selector" ]]; then
		printf 'Canonical selection must be a regular file: %s. Run ./build canonize IMPL.\n' "$selector" >&2
		return 1
	fi
	# read accepts a missing final LF. Exact-byte comparison below rejects extra
	# lines, extra LFs, CRLF, and embedded NULs that Bash would otherwise discard.
	if IFS= read -r selected < "$selector"; then :; fi
	if ! pb_registered_impl "$selected" "$@" || {
		! cmp -s "$selector" <(printf '%s' "$selected") &&
		! cmp -s "$selector" <(printf '%s\n' "$selected")
	}; then
		printf 'Invalid CANONICAL_IMPL. Run ./build canonize IMPL using a registered implementation.\n' >&2
		return 1
	fi
	printf '%s\n' "$selected"
}

pb_canonize() {
	local selector="$1" requested="$2" existing temporary
	shift 2
	if ! pb_registered_impl "$requested" "$@"; then
		printf 'Unknown implementation: %s\n' "$requested" >&2
		return 1
	fi
	if [[ -L "$selector" || ( -e "$selector" && ! -f "$selector" ) ]]; then
		printf 'CANONICAL_IMPL must be a regular file, not a symlink or directory: %s\n' "$selector" >&2
		return 1
	fi
	if existing="$(pb_read_canonical "$selector" "$@" 2>/dev/null)" && [[ "$existing" == "$requested" ]]; then
		printf '%s implementation canonized. Rerun ./build to rebuild.\n' "$requested"
		return 0
	fi
	temporary="$(mktemp "${selector}.XXXXXX")" || return 1
	if ! printf '%s\n' "$requested" > "$temporary" ||
		! chmod 644 "$temporary" || ! mv -f -- "$temporary" "$selector"; then
		rm -f -- "$temporary"
		return 1
	fi
	printf '%s implementation canonized. Rerun ./build to rebuild.\n' "$requested"
}

pb_host_platform() {
	local os arch
	case "$1" in
		Linux|linux) os=linux ;;
		Darwin|darwin|macos) os=macos ;;
		Windows_NT|windows|mswin|MSYS*|MINGW*|CYGWIN*) os=mswin ;;
		*) printf 'Unsupported operating system: %s\n' "$1" >&2; return 1 ;;
	esac
	case "$2" in
		x86_64|amd64|AMD64) arch=amd64 ;;
		aarch64|arm64|ARM64) arch=arm64 ;;
		*) printf 'Unsupported architecture: %s\n' "$2" >&2; return 1 ;;
	esac
	case "$os-$arch" in
		linux-amd64|linux-arm64|macos-arm64|mswin-amd64|mswin-arm64)
			printf '%s-%s\n' "$os" "$arch" ;;
		*) printf 'Unsupported platform: %s-%s\n' "$os" "$arch" >&2; return 1 ;;
	esac
}

pb_build_scope() {
	local implementations=canonical platforms=host flag
	for flag in "$@"; do
		case "$flag" in
			--all-impls|--all-implementations) implementations=all ;;
			--all-plats|--all-platforms) platforms=all ;;
			--all) implementations=all; platforms=all ;;
			*) printf 'Unknown build scope: %s\n' "$flag" >&2; return 1 ;;
		esac
	done
	printf '%s %s\n' "$implementations" "$platforms"
}
