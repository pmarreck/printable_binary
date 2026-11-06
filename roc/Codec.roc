Codec := {}.{
	encode : List(U8), List(List(U8)) -> List(U8)
	encode = |input, mapping| encode_spaces(input, mapping, False)

	encode_spaces : List(U8), List(List(U8)), Bool -> List(U8)
	encode_spaces = |input, mapping, spaces| encode_with(input, mapping, spaces, False, False, [])

	encode_with : List(U8), List(List(U8)), Bool, Bool, Bool, List(U8) -> List(U8)
	encode_with = |input, mapping, spaces, tabs, crlf, preserved| {
		var $out = List.with_capacity(List.len(input) * 3)
		for byte in input {
			if should_preserve(byte, spaces, tabs, crlf, preserved) {
				$out = List.append($out, byte)
			} else {
				glyph = List.get(mapping, U8.to_u64(byte)) ?? crash "PrintableBinary mapping is incomplete"
				$out = List.concat($out, glyph)
			}
		}
		$out
	}

	decode : List(U8), List(List(U8)), Bool, Bool -> List(U8)
	decode = |input, mapping, spaces, strip_whitespace| Codec.decode_report(input, mapping, spaces, strip_whitespace).bytes

	## Unknown wire bytes are preserved one byte at a time. The report retains
	## counts only; callers can inspect spans with the bounded next_event cursor.
	decode_report : List(U8), List(List(U8)), Bool, Bool -> Decoded
	decode_report = |input, mapping, spaces, strip_whitespace| {
		var $out = List.with_capacity(List.len(input))
		var $index = 0
		var $invalid_events = 0.U64
		var $invalid_bytes = 0.U64
		var $in_invalid_span = False
		while $index < List.len(input) {
			match next_token(input, $index, mapping, spaces, strip_whitespace) {
				Accepted(byte, width) => {
					$out = List.append($out, byte)
					$index = $index + width
					$in_invalid_span = False
				}
				Ignored => {
					$index = $index + 1
					$in_invalid_span = False
				}
				Invalid(byte) => {
					if Bool.not($in_invalid_span) {
						$invalid_events = $invalid_events + 1
					}
					$in_invalid_span = True
					$invalid_bytes = $invalid_bytes + 1
					$out = List.append($out, byte)
					$index = $index + 1
				}
			}
		}
		{ bytes: $out, report: { invalid_events: $invalid_events, invalid_bytes: $invalid_bytes } }
	}

	## Pure incremental event traversal. Input offsets include base; cursor
	## offsets remain relative to this input. Accepted/ignored tokens close spans.
	next_event : List(U8), List(List(U8)), Bool, Bool, U64, Cursor -> NextEvent
	next_event = |input, mapping, spaces, strip_whitespace, base, cursor| {
		var $index = cursor.input_offset
		var $output = cursor.output_offset
		while $index < List.len(input) {
			match next_token(input, $index, mapping, spaces, strip_whitespace) {
				Accepted(_, width) => {
					$index = $index + width
					$output = $output + 1
				}
				Ignored => { $index = $index + 1 }
				Invalid(_) => {
					start = $index
					output_start = $output
					var $at_end = False
					while $index < List.len(input) and Bool.not($at_end) {
						match next_token(input, $index, mapping, spaces, strip_whitespace) {
							Invalid(_) => {
								$index = $index + 1
								$output = $output + 1
							}
							Accepted(_, _) => { $at_end = True }
							Ignored => { $at_end = True }
						}
					}
					return Event({ input_offset: base + start, output_offset: output_start, input_length: $index - start, output_length: $output - output_start }, { input_offset: $index, output_offset: $output })
				}
			}
		}
		Done
	}

	is_likely_double_encoded : List(U8), List(List(U8)) -> Bool
	is_likely_double_encoded = |input, mapping| {
		input_length = List.len(input)
		input_length > 0 and count_encoded_glyphs(input, mapping, 0, 0) * 100 > input_length * 5
	}

	format_output : List(U8), U64, U64, Bool -> List(U8)
	format_output = |input, group_size, groups_per_line, spaces| {
		if group_size == 0 or groups_per_line == 0 {
			input
		} else {
			var $out = List.with_capacity(List.len(input))
			var $index = 0
			var $characters = 0.U64
			while $index < List.len(input) {
				first = List.get(input, $index) ?? crash "PrintableBinary format index"
				width = if first >= 240 {
					4.U64
				} else if first >= 224 {
					3
				} else if first >= 192 {
					2
				} else {
					1
				}
				remaining = List.len(input) - $index
				count = if width < remaining {
					width
				} else {
					remaining
				}
				$out = List.concat($out, List.take_first(List.drop_first(input, $index), count))
				$index = $index + count
				$characters = $characters + 1
				if $characters % group_size == 0 and $index < List.len(input) {
					separator = if ($characters // group_size) % groups_per_line == 0 {
						10.U8
					} else if spaces {
						9
					} else {
						32
					}
					$out = List.append($out, separator)
				}
			}
			$out
		}
	}
}

