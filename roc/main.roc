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

main! : List(Str) => Try({}, [Exit(I32)])
main! = |args| {
	match CliCore.parse(List.drop_first(args, 1)) {
		Help => write_stdout!(help_text.to_utf8())
		About => write_stdout!("printable-binary Roc on native platform".to_utf8())
		MappingTable => write_stdout!(CliOutput.mapping_table(Map.glyphs, Map.ascii_names))
		MappingJson => write_stdout!(CliOutput.mapping_json(Map.glyphs, Map.ascii_names))
		MappingCsv => write_stdout!(CliOutput.mapping_csv(Map.glyphs, Map.ascii_names))
		ParseError(message) => fail!("Error: ${message}\n")
		Run(options) => run!(options)
	}
}

run! : CliCore.Options => Try({}, [Exit(I32)])
run! = |options| {
	if options.container and (options.tabs or options.crlf or List.len(options.preserve) > 0) {
		fail!("Error: --tabs/--crlf/-w/--preserve are not supported with --container\n")
	} else {
		started_at = now_monotonic_nanoseconds!({})?
		input = read_input!(options.input)?
		write_range_warning!(CliCore.range_warning(input, options.range_start, options.range_end))?
		if options.decode and options.spaces and options.strip_whitespace and CliCore.has_indented_spaces_after_newline(input) {
			write_stderr!("Warning: spaces after newline are preserved by --spaces while --strip-whitespace is active\n".to_utf8())?
		} else {
			{}
		}
		if options.container {
			run_container!(input, options)?
		} else {
			run_raw!(input, options)?
		}
		write_input_throughput!(List.len(input), started_at)
	}
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

run_raw! : List(U8), CliCore.Options => Try({}, [Exit(I32)])
run_raw! = |input, options| {
	if options.decode and options.passthrough {
		write_stderr!("Warning: --passthrough ignored in decode mode\n".to_utf8())?
	} else {
		{}
	}
	if Bool.not(options.decode) and Bool.not(options.no_double_encode_check) and Codec.is_likely_double_encoded(input, Map.glyphs) {
		write_stderr!("Warning: input appears to be already encoded; continuing may double-encode it\n".to_utf8())?
	} else {
		{}
	}
	encoded_or_decoded = CliCore.transform(input, options, Map.glyphs)
	if options.passthrough and Bool.not(options.decode) {
		write_stdout!(input)?
		write_stderr!(encoded_or_decoded)
	} else {
		write_stdout!(encoded_or_decoded)
	}
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

write_range_warning! : CliCore.RangeWarning => Try({}, [Exit(I32)])
write_range_warning! = |warning| {
	match warning {
		NoRangeWarning => Ok({})
		RangeEndClamped => write_stderr!("Warning: range end exceeds input size; clamping\n".to_utf8())
		RangeStartExceedsInput => write_stderr!("Warning: range start exceeds input size\n".to_utf8())
		EmptyRange => write_stderr!("Warning: empty range\n".to_utf8())
	}
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

help_text = "Usage: printable-binary-roc [OPTIONS] [INPUT]\n\nOptions:\n  -d, --decode                 Decode printable-binary input\n  -s, --spaces                 Preserve literal spaces while encoding\n  -t, --tabs                   Preserve literal tabs while encoding\n  -n, --crlf                   Preserve literal CR and LF while encoding\n  -w, --preserve-whitespace    Preserve spaces, tabs, CR, and LF\n  -P, --preserve=CHARS         Preserve selected bytes while encoding\n  -p, --passthrough            Copy original input to stdout; encoded form to stderr\n  -S, --strip-whitespace       Remove transport whitespace before decoding\n  -C, --container              Encode or decode a printable-binary-file container\n      --range START-END        Limit input to an inclusive byte range\n      --start N --end N        Set inclusive range bounds\n      --mappings               Print the character mapping table\n      --mappings-json          Print mapping data as JSON\n      --mappings-csv           Print mapping data as CSV\n      --about                  Print implementation metadata\n  -h, --help                   Show this help\n"
