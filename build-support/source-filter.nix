# Nix inputs/flags still determine the build. Keep known non-runtime workflow
# files outside compiler sources while retaining current and future code.
root:
let
  excluded = map (relative: "${toString root}/${relative}") [
    "CANONICAL_IMPL" "README.md" "README_IMPLEMENTATIONS.md" "PLAN.md" "INTENT.md"
    ".dirtree-state" ".gitignore" "flake.nix" "flake.lock"
    "build" "build-all" "run" "test" "build-support/source-filter.nix"
    "docs/PLAN_LOG.md" "docs/plan_context/current-work.md"
    "tests/test-all" "tests/unit/test-test-entrypoint"
  ];
in
path: _type: !(builtins.elem (toString path) excluded)
