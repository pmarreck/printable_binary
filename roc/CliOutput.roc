import Codec

CliOutput := {}.{
	recovery_error_prefix : Codec.ErrorEvent -> List(U8)
	recovery_error_prefix = |event| "{\"type\":\"error\",\"input_offset\":${event.input_offset.to_str()},\"output_offset\":${event.output_offset.to_str()},\"input_length\":${event.input_length.to_str()},\"output_length\":${event.output_length.to_str()},\"hex\":\"".to_utf8()

	## Hex rendering is bounded even for a single arbitrarily long event.
	recovery_hex : List(U8), U64, U64 -> List(U8)
	recovery_hex = |input, start, requested| {
		count = if requested > 128 128 else requested
		var $out = List.with_capacity(count * 2)
		for index in start.until(start + count) {
			byte = List.get(input, index) ?? crash "PrintableBinary recovery hex index"
			$out = List.append($out, lower_hex_digit(byte // 16))
			$out = List.append($out, lower_hex_digit(byte % 16))
		}
		$out
	}

	recovery_summary : Codec.Report, U64, U64, { messages : List(Str), omitted : U64 } -> List(U8)
	recovery_summary = |report, input_bytes, output_bytes, warnings| {
		finish_summary("{\"type\":\"summary\",\"invalid_events\":${report.invalid_events.to_str()},\"invalid_bytes\":${report.invalid_bytes.to_str()},\"input_bytes\":${input_bytes.to_str()},\"output_bytes\":${output_bytes.to_str()},\"complete\":true".to_utf8(), warnings)
	}

	incomplete_summary : { messages : List(Str), omitted : U64 } -> List(U8)
	incomplete_summary = |warnings| finish_summary("{\"type\":\"summary\",\"invalid_events\":null,\"invalid_bytes\":null,\"input_bytes\":null,\"output_bytes\":null,\"complete\":false".to_utf8(), warnings)

	fatal_error : Str -> List(U8)
	fatal_error = |message| List.concat(List.concat("{\"type\":\"error\",\"fatal\":true,\"message\":\"".to_utf8(), json_escape(message.to_utf8())), "\"}\n".to_utf8())

	mapping_table : List(List(U8)), List(List(U8)) -> List(U8)
	mapping_table = |glyphs, ascii_names| {
		var $out = "Byte   Dec   ASCII        Mapping\n".to_utf8()
		for index in (0.U64).until(List.len(glyphs)) {
			glyph = List.get(glyphs, index) ?? crash "PrintableBinary mapping is incomplete"
			ascii_name = List.get(ascii_names, index) ?? crash "PrintableBinary ASCII names are incomplete"
			$out = List.concat($out, hex_byte(index))
			$out = List.concat($out, "   ".to_utf8())
			$out = List.concat($out, U64.to_str(index).to_utf8())
			$out = List.concat($out, "     ".to_utf8())
			$out = List.concat($out, ascii_name)
			$out = List.concat($out, "  ".to_utf8())
			$out = List.concat($out, glyph)
			$out = List.append($out, 10)
		}
		$out
	}

	mapping_json : List(List(U8)), List(List(U8)) -> List(U8)
	mapping_json = |glyphs, ascii_names| {
		var $out = [91]
		for index in (0.U64).until(List.len(glyphs)) {
			glyph = List.get(glyphs, index) ?? crash "PrintableBinary mapping is incomplete"
			ascii_name = List.get(ascii_names, index) ?? crash "PrintableBinary ASCII names are incomplete"
			if index > 0 {
				$out = List.append($out, 44)
			}
			$out = List.concat($out, "{\"byte\":".to_utf8())
			$out = List.concat($out, U64.to_str(index).to_utf8())
			$out = List.concat($out, ",\"hex\":\"".to_utf8())
			$out = List.concat($out, hex_byte(index))
			$out = List.concat($out, "\",\"dec\":".to_utf8())
			$out = List.concat($out, U64.to_str(index).to_utf8())
			$out = List.concat($out, ",\"ascii\":\"".to_utf8())
			$out = List.concat($out, json_escape(ascii_name))
			$out = List.concat($out, "\",\"mapping\":\"".to_utf8())
			$out = List.concat($out, json_escape(glyph))
			$out = List.concat($out, "\"}".to_utf8())
		}
		List.concat($out, "]\n".to_utf8())
	}

	mapping_csv : List(List(U8)), List(List(U8)) -> List(U8)
	mapping_csv = |glyphs, ascii_names| {
		var $out = "byte,hex,dec,ascii,mapping\n".to_utf8()
		for index in (0.U64).until(List.len(glyphs)) {
			glyph = List.get(glyphs, index) ?? crash "PrintableBinary mapping is incomplete"
			ascii_name = List.get(ascii_names, index) ?? crash "PrintableBinary ASCII names are incomplete"
			$out = List.concat($out, U64.to_str(index).to_utf8())
			$out = List.append($out, 44)
			$out = List.concat($out, hex_byte(index))
			$out = List.append($out, 44)
			$out = List.concat($out, U64.to_str(index).to_utf8())
			$out = List.concat($out, ",\"".to_utf8())
			$out = List.concat($out, csv_escape(ascii_name))
			$out = List.concat($out, "\",\"".to_utf8())
			$out = List.concat($out, csv_escape(glyph))
			$out = List.concat($out, "\"\n".to_utf8())
		}
		$out
	}

	input_throughput : U64, U64 -> List(U8)
	input_throughput = |input_bytes, elapsed_nanoseconds| {
		megabytes_hundredths = (input_bytes + 5_000) // 10_000
		effective_elapsed_nanoseconds = if elapsed_nanoseconds < 500_000 {
			500_000
		} else {
			elapsed_nanoseconds
		}
		elapsed_milliseconds = (effective_elapsed_nanoseconds + 500_000) // 1_000_000
		megabytes_per_second_hundredths = (input_bytes * 100_000 + (effective_elapsed_nanoseconds // 2)) // effective_elapsed_nanoseconds
		"Input throughput: ${fixed_2(megabytes_hundredths)} MB read in ${fixed_3(elapsed_milliseconds)} s (${fixed_2(megabytes_per_second_hundredths)} MB/s)\n".to_utf8()
	}
}

finish_summary : List(U8), { messages : List(Str), omitted : U64 } -> List(U8)
finish_summary = |prefix, warnings| {
	var $out = prefix
	if List.len(warnings.messages) > 0 {
		$out = List.concat($out, ",\"warnings\":[".to_utf8())
		var $first = True
		for message in warnings.messages {
			if Bool.not($first) {
				$out = List.append($out, 44)
			}
			$out = List.append($out, 34)
			$out = List.concat($out, json_escape(message.to_utf8()))
			$out = List.append($out, 34)
			$first = False
		}
		$out = List.append($out, 93)
	}
	if warnings.omitted > 0 {
		$out = List.concat($out, ",\"warnings_omitted\":${warnings.omitted.to_str()}".to_utf8())
	}
	List.concat($out, "}\n".to_utf8())
}

lower_hex_digit : U8 -> U8
lower_hex_digit = |nibble| if nibble < 10 nibble + 48 else nibble - 10 + 97

fixed_2 : U64 -> Str
fixed_2 = |hundredths| {
	whole = hundredths // 100
	fraction = hundredths % 100
	if fraction < 10 {
		"${U64.to_str(whole)}.0${U64.to_str(fraction)}"
	} else {
		"${U64.to_str(whole)}.${U64.to_str(fraction)}"
	}
}

fixed_3 : U64 -> Str
fixed_3 = |thousandths| {
	whole = thousandths // 1_000
	fraction = thousandths % 1_000
	if fraction < 10 {
		"${U64.to_str(whole)}.00${U64.to_str(fraction)}"
	} else if fraction < 100 {
		"${U64.to_str(whole)}.0${U64.to_str(fraction)}"
	} else {
		"${U64.to_str(whole)}.${U64.to_str(fraction)}"
	}
}

hex_byte : U64 -> List(U8)
hex_byte = |value| {
	byte = U64.to_u8_wrap(value)
	[48, 120, hex_digit(U8.shr_zf_wrap(byte, 4)), hex_digit(U8.bitwise_and(byte, 15))]
}

hex_digit : U8 -> U8
hex_digit = |nibble| {
	if nibble < 10 {
		nibble + 48
	} else {
		nibble - 10 + 65
	}
}

json_escape : List(U8) -> List(U8)
json_escape = |input| {
	var $out = List.with_capacity(List.len(input))
	for byte in input {
		if byte == 34 or byte == 92 {
			$out = List.append($out, 92)
			$out = List.append($out, byte)
		} else if byte < 32 {
			$out = List.concat($out, "\\u00".to_utf8())
			$out = List.append($out, lower_hex_digit(byte // 16))
			$out = List.append($out, lower_hex_digit(byte % 16))
		} else {
			$out = List.append($out, byte)
		}
	}
	$out
}

csv_escape : List(U8) -> List(U8)
csv_escape = |input| {
	var $out = List.with_capacity(List.len(input))
	for byte in input {
		$out = List.append($out, byte)
		if byte == 34 {
			$out = List.append($out, byte)
		}
	}
	$out
}
