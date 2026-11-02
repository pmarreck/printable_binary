# A bounded rolling pool refills a slot whenever any owned worker finishes.
# Caller supplies private scratch and a function that owns its own mutable state.
pb_run_test_groups() {
	local limit="${1:-}" scratch="${2:-}" callback="${3:-}"
	[[ "$#" -ge 4 && "$limit" =~ ^[1-8]$ && -d "$scratch" && ! -L "$scratch" ]] || {
		printf 'Invalid CLI group limit, scratch directory, or group set\n' >&2
		return 2
	}
	shift 3
	local -a groups=("$@")
	local -A seen=() active=()
	local group index next=0 completed failed=0
	for group in "${groups[@]}"; do
		if [[ ! "$group" =~ ^[a-z][a-z0-9_]*$ || -n "${seen[$group]+present}" ]]; then
			printf 'Invalid or duplicate CLI group: %s\n' "$group" >&2
			return 2
		fi
		seen[$group]=1
	done
	declare -F "$callback" >/dev/null || return 2
	local logs
	logs="$(mktemp -d "$scratch/cli-groups.XXXXXXXX")" || return 1
	while ((next < ${#groups[@]} || ${#active[@]} > 0)); do
		while ((next < ${#groups[@]} && ${#active[@]} < limit)); do
			("$callback" "${groups[next]}") > "$logs/$next.out" 2> "$logs/$next.err" &
			active[$!]=1
			next=$((next + 1))
		done
		completed=''
		# An explicit PID set leaves unrelated background children to their owner.
		if ! wait -n -p completed "${!active[@]}"; then failed=1; fi
		if [[ -n "${completed:-}" && -v "active[$completed]" ]]; then
			unset 'active[$completed]'
		else
			# Do not abandon owned children if the wait itself fails.
			failed=1
			for group in "${!active[@]}"; do wait "$group" || failed=1; done
			active=()
		fi
	done
	# Replay complete logs in declaration order, never interleaved worker output.
	for ((index=0; index<${#groups[@]}; index++)); do
		cat "$logs/$index.out" || failed=1
		cat "$logs/$index.err" >&2 || failed=1
	done
	rm -rf -- "$logs" || failed=1
	return "$failed"
}
