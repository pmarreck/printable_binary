# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Malformed-input parity

- [ ] Add shared malformed-byte regressions and deterministic seeded coverage to the complete suite, then align implementations with automatic byte-preserving fallback and separate canonical validation (implementation authorized 2026-11-06; context: docs/plan_context/current-work.md).
	- [x] How should recovered input errors be counted and returned? Answer: Count invalid-input events and invalid input bytes separately; a multi-byte error counts as one event, and CLI status saturates the event count at 255 while library/diagnostic totals remain exact (decided 2026-11-06 13:03 EST; context: docs/plan_context/current-work.md).
	- [x] Should diagnostics include input and output offsets? Answer: Yes, include both as zero-based byte offsets at the start of each event, with input measured in the original encoded stream and output in the decoded stream (decided 2026-11-06 15:33 EST; context: docs/plan_context/current-work.md).
	- [x] Establish failing library/CLI regressions for contiguous events, dual spans, exact counts/hex, NDJSON purity, sink failure and saturated exit status; missing APIs/flags and false-success I/O witnesses reproduced before fixes (done 2026-11-06 16:53 EST; context: docs/plan_context/current-work.md).
	- [x] Add Rust recovery/report APIs and structured CLI plus Zig core recovery, preserving strict validators; failing API/CLI controls and the complete local suite pass (done 2026-11-06 15:57 EST; context: docs/plan_context/current-work.md).
	- [x] Implement Rust and Zig recovery/report APIs and CLI adapters while retaining strict canonical validators and tag guards; complete local suite passes, including seeded mutation oracles and allocation/sink failures (done 2026-11-06 16:15 EST; context: docs/plan_context/current-work.md).
	- [x] Requalify cross-language recovery after fixing Node diagnostic backpressure; the complete gate passes with the paused-reader regression and all surface/profile checks (done 2026-11-06 17:05 EST; context: docs/plan_context/current-work.md).
	- [ ] Add bounded seeded coverage, document the APIs/flags, run the complete checks, then push and verify the exact commit in CI.

## Repository CI

- [ ] Deliver the pending acknowledgment for the disabled legacy GitHub CI workflow when the requesting coordinator's durable-message route is reachable; the workflow file and Pages remain unchanged (context: docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Evaluate a Latin-friendly high-byte alphabet retaining rough alphabetic progression, UTF-8 byte economy, and terminal readability; compatibility breaks are permitted, but select the replacement repertoire explicitly (context: docs/plan_context/current-work.md).
	- [ ] Await font-distinction feedback on `𝐚 𝒂 𝖺 𝗮 𝚊`, then select or reject a concrete versioned textual repertoire without changing existing bytewise/v1 data interpretation.
- [ ] Specify optional `ρΒ_`/`ρΒ1_` v1 tagging with reserved-prefix errors, standard martini quoting, a leading-tag encoder guard/raw-input override, and single-pass excerpts before implementation (context: docs/plan_context/current-work.md).
	- [ ] Should mixed-excerpt decoding reject openers inside an active frame and closers outside any frame, or allow implicit switches/literal stray closers? Owner decision pending; EOF still permits an omitted final closer.
	- [ ] Reconcile textual payload quoting with single-pass mixed-region framing and test parser transitions before adding excerpt decoding.

## Deferred features

- [ ] Implement opt-in --suggest-on-error only when resumed: bounded, mode-aware candidates for byte substitutions/insertions/deletions and single-bit flips, never single-bit insertion/deletion or automatic repair (context: docs/plan_context/current-work.md).
- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
		- [ ] Should Roc unit checks remain explicitly mixed compile/test timing, or should test-artifact export be a separate compiler task? Its pinned compiler caches verdicts and publishes no test executable; owner decision pending.
	- [ ] Coordinate the approved quiet timing window, then perform one complete qualification retry with exact prepared artifacts and unchanged limits; await the infrastructure coordinator's verified admission control and cleared storage pressure before using the retry (context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
