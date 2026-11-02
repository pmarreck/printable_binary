let
	filterFor = import ../../build-support/runtime-source-filter.nix;
	filter = filterFor "/project";
	cases = [
		{ path = "/project/PLAN.md"; include = false; }
		{ path = "/project/README.md"; include = false; }
		{ path = "/project/README_IMPLEMENTATIONS.md"; include = false; }
		{ path = "/project/INTENT.md"; include = false; }
		{ path = "/project/.dirtree-state"; include = false; }
		{ path = "/project/docs/PLAN_LOG.md"; include = false; }
		{ path = "/project/docs/plan_context/current-work.md"; include = false; }
		{ path = "/project/CANONICAL_IMPL"; include = true; }
		{ path = "/project/build"; include = true; }
		{ path = "/project/build-all"; include = true; }
		{ path = "/project/run"; include = true; }
		{ path = "/project/test"; include = true; }
		{ path = "/project/flake.nix"; include = true; }
		{ path = "/project/flake.lock"; include = true; }
		{ path = "/project/.gitignore"; include = true; }
		{ path = "/project/build-support/runtime-source-filter.nix"; include = true; }
		{ path = "/project/character_map.txt"; include = true; }
		{ path = "/project/src/new-code.zig"; include = true; }
		{ path = "/project/src/README.md"; include = true; }
		{ path = "/project/docs/new-code.zig"; include = true; }
		{ path = "/project/docs/CODEC_MODES.md"; include = true; }
		{ path = "/project/tests/fixtures/PLAN.md"; include = true; }
		{ path = "/project/tests/new-suite"; include = true; }
		{ path = "/project/PLAN.md.backup"; include = true; }
		{ path = "/project/new-source"; include = true; }
	];
	source = fixture: builtins.path {
		path = fixture;
		name = "printable-binary-runtime-identity-fixture";
		filter = filterFor fixture;
	};
	a = source ../fixtures/source-identity/a;
	b = source ../fixtures/source-identity/b;
	c = source ../fixtures/source-identity/c;
in
assert builtins.all (case: filter case.path "regular" == case.include) cases;
assert builtins.all (path: filter path "directory") [ "/project/src" "/project/tests" "/project/docs" ];
assert a == b;
assert a != c;
true
