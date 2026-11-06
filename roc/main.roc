app [main!] { pf: platform "platform/main.roc", roc: "nightly-2026-10-04-130536d" }

import CliCore
import CliOutput
import Codec
import Container
import Map
import pf.Clock
import pf.Environment
import pf.File
import pf.Stderr
import pf.Stdin
import pf.Stdout

debug_banner = ""

main! : List(Str) => Try({}, [Exit(I32)])
main! = |args| {
	ndjson = List.contains(args, "--ndjson-stderr")
	if Bool.not(ndjson) {
		write_stderr!(debug_banner.to_utf8())?
	}
	match CliCore.parse(List.drop_first(args, 1)) {
		Help => write_stdout!(help_text.to_utf8())
		About => match Environment.build_identity!({}) {
			Ok(identity) => write_stdout!("printable-binary 1.0.0 (Roc) Encode bytes as printable UTF-8; ${identity}\n".to_utf8())
			Err(_) => fail!("Error: unable to report the compilation target\n")
		}
		MappingTable => write_stdout!(CliOutput.mapping_table(Map.glyphs, Map.ascii_names))
		MappingJson => write_stdout!(CliOutput.mapping_json(Map.glyphs, Map.ascii_names))
		MappingCsv => write_stdout!(CliOutput.mapping_csv(Map.glyphs, Map.ascii_names))
		ParseError(message) => {
			if ndjson {
				write_stderr!(CliOutput.fatal_error(message))?
				write_stderr!(CliOutput.incomplete_summary({ messages: [], omitted: 0 }))?
				Err(Exit(1))
			} else {
				fail!("Error: ${message}\n")
			}
		}
		Run(options) => match run!(options) {
			Ok(invalid_events) => if invalid_events == 0 {
				Ok({})
			} else {
				Err(Exit(U64.to_i32_wrap(if invalid_events > 255 255 else invalid_events)))
			}
			Err(ReportedExit(code)) => {
				if options.ndjson_stderr {
					write_stderr!(CliOutput.incomplete_summary({ messages: [], omitted: 0 }))?
				}
				Err(Exit(code))
			}
			Err(Exit(code)) => {
				if options.ndjson_stderr {
					write_stderr!(CliOutput.fatal_error("input, output or runtime operation failed"))?
					write_stderr!(CliOutput.incomplete_summary({ messages: [], omitted: 0 }))?
				}
				Err(Exit(code))
			}
			Err(Failed(code, warnings)) => {
				if options.ndjson_stderr {
					write_stderr!(CliOutput.fatal_error("input, output or runtime operation failed"))?
					write_stderr!(CliOutput.incomplete_summary(warnings))?
				}
				Err(Exit(code))
			}
		}
	}
}

run! : CliCore.Options => Try(U64, [Exit(I32), ReportedExit(I32), Failed(I32, CliCore.Warnings)])
run! = |options| {
	if options.strict and Bool.not(options.decode) {
		fail_mode!("--strict requires bytewise decode mode", options.ndjson_stderr)
	} else if (options.container or options.hexlike) and (options.strict or options.ndjson_stderr) {
		fail_mode!("--strict/--ndjson-stderr are supported only for raw bytewise input", options.ndjson_stderr)
	} else if options.ndjson_stderr and options.passthrough and Bool.not(options.decode) {
		fail_mode!("--ndjson-stderr cannot be combined with --passthrough", True)
	} else if options.container and (options.tabs or options.crlf or List.len(options.preserve) > 0) {
		fail_mode!("--tabs/--crlf/-w/--preserve are not supported with --container", options.ndjson_stderr)
	} else {
		started_at = now_monotonic_nanoseconds!({})?
		input = read_input!(options.input)?
		warnings = CliCore.warnings(input, options, Map.glyphs)
		match run_input!(input, options, warnings, started_at) {
			Ok(count) => Ok(count)
			Err(Exit(code)) => Err(Failed(code, warnings))
		}
	}
}

