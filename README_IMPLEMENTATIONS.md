# PrintableBinary implementations

All nine executable implementations use the same 256-byte mapping. Zig is the canonical CLI. Rust provides an embedded raw codec and a smaller stdin CLI; the other implementations provide the full CLI contract. See [README.md](README.md) for encoding options, containers, library APIs, and the byte/glyph reference.

## Build and select

Builders require Nix with flakes enabled. `flake.nix` and `flake.lock` pin dependencies; language compilers run inside derivations. `nix develop` supplies editing and diagnostic tools, rather than a separate supported build backend.

```bash
./build                       # Canonical implementation, current platform
./build --all-impls            # All declared implementations for this platform
./build --all-implementations  # Same scope, long alias
./build --all-plats            # Canonical implementation, every declared platform
./build --all                  # Every declared implementation/platform combination
./build --impl=c               # Build C privately without changing the canonical command
./build --platform=mswin-arm64 # Explicit cross target for the canonical implementation
./build --debug                # Debug profile
./build --test                 # ReleaseSafe profile
./run --help                   # Build the selected host product, then launch it
./test                        # Complete Nix check graph; failures accumulate
```

`build-all` is a one-way alias for `./build --all-impls`. Scope flags are independent, order-insensitive, and repeatable. `--all` covers the declared matrix, not an invented Cartesian product. An unavailable required builder fails the operation.

`CANONICAL_IMPL` contains one registered implementation identifier, initially `zig`. Change it without compiling or switching an installed command:

```bash
./build canonize c
./build
```

Canonization records intent. Only a subsequent successful build publishes the new canonical host command. `./build --impl=rust`, for example, builds Rust without changing that selection. Choosing Rust as canonical also chooses its narrower CLI surface.

Optimized `ReleaseFast` is the default; `--test` selects `ReleaseSafe`, and `--debug` selects `Debug`. No portable preset enables host-only CPU tuning. Make's supported public aliases delegate to these same commands. Its compiler recipes are implementation details of Nix packages. Retired manual optimization recipes remain recoverable in Git history; they are not qualified build presets.

## Platforms and products

Platform identifiers (`PF`) are `linux-amd64`, `linux-arm64`, `macos-arm64`, `mswin-amd64`, and `mswin-arm64`. Compiler triples and Nix system names keep their tool-specific spellings.

| Implementation ID | Declared targets | Optional ABI variant | Installed command |
| --- | --- | --- | --- |
| `zig` | All five PFs | Linux `musl`; Windows `gnu`; none on macOS | `printable-binary` (`.exe` on Windows) |
| `c` | Linux amd64/arm64, macOS arm64 | Linux `gnu` | `printable-binary-c` |
| `ffi` | Linux amd64/arm64, macOS arm64 | Linux `gnu` | `printable-binary-ffi` |
| `rust` | Linux amd64/arm64, macOS arm64 | Linux `gnu` | `printable-binary-rs` |
| `roc` | Linux amd64/arm64 | `musl` | `printable-binary-roc` |
| `luajit` | Linux amd64/arm64, macOS arm64 | None | `printable-binary-luajit` |
| `node` | Linux amd64/arm64, macOS arm64 | None | `printable-binary-node` |
| `ape` | All five PFs, built on Linux | None | `printable-binary-ape.com` |
| `wasm` | Linux amd64/arm64, macOS arm64 launchers | None | `printable-binary-wasm` |

The authoritative support declaration is [build-support/implementations](build-support/implementations). C, FFI, Rust, and runtime wrappers require their native Nix builder. APE requires a Linux Nix builder even when selected for macOS or Windows. Windows artifacts are cross-built through Nix on a supported host, WSL, or an appropriate remote builder.

Complete installation trees live under `<implementation>-out/<PF>/[<VARIANT>/]<profile>/`. Omit the variant directory when it does not apply. They retain libraries, headers, maps, runtime modules, and build metadata, rather than only a loose executable. Examples on Linux amd64:

```text
zig-out/linux-amd64/musl/ReleaseFast/bin/printable-binary
c-out/linux-amd64/gnu/ReleaseFast/bin/printable-binary-c
ffi-out/linux-amd64/gnu/ReleaseFast/lib/libprintable_binary.a
ape-out/linux-amd64/ReleaseFast/bin/printable-binary-ape.com
wasm-out/linux-amd64/ReleaseFast/bin/printable-binary-wasm
```

