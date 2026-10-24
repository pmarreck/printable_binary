# Public commands delegate to Nix; build-* and c-cli are derivation internals.
.DEFAULT_GOAL := all
PROFILE ?= ReleaseFast
PREFIX ?=
CORE_PREFIX ?=
CC ?= clang
ZIG ?= zig
EMCC ?= emcc
APE_CC ?= cosmocc
TARGET_FLAGS ?=
ZIG_TARGET ?=
CFLAGS = -std=c99 -Wall -Wextra -I. -Isrc
PROFILE_FLAGS_ReleaseFast = -O3 -DNDEBUG
PROFILE_FLAGS_ReleaseSafe = -O2
PROFILE_FLAGS_Debug = -O0 -g -DDEBUG
PROFILE_FLAGS = $(PROFILE_FLAGS_$(PROFILE))
EM_FLAGS = -s STANDALONE_WASM=1 -s FILESYSTEM=1 -s INITIAL_MEMORY=134217728

.PHONY: all release debug zig-cli zig-lib ffi-cli ape wasm windows
all release:
	./build --profile=$(PROFILE)
debug:
	./build --debug
zig-cli zig-lib:
	./build --impl=zig --profile=$(PROFILE)
ffi-cli:
	./build --impl=ffi --profile=$(PROFILE)
ape wasm:
	./build --impl=$@ --profile=$(PROFILE)
windows:
	./build --impl=zig --platform=mswin-amd64 --profile=$(PROFILE)

.PHONY: test test-ape test-ffi test-zig
test test-ape test-ffi test-zig:
	./test

# Nix supplies fresh installation/scratch prefixes and pinned compiler tools.
# These leaves never invoke ./build or recursively enter Nix.
.PHONY: prepare-prefix c-cli build-ffi build-ape build-wasm
prepare-prefix:
	@test -n "$(PROFILE_FLAGS)" || { printf 'Unknown build profile: %s\n' "$(PROFILE)" >&2; exit 2; }
	@test -n "$(PREFIX)" || { printf 'Nix must supply a fresh PREFIX\n' >&2; exit 2; }
	@test ! -L "$(PREFIX)" || { printf 'Refusing to build through a product symlink; choose a fresh PREFIX\n' >&2; exit 2; }
	mkdir -p "$(PREFIX)/bin"
c-cli: prepare-prefix
	$(CC) $(CFLAGS) $(PROFILE_FLAGS) $(TARGET_FLAGS) $(LDFLAGS) -o "$(PREFIX)/bin/printable-binary-c" src/printable_binary.c
	cp character_map.txt "$(PREFIX)/bin/character_map.txt"
build-ffi: prepare-prefix
	@test -n "$(CORE_PREFIX)" -a -n "$(ZIG_TARGET)" || { printf 'Nix must supply CORE_PREFIX and ZIG_TARGET\n' >&2; exit 2; }
	$(ZIG) build -Dtarget=$(ZIG_TARGET) -Dcpu=baseline -Doptimize=$(PROFILE) --prefix "$(CORE_PREFIX)"
	$(CC) $(CFLAGS) $(PROFILE_FLAGS) $(TARGET_FLAGS) $(LDFLAGS) -o "$(PREFIX)/bin/printable-binary-ffi" src/printable_binary_ffi_main.c "$(CORE_PREFIX)/lib/libprintable_binary.a"
	cp -R "$(CORE_PREFIX)/lib" "$(CORE_PREFIX)/include" "$(PREFIX)/"
build-ape: prepare-prefix
	$(APE_CC) $(CFLAGS) $(PROFILE_FLAGS) -o "$(PREFIX)/bin/printable-binary-ape.com" src/printable_binary.c
build-wasm: prepare-prefix
	$(EMCC) $(CFLAGS) $(PROFILE_FLAGS) $(EM_FLAGS) -DPRINTABLE_BINARY_HELP_NAME=\"printable-binary\" -o "$(PREFIX)/bin/printable-binary.wasm" src/printable_binary.c

.PHONY: clean distclean
clean distclean:
	@printf 'Cleanup refused: select generated artifacts explicitly and remove them recoverably; source scripts and mappings are never cleanup targets.\n' >&2
	@exit 2

.PHONY: size gcc clang analyze profile asan msan memcheck emit-ir ape-ffi pgo-instrument pgo-train pgo-build pgo-ffi test-pgo test-validate benchmark compare hyperfine install uninstall cosmocc
size gcc clang analyze profile asan msan memcheck emit-ir ape-ffi pgo-instrument pgo-train pgo-build pgo-ffi test-pgo test-validate benchmark compare hyperfine install uninstall cosmocc:
	@printf 'Retired manual target: %s. Use ./build and ./test; diagnostic experiments require explicit Nix outputs before qualification. Historical recipes remain in Git history.\n' '$@' >&2
	@exit 2

.PHONY: help
help:
	@printf '%s\n' \
		'Builds require Nix. ./build is the primary interface.' \
		'make [release|debug]         Canonical host implementation' \
		'make zig-cli|ffi-cli|ape|wasm Select a host implementation' \
		'make windows                Cross-build Zig for mswin-amd64' \
		'make test                   Complete suite through ./test' \
		'make clean|distclean        Refused; preserve sources and retained generations'