run_input! : List(U8), CliCore.Options, CliCore.Warnings, U64 => Try(U64, [Exit(I32)])
run_input! = |input, options, warnings, started_at| {
	if Bool.not(options.ndjson_stderr) {
		for message in warnings.messages {
			write_stderr!("Warning: ${message}\n".to_utf8())?
		}
	}
	invalid_events = if options.container {
		run_container!(input, options)?
		0
	} else {
		run_raw!(input, options, warnings)?
	}
	if Bool.not(options.ndjson_stderr) {
		write_input_throughput!(List.len(input), started_at)?
	}
	Ok(invalid_events)
}

run_container! : List(U8), CliCore.Options => Try({}, [Exit(I32)])
run_container! = |input, options| {
	if options.decode {
		match Container.decode(input, Map.glyphs) {
			Ok(result) => {
				if result.ignored_formatting_spaces {
					space_glyph = List.get(Map.glyphs, 32) ?? crash "PrintableBinary mapping is incomplete"
					warning = List.concat("Warning: literal spaces in container data were assumed to be ignorable formatting because the space glyph ".to_utf8(), space_glyph)
					write_stderr!(List.concat(warning, " was also present; stripping them\n".to_utf8()))?
				} else {
					{}
				}
				write_stdout!(result.bytes)
			}
			Err(_) => fail!("Error: container integrity check failed\n")
		}
	} else {
		filename = basename(options.input)
		write_stdout!(Container.encode(input, Str.to_utf8(filename), options.spaces, Map.glyphs))
	}
}

run_raw! : List(U8), CliCore.Options, CliCore.Warnings => Try(U64, [Exit(I32)])
run_raw! = |input, options, warnings| {
	ranged = CliCore.range_input(input, options)
	transformed = if options.decode and Bool.not(options.hexlike) {
		Codec.decode_report(ranged.bytes, Map.glyphs, options.spaces, options.strip_whitespace)
	} else {
		{ bytes: CliCore.transform(input, options, Map.glyphs), report: { invalid_events: 0, invalid_bytes: 0 } }
	}
	if transformed.report.invalid_events > 0 {
		write_recovery_events!(ranged.bytes, ranged.input_base, options)?
	}
	withheld = options.strict and transformed.report.invalid_events > 0
	if options.passthrough and Bool.not(options.decode) {
		write_stdout!(input)?
		write_stderr!(transformed.bytes)?
	} else if Bool.not(withheld) {
		write_stdout!(transformed.bytes)?
	}
	if options.ndjson_stderr {
		write_stderr!(CliOutput.recovery_summary(transformed.report, List.len(input), if withheld 0 else List.len(transformed.bytes), warnings))?
	} else if transformed.report.invalid_events > 0 {
		write_stderr!("Invalid input: ${transformed.report.invalid_events.to_str()} events, ${transformed.report.invalid_bytes.to_str()} bytes\n".to_utf8())?
	}
	Ok(transformed.report.invalid_events)
}

write_recovery_events! : List(U8), U64, CliCore.Options => Try({}, [Exit(I32)])
write_recovery_events! = |input, base, options| {
	var $cursor = { input_offset: 0, output_offset: 0 }
	var $done = False
	while Bool.not($done) {
		match Codec.next_event(input, Map.glyphs, options.spaces, options.strip_whitespace, base, $cursor) {
			Done => { $done = True }
			Event(event, cursor) => {
				if options.ndjson_stderr {
					write_stderr!(CliOutput.recovery_error_prefix(event))?
				} else {
					write_stderr!("Error: invalid bytewise input input_offset=${event.input_offset.to_str()} output_offset=${event.output_offset.to_str()} input_length=${event.input_length.to_str()} output_length=${event.output_length.to_str()} hex=".to_utf8())?
				}
				var $hex_offset = event.input_offset - base
				end = $hex_offset + event.input_length
				while $hex_offset < end {
					chunk = CliOutput.recovery_hex(input, $hex_offset, end - $hex_offset)
					write_stderr!(chunk)?
					$hex_offset = $hex_offset + List.len(chunk) // 2
				}
				write_stderr!(if options.ndjson_stderr "\"}\n".to_utf8() else "\n".to_utf8())?
				$cursor = cursor
			}
		}
	}
	Ok({})
}