Report : { invalid_events : U64, invalid_bytes : U64 }
Decoded : { bytes : List(U8), report : Report }
Cursor : { input_offset : U64, output_offset : U64 }
ErrorEvent : { input_offset : U64, output_offset : U64, input_length : U64, output_length : U64 }
NextEvent : [Done, Event(ErrorEvent, Cursor)]
Token : [Accepted(U8, U64), Ignored, Invalid(U8)]

next_token : List(U8), U64, List(List(U8)), Bool, Bool -> Token
next_token = |input, index, mapping, spaces, strip_whitespace| {
	remaining = List.drop_first(input, index)
	mapped = find_mapping(remaining, mapping, 0)
	byte = List.get(input, index) ?? crash "PrintableBinary decode index"
	if mapped >= 0 {
		glyph = List.get(mapping, I64.to_u64_wrap(mapped)) ?? crash "PrintableBinary mapping is incomplete"
		Accepted(I64.to_u8_wrap(mapped), List.len(glyph))
	} else if spaces and byte == 32 {
		Accepted(32, 1)
	} else if strip_whitespace and should_strip(byte, spaces) {
		Ignored
	} else {
		Invalid(byte)
	}
}

should_preserve : U8, Bool, Bool, Bool, List(U8) -> Bool
should_preserve = |byte, spaces, tabs, crlf, preserved| {
	(spaces and byte == 32)
		or (tabs and byte == 9)
			or (crlf and (byte == 10 or byte == 13))
				or List.contains(preserved, byte)
}

count_encoded_glyphs : List(U8), List(List(U8)), U64, U64 -> U64
count_encoded_glyphs = |input, mapping, index, count| {
	if index >= List.len(input) {
		count
	} else {
		remaining = List.drop_first(input, index)
		mapped = find_mapping(remaining, mapping, 0)
		if mapped < 0 {
			count_encoded_glyphs(input, mapping, index + 1, count)
		} else {
			glyph = List.get(mapping, I64.to_u64_wrap(mapped)) ?? crash "PrintableBinary mapping is incomplete"
			first = List.get(glyph, 0) ?? crash "PrintableBinary glyph is empty"
			increment = if first >= 128 {
				1
			} else {
				0
			}
			count_encoded_glyphs(input, mapping, index + List.len(glyph), count + increment)
		}
	}
}

find_mapping : List(U8), List(List(U8)), U64 -> I64
find_mapping = |remaining, mapping, index| {
	if index >= List.len(mapping) {
		-1
	} else {
		glyph = List.get(mapping, index) ?? crash "PrintableBinary mapping is incomplete"
		if List.starts_with(remaining, glyph) {
			U64.to_i64_wrap(index)
		} else {
			find_mapping(remaining, mapping, index + 1)
		}
	}
}

should_strip : U8, Bool -> Bool
should_strip = |byte, spaces| {
	(byte == 9 or byte == 10 or byte == 13) or (byte == 32 and Bool.not(spaces))
}
