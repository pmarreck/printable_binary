# Fresh network diagnostics are separate from Nix's local source cache.
pb_probe_source_url() {
	curl --head --silent --show-error --fail --location \
		--connect-timeout 10 --max-time 45 \
		--header 'Cache-Control: no-cache' --header 'Pragma: no-cache' \
		--output /dev/null "$1"
}

pb_check_source_availability() {
	local lock="$1" urls url failures=0
	urls="$(jq -er '
		if .version != 7 then error("unsupported lock format") else .nodes end |
		[.[] | select(.locked.type == "github") | .locked |
			if (.owner | test("^[A-Za-z0-9_.-]+$")) and
				(.repo | test("^[A-Za-z0-9_.-]+$")) and
				(.rev | test("^[0-9a-f]{40}$"))
			then "https://github.com/\(.owner)/\(.repo)/archive/\(.rev).tar.gz"
			else error("invalid immutable GitHub source") end] |
		if length == 0 then error("no pinned GitHub sources") else sort | unique | .[] end
	' "$lock")" || return 1
	while IFS= read -r url; do
		if pb_probe_source_url "$url"; then
			printf 'PASS: source reachable: %s\n' "$url"
		else
			printf 'FAIL: source unavailable: %s\n' "$url" >&2
			failures=$((failures + 1))
		fi
	done <<< "$urls"
	[[ "$failures" == 0 ]]
}
