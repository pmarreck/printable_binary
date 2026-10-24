# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Cross-platform build architecture

- [x] Verify advertised Debug and ReleaseSafe host products and test the required Debug stderr banner (done 2026-10-24 00:09 EDT).
	- [x] Bundle the Zig compiler runtime in the C-linkable library so safety-enabled FFI products link without disabling stack probes (done 2026-10-24 00:09 EDT).
	- [x] Preserve Debug banners, passthrough data, and inherited stdin/stdout positions by using streaming Zig standard-handle adapters (done 2026-10-24 00:09 EDT).
- [x] Keep shared CLI suite output clean, remove binary-unsafe shebang probing, and replace its legacy errexit control with explicit assertions (done 2026-10-23 22:10 EDT).
- [x] Verify a real canonical host build and publication; retain explicit gaps for foreign runtime verification and coordinate any global PATH cutover separately (done 2026-10-23 22:10 EDT).
- [ ] Coordinate verified native-PF PATH selection with the shell-configuration agent, then move recognized legacy compiled generic-bin products recoverably.

## Build portability

- [x] Replace the experimental Roc compiler fork with a tested official flake and matching glue source, building and testing for the host platform (done 2026-10-24 00:09 EDT).
- [x] Add a source-availability check that cannot pass solely because a pinned GitHub revision is already cached locally (done 2026-10-24 00:09 EDT).

## Codec and Rust consumer requests

- [x] Prevent malformed UTF-8 aliases in Zig's compact two-/three-byte lookups; exhaust both lookup domains and retain real CLI regressions (done 2026-10-24 00:09 EDT).
- [x] Fix the reproduced Rust decoder aliasing of malformed and truncated UTF-8; exhaust all two-byte inputs against exact canonical glyph matches (done 2026-10-24 00:09 EDT).
- [x] Make the Rust crate self-contained at build/package time and test its generated mapping against the canonical map (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).
- [x] Add Rust encode/decode spaces-preserving options with shared mapping regressions (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Specify optional `ρΒ_`/`ρΒ1_` v1 tagging with reserved-prefix errors, standard martini quoting, a leading-tag encoder guard/raw-input override, and single-pass excerpts before implementation (context: docs/plan_context/current-work.md).
- [ ] Measure optimized tag-recognition overhead for the accepted martini-prefixed spelling before finalizing framed decoding (context: docs/plan_context/current-work.md).
	- [ ] Add a shared-engine executable bm frontend and retain the existing CLI-comparison tools and all-nine implementation inventory recoverably.
- [x] Preserve alphabet-only recognition of raw PB, including byte-encoded literal UTF-8, without introducing new raw escape characters (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).

## Deferred features

- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Audit the exact-commit CI target manifest against the complete required check set, including the Rust toolchain pin check.
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
- [ ] Report the published self-contained Rust crate revision and spaces-option API to the requesting consumer after push verification.
