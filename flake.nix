{
  description = "PrintableBinary implementations, reproducible builds, and checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    performance-profiling = {
      url = "github:pmarreck/performance_profiling/ecf713b81a74a51f76719bf9debc44fe23a0b331";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    roc-overlay = {
      url = "github:roc-lang/roc-overlay/d0ad2328b1d81e2f6dcfcdf1fc800d9e74838a4d";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-darwin.follows = "nixpkgs";
    };
    rocSource = {
      url = "github:roc-lang/roc/130536d915d4355d6152c7e20529a09a5a0cbe32";
      flake = false;
    };
    rocPlatformTemplate = {
      url = "github:lukewilliamboswell/roc-platform-template-zig/4915dc3812b8525bbb8ff17ce0fe3c61ca9e2966";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, rust-overlay, roc-overlay, rocSource, rocPlatformTemplate, performance-profiling }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        zig = zig-overlay.packages.${system}."0.16.0";
        rustToolchain = pkgs.rust-bin.stable."1.97.1".default;
        rocNightly = roc-overlay.packages.${system}."nightly-2026-10-04-130536d";
        rocCompiler = assert rocSource.rev == rocNightly.compilerCommit; rocNightly;
        rocLinkerInputs = pkgs.fetchurl {
          url = "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/link-inputs-sha256-2df3df339dfb1ad4ae1fad0f382cc100c5b31b3921cdeff939f6aea51457886d/link-inputs-all.tar";
          hash = "sha256-5U5u0Q/UM/VcmrnRuP80Zzm1ydIfJMgzzQvkeFOTrvQ=";
        };
        rocLinkerInputsHash = "e54e6ed10fd433f55c9ab9d1b8ff346739b5c9d21f24c833cd0be4785393aef4";

        cosmoccVersion = "4.0.2";
        cosmoccHash = "sha256-6KZv7KU2rJhwfc9k6z9I6ZdfIS1KqRFLZUo8YyuD7ZY=";
        cosmoccSrc = pkgs.fetchzip {
          url = "https://cosmo.zip/pub/cosmocc/cosmocc-${cosmoccVersion}.zip";
          hash = cosmoccHash;
          stripRoot = false;
        };
        cosmoccBin = pkgs.stdenvNoCC.mkDerivation {
          pname = "cosmocc-bin";
          version = cosmoccVersion;
          src = cosmoccSrc;
          phases = [ "installPhase" ];
          installPhase = ''
            mkdir -p $out
            cp -r $src/* $out/
          '' + pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            # WSL's MZ handler can intercept APE helpers inside the sandbox.
            # Bootstrap through the native ELF loader, including assimilate
            # itself, and convert build tools only. Compiler outputs stay APE.
            cp "$out/bin/assimilate" "$TMPDIR/assimilate"
            find "$out" -type f -perm /111 -print0 | while IFS= read -r -d "" tool; do
              if [[ $(head -c 2 "$tool") == MZ ]]; then
                chmod u+w "$tool"
                "$out/bin/ape-${pkgs.stdenv.hostPlatform.parsed.cpu.name}.elf" \
                  "$TMPDIR/assimilate" -e -c \
                  ${if pkgs.stdenv.hostPlatform.isAarch64 then "-a" else "-x"} "$tool"
              fi
            done
            bash ${./tests/test_cosmocc_host_tools} "$out"
          '';
        };

        emscriptenFlags = "-O3 -DNDEBUG "
          + "-s STANDALONE_WASM=1 "
          + "-s FILESYSTEM=1 "
          + "-s INITIAL_MEMORY=134217728 "
          + "-DPRINTABLE_BINARY_HELP_NAME=\\\"printable-binary\\\"";

        nativeCBase = pkgs.stdenv.mkDerivation {
          pname = "printable-binary-c";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.clang ];

          buildPhase = ''
            clang -O3 -Wall -Wextra -I. -o printable-binary-c src/printable_binary.c
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp printable-binary-c $out/bin/
            cp character_map.txt $out/bin/character_map.txt
          '';

          meta = with pkgs.lib; {
            description = "High-performance C implementation of PrintableBinary";
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };

        wasmBase = pkgs.stdenv.mkDerivation {
          pname = "printable-binary-wasm";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.emscripten ];

          buildPhase = ''
            export EM_CACHE="$TMPDIR/emscripten_cache"
            mkdir -p "$EM_CACHE"
            emcc -I. src/printable_binary.c ${emscriptenFlags} -o printable-binary.wasm
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp printable-binary.wasm $out/bin/printable-binary.wasm
            cp character_map.txt $out/bin/character_map.txt
          '';

          meta = with pkgs.lib; {
            description = "PrintableBinary compiled to WebAssembly via Emscripten";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        # APE compilation requires Linux; foreign targets use that Nix builder.
        apeBase = pkgs.stdenvNoCC.mkDerivation {
          pname = "printable-binary-ape";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [
            cosmoccBin
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.coreutils
          ];

          buildPhase = ''
            export PATH=${cosmoccBin}/bin:$PATH
            export HOME=$TMPDIR
            # Clear any inherited include paths that might conflict
            unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
            cosmocc -O3 -DNDEBUG -I. -o printable-binary-ape.com src/printable_binary.c
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp printable-binary-ape.com $out/bin/printable-binary-ape.com
            cp character_map.txt $out/bin/character_map.txt
          '';

          meta = with pkgs.lib; {
            description = "PrintableBinary built as an Actually Portable Executable (Cosmopolitan, pinned ${cosmoccVersion})";
            license = licenses.mit;
            # Foreign APE products select a Linux Nix builder explicitly.
            platforms = platforms.linux;
          };
        };

        # Zig implementation
        zigBase = pkgs.stdenv.mkDerivation {
          pname = "printable-binary";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [ zig ];

          buildPhase = ''
            export HOME=$TMPDIR
            zig build -Doptimize=ReleaseFast
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/printable-binary $out/bin/
            cp character_map.txt $out/bin/character_map.txt
          '';

          meta = with pkgs.lib; {
            description = "PrintableBinary Zig implementation";
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };

        printableBinaryRocPlatform = pkgs.stdenvNoCC.mkDerivation {
          pname = "printable-binary-roc-platform";
          version = "0.1.0";
          src = rocPlatformTemplate;
          strictDeps = true;
          nativeBuildInputs = [ pkgs.gnutar pkgs.patch pkgs.python3 rocCompiler zig ];

          unpackPhase = ''
            cp -R "$src" source
            chmod -R u+w source
            cd source
          '';

          patchPhase = ''
            patch -p1 < ${./roc/platform.patch}
            patch -p1 < ${./roc/platform-extension.patch}
            patch -p1 < ${./roc/platform-identity.patch}
            cp ${./src/zig/platform_identity.zig} src/platform_identity.zig
          '';

          buildPhase = ''
			export HOME="$TMPDIR/home"
			export XDG_CACHE_HOME="$HOME/.cache"
			mkdir -p "$XDG_CACHE_HOME"
            linker_cache=".zig-cache/linker-inputs/${rocLinkerInputsHash}"
            mkdir -p "$linker_cache/tree"
            cp ${rocLinkerInputs} "$linker_cache/archive.tar.gz"
            tar -xf "$linker_cache/archive.tar.gz" -C "$linker_cache/tree"
            roc glue ${rocSource}/src/glue/src/ZigGlue.roc ./src ./platform/main.roc
            roc fmt platform/main.roc platform/Host.roc platform/Clock.roc platform/Environment.roc
            zig build native -Doptimize=ReleaseFast
          '';

          installPhase = ''
            mkdir -p "$out"
            cp -R platform "$out/platform"
          '';
        };

        rocBase = pkgs.stdenvNoCC.mkDerivation {
          pname = "printable-binary-roc";
          version = "1.0.0";
          src = ./.;
          strictDeps = true;
          nativeBuildInputs = [ rocCompiler ];

          buildPhase = ''
			export HOME="$TMPDIR/home"
			export XDG_CACHE_HOME="$HOME/.cache"
			mkdir -p "$XDG_CACHE_HOME"
            cp -R ${printableBinaryRocPlatform}/platform roc/platform
            roc build --jobs="$NIX_BUILD_CORES" --no-cache --opt=speed roc/main.roc --output=printable-binary-roc
          '';

          installPhase = ''
            mkdir -p "$out/bin"
            cp printable-binary-roc "$out/bin/"
          '';

          meta = with pkgs.lib; {
            description = "PrintableBinary Roc implementation";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };
        platform = {
          x86_64-linux = "linux-amd64";
          aarch64-linux = "linux-arm64";
          aarch64-darwin = "macos-arm64";
        }.${system};
        matrixRows = map (line:
          let fields = pkgs.lib.splitString "|" line;
          in assert builtins.length fields == 8; {
            implementation = builtins.elemAt fields 0;
            platform = builtins.elemAt fields 1;
            variant = builtins.elemAt fields 2;
            target = builtins.elemAt fields 3;
            builder = builtins.elemAt fields 4;
            package = builtins.elemAt fields 5;
            command = builtins.elemAt fields 6;
            format = builtins.elemAt fields 7;
          }
        ) (builtins.filter (line: line != "" && !(pkgs.lib.hasPrefix "#" line))
          (pkgs.lib.splitString "\n" (builtins.readFile ./build-support/implementations)));
        runtimeSource = pkgs.lib.cleanSourceWith {
          name = "printable-binary-runtime-source";
          src = ./.;
          filter = import ./build-support/runtime-source-filter.nix ./.;
        };
        packageSource = pkgs.lib.cleanSourceWith {
          name = "printable-binary-source";
          src = ./.;
          filter = import ./build-support/source-filter.nix ./.;
        };
        localBuildProducts = import ./build-support/packages.nix {
          inherit pkgs system zig rustToolchain rocCompiler;
          rocPlatform = printableBinaryRocPlatform;
          source = packageSource;
          rows = matrixRows;
          basePackages = { c = nativeCBase; zig = zigBase; ape = apeBase; wasm = wasmBase; roc = rocBase; };
        };
        buildProducts = localBuildProducts // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin
          (pkgs.lib.listToAttrs (pkgs.lib.concatMap (row: map (profile: {
            name = "${row.package}-${profile}";
            value = self.packages.x86_64-linux."${row.package}-${profile}";
          }) [ "ReleaseFast" "ReleaseSafe" "Debug" ]) (builtins.filter (row: row.implementation == "ape") matrixRows)));
        canonical = let
          raw = builtins.readFile ./CANONICAL_IMPL;
          selected = pkgs.lib.removeSuffix "\n" raw;
        in if builtins.elem selected (map (row: row.implementation) matrixRows)
          && (raw == selected || raw == selected + "\n")
          then selected else throw "Invalid CANONICAL_IMPL; run ./build canonize IMPL";
        selectedProduct = "build-${canonical}-${platform}-ReleaseFast";
        canonicalPackage = product: row: import ./build-support/canonical-package.nix {
          inherit pkgs product;
          entry = row.command;
          implementation = row.implementation;
        };
        canonicalRow = pkgs.lib.findFirst (row: row.implementation == canonical && row.platform == platform)
          (throw "Canonical implementation ${canonical} has no declared ${platform} build") matrixRows;
        printableBinaryNative = buildProducts."build-c-${platform}-ReleaseFast";
        printableBinaryWasm = buildProducts."build-wasm-${platform}-ReleaseFast";
        printableBinaryZig = buildProducts."build-zig-${platform}-ReleaseFast";
        printableBinaryApe = buildProducts."build-ape-${platform}-ReleaseFast";
        printableBinaryRoc = buildProducts."build-roc-${platform}-ReleaseFast";
        tagRecognition = import ./build-support/tag-recognition.nix {
          inherit pkgs zig;
          source = packageSource;
          rawProduct = printableBinaryZig;
        };
        allPackages = buildProducts // {
          inherit printableBinaryNative printableBinaryWasm printableBinaryZig tagRecognition;
          textualSizeStudy = pkgs.writeShellScriptBin "printable-binary-textual-size-study" ''
            exec ${pkgs.nodejs_24}/bin/node ${packageSource}/tests/benchmark/textual_size/study.mjs "$@"
          '';
          default = canonicalPackage buildProducts.${selectedProduct} canonicalRow;
          allImplementations = pkgs.linkFarm "printable-binary-implementations-${platform}"
            (map (row: {
              name = row.implementation;
              path = buildProducts."${row.package}-ReleaseFast";
            }) (builtins.filter (row: row.platform == platform) matrixRows));
        } // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          inherit printableBinaryApe printableBinaryRoc;
        };
      in
      {
        devShells.build = pkgs.mkShell {
          packages = with pkgs; [ bash binutils coreutils diffutils file jq ];
        };
        devShells.profiling = pkgs.mkShell {
          packages = [ performance-profiling.packages.${system}.default pkgs.bash pkgs.gitMinimal ];
          PB_PROFILE_PF = platform;
        };
        # Runtime tools for exact prepared tests; language builds stay in derivations.
        devShells.tests = pkgs.mkShell {
          packages = with pkgs; [
            bash coreutils diffutils gawk gnugrep gnused jq python3
            xxd hexdump luajit nodejs_24 binutils elixir
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap pkgs.util-linux ];
        };
        devShells.default = pkgs.mkShell {
          buildInputs =
            let
              linuxOnly = with pkgs; lib.optionals (!stdenv.isDarwin) [ valgrind perf-tools ];
            in
            with pkgs; [
              # C compilation/tools
              gcc
              clang

              # Build systems
              gnumake
              cmake
              ninja

              # Performance and profiling tools
              hyperfine
              time

              # Cross-compilation targets (optional)
              pkgsCross.mingwW64.buildPackages.gcc

              # Actually Portable Executable (cosmopolitan, pinned)
              cosmoccBin

              # Development utilities
              bash
              coreutils
              diffutils
              jq
              xxd
              hexdump
              file

              # Benchmarking and testing
              luajit
              wazero

              # Zig compiler
              zig

              # LLVM tools (for PGO profdata merge, IR analysis)
              llvmPackages.llvm

              # JavaScript/TypeScript runtime for web implementation
              deno
              nodejs_24

              # WebAssembly toolchain
              emscripten

              # Elixir/Erlang (the ~PB compile-time sigil demo)
              elixir
            ]  ++ [ rustToolchain ]
			   ++ lib.optionals stdenv.isLinux [ rocCompiler ]
               ++ lib.optionals stdenv.isDarwin [ lldb ]
               ++ lib.optionals (!stdenv.isDarwin) [ gdb ]
               ++ linuxOnly;

          shellHook = ''
            echo "PrintableBinary Development Environment"
            echo "========================================"
            echo "Available compilers:"
            echo "  gcc: $(gcc --version | head -n1)"
            echo "  clang: $(clang --version | head -n1)"
            ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              echo "  roc: $(roc version)"
            ''}
            echo ""
            echo "Available tools:"
            echo "  make, cmake, ninja"
            echo "  gdb, valgrind"
            echo "  hyperfine (for benchmarking)"
            echo "  deno (for JavaScript/web implementation)"
            echo "  node (for CLI/automation tests)"
            echo "  emcc (Emscripten) for WebAssembly builds"
            echo "  cosmocc ${cosmoccVersion} (pinned) for APE builds (fat x86_64 + arm64)"
            echo "  wazero (WASI runtime for testing)"
            echo ""
            echo "Example build commands:"
            echo "  ./build                       # canonical host product through Nix"
            echo "  ./build --all-impls            # every declared host implementation"
            echo "  ./build --all-plats            # canonical implementation, all declared PFs"
            echo "  ./build --all                  # both scopes"
            echo "  ./build canonize zig           # record intent without building"
            echo "  ./run --help                   # build and launch the exact host command"
            echo "  ./test                         # complete Nix check graph"
            echo ""
            echo "Test JavaScript implementation:"
            echo "  deno run --allow-read --allow-env tests/js/test_printable_binary.js"
            echo ""
            echo "Serve web interface (requires simple http server):"
            echo "  python3 -m http.server 8000"
            echo "  # Then open http://localhost:8000 in your browser"
            echo ""
            echo "Cross-compilation example:"
            echo "  ./build --platform=mswin-amd64"
            echo ""
          '';

          CC = "gcc";
          CXX = "g++";
        };

        packages = assert (import ./tests/nix/build-matrix-contract.nix { packages = allPackages; inherit platform canonical; });
          assert (import ./tests/nix/source-filter-contract.nix (import ./build-support/source-filter.nix "/project"));
          assert (import ./tests/nix/source-identity-contract.nix);
          assert (import ./tests/nix/prepared-reuse-contract.nix { checks = self.checks.${system}; inherit zig; });
          allPackages;

        checks = assert (import ./tests/nix/runtime-source-contract.nix); {
          test-tag-recognition = tagRecognition;
          test-cli-groups = pkgs.stdenvNoCC.mkDerivation {
            name = "test-cli-groups";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ bash coreutils gawk luajit python3 xxd hexdump ];
            buildPhase = ''
              bash tests/unit/test-cli-group-runner
              bash tests/unit/test-cli-case-inventory
              patchShebangs tests/fixtures/fail-first-codec-call bin/printable-binary-luajit
              bash tests/integration/test-shared-suite-failure "$PWD/bin/printable-binary-luajit"
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };
          rust-toolchain-pin = pkgs.runCommand "printable-binary-rust-toolchain-pin" {
            nativeBuildInputs = [ rustToolchain ];
          } ''
            actual="$(rustc --version)"
            case "$actual" in
              "rustc 1.97.1 "*) ;;
              *)
                echo "expected rustc 1.97.1, got $actual" >&2
                exit 1
                ;;
            esac
            mkdir -p "$out"
          '';

          # Documentation and benchmark inventory stay in sync with the supported
          # implementations and the 256-row source-byte mapping reference.
          test-docs-benchmark-contract = pkgs.stdenvNoCC.mkDerivation {
            name = "test-docs-benchmark-contract";
            src = ./.;
            nativeBuildInputs = with pkgs; [ bash binutils file gawk gnugrep jq nodejs_24 ];
            PB_REQUIRED_CI_TARGETS = pkgs.writeText "printable-binary-required-ci-targets" (pkgs.lib.concatStringsSep "\n"
              ([ "packages.x86_64-linux.default" ] ++ map (name: "checks.x86_64-linux.${name}") (builtins.attrNames self.checks.x86_64-linux)) + "\n");
            buildPhase = ''
              export HOME=$TMPDIR
              bash ./tests/test_docs_benchmark_contract
              node tests/unit/test-codec-tag-docs.mjs
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          test-c = pkgs.stdenv.mkDerivation {
            name = "test-c";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ clang python3 xxd hexdump ];
            buildPhase = ''
              clang -O2 -Wall -Wextra -I. -o test-c-two-byte-domain tests/unit/test-c-two-byte-domain.c
              clang -O3 -Wall -Wextra -I. -o printable-binary-c src/printable_binary.c
            '';
            installPhase = ''
              install -Dm755 printable-binary-c "$out/bin/printable-binary-c"
              install -Dm755 test-c-two-byte-domain "$out/libexec/test-c-two-byte-domain"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/unit/test-prepared-native-driver
              bash tests/cli/test-prepared-native c "$out"
            '';
          };

          test-zig-unit = pkgs.stdenv.mkDerivation {
            name = "test-zig-unit";
            src = runtimeSource;
            nativeBuildInputs = [ zig pkgs.nodejs_24 ];
            buildPhase = ''
              export HOME=$TMPDIR
              node utils/generate_textual_policy.mjs --zig --check src/zig/textual_policy.zig
              zig build test-bins -Doptimize=ReleaseSafe
              zig build textual-example -Doptimize=ReleaseFast
            '';
            doCheck = true;
            checkPhase = ''
              for suite in test-core test-ffi test-platform-identity test-cli-textual; do
                if ./zig-out/libexec/$suite > unit.log 2>&1; then
                  echo "PASS: $suite"
                else
                  cat unit.log >&2
                  exit 1
                fi
              done
              node tests/cli/test-rust-textual.mjs ./zig-out/libexec/textual-example Zig
            '';
            installPhase = "mkdir -p $out && cp -R zig-out/libexec $out/ && touch $out/passed";
          };

          test-zig = pkgs.stdenv.mkDerivation {
            name = "test-zig";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ zig python3 xxd hexdump nodejs_24 ];
            buildPhase = ''
              export HOME=$TMPDIR
              zig build -Doptimize=ReleaseFast
            '';
            installPhase = ''
              install -Dm755 zig-out/bin/printable-binary "$out/bin/printable-binary"
              install -Dm644 zig-out/lib/libprintable_binary.a "$out/lib/libprintable_binary.a"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/cli/test-prepared-native zig "$out"
            '';
          };

          # The installed command name is a compatibility contract: Zig is the
          # default CLI, while the source-distributed LuaJIT implementation
          # remains explicitly selectable for comparison and fallback.
          test-cli-layout = pkgs.stdenvNoCC.mkDerivation {
            name = "test-cli-layout";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ luajit ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-luajit
              test -x ${printableBinaryZig}/bin/printable-binary
              test ! -e ${printableBinaryZig}/bin/printable-binary-zig
              bash ./tests/test_cli_layout \
                ${self.checks.${system}.test-zig}/bin/printable-binary \
                ./bin/printable-binary-luajit
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          test-js = pkgs.stdenv.mkDerivation {
            name = "test-js";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ nodejs_24 python3 xxd hexdump ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-node.js
              IMPLEMENTATION_TO_TEST=./bin/printable-binary-node.js bash ./tests/cli/test-suite-output bash ./tests/test
              bash ./tests/test_node_cli_stats
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # The retained LuaJIT CLI has an explicit name but remains a supported
          # full implementation, including the common stderr throughput contract.
          test-lua = pkgs.stdenv.mkDerivation {
            name = "test-lua";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ luajit python3 xxd hexdump ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-luajit
              IMPLEMENTATION_TO_TEST=./bin/printable-binary-luajit bash ./tests/cli/test-suite-output bash ./tests/test
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # JS library unit tests (container codec + crc32 vector-pinning, issue #1).
          # Previously orphaned (test-js runs only the cross-impl CLI suite); wired
          # in so the printable-binary-file.json container is MFIC-guarded in CI.
          test-js-unit = pkgs.stdenv.mkDerivation {
            name = "test-js-unit";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ nodejs_24 allPackages.textualSizeStudy ];
            buildPhase = ''
              export HOME=$TMPDIR
              node tests/js/test_printable_binary.js
              node tests/benchmark/textual_size/test.mjs
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Container (.pbf.json) CLI round-trip + self-verify, issue #1. Parameterized
          # by IMPLEMENTATION_TO_TEST; one check per impl as they gain -C/--container.
          test-container-node = pkgs.stdenv.mkDerivation {
            name = "test-container-node";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ nodejs_24 ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-node.js
              IMPLEMENTATION_TO_TEST=./bin/printable-binary-node.js bash ./tests/test_container
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Container (.pbf.json) for the Zig CLI (issue #1).
          test-container-zig = pkgs.stdenv.mkDerivation {
            name = "test-container-zig";
            src = runtimeSource;
            buildPhase = ''
              export HOME=$TMPDIR
              IMPLEMENTATION_TO_TEST=${self.checks.${system}.test-zig}/bin/printable-binary bash ./tests/test_container
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Cross-impl container differential: Node <-> Zig must agree (issue #1).
          test-container-cross = pkgs.stdenv.mkDerivation {
            name = "test-container-cross";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ nodejs_24 luajit ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-node.js bin/printable-binary-luajit
              for impl in ${self.checks.${system}.test-zig}/bin/printable-binary \
                ${self.checks.${system}.test-ffi-cli}/libexec/test-ffi-cli \
                ${self.checks.${system}.test-c}/bin/printable-binary-c ./bin/printable-binary-luajit; do
                IMPL_A=./bin/printable-binary-node.js IMPL_B="$impl" bash ./tests/test_container_cross || exit 1
              done
            '';

            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Container (.pbf.json) for the C FFI CLI — dogfoods the FFI (pb_crc32 etc).
          test-container-ffi = pkgs.stdenv.mkDerivation {
            name = "test-container-ffi";
            src = runtimeSource;
            buildPhase = ''
              export HOME=$TMPDIR
              IMPLEMENTATION_TO_TEST=${self.checks.${system}.test-ffi-cli}/libexec/test-ffi-cli bash ./tests/test_container
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Container (.pbf.json) for the standalone C CLI (issue #1).
          test-container-c = pkgs.stdenv.mkDerivation {
            name = "test-container-c";
            src = runtimeSource;
            buildPhase = ''
              export HOME=$TMPDIR
              IMPLEMENTATION_TO_TEST=${self.checks.${system}.test-c}/bin/printable-binary-c bash ./tests/test_container
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Container (.pbf.json) for the Lua reference CLI (issue #1).
          test-container-lua = pkgs.stdenv.mkDerivation {
            name = "test-container-lua";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ luajit ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs bin/printable-binary-luajit
              IMPLEMENTATION_TO_TEST=./bin/printable-binary-luajit bash ./tests/test_container
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Rust crate: in-crate tests + the transport-critical cross-impl guard
          # (Rust encode must be byte-identical to Zig over all 256 bytes).
          test-rust = pkgs.stdenv.mkDerivation {
            name = "test-rust";
            src = runtimeSource;
            nativeBuildInputs = [ rustToolchain pkgs.jq pkgs.nodejs_24 ];
            buildPhase = ''
              export HOME=$TMPDIR
              export CARGO_HOME=$TMPDIR/cargo
              bash tests/unit/test-rust-map-sync
              node utils/generate_textual_policy.mjs --check rust/src/textual_policy.rs
              bash tests/integration/test-rust-package "$PWD/packaged-test-artifacts" "$PWD/packaged-test-metadata.json"
              cargo test --release --offline --manifest-path rust/Cargo.toml
              cargo build --release --offline --manifest-path rust/Cargo.toml
              cargo build --release --offline --manifest-path rust/Cargo.toml --example textual
              cargo metadata --locked --offline --no-deps --format-version 1 --manifest-path rust/Cargo.toml > rust-test-metadata.json
              node tests/cli/test-rust-textual.mjs ./rust/target/release/examples/textual
              bash tests/cli/test-rust-malformed-utf8 ./rust/target/release/printable-binary-rs
              bash tests/cli/test-rust-spaces ./rust/target/release/printable-binary-rs ${self.checks.${system}.test-zig}/bin/printable-binary
              for i in $(seq 0 255); do printf "\\$(printf '%03o' "$i")"; done > allbytes
              ./rust/target/release/printable-binary-rs < allbytes > r.out 2> r.err
              grep -Eq 'Input throughput: [0-9]+[.][0-9]{2} MB read in [0-9]+[.][0-9]{3} s \([0-9]+[.][0-9]{2} MB/s\)' r.err || {
                echo "FAIL: Rust CLI did not emit input throughput" >&2
                cat r.err >&2
                exit 1
              }
              PRINTABLE_BINARY_MUTE_STATS=1 ${self.checks.${system}.test-zig}/bin/printable-binary < allbytes > z.out
              cmp r.out z.out || { echo "FAIL: Rust encode != Zig encode" >&2; exit 1; }
              ./rust/target/release/printable-binary-rs -d < z.out > rt.out 2> rt.err
              grep -Eq 'Input throughput: [0-9]+[.][0-9]{2} MB read in [0-9]+[.][0-9]{3} s \([0-9]+[.][0-9]{2} MB/s\)' rt.err || {
                echo "FAIL: Rust decode did not emit input throughput" >&2
                cat rt.err >&2
                exit 1
              }
              cmp allbytes rt.out || { echo "FAIL: Rust decode(Zig encode) != original" >&2; exit 1; }
              echo "Rust <-> Zig byte-identical across all 256 bytes"
            '';
            installPhase = ''
              cargo test --release --offline --no-run --message-format=json --manifest-path rust/Cargo.toml > native-test-artifacts.json
              node tests/integration/export-rust-tests.mjs native-test-artifacts.json rust-test-metadata.json "$out"
              cp -R packaged-test-artifacts "$out/packaged"
              mkdir -p "$out/bin"
              install -m755 rust/target/release/printable-binary-rs "$out/bin/printable-binary-rs"
              install -m755 rust/target/release/examples/textual "$out/libexec/textual-example"
              install -m755 ${self.checks.${system}.test-zig}/bin/printable-binary "$out/libexec/printable-binary-reference"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/unit/test-retained-rust-driver
              bash tests/cli/test-retained-rust "$out" rust-test-metadata.json packaged-test-metadata.json
            '';
          };

          # ~PB compile-time sigil (Elixir). Runs the crate's own unit + doctest
          # suite, then the MFIC cross-impl guard: the Zig CLI is the INDEPENDENT
          # encoder oracle (Elixir did not write it), so Elixir decode/1 must
          # reproduce the original bytes for all 256 single bytes AND an 8 KiB
          # seeded multi-byte stream (exercises 2/3-byte glyph boundaries).
          test-elixir = pkgs.stdenv.mkDerivation {
            name = "test-elixir";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ elixir luajit ];
            buildPhase = ''
              export HOME=$TMPDIR
              export MIX_HOME=$TMPDIR/mix
              export HEX_HOME=$TMPDIR/hex
              export ELIXIR_ERL_OPTIONS="+fnu"
              # A fixed private staging path keeps BEAM metadata reproducible.
              test ! -e elixir-compilation-source
              mkdir elixir-compilation-source
              cp -R elixir elixir-compilation-source/elixir
              cp character_map.txt elixir-compilation-source/character_map.txt
              cp tests/integration/elixir-prepared-runner.ex elixir-compilation-source/elixir/prepared_runner.ex
              staged_project="$PWD/elixir-compilation-source/elixir"
              (cd "$staged_project" && MIX_ENV=test mix compile --no-deps-check)
              app_ebin="$staged_project/_build/test/lib/printable_binary/ebin"
              elixir -pa "$app_ebin" tests/integration/prepare-elixir-tests.exs "$staged_project" "$PWD/elixir-test-beams"
              mkdir elixir-app-beams
              cp -R "$app_ebin/." elixir-app-beams/
              # Retire the staging tree before tests: no runtime source lookup.
              mv elixir-compilation-source "$TMPDIR/retired-elixir-compilation-source"
            '';
            installPhase = ''
              mkdir -p "$out/lib"
              cp -R elixir-app-beams "$out/lib/elixir-app"
              cp -R elixir-test-beams "$out/lib/elixir-tests"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/cli/test-elixir-prepared "$out" ${self.checks.${system}.test-zig}/bin/printable-binary
            '';
          };

          # Dogfood the C FFI boundary: build the C FFI CLI against the Zig static
          # lib and round-trip through it (encode/decode + hexlike).
          test-ffi-cli = pkgs.stdenv.mkDerivation {
            name = "test-ffi-cli";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ clang ];
            buildPhase = ''
              export HOME=$TMPDIR
              clang -O2 -I. -o pb-ffi src/printable_binary_ffi_main.c ${self.checks.${system}.test-zig}/lib/libprintable_binary.a
              LC_ALL=C awk 'BEGIN { for (i=0; i<4096; i++) printf "%c", i%256 }' > in.bin
              patchShebangs tests/fixtures/fault-ffi-stage
            '';
            doCheck = true;
            checkPhase = ''
              bash tests/unit/test-ffi-smoke-driver ./pb-ffi in.bin
            '';
            installPhase = ''
              mkdir -p $out/libexec
              cp pb-ffi $out/libexec/test-ffi-cli
              cp in.bin $out/libexec/ffi-smoke-input
              touch $out/passed
            '';
          };

          # Fixed-work ownership checks replace two serial wall-clock windows.
          # Zig's C ABI has allocator/failure controls in test-zig-unit; retain
          # tests/leak_test and leak_harness.c for extended RSS diagnostics.
          test-leak = pkgs.stdenv.mkDerivation {
            name = "test-leak";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ clang ];
            buildPhase = ''
              export HOME=$TMPDIR
              patchShebangs tests/fixtures/leak-target
              clang -O2 -Wall -Wextra -I. -o test-c-allocation-lifecycle tests/unit/test-c-allocation-lifecycle.c
            '';
            doCheck = true;
            checkPhase = ''
              bash tests/unit/test-leak-driver
              ./test-c-allocation-lifecycle
              for defect in retain-result skip-work; do
                if ./test-c-allocation-lifecycle --$defect > control.log 2>&1; then
                  echo "FAIL: allocation control accepted $defect" >&2
                  exit 1
                fi
                case "$defect" in
                  retain-result) grep -q 'retained requested bytes' control.log || { cat control.log >&2; exit 1; } ;;
                  skip-work) grep -q 'skipped allocating work' control.log || { cat control.log >&2; exit 1; } ;;
                esac
              done
              echo "PASS: deliberate C ownership leak and skipped-work controls rejected"
            '';
            installPhase = "mkdir -p $out/libexec && cp test-c-allocation-lifecycle $out/libexec/ && touch $out/passed";
          };

          # Guard against a stale generated C header: regenerating from
          # character_map.txt must reproduce the committed character_map_embedded.h.
          test-embedded-map-sync = pkgs.stdenv.mkDerivation {
            name = "test-embedded-map-sync";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ luajit ];
            buildPhase = ''
              cp character_map_embedded.h committed.h
              luajit utils/generate_embedded_map.lua
              if ! diff -q committed.h character_map_embedded.h; then
                echo "character_map_embedded.h is stale; run: luajit utils/generate_embedded_map.lua" >&2
                exit 1
              fi
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };
        } // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          # Roc's currently patched native platform is Linux-only.
          test-roc = pkgs.stdenvNoCC.mkDerivation {
            name = "test-roc";
            src = runtimeSource;
            strictDeps = true;
            nativeBuildInputs = with pkgs; [ hexdump jq luajit python3 xxd rocCompiler ];
            buildPhase = ''
              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$HOME/.cache"
              mkdir -p "$XDG_CACHE_HOME"
              bash tests/unit/test-roc-toolchain-pin
              test "$(roc version)" = "Roc compiler version ${rocCompiler.compilerVersion}"
              cp -R ${printableBinaryRocPlatform}/platform roc/platform
              roc test --jobs="$NIX_BUILD_CORES" roc/TestCodec.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestHexlike.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestMap.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestCrc.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestContainer.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestCliCore.roc
              roc test --jobs="$NIX_BUILD_CORES" roc/TestCliOutput.roc
              bash tests/test_roc_map_sync
              roc build --jobs="$NIX_BUILD_CORES" --no-cache --opt=speed roc/main.roc --output=printable-binary-roc
            '';
            installPhase = ''
              install -Dm755 printable-binary-roc "$out/bin/printable-binary-roc"
              install -Dm755 ${self.checks.${system}.test-zig}/bin/printable-binary "$out/libexec/printable-binary-reference"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/cli/test-roc-prepared "$out"
            '';
          };

          test-build-all = pkgs.stdenvNoCC.mkDerivation {
            name = "test-build-all";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ bash binutils jq file gawk gnumake git luajit python3 xxd hexdump ];
            buildPhase = ''
              patchShebangs tests/fixtures
              bash ./tests/test_build_all
              test -x ${printableBinaryApe}/bin/printable-binary-ape.com
              bash ./tests/integration/test-built-products ${allPackages.allImplementations} ${pkgs.linkFarm "printable-binary-zig-cross-products" (map (pf: {
                name = pf;
                path = buildProducts."build-zig-${pf}-ReleaseFast";
              }) [ "linux-amd64" "linux-arm64" "macos-arm64" "mswin-amd64" "mswin-arm64" ])} ${pkgs.linkFarm "printable-binary-canonical-products" (map (row: {
                name = row.implementation;
                path = canonicalPackage buildProducts."${row.package}-ReleaseFast" row;
              }) (builtins.filter (row: row.platform == platform) matrixRows))}
              bash ./tests/integration/test-built-profiles ${pkgs.linkFarm "printable-binary-host-profiles" (pkgs.lib.concatMap (profile: map (row: {
                name = "${profile}/${row.implementation}";
                path = buildProducts."${row.package}-${profile}";
              }) (builtins.filter (row: row.platform == platform) matrixRows)) [ "ReleaseSafe" "Debug" ])}
            '';
            installPhase = "mkdir -p $out && touch $out/passed";
          };

          # Architecture invariant: importing the `printable_binary` Zig module
          # must emit ZERO `pb_*` C symbols (the C ABI lives only in the FFI-root
          # static lib). Two static (musl) consumers of pb otherwise collide on
          # `duplicate symbol: pb_*` under ld.lld — this blocked difz. nm is an
          # independent oracle. Linux-only: this parser uses ELF symbol spelling,
          # not Mach-O's leading underscore. Static-musl downstream links exposed
          # this duplicate-symbol fault. See tests/test_module_no_ffi_symbols.
          test-no-ffi-symbols = pkgs.stdenv.mkDerivation {
            name = "test-no-ffi-symbols";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ zig binutils ];
            buildPhase = ''
              export HOME=$TMPDIR
              zig build consumer-lib -Doptimize=ReleaseFast
            '';
            installPhase = ''
              install -Dm644 zig-out/lib/libmodule_consumer.a "$out/lib/libmodule_consumer.a"
              install -Dm644 ${self.checks.${system}.test-zig}/lib/libprintable_binary.a "$out/lib/libprintable_binary.a"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/unit/test-module-symbols
              bash tests/unit/test-module-symbol-driver "$out/lib/libmodule_consumer.a" "$out/lib/libprintable_binary.a"
            '';
          };

          test-ape = pkgs.stdenvNoCC.mkDerivation {
            name = "test-ape";
            src = runtimeSource;
            nativeBuildInputs = with pkgs; [ cosmoccBin coreutils python3 xxd hexdump bash ];
            buildPhase = ''
              export PATH=${cosmoccBin}/bin:$PATH
              export HOME=$TMPDIR
              unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
              cosmocc -O3 -DNDEBUG -I. -o printable-binary-ape.com src/printable_binary.c
              # Host-native build tools must still produce a portable APE.
              test "$(head -c 2 printable-binary-ape.com)" = MZ
              chmod +x printable-binary-ape.com
            '';
            installPhase = ''
              install -Dm755 printable-binary-ape.com "$out/bin/printable-binary-ape.com"
              touch "$out/passed"
            '';
            doInstallCheck = true;
            installCheckPhase = ''
              bash tests/cli/test-prepared-native ape "$out"
            '';
          };
        };
      });
}
