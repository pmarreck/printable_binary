#!/usr/bin/env bash
# Hermetic capture helper for the Nix test sandbox. It mirrors the dynamic
# out/err/rc contract of the developer's capture helper for text test output.

capture() {
	local capture_out
	local capture_err
	capture_out="$(mktemp)" || return 1
	capture_err="$(mktemp)" || {
		rm -f "$capture_out"
		return 1
	}

	"$@" >"$capture_out" 2>"$capture_err"
	rc=$?
	out="$(<"$capture_out")"
	err="$(<"$capture_err")"
	rm -f "$capture_out" "$capture_err"
}
