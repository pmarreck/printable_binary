# PLAN

History is in [docs/PLAN_LOG.md](docs/PLAN_LOG.md); decisions and current build evidence are in [docs/plan_context/current-work.md](docs/plan_context/current-work.md).

## Codec and Rust consumer requests

- [x] Restore Roc hexlike/formatting parity exposed by the complete case inventory; all shared cases and independent all-byte comparisons now pass (done 2026-11-01 12:30 EST; context: docs/plan_context/current-work.md).

## Optional stream tagging

- [ ] Compare bytewise size with provisional textual escape grammars on seeded random/compressed data and exact text-byte mixtures; verify byte recovery, reject alternate spellings, and report quoting/fallback costs before selecting the format (context: docs/plan_context/current-work.md).
- [ ] Implement the approved opt-in `textual` codec alongside unchanged `bytewise`, with martini quoting and explicit bijection domains/proofs; settle malformed-UTF-8 and Unicode-control policy before implementing those choices (context: docs/plan_context/current-work.md).
	- [x] Separate project or mode? Answer: proceed with bytewise/textual modes in this project and establish bijectivity for both; a new repository is not needed for this increment (done 2026-11-01 13:22 EST; context: docs/plan_context/current-work.md).
	- [x] Must textual input be valid UTF-8 if controls remain supported? Answer: yes; all Unicode controls have valid UTF-8 encodings, malformed byte sequences are rejected, and arbitrary bytes remain supported by bytewise mode (done 2026-11-01 13:25 EST; context: docs/plan_context/current-work.md).
	- [ ] Revisit valid-UTF-8-only textual input for mixed binary/text inspection; explain distinct raw-byte escapes, canonicality validation, streaming boundaries, and size/performance tradeoffs before changing the domain (context: docs/plan_context/current-work.md).
	- [ ] Define textual martini quoting for replacement glyphs and the marker itself, reconcile framing dispatch, and prove unique parsing/two-sided inverses over explicit domains before implementation (context: docs/plan_context/current-work.md).
	- [ ] Add bytewise/textual dispatch using `ρΒ1_`/`ρΤ1_` tags or explicit out-of-band mode selection; do not guess from untagged content (context: docs/plan_context/current-work.md).
	- [x] Should textual output be tagged by default? Answer: yes; keep bytewise output untagged by default, with explicit modes also supporting untagged payloads (done 2026-11-01 13:24 EST; context: docs/plan_context/current-work.md).
	- [x] CJK-only or broader preservation? Answer: general visible Unicode outside the PB alphabet, including other languages and emoji; reserved PB glyphs and controls still encode normally (done 2026-11-01 12:39 EST).
	- [x] Does accidental valid UTF-8 break byte/glyph alignment? Answer: yes in the proposed readable mode, not raw mode; losslessness can remain, but byte offsets, glyph counts, column widths, and alphabet-only detection need a separate contract (done 2026-11-01 12:42 EST).
	- [ ] Audit byte/glyph/column assumptions, buffer sizing, UTF-16 code-unit loops, formatting, detection, and framing before adding the explicitly opt-in Unicode profile.
- [ ] Evaluate a Latin-friendly high-byte alphabet retaining rough alphabetic progression, UTF-8 byte economy, and terminal readability; compatibility breaks are permitted, but select the replacement repertoire explicitly (context: docs/plan_context/current-work.md).
	- [x] Which Latin-passthrough tradeoff takes priority? Answer: investigate Latin-looking symbols, accept larger UTF-8 output, and qualify font/terminal width; the exact alphabet remains unselected (done 2026-11-01 12:36 EST).
- [ ] Specify optional `ρΒ_`/`ρΒ1_` v1 tagging with reserved-prefix errors, standard martini quoting, a leading-tag encoder guard/raw-input override, and single-pass excerpts before implementation (context: docs/plan_context/current-work.md).
	- [x] Which encoding mode gets the leading-tag guard? Answer: tagged-output mode only; ordinary raw CLI encoding and the raw library remain unconditional (done 2026-11-01 12:39 EST).

## Deferred features

- [ ] Implement approved container metadata injection only when that deferred feature is resumed (context: docs/plans/2026-07-21-container-metadata-injection-design.md).
- [ ] Measure reusable-output ownership only if a consumer needs it; retain the current owned-slice API until then (context: docs/plan_context/current-work.md).

## Explicit holds

- [ ] Keep the raw Rust GUI/Zig transport protocol on hold until its specification is supplied.
- [ ] Keep container-only table-driven CRC32 optimization parked until explicitly resumed; use the performance-profiling workflow if resumed.

## Final verification and shipping

- [ ] Measure complete-suite execution separately from compilation/setup/queue wait and meet the few-seconds budget without reducing coverage, using bounded concurrency where safe.
	- [x] Run isolated shared-CLI groups with bounded concurrency and all assertions; fresh Node execution fell from 10.76 to 4.55 seconds and all 26 Linux checks pass (done 2026-11-01 12:30 EST; context: docs/plan_context/current-work.md).
	- [ ] Prepare all remaining exact test artifacts and separate fresh complete-suite execution from compilation, including the tag-probe safety/mutant builds.
	- [x] Retain precompiled tag-probe safety/mutant artifacts and re-execute the unchanged contracts in 0.20 seconds; all 26 Linux checks pass (done 2026-11-01 13:25 EST; context: docs/plan_context/current-work.md).
- [ ] Finish active authorized work, retain explicit holds, resolve remaining framing choices, run the complete gates to green, then push and verify the exact commit in CI.
