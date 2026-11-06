#!/usr/bin/env node

/**
 * PrintableBinary Node.js CLI
 * Provides a command-line interface that mirrors the Lua/C tools
 * Supports encode/decode and optional formatting.
 */

import fs from 'fs';
import { performance } from 'node:perf_hooks';

const ndjsonStderr = process.argv.slice(2).includes('--ndjson-stderr');
// The Nix packaging graph toggles this exact constant for Debug products.
const debugBuild = false;
const warnings = [];
let PrintableBinary;
// Stream failures are handled through writeTo's callback, without a second
// uncaught EventEmitter error printing a stack trace into structured stderr.
process.stdout.on('error', () => {});
process.stderr.on('error', () => {});

function warning(message) {
  if (ndjsonStderr) warnings.push(message);
  else process.stderr.write(`Warning: ${message}\n`);
}

function diagnosticWrite(text) {
  return writeTo(process.stderr, text);
}

async function reportEvent(event) {
  const { bytes, ...fields } = event;
  await diagnosticWrite(ndjsonStderr
    ? JSON.stringify(fields).slice(0, -1) + ',"hex":"'
    : `Invalid input: input_offset=${event.input_offset} output_offset=${event.output_offset} input_length=${event.input_length} output_length=${event.output_length} hex=`);
  // Borrow each fixed-size slice. Never retain a hex string for the whole span.
  for (let offset = 0; offset < bytes.length; offset += 256) {
    const length = Math.min(256, bytes.length - offset);
    await diagnosticWrite(Buffer.from(bytes.buffer, bytes.byteOffset + offset, length).toString('hex'));
  }
  await diagnosticWrite(ndjsonStderr ? '"}\n' : '\n');
}

function printUsage() {
  const progname = process.argv[1]
    ? process.argv[1].split('/').slice(-1)[0]
    : 'printable-binary-node';

  const usage = `
PrintableBinary (JavaScript CLI) - Encode binary data as printable UTF-8 and decode it back

Usage: ${progname} [options] [file]

Options:
  -d, --decode          Decode mode (default is encode mode)
  -s, --spaces          Preserve and accept literal data spaces
  -t, --tabs            Preserve literal tabs on encode
  -n, --crlf            Preserve literal CR/LF on encode
  -w, --preserve-whitespace  Preserve all whitespace (spaces + tabs + CRLF)
  -P, --preserve=CHARS  Preserve specific characters on encode
  -S, --strip-whitespace  Ignore transport whitespace without joining glyph fragments
  --strict             Report invalid decode input without emitting payload
  --ndjson-stderr       Emit JSON error events and a final summary on stderr
  -p, --passthrough     Pass input to stdout unchanged, send encoded data to stderr
  -f, --format NxM      Format output in groups (e.g. 75x1)
  -f=NXM, --format=NXM  Alternate syntax for specifying formatting
  --mappings            Show the byte-to-character mapping table
  --mappings-json       Output the mappings as JSON
  --mappings-csv        Output the mappings as CSV
  --no-double-encode-check   Skip detection of already-encoded input
  --about               Print version and execution platform
  -h, --help            Show this help

Encoding modes:
  -X, --hexlike    Hexlike mode: passthrough ASCII stays as-is, all other bytes
                   shown as uppercase hex runs prefixed by \u039F\u03C7 (Greek Omicron+Chi,
                   NOT ASCII 0x \u2014 beware when copying hex for other purposes).
                   Use with -d to decode hexlike-encoded data back to binary.
  -C, --container  Container mode: encode a file to a self-verifying .pbf.json
                   (keeps filename, dates, perms + crc32). Use with -d to decode
                   a .pbf.json container back to the original file.

Range options (select byte range from input before processing):
  --range X-Y              Byte range, 0-indexed inclusive (e.g., --range 0-9)
  --start X                Start offset (negative = from end, like xxd -s)
  --end Y                  End offset (inclusive)
  X-Y (positional)         Shorthand for --range X-Y
  Hex offsets supported: --range 0x0A-0xFF
  Omitted bounds: --range -9 (first 10 bytes), --range 10- (byte 10 to EOF)

Use --strip-whitespace to ignore ASCII transport whitespace between complete glyphs. Unknown bytes are preserved and reported. Controls and syntax-sensitive bytes use visible glyphs; --spaces retains literal data spaces and warns about indentation.

If no file is specified, input is read from stdin.
Output is written to stdout.
`;
  process.stderr.write(usage);
}

