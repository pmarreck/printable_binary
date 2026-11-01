# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Cross-platform build architecture

- [x] Coordinate verified native-PF PATH selection and retire recognized generic-bin products with checksum-verified recoverable backups (done 2026-11-01 11:28 EST; context: docs/plan_context/current-work.md).

## Build portability

- [x] Add a source-availability check that cannot pass solely because a pinned GitHub revision is already cached locally (done 2026-10-24 00:09 EDT).

## Codec and Rust consumer requests

- [x] Reject malformed two-byte lookup aliases in the shared C/APE/WASM decoder and retain exact-product regressions (done 2026-10-24 01:00 EDT).
- [x] Prevent malformed UTF-8 aliases in Zig's compact two-/three-byte lookups; exhaust both lookup domains and retain real CLI regressions (done 2026-10-24 00:09 EDT).
- [x] Fix the reproduced Rust decoder aliasing of malformed and truncated UTF-8; exhaust all two-byte inputs against exact canonical glyph matches (done 2026-10-24 00:09 EDT).
- [x] Make the Rust crate self-contained at build/package time and test its generated mapping against the canonical map (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).
- [x] Add Rust encode/decode spaces-preserving options with shared mapping regressions (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Design CJK UTF-8 passthrough for readable logs; discuss PB-glyph collisions before extending passthrough to non-CJK scripts.
- [ ] Specify optional `ρΒ_`/`ρΒ1_` v1 tagging with reserved-prefix errors, standard martini quoting, a leading-tag encoder guard/raw-input override, and single-pass excerpts before implementation (context: docs/plan_context/current-work.md).
- [x] Measure optimized tag-recognition overhead for the accepted martini-prefixed spelling before finalizing framed decoding (done 2026-10-24 01:13 EDT; context: docs/plan_context/current-work.md).
	- [x] Add a shared-engine executable bm frontend and retain the existing CLI-comparison tools and all-nine implementation inventory recoverably (done 2026-10-24 00:56 EDT).
- [x] Preserve alphabet-only recognition of raw PB, including byte-encoded literal UTF-8, without introducing new raw escape characters (done 2026-10-24 00:09 EDT; context: docs/plan_context/current-work.md).

## Deferred features

- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Commit all reviewed outstanding work, push yolo, and verify the exact pushed commit in Mechatron Prime CI.
- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
- [x] Audit the exact-commit CI target manifest against the complete required check set, including the Rust toolchain pin check (done 2026-10-24 01:00 EDT).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
- [ ] Report the published self-contained Rust crate revision and spaces-option API to the requesting consumer after push verification.
