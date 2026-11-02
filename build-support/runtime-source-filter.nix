# Runtime checks retain selectors, entrypoints, Nix inputs and future source.
# Only these exact documentation/workflow paths are irrelevant to execution.
root:
let
	excluded = map (relative: "${toString root}/${relative}") [
		"README.md" "README_IMPLEMENTATIONS.md" "PLAN.md" "INTENT.md"
		".dirtree-state" "docs/PLAN_LOG.md" "docs/plan_context/current-work.md"
	];
in
path: _type: !(builtins.elem (toString path) excluded)