function csvEscape(value) {
  return `"${value.replace(/"/g, '""')}"`;
}

function outputMappings(entries, format) {
  if (format === 'json') {
    process.stdout.write(JSON.stringify(entries, null, 2) + '\n');
    return;
  }

  if (format === 'csv') {
    const lines = ['byte,hex,dec,ascii,mapping'];
    for (const entry of entries) {
      lines.push([
        entry.byte,
        entry.hex,
        entry.dec,
        csvEscape(entry.ascii),
        csvEscape(entry.mapping)
      ].join(','));
    }
    process.stdout.write(lines.join('\n') + '\n');
    return;
  }

  const header = `${'Byte'.padEnd(6)} ${'Dec'.padEnd(5)} ${'ASCII'.padEnd(12)} Mapping`;
  process.stdout.write(header + '\n');
  for (const entry of entries) {
    const line = `${entry.hex.padEnd(6)} ${String(entry.dec).padEnd(5)} ${entry.ascii.padEnd(12)} ${entry.mapping}`;
    process.stdout.write(line + '\n');
  }
}

function parseOffsetValue(s) {
  if (!/^(?:0[xX][0-9a-fA-F]+|-?\d+)$/.test(s)) throw new Error(`Invalid byte offset: ${s}`);
  const value = Number(s);
  if (!Number.isSafeInteger(value)) throw new Error(`Invalid byte offset: ${s}`);
  return value;
}

function parseRangeSpec(spec) {
  if (!spec || spec.length === 0) return null;
  // Find separator hyphen (not inside hex prefix)
  let sepIdx = -1;
  let i = 0;
  if (spec.length > 2 && spec[0] === '0' && (spec[1] === 'x' || spec[1] === 'X')) {
    i = 2;
    while (i < spec.length && /[0-9a-fA-F]/.test(spec[i])) i++;
  } else {
    while (i < spec.length && /[0-9]/.test(spec[i])) i++;
  }
  if (i < spec.length && spec[i] === '-') {
    sepIdx = i;
  } else if (spec[0] === '-') {
    sepIdx = 0;
  } else {
    return null;
  }

  let start = null;
  let end = null;
  if (sepIdx > 0) {
    start = parseOffsetValue(spec.slice(0, sepIdx));
  }
  const endStr = spec.slice(sepIdx + 1);
  if (endStr.length > 0) {
    end = parseOffsetValue(endStr);
  }
  return { start, end };
}

function isPositionalRange(s) {
  if (!s || s.length === 0 || s[0] === '-') return false;
  return /^(0x[0-9a-fA-F]+|\d+)-/.test(s);
}

