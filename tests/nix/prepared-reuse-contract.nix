{ checks, zig }:
let
	uses = consumer: producer:
		builtins.elem checks.${producer}.drvPath
			(builtins.attrNames (builtins.getContext (checks.${consumer}.buildPhase + checks.${consumer}.installPhase)));
	zigConsumers = [ "test-cli-layout" "test-container-zig" "test-container-cross" "test-rust" "test-elixir" ]
		++ (if checks ? test-roc then [ "test-roc" ] else []);
in
assert builtins.all (name: uses name "test-zig"
	&& !(builtins.elem (toString zig) (map toString checks.${name}.nativeBuildInputs))) zigConsumers;
assert uses "test-container-c" "test-c";
assert uses "test-container-cross" "test-c";
assert uses "test-container-ffi" "test-ffi-cli";
assert uses "test-container-cross" "test-ffi-cli";
assert uses "test-ffi-cli" "test-zig";
assert !(checks ? test-no-ffi-symbols) || uses "test-no-ffi-symbols" "test-zig";
true
