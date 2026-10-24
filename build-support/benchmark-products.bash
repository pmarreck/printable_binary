# Resolve only the exact optimized product selected by the declared matrix.
# Verification is the same port used for build publication; no PATH fallback.
pb_benchmark_product() {
	local root="$1" pf="$2" implementation="$3" row impl platform variant target builder package entry format path
	row="$(pb_build_plan "$root/build-support/implementations" "$implementation" "$pf" canonical host)" || return 1
	IFS='|' read -r impl platform variant target builder package entry format <<< "$row"
	path="$(pb_product_path "$impl" "$platform" "$variant" ReleaseFast)" || return 1
	pb_verify_product "$root/$path" "$impl" "$platform" "$variant" "$target" ReleaseFast "$entry" "$format" nix || return 1
	printf '%s/%s/bin/%s\n' "$root" "$path" "$entry"
}