Only the canonical host command is published in `bin/<PF>/`. Unix publication uses a direct relative symlink to a verified retained product; standalone Windows publication uses a copy and an ownership record, without requiring symlink privileges. Noncanonical products and foreign targets coexist without switching the host command. `.nix-out/` retains per-generation Nix output roots for rollback. Never compile through an installation link into the immutable store.

Builds serialize publication, verify metadata and executable headers before selecting products, and cancel publication if `CANONICAL_IMPL` changes during compilation. Build or verification failure leaves the previous canonical command selected. Broad `make clean`/`distclean` operations are refused to protect source scripts, mappings, and retained products.

For shell setup, put only the current `bin/<PF>/` before portable generic `bin/`. Do not recursively admit foreign products, `result/bin`, or `zig-out/bin`. The build does not edit global PATH. Until shell configuration is qualified, use the explicit PF path or `./run`. A new PATH selection may require shell refresh or rehash.

## Nix packages

```bash
nix build .                              # Canonical product
nix run . -- --help                       # Canonical command
nix build .#allImplementations            # Host products, grouped by implementation
nix build .#build-rust-linux-amd64-ReleaseFast
nix build .#build-zig-mswin-arm64-ReleaseSafe
```

`default` follows `CANONICAL_IMPL` and always exposes `bin/printable-binary`. Implementation packages retain their distinct command names. The selector and specifically listed non-runtime workflow files do not enter compiler source closures. Canonization and plan updates therefore avoid unrelated recompilation. Runtime checks separately exclude seven exact workflow/documentation paths, but retain selectors, entrypoints, Nix inputs, fixtures and future files; the documentation check keeps the full source. Path-set and source-hash regressions verify both filters. A cached check remains evidence of its earlier execution, not a fresh runtime measurement. Existing `printableBinaryZig`, `printableBinaryNative`, `printableBinaryRoc`, `printableBinaryApe`, and `printableBinaryWasm` attributes select host ReleaseFast products where declared.

## Implementation details

### Zig Implementation

The canonical full CLI uses the Zig library directly. The installed product includes the CLI, C-compatible library, and headers. Its core uses contiguous mapping storage, literal-prefix SIMD checks, and direct UTF-8 decode tables. Cross-compilation is declared for all five PFs.

The Zig library also exposes `textual.encode`/`decode`, explicitly untagged
`textual.encodePayload`/`decodePayload`, and tagged-or-legacy `decodeAuto` with
the same canonical textual v1 format as Rust. A separate test adapter compares
both libraries against the pinned Unicode oracle over every scalar. Allocation
failure controls cover the Zig textual ownership path. The CLI exposes explicit
`--textual`, `--untagged`, `--raw-input` and `--decode-auto` selection; plain
encoding/`-d` and the C ABI remain bytewise. Tagged-output ingress guards do not
apply to raw library calls. Mixing textual with formatting/container/preservation
features is rejected rather than weakening canonicality.

### C Implementation

The standalone C CLI provides the full file, formatting, mapping, passthrough, and container interface. It has its own `c-out/` products. The `ffi` implementation instead exercises the Zig core through its public C ABI and retains the library and headers alongside the C CLI.

### Cosmopolitan APE

APE means Actually Portable Executable. It shares C source with the standalone C implementation but has a separate implementation identifier, package, tests, and `ape-out/` tree. Cosmopolitan supplies the portable runtime; the distributed fat executable retains its architecture slices. Linux build-tool helpers are converted to host-native ELF so their execution does not depend on the host's MZ handler. That conversion does not apply to the distributed application.

### WebAssembly Implementation

Emscripten compiles the full C CLI to `wasm32-unknown-emscripten`; the resulting standalone module runs through wazero's WASI interface. The Nix product includes `printable-binary.wasm` and a pinned `printable-binary-wasm` launcher. The launcher inherits environment variables; a direct `wazero run` invocation must pass them explicitly with `--env` or `--env-inherit`.

The packaged launcher leaves the host filesystem unmounted. Use stdin/stdout by default; direct file access requires an explicit WASI mount when invoking the runtime. Sharing the C option parser does not grant the module host filesystem access.

### Roc Implementation

Roc supplies pure raw and hexlike codecs, UTF-8 glyph-aware formatting, a container codec, argument parser, and output renderer. Its bundled Zig platform handles raw-byte I/O, files, clocks, and environment access. Linux is the required execution environment; no successful macOS runtime verification is claimed. Compiler and platform changes must pass Roc module tests plus the complete shared CLI inventory, container, map synchronization, and independent hexlike/formatting differential checks.

