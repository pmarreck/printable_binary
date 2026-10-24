{ packages, platform, canonical ? "zig" }:
let
  profiles = [ "ReleaseFast" "ReleaseSafe" "Debug" ];
  zigPlatforms = [ "linux-amd64" "linux-arm64" "macos-arm64" "mswin-amd64" "mswin-arm64" ];
  hostImplementations = if platform == "macos-arm64"
    then [ "c" "ffi" "rust" "luajit" "node" "wasm" ]
    else [ "c" "ffi" "rust" "luajit" "node" "wasm" "roc" ];
  required = builtins.concatLists (map (profile:
    (map (pf: "build-zig-${pf}-${profile}") zigPlatforms)
    ++ (map (impl: "build-${impl}-${platform}-${profile}") hostImplementations)
    ++ (map (pf: "build-ape-${pf}-${profile}") zigPlatforms)
  ) profiles);
  canonicalName = "build-${canonical}-${platform}-ReleaseFast";
  entrypoints = {
    zig = "printable-binary";
    c = "printable-binary-c";
    ffi = "printable-binary-ffi";
    rust = "printable-binary-rs";
    roc = "printable-binary-roc";
    luajit = "printable-binary-luajit";
    node = "printable-binary-node";
    ape = "printable-binary-ape.com";
    wasm = "printable-binary-wasm";
  };
in
builtins.all (name: builtins.hasAttr name packages) required
&& builtins.hasAttr canonicalName packages
&& (packages.default.implementationProduct or packages.default).drvPath == packages.${canonicalName}.drvPath
&& (packages.default.meta.mainProgram or "") == "printable-binary"
&& packages.${canonicalName}.meta.mainProgram == entrypoints.${canonical}
