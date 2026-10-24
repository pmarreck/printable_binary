#!/usr/bin/env node

/**
 * PrintableBinary Node.js CLI
 * Provides a command-line interface that mirrors the Lua/C tools
 * Supports encode/decode and optional formatting.
 */

import fs from 'fs';
import { performance } from 'node:perf_hooks';
import PrintableBinary from '../js/printable_binary.js';

function printUsage() {
  const progname = process.argv[1]
    ? process.argv[1].split('/').slice(-1)[0]
    : 'printable-binary-node';

  const usage = `
PrintableBinary (JavaScript CLI) - Encode binary data as printable UTF-8 and decode it back

Usage: ${progname} [options] [file]

Options:
  -d, --decode          Decode mode (default is encode mode)
  -s, --spaces          Preserve literal spaces (decoder still ignores tabs/newlines/CR)
  -t, --tabs            Preserve literal tabs on encode
  -n, --crlf            Preserve literal CR/LF on encode
  -w, --preserve-whitespace  Preserve all whitespace (spaces + tabs + CRLF)
  -P, --preserve=CHARS  Preserve specific characters on encode
  -S, --strip-whitespace  Strip whitespace before decoding (for block-formatted input)
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

Encoded output is whitespace-agnostic: you can reflow, indent, or wrap it freely because the decoder ignores real whitespace while rendering quotes, backslashes, tabs, and control bytes as visible, but clearly related, glyphs (e.g., SPACE→␣, TAB→⇥, CR→⏎, LF→↧, single quote→ʼ, double quote→˵, backslash→⧷). With --spaces, literal spaces are treated as data (and we warn on indented lines).

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
  if (!s || s.length === 0) return null;
  if (s.startsWith('0x') || s.startsWith('0X')) {
    const val = parseInt(s, 16);
    return isNaN(val) ? null : val;
  }
  const val = parseInt(s, 10);
  return isNaN(val) ? null : val;
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

  const setMappingsFormat = (mode) => {
    if (mappingsFormat && mappingsFormat !== mode) {
      process.stderr.write('Error: Only one mappings output option can be specified\n');
      process.exit(1);
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
        process.stderr.write('Error: --preserve requires a value\n');
        process.exit(1);
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
        process.stderr.write('Error: --range requires an argument\n');
        process.exit(1);
      }
      const parsed = parseRangeSpec(argv[++i]);
      if (!parsed) {
        process.stderr.write(`Error: Invalid range specification: ${argv[i]}\n`);
        process.exit(1);
      }
      if (parsed.start !== null) rangeStart = parsed.start;
      if (parsed.end !== null) rangeEnd = parsed.end;
    } else if (arg.startsWith('--range=')) {
      const parsed = parseRangeSpec(arg.slice(8));
      if (!parsed) {
        process.stderr.write(`Error: Invalid range specification: ${arg.slice(8)}\n`);
        process.exit(1);
      }
      if (parsed.start !== null) rangeStart = parsed.start;
      if (parsed.end !== null) rangeEnd = parsed.end;
    } else if (arg === '--start') {
      if (i + 1 >= argv.length) {
        process.stderr.write('Error: --start requires an argument\n');
        process.exit(1);
      }
      rangeStart = parseOffsetValue(argv[++i]);
    } else if (arg.startsWith('--start=')) {
      rangeStart = parseOffsetValue(arg.slice(8));
    } else if (arg === '--end') {
      if (i + 1 >= argv.length) {
        process.stderr.write('Error: --end requires an argument\n');
        process.exit(1);
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
            process.stderr.write(`Error: Unknown option -${ch}\n`);
            printUsage();
            process.exit(1);
        }
      }
    } else if (arg.startsWith('-')) {
      process.stderr.write(`Error: Unknown option ${arg}\n`);
      printUsage();
      process.exit(1);
    } else if (isPositionalRange(arg)) {
      const parsed = parseRangeSpec(arg);
      if (parsed) {
        if (parsed.start !== null) rangeStart = parsed.start;
        if (parsed.end !== null) rangeEnd = parsed.end;
      } else if (!filePath) {
        filePath = arg;
      } else {
        process.stderr.write(`Error: Unexpected argument ${arg}\n`);
        process.exit(1);
      }
    } else if (!filePath) {
      filePath = arg;
    } else {
      process.stderr.write(`Error: Unexpected argument ${arg}\n`);
      process.exit(1);
    }
  }

  return { decodeMode, formatSpec, filePath, mappingsFormat, passthrough, spacesMode, stripWhitespace, tabsMode, crlfMode, preserveChars, rangeStart, rangeEnd, noDoubleEncodeCheck, hexlikeMode, containerMode };
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
  if (!muteStats()) {
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
  const { decodeMode, formatSpec, filePath, mappingsFormat, passthrough, spacesMode, stripWhitespace, tabsMode, crlfMode, preserveChars, rangeStart, rangeEnd, noDoubleEncodeCheck, hexlikeMode, containerMode } = parseArgs(process.argv.slice(2));
  const pb = new PrintableBinary();

  try {
    if (mappingsFormat) {
      const entries = pb.getMappings();
      outputMappings(entries, mappingsFormat);
      return;
    }

    const throughputStartedAt = performance.now();
    let input = await readInput(filePath);
    const inputBytesRead = input.length;

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
        process.stderr.write(`Warning: start offset ${start} exceeds input size ${inputLen}\n`);
        input = Buffer.alloc(0);
      } else if (start > end) {
        process.stderr.write('Warning: start offset exceeds end offset, empty range\n');
        input = Buffer.alloc(0);
      } else {
        if (end >= inputLen) {
          process.stderr.write(`Warning: end offset ${end} exceeds input size ${inputLen}, clamping to ${inputLen - 1}\n`);
          end = inputLen - 1;
        }
        input = input.subarray(start, end + 1);
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
        process.stderr.write('Warning: --passthrough ignored in decode mode\n');
      }
      const inputStr = input.toString('utf8');
      stats(`Decoding mode: Input size is ${input.length} bytes`);

      if (hexlikeMode) {
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
        if (PrintableBinary.detectHexlike(inputStr)) {
          process.stderr.write('Warning: input appears to contain hexlike (\u039F\u03C7) encoding; use --hexlike -d to decode\n');
        }

        if (stripWhitespace) {
          stats('Decoded with whitespace stripping');
        }
        const decoded = pb.decode(inputStr, {
          spaces: spacesMode,
          stripWhitespace: stripWhitespace,
          warnOnIndent: spacesMode && stripWhitespace
        });
        stats(`Decoded result size: ${decoded.length} bytes`);
        await writeTo(process.stdout, Buffer.from(decoded));
      }
    } else {
      // Check for double-encoding
      if (!noDoubleEncodeCheck) {
        const deInfo = pb.detectDoubleEncode(input.toString('utf8'));
        if (deInfo.detected) {
          process.stderr.write(
            `Warning: Input appears to already be printable-binary encoded (${(deInfo.confidence * 100).toFixed(1)}% detection).\n` +
            `         Use --no-double-encode-check to suppress this warning.\n`
          );
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
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    process.exit(1);
  }
}

main();
