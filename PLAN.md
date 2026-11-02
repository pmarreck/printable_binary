# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Evaluate a Latin-friendly high-byte alphabet retaining rough alphabetic progression, UTF-8 byte economy, and terminal readability; compatibility breaks are permitted, but select the replacement repertoire explicitly (context: docs/plan_context/current-work.md).
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

- [x] Check CI for the exact current pushed commit; Answer: remote yolo matches f4dcf9913d190ad6bf8dc95742ec1ce4dc7097a4 and all 28 targets passed in 72 seconds, finished 09:48 EST (done 2026-11-02 09:59 EST).
- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
		- [ ] Should Roc unit checks remain explicitly mixed compile/test timing, or should test-artifact export be a separate compiler task? Its pinned compiler caches verdicts and publishes no test executable; owner decision pending.
		- [ ] Integrate the remaining prepared runtime cases into one bounded concurrent complete runner through ./test, with compilation/setup/admission measured separately and no coverage omissions.
			- [ ] Reduce the measured build/product/profile and Zig unit/differential costs without removing cases or required safety checks; the diagnostic observed 19.84 and 6.12 seconds respectively (context: docs/plan_context/current-work.md).
				- [x] Measure checked backing for all 65,536 textual pairs with safety/traces/leak/failure checks retained; controlled old/new/new/old core runs pass at 4.79/0.73/0.73/4.71 seconds and complete gates pass (done 2026-11-02 10:09 EST; context: docs/plan_context/current-work.md).
				- [x] Verify clock diagnostics and a one-MiB smoke sample through complete gates; repeated 32-KiB CPU readings caused rejection, all 500 larger probes pass and nonpositive intervals remain errors (done 2026-11-02 10:09 EST; context: docs/plan_context/current-work.md).
				- [ ] Measure nested worker limits under the declared resource envelope; the checked-backing 26/26 run still takes 18.78 seconds under high shared-host load (context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
