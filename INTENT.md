# PrintableBinary intent

## Purpose and users

PrintableBinary gives developers and technical users a reversible text representation of arbitrary bytes. It keeps ordinary ASCII recognizable while representing control and non-ASCII bytes as visible UTF-8 glyphs, so binary values can be inspected, copied, embedded in text formats, and restored byte-for-byte.

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

Optional language-aware UTF-8 passthrough should keep multilingual logs readable while preserving exact byte recovery. CJK scripts do not collide with the current alphabet; broader Latin passthrough needs an explicit collision policy or replacement alphabet. Compatibility breaks are permitted at the current adoption level, but no replacement repertoire has been selected. [`PLAN.md`](PLAN.md) tracks this direction and the remaining opt-in framing work.