The compiler comes from the official Roc nightly overlay, with an immutable official source pin for glue generation. Nix asserts that the source commit matches the selected compiler. `./check-sources` separately probes the pinned GitHub archive URLs over the network, bypassing the local Nix source cache. It is an explicit online diagnostic; deterministic source-checker regressions remain part of `./test`. Archive reachability does not verify release assets or foreign runtime behavior.

### Rust Implementation

The self-contained Rust crate provides `encode`, `decode`, `encode_into`, and `decode_into`, with caller-owned buffer reuse. Their `_with_options` variants accept `EncodeOptions { spaces }` and `DecodeOptions { spaces, strip_whitespace }`; the original functions keep their raw defaults. Whitespace stripping ignores literal ASCII space, TAB, CR, and LF, except that spaces mode retains literal spaces. Encoded data glyphs still decode normally.

Its stdin CLI supports `-d`/`--decode`, `-s`/`--spaces`, and `--strip-whitespace`. File arguments, formatting, mapping reports, runtime map overrides, and containers belong to the full CLIs. The build script generates tables from a crate-local mapping copy, never a repository-parent file. The complete suite compares that copy with the canonical map and builds/tests the extracted Cargo package offline.

The Rust library additionally exposes `textual::encode`/`textual::decode` for
tagged Unicode-preserving values, `textual::encode_payload`/`decode_payload` for
explicit untagged payloads, and `decode_auto`/`decode_auto_with_options` for
tagged-or-legacy log reading. This mode accepts arbitrary bytes, keeps ordinary
spaces and ZWJ/ZWNJ, quotes literal reserved glyphs with U+F000, and rejects
noncanonical payload spellings. Its Unicode 16.0 policy data is inside the crate;
neither compilation nor packaged use depends on a sibling checkout or Node.
The complete Rust check independently compares every Unicode scalar with the
pinned Node oracle and verifies arbitrary-byte and canonicality cases. This does
not change the raw stdin CLI or claim mixed-region/streaming support.

The `test-rust` Nix result retains native unit/integration test executables,
the raw CLI, the textual example adapter and an independent Zig reference.
Its source-local paths are removed from the retained target inventory. An
installed-artifact check compares every native target with Cargo metadata,
rejects missing/duplicate targets, and executes the retained tests after fixup.
The isolated packaged crate has its own `packaged/` test bundle and path-free
Cargo inventory, built from the extracted archive. Those tests run again after
the temporary crate/build tree is gone. A shared exporter validates target
completeness and safe names before writing; its controls cover ignored build
messages, omissions, duplication, empty inventories and unsafe names.
Existing package, native, documentation and CLI checks remain in the complete
test entry point. Retention enables fresh runtime measurement; it does not by
itself establish the complete-suite execution budget.

### LuaJIT and JavaScript / Node

LuaJIT remains explicitly named `printable-binary-luajit`. It is useful as a modifiable reference, but its string allocation limits differ from Zig's native buffers. The current Zig CLI still buffers the complete input and result; streaming standard-handle I/O does not imply bounded-memory conversion. The JavaScript module powers the browser UI and Node CLI. Their source-distributed scripts remain in generic `bin/`; Nix products pin the interpreters and required resources.

## CLI behavior

