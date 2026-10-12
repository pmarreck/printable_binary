import Codec

CliCore := {}.{
	default_options : Options
	default_options = {
		decode: False,
		passthrough: False,
		spaces: False,
		tabs: False,
		crlf: False,
		strip_whitespace: False,
		preserve: [],
		container: False,
		no_double_encode_check: False,
		range_start: Absent,
		range_end: Absent,
		input: StandardInput,
	}

	parse : List(Str) -> ParseResult
	parse = |args| parse_args(args, 0, CliCore.default_options)

	transform : List(U8), Options, List(List(U8)) -> List(U8)
	transform = |input, options, mapping| {
		ranged = apply_range(input, options.range_start, options.range_end)
		if options.decode {
			Codec.decode(ranged, mapping, options.spaces, options.strip_whitespace)
		} else {
			Codec.encode_with(ranged, mapping, options.spaces, options.tabs, options.crlf, options.preserve)
		}
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
		} else if start > end {
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
	preserve : List(U8),
	container : Bool,
	no_double_encode_check : Bool,
	range_start : MaybeIndex,
	range_end : MaybeIndex,
	input : InputSource,
}

MaybeIndex : [Absent, Present(I64)]

InputSource : [StandardInput, Input(Str)]

ParseResult : [Run(Options), Help, About, MappingTable, MappingJson, MappingCsv, ParseError(Str)]

RangeWarning : [NoRangeWarning, RangeEndClamped, RangeStartExceedsInput, EmptyRange]

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
			} else if argument == "--passthrough" or argument == "-p" {
				parse_args(args, index + 1, { ..options, passthrough: True })
			} else if argument == "--container" or argument == "-C" {
				parse_args(args, index + 1, { ..options, container: True })
			} else if argument == "--no-double-encode-check" {
				parse_args(args, index + 1, { ..options, no_double_encode_check: True })
			} else if argument == "-stn" {
				parse_args(args, index + 1, { ..options, spaces: True, tabs: True, crlf: True })
			} else if Str.starts_with(argument, "--preserve=") {
				parse_args(args, index + 1, { ..options, preserve: Str.to_utf8(Str.drop_prefix(argument, "--preserve=")) })
			} else if Str.starts_with(argument, "-f") {
				parse_args(args, index + 1, options)
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
