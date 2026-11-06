{ pkgs, zig, source, rawProduct }:
pkgs.stdenvNoCC.mkDerivation {
	pname = "printable-binary-tag-recognition";
	version = "1";
	src = source;
	strictDeps = true;
	passthru.rawReference = "${rawProduct}/bin/printable-binary";
	nativeBuildInputs = [ zig pkgs.luajit pkgs.jq ];
	buildPhase = ''
		runHook preBuild
		export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
		mkdir -p "$HOME" "$XDG_CACHE_HOME" tests/benchmark/tag_probe/fixtures
		luajit tests/benchmark/tag_probe/generate-fixtures.lua character_map.txt tests/benchmark/tag_probe/fixtures
		cp src/zig/printable_binary.zig tests/benchmark/tag_probe/core.zig
		# Preserve the relocated core's relative import closure inside this source.
		cp src/zig/textual.zig src/zig/textual_policy.zig src/zig/recovery.zig tests/benchmark/tag_probe/
		test "$(grep -Fxc '        result[pos] = input[i];' tests/benchmark/tag_probe/core.zig)" = 1
		substituteInPlace tests/benchmark/tag_probe/core.zig --replace-fail \
			'        result[pos] = input[i];
        pos += 1;
        i += 1;' \
			'        @import("tag_probe").onMiss(input[i..]);
        result[pos] = input[i];
        pos += 1;
        i += 1;'
		zig build tag-probe -Dtag-probe=true -Doptimize=ReleaseFast \
			${pkgs.lib.optionalString pkgs.stdenv.isLinux "-Dtarget=${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-musl"} --prefix "$out"
		zig build tag-probe-test-bin -Dtag-probe=true -Doptimize=ReleaseSafe \
			${pkgs.lib.optionalString pkgs.stdenv.isLinux "-Dtarget=${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-musl"} --prefix "$out"
		# Compile the same real producer defects once; every check re-executes them.
		cp tests/benchmark/tag_probe/observer.zig "$TMPDIR/observer.original"
		cp tests/benchmark/tag_probe/core.zig "$TMPDIR/core.original"
		substituteInPlace tests/benchmark/tag_probe/observer.zig --replace-fail 'candidates += 1;' 'candidates += 0;'
		zig build tag-probe -Dtag-probe=true -Doptimize=ReleaseFast \
			${pkgs.lib.optionalString pkgs.stdenv.isLinux "-Dtarget=${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-musl"} --prefix "$TMPDIR/no-count"
		install -Dm755 "$TMPDIR/no-count/bin/printable-binary-tag-probe" "$out/libexec/tag-probe-no-count"
		cp "$TMPDIR/observer.original" tests/benchmark/tag_probe/observer.zig
		substituteInPlace tests/benchmark/tag_probe/core.zig --replace-fail 'result[pos] = byte;' 'result[pos] = byte ^ 1;'
		zig build tag-probe -Dtag-probe=true -Doptimize=ReleaseFast \
			${pkgs.lib.optionalString pkgs.stdenv.isLinux "-Dtarget=${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-musl"} --prefix "$TMPDIR/wrong-byte"
		install -Dm755 "$TMPDIR/wrong-byte/bin/printable-binary-tag-probe" "$out/libexec/tag-probe-wrong-byte"
		cp "$TMPDIR/core.original" tests/benchmark/tag_probe/core.zig
		runHook postBuild
	'';
	doCheck = true;
	checkPhase = ''
		runHook preCheck
		bash tests/benchmark/tag_probe/test-prepared "$out" ${rawProduct}/bin/printable-binary
		runHook postCheck
	'';
	dontInstall = true;
}
