# Bounded waves keep the scheduler small; each callback gets a separate process.
# Caller supplies private scratch and a function that owns its own mutable state.
pb_run_test_groups() {
	local limit="${1:-}" scratch="${2:-}" callback="${3:-}"
	[[ "$#" -ge 4 && "$limit" =~ ^[1-8]$ && -d "$scratch" && ! -L "$scratch" ]] || {
		printf 'Invalid CLI group limit, scratch directory, or group set\n' >&2
		return 2
	}
	shift 3
	local -a groups=("$@") pids=()
	local -A seen=()
	local group index start end failed=0
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
	for ((start=0; start<${#groups[@]}; start+=limit)); do
		end=$((start + limit))
		((end <= ${#groups[@]})) || end=${#groups[@]}
		pids=()
		for ((index=start; index<end; index++)); do
			("$callback" "${groups[index]}") > "$logs/$index.out" 2> "$logs/$index.err" &
			pids+=("$!")
		done
		for group in "${pids[@]}"; do
			if ! wait "$group"; then failed=1; fi
		done
	done
	# Replay complete logs in declaration order, never interleaved worker output.
	for ((index=0; index<${#groups[@]}; index++)); do
		cat "$logs/$index.out" || failed=1
		cat "$logs/$index.err" >&2 || failed=1
	done
	rm -rf -- "$logs" || failed=1
	return "$failed"
}
