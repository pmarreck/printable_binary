# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Cross-platform build architecture

- [x] Keep APE as its own implementation and output tree, separate from standalone C even where sources are shared (done 2026-10-23 20:49 EDT).
- [x] Record the implementation/target matrix and add tested canonical selection and scope resolution, with Zig selected initially (done 2026-10-23 20:49 EDT; context: docs/plan_context/current-work.md).
- [x] Migrate build publication to verified PF/variant/profile product trees with retained Nix roots, serialized publication, and failure retention (done 2026-10-23 20:49 EDT).
- [x] Consolidate build-all, run, native builders, Nix packages, documentation, and exact-product tests behind the Nix-only build contract (done 2026-10-23 20:49 EDT).
- [x] Replace broad Make cleanup that can delete source scripts and the canonical mapping with a tested non-destructive interface (done 2026-10-23 20:49 EDT).
- [ ] Derive each CLI's one-line --about PF and optional VARIANT from its actual target and test conflicting runtime environment values.
- [ ] Keep shared CLI suite output clean, remove binary-unsafe shebang probing, and replace its legacy errexit control with explicit assertions.
- [ ] Verify a real canonical host build and publication; retain explicit gaps for foreign runtime verification and coordinate any global PATH cutover separately.
- [ ] Coordinate verified native-PF PATH selection with the shell-configuration agent, then move recognized legacy compiled generic-bin products recoverably.

## Build portability

- [ ] Replace the experimental Roc compiler fork with a tested official flake and matching glue source, building and testing for the host platform.
- [ ] Add a source-availability check that cannot pass solely because a pinned GitHub revision is already cached locally.

## Rust crate consumer requests

- [ ] Make the Rust crate self-contained at build/package time and test its generated mapping against the canonical map (context: docs/plan_context/current-work.md).
- [ ] Add Rust encode/decode spaces-preserving options with shared mapping regressions and report the usable revision to the requesting consumer (context: docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Specify optional `ρΒ1_` tagging, single-pass excerpt framing, martini escaping, and encoded-tag detection before implementation (context: docs/plan_context/current-work.md).
- [ ] Measure optimized tag-recognition overhead and compare marker spellings before finalizing framed decoding (context: docs/plan_context/current-work.md).
- [ ] Preserve alphabet-only recognition of raw PB, including byte-encoded literal UTF-8, without introducing new raw escape characters (context: docs/plan_context/current-work.md).

## Deferred features

- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Finish authorized remaining work, resolve explicitly held or underspecified items, run the complete gates to green, then push and verify the exact commit in CI.

## Recent completions

- [x] Restore the executable root test entrypoint and migrate existing suites and callers under tests, with all 24 Linux checks passing (done 2026-10-23 19:00 EDT; commit 409e974).
- [x] Make Linux cosmocc build helpers host-native while preserving portable APE application output; pass all Linux Nix checks and build the canonical Zig package (done 2026-10-23 18:35 EDT; commit ce9ccf8).
- [x] Add the full Roc CLI and shared unit, CLI, container, and differential tests (done 2026-10-11 23:09 EDT; commit 8942124).
- [x] Restore the public Roc input and correct Linux-only flake output declarations (done 2026-10-12 14:23 EDT; commit cdefa95).
