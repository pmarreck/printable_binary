let
  source = fixture: builtins.path {
    path = fixture;
    name = "printable-binary-source-identity-fixture";
    filter = import ../../build-support/source-filter.nix fixture;
  };
  a = source ../fixtures/source-identity/a;
  b = source ../fixtures/source-identity/b;
  c = source ../fixtures/source-identity/c;
in
  a == b && a != c
  && builtins.readFile "${a}/src/value.zig" == "pub const value = 1;\n"
