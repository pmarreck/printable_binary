---
description: "WASM benchmarks must stream inputs and APE needs a clean environment."
datetime: 2026-07-17T13:57:46-04:00 # America/New_York (EDT)
tags: [wasm, wat, webassembly, benchmarks, stream, inputs, ape, clean, environment]
---
The Emscripten/WASI CLI cannot open an arbitrary host file path under wazero's
default sandbox. Benchmark adapters must redirect each generated input file to
stdin and pass `-d` after wazero's `--` separator for decode.

In the tested Nix development environment, the Cosmopolitan APE reported
`Exec format error` when launched directly, but worked with a minimal `env -i`
PATH/HOME/TMPDIR. Use the clean-environment adapter in
`benchmarks/benchmark-zig-opt` for APE benchmarks so the executable itself,
rather than development-shell state, is measured.
