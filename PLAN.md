# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Codec and Rust consumer requests

- [x] Spell both tag headers with explicit U+F000 and UTF-8 bytes in the README/codec contract; a regression failed before the tables and the complete local gate now passes (done 2026-11-02 03:07 EST).

## Optional stream tagging

- [ ] Evaluate a Latin-friendly high-byte alphabet retaining rough alphabetic progression, UTF-8 byte economy, and terminal readability; compatibility breaks are permitted, but select the replacement repertoire explicitly (context: docs/plan_context/current-work.md).
	- [x] Evaluate a 128-symbol mathematical-letter candidate: sampled Latin shrinks 1.415×→1.000× but random textual grows 1.781×→2.628×; twelve low-byte Latin glyphs remain reserved and no palette is adopted (done 2026-11-02 03:01 EST; context: docs/plan_context/current-work.md).
	- [ ] Await font-distinction feedback on `𝐚 𝒂 𝖺 𝗮 𝚊`, then select or reject a concrete versioned textual repertoire without changing existing bytewise/v1 data interpretation.
- [ ] Specify optional `ρΒ_`/`ρΒ1_` v1 tagging with reserved-prefix errors, standard martini quoting, a leading-tag encoder guard/raw-input override, and single-pass excerpts before implementation (context: docs/plan_context/current-work.md).
	- [ ] Should mixed-excerpt decoding reject openers inside an active frame and closers outside any frame, or allow implicit switches/literal stray closers? Owner decision pending; EOF still permits an omitted final closer.
	- [ ] Reconcile textual payload quoting with single-pass mixed-region framing and test parser transitions before adding excerpt decoding.

## Deferred features

- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
		- [x] Retain compiled Elixir app/test modules and run all seven ExUnit/doctest cases plus two seeded Zig differentials without project compilation; full gate/all-system evaluation pass and fresh execution takes 0.36–0.42 seconds (done 2026-11-02 05:39 EST; context: docs/plan_context/current-work.md).
		- [ ] Should Roc unit checks remain explicitly mixed compile/test timing, or should test-artifact export be a separate compiler task? Its pinned compiler caches verdicts and publishes no test executable; owner decision pending.
		- [x] Retain the exact Roc CLI/reference and re-execute all CLI/container/parity/muting contracts independently of all 61 required compiler-driven unit cases; fresh CLI execution takes 1.16–2.05 seconds (done 2026-11-02 05:44 EST; context: docs/plan_context/current-work.md).
		- [ ] Integrate the remaining prepared runtime cases into one bounded concurrent complete runner through ./test, with compilation/setup/admission measured separately and no coverage omissions.
		- [x] Reuse exact declared C/Zig/FFI artifacts across layout, container and differential checks; dependency-context regression, full Linux gate and all-three-system evaluation pass (done 2026-11-02 04:40 EST; context: docs/plan_context/current-work.md).
		- [x] Retain module/FFI archives and reject malformed inputs, missing fixture work and tool faults; full Linux gate/all-system evaluation pass and fresh verification takes 0.69–0.80 seconds (done 2026-11-02 05:10 EST; context: docs/plan_context/current-work.md).
		- [x] Retain both Rust test bundles with original Cargo metadata, exporter/runner defect controls and full-gate verification; fresh native/control execution takes 0.87–0.88 seconds (done 2026-11-02 04:26 EST; context: docs/plan_context/current-work.md).
		- [x] Retain exact C, Zig and separate APE CLI/domain-test artifacts; unchanged contracts pass after installation and fresh concurrent execution takes 1.66 seconds; complete gate passes (done 2026-11-02 03:53 EST; context: docs/plan_context/current-work.md).
		- [x] Preserve runtime check derivations across known metadata-only edits while retaining full documentation checks and all executable inputs; classifier/identity regressions and complete gate pass (done 2026-11-02 03:41 EST; context: docs/plan_context/current-work.md).
		- [x] Retain all five native Rust test targets and CLI/reference artifacts with independent target inventories; full gate passes and fresh native execution takes 0.16–0.17 seconds (done 2026-11-02 03:35 EST; context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