Full CLIs support files/stdin, formatting, preservation modes, mapping reports, passthrough, byte ranges, hexlike encoding, and `.pbf.json` containers. See `--help` and [the main usage reference](README.md#usage) for exact arguments. Data goes to stdout; diagnostics and input-throughput statistics go to stderr.

`--about` prints one line with version, implementation, description, `PF=<OS>-<ARCH>`, and an optional `VARIANT=gnu` or `VARIANT=musl`. Native executables report their compilation target. Node and LuaJIT report their runtime platform. APE and the WASM launcher report execution PF plus `target=cosmopolitan` or `target=wasm32-unknown-emscripten`; OS/ARCH/PF environment overrides do not select those fields. A directly invoked WASM module knows its compiler target, but needs its host launcher to supply execution PF.

```text
Input throughput: 4999.36 MB read in 49.939 s (100.11 MB/s)
```

MB means decimal input megabytes (1,000,000 bytes), with two decimal places. The rate covers input read, codec work, and output write. It measures bytes read, including the larger encoded input during decoding. Set `PRINTABLE_BINARY_MUTE_STATS=1` to suppress it.

Full CLIs accept `PRINTABLE_BINARY_MAP` for a 256-glyph override. Mapping reports reflect the active map. Rust's tables are compiled in and do not use that runtime override. The raw mapping and optional whitespace-preservation modes remain distinct contracts; compare like modes.

## Tests and performance

`./test` is the complete entrypoint. It reaches every required Nix check, including module tests, shared CLI/container tests, map synchronization, differential checks, build/publication regressions, and bounded existing resource checks. Publication tests use disposable projects and exact prepared products, never a stale PATH executable.

The shared CLI contract runs eight independent groups with private temporary trees and stable output order. Its worker limit defaults to the Nix core budget, capped at eight. Direct, isolated prepared-suite invocations accept `PB_TEST_JOBS=1` for serial diagnosis; pure Nix checks do not inherit that caller override. Every case remains required. An ordered inventory captured before parallelization rejects missing, duplicate, or reordered case results. Compilation, cached verdicts, and fresh test execution are separate evidence; a fast cached `./test` does not establish fresh runtime.

The `test-c`, `test-zig` and separate `test-ape` Nix results retain the exact
executables used by their contracts. `tests/cli/test-prepared-native` re-executes
those same checks after installation, including the C two-byte domain test,
malformed-byte regressions and Zig's textual CLI cases. For isolated, fresh
prepared execution, `nix develop .#tests` supplies the declared runtime tools,
including Python, Node and binary-inspection tools; language builds stay in Nix
derivations. The complete suite remains
`./test`; this native trio is only a subset.

Layout, container and differential checks consume the exact retained native
artifacts through declared Nix dependencies. The Zig result also retains its
static FFI archive; the FFI check links its C adapter once with the existing
`-O2` flags. The C CLI remains `-O3`, and the shared Zig CLI/library remains
ReleaseFast for the native check target. A dependency-context regression checks
these producer references and the absence of repeated Zig compiler inputs in
consumers. Required assertions, safety-enabled unit tests and portable-runtime
checks remain in the complete gate.

The Linux module-symbol check retains its consumer and FFI archives and analyzes
them without compiling again. It requires the consumer fixture's own export,
rejects symbol-tool failures and any diagnostics, and checks the C-ABI namespace
separation. Pure classifier tests cover included/excluded ELF symbol-type sets;
real archive corruption, missing work and controlled tool faults must fail.

Linux verification has exercised all nine installed host codecs in both mapping directions against the canonical table. Zig has also compiled all five targets with verified ELF, Mach-O, and PE headers. That is cross-build evidence; macOS, Windows, and Linux arm64 execution remain separate verification requirements.

The comparative runner covers Roc, Rust, WebAssembly, and APE as well as C, Zig, LuaJIT, and Node. It verifies round trips before timing, uses deterministic workloads, and includes runtime startup in end-to-end results. APE uses a clean-environment adapter; Rust uses stdin; WASM includes wazero. Historical timings do not establish current performance on another machine.

```bash
./build --all-impls
nix develop -c ./benchmarks/benchmark-zig-opt --list-impls
nix develop -c ./benchmarks/benchmark-zig-opt --impls roc,rust,wasm,ape --sizes "10M"
```

`./bm` runs the separate tag-recognition experiment through a pinned shared
profiling engine. Set `PERFORMANCE_HISTORY_URL` to an existing writable
`file:///absolute/directory` outside this repository, or pass `--history-url`.
For example, `./bm --case alphabet-cpu-1 --history-url file:///path/to/history`.
The default configuration names `/var/lib/performance-profiling`; the command
does not create or change permissions on that directory.

The experiment compares the raw Zig decoder with a benchmark-only copy that
checks the seven-byte tag namespace on lookup misses. It verifies output against
canonical-map fixtures after each sample and records both decoders' process CPU
and monotonic wall samples. Each workload has one-core and twelve-core cases;
the decoder itself remains single-threaded. Whole patterns fill approximately
16 MiB of encoded input, with exact input and decoded byte counts recorded.
Fixture construction, warmup, verification, and freeing output are excluded from
the timed decoder call; allocation and shrinking its owned result are included.

This measures namespace observation, not a complete framing parser or whole-CLI
throughput. Historical records live outside the checkout. A new cohort reports
`UNBASELINED` (exit 3), rather than approving its own baseline. Deterministic
fixture, oracle, and adapter checks are part of `./test`; fresh host measurements
run separately through `./bm`, outside cached Nix checks. The two older C/Lua
comparison scripts and historical result directories remain under `benchmarks/`.

The benchmark resolves and verifies exact host ReleaseFast products from this layout; it never falls back to generic binaries, Cargo caches, or `result/bin`. Inspect `--list-impls` before measuring. In-process codec microbenchmarks exclude startup and I/O and must not be compared directly with these end-to-end results. New performance gates and baseline changes follow the shared performance-profiling contract.