function parseArgs(argv) {
  let decodeMode = false;
  let formatSpec = null;
  let filePath = null;
  let mappingsFormat = null;
  let passthrough = false;
  let spacesMode = false;
  let rangeStart = null;
  let rangeEnd = null;
  let noDoubleEncodeCheck = false;
  let stripWhitespace = false;
  let tabsMode = false;
  let crlfMode = false;
  let preserveChars = '';
  let hexlikeMode = false;
  let containerMode = false;
  let strict = false;

  const setMappingsFormat = (mode) => {
    if (mappingsFormat && mappingsFormat !== mode) {
      throw new Error('Only one mappings output option can be specified');
    }
    mappingsFormat = mode;
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === '-h' || arg === '--help') {
      printUsage();
      process.exit(0);
    } else if (arg === '--about') {
      const os = { linux: 'linux', darwin: 'macos', win32: 'mswin' }[process.platform];
      const arch = { x64: 'amd64', arm64: 'arm64' }[process.arch];
      if (!os || !arch || (os === 'macos' && arch !== 'arm64')) {
        process.stderr.write('Unsupported execution platform\n');
        process.exit(1);
      }
      process.stdout.write(`printable-binary 1.0.0 (Node) Encode bytes as printable UTF-8; PF=${os}-${arch}\n`);
      process.exit(0);
    } else if (arg === '-d' || arg === '--decode') {
      decodeMode = true;
    } else if (arg === '--strict') {
      strict = true;
    } else if (arg === '--ndjson-stderr') {
      // Pre-scanned so parse failures are JSON regardless of option order.
    } else if (arg === '-s' || arg === '--spaces') {
      spacesMode = true;
    } else if (arg === '-f' || arg === '--format') {
      // Bare -f: default grouping (8x10), like the other implementations. Do not
      // consume the next argument (it is the input file); use -f=NxM for a spec.
      formatSpec = '8x10';
    } else if (arg.startsWith('-f=')) {
      formatSpec = arg.slice(3);
    } else if (arg.startsWith('--format=')) {
      formatSpec = arg.slice(9);
    } else if (arg === '--mappings') {
      setMappingsFormat('table');
    } else if (arg === '--mappings-json') {
      setMappingsFormat('json');
    } else if (arg === '--mappings-csv') {
      setMappingsFormat('csv');
    } else if (arg === '-p' || arg === '--passthrough') {
      passthrough = true;
    } else if (arg === '-S' || arg === '--strip-whitespace') {
      stripWhitespace = true;
    } else if (arg === '-t' || arg === '--tabs') {
      tabsMode = true;
    } else if (arg === '-n' || arg === '--crlf') {
      crlfMode = true;
    } else if (arg === '-w' || arg === '--preserve-whitespace') {
      spacesMode = true;
      tabsMode = true;
      crlfMode = true;
    } else if (arg === '-P' || arg === '--preserve') {
      if (i + 1 >= argv.length) {
        throw new Error('--preserve requires a value');
      }
      preserveChars = argv[++i];
    } else if (arg.startsWith('--preserve=')) {
      preserveChars = arg.slice(11);
    } else if (arg === '-X' || arg === '--hexlike') {
      hexlikeMode = true;
    } else if (arg === '-C' || arg === '--container') {
      containerMode = true;
    } else if (arg === '--no-double-encode-check') {
      noDoubleEncodeCheck = true;
    } else if (arg === '--range') {
      if (i + 1 >= argv.length) {
        throw new Error('--range requires an argument');
      }
      const parsed = parseRangeSpec(argv[++i]);
      if (!parsed) {
        throw new Error(`Invalid range specification: ${argv[i]}`);
      }
      if (parsed.start !== null) rangeStart = parsed.start;
      if (parsed.end !== null) rangeEnd = parsed.end;
    } else if (arg.startsWith('--range=')) {
      const parsed = parseRangeSpec(arg.slice(8));
      if (!parsed) {
        throw new Error(`Invalid range specification: ${arg.slice(8)}`);
      }
      if (parsed.start !== null) rangeStart = parsed.start;
      if (parsed.end !== null) rangeEnd = parsed.end;
    } else if (arg === '--start') {
      if (i + 1 >= argv.length) {
        throw new Error('--start requires an argument');
      }
      rangeStart = parseOffsetValue(argv[++i]);
    } else if (arg.startsWith('--start=')) {
      rangeStart = parseOffsetValue(arg.slice(8));
    } else if (arg === '--end') {
      if (i + 1 >= argv.length) {
        throw new Error('--end requires an argument');
      }
      rangeEnd = parseOffsetValue(argv[++i]);
    } else if (arg.startsWith('--end=')) {
      rangeEnd = parseOffsetValue(arg.slice(6));
    } else if (arg.startsWith('-') && !arg.startsWith('--') && arg.length > 2) {
      // Combined short flags like -stn
      const flags = arg.slice(1);
      for (const ch of flags) {
        switch (ch) {
          case 's': spacesMode = true; break;
          case 't': tabsMode = true; break;
          case 'n': crlfMode = true; break;
          case 'w': spacesMode = true; tabsMode = true; crlfMode = true; break;
          case 'd': decodeMode = true; break;
          case 'p': passthrough = true; break;
          case 'S': stripWhitespace = true; break;
          case 'X': hexlikeMode = true; break;
          case 'C': containerMode = true; break;
          default:
            throw new Error(`Unknown option -${ch}`);
        }
      }
    } else if (arg.startsWith('-')) {
      throw new Error(`Unknown option ${arg}`);
    } else if (isPositionalRange(arg)) {
      const parsed = parseRangeSpec(arg);
      if (parsed) {
        if (parsed.start !== null) rangeStart = parsed.start;
        if (parsed.end !== null) rangeEnd = parsed.end;
      } else if (!filePath) {
        filePath = arg;
      } else {
        throw new Error(`Unexpected argument ${arg}`);
      }
    } else if (!filePath) {
      filePath = arg;
    } else {
      throw new Error(`Unexpected argument ${arg}`);
    }
  }

  if (strict && !decodeMode) throw new Error('--strict requires --decode');
  if (formatSpec && (!/^[1-9]\d*x[1-9]\d*$/.test(formatSpec) ||
      !formatSpec.split('x').every(value => Number.isSafeInteger(Number(value))))) {
    throw new Error(`Invalid format specification: ${formatSpec}; dimensions must be positive integers`);
  }
  if ((strict || ndjsonStderr) && (hexlikeMode || containerMode)) {
    throw new Error('--strict/--ndjson-stderr are supported only in bytewise mode, not --hexlike/--container');
  }
  if (ndjsonStderr && (mappingsFormat || (passthrough && !decodeMode))) {
    throw new Error('--ndjson-stderr cannot be combined with mappings or encode --passthrough');
  }
  return { decodeMode, formatSpec, filePath, mappingsFormat, passthrough, spacesMode, stripWhitespace, tabsMode, crlfMode, preserveChars, rangeStart, rangeEnd, noDoubleEncodeCheck, hexlikeMode, containerMode, strict };
}

