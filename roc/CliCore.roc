import Codec
import Hexlike

CliCore := {}.{
	default_options : Options
	default_options = {
		decode: False,
		passthrough: False,
		spaces: False,
		tabs: False,
		crlf: False,
		strip_whitespace: False,
		strict: False,
		ndjson_stderr: False,
		preserve: [],
		container: False,
		hexlike: False,
		format_group: 0,
		format_lines: 10,
		no_double_encode_check: False,
		range_start: Absent,
		range_end: Absent,
		input: StandardInput,
	}

	parse : List(Str) -> ParseResult
	parse = |args| parse_args(args, 0, CliCore.default_options)

	## Warning storage is bounded independently of input/error event count.
	warnings : List(U8), Options, List(List(U8)) -> Warnings
	warnings = |input, options, mapping| {
		var $warnings = { messages: [], omitted: 0 }
		match CliCore.range_warning(input, options.range_start, options.range_end) {
			NoRangeWarning => {}
			RangeEndClamped => { $warnings = add_warning($warnings, "range end exceeds input size; clamping") }
			RangeStartExceedsInput => { $warnings = add_warning($warnings, "range start exceeds input size") }
			EmptyRange => { $warnings = add_warning($warnings, "empty range") }
		}
		if options.decode and options.spaces and options.strip_whitespace and CliCore.has_indented_spaces_after_newline(input) {
			$warnings = add_warning($warnings, "spaces after newline are preserved by --spaces while --strip-whitespace is active")
		}
		if Bool.not(options.container) {
			if options.decode and options.passthrough {
				$warnings = add_warning($warnings, "--passthrough ignored in decode mode")
			}
			if options.decode and options.hexlike and Bool.not(Hexlike.has_prefix(input)) {
				$warnings = add_warning($warnings, "no hexlike (Οχ) sequences found in input")
				if Codec.is_likely_double_encoded(input, mapping) {
					$warnings = add_warning($warnings, "input appears to contain standard printable-binary encoding")
				}
			} else if options.decode and Bool.not(options.hexlike) and Hexlike.detect(input) {
				$warnings = add_warning($warnings, "input appears to contain hexlike (Οχ) encoding; use --hexlike -d to decode")
			}
			if Bool.not(options.decode) and Bool.not(options.hexlike) and Bool.not(options.no_double_encode_check) and Codec.is_likely_double_encoded(input, mapping) {
				$warnings = add_warning($warnings, "input appears to be already encoded; continuing may double-encode it")
			}
		}
		$warnings
	}

	transform : List(U8), Options, List(List(U8)) -> List(U8)
	transform = |input, options, mapping| {
		ranged = apply_range(input, options.range_start, options.range_end)
		if options.hexlike {
			if options.decode {
				Hexlike.decode(ranged)
			} else {
				Hexlike.encode(ranged, options.spaces)
			}
		} else if options.decode {
			Codec.decode(ranged, mapping, options.spaces, options.strip_whitespace)
		} else {
			encoded = Codec.encode_with(ranged, mapping, options.spaces, options.tabs, options.crlf, options.preserve)
			Codec.format_output(encoded, options.format_group, options.format_lines, options.spaces)
		}
	}

	range_input : List(U8), Options -> { bytes : List(U8), input_base : U64 }
	range_input = |input, options| {
		start = resolve_start(options.range_start, U64.to_i64_wrap(List.len(input)))
		{ bytes: apply_range(input, options.range_start, options.range_end), input_base: if start < 0 0 else I64.to_u64_wrap(start) }
	}

	range_warning : List(U8), MaybeIndex, MaybeIndex -> RangeWarning
	range_warning = |input, start_option, end_option| {
		length = U64.to_i64_wrap(List.len(input))
		start = resolve_start(start_option, length)
		end = resolve_end(end_option, length)
		start_exceeds = match start_option {
			Absent => False
			Present(_) => start >= length
		}
		end_needs_clamp = match end_option {
			Absent => False
			Present(_) => end >= length
		}
		if start_exceeds {
			RangeStartExceedsInput
		} else if start > end and (start_option != Absent or end_option != Absent) {
			EmptyRange
		} else if end_needs_clamp {
			RangeEndClamped
		} else {
			NoRangeWarning
		}
	}

	has_indented_spaces_after_newline : List(U8) -> Bool
	has_indented_spaces_after_newline = |input| contains_indented_spaces_after_newline(input, False)
}

