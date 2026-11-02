# Bytewise and textual codec contracts

Status: the arbitrary-byte textual direction, compact PB fallback, martini
quoting and default textual tagging are accepted. The Rust library provides the
first whole-value implementation, followed by the Zig library; other implementations and mixed-region
framing/streaming remain separate work. Textual v1 preserves ordinary ASCII spaces and ZWJ/ZWNJ, along with
combining/variation marks, and encodes other whitespace and format controls.
This document specifies the payload construction and its mathematical inverse
argument; it is not a machine-checked proof of an implementation.

## Domains and fixed inputs

Both source domains are finite strings of arbitrary bytes, including malformed
UTF-8. There is no normalization, replacement-character repair, or inference of
whether valid UTF-8 bytes were intended as text.

Let `g` be a fixed 256-entry byte-to-Unicode-scalar table. Its entries must be
distinct, each must be one valid scalar, and none may be the marker `M`, U+F000.
Any ASCII scalar appearing in the table must map to its own byte. The current
canonical table in `character_map.txt` satisfies these finite conditions. An
explicit preservation profile needs its own fixed table and the same checks;
it is not a reason to accept ambiguous alternate representations.

Let `A` be the table's output alphabet and `R` its non-ASCII members. Let `V(c)`
be the format version's fixed Unicode-preservation predicate. Controls and other
designated nonprinting characters are excluded from `V`. Literal `M` is always
quoted. A policy must be fixed independently of platform fonts or changing
runtime Unicode databases before publishing the format. The size experiment's
conservative Unicode 16.0 policy is evidence, not the final production policy.
Production v1 freezes Unicode 16.0 Cc/Cf/White_Space data, with U+0020, U+200C
and U+200D excluded from the sensitive set. Textual uses the existing byte map
with byte 32 mapping to literal ASCII space; the unused space glyph `␣` is
therefore ordinary preserved text, not a textual replacement glyph.

## Bytewise payload

Replace each source byte `b` with `g(b)`. The canonical target language is `A*`,
not arbitrary Unicode accepted by a permissive decoder. Decode each scalar
using the inverse table.

Proof: distinct entries make the one-byte mapping a bijection. UTF-8 scalar
boundaries make its output words uniquely separable into glyphs. Applying the
inverse to each glyph restores every source byte, while applying the forward
table to each inverse restores every word in `A*`. Concatenation extends the
two one-symbol identities to strings of every finite length. This argument
does not extend the guarantee to ignored formatting or unknown-glyph fallback.

## Textual payload

Scan source bytes from left to right using strict UTF-8 validity. Consume a
complete valid scalar when one begins at the current position; otherwise
consume one malformed byte. At EOF, incomplete sequences are malformed bytes,
not discarded text. Encode each resulting source unit as follows:

| Source unit | Encoded form |
| --- | --- |
| ASCII byte `b` | `g(b)` |
| Malformed byte `b` | `g(b)` |
| Literal marker `M` | `MM` |
| Non-ASCII scalar `c` excluded by `V` | PB mapping of every byte of its UTF-8 encoding |
| Preserved scalar `c` in `R` | `Mc` |
| Other preserved scalar `c` | Literal UTF-8 `c` |

For the default bytewise table this gives LF → `¶`, literal `¶` → `¶`, and
literal U+F000 → ``. CJK scalars ordinarily pass unchanged. A well-formed C1
control is represented using the PB glyphs for its UTF-8 bytes; a lone malformed
C1-valued byte uses its one byte glyph. These represent different source bytes.

### Token decoding

An unprefixed scalar is one token. `M` instead begins a two-scalar quote whose
second scalar must be `M` or a member of `R`; missing or other followers error.
For an unprefixed member of `A`, emit its one source byte. For another
unprefixed scalar, emit its UTF-8 bytes. For a quote, emit the second scalar's
UTF-8 bytes literally. Produced bytes are never rescanned as tokens.

This token decoder alone is lossless for encoded input but is not a bijection
over every syntactically permitted token string. For example, literal `中` and
three unquoted PB glyphs for `E4 B8 AD` would produce the same source bytes.

### Canonical target language

Canonical textual payloads obey an additional local representation rule:
greedily segment the decoded bytes using the source-unit rule above. Each unit
must have exactly the corresponding token spelling from the encoding table.
Thus a preserved scalar must use its literal or quoted spelling, never its
bytewise spelling; malformed bytes and excluded scalars must use their PB
spelling. Unnecessary quotes and raw sensitive characters are not canonical.

The whole-buffer Rust and Zig implementations check this rule by re-encoding
the recovered bytes and comparing exact input bytes. A production checker may
instead validate the same local conditions incrementally. Accepting redundant
spellings for convenience would widen the language and forfeit the second
inverse identity over that wider set.

### Two inverse identities

First consider any source string `x`. Every encoder case produces complete
tokens. No ordinary output glyph is `M`, and every emitted marker has its
explicit quoted follower, so adjacent source units cannot alter token parsing.
The token decoder inverts each case: table glyphs restore individual bytes,
ordinary scalars restore their original UTF-8, and quotes restore exactly the
quoted scalar. Concatenating those restored source units gives `x`.

Consequently, the canonical check accepts `E(x)`: its recovered bytes are `x`
and their prescribed representation is precisely `E(x)`. Therefore
`D(E(x)) = x` for every arbitrary-byte source string.

