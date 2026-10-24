{ pkgs, system, zig, rustToolchain, rocCompiler, rocPlatform, basePackages, source, rows }:
let
  lib = pkgs.lib;
  profiles = [ "ReleaseFast" "ReleaseSafe" "Debug" ];
  available = row: row.builder == "host" || row.builder == system
    || (row.builder == "linux" && pkgs.stdenv.isLinux);
  makePackage = row: profile:
    let
      impl = row.implementation;
      clangTarget = if row.platform == "macos-arm64" then "aarch64-apple-darwin" else row.target;
      nativeBase = pkgs.stdenv.mkDerivation {
        pname = "printable-binary-${impl}";
        version = "1.0.0";
        src = source;
        strictDeps = true;
      };
      base = basePackages.${impl} or nativeBase;
      metadata = {
        implementation = impl;
        PF = row.platform;
        inherit profile;
        target = row.target;
        executable = row.command;
        format = row.format;
        backend = "nix";
        runtime = if builtins.elem impl [ "zig" "ape" "roc" ] then "system" else "nix-closure";
      } // lib.optionalAttrs (row.variant != "-") { VARIANT = row.variant; };
      commonInstall = ''
        mkdir -p "$out/share/printable-binary" "$out/bin"
        cp character_map.txt "$out/share/printable-binary/character_map.txt"
        if [ ! -e "$out/bin/character_map.txt" ]; then
          ln -s ../share/printable-binary/character_map.txt "$out/bin/character_map.txt"
        fi
        printf '%s\n' ${lib.escapeShellArg (builtins.toJSON metadata)} > "$out/share/printable-binary/build.json"
      '';
      specific =
        if impl == "zig" then {
          nativeBuildInputs = [ zig ];
          buildPhase = ''
            export HOME="$TMPDIR"
            zig build -Dtarget=${row.target} -Dcpu=baseline -Doptimize=${profile} --prefix "$out"
          '';
          installPhase = commonInstall;
          dontPatchELF = true;
        } else if impl == "c" then {
          buildPhase = ''
            make c-cli PREFIX="$out" PROFILE=${profile} CC=clang TARGET_FLAGS=--target=${clangTarget}
          '';
          installPhase = commonInstall;
        } else if impl == "ffi" then {
          nativeBuildInputs = [ zig pkgs.clang ];
          buildPhase = ''
            export HOME="$TMPDIR"
            make build-ffi PREFIX="$out" CORE_PREFIX="$TMPDIR/core" PROFILE=${profile} \
              CC=clang TARGET_FLAGS=--target=${clangTarget} ZIG_TARGET=${row.target}
          '';
          installPhase = commonInstall;
        } else if impl == "rust" then {
          nativeBuildInputs = [ rustToolchain ];
          buildPhase = ''
            export HOME="$TMPDIR" CARGO_HOME="$TMPDIR/cargo"
            export RUSTFLAGS="-C target-cpu=generic"
            ${lib.optionalString (profile == "ReleaseSafe") "export CARGO_PROFILE_RELEASE_OVERFLOW_CHECKS=true"}
            cargo build --locked --offline --manifest-path rust/Cargo.toml \
              --target ${row.target} ${lib.optionalString (profile != "Debug") "--release"}
          '';
          installPhase = ''
            mkdir -p "$out/bin"
            cp rust/target/${row.target}/${if profile == "Debug" then "debug" else "release"}/printable-binary-rs "$out/bin/"
          '' + commonInstall;
        } else if impl == "roc" then {
          buildPhase = ''
            export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
            mkdir -p "$HOME" "$XDG_CACHE_HOME"
            cp -R ${rocPlatform}/platform roc/platform
            roc build --no-cache --target=${row.target} \
              --opt=${if profile == "Debug" then "dev" else "speed"} \
              ${lib.optionalString (profile == "Debug") "--debug"} roc/main.roc --output=printable-binary-roc
          '';
        } else if impl == "ape" then {
          buildPhase = ''
            export HOME="$TMPDIR"
            unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
            make build-ape PREFIX="$out" PROFILE=${profile}
          '';
          installPhase = commonInstall;
        } else if impl == "wasm" then {
          nativeBuildInputs = base.nativeBuildInputs ++ [ pkgs.makeWrapper ];
          buildPhase = ''
            export EM_CACHE="$TMPDIR/emscripten_cache"
            mkdir -p "$EM_CACHE"
            make build-wasm PREFIX="$out" PROFILE=${profile}
          '';
          installPhase = ''
            substitute ${./wasm-launcher.in} "$out/bin/printable-binary-wasm" \
              --subst-var-by bash ${pkgs.bash}/bin/bash \
              --subst-var-by config ${./config.bash} \
              --subst-var-by uname ${pkgs.coreutils}/bin/uname \
              --subst-var-by wazero ${pkgs.wazero}/bin/wazero \
              --subst-var-by module "$out/bin/printable-binary.wasm"
            chmod +x "$out/bin/printable-binary-wasm"
          '' + commonInstall;
        } else if impl == "luajit" then {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            mkdir -p "$out/bin" "$out/libexec"
            cp bin/printable-binary-luajit character_map.txt "$out/libexec/"
            makeWrapper ${pkgs.luajit}/bin/luajit "$out/bin/printable-binary-luajit" \
              --add-flags "$out/libexec/printable-binary-luajit"
          '' + commonInstall;
        } else if impl == "node" then {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            destination="$out/libexec/printable-binary"
            mkdir -p "$destination/bin" "$out/bin"
            cp -R js "$destination/"
            cp package.json character_map.txt "$destination/"
            cp bin/printable-binary-node.js "$destination/bin/"
            makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/printable-binary-node" \
              --add-flags "$destination/bin/printable-binary-node.js"
          '' + commonInstall;
        } else throw "No native build graph registered for ${impl}";
    in base.overrideAttrs (old: {
      pname = "printable-binary-${impl}-${row.platform}-${profile}";
      src = source;
      dontStrip = true;
      installPhase = old.installPhase + commonInstall;
      meta = (old.meta or {}) // { platforms = [ system ]; mainProgram = row.command; };
    } // specific);
in
lib.listToAttrs (lib.concatMap (row: map (profile: {
  name = "${row.package}-${profile}";
  value = makePackage row profile;
}) profiles) (builtins.filter available rows))
