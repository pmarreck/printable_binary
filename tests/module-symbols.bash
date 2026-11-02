# Pure classifiers for GNU/ELF nm rows; no filesystem or tool access.
pb_count_symbol_defs() {
	local address kind name extra count=0
	while IFS=$' \t' read -r address kind name extra; do
		if [[ "$address" =~ ^[0-9a-fA-F]+$ && "$kind" =~ ^[TtDdRrBb]$ && "$name" == pb_* && -z "$extra" ]]; then
			count=$((count + 1))
		fi
	done <<< "$1"
	printf '%s\n' "$count"
}

pb_has_consumer_export() {
	local address kind name extra
	while IFS=$' \t' read -r address kind name extra; do
		if [[ "$address" =~ ^[0-9a-fA-F]+$ && "$kind" == T && "$name" == module_consumer_touch && -z "$extra" ]]; then
			return 0
		fi
	done <<< "$1"
	return 1
}
