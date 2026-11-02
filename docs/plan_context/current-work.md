# Current work and retained decisions

## Cross-platform build migration authorized on 2026-10-23

The accumulated work was published as `f806bca411ef5e1756b13a7ecd5950f4395449a8`
on 2026-11-01. The fetched remote matches that revision. Mechatron Prime CI
passed all 26 exact-commit targets, finishing at 16:40:39 UTC. Its 41-second
run is not a fresh execution-only suite measurement. The Rust consumer received
a durable inbox delivery containing the published pin and option API; delivery
does not establish acknowledgment.

Cutover completed on 2026-11-01 after the shell-configuration project reported
qualified native-before-generic PATH selection. Fresh shell verification selects
`bin/linux-amd64/printable-binary`, whose one-line identity reports Zig and
`PF=linux-amd64 VARIANT=musl`. Ten recognized legacy compiled generic-bin
artifacts, including the previously tracked APE binary and foreign/debug
artifacts, were moved to a private recoverable backup with matching SHA-256
checksums. Portable LuaJIT, Node, conversion scripts, the mapping symlink, and
all namespaced product trees remain intact. No global shell configuration was
edited by this project.

The next verification must distinguish compilation, setup, queue wait, and actual
complete-suite execution. The owner reaffirmed a few-seconds execution budget;
cached Nix check results cannot establish that budget. The existing check
derivations mix compilation and execution, so their combined phase times remain
mixed until execution-only spans or prepared test runners are available.

The first runtime investigation found a hard lower bound: `test-leak` ran two
serial six-second RSS loops. Its shell adapter also accepted nonzero target exits
once four stable samples existed. A ten-case process/sampling regression failed
on exits 7, 124, and 139 in both FFI and CLI modes; the adapter now rejects them.
The candidate default gate replaces those elapsed-time windows with fixed-work
allocation lifecycles. The standalone C adapter records actual requested
malloc/calloc/realloc/free ownership, verifies canonical encoded bytes and
round trips, and requires zero residuals after each cycle. Deliberately retained
results and skipped work must fail. Its first Nix check passed with 610 requests,
75,008 peak requested bytes, and zero residuals; libc-internal allocations and
bookkeeping are explicitly outside that metric.

The Zig C ABI now receives its allocator through the build graph: the shipped
adapter still uses the page allocator without libc; the test adapter records
ownership through the standard testing allocator. A positive-allocation assertion
failed before wiring that dependency, preventing an uninstrumented pass. Fixed
lifecycles and allocation-failure sweeps now pass. The unit check retains the
same compiled test executables and separates build/check phases. FFI-filtered
tests avoid rerunning the imported core suite, which remains fully covered by
its own executable. The extended RSS tools remain recoverable and usable, but
no longer impose a wall-clock delay on default correctness checks. Full-suite
qualification and fresh execution measurements remain pending for this candidate.

The complete candidate then passed all 25 Linux Nix checks on 2026-11-01.
Fresh host measurements used prepared, safety-enabled test executables, private
filesystem confinement for mutating suites, the pinned shared latency recorder,
and the existing host resource admission envelope. No compilation occurred in
the execution spans. Run `pb-unit-node-20261101-1207` measured a five-sub-suite
subset at 10.82 seconds: correctness passed, latency exceeded the five-second
budget. An attribution run, `pb-unit-node-phases-20261101-1208`, measured 11.23
seconds, including 10.76 seconds for the shared Node CLI suite, 0.33 seconds for
the C ownership/RSS-driver controls, 0.08 seconds for the Zig core, and 0.06
seconds for Zig FFI. Both runs retained unchanged before/after source identity
`f9bc9f290f22a45d5cfd52240c26e9e7f0172dc811b7f6eaf80198e63916b1b4`.
These are fresh subset observations, not a complete-suite budget pass or a
historical baseline approval. The initial measurement attempt ran no tests
because its configured history directory was absent; successful diagnostic
records use an explicit private user-state history override.

The next optimization is isolated parallel groups within the shared CLI suite;
parallelizing implementations alone cannot beat its measured Node critical path.
Retain every assertion, real executable invocation, and failure propagation.
Compilation dominates the separately inspected 51-second tag-probe check phase:
that phase still builds a safety test and two deliberate-defect executables.
Move compilation to preparation before attributing its runtime. SIMD is deferred
here because the measured costs are process orchestration and mandatory waiting,
not evidence of an unvectorized codec hot path.

The allocation-lifecycle increment shipped as
`1e1e339249ea40726f00d48cdf6c3aa440915389`. The fetched remote matches, and all
26 exact-commit Mechatron Prime CI targets passed at 17:11:13 UTC on 2026-11-01.

The next candidate wraps the unchanged shared CLI cases in eight independent
groups with private temporary trees. A tested bounded-wave scheduler preserves
declaration-order output, waits for all groups, rejects malformed/duplicate group
sets, and propagates every worker failure. A FIFO barrier establishes actual
two-worker overlap without sleeps; the only timer is a five-second deadlock guard.
The pre-refactor, passing serial suite supplied 224 case/result lines, retained in
`tests/fixtures/shared-cli-case-inventory.txt`. The output gate initially accepted
missing, duplicated, and reversed traces; those three controls now fail.

A no-fault run of the exact codec adapter with spaces in its path exposed an
existing unquoted-command failure. Quoting those invocations and checking the
range-reference/idempotence command statuses made the positive control pass.
The fault adapter then atomically chooses one ordinary encoder invocation and
returns 7 after preserving its genuine stdout; the complete suite must reject it.
This prevents an unrelated path error from masquerading as a successful control.

Fresh run `pb-parallel-node-20261101-1217` passed the complete 224-line Node CLI
inventory in 4.55 seconds with eight groups, compared with the earlier serial
10.76-second observation. Total recorder begin-to-finish time was 4.63 seconds.
Its source identity remained
`b2f3588a32b36c4526f32c37379f27065e75d4cc3d4c719d937267aef80b33ac`.
The prepared Node executable is unchanged; this is a concurrency/layout change
to tests, not a codec speedup or historical-baseline approval. Host load before
the run was approximately 39 over 128 logical CPUs. The run establishes a
Node-sub-suite budget pass, not a complete-project execution budget pass.
The complete candidate passed all 26 Linux checks on 2026-11-01 at 12:30 EST.
This includes the additional mandatory scheduler/inventory check, so the CI
manifest now contains 27 targets including the canonical package.

The first complete run exposed missing Python/hexdump test dependencies and a
previously hidden Roc parity gap: Roc's help omitted hexlike, causing the older
suite to skip all 20 hexlike cases, and its parser accepted formatting flags
without applying them. The stronger inventory gate was retained. Six new Roc
expectations failed with zero compiler errors before implementing pure hexlike
encoding/decoding and glyph-aware formatting. The final Roc CLI passes the whole
shared inventory, warning/help behavior, malformed-format controls, pure boundary
tests, and independent exact-output comparisons against Zig over all 256 values
with and without preserved spaces. Required test dependencies are declared in
the build-architecture check rather than obtained from the host.

On 2026-11-01 the owner authorized committing and pushing the accumulated work
without waiting for the remaining framing choice. All 25 Linux Nix checks
passed again after retirement of the legacy products and the memory migration.
This establishes correctness for that check source, not a few-seconds fresh
execution result. The repository CI guide is a regular, self-contained file
that links to the shared authority rather than depending on a sibling checkout.

## CJK-readable log encoding requested on 2026-11-01

The high-byte mapping was intentionally chosen to progress roughly through
accented Latin letters, giving readers a visual estimate of numeric order, while
favoring shorter UTF-8 representations. The owner explicitly permits an alphabet
compatibility break at the project's current adoption level to preserve ordinary
Latin-language text. Retain those ordering and byte-economy goals when comparing
replacement alphabets. Do not merely move collisions to another natural script
without discussing that tradeoff. No replacement alphabet is selected, and
existing persisted data must remain recoverable through the historical map.

Pinned Unicode 16.0 inspection found that all 128 high-byte glyphs are Latin
script (125 two-byte UTF-8 glyphs and three three-byte glyphs), while none fall
in U+00C0–U+00FF. Common Latin-1 accents are therefore already disjoint; extended
letters such as `ă` and `ź` are not. On 2026-11-01 at 12:36 EST, the owner selected
the Latin-looking symbol direction: larger UTF-8 output is acceptable, and font
rendering/terminal-width behavior must be qualified. Retaining the compact
accented-letter alphabet plus collision quoting is not the selected priority.
This accepts the investigation's tradeoff, not a concrete 128-glyph alphabet.

The owner also selected general visible Unicode outside the active PB alphabet,
not a CJK-only mode. This covers other languages and emoji without separate
script allowlists; reserved PB glyphs and control characters still need normal
byte encoding. No Unicode normalization is proposed. One remaining policy
question concerns ZWJ/ZWNJ: preserving those invisible joiners supports joined
emoji and language shaping, while C0/C1, bidi controls, and other format controls
would stay encoded. Define combining and variation marks explicitly too, rather
than conflating valid UTF-8 with visible text. Audit all 256 reserved glyphs,
including lower-byte letters, before claiming any natural-script alphabet is
collision-free. Neither investigation changes the default codec yet.

The owner raised the byte-alignment consequence explicitly on 2026-11-01:
arbitrary binary can contain syntactically valid multibyte UTF-8 without having
textual intent. A readable mode cannot infer that intent. For example, `E4 B8 AD`
is three source bytes; raw PB emits three code points, whereas preserving `中`
emits one code point, commonly two terminal cells. Keep the canonical raw codec
byte-oriented and make readable Unicode a separate opt-in profile rather than a
silent default change. Its reversible byte mapping can remain lossless when the
passthrough set excludes active PB glyphs and reserved framing controls, but it
does not retain byte offsets derived from glyph counts, fixed-column layout, or
alphabet-only detection. Larger UTF-8 representations in the replacement raw
alphabet are a separate change: each byte can still emit one Unicode scalar.

