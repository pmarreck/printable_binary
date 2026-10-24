filter:
builtins.all (case: filter case.path case.type == case.include) [
  { path = "/project/CANONICAL_IMPL"; type = "regular"; include = false; }
  { path = "/project/src/CANONICAL_IMPL"; type = "regular"; include = true; }
  { path = "/project/build.zig"; type = "regular"; include = true; }
  { path = "/project/new-source.zig"; type = "regular"; include = true; }
  { path = "/project/CANONICAL_IMPL.backup"; type = "regular"; include = true; }
  { path = "/project/src"; type = "directory"; include = true; }
]