read_input! : CliCore.InputSource => Try(List(U8), [Exit(I32)])
read_input! = |input_source| {
	match input_source {
		StandardInput =>
			match Stdin.bytes!({}) {
				Ok(bytes) => Ok(bytes)
				Err(_) => Err(Exit(1))
			}
		Input(path) =>
			if path == "-" {
				match Stdin.bytes!({}) {
					Ok(bytes) => Ok(bytes)
					Err(_) => Err(Exit(1))
				}
			} else {
				match File.read_bytes!(path) {
					Ok(bytes) => Ok(bytes)
					Err(_) => Err(Exit(1))
				}
			}
	}
}

now_monotonic_nanoseconds! : {} => Try(U64, [Exit(I32)])
now_monotonic_nanoseconds! = |{}| {
	match Clock.monotonic_nanoseconds!({}) {
		Ok(nanoseconds) => Ok(nanoseconds)
		Err(_) => Err(Exit(1))
	}
}

write_input_throughput! : U64, U64 => Try({}, [Exit(I32)])
write_input_throughput! = |input_bytes, started_at| {
	finished_at = now_monotonic_nanoseconds!({})?
	elapsed_nanoseconds = if finished_at < started_at {
		0
	} else {
		finished_at - started_at
	}
	match Environment.stats_muted!({}) {
		Ok(True) => Ok({})
		Ok(False) => write_stderr!(CliOutput.input_throughput(input_bytes, elapsed_nanoseconds))
		Err(_) => Err(Exit(1))
	}
}

fail_mode! : Str, Bool => Try(a, [Exit(I32), ReportedExit(I32)])
fail_mode! = |message, ndjson| {
	write_stderr!(if ndjson CliOutput.fatal_error(message) else "Error: ${message}\n".to_utf8())?
	Err(ReportedExit(1))
}

basename : CliCore.InputSource -> Str
basename = |input_source| {
	match input_source {
		StandardInput => ""
		Input(path) =>
			match Str.split_last(path, "/") {
				Ok(parts) => parts.after
				Err(_) =>
					match Str.split_last(path, "\\") {
						Ok(parts) => parts.after
						Err(_) => path
					}
			}
	}
}

write_stdout! : List(U8) => Try({}, [Exit(I32)])
write_stdout! = |bytes| {
	match Stdout.bytes!(bytes) {
		Ok({}) => Ok({})
		Err(_) => Err(Exit(1))
	}
}

write_stderr! : List(U8) => Try({}, [Exit(I32)])
write_stderr! = |bytes| {
	match Stderr.bytes!(bytes) {
		Ok({}) => Ok({})
		Err(_) => Err(Exit(1))
	}
}

fail! : Str => Try({}, [Exit(I32)])
fail! = |message| {
	write_stderr!(Str.to_utf8(message))?
	Err(Exit(1))
}

help_text = "Usage: printable-binary-roc [OPTIONS] [INPUT]\n\nOptions:\n  -d, --decode                 Decode printable-binary input\n  -s, --spaces                 Preserve literal spaces while encoding\n  -t, --tabs                   Preserve literal tabs while encoding\n  -n, --crlf                   Preserve literal CR and LF while encoding\n  -w, --preserve-whitespace    Preserve spaces, tabs, CR, and LF\n  -P, --preserve=CHARS         Preserve selected bytes while encoding\n  -p, --passthrough            Copy original input to stdout; encoded form to stderr\n  -S, --strip-whitespace       Ignore transport whitespace tokens while decoding\n      --strict                 Withhold decoded payload on bytewise errors\n      --ndjson-stderr          Emit bytewise diagnostics as JSON lines\n  -C, --container              Encode or decode a printable-binary-file container\n      --range START-END        Limit input to an inclusive byte range\n      --start N --end N        Set inclusive range bounds\n      --mappings               Print the character mapping table\n      --mappings-json           Print mapping data as JSON\n      --mappings-csv           Print mapping data as CSV\n      --about                  Print implementation metadata\n  -f, --format NxM          Group raw PB output (bare -f uses 8x10)\n  -X, --hexlike              Uppercase hex runs prefixed by Οχ, not ASCII 0x\n  -h, --help                   Show this help\n\nRaw bytewise decoding preserves unknown bytes and exits with the invalid span count (at most 255). Diagnostics are not supported with --container or --hexlike.\n"