async function readInput(filePath) {
  if (filePath) {
    return fs.promises.readFile(filePath);
  }

  // Read from stdin
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

function muteStats() {
  return process.env.PRINTABLE_BINARY_MUTE_STATS === '1';
}

function stats(msg) {
  if (!ndjsonStderr && !muteStats()) {
    process.stderr.write(msg + '\n');
  }
}

function writeTo(stream, data) {
  return new Promise((resolve, reject) => {
    try {
      stream.write(data, (err) => err ? reject(err) : resolve());
    } catch (err) {
      reject(err);
    }
  });
}

function reportInputThroughput(inputBytesRead, startedAt) {
  const elapsedSeconds = Math.max((performance.now() - startedAt) / 1000, 0.0005);
  const megabytes = inputBytesRead / 1_000_000;
  stats(`Input throughput: ${megabytes.toFixed(2)} MB read in ${elapsedSeconds.toFixed(3)} s (${(megabytes / elapsedSeconds).toFixed(2)} MB/s)`);
}

async function main() {
  try {
    if (debugBuild && !ndjsonStderr) await diagnosticWrite('\x1b[33mDEBUG BUILD!\x1b[0m\n');
    if (ndjsonStderr && process.argv.slice(2).some(arg => ['-h', '--help', '--about'].includes(arg))) {
      throw new Error('--ndjson-stderr cannot be combined with --help/--about');
    }
    const { decodeMode, formatSpec, filePath, mappingsFormat, passthrough, spacesMode, stripWhitespace, tabsMode, crlfMode, preserveChars, rangeStart, rangeEnd, noDoubleEncodeCheck, hexlikeMode, containerMode, strict } = parseArgs(process.argv.slice(2));
    ({ default: PrintableBinary } = await import('../js/printable_binary.js'));
    const pb = new PrintableBinary();
    if (mappingsFormat) {
      const entries = pb.getMappings();
      outputMappings(entries, mappingsFormat);
      return;
    }

    const throughputStartedAt = performance.now();
    let input = await readInput(filePath);
    const inputBytesRead = input.length;
    let inputOffset = 0;
    let outputBytes = 0;
    let summary = { invalid_events: 0, invalid_bytes: 0 };

    // Apply byte range if specified
    if (rangeStart !== null || rangeEnd !== null) {
      const inputLen = input.length;
      let start = rangeStart !== null ? rangeStart : 0;
      let end = rangeEnd !== null ? rangeEnd : inputLen - 1;

      // Handle negative start (from end)
      if (start < 0) {
        start = inputLen + start;
        if (start < 0) start = 0;
      }

      if (start >= inputLen) {
        warning(`start offset ${start} exceeds input size ${inputLen}`);
        input = Buffer.alloc(0);
      } else if (start > end) {
        warning('start offset exceeds end offset, empty range');
        input = Buffer.alloc(0);
      } else {
        if (end >= inputLen) {
          warning(`end offset ${end} exceeds input size ${inputLen}, clamping to ${inputLen - 1}`);
          end = inputLen - 1;
        }
        input = input.subarray(start, end + 1);
        inputOffset = start;
      }
    }

    if (containerMode) {
      // Only --spaces is honored in container mode; --tabs/--crlf/-w/--preserve
      // would put raw tab/CR/LF (or arbitrary chars) into the JSON value, breaking
      // single-line-JSON validity and the tab/CR/LF-stripping transport-resistance.
      if (tabsMode || crlfMode || preserveChars) {
        process.stderr.write('Error: --tabs/--crlf/-w/--preserve are not supported with --container (only --spaces is honored; other whitespace stays encoded)\n');
        process.exit(1);
      }
      if (decodeMode) {
        const res = pb.decodeText(input.toString('utf8'));
        stats(`Decoded ${res.kind} container${res.filename && res.filename !== 'decoded.bin' ? ' (' + res.filename + ')' : ''}: ${res.bytes.length} bytes`);
        await writeTo(process.stdout, Buffer.from(res.bytes));
      } else {
        const meta = {};
        if (filePath) {
          meta.filename = filePath.split(/[\\/]/).pop();
          try {
            const st = fs.statSync(filePath);
            meta.modified_ms = Math.round(st.mtimeMs);
            if (st.birthtimeMs && st.birthtimeMs > 0) meta.created_ms = Math.round(st.birthtimeMs);
            meta.mode = '0' + (st.mode & 0o777).toString(8);
          } catch (_e) { /* metadata is best-effort */ }
        }
        const container = pb.encodeToContainer(new Uint8Array(input), meta, { spaces: spacesMode });
        stats(`Encoded ${input.length} bytes -> .pbf.json container (crc32 ${container.crc32})`);
        await writeTo(process.stdout, JSON.stringify(container, null, 2) + '\n');
      }
      reportInputThroughput(inputBytesRead, throughputStartedAt);
      return;
    }


    if (decodeMode) {
      if (passthrough) {
        warning('--passthrough ignored in decode mode');
      }
      stats(`Decoding mode: Input size is ${input.length} bytes`);

      if (hexlikeMode) {
        const inputStr = input.toString('utf8');
        // Hexlike decode
        const { data: decoded, foundHex } = pb.hexlikeDecode(inputStr, {
          spaces: spacesMode
        });

        // Warn if no Οχ sequences found
        if (!foundHex) {
          process.stderr.write('Warning: no hexlike (\u039F\u03C7) sequences found in input\n');
        }

        // Warn if PB-style encoding detected
        const deInfo = pb.detectDoubleEncode(inputStr);
        if (deInfo.detected) {
          process.stderr.write('Warning: input appears to contain standard printable-binary encoding\n');
        }

        stats(`Decoded result size: ${decoded.length} bytes`);
        await writeTo(process.stdout, Buffer.from(decoded));
      } else {
        // Warn if hexlike encoding detected in regular PB decode
        if (input.includes(Buffer.from('Οχ')) && PrintableBinary.detectHexlike(input.toString('utf8'))) {
          warning('input appears to contain hexlike (\u039F\u03C7) encoding; use --hexlike -d to decode');
        }
        if (spacesMode && /[\r\n] {2,}/.test(input.toString('latin1'))) {
          warning('spaces after newline are treated as data in --spaces mode');
        }

        if (stripWhitespace) {
          stats('Decoded with whitespace stripping');
        }
        const result = await pb.decodeReportAsync(input, {
          spaces: spacesMode,
          stripWhitespace: stripWhitespace,
          inputOffset,
        }, reportEvent);
        const decoded = result.bytes;
        summary = result.summary;
        stats(`Decoded result size: ${decoded.length} bytes`);
        if (!(strict && summary.invalid_events)) {
          await writeTo(process.stdout, decoded);
          outputBytes = decoded.length;
        }
      }
    } else {
      // Check for double-encoding
      if (!noDoubleEncodeCheck) {
        const deInfo = pb.detectDoubleEncode(input.toString('utf8'));
        if (deInfo.detected) {
          warning(`Input appears to already be printable-binary encoded (${(deInfo.confidence * 100).toFixed(1)}% detection). Use --no-double-encode-check to suppress this warning.`);
        }
      }

      if (hexlikeMode) {
        const encoded = pb.hexlikeEncode(input, { spaces: spacesMode });
        stats(`Encoded ${input.length} bytes of input to ${Buffer.byteLength(encoded, 'utf8')} bytes`);
        if (passthrough) {
          await writeTo(process.stdout, input);
          await writeTo(process.stderr, encoded);
        } else {
          await writeTo(process.stdout, encoded);
        }
      } else {
        const options = { spaces: spacesMode, tabs: tabsMode, crlf: crlfMode };
        if (preserveChars) {
          options.preserve = preserveChars;
        }
        if (formatSpec) {
          options.format = formatSpec;
        }
        const encoded = pb.encode(input, options);
        outputBytes = Buffer.byteLength(encoded, 'utf8');
        stats(`Encoded ${input.length} bytes of input to ${Buffer.byteLength(encoded, 'utf8')} bytes`);
        if (passthrough) {
          await writeTo(process.stdout, input);
          await writeTo(process.stderr, encoded);
        } else {
          await writeTo(process.stdout, encoded);
        }
      }
    }
    reportInputThroughput(inputBytesRead, throughputStartedAt);
    if (ndjsonStderr) {
      const elapsed_seconds = Math.max((performance.now() - throughputStartedAt) / 1000, 0.0005);
      await writeTo(process.stderr, JSON.stringify({ type: 'summary', ...summary,
        input_bytes: inputBytesRead, output_bytes: outputBytes, complete: true,
        elapsed_seconds, input_mbps: inputBytesRead / 1_000_000 / elapsed_seconds, warnings }) + '\n');
    } else if (summary.invalid_events) {
      process.stderr.write(`Invalid input: ${summary.invalid_events} events, ${summary.invalid_bytes} bytes\n`);
    }
    process.exitCode = Math.min(summary.invalid_events, 255);
  } catch (err) {
    process.exitCode = 1;
    try {
      if (ndjsonStderr) {
        await diagnosticWrite(JSON.stringify({ type: 'error', fatal: true, message: err.message }) + '\n');
        await diagnosticWrite(JSON.stringify({ type: 'summary', complete: false, invalid_events: null,
          invalid_bytes: null, input_bytes: null, output_bytes: null, warnings }) + '\n');
      } else process.stderr.write(`Error: ${err.message}\n`);
    } catch (_) { /* Broken diagnostic streams cannot report their own failure. */ }
  }
}

main();
