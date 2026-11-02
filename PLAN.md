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

- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
		- [ ] Should Roc unit checks remain explicitly mixed compile/test timing, or should test-artifact export be a separate compiler task? Its pinned compiler caches verdicts and publishes no test executable; owner decision pending.
		- [ ] Integrate the remaining prepared runtime cases into one bounded concurrent complete runner through ./test, with compilation/setup/admission measured separately and no coverage omissions.
			- [ ] Reduce the measured build/product/profile and Zig unit/differential costs without removing cases or required safety checks; the diagnostic observed 19.84 and 6.12 seconds respectively (context: docs/plan_context/current-work.md).
				- [x] Verify fork-free fixtures and first-wave control scheduling through complete gates and 26/26 fresh execution at 6.45 seconds, still over budget (done 2026-11-02 10:34 EST; context: docs/plan_context/current-work.md).
				- [x] Parallelize all six runner-control suites with private state, an independent exact-argv/duplicate/failure driver and full-gate verification; five continuation controls failed before dispatch changed (done 2026-11-02 10:34 EST; context: docs/plan_context/current-work.md).
				- [x] Replace 512 all-byte fixture forks per shared CLI run with a one-process generator checked against literal hex; complete original CLI inventories and full gate pass (done 2026-11-02 10:34 EST; context: docs/plan_context/current-work.md).
				- [ ] Reduce remaining controller scope-test dummy artifact overhead while retaining all actual publication/header/installed-product tests; fresh build group still takes 6.47 seconds (context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
