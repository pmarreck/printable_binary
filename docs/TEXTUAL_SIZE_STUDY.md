# Experimental textual encoding: output size

This study compares output byte counts, not throughput. Both textual grammars
are experimental; neither is a production CLI mode or a completed framing
implementation. The bytewise format is unchanged.

## Main result

Reusing PB glyphs for malformed bytes avoids an expensive escape prefix per
byte. In these fixtures it makes textual output slightly smaller even for
uniform-like random data, and substantially smaller for non-ASCII text. Literal
PB-glyph-heavy text is an important counterexample: quoting can make it larger.

Following the experiment, the selected implementation direction is arbitrary-byte
textual input with compact PB fallback, martini quoting and strict canonical
decoding. The hex grammar remains a comparison only. Production integration and
the joining/format-control policy still require completion.

The table shows mean output/input byte ratios over three seeded runs. Textual
totals include one nine-byte `ρΤ1_` opener; bytewise totals are untagged.

| Synthetic input | Bytewise | Textual: PB fallback | Textual: explicit hex fallback |
| --- | ---: | ---: | ---: |
| Seeded random bytes | 1.85× | 1.79× | 3.49× |
| Deflate-compressed mixed data | 1.85× | 1.79× | 3.51× |
| 25% CJK text, 75% random | 1.90× | 1.61× | 2.89× |
| 50% CJK text, 50% random | 1.95× | 1.43× | 2.28× |
| 75% CJK text, 25% random | 2.00× | 1.24× | 1.67× |
| CJK text | 2.05× | 1.06× | 1.06× |
| 50% multilingual text, 50% random | 1.91× | 1.51× | 2.37× |
| Multilingual text | 1.96× | 1.24× | 1.24× |
| Accented Latin text, including reserved glyphs | 1.59× | 1.42× | 1.42× |
| ASCII log text | 1.40× | 1.40× | 1.40× |
| Repeated literal `ă` (a current PB glyph) | 2.00× | 2.50× | 2.50× |

These are measured synthetic distributions, not universal size guarantees.
ASCII-sensitive punctuation, spaces, and controls retain their existing PB
mapping, so preserving ASCII does not eliminate their expansion. Reserved Latin
letters can still require quoting. Random bytes also contain ordinary ASCII
and accidentally well-formed multibyte UTF-8; no textual intent is inferred.

Approximately 42.8–42.9% of random source bytes required malformed-byte fallback.
Martini quoting added 1,878–1,965 bytes per 262,144-byte random input, plus the
nine-byte tag. The explicit alternative instead spent six UTF-8 bytes per
malformed source byte. The compact candidate retains the current three-times-
input worst-case payload bound: ASCII/raw-byte mapping costs at most three
bytes per source byte, preserved scalars do not expand, and scalar quotes also
fit within that bound. A header is additional. That bound is not a promise that
textual output is always smaller than bytewise output.

## Candidate grammars and verification

Both candidates scan source bytes greedily for valid UTF-8 scalars. ASCII uses
the current PB mapping. Unicode Cc, Cf, and White_Space characters use PB mapping
of their UTF-8 bytes. Other Unicode scalars pass unchanged, except literal
nonidentity PB glyphs and U+F000, which receive a U+F000 prefix. Thus LF becomes
`¶`, literal `¶` becomes `¶`, and literal U+F000 doubles.

For malformed source bytes, `pb-fallback` emits the ordinary PB byte glyph;
`hex-escape` emits U+F000, ASCII `x`, and exactly two uppercase hexadecimal digits.
Neither needs to emit malformed UTF-8. This conservative experimental policy
escapes joiners too; the production joining/format-control policy remains open.

The prototype decoder parses once and then re-encodes the recovered bytes to
reject noncanonical spellings. For example, bytewise glyphs spelling the UTF-8
bytes of `中` are rejected because the encoder would preserve that scalar.
Redundant ASCII byte escapes, unnecessary quotes, incomplete escapes, malformed
Unicode strings, and raw sensitive characters are also rejected. This whole-
buffer validation is not evidence of production streaming cost or throughput.

Every measured case recovers the source bytes under both candidates. Each
bytewise baseline matches the pre-existing JavaScript encoder and an independent
Nix-built Zig CLI. The reference invocation explicitly disables the existing
already-encoded-input heuristic, while retaining exact-byte, successful-exit,
and clean-stderr checks. This matters for deliberately glyph-heavy input.

Required checks in `./test` cover all 256 one-byte inputs, every reserved map
glyph, all C0/C1 controls, canonicality negative controls, exact size ledgers,
text-mixture fractions, and the reference adapter's arguments/failure handling.
The UTF-8 classifier is independently checked against Node's native validator
over all 65,536 two-byte inputs and representative three-/four-byte validity
boundaries. These tests support the experiment; they are not a formal proof of
the production implementation or every Unicode input.

## Reproduction and evidence

The fixtures use 262,144 seeded bytes from `random` 0.4.0, seeds 42, 43 and 44.
Text is inserted in whole 1,024-byte blocks, padded only at complete Unicode
boundaries. Fractions count deliberately inserted text bytes, not characters or
all incidentally valid UTF-8 in the random portions. Compressed fixtures use
Deflate on the random input or the half-multilingual mixture. The pinned runtime
was Node 24.15.0, Unicode 16.0, zlib 1.3.2.

Prepare the probe through Nix, then supply deterministic source bytes:

```bash
nix build --no-link .#textualSizeStudy
random --seed 42 --binaryoutput --count 262144 | nix run .#textualSizeStudy
```

The optional `--reference PATH` argument checks a prepared bytewise CLI too.
On shared hosts, run the prepared probe under the configured resource budget
and isolation boundary. This study ran with bounded admission and a read-only
host filesystem. It used no private input files.

The complete byte ledgers, fixture hashes, source-stream hashes and binary
identities are retained in [the raw results](experiments/textual-size-results.json).
The experiment's code lives in [`tests/benchmark/textual_size/`](../tests/benchmark/textual_size/).
No speed, memory-growth, historical performance-gate, or complete-suite latency
claim follows from these deterministic size measurements.
