{ pkgs, checks, source, rustToolchain }:
let
	lib = pkgs.lib;
	native = name: checks.${name};
	zig = "${native "test-zig"}/bin/printable-binary";
	ffi = "${native "test-ffi-cli"}/libexec/test-ffi-cli";
	c = "${native "test-c"}/bin/printable-binary-c";
	container = command: ''
		IMPLEMENTATION_TO_TEST=${lib.escapeShellArg command} bash tests/test_container || exit 1
	'';
	shared = command: ''
		IMPLEMENTATION_TO_TEST=${lib.escapeShellArg command} bash tests/cli/test-suite-output bash tests/test || exit 1
	'';
	recipes = {
		rust-toolchain-pin = ''
			case "$(${rustToolchain}/bin/rustc --version)" in
				"rustc 1.97.1 "*) ;; *) exit 1 ;;
			esac
		'';
		test-cli-groups = ''
			bash tests/unit/test-suite-control-driver || exit 1
			bash tests/cli/test-suite-controls "$PWD/bin/printable-binary-luajit" || exit 1
		'';
		test-docs-benchmark-contract = ''
			export PB_REQUIRED_CI_TARGETS=${checks.test-docs-benchmark-contract.PB_REQUIRED_CI_TARGETS}
			bash tests/test_docs_benchmark_contract || exit 1
			node tests/unit/test-codec-tag-docs.mjs || exit 1
		'';
		test-c = ''
			bash tests/unit/test-prepared-native-driver || exit 1
			bash tests/cli/test-prepared-native c ${native "test-c"} || exit 1
		'';
		test-zig = ''bash tests/cli/test-prepared-native zig ${native "test-zig"} || exit 1'';
		test-ape = ''bash tests/cli/test-prepared-native ape ${native "test-ape"} || exit 1'';
		test-zig-unit = ''
			node utils/generate_textual_policy.mjs --zig --check src/zig/textual_policy.zig || exit 1
			for suite in test-core test-ffi test-platform-identity test-cli-textual; do
				if ${native "test-zig-unit"}/libexec/$suite > unit.log 2>&1; then
					printf 'PASS: %s\n' "$suite"
				else cat unit.log >&2; exit 1; fi
			done
			node tests/cli/test-rust-textual.mjs ${native "test-zig-unit"}/libexec/textual-example Zig || exit 1
		'';
		test-cli-layout = ''
			test -x ${checks.test-cli-layout.canonicalReference} || exit 1
			test ! -e ${checks.test-cli-layout.canonicalLegacyAlias} || exit 1
			bash tests/test_cli_layout ${zig} ./bin/printable-binary-luajit || exit 1
		'';
		test-js = shared "./bin/printable-binary-node.js" + ''bash tests/test_node_cli_stats || exit 1'';
		test-lua = shared "./bin/printable-binary-luajit";
		test-js-unit = ''
			node tests/js/test_printable_binary.js || exit 1
			node tests/benchmark/textual_size/test.mjs || exit 1
		'';
		test-container-node = container "./bin/printable-binary-node.js";
		test-container-zig = container zig;
		test-container-c = container c;
		test-container-ffi = container ffi;
		test-container-lua = container "./bin/printable-binary-luajit";
		test-container-cross = ''
			for impl in ${zig} ${ffi} ${c} ./bin/printable-binary-luajit; do
				IMPL_A=./bin/printable-binary-node.js IMPL_B="$impl" bash tests/test_container_cross || exit 1
			done
		'';
		test-rust = ''
			bash tests/unit/test-rust-map-sync || exit 1
			node utils/generate_textual_policy.mjs --check rust/src/textual_policy.rs || exit 1
			bash tests/unit/test-retained-rust-driver || exit 1
			bash tests/cli/test-retained-rust ${native "test-rust"} \
				${native "test-rust"}/share/original-source-targets.json \
				${native "test-rust"}/share/original-package-targets.json || exit 1
			node tests/cli/test-rust-textual.mjs ${native "test-rust"}/libexec/textual-example || exit 1
			node tests/cli/test-recovery.mjs ${native "test-rust"}/bin/printable-binary-rs Rust || exit 1
			bash tests/cli/test-rust-malformed-utf8 ${native "test-rust"}/bin/printable-binary-rs || exit 1
			bash tests/cli/test-rust-spaces ${native "test-rust"}/bin/printable-binary-rs ${zig} || exit 1
			luajit -e 'for byte=0,255 do io.write(string.char(byte)) end' > allbytes || exit 1
			${native "test-rust"}/bin/printable-binary-rs < allbytes > rust.out 2> rust.err || exit 1
			grep -Eq 'Input throughput: [0-9]+[.][0-9]{2} MB read in [0-9]+[.][0-9]{3} s \([0-9]+[.][0-9]{2} MB/s\)' rust.err || exit 1
			PRINTABLE_BINARY_MUTE_STATS=1 ${zig} < allbytes > zig.out 2> zig.err || exit 1
			test ! -s zig.err && cmp rust.out zig.out || exit 1
			${native "test-rust"}/bin/printable-binary-rs -d < zig.out > decoded 2> rust.err || exit 1
			grep -Eq 'Input throughput: [0-9]+[.][0-9]{2} MB read in [0-9]+[.][0-9]{3} s \([0-9]+[.][0-9]{2} MB/s\)' rust.err || exit 1
			cmp allbytes decoded || exit 1
		'';
		test-elixir = ''bash tests/cli/test-elixir-prepared ${native "test-elixir"} ${zig} || exit 1'';
		test-ffi-cli = ''
			bash tests/unit/test-ffi-smoke-driver ${ffi} ${native "test-ffi-cli"}/libexec/ffi-smoke-input || exit 1
		'';
		test-leak = ''
			bash tests/unit/test-leak-driver || exit 1
			${native "test-leak"}/libexec/test-c-allocation-lifecycle || exit 1
			for defect in retain-result skip-work; do
				${native "test-leak"}/libexec/test-c-allocation-lifecycle --$defect > control.log 2>&1
				[[ "$?" != 0 ]] || exit 1
				case "$defect" in
					retain-result) grep -q 'retained requested bytes' control.log || exit 1 ;;
					skip-work) grep -q 'skipped allocating work' control.log || exit 1 ;;
				esac
			done
		'';
		test-embedded-map-sync = ''
			cp character_map_embedded.h committed.h || exit 1
			luajit utils/generate_embedded_map.lua || exit 1
			diff -q committed.h character_map_embedded.h || exit 1
		'';
		test-roc = ''
			bash tests/unit/test-roc-toolchain-pin || exit 1
			bash tests/cli/test-roc-prepared ${native "test-roc"} || exit 1
		'';
		test-build-all = builtins.replaceStrings [ "patchShebangs tests/fixtures" ]
			[ "# Shebangs are patched in the prepared source." ] checks.test-build-all.buildPhase;
		test-no-ffi-symbols = ''
			bash tests/unit/test-module-symbols || exit 1
			bash tests/unit/test-module-symbol-driver ${native "test-no-ffi-symbols"}/lib/libmodule_consumer.a \
				${native "test-no-ffi-symbols"}/lib/libprintable_binary.a || exit 1
		'';
		test-tag-recognition = ''
			bash tests/benchmark/tag_probe/test-prepared ${native "test-tag-recognition"} \
				${checks.test-tag-recognition.rawReference} || exit 1
		'';
	};
	names = builtins.attrNames recipes;
	expected = builtins.filter (name: name != "test-prepared-runtime") (builtins.attrNames checks);
	# Every check must have an explicit runtime scope; omissions are evaluation errors.
	coverage = import ../tests/nix/prepared-runtime-contract.nix { inherit names expected; };
	tools = with pkgs; [ bash coreutils diffutils findutils gawk gnugrep gnused gzip jq python3
		xxd hexdump luajit nodejs_24 binutils elixir gnumake git file ];
	heavy = [ "test-js" "test-build-all" "test-cli-groups" "test-rust" "test-zig-unit" "test-roc" "test-ape" "test-c" "test-zig" ];
	ordered = heavy ++ builtins.filter (name: !(builtins.elem name heavy)) names;
	identifier = name: builtins.replaceStrings [ "-" ] [ "_" ] name;
	caseScript = name: pkgs.writeShellScript "prepared-${name}" ''
		set -u
		export PATH=${lib.makeBinPath tools}
		[[ "$#" == 0 && -n "''${NIX_BUILD_TOP:-}''${TEST_WORKSPACE:-}" ]] || exit 2
		scratch="$(mktemp -d)" || exit 1
		trap 'rm -rf -- "$scratch"' EXIT
		export HOME="$scratch/home" TMPDIR="$scratch/tmp"
		mkdir -p "$HOME" "$TMPDIR" "$scratch/project" || exit 1
		cp -R ${bundle}/source/. "$scratch/project/" || exit 1
		chmod -R u+w "$scratch/project" || exit 1
		cd "$scratch/project" || exit 1
		unset PRINTABLE_BINARY_MAP PRINTABLE_BINARY_MUTE_STATS
		${recipes.${name}}
	'';
	# Scripts refer to source-only output to avoid a derivation self-reference.
	bundle = pkgs.stdenvNoCC.mkDerivation {
		name = "printable-binary-runtime-fixtures";
		src = source;
		nativeBuildInputs = tools;
		dontBuild = true;
		dontFixup = true;
		installPhase = ''
			mkdir -p "$out/source"
			cp -R . "$out/source/"
			chmod -R u+w "$out/source"
			patchShebangs "$out/source/bin" "$out/source/tests/fixtures"
		'';
	};
in
assert coverage;
assert !(lib.hasInfix "patchShebangs" recipes.test-build-all);
pkgs.linkFarm "printable-binary-prepared-runtime" (
	[ { name = "source"; path = "${bundle}/source"; }
		{ name = "expected"; path = pkgs.writeText "runtime-case-inventory" (lib.concatMapStrings (name: identifier name + "\n") ordered); }
		{ name = "scope"; path = pkgs.writeText "runtime-case-scope" "Runtime cases only. Roc's 61 compiler-driven unit cases remain a mixed prerequisite, not fresh execution.\n"; }
	] ++ map (name: { name = "cases/${identifier name}"; path = caseScript name; }) names
)