Before implementation, audit every implementation and consumer-facing API for
byte counts versus scalars, grapheme clusters, terminal cells, and UTF-16 code
units. Check sizing, worst-case repeated four-byte mapping glyphs, formatting,
validation/detection, stream chunk boundaries, and framing. The proposed profile
keeps existing ASCII escaping unchanged and adds non-ASCII text preservation;
that boundary remains explicit rather than broadening JSON-sensitive ASCII
passthrough accidentally. Unicode distinguishes grapheme clusters from code
points in [UAX #29](https://www.unicode.org/reports/tr29/) and warns that terminal
width needs implementation-specific tailoring in
[UAX #11](https://www.unicode.org/reports/tr11/). No universal font-width guarantee
is inferred from the East_Asian_Width property alone.

The owner then identified the stronger representation problem: both literal `中`
and the three raw PB glyphs for `E4 B8 AD` decode to the same source bytes. Thus
`decode(encode(x)) == x` alone is not enough. Over the expanded accepted alphabet,
decoding is many-to-one, and `encode(decode(y)) == y` cannot hold for both forms.
A deterministic Unicode encoder can remain injective, but a bijective Unicode
format would need an explicitly restricted canonical language and rejection of
alternate bytewise spellings. Restricting the codomain to the encoder's image
without enforcing that boundary does not preserve the existing simple-alphabet
contract. The current permissive raw decoder already tolerates unknown Unicode;
raw PB's bijection applies to its declared canonical alphabet, not every input
the permissive decoder happens to accept.

There is also a composability change: raw byte substitution satisfies
`E(x ++ y) == E(x) ++ E(y)`. Unicode-aware encoding does not: separately encoding
`E4` and `B8 AD` yields three PB glyphs, while encoding their concatenation can
yield `中`. Streaming carry can make one logical message independent of read
chunks, but independently encoded pieces need not concatenate to a canonical
Unicode representation. On 2026-11-01 the owner requested further discussion
rather than selecting a contract. Keep the Unicode path at the design stage;
do not treat the recommended readable-view option as accepted.

The subsequent proposal is selective escaping of nonprinting/control and
syntax-sensitive characters, passing other content through. It is an exploratory
alternative, not authorization to create a separate project, replace the raw
format, or implement a mode. An explicit mode within this project is equally
under consideration; repository separation and format-contract separation are
different decisions. No version or project name has been selected.

Selective escaping need not sacrifice bijectivity if literal replacement glyphs
or escape syntax have an unambiguous canonical representation. Its input domain
also matters: substituting only selected ASCII bytes can preserve ordinary UTF-8
without recognizing multibyte characters, and an unambiguous bytewise escape
grammar can preserve concatenation. It cannot also guarantee printable UTF-8
for arbitrary invalid UTF-8 input while passing every other byte unchanged.
C1 byte values cannot be treated as Unicode controls without considering their
role inside UTF-8 sequences. The syntax-sensitive set is context-dependent;
JSON, shell, and language-literal safety are not interchangeable guarantees.
These are design questions, not accepted restrictions or implementation choices.

The proposed user-facing names are `bijective` for the current bytewise format
and `map-sensitive` for selectively mapping controls and syntax-sensitive
characters while preserving other text. These names remain under discussion.
Bijectivity describes a mapping guarantee, not an exclusive mode category: a
text-preserving escape codec could also be bijective with an appropriate
canonical grammar. Define the sensitive subset explicitly rather than treating
all existing nonidentity byte mappings as Unicode character substitutions.
Literal replacement glyphs still need a collision policy; preserving literal
`¶` unchanged while mapping LF to `¶` would prevent exact recovery of both.
No codec, command-line interface, or default has changed.

The naming discussion then proposed `bytewise` and `textual`, conditional on
establishing bijectivity for both. The martini U+F000 is already the intended
escape character; the textual proposal should reuse that decision rather than
invent another introducer. The existing accepted framing rule doubles the
marker to quote it. A natural textual extension is `M` plus a reserved replacement
glyph to emit that glyph literally, without rescanning produced output. Thus
LF could encode as `¶`, literal `¶` as `M¶`, and literal `M` as `MM`. These
illustrate the proposed grammar, not implemented behavior or a complete spec.

A proof route for a simplified valid-UTF-8 input domain is to let `S` be the
selected ASCII characters, `g` their injective single-glyph mapping, `G` its
range, and `M` the marker. Require `S` and `G` to be disjoint and `M` outside
both. Encode a member of `S` with `g`, a member of `G` or `M` with an `M` prefix,
and every other scalar literally. Canonical output tokens are unprefixed
scalars outside `S` and `M`, or `M` followed by a member of `G` or `M`. These
tokens parse uniquely; decoding a bare mapped glyph reverses `g`, decoding a
quoted token emits its second scalar, and other tokens pass through. Each token
rule has a unique inverse, so induction over tokens can establish both inverse
identities. Reject unnecessary quotes, bare sensitive characters, incomplete
escapes, and undefined quote forms from that canonical language. Permissive
acceptance of equivalent spellings must not be called bijective over that wider
accepted set.

This is a candidate proof construction, not proof of the full feature or its
implementation. Settle the actual sensitive repertoire, Unicode-control policy,
valid-UTF-8 versus arbitrary-byte domain, and framing integration first. Framing
already permits omitted or explicit v1 spellings and optional closing tags, so
its permissive wire language must not be conflated with a bijective canonical
payload language. Verify the raw map independently over all 256 bytes and prove
its string extension; for textual encoding, prove the declared grammar and then
test actual code against it, including chunk boundaries and deliberate malformed
or redundant escapes. Sampling two-way round trips alone is not a universal
proof. This was still exploratory at that checkpoint; implementation approval
arrived in the subsequent decision below.

At 13:22 EST on 2026-11-01, the owner approved proceeding with `bytewise` and
`textual` modes, with the stated bijection goal and martini quoting. This is work
inside the existing project, not a new repository or a silent raw-format change.
The remaining implementation choices still require a precise contract. The
next mode-identification proposal reuses `ρΒ1_` for bytewise and adds
`ρΤ1_` for textual; the latter uses Greek capital tau U+03A4, alongside rho
U+03C1 and the existing beta U+0392. Each explicit-v1 opener is nine UTF-8 bytes.
Matching textual closers would use `/ρΤ`. The namespace extension remains a
proposal until checked against the full framing grammar.

Untagged payload languages overlap, so content heuristics cannot reliably
identify the intended codec. Tags provide in-band identification; explicit mode
arguments or typed APIs provide out-of-band identification. Do not infer textual
mode merely from valid UTF-8 or a marker-like character. Two owner questions
were asked: whether textual output should be tagged by default while bytewise
retains its untagged default, and whether textual input requires valid UTF-8 or
also accepts arbitrary bytes with malformed-sequence escapes. The owner answered
the first: tag textual output by default and keep bytewise untagged; explicit
modes can also support untagged payloads. This explicitly updates the earlier
opt-in-only tagging direction for textual mode, not bytewise mode. The owner
subsequently accepted valid-UTF-8 input provided control characters are
supported. They are: ASCII controls, including NUL, retain their single-byte
UTF-8 spellings; C1 control code points require proper multibyte spellings (for
example, U+0080 is `C2 80`, while a lone `80` is invalid UTF-8). These encoding
rules follow [RFC 3629](https://www.rfc-editor.org/rfc/rfc3629#section-3).
Textual input is therefore valid UTF-8, controls included; malformed UTF-8 is
rejected without normalization or replacement. Arbitrary bytes remain the
bytewise domain.

The next question reopens the textual input-domain discussion: arbitrary-byte
input would also expose readable UTF-8 runs embedded in otherwise binary data.
This benefit does not inherently preclude bijectivity. A candidate extension
greedily encodes valid UTF-8 scalars with the textual rules and uses a separate
martini-prefixed raw-byte token for malformed bytes. For example, `MxHH` could
represent one raw byte; that spelling is illustrative, not selected. Strict
canonical decoding must reject alternate raw-byte-token runs that could instead
have been represented by normal textual tokens. In particular, escaped bytes
`E4 B8 AD` must not form a second accepted spelling for literal `中`. Proper
Unicode C1 controls and lone invalid C1-valued bytes need distinct meanings.

This adds bounded UTF-8 lookahead/carry and canonicality validation. Read-buffer
boundaries must not change output; independently encoded pieces may still
concatenate to a noncanonical representation when a UTF-8 scalar straddles their
source boundary. Invalid-byte escapes may substantially expand binary-heavy
data, and CPU cost needs measurement rather than an assumed percentage. The
benefit is one arbitrary-byte input domain with readable text runs and no
malformed-UTF-8 rejection. The previously approved valid-UTF-8-only baseline is
not silently replaced by this question; the owner has requested the tradeoffs,
not yet selected this extension.

The original motivation was clarified as safe inspection of arbitrary binary
without disturbing terminal state, while retaining readable embedded ASCII
instead of hexadecimal. The requested next step is now a size experiment:
compare random-like/compressed data with UTF-8-heavy data and mixtures, including
roughly half text by source bytes. This authorizes experimental codecs and
measurements, not silently selecting the production escape grammar.

Compare an explicit `MxHH` raw-byte escape against a more compact candidate:
reuse existing PB glyphs for invalid bytes and encoded Unicode controls, preserve
eligible UTF-8 scalars, and martini-quote literal reserved glyphs or the martini.
The compact candidate still needs canonical validation: bytewise glyphs spelling
a source scalar that should have been preserved or quoted are alternate forms
and must be rejected. Do not assume per-invalid-byte martinis are necessary.
Report all expansion in UTF-8 bytes, separate the nine-byte default textual tag,
distinguish deliberately inserted text fraction from accidentally valid UTF-8
in random input, and verify recovery independently before counting savings.

The size experiment is complete: three seeded 262,144-byte source pools produced
45 random, compressed and text-mixture fixtures, each checked against the
existing JavaScript codec and a separately prepared Zig CLI. Both experimental
textual variants recover every source exactly and reject their noncanonical
alternatives. Compact PB fallback averages approximately 1.79 output bytes per
input byte for random-like data, versus bytewise 1.85 and explicit raw-byte hex
escapes 3.49. Half-random/half-CJK data measures about 1.43 versus bytewise 1.95;
repeated literal reserved `ă` is a counterexample at 2.50 versus bytewise 2.00.
Full methods, qualification limits and byte ledgers are in
[the size-study report](../TEXTUAL_SIZE_STUDY.md). These are deterministic size
measurements, not speed claims or production-code proof. All measured textual
totals include the nine-byte default opener. The compact fallback is the new
recommendation for arbitrary-byte textual input, not an implicitly approved
production grammar. The conservative study policy escapes joiners; the pending
Unicode joining/format-control policy question remains open.

At 13:52 EST the owner explicitly selected arbitrary-byte textual input with
compact PB fallback for malformed bytes, strict canonical decoding and martini
quoting. This supersedes the earlier valid-UTF-8-only baseline and turns the
recommendation above into the accepted direction. The complete Linux suite now
passes all 26 checks including the prototype and its required regressions;
all declared systems also pass evaluation without claiming foreign execution.
The production joining/format-control policy remains pending. No production
codec or raw mapping has changed in this experiment increment.

The prior preparation increment is published at `4468278`; origin/yolo was
independently verified, and Mechatron Prime CI passed all 27 targets in its
40-second validation run. This does not settle the still-open fresh complete-
suite execution budget. The size-study code and its regressions now join the
existing JavaScript unit check in the complete test entry point.

The complete Linux Nix check run passed all 26 checks at 13:25 EST. It includes
the retained tag-probe safety test and both actual optimized mutant artifacts,
all previous implementation contracts, and cross-target build-architecture
checks. Foreign-system evaluation and exact-commit CI verification remain
separate gates. This passing build does not establish the fresh full-suite
execution budget; the measured 0.20-second result is still a subset only.

Checkpoint: `d66e722` is published with all 27 Mechatron Prime CI targets green.
The next test-preparation increment retains the tag-probe safety and two real
mutant executables. Its missing-artifact control failed against the previous
package, its focused Nix check passes, and fresh run
`pb-prepared-tag-20261101-1244` executes the same fixtures/safety/adapter/mutant
contracts in 0.20 seconds (0.33 seconds recorder total), with unchanged source
identity `33b405196596df431e97ab3c8b139b518345ba15ad9a080f89d731e46d3560bd`.
Compilation took 79 seconds in its separate preparation phase. Full-suite
qualification and shipment of this increment remain pending; the full-project
fresh-execution budget is still open. The semantic-search service did not return
an audit result, so the initial sizing/Unicode audit used direct source inspection.

The requested optional mode should preserve readable Chinese, Japanese, and
Korean text instead of byte-encoding every UTF-8 octet. An inspection of all 256
canonical glyphs with the pinned runtime's Unicode 16.0 script data found no Han,
Hiragana, Katakana, or Hangul conflicts. The default decoder already copies
unrecognized complete UTF-8 sequences unchanged, so an encoder-side CJK
passthrough can preserve byte-for-byte recovery without reassigning the existing
256 mappings. This is a proposed expanded output repertoire, not implemented
behavior or a change to default raw encoding.

The owner explicitly separated broader non-CJK support because PB's Latin-range
glyphs can also be ordinary non-English text. Discuss those collisions before
extending preservation to other scripts. Define the CJK repertoire, shared
punctuation/marks, supplementary ideographs, malformed UTF-8 handling, and
recognition rules before implementation. Unicode distinguishes scripts from
blocks and documents shared characters through Script_Extensions in
[UAX #24](https://www.unicode.org/reports/tr24/); one basic ideograph range is
insufficient for Japanese and Korean text. Keep controls encoded and retain
exhaustive mapping, collision, and both-direction round-trip checks over each
declared canonical image. Raw alphabet-only recognition remains unchanged;
the new optional mode would need an explicitly expanded recognizer.

Adopt the shared cross-platform build architecture in this repository. Zig remains the initial canonical implementation. The migration starts with selection and scope tests, then verified target-separated product publication and command consolidation. Global shell/PATH configuration is outside this repository's migration; record existing command resolution and coordinate its cutover separately. Existing generated products and unknown files must remain recoverable.

APE is a distinct executable implementation with its own identifier, support declarations, package selection, and `ape-out/` product tree. Sharing C source does not merge it with the standalone C implementation. Shipping is deferred until the restructuring and remaining authorized plan work pass the complete gates. Explicit holds and missing protocol/framing choices remain visible owner decisions; they must not be silently treated as completed or implemented from guesses.

The current `build` script defaults to the combined Nix distribution and copies compiled products into generic `bin/`. `build_all` delegates to `build all`; Make and tests also use generic `bin/` or `zig-out/bin/`. The Nix default bundles Zig, standalone C, and WASM, plus APE and Roc on Linux. Rust, LuaJIT, Node.js, and the C-FFI CLI also have executable implementations. Their actual build/runtime support must be inventoried rather than claiming a full implementation/platform Cartesian product. The target vocabulary is `macos-arm64`, `linux-amd64`, `linux-arm64`, `mswin-amd64`, and `mswin-arm64`; compiler and Nix identifiers retain their native spellings.

Acceptance includes strict non-executable `CANONICAL_IMPL` parsing; canonization without building or publishing; independent all-implementation/all-platform scope flags; verified headers and runtime requirements; coexisting PF/variant/profile products; publication only after success with previous selections retained on failure; retained Nix output roots; and exact-product tests. The first small behavior is selection without build/publication side effects. Its edge cases include hostile selector contents, repeated canonization, and malformed or unavailable implementation/platform combinations.

Initial TDD evidence: `tests/unit/test-build-config` failed because the build configuration core did not exist, then passed after adding `build-support/config.bash`. A subsequent directory-selector regression failed because a rename could move the temporary file inside that directory; canonization now rejects non-regular destinations before writing. A project-selection regression failed before adding `CANONICAL_IMPL` with the initial value `zig`. The 83 focused checks cover exact selector bytes (including NUL, CRLF, extra LF, and shell-looking input), unchanged inode/content on repeated canonization, paths with spaces, the five-platform host classifier, and all scope aliases/orderings. These checks are reached through the existing `test-build-all` Nix/CI check. The queued Linux run completed successfully on 2026-10-23: all flake checks passed and the canonical Zig package built. `./build` has not yet been switched to this configuration core, and output/PATH migration is still pending.

The test directory is now `tests/`; root `./test` runs the complete accumulating Nix check graph. A recording-adapter regression failed while `test` was still a directory, then passed after migration, including child failure propagation. All 24 Linux checks passed against the frozen migrated source. Existing suites, Zig consumer fixtures, Make targets, and current documentation point to the new directory. Earlier historical receipts keep the paths actually used at the time.

The next candidate now wires `build`, `build-all`, and `run` to the tested configuration core. `build-support/implementations` declares nine independent implementations and 30 supported target combinations; APE has a separate identifier, package stem, and product tree. Scope tests compare complete sets. The Nix package matrix exposes ReleaseFast, ReleaseSafe, and Debug variants, uses three native Nix build systems, cross-compiles the canonical Zig implementation for all five PF targets, and requires Linux builders for APE. Darwin APE products explicitly resolve to the Linux builder instead of being omitted from an all-implementations request. Evaluation succeeds across all declared Nix systems; this alone does not establish successful compilation or foreign execution.

Build candidates retain per-generation Nix roots or direct prefixes, verify manifest fields and executable target headers, select implementation/PF/ABI/profile product trees, and publish only the canonical host command. The source snapshot is frozen once for a multi-product Nix build. A project-wide atomic directory lock prevents overlapping publications; a canonical selection changed during compilation cancels publication. Confined tests cover canonical switching, scope aliases/order/repetition, protected paths, rejected unmanaged outputs, failed builds and verification, and a competing build callback without sleeps. Canonization through the public frontend is checked without invoking Nix or the shared build queue.

Unix publication uses direct relative symlinks. Windows publication of the standalone Zig/APE command uses an atomic copy rather than requiring symlink privileges. Its hash record accepts the pre-copy and post-copy states before the copy, allowing retries after either boundary. Fault injection before and after each Windows publication effect exposed duplicate copies and non-no-op retries; completed copies are now recognized, and a completed retry changes nothing. These filesystem operations passed Linux confinement tests with simulated Windows publication paths. They are not Windows runtime evidence. The real-product gate is being expanded to inspect every installed host implementation, exhaust both mapping directions against the canonical table, inspect all five Zig target headers, and publish independently prepared products in a disposable project.

The actual pinned Emscripten compiler reports `wasm32-unknown-emscripten` (Emscripten 5.0.7-git, Clang 22.1.6). The matrix records that compiler spelling; WASI describes the standalone module's runtime interface rather than changing the compiler triple. Source filtering excludes only root `CANONICAL_IMPL`, with classifier tests that retain nested similarly named files and future sources, so changing canonical selection does not become every implementation's source dependency.

Decisions confirmed on 2026-10-23: finish active work while retaining explicit holds; container metadata, the parked CRC32 optimization, and the unspecified raw transport are not resumed. PATH cutover coordination with the shell-configuration project is authorized after verification of the native-PF commands. The portable-runtime exception to `--about` is accepted: APE and the WASM launcher report active execution PF, ignoring OS/ARCH/PF environment overrides, alongside their actual portable target. Native Zig/C/Rust/Roc report compilation-target PF. Generic-bin legacy products have not yet been removed or retargeted, and global PATH has not been changed. Pushing remains deferred until active work and the complete gates are green.

The first real matrix gate passed against its frozen source: all nine installed host implementations encoded all 256 bytes exactly as `character_map.txt` specifies and decoded that representation back to the original bytes; the real controller/verifier/publisher selected these independently prepared products in a disposable project. Zig successfully compiled for all five declared PF targets, and their actual ELF, Mach-O, and PE headers matched the declared platforms. No foreign runtime execution is claimed. Subsequent work aligns the native C Make interface with Nix, adds canonical Nix command aliases, and validates the complete suite before committing that milestone.

The native Make regression reproduced a data-loss hazard in a disposable project: legacy `clean` removed the source-script directory and the canonical `.txt` mapping. `clean`/`distclean` now refuse broad removal and explain that generated artifacts must be selected explicitly and removed recoverably. The C Make target now accepts `PREFIX` and `PROFILE`, uses portable CPU defaults, and is called by its Nix package instead of duplicating its compile command. These focused adapter checks pass; the full post-change gate is pending.

### Nix-only build and PATH checkpoint

The frozen Nix-only migration passed all 24 Linux checks at 20:49 EDT on 2026-10-23, including real installed C/FFI/APE/WASM products through their consolidated Make leaves, nine canonical aliases, exact benchmark product discovery, and all five Zig target headers. This checkpoint excludes the later uncommitted CLI-identity and shared-suite output changes. Queue wait was roughly ten minutes; execution remained within its 30-minute resource envelope.

The subsequent Nix-only revision replaces public Make commands with delegations and keeps explicit C/FFI/APE/WASM compiler leaves inside derivations. It removes manual compiler/download/install/cleanup workflows from the supported interface; historical recipes remain recoverable in Git. Benchmark discovery now resolves verified host ReleaseFast product trees, without stale generic-bin, Cargo-cache, or result-link fallback. Confined regressions cover every declared implementation/PF pair, real installed-product discovery, and Git's ignore classifier over generated and current/future source path sets. A fresh complete Linux run against a frozen source was admitted after roughly ten minutes of queue wait; its execution result is pending.

The CLI-identity work has failing executable regressions against all nine previously built host products. Native C/FFI, Rust, and Zig now have draft compilation-target identity; interpreted Node and LuaJIT checks pass on Linux with conflicting OS/ARCH/PF/VARIANT environment values. Roc obtains target fields through its Zig host library; the WASM launcher supplies a host-derived execution PF independently of caller overrides, while its module supplies the compiler target. These native/platform changes still require actual Nix compilation and runtime verification. The pre-identity suite also exposed existing binary-unsafe shebang probing and uncaptured expected statistics in the legacy shared CLI suite; that cleanup is queued explicitly, rather than claiming the output is clean.

At 20:23 EDT on 2026-10-23, the complete 24-check Linux graph passed, including the native C interface and canonical aliases for all nine installed host products. The real `./build` then published the canonical Zig ReleaseFast command at `bin/linux-amd64/printable-binary`; a direct invocation produced the expected mapping. The frozen source used for that run still included the draft direct backend. The subsequently refreshed architecture skill requires Nix as the sole build operation, so that backend and its switch are being removed with a failing-first missing-Nix/no-fallback regression. Earlier direct-prefix design notes above describe the superseded draft.

The shell-configuration agent acknowledged the verified native-PF handoff at 20:24 EDT and queued this project as a qualification pilot. It must first restore its own suite and implement the actual PATH constructor contract. Next action belongs to that agent: return readiness with exact test/commit evidence, including refresh/rehash behavior. Until then, this project keeps every legacy compiled generic-bin product intact; no global PATH cutover or retirement is claimed. Other build, interface, portability, and codec work can continue.

The shared-suite stderr gate initially failed with 2,419 bytes of uncaptured statistics and binary shebang warnings. The suite now probes only a confirmed script header, uses explicit success checks for codec invocations, and enables diagnostics explicitly in warning/statistics cases while keeping ordinary cases muted. A fault adapter preserves genuine encoded stdout but returns status 7 on its first call; the real shared suite rejects it immediately, including a fixture path with spaces. The legacy `tests/test-all` helper initially failed delegation/failure-propagation checks and is now a one-way alias to the complete root command. The WASM smoke test initially returned success for a missing explicit product; it now requires the prepared launcher and is reached from the real-product check. No host filesystem mount was added to WASM; stdin/stdout is the packaged default.

The first full CLI-identity run failed in APE compilation because Cosmopolitan hides `IsLinux`, `IsWindows`, and `IsXnu` behind `_COSMO_SOURCE`. The C source now enables that feature macro before system headers. The failed run did not publish anything. The eight other newly built host products passed the strict identity/help checks in confinement, including the WASM launcher's replacement of conflicting caller-supplied execution metadata. A focused APE build followed by the complete graph is the next verification step; the feature-macro repair is not yet claimed green.

The APE feature-macro repair built successfully through Nix and passed the strict identity check; both architecture syntax diagnostics also passed. The complete retry then exposed a sandbox-only test-adapter error: the legacy alias directly executed a copied, unpatched `/usr/bin/env` test shebang. It now invokes Bash explicitly. A separate source-cache regression failed before excluding specifically listed non-runtime metadata/workflow files. Real filtered-source hashes now stay equal when only fixture metadata changes and differ when fixture code changes; classification tests retain future source files, Make, the mapping, and WASM runtime inputs. Required checks still consume the complete test/documentation source. The next full retry must qualify this revision before publication or a new commit.

The CLI-identity/source-cache checkpoint passed all 24 Linux Nix checks at 22:10 EDT on 2026-10-23, then the real build published the verified canonical Zig ReleaseFast command. Its direct `--about` reports `PF=linux-amd64 VARIANT=musl` despite conflicting caller metadata. All nine installed host implementations pass the identity and exhaustive canonical-map contracts; all five Zig target headers match. Foreign runtime execution, Debug/ReleaseSafe execution, and the coordinated PATH cutover remain separate open work. The full run waited roughly twenty minutes for admission and completed within its 30-minute execution limit.

The expanded profile build reproduced a ReleaseSafe C-FFI linker failure on `__zig_probe_stack`. The pinned Zig build API leaves compiler-runtime bundling unset for a static library by default; C linkers do not automatically add Zig's runtime. The draft build graph now bundles it in the C-linkable archive, preserving stack probes and safety checks. This repair still needs the real profile gate. Separately, the frozen pre-repair Rust package check fails during its build script's parent-directory map read, independently confirming the crate-containment bug.

The official compiler replacement passed its focused Linux gate: all Roc module expectations, shared CLI/container contracts, and cross-implementation containers passed against the frozen candidate. The actual installed C Debug product failed the new banner contract with empty stderr, proving the profile assertion is non-vacuous before adding banners across the implementations. The next complete run must qualify these later changes together.

The first full profile retry passed the isolated packaged Rust build/tests, all 65,536 two-byte decoder cases, and Rust/Zig spaces/whitespace differentials. Its remaining failures came from Roc's compile-time constant-condition warning, which returns nonzero even when code generation succeeds. The banner now uses a profile-selected string instead of a constant `if`; the corrected main passed a confined `roc check` with no diagnostics. Warnings remain enforced. The complete post-repair graph is still required.

The post-Roc-repair retry passed the native identity/mapping gate and the remaining Roc/Rust suites, then failed the Debug Zig help assertion. Its positional stderr writer overwrote the earlier banner when redirected to a regular file. An expanded passthrough assertion also fails against that prepared product. Standard-output/error data writers now use streaming writes, and help uses the streaming convenience call. The same retry will include exact UTF-8 byte guards: malformed `E2 07 A5` also reproduces a three-byte alias, so the new pure lookup controls exhaust 65,536 two-byte inputs and 16,777,216 three-byte inputs against the canonical table. Their runtime cost and safety-enabled execution remain to be measured by the next complete gate.

## Rust consumer request received on 2026-10-23

The corresponding new Zig CLI regression fails on malformed bytes `C2 36`: its two-byte lookup also masks prefix/continuation bits without checking that they form a valid UTF-8 glyph. This is outside the canonical PB alphabet, but should not silently alias a recognized control glyph. The bounded two-/three-byte corrections join the next build/profile retry after their failing CLI reproductions. The namespace-probe experiment must also distinguish valid UTF-8 PB regions from arbitrary literal bytes: a decoder's multibyte fallback can skip a marker start following a malformed prefix, so a future framing parser needs explicit resynchronization rather than assuming every miss begins at a valid character boundary.

The same standard-handle adapter issue also reproduces for inherited stdin positions: a prepared Zig CLI rereads a regular input file from byte zero after its caller consumed a prefix. Stdin now uses a streaming reader; explicitly opened input files retain their positional reader. The complete profile checks include inherited input/output positions and full passthrough output, while the Zig unit check runs with ReleaseSafe. These corrections remain uncommitted until the complete retry passes.
A new persistent CLI regression reproduced a Rust decoder error: input bytes `82 B6` become LF because the two-byte lookup masks away invalid UTF-8 prefix bits. A truncated three-byte sequence can also enter the two-byte table after length clamping. The draft correction checks exact lead/continuation ranges, never reclassifies a truncated prefix, and advances one unrecognized byte at a time. Its independent unit regression enumerates all 65,536 two-byte inputs and accepts only complete canonical glyph matches. The correction still needs compilation and the complete gate; the reproduced failure does not establish the fix is green.

The requesting consumer needs a distributable Rust crate and spaces-preserving encode/decode options matching Zig. The crate's `build.rs` currently reads `../character_map.txt`, so it is not self-contained. Build scripts must not read above their crate. Generate or vendor the required mapping inside `rust/`, and add a repository-level synchronization regression to prevent drift from `character_map.txt`. Validate a packaged/isolated crate rather than relying solely on a full-checkout build. Keep the consumer request queued after the active build migration; reply with the usable crate path and revision after verification. The separate raw Rust transport protocol remains on hold.

The expanded milestone passed all 24 Linux Nix checks at 00:09 EDT on 2026-10-24 against frozen source `/nix/store/0md3pcpp72kkwd9ziyxqb1k9pqkb55w3-source`. The same admitted job then built and selected all nine host ReleaseFast products and published the canonical Zig command. Verification includes all eighteen host Debug/ReleaseSafe products, the official native Roc compiler and matching glue, the extracted self-contained Rust crate, Rust/Zig option comparisons, and raw literal-tag preservation across all nine products. Zig's ReleaseSafe unit suite exhausts all 65,536 two-byte and 16,777,216 three-byte lookup inputs; Rust exhausts all 65,536 two-byte inputs. Foreign Zig headers are checked for all five targets, without claiming foreign runtime execution. Standard-handle streaming adapters preserve inherited offsets; the current Zig CLI still buffers the complete input and result. This milestone does not implement framing or complete the global PATH cutover.

Follow-up verification reproduced the malformed `C2 36` to LF alias in the shared standalone C/APE/WASM decoder. Its two-byte lookup now validates the lead and continuation bytes before masking. A C unit test exhausts all 65,536 two-byte inputs against exact embedded glyph bytes, alongside the independent canonical-map checks. At 01:00 EDT on 2026-10-24, the complete Linux run passed that test, all nine installed codec checks, and all eighteen safety/debug profiles. The run remained red on the benchmark's newly added default-seed regression: the shared engine supplies hexadecimal text while the probe parsed a number. The probe now preserves seed text, and another complete run must qualify that change before a new commit.

The CI manifest now includes the previously omitted Rust toolchain-pin check and the new recognition check. The documentation check derives its required target set from Nix's actual Linux check names, preventing synchronized omissions in a manually maintained test list and manifest. The provisioning dry run and subsequent dedicated-webhook provisioning both succeeded for the canonical repository. Exact-commit CI verification still follows the authorized push.

## Build portability

The Linux APE package failed on a WSL consumer at commit `cdefa95`. The reported build returned exit 127 from cosmocc's `mktemper` invocation, even though the same package built on native Linux CI. The bundled helper begins with an `MZ` executable header. The report's proposed cause is WSL's Windows-interoperability handler claiming the binary inside the Nix sandbox; that handler has not been inspected directly.

The required repair is independent of host MZ handlers. [Cosmopolitan's toolchain documentation](https://github.com/jart/cosmopolitan/blob/master/tool/cosmocc/README.md) describes its native APE loaders and `assimilate`, which converts APE files to native ELF. Validate all executable toolchain files, including compiler subprocesses below `libexec`, rather than checking only `mktemper`. Keep the final distributed PrintableBinary APE portable; only the build tools should become host-native. A consumer needing only the canonical CLI can select `packages.<system>.printableBinaryZig` instead of the full default suite.

The persistent `test/test_cosmocc_host_tools` regression fails against the original bundle: 67 of 81 executable regular files have MZ headers. The Linux installation bootstraps assimilation through the bundled host-native ELF loader and checks every executable file afterward. `test-ape` separately requires the compiled application to retain its MZ header before running the shared CLI tests. All-system flake evaluation and all Linux runtime checks pass; the repair is committed as `ce9ccf8`. WSL-specific execution has not been repeated here.

The compiler input currently selects the native backend from a published `roc_luajit` snapshot. It does not generate LuaJIT output, but this experimental fork creates an unwanted upstream-tracking dependency. The preferred candidate is the official [Roc binary overlay](https://github.com/roc-lang/roc-overlay), which packages official native nightly releases. Pair the selected compiler with matching official `ZigGlue.roc` source and a compatible platform and Zig version.

Fresh upstream inspection on 2026-10-23 found overlay revision `d0ad2328b1d81e2f6dcfcdf1fc800d9e74838a4d` records the current platform's exact language pin, `nightly-2026-10-04-130536d`, for Linux and macOS on both architectures. That release names official compiler source commit `130536d915d4355d6152c7e20529a09a5a0cbe32`; the overlay exposes `compilerCommit` and the selected asset metadata as package passthru. This permits a matching-glue assertion without a manually maintained compiler fork or project-local release download recipe. It is the closest-version candidate for the dependency replacement, not a compiler/platform build result. Upstream PR #10782 merged on 2026-08-14, before that nightly; the later source-flake Darwin `broken` flag alone does not establish a failure in this binary package.

Upstream fixed one distributed macOS linking issue, including `roc glue`, in [PR #10782](https://github.com/roc-lang/roc/pull/10782), while its source-build Nix definition still marks Darwin broken at revision `38a3029`. That flag is not a new failure reproduction. Darwin verification has been prepared separately; no successful Darwin verification has been reported to this project yet. The acceptance target here is host-native compilation and shared PrintableBinary correctness tests, with Linux CI as the required execution environment, rather than a Roc cross-platform execution matrix.

The earlier unreachable source input was repaired in `cdefa95`. GitHub archive availability was checked directly. Cached local evaluation and CI do not independently prove a source remains downloadable, so a source-availability regression should bypass the existing source cache without altering the user's main Nix store.

## Optional type tag selected on 2026-10-20

### Current v1 wire contract and implementation boundary

The selected markers use exact UTF-8 bytes, independent of font rendering. Let `M` denote U+F000 (`EF 80 80`), `P` denote Greek rho U+03C1 (`CF 81`), and `B` denote Greek capital beta U+0392 (`CE 92`). The accepted opener is `MPB_` or `MPB1_`; the closer is `M/PB`. The ordinary ASCII underscore terminates the version. An omitted version and exactly ASCII `1` select v1; other spellings, including `01`, are unsupported. A complete reserved `MPB` prefix followed by a malformed or truncated header is an error in tag-aware mode. A reader can reject unsupported version spellings without buffering an arbitrary digit string.

| Control | Visible spelling | UTF-8 bytes | Effect |
| --- | --- | --- | --- |
| Bare v1 opener | `ρΒ_` | `EF 80 80 CF 81 CE 92 5F` (8) | Begin PB decoding |
| Explicit v1 opener | `ρΒ1_` | `EF 80 80 CF 81 CE 92 31 5F` (9) | Begin PB decoding |
| Closer | `/ρΒ` | `EF 80 80 2F CF 81 CE 92` (8) | Begin literal passthrough |
| Quoted marker | `` | `EF 80 80 EF 80 80` (6) | Emit one literal `M`; keep the current mode |

A bare opener/closer pair costs 16 bytes; an explicit-v1 pair costs 17. The closer is optional for a whole-stream frame. Quoting adds three bytes per literal martini. It quotes only the marker, never a protected body. Thus `MM` followed by `PB1_` emits a literal martini and treats the remaining characters in the current mode, rather than recognizing an opener. A quote sequence is consumed once. Produced bytes are never scanned again for controls or decoded again as PB glyphs.

There are two intended initial states: a tag-aware PB decoder begins in PB mode, while an excerpt decoder begins in literal mode. A closer switches either to literal passthrough until another opener. This is a two-state model without a nesting stack. Activation, final command spellings, redundant opener/closer policy, handling of incomplete prefixes shorter than the reserved namespace, and interactions with non-default preservation options must be qualified before implementing a public parser. These integration details are not silently resolved by the wire spelling.

Tagged-output encoding rejects an actual leading tag unless explicit raw-input intent overrides that guard. On 2026-11-01 the owner scoped this guard to tagged-output mode only: ordinary raw CLI encoding and the raw library codec stay unconditional. Neither an ordinary byte-encoded tag nor a decoded output tag proves accidental double encoding: both can represent intentional literal source bytes. Preserve those raw payloads exactly, and never apply a recursive encoded-tag rejection rule.

The recognition experiment observes the seven-byte opener namespace on the existing raw decoder's lookup-miss path, leaving production code unchanged. It preserves and independently verifies raw output; it counts namespace candidates, not validated frames. Version validation, quote handling, mode transitions, arbitrary-binary resynchronization, and incremental chunk boundaries are outside that prototype. Its timing cannot establish a complete framed decoder's slowdown. In particular, a malformed UTF-8 prefix can hide a marker within the existing raw fallback group; a future mixed-binary parser must scan literal bytes independently and carry partial marker state across chunks.

The Nix-built recognition package passed its focused Linux check at 00:56 EDT on 2026-10-24, using source `qvspfghybmr9sfq6ziv1m1sg2mx28k2w-printable-binary-source`. All seven independently generated fixtures match the prepared raw CLI. ReleaseSafe tests verify the repeated outputs, exact candidate counts, prefix mutation set, and work oracle. The actual optimized producer rejects deliberately disabled counting with `WrongCount` and corrupted decoded bytes with `WrongBytes`, without emitting measurement JSON. Linux probes link statically against musl after the first safety-test run exposed an unavailable system dynamic loader in the Nix sandbox. Those cached build checks do not substitute for fresh host measurements. The complete suite and fresh timing run remain pending.

The complete retry passed all 25 Linux Nix checks at 01:12 EDT on 2026-10-24, including the default hexadecimal-text seed regression and all C/APE/WASM malformed-input checks. Its complete check source is `/nix/store/2ysvvh714jymn82r4rrglb9m92xbrx72-xadskc5alg4kxp2j5lcm7svw5s4hdnm3-source`. The same admitted job then ran fourteen fresh recognition cases with the pinned shared engine. Every case verified work, completed in one attempt, and retained matching source fingerprints before/after (`726fb7a86b546535ec5f51ceb57ad328a6a5a010f42f1cafa6bdb5d6a94d214f`). The benchmark executable SHA-256 is `a1462de62b221fff33f596109c44fa5f93c55a90afbd435acde4d45b32b30360`. All records are `UNBASELINED`, with no approval or historical-pass claim; the campaign exits 3 for that reason. External history remains outside the repository.

Measurements used Zig 0.16.0 ReleaseFast, Linux x86-64/musl, and an AMD Ryzen Threadripper 3990X. Each case warms both variants three times, then alternates their order for five paired samples over approximately 16 MiB of encoded input. Twelve-core cases permit scheduling on twelve CPUs; the decoder still uses one worker. CPU deltas compare mean process CPU duration against the unchanged raw decoder. Rates count encoded input bytes in decimal MB per process CPU second, not decoded output or end-to-end CLI throughput.

| Input pattern | CPU delta, 1 allowed CPU | CPU delta, 12 allowed CPUs | Observer input MB/CPU s, 1 CPU |
| --- | ---: | ---: | ---: |
| Self-mapped ASCII | -0.45% | +3.86% | 1651.59 |
| ASCII with literal spaces | +10.86% | +11.71% | 416.67 |
| Complete mapping alphabet | +7.61% | +10.97% | 581.73 |
| Unknown UTF-8 mixed with ASCII | -5.40% | -5.42% | 412.81 |
| Sparse opener namespaces | +7.55% | +16.63% | 573.45 |
| Dense opener namespaces | +5.95% | +12.18% | 568.45 |
| Ordinary byte-encoded literal opener | +5.96% | +7.96% | 650.78 |

This single campaign does not establish a universal overhead percentage or a speedup from framing. It includes code-generation and allocation effects that have not been attributed separately. Notably, alphabet-only input has zero namespace candidates but still shows a measurable delta. Baseline CPU sample coefficients of variation range from 0.11% to 1.78%; observer values range from 0.27% to 7.50%. CPU and wall samples, exact byte counts, fixture definitions, and source/executable identities are retained in the external records. Full framing, quoted-marker interpretation, literal-region scanning, and chunk-boundary state require their own implementation and measurements. Production raw decoding has no observer added.

Encoder-ingress decision confirmed on 2026-10-23: v1 encoding rejects input that already starts with a tag, and offers an explicit raw-input override for literal source bytes. It does not parse and pass existing frames through during encoding. Together with reserved-prefix errors, exact v1 version spellings, and standard martini quoting, this settles the original two pending questions. One interface follow-up asks whether the guard covers all CLI encoding or only tagged-output mode; the raw library API remains unconditional. Parser implementation remains separate from the recognition measurement experiment.

Reserved-prefix decision confirmed on 2026-10-23: `ρΒ` reserves the opener namespace in tag-aware mode. Malformed or truncated headers are errors; literal examples must quote the martini. This avoids buffering arbitrarily long digit strings for literal fallback. The raw codec remains unchanged. The encoder-ingress decision is recorded above.

Version decision confirmed on 2026-10-23: an omitted version or exactly ASCII `1` selects v1. Other spellings, including leading-zero `01`, are reserved and produce unsupported-version errors in tag-aware mode. The raw codec is unchanged. This settles the version question noted in the earlier checkpoint below.

Decision confirmed at 21:00 EDT on 2026-10-23: v1 uses standard martini quoting. Doubling quotes the following martini marker only; it does not create a protected-body parser state, and decoding continues in the current mode. Literal examples can be encoded as ordinary source bytes, with the corresponding expansion. The earlier escaped-opener/closer whole-body protection proposal is superseded for v1. The later version decision above settles omitted and leading-zero versions. No framing implementation has been started.

Read-only codec inspection suggests a measurement candidate: recognize reserved markers on the existing decode-lookup miss path. Valid alphabet glyphs already take the successful lookup path, and the literal-prefix SIMD path need not acquire a separate per-byte marker test. This is a code-layout hypothesis, not a measured overhead claim. The canonical table contains digits and `_`, but none of U+F000, rho, capital beta, or ASCII `/`; underscores need no special sentinel role. Literal passthrough regions would need their own candidate scan, potentially filtering for the first UTF-8 byte before checking the complete marker. Compare absent, rare, dense, and chunk-split markers over ASCII-heavy, all-byte, and unknown-UTF-8 workloads. Measure verified optimized work with the shared profiling engine, separately for one and twelve cores, and keep input-byte rates distinct from decoded-byte rates.

Two specification risks remain beyond quoting. The proposed unbounded version-digit field needs an explicit malformed-prefix policy for bounded streaming state: reserving the recognized namespace and rejecting malformed headers differs from buffering arbitrarily long prefixes for literal fallback. Encoder ingress also needs a precise distinction between raw source bytes and already framed input; standard decoder quoting alone does not resolve automatic double-encoding prevention. Keep these decisions visible before implementing framing rather than inferring whole-body passthrough from the superseded protection proposal.

Revision accepted on 2026-10-23: the opener is now U+F000, Greek rho U+03C1, Greek capital beta U+0392, zero or more ASCII version digits, and an ordinary ASCII underscore: `ρΒ1_` or `ρΒ_`. The closer is `/ρΒ`. Keep the ASCII underscore because the leading out-of-alphabet martini already distinguishes markers, and the underscore only terminates the version field. The opener is 8 bytes plus its digit count; the closer is 8 bytes. U+F000 quotes itself by doubling under the standard quoting decision above. An optional closer switches decoding to byte passthrough until the next opener. Tagging remains opt-in and unimplemented. Malformed markers, encoder ingress, and initial decoder state still need an explicit contract. The following notes preserve earlier discussion, not the current marker spelling or quoting model.

The selected optional stream tag is `_ρΒ1_`, with code points U+005F, U+03C1, U+0392, U+0031, U+F000, U+005F. U+F000's martini silhouette depends on the font; recognition uses exact UTF-8 bytes. The raw 256-byte mapping remains unchanged. This is a selected tag spelling, not an implemented feature or a completed framing specification.

Additional U+F000 characters before the final underscore are proposed as escapes for literal leading tag spellings, including already escaped forms. Before implementation, define which boundary consumes the escape, whether the encoder inserts it automatically or requires explicit literal-input intent, and how original bytes are recovered without recursive unescaping. Prefix-only recognition is proposed; interior occurrences need no special handling for whole-stream type detection.

A second proposed guard recognizes the raw PrintableBinary-encoded form of the tag as possible accidental double encoding. This is not conclusive for existing raw streams: encoding a legitimate source whose first bytes are the tag yields exactly that prefix. Strict tag-aware errors versus raw-mode warnings, explicit raw overrides, and the interaction with literal-prefix escaping remain design choices. Acceptance tests must include literal tag prefixes, arbitrary runs of martinis, truncated and chunk-split prefixes, empty payloads, and byte-for-byte recovery without false-positive rejection of raw data.

The discussion subsequently raised a fixed single decoding pass, tentative preference for automatic handling, and encoded excerpts embedded in otherwise literal text. A proposed refinement is one optional start/end framing syntax, with a whole-stream payload represented by one frame. The selected opening tag is unchanged; a closing spelling such as `_/ρΒ1_` is a proposal, not an accepted delimiter. No nested frame interpretation or recursive decoding is proposed. Decode each original input region once and never scan produced bytes for new markers.

This refinement changes the earlier escape proposal: escape marker spellings only in literal text that remains outside encoded frames. A writer that knows which regions are literal can insert one extra martini automatically, and the reader can remove exactly one escape level. An encoded frame's body already uses the mapping alphabet, so it cannot emit the reserved tag glyphs directly. A body that starts with the encoded tag can legitimately represent original bytes starting with the literal tag; rejecting that body would break lossless recovery. The encoded-tag guard must therefore be scoped to a boundary where a frame header is expected, not applied to valid payload or recursively produced output. An explicit raw-input path is still needed because identical input bytes cannot communicate whether a marker is literal or intentional framing.

The opening tag is exactly 10 UTF-8 bytes (`5f cf 81 ce 92 31 ef 80 80 5f`). Under the hypothetical model of independent uniform random bytes, its probability at byte zero is 2^-80, about one in 1.21e24. Searching throughout a 1 GiB stream gives about 8.88e-16 expected starting-tag matches under that same model. These are calculations, not measured probabilities for natural text. Intentional documents, tests, or adversarial inputs can include the exact marker at will, so rarity does not replace literal escapes or explicit input intent. Framing scope and error policy remain proposals pending an accepted contract.

The later discussion distinguishes proposed PB decoding outside fragments from excerpt expansion over literal outside bytes. In the proposed framing-aware `decode`, untagged outside glyphs remain PB input; a single-martini fragment decodes once, while protected fragments lose one escape level and preserve their enclosed representation. A separate `decode-excerpts` operation copies outside bytes unchanged. The current Zig decoder has no such framing support: it decodes recognized glyphs everywhere and passes unrecognized characters through. Neither input mode should rescan produced bytes for new instructions.

Recognition cost and frequent switching remain open measurement/design questions. The proposed closing tag `_/ρΒ1_` is 11 UTF-8 bytes, making an ordinary pair 21 bytes; adding one U+F000 to each delimiter makes the pair 27 bytes. A two-byte replacement for only the leading underscore would make a pair 23 bytes, or 25 bytes if both underscores in both delimiters were replaced. These are exact byte counts, not runtime measurements, and no alternative spelling is selected.

The underscore is self-mapped and may be copied by the existing 16-byte ASCII prefix fast path. An unmapped leading glyph could simplify marker dispatch. Keeping the selected spelling is also possible: recognize an unmapped interior glyph such as rho, with enough input context to account for the preceding underscore and read-buffer boundaries. Candidate recognition belongs outside the successful mapping hot path where possible; do not add a full tag comparison at every input byte or an unnecessary whole-input prescan. Compare optimized implementations on representative and adversarial underscore-heavy input, sparse and dense frames, and chunk-split markers before claiming a slowdown percentage. Raw mode can retain its existing path if framing is a separate operation. Use the performance-profiling contract for measurements.

Individual literal glyphs should not require a delimiter pair. A proposed short escape within PB-decoded content is backslash plus one complete UTF-8 character: `\¶` would yield literal UTF-8 `¶` instead of LF, with one added byte. Literal backslashes need an explicit representation too. The scope must leave ordinary text outside excerpts unaffected, and marker escapes must prevent recognition of an escaped opener. Self-mapped ASCII and unknown glyphs already pass unchanged in the current default decoder. Arbitrary preservation options also require care because they can allow reserved marker bytes through an encoder. No short-quote grammar or new codec behavior has been implemented or accepted yet.

Correction on 2026-10-21: the bare-backslash short-quote proposal above is withdrawn for raw PB. Existing consumers may recognize PB by requiring every UTF-8 character to belong to the canonical alphabet; ASCII backslash is deliberately outside that alphabet and encodes as `⧷`. Preserve this alphabet-only property of default raw output. Choosing an existing PB glyph sequence as a new escape would also need a separate grammar, because every such sequence already has a raw byte interpretation.

Literal UTF-8 already has an alphabet-preserving representation. Literal `¶` consists of bytes C2 B6, which encode as `ĺİ`; one ordinary decode recovers literal UTF-8 `¶`, without scanning that produced character again as LF. This representation is four UTF-8 bytes rather than the two-byte original, and needs neither a delimiter pair nor a new quoting rule. The existing compiled CLI verified `encode("¶") == "ĺİ"` and `decode("ĺİ") == "¶"`, with recovered bytes C2 B6. This was a focused diagnostic, not a new persistent regression suite or a framing implementation.

The selected tag itself intentionally contains characters outside the raw alphabet. Alphabet-only recognition therefore applies to raw payload, not an entire tagged or mixed stream. Any supported framing needs an explicit framing-aware recognizer that validates its grammar and checks the appropriate PB regions. Do not broaden the raw alphabet to include tags or quote characters merely to make the existing heuristic accept a new format. Framing remains unimplemented and its grammar remains open.

## Textual consumer handoff

A CJK/logging consumer requested notification after a usable textual codec is
published and its exact commit passes CI. The size-study prototype alone does
not satisfy that condition. Read-only integration inspection found the consumer
uses this project's Rust crate with spaces-preserving encode/decode options.
Prioritize a usable Rust library increment, retain that integration case in its
tests, and include the exact revision, API examples and canonicality rules in
the eventual durable-inbox handoff. Do not change the consumer repository or
claim delivery/acknowledgment before the requested condition is met.

The experiment increment `d8963ca8a91bf661d18ae4feb3f4669a2718413d` is now
published, origin/yolo was independently verified, and exact-commit Mechatron
Prime CI passed all 27 targets in 37 seconds. This is not yet a working Rust
textual API, so no ready-for-adoption message has been sent. The payload grammar
and conditional inverse argument are drafted in
[the codec-mode contract](../CODEC_MODES.md); production implementation proof
and framing integration remain separate work.

The remaining policy defaults were accepted on 2026-11-02: preserve ordinary
ASCII spaces and ZWJ/ZWNJ, along with combining and variation marks. Other
Unicode 16.0 Cc/Cf/White_Space scalars are byte-encoded. The production policy
is frozen in the Rust crate and independently checked against the pinned Node
Unicode property database; the older size experiment retains its original
conservative defaults for reproducibility.

The first Rust implementation now provides tagged `textual::encode`/`decode`,
explicit untagged payload functions, typed canonicality errors, and
`decode_auto_with_options` for new tagged values alongside legacy
spaces-preserving logs. Raw functions and installed CLI behavior are unchanged.
Whole-value tags accept omitted/exact v1 and an optional matching final closer;
mixed excerpts, bounded-memory streaming and other language ports remain open.
The source/tag inputs to library encoding are always raw, not recursively parsed.

TDD first established seven failing Rust textual tests. The implementation then
passed exhaustive one-/two-byte round trips, all Unicode scalars, literal-marker
and replacement-glyph quoting, malformed-byte controls, canonical rejection,
and legacy-log migration. An independent Node differential compares exact
encoded bytes and recovery for every Unicode scalar and arbitrary-byte cases.
The extracted Cargo package builds/tests offline without repository-parent
dependencies. The complete `./test --option substitute false` gate passed on
2026-11-02, including all required Linux checks; non-host platforms were not
executed by that command. Compilation/setup are not claimed as test execution:
the Rust check's build phase took 42 seconds, while its seven new native tests
took 0.05 seconds. The complete-suite fresh execution budget is still open.
Published as `cf9859d4f6bbda0a7732131556d1336323149fc9`; origin/yolo was
independently verified and exact-commit Mechatron Prime CI passed all 27 targets
in 40 seconds, finishing 2026-11-02T07:06:18Z. The requested durable handoff
includes the revision, typed Rust adapters, legacy-log migration and scope
limits. Delivery and a native session notification succeeded; the recipient
acknowledged the exact revision at 02:07 EST and owns the consumer integration,
including error propagation and upgrading readers with writers. Consumer CI
was initially pending. The recipient later reported adoption at consumer
revision `8a100f8`, pushed after its full local Nix gate: tagged CJK stays literal,
legacy literals remain readable, malformed values propagate errors, and mutants
that swallow errors or drop legacy support fail. Exact-commit consumer CI was
then independently verified: all three targets passed in 15 seconds, finishing
2026-11-02T07:50:45Z. No consumer source/lockfile/hash was modified here.
Next: port the accepted contract to the Zig library, then integrate explicit
CLI selection and finish the remaining framing/verification work.

The Zig port first reproduced three failing payload tests and, after the
payload increment passed, a separate failing tagged-value test. It now exposes
`textual.encode`/`decode`, `encodePayload`/`decodePayload`, and `decodeAuto`,
with the same fixed policy, canonicality rule, whole-value framing and legacy
options as Rust. The policy generator checks both language tables. Focused
Nix checks passed for both libraries, including independent exact-byte Unicode
scalar differentials and injected failure at each Zig allocation. The complete
gate first exposed the benchmark's relocated core missing its new relative
imports. Staging those declared in-repository sources alongside the instrumented
copy repaired the closure without bypassing the safety/defect controls. The
complete Linux gate then passed at 02:16 EST on 2026-11-02. Installed CLI behavior
and C ABI remain unchanged. The benchmark build phase took 83 seconds including
compilation; it is not a runtime measurement. CLI integration is next. Two
existing test-output leaks were observed and queued: the FFI hexlike smoke
pipeline emits unasserted status, and the Elixir test VM warns about its locale.

The Zig library increment was published as
`964e7298475715983479bfa55ba66dcb4d26fd76`; the fetched remote matched it and all
27 exact-commit Mechatron Prime CI targets passed in 40 seconds, finishing
2026-11-02T07:19:38Z. CLI integration keeps default encoding and plain `-d`
bytewise, avoiding a change to existing raw pipelines. Explicit `--textual`
selects tagged textual encoding/decoding; `--untagged` selects its payload API,
`--raw-input` overrides only the tagged encoder's leading-tag guard, and
`--decode-auto` selects tagged-or-legacy decoding. These flag spellings are an
implementation choice for the accepted mode/tag policy. Textual mode does not
use bytewise formatting, container, passthrough, or arbitrary preservation
options; `--spaces` is redundant and permitted. Auto decoding applies spaces
and stripping options only to bytewise input, never to textual canonicality.
Input ranges remain raw input-byte ranges, not scalar/glyph/column coordinates.
The first real CLI regression failed on the missing textual option; the new
mode-policy option sets are exhaustively classified in pure tests. The complete
local Linux gate passed on 2026-11-02 at 02:24 EST, retaining the shared raw CLI
contracts, scalar differentials, safety/defect checks and all five cross-target
headers. The first explicit CLI version is ready to ship. Mixed excerpts, bytewise tagged-output emission and
bounded-memory streaming are not included in this increment.

The CLI increment is committed as `39ffadcba1c806ba930a7dd9dbbccff999202dbf`.
Its full local gate passed before commit. The real Nix-backed canonical build
published the verified native Zig host product, separate from all tests; the
PATH command now exposes textual mode, and a CJK round trip through that exact
command succeeded. The pushed remote matched the revision; all 27 exact-commit
Mechatron Prime CI targets passed in 45 seconds, finishing 2026-11-02T07:31:19Z.
For mixed excerpts, one consequential delimiter transition remains explicitly
queued for the owner: reject a new opener while a frame is active and reject a
closer in literal mode, or permit implicit frame switches and literal stray
closers. Recommend rejecting misplaced delimiters without nesting; an optional
final closer still permits EOF to terminate the active frame. Do not implement
that unresolved transition while proceeding with independent test cleanup.

The cleanup shipped as `04a985e2d034994050987e4f4b3f32c741e9f49e`; the fetched
remote matched it and all 27 exact-commit Mechatron Prime CI targets passed in
36 seconds, finishing 2026-11-02T07:56:08Z. The consumer then identified that
the leading private-use marker can disappear visually. A new documentation
regression failed before explicit header tables were added; it now compares
both escaped spellings and all nine UTF-8 bytes. README examples identify the
marker explicitly. The complete local Linux gate passed at the next checkpoint
on 2026-11-02 before committing these documentation changes. Next unblocked
execution-budget work is retaining exact Rust artifacts without replacing or
dropping any current native/package/CLI checks.

The header documentation fix shipped as
`27a92c3c4e6db4975d4a7c47e1ece9c626e59e2d`; the fetched remote matched and all 27
exact-commit Mechatron Prime CI targets passed in 46 seconds, finishing
2026-11-02T08:17:16Z. Rust artifact retention first failed on the missing native
manifest, while all existing Rust checks still passed. The export now retains
all five native Cargo test targets, the raw Rust CLI, textual adapter and Zig
reference, plus a path-free projection of Cargo's target metadata. The installed
check validates the complete target set and re-executes the tests after fixup;
omitted and duplicate target controls fail. All old package/native/doc/CLI checks
remain unchanged. Focused retention checks and the complete local gate pass.

Fresh, confined execution of the five retained native executables (15 native
test functions) passed without compilation. External latency jobs
`pb-rust-native-20261102-0336-cores1` and `-cores12` recorded 0.168484201 and
0.157163876 seconds of execution, with 0.659583953/0.481253228 seconds of
resource-admission/shell setup and 0.947919948/0.752272412 seconds from recorder
begin to finish. Both source identities remained
`01a5ea459ee95691ca6621242d13715910405d63e082e28f9b41ef2ad4938e04`.
The CPU allowances were one and twelve CPUs, not twelve suite workers. These
are native-only observations, not a complete-suite result or comparative
speedup claim. Initial launcher attempts ran no measured tests: the latency
recorder's pending state follows `TMPDIR`, which the resource-admission wrapper
changes. The corrected invocation preserves that wrapper's task scratch for
the workload while explicitly using the original recorder scratch only for
recorder processes. Those failed/incomplete observations remain in history.
Packaged-crate/runtime and other-language preparation still need completion
before claiming a fresh complete-suite budget pass.

Rust artifact retention shipped as
`9ba1ab407a19d3181a64751da52bf9174d13ec0b`. The fetched remote matched; all 27
exact-commit Mechatron Prime CI targets passed in 36 seconds, finishing
2026-11-02T08:36:45Z. Runtime check source filtering is the next feedback-latency
increment: the unfiltered source failed both the path-set classifier and a real
store-identity comparison between fixtures differing only in PLAN content.
The corrected filter excludes seven exact workflow/documentation paths, not
classes of Markdown or whole directories. It retains selectors, entrypoints,
Nix expressions/lock, ignore rules, all fixtures and future files. The full
documentation check keeps its unfiltered source. Focused classifier/identity
checks pass. Evaluating all 26 actual check derivations before and after a
context-only edit changed exactly `test-docs-benchmark-contract`; the other 25
derivations were identical. The complete local gate passed, including the
unchanged tag-probe safety and real-mutant checks. Its roughly 88-second
tag-probe build phase remains compilation, not execution. This removes
avoidable invalidation, not fresh test execution. The next actionable increment
is retaining exact native CLI/domain-test artifacts for compilation-free
contract execution; full-suite runtime remains unqualified.

The runtime-source change shipped as
`e3acf815af3b0d5453d8e61daf2d1044abe3b393`; the fetched remote matched and all
27 exact-commit Mechatron Prime CI targets passed in 44 seconds, finishing
2026-11-02T08:42:49Z. The next retention regression first failed after the old C
tests passed because the installed CLI artifact was missing. C, Zig and separate
APE checks now retain their exact executables and run the same contracts after
fixup rather than mixing execution into compilation. C retains its exhaustive
65,536-input decoder test; Zig retains its textual CLI cases; APE retains its MZ
header check and distinct role. The driver also rejects all three missing and
symlinked artifact roles, five unknown roles and three invalid argument counts.
Focused checks pass. The new compiler-free `.#tests` shell supplies the existing
fixtures' runtime dependencies explicitly; the ordinary development shell did
not supply Python, which the fresh run exposed rather than silently skipping.

Fresh, confined native-trio jobs
`pb-native-cli-trio-20261102-0350-cores1` and `-cores12` passed without compiling.
Execution took 4.907075310 seconds with serial roles/groups on one CPU and
1.663718260 seconds with three concurrent roles, four CLI groups each, on twelve
CPUs. Admission/shell setup took 2.170673304/0.484840566 seconds; recorder
begin-to-finish totals were 7.240537417/2.266985314 seconds. Both source identities
remained `0ad8e6d614d36d7f6380a4048914c77fe9e0da99cc8fb13e62b0bb8ccb5fc211`.
The four counted outer units are the driver-control group and three complete
native contracts, each retaining its 224-line ordered CLI inventory. This is a
subset observation, not a full-suite budget pass or historical speedup claim.
Earlier launcher/dependency failures remain ERROR/incomplete in history. One
launcher failure also exposed systemd argument expansion of inline Bash arrays;
that diagnosis was delivered durably to the CI service project without changing
its launcher or bypassing resource controls. The complete local gate passed,
including the unchanged tag-probe controls. The next unblocked preparation item
is retaining the isolated packaged-crate tests and their independent inventory;
the full-suite execution-budget item remains open.

Native CLI artifact retention shipped as
`ab9d64f6a7569954c66d0eab8d979defb402317f`; the fetched remote matched and all
27 exact-commit Mechatron Prime CI targets passed in 38 seconds. Packaged Rust
retention first failed because the installed `packaged/` bundle was missing,
after the existing package/source/CLI checks passed. Both source and extracted
crate builds now export their own five test targets and independent path-free
Cargo inventories through one shared exporter. Installed checks re-execute both
sets after the package scratch tree is removed. The archive is still built and
tested offline in an isolated directory; no source or package checks were
removed. Export controls retain all lib/bin/test roles, ignore non-test compiler
records, and reject omissions, duplicates, empty sets and unsafe names before
creating output. A stricter unsafe-name control failed before adding its
specific validation diagnostic, preventing an unrelated filesystem failure from
satisfying that negative test. Focused artifact checks and the confined export
controls and the complete local gate pass.

Fresh confined jobs `pb-rust-retained-20261102-0405-cores1` and `-cores12`
executed the source bundle, package bundle and export controls without a
compiler. Execution took 0.785261107/0.748686840 seconds; combined
admission/shell setup took 3.590053360/3.067978641 seconds, and recorder
begin-to-finish totals were 5.287970435/3.933161776 seconds. Source identity stayed
`c38eab7a57b8cbc2972749349196a178845cbf73075e5cca8c7b2da7c5ef737f`.
The three recorded outer units include ten native executables (30 native test
functions) and the export-control group. Outer units run sequentially; one and
twelve denote CPU allowances, not twelve worker processes. This remains a
subset measurement, not a complete Rust/whole-project execution claim or a
historical speedup. Setup dominates result delivery in these observations;
queue admission and shell/evaluation are not separately attributed yet. The
next prepared-run integration should split those phases rather than treat the
three-second setup as zero. Next unblocked work is reusing declared exact
prepared CLI artifacts in remaining checks, then retaining the remaining
runtime artifacts without dropping their assertions. Final review identified a
circular package-inventory check: it used the exporter's projection as its own
expected metadata. A separate original-Cargo-metadata requirement failed before
the package harness preserved that input outside the exported bundle. Both
source and package installation checks now compare against Cargo's original
metadata. A producer-fault fixture that omits a non-test metadata target must be
rejected in both roles, before attempting fixture execution. The earlier timing
observations precede these stronger controls and remain historical subset
evidence; the final strengthened gate must pass before publication.

The strengthened full gate passed. A subsequent attribution launcher had a
multilayer-quoting error: its measured `bash -c` received no program, while the
three test commands ran outside that measured child. The recorder rejected the
observation despite the caller reporting success, preserving the real child
failure. Those commands only created private temporary fixtures or read/run
retained artifacts; they did not publish products or touch selectors. A shared
checked-in retained-Rust runner now replaces inline test code and is reached
from the mandatory Nix installation check with the original Cargo metadata.
Fresh measurement must use that script through the confinement adapter, never
the failed observation. Its admission split did identify about 0.11 seconds of
admission/launch versus 2.47 seconds entering the Nix environment, but its
execution duration is invalid. Other compilation was active on the shared host
(11 compiler processes; load averages 29.22/51.08/47.27 before that attempt).

The file-based runner and strengthened original-metadata checks passed the
complete local gate. Runner controls inject each of the three group failures,
verify all groups still run, retain exact arguments with spaces, cover both
metadata-selection forms and reject invalid arities. Final fresh, confined jobs
`pb-rust-retained-runner-20261102-0425-cores1` and `-cores12` passed both real test
bundles plus exporter and runner controls. Execution took 0.878890302 and
0.865120314 seconds. The four outer units cover ten native executables (30 test
functions), nine export controls and eight runner-adapter cases. CPU allowances
were one and twelve; the outer groups remain sequential. Source identity stayed
`946ea87b7edb6931358bf36ea0c2f7630b4bf6c02ba41a385cf4b506f426e450`.
Admission/launch took 0.121144842/0.121184647 seconds; Nix environment entry took
2.540488686/0.403094282 seconds; recorder totals were
3.833147232/1.541064424 seconds. This localizes the variable setup cost to Nix
environment entry rather than admission; finer evaluation/cache/load
attribution remains unknown. The host had eight compiler processes and load
averages 29.32/37.76/40.21 before this pair. These are subset observations, not a
whole-project budget pass or approved historical comparison. Remaining runtime
preparation should reuse exact artifacts and one admitted runtime environment,
not enter a new shell or compile again for every subsuite.

Packaged Rust retention shipped as
`cfa62ae973b0f93b7090c59dd9f4e9887ea88a55`; the fetched remote matched and all
27 exact-commit Mechatron Prime CI targets passed in 41 seconds, finishing
2026-11-02T09:30:46Z. The next dependency-context regression failed against the
old check graph, which separately built native CLI copies. Layout, container,
Rust, Elixir and Roc differential checks now consume exact retained C/Zig/FFI
artifacts through declared same-system Nix dependencies. The Zig result retains
its static archive too; the FFI adapter links it with the unchanged `-O2` flags.
The C CLI stays `-O3`, and the native Zig CLI/library stays ReleaseFast, matching
the former default `zig build` mode. No executable source, assertion, safety
profile or portable-runtime gate was removed. The contract verifies producer
derivation contexts and removes explicit Zig compiler inputs from consumers.
The complete Linux gate passed, and `nix flake check --all-systems --no-build`
passed for x86-64 Linux, ARM64 Linux and ARM64 macOS. Foreign evaluation does
not establish foreign execution. No runtime speedup or full-suite latency pass
is claimed from this dependency refactor. Next is retaining module-symbol
archives and extracting robust fresh analysis, including a regression for
malformed consumer archives whose `nm` failure was hidden by a pipeline.

Native artifact reuse shipped as `351feffb781666fcbf0d12d0c3e5d2699a3632aa`;
the fetched remote matched and all 27 exact-commit Mechatron Prime CI targets
passed in 47 seconds, finishing 2026-11-02T09:46:57Z. Module-symbol extraction
then reproduced five defective outcomes: malformed consumer acceptance,
malformed FFI failure for the wrong reason, missing consumer work acceptance,
and ignored injected tool failure/warning. Compilation now stays in the Nix
build phase; both archives are retained and analyzed after fixup. The FFI
archive is the exact declared Zig check dependency. Pure classifiers cover all
53 alphabetic/unknown symbol-type rows as included/excluded sets, malformed
rows and the fixture export. The adapter checks real tool status and preserves
even newline-only diagnostics before counting symbols. Its positive genuine
archives and fourteen rejection controls pass, including corruption, missing
files, polluted/absent namespaces, empty consumer work, tool failures/warnings,
missing tools and invalid arities. Focused checks pass; the complete gate and
fresh execution measurement remain next. No ABI implementation changed.

The complete Linux gate and all-three-system evaluation passed. Fresh confined
jobs `pb-module-symbols-20261102-0506-cores1` and `-cores12` passed both outer
groups: pure classification and all fifteen genuine/fault adapter cases.
Execution took 0.688327027/0.803374676 seconds with source identity fixed at
`5642da4b369d0f0909fe6808bbc054a72d4aad528d7a5210e0f283539371fd69`.
One/twelve are CPU allowances, not parallel classifier workers. Admission/launch
took 0.369892532/0.099124356 seconds; Nix environment entry took
6.793827815/0.387616463 seconds; recorder begin-to-finish totals were
9.374921406/1.483716907 seconds. Instrumentation accounted for
1.237910302/0.040814408 seconds. Ten other compiler processes were active before
the pair, with load averages 22.68/27.86/27.53. Setup/instrumentation remain
visible findings, not execution time or zeros; finer cold-cache versus host-load
attribution is not established. These are subset observations, without a
historical speedup or whole-suite budget claim. Next unblocked work is retaining
the remaining Elixir/Roc runtime artifacts and wiring one bounded complete fresh
runner, keeping unsplit compiler/test work explicit.

Test-cleanup TDD reproduced the FFI smoke's leaked statistics and accepted
stage defects after extracting the existing shell workflow without errexit.
The old hexlike pipeline could hide an encoder failure behind a successful
decoder. The replacement checks all four stage exit codes explicitly, captures
and validates exact size/rate transcripts, compares restored bytes, and rejects
eight deliberately injected exits/diagnostics. Both the real adapter and the
no-fault injection adapter must pass first. Inputs are deterministic all-byte
data; tests run only in disposable/Nix-owned outputs. FFI compilation and check
execution now have separate phases, and the prepared binary/input are retained
for fresh runtime measurement rather than forcing another compilation.

A new Elixir runtime assertion failed with native filename encoding `:latin1`.
The pinned VM's `+fnu` option fixes that underlying assumption instead of hiding
its warning. Unit order and the 8 KiB cross-language fixture are seeded. Reusing
the existing PRNG exposed its invalid Lua module path; resolving its bundled
hash module relative to the script now works from both repository root and
utility directory, producing identical fixtures. Focused FFI/Elixir Nix checks
pass. The complete Linux gate passed on 2026-11-02 before the fresh measurements
below; no full-suite fresh execution latency claim follows from build results.

Fresh runs `pb-ffi-smoke-20261102-0241-cores1` and
`pb-ffi-smoke-20261102-0241-cores12` execute all ten FFI smoke/control cases using
the exact prepared artifact, private tmpfs outputs and a read-only host view.
The shared latency recorder measured execution at 0.397 and 0.459 seconds,
with begin-to-finish totals of 0.477 and 0.531 seconds. No compilation occurred
inside those spans. `taskset` constrained CPUs to `0` and `0-11`; the records'
concurrency labels denote those CPU allowances, not twelve parallel workers.
The harness remains serial. Both runs retain identical before/after source
identity `b2627d13fa777b68693a8342e1598e05ba3b70c4418997698432e88f41e0ccb7`.
These are subset budget passes under the existing resource envelope, not a
complete-project latency pass, comparative speedup or baseline-epoch approval.

## Latin-friendly alphabet investigation: unadopted candidate

A bounded Node/Unicode 16.0 experiment kept the low half of the current map and
replaced its 128 high-byte glyphs with lowercase mathematical Latin-looking
symbols. The five contiguous styles start at U+1D41A, U+1D482, U+1D5BA, U+1D5EE
and U+1D68A. Iterate letters a–z, five styles per letter for a–x and four for
y/z: this defines 128 distinct four-byte scalars, ordered by the underlying
letter. Example a forms: `𝐚 𝒂 𝖺 𝗮 𝚊`; z forms: `𝐳 𝒛 𝗓 𝘇`. They are mathematical
symbols with compatibility decompositions, not ordinary prose letters.
[Unicode 16.0 character data](https://www.unicode.org/Public/16.0.0/ucd/UnicodeData.txt)
records those identities; the pinned Node property/normalization checks agree.

Four 262,144-byte fixtures compare current versus candidate textual payloads,
including nine bytes of header accounting, with ordinary spaces/joiners
preserved. Random bytes use xorshift32 seed 42; CJK repeats `中文 日本語 한국어`,
and Latin repeats `Příliš žluťoučký kůň. Zażółć gęślą jaźń. Őrült tükör. ĂÂăâ ȘșȚț.`.
Prefixes are cut at byte boundaries, so a final incomplete scalar is intentionally
possible. Half-CJK concatenates half the random prefix with half the CJK prefix.
Both experimental decoders recovered every fixture exactly.

| Input | Current textual | Candidate textual | Current bytewise |
| --- | ---: | ---: | ---: |
| Seeded random | 1.781× | 2.628× | 1.852× |
| Half CJK | 1.390× | 1.813× | 1.983× |
| CJK | 1.000× | 1.000× | 2.115× |
| Latin sample | 1.415× | 1.000× | 1.830× |

This is a one-seed exploratory size result, not a throughput measurement or
adopted format. Applying the candidate to bytewise too would increase its
random-data ratio to 2.843×. Keeping compact bytewise unchanged and considering
a new textual version is therefore the stronger direction for evaluation.
All 128 candidate glyphs collapse to only 26 ASCII letters under NFKC, so
normalizing the encoded representation cannot preserve bytes. NFC stability
does not make NFKC safe. Font coverage, stylistic distinction and actual terminal
columns remain unverified; Unicode's width property alone is insufficient for
terminal layout. [Unicode 16.0 width guidance](https://www.unicode.org/reports/tr11/tr11-43.html)
explicitly calls for terminal-specific handling.

Replacing only the high half still leaves twelve Latin-script low-byte glyphs:
`ª ȯ ʘ Ɣ º ɨ Ƶ ǁ ǀ ǃ Ꞩ Ɂ`, representing bytes
`07 0e 0f 10 13 16 1a 1d 1e 21 24 3f`. They would still require literal quoting;
this candidate is not a complete Latin-free alphabet. Its four-byte entries
also require a fresh audit of every production buffer/lookup path before use.
The owner has a queued font-preview question. No alphabet has changed. Since
textual v1 is now used in persisted consumer logs, any incompatible map must
get a distinct format version and retain v1 decoding, not silently replace v1.

## Decisions that remain deferred or on hold

- Container metadata injection is specified in [the approved design](../plans/2026-07-21-container-metadata-injection-design.md), but remains a deferred feature rather than the active milestone.
- Reusable encode/decode output capacity is conditional on an actual consumer need. The current owned-slice API shrinks its allocation before returning; changing ownership requires an explicit API design. Repeated calls must not expose stale bytes from an earlier, longer result.
- The raw Rust GUI/Zig transport protocol is explicitly on hold pending its specification. Container-format work does not authorize inventing that protocol.
- Container-only table-driven CRC32 optimization remains parked until explicitly resumed. Benchmark work uses the shared performance-profiling contract.
- The old speculative Zig decode optimization task was superseded by the measured decoder-table and SIMD work delivered in July. Do not reopen it merely because an older plan entry was unchecked.
- Integrated compression was declined. Compression belongs in the caller's pipe chain. Its abandoned design considered an LZMA2 library versus shelling out, but no implementation is queued.

## Reconciled historical work

The earlier web-interface hold was resolved by the approved Encode/Decode tab design delivered in `7b70844c`. Node container support followed in `9dda0bbd`; the June 27 checkpoint records the remaining Zig, C FFI, standalone C, and Lua implementations as delivered. The existing `test-container-*` and `test-container-cross` checks cover those contracts. The old unchecked container and web tasks are therefore completed history, not outstanding owner decisions.

The retained container contract has schema version 1, snake_case keys, lowercase eight-digit CRC32 values, `.pbf.json` names, and the `data` value serialized last. `--spaces` is supported without a schema field: encoded CRC probing distinguishes preserved data spaces from transport whitespace. Incompatible preservation flags fail in container mode. The C FFI null-preservation pointer guard and shared mapping checks were delivered in July.

The full pre-reconciliation plan is recoverable with `git show cdefa95:PLAN.md`; its completed checkboxes are retired in [PLAN_LOG.md](../PLAN_LOG.md). It also records an old stale-base recovery: core work was moved from `dd0f8014` onto `yolo` at `3a6682dc`, while `ef7496c2` was retained as a historical safety net. This reconciliation does not delete or rewrite any branch or historical commit. Current project instructions use Git directly and Mechatron Prime CI; obsolete Jujutsu-only and retired CI instructions in old checkpoints are historical.
