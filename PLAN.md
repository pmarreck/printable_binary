# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Codec and Rust consumer requests

- [x] Deliver a working textual codec to the requesting CJK/logging consumer through its durable inbox after publication and exact-commit CI, including revision, integration examples and legacy-log reading; receipt acknowledged and consumer integration underway (done 2026-11-02 02:07 EST; commit cf9859d; context: docs/plan_context/current-work.md).
	- [x] Implement and publish the Rust textual library first, retaining legacy-log decoding without waiting for the canonical Zig port; all 27 exact-commit CI targets passed (done 2026-11-02 02:06 EST; commit cf9859d).
	- [x] Implement the Rust payload and whole-value tagged APIs with legacy-log reading, frozen Unicode policy and independent exhaustive-scalar checks; the complete local Nix test gate passes (done 2026-11-02 02:02 EST; context: docs/plan_context/current-work.md).
	- [x] Preserve ordinary spaces and ZWJ/ZWNJ in textual v1? Answer: yes; retain combining/variation marks too, and visibly encode other whitespace and format controls (done 2026-11-02 01:41 EST; context: docs/CODEC_MODES.md).

## Optional stream tagging

- [x] Compare bytewise versus provisional textual sizes? Answer: compact PB fallback measured 1.79× on random input versus bytewise 1.85× and explicit escapes 3.49×; half-CJK measured 1.43× versus 1.95×, while glyph-heavy text can grow; 45 fixtures recover exactly (done 2026-11-01 13:49 EST; context: docs/TEXTUAL_SIZE_STUDY.md).
- [x] Implement arbitrary-byte textual v1 in Rust/Zig libraries and the Zig CLI, retaining bytewise defaults, compact fallback, spaces/joiners, quoting and canonical validation; complete local gates pass (done 2026-11-02 02:24 EST; context: docs/CODEC_MODES.md).
	- [x] Port the accepted textual payload and tagged whole-value contract to the Zig library; cross-language scalar differentials, allocation-failure controls and the complete local gate pass (done 2026-11-02 02:16 EST; context: docs/plan_context/current-work.md).
	- [x] Separate project or mode? Answer: proceed with bytewise/textual modes in this project and establish bijectivity for both; a new repository is not needed for this increment (done 2026-11-01 13:22 EST; context: docs/plan_context/current-work.md).
	- [x] Must textual input be valid UTF-8 if controls remain supported? Answer: yes; all Unicode controls have valid UTF-8 encodings, malformed byte sequences are rejected, and arbitrary bytes remain supported by bytewise mode (done 2026-11-01 13:25 EST; context: docs/plan_context/current-work.md).
	- [x] Which textual input contract follows the size study? Answer: accept arbitrary bytes with compact PB fallback for malformed bytes, strict canonical decoding and martini quoting; this supersedes valid-UTF-8-only input (done 2026-11-01 13:52 EST; context: docs/TEXTUAL_SIZE_STUDY.md).
	- [x] Define textual payload martini quoting, unique token parsing and conditional two-sided inverse arguments over explicit domains; strict Rust/Zig implementations are independently tested, not machine-proved (done 2026-11-02 02:16 EST; context: docs/CODEC_MODES.md).
	- [x] Integrate explicit CLI textual and tagged-or-legacy decoding using the tested dispatch; default raw operations stay unchanged and untagged textual requires explicit selection (done 2026-11-02 02:24 EST; context: docs/plan_context/current-work.md).
	- [x] Should textual output be tagged by default? Answer: yes; keep bytewise output untagged by default, with explicit modes also supporting untagged payloads (done 2026-11-01 13:24 EST; context: docs/plan_context/current-work.md).
	- [x] Does accidental valid UTF-8 break byte/glyph alignment? Answer: yes in the proposed readable mode, not raw mode; losslessness can remain, but byte offsets, glyph counts, column widths, and alphabet-only detection need a separate contract (done 2026-11-01 12:42 EST).
	- [x] Audit active Rust/Zig textual paths for byte/scalar/column units, capacity, scalar iteration, formatting, detection and whole-value framing; unported runtimes remain bytewise (done 2026-11-02 02:24 EST; context: docs/CODEC_MODES.md).
- [ ] Evaluate a Latin-friendly high-byte alphabet retaining rough alphabetic progression, UTF-8 byte economy, and terminal readability; compatibility breaks are permitted, but select the replacement repertoire explicitly (context: docs/plan_context/current-work.md).
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
	- [x] Capture/assert all FFI smoke diagnostics with eight defect controls, enforce the Elixir VM's UTF-8 filename mode and seeded fixtures; complete local gate passes and fresh FFI execution takes 0.40–0.46 seconds (done 2026-11-02 02:42 EST; context: docs/plan_context/current-work.md).
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
	- [x] Retain precompiled tag-probe safety/mutant artifacts and re-execute the unchanged contracts in 0.20 seconds; all 26 Linux checks pass (done 2026-11-01 13:25 EST; context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
