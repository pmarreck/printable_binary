CliOutput := {}.{
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