contains_indented_spaces_after_newline : List(U8), Bool -> Bool
contains_indented_spaces_after_newline = |input, after_newline| {
	match input {
		[] => False
		[byte, .. as rest] =>
			if after_newline and byte == 32 {
				True
			} else {
				contains_indented_spaces_after_newline(rest, byte == 10)
			}
	}
}

Options : {
	decode : Bool,
	passthrough : Bool,
	spaces : Bool,
	tabs : Bool,
	crlf : Bool,
	strip_whitespace : Bool,
	strict : Bool,
	ndjson_stderr : Bool,
	preserve : List(U8),
	container : Bool,
	hexlike : Bool,
	format_group : U64,
	format_lines : U64,
	no_double_encode_check : Bool,
	range_start : MaybeIndex,
	range_end : MaybeIndex,
	input : InputSource,
}

MaybeIndex : [Absent, Present(I64)]

InputSource : [StandardInput, Input(Str)]

ParseResult : [Run(Options), Help, About, MappingTable, MappingJson, MappingCsv, ParseError(Str)]

RangeWarning : [NoRangeWarning, RangeEndClamped, RangeStartExceedsInput, EmptyRange]

Warnings : { messages : List(Str), omitted : U64 }

add_warning : Warnings, Str -> Warnings
add_warning = |warnings, message| {
	if List.len(warnings.messages) < 8 {
		{ ..warnings, messages: List.append(warnings.messages, message) }
	} else {
		{ ..warnings, omitted: warnings.omitted + 1 }
	}
}

parse_args : List(Str), U64, Options -> ParseResult
parse_args = |args, index, options| {
	match List.get(args, index) {
		Err(_) => Run(options)
		Ok(argument) =>
			if argument == "--help" or argument == "-h" {
				Help
			} else if argument == "--about" {
				About
			} else if argument == "--mappings" {
				MappingTable
			} else if argument == "--mappings-json" {
				MappingJson
			} else if argument == "--mappings-csv" {
				MappingCsv
			} else if argument == "--decode" or argument == "-d" {
				parse_args(args, index + 1, { ..options, decode: True })
			} else if argument == "--spaces" or argument == "-s" {
				parse_args(args, index + 1, { ..options, spaces: True })
			} else if argument == "--tabs" or argument == "-t" {
				parse_args(args, index + 1, { ..options, tabs: True })
			} else if argument == "--crlf" or argument == "-n" {
				parse_args(args, index + 1, { ..options, crlf: True })
			} else if argument == "--preserve-whitespace" or argument == "-w" {
				parse_args(args, index + 1, { ..options, spaces: True, tabs: True, crlf: True })
			} else if argument == "--strip-whitespace" or argument == "-S" {
				parse_args(args, index + 1, { ..options, strip_whitespace: True })
			} else if argument == "--strict" {
				parse_args(args, index + 1, { ..options, strict: True })
			} else if argument == "--ndjson-stderr" {
				parse_args(args, index + 1, { ..options, ndjson_stderr: True })
			} else if argument == "--passthrough" or argument == "-p" {
				parse_args(args, index + 1, { ..options, passthrough: True })
			} else if argument == "--container" or argument == "-C" {
				parse_args(args, index + 1, { ..options, container: True })
			} else if argument == "--hexlike" or argument == "-X" {
				parse_args(args, index + 1, { ..options, hexlike: True })
			} else if argument == "-dX" or argument == "-Xd" {
				parse_args(args, index + 1, { ..options, hexlike: True, decode: True })
			} else if argument == "--no-double-encode-check" {
				parse_args(args, index + 1, { ..options, no_double_encode_check: True })
			} else if argument == "-stn" {
				parse_args(args, index + 1, { ..options, spaces: True, tabs: True, crlf: True })
			} else if Str.starts_with(argument, "--preserve=") {
				parse_args(args, index + 1, { ..options, preserve: Str.to_utf8(Str.drop_prefix(argument, "--preserve=")) })
			} else if argument == "-f" or argument == "--format" {
				parse_format_option(args, index, options, argument == "-f")
			} else if Str.starts_with(argument, "--format=") {
				apply_format(args, index + 1, options, Str.drop_prefix(argument, "--format="))
			} else if Str.starts_with(argument, "-f=") {
				apply_format(args, index + 1, options, Str.drop_prefix(argument, "-f="))
			} else if Str.starts_with(argument, "-f") {
				apply_format(args, index + 1, options, Str.drop_prefix(argument, "-f"))
			} else if argument == "--preserve" or argument == "-P" {
				match List.get(args, index + 1) {
					Ok(value) => parse_args(args, index + 2, { ..options, preserve: Str.to_utf8(value) })
					Err(_) => ParseError("Missing value for --preserve")
				}
			} else if argument == "--range" {
				parse_range_option(args, index, options)
			} else if argument == "--start" {
				parse_bound_option(args, index, options, True)
			} else if argument == "--end" {
				parse_bound_option(args, index, options, False)
			} else if Str.starts_with(argument, "-") {
				ParseError("Unknown option: ${argument}")
			} else {
				parse_positional(argument, args, index, options)
			}
	}
}

