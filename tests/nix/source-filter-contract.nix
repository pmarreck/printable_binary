filter:
builtins.all (case: filter case.path case.type == case.include) [
  { path = "/project/CANONICAL_IMPL"; type = "regular"; include = false; }
  { path = "/project/src/CANONICAL_IMPL"; type = "regular"; include = true; }
  { path = "/project/build.zig"; type = "regular"; include = true; }
  { path = "/project/new-source.zig"; type = "regular"; include = true; }
  { path = "/project/CANONICAL_IMPL.backup"; type = "regular"; include = true; }
  { path = "/project/src"; type = "directory"; include = true; }
  { path = "/project/README.md"; type = "regular"; include = false; }
  { path = "/project/README_IMPLEMENTATIONS.md"; type = "regular"; include = false; }
  { path = "/project/PLAN.md"; type = "regular"; include = false; }
  { path = "/project/docs/plan_context/current-work.md"; type = "regular"; include = false; }
  { path = "/project/.dirtree-state"; type = "regular"; include = false; }
  { path = "/project/tests/test-all"; type = "regular"; include = false; }
  { path = "/project/tests/unit/test-test-entrypoint"; type = "regular"; include = false; }
  { path = "/project/build"; type = "regular"; include = false; }
  { path = "/project/test"; type = "regular"; include = false; }
  { path = "/project/docs/new-code.zig"; type = "regular"; include = true; }
  { path = "/project/tests/new-code.zig"; type = "regular"; include = true; }
  { path = "/project/src/README.md"; type = "regular"; include = true; }
  { path = "/project/Makefile"; type = "regular"; include = true; }
  { path = "/project/character_map.txt"; type = "regular"; include = true; }
  { path = "/project/build-support/config.bash"; type = "regular"; include = true; }
  { path = "/project/build-support/wasm-launcher.in"; type = "regular"; include = true; }
]
