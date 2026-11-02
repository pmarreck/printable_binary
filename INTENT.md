# PrintableBinary intent

## Purpose and users

PrintableBinary gives developers and technical users a reversible text representation of arbitrary bytes. It keeps ordinary ASCII recognizable while representing control and non-ASCII bytes as visible UTF-8 glyphs, so binary values can be inspected, copied, embedded in text formats, and restored byte-for-byte.

The original use cases are safe terminal inspection of unknown binary data without emitting terminal-control sequences, and seeing recognizable text embedded in binary instead of obscuring it behind hexadecimal byte values. A readable-Unicode direction should extend those inspection goals rather than replace them with text-input validation.

## Desired outcomes

- A single documented byte-to-glyph mapping with exact, bijective encode/decode behavior across its 256-byte domain.
- Usable CLI, library, web, and portable-runtime implementations that interoperate byte-for-byte.
- Full CLI implementations can encode and decode streams and files, expose mappings, preserve documented formatting modes, produce self-verifying `.pbf.json` containers, and report non-data status through stderr.
- Users can select an implementation for their operating system, runtime, or distribution constraint without changing the encoded format.

## Scope and non-goals

The project includes implementations and adapters in languages and runtimes that can demonstrably preserve the mapping and public contract. It does not promise identical internal architecture, performance, startup cost, or feature sets for intentionally minimal transports such as the Rust stdin codec. It does not turn PrintableBinary into a general archive, compression, or encryption format.

## Constraints and tradeoffs

- The mapping's readable glyph choices balance semantic resemblance, UTF-8 byte economy, and stable monospace display width.
- High-byte glyphs should progress roughly alphabetically, giving readers a visual estimate of byte order; a future Latin-friendly alphabet must weigh that readability against encoding size and ordinary-language collisions.
- Correctness means both directions of the mapping are independently checked over all 256 values; agreeing implementations alone are insufficient evidence.
- Full CLI behavior must preserve raw bytes on stdout and keep diagnostics, status, and warnings on stderr.
- Reproducible builds and tests define supported implementation surfaces. Every supported implementation must be covered by its appropriate Nix check and the complete test entry point.
- Public repository content must remain free of personal machine, network, account, and operational details.

## Success evidence

The parameterized CLI and container tests, exhaustive mapping checks, independent cross-implementation differentials, and documented Nix/Mechatron Prime CI targets establish the executable contract. The current test and build wiring live in [`flake.nix`](flake.nix), [`tests/`](tests/), and [`.mechatron-prime/targets`](.mechatron-prime/targets).

## Current direction

Keep the existing byte-oriented format as `bytewise` and add an opt-in `textual` codec for readable multilingual logs. Textual encoding should preserve ordinary Unicode text while visibly encoding controls, syntax-sensitive characters, and reserved glyphs needed for unambiguous decoding. Reuse U+F000 as the escape introducer. Establish explicit domains, canonical output grammars, and two-sided inverse arguments for both codecs; lossless forward round trips alone are not the complete guarantee.

Textual output carries a mode tag by default; bytewise output remains untagged by default. Explicit mode selection may also identify untagged payloads. Both modes accept arbitrary bytes: textual encoding preserves eligible UTF-8 scalars and uses existing PB byte glyphs for malformed bytes, with martini quoting and strict canonical payload decoding. Textual v1 preserves ordinary ASCII spaces, ZWJ/ZWNJ, and combining/variation marks; other Unicode 16.0 Cc/Cf/White_Space characters are visibly encoded. This supersedes the initially considered valid-UTF-8-only restriction. [The size-study report](docs/TEXTUAL_SIZE_STUDY.md) records the alternatives and their limits; [the codec contract](docs/CODEC_MODES.md) defines the fixed policy and inverse argument. Prioritize the Rust library for the first textual delivery without changing the canonical Zig selection. Mixed-region framing and streaming remain distinct integration work. The separate Latin-friendly alphabet investigation permits compatibility breaks at the current adoption level, but has not selected a replacement repertoire. [`PLAN.md`](PLAN.md) tracks implementation and framing work; [the design context](docs/plan_context/current-work.md) preserves decisions and verification evidence.