parse_format_option : List(Str), U64, Options, Bool -> ParseResult
parse_format_option = |args, index, options, allow_default| {
	match List.get(args, index + 1) {
		Ok(value) => match parse_format(value) {
			ParsedFormat(group_size, lines) => parse_args(args, index + 2, { ..options, format_group: group_size, format_lines: lines })
			InvalidFormat => if allow_default {
				parse_args(args, index + 1, { ..options, format_group: 8, format_lines: 10 })
			} else {
				ParseError("Invalid format: ${value}")
			}
		}
		Err(_) => if allow_default {
			parse_args(args, index + 1, { ..options, format_group: 8, format_lines: 10 })
		} else {
			ParseError("Missing format value")
		}
	}
}

apply_format : List(Str), U64, Options, Str -> ParseResult
apply_format = |args, next_index, options, value| {
	match parse_format(value) {
		ParsedFormat(group_size, lines) => parse_args(args, next_index, { ..options, format_group: group_size, format_lines: lines })
		InvalidFormat => ParseError("Invalid format: ${value}")
	}
}

FormatResult : [ParsedFormat(U64, U64), InvalidFormat]

parse_format : Str -> FormatResult
parse_format = |value| {
	match Str.split_first(value, "x") {
		Ok(parts) => match (U64.from_str(parts.before), U64.from_str(parts.after)) {
			(Ok(group_size), Ok(lines)) => if group_size > 0 and lines > 0 {
				ParsedFormat(group_size, lines)
			} else {
				InvalidFormat
			}
			_ => InvalidFormat
		}
		Err(_) => match U64.from_str(value) {
			Ok(group_size) => if group_size > 0 {
				ParsedFormat(group_size, 10)
			} else {
				InvalidFormat
			}
			Err(_) => InvalidFormat
		}
	}
}

parse_range_option : List(Str), U64, Options -> ParseResult
parse_range_option = |args, index, options| {
	match List.get(args, index + 1) {
		Err(_) => ParseError("Missing value for --range")
		Ok(specification) =>
			match parse_range(specification) {
				ParsedRange(range) => parse_args(args, index + 2, { ..options, range_start: range.start, range_end: range.end })
				InvalidRange => ParseError("Invalid range: ${specification}")
			}
	}
}

parse_bound_option : List(Str), U64, Options, Bool -> ParseResult
parse_bound_option = |args, index, options, is_start| {
	match List.get(args, index + 1) {
		Err(_) => ParseError("Missing range bound")
		Ok(specification) =>
			match parse_index(specification) {
				ParsedIndex(value) =>
					if is_start {
						parse_args(args, index + 2, { ..options, range_start: Present(value) })
					} else {
						parse_args(args, index + 2, { ..options, range_end: Present(value) })
					}
				InvalidIndex => ParseError("Invalid range bound: ${specification}")
			}
	}
}