Conversely, let `y` be any canonical payload. Its decoded bytes have a unique
greedy source-unit partition. The canonical rule requires exactly the encoder's
spelling for every one of those units. Encoding the decoded units therefore
reconstructs `y`, establishing `E(D(y)) = y`.

These identities prove a bijection between arbitrary byte strings and the
declared canonical textual language, conditional on the fixed mapping,
preservation policy and strict UTF-8 rules. Independent tests must still show
that a concrete implementation follows those rules. Finite test samples alone
do not prove the implementation correct over every possible string.

## Streaming and composition

Bytewise encoding respects arbitrary source-byte concatenation. Textual encoding
does not: separately encoding `E4` and `B8 AD` differs from encoding their
concatenation as `中`. A streaming encoder must carry incomplete UTF-8 across
read boundaries rather than treating reads as separate messages. Chunking must
not alter the encoded representation. A decoder/checker likewise needs pending
UTF-8, quote and canonicality state. Whole-message allocation in the prototype
does not establish production streaming behavior or throughput.

## Coordinate, buffer and integration audit

Byte counts, Unicode scalars, grapheme clusters and terminal columns are different
units. The Rust and Zig textual paths do not call bytewise formatting or infer a
column width from a scalar. The CLI integration enforces that separation.

| Surface | Bytewise | Textual v1 |
| --- | --- | --- |
| Input offsets/ranges | Source bytes | Source bytes, possibly cutting a UTF-8 scalar |
| Output scalar count | One scalar per source byte | Variable; quotes and Unicode preservation change counts |
| Display columns | Depends on the selected glyphs and font | Variable: CJK, combining marks, joiners and emoji need grapheme/font-aware layout |
| Encoded buffer bound | Current table: at most three bytes per source byte | At most three bytes per source byte, plus nine for the canonical tag |
| Formatting/preservation flags | Existing bytewise policy | No bytewise formatting, container or extra preservation flags; ordinary spaces are fixed policy |
| Identification | Canonical payload uses the 256-glyph alphabet | Use a tag or explicit external mode; alphabet containment is insufficient |

Rust uses standard UTF-8 chunks and scalar iteration; Zig validates complete
scalars before preserving them and validates the complete encoded input before
token decoding. Four-byte scalars, overlong encodings, surrogate spellings,
out-of-range values and truncated input are covered by native and independent
oracle checks. Neither path splits a scalar with a two-byte/UTF-16 code-unit
loop. JavaScript currently supplies the independent oracle, not a production
textual mode; other language/runtime ports must audit their own iteration and
buffer assumptions before exposure.

Current textual encoders allocate whole-message output; the strict decoders
also allocate recovered bytes and a canonical re-encoding. Zig checks capacity
multiplication and tests cleanup under every induced allocation failure. The
bound is allocation evidence, not a throughput or constant-memory claim. Counts
and CLI statistics remain UTF-8/input byte counts, never display-width claims.
Slicing input before encoding preserves arbitrary selected bytes exactly;
slicing encoded input can produce a missing tag or invalid/noncanonical payload.

## Mode tags and framing boundary

The canonical explicit-v1 openers are `ρΒ1_` for bytewise and `ρΤ1_` for
textual, each nine UTF-8 bytes. Rho is U+03C1, beta U+0392, tau U+03A4. The
matching closers are `/ρΒ` and `/ρΤ`, each eight bytes. These
introducer characters are outside the current PB alphabet. A textual payload
quote cannot be confused with either opener or closer: its quoted follower is
`M` or a member of `R`, neither rho nor ASCII slash.

Both openers begin with **U+F000**, which some fonts render invisibly. The
visible `ρΤ1_` alone is six UTF-8 bytes, not a textual tag. In escaped notation,
`\u{f000}` denotes the actual scalar, not literal backslash/ASCII source bytes:

| Mode | Escaped spelling | UTF-8 bytes |
| --- | --- | --- |
| Bytewise | `\u{f000}ρΒ1_` | `ef 80 80 cf 81 ce 92 31 5f` |
| Textual | `\u{f000}ρΤ1_` | `ef 80 80 cf 81 ce a4 31 5f` |

Prefer the exported Rust `textual::TAG` or Zig `textual.tag` constant when
constructing a textual header. Rendering is not evidence that the marker is
present or absent; inspect code points or bytes when copying a literal tag.

Untagged mode identification must come from an explicit argument, typed API or
external metadata. Overlapping payload languages cannot establish intended
mode by content alone. Textual output is tagged by default; bytewise output
stays untagged by default. Explicitly selected modes may use untagged payloads.

A fixed canonical prefix plus its payload preserves the payload bijection.
The broader framing/excerpt reader is a separate operation: omitted/explicit
v1 spellings, optional closers and literal-region layout can be equivalent
transport representations. Do not claim the entire permissive framing language
is bijective. Existing framing decisions remain recorded in
[the design context](plan_context/current-work.md); parser transitions,
codec dispatch, quoting context and ingress guards need integration tests.

## Implementation evidence

[The size study](TEXTUAL_SIZE_STUDY.md) implements both an explicit malformed-
byte escape and the selected compact fallback construction, with canonical
rejection, independent bytewise comparisons and UTF-8 boundary controls. It
does not substitute for production API, framing, streaming, cross-platform,
or optimized performance qualification.