parse_positional : Str, List(Str), U64, Options -> ParseResult
parse_positional = |argument, args, index, options| {
	match parse_range(argument) {
		ParsedRange(range) =>
			match options.range_start {
				Absent => parse_args(args, index + 1, { ..options, range_start: range.start, range_end: range.end })
				Present(_) => parse_input(argument, args, index, options)
			}
		InvalidRange => parse_input(argument, args, index, options)
	}
}

parse_input : Str, List(Str), U64, Options -> ParseResult
parse_input = |argument, args, index, options| {
	match options.input {
		StandardInput => parse_args(args, index + 1, { ..options, input: Input(argument) })
		Input(_) => ParseError("Only one input path is allowed")
	}
}

RangeResult : [ParsedRange({ start : MaybeIndex, end : MaybeIndex }), InvalidRange]

parse_range : Str -> RangeResult
parse_range = |specification| {
	match Str.split_first(specification, "-") {
		Err(_) => InvalidRange
		Ok(parts) => {
			start = parse_optional_index(parts.before)
			end = parse_optional_index(parts.after)
			match start {
				InvalidIndex => InvalidRange
				ParsedMaybeIndex(start_value) =>
					match end {
						InvalidIndex => InvalidRange
						ParsedMaybeIndex(end_value) => ParsedRange({ start: start_value, end: end_value })
					}
			}
		}
	}
}

IndexResult : [ParsedIndex(I64), InvalidIndex]

MaybeIndexResult : [ParsedMaybeIndex(MaybeIndex), InvalidIndex]

parse_optional_index : Str -> MaybeIndexResult
parse_optional_index = |text| {
	if text == "" {
		ParsedMaybeIndex(Absent)
	} else {
		match parse_index(text) {
			ParsedIndex(value) => ParsedMaybeIndex(Present(value))
			InvalidIndex => InvalidIndex
		}
	}
}

parse_index : Str -> IndexResult
parse_index = |text| {
	if Str.starts_with(text, "0x") or Str.starts_with(text, "0X") {
		parse_hex(Str.to_utf8(Str.drop_prefix(Str.drop_prefix(text, "0x"), "0X")), 0)
	} else {
		match I64.from_str(text) {
			Ok(value) => ParsedIndex(value)
			Err(_) => InvalidIndex
		}
	}
}

parse_hex : List(U8), I64 -> IndexResult
parse_hex = |digits, value| {
	match digits {
		[] => ParsedIndex(value)
		[digit, .. as rest] =>
			match hex_value(digit) {
				InvalidIndex => InvalidIndex
				ParsedIndex(nibble) => parse_hex(rest, value * 16 + nibble)
			}
	}
}

hex_value : U8 -> IndexResult
hex_value = |digit| {
	if digit >= 48 and digit <= 57 {
		ParsedIndex(U8.to_i64(digit) - 48)
	} else if digit >= 65 and digit <= 70 {
		ParsedIndex(U8.to_i64(digit) - 65 + 10)
	} else if digit >= 97 and digit <= 102 {
		ParsedIndex(U8.to_i64(digit) - 97 + 10)
	} else {
		InvalidIndex
	}
}

apply_range : List(U8), MaybeIndex, MaybeIndex -> List(U8)
apply_range = |input, start_option, end_option| {
	length = U64.to_i64_wrap(List.len(input))
	start = resolve_start(start_option, length)
	end = resolve_end(end_option, length)
	if start >= length or start > end {
		[]
	} else {
		clamped_start = if start < 0 {
			0
		} else {
			start
		}
		clamped_end = if end >= length {
			length - 1
		} else {
			end
		}
		if clamped_start > clamped_end {
			[]
		} else {
			List.take_first(List.drop_first(input, I64.to_u64_wrap(clamped_start)), I64.to_u64_wrap(clamped_end - clamped_start + 1))
		}
	}
}

resolve_start : MaybeIndex, I64 -> I64
resolve_start = |option, length| {
	match option {
		Absent => 0
		Present(value) => if value < 0 {
			length + value
		} else {
			value
		}
	}
}

resolve_end : MaybeIndex, I64 -> I64
resolve_end = |option, length| {
	match option {
		Absent => length - 1
		Present(value) => if value < 0 {
			length + value
		} else {
			value
		}
	}
}
