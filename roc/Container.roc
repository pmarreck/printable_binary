import Codec

Container := {}.{
	crc32 : List(U8) -> U32
	crc32 = |input| {
		var $crc = 0xFFFFFFFF
		for byte in input {
			$crc = crc_byte(U32.bitwise_xor($crc, U8.to_u32(byte)), 0)
		}
		U32.bitwise_not($crc)
	}

	encode : List(U8), List(U8), Bool, List(List(U8)) -> List(U8)
	encode = |input, filename, spaces, mapping| {
		data = Codec.encode_spaces(input, mapping, spaces)
		encoded_crc = crc32_hex(canonical_payload(data, spaces))
		var $out = "{\n  \"format\": \"printable-binary-file\",\n  \"version\": 1,\n  \"filename\": \"".to_utf8()
		$out = List.concat($out, json_escape(filename))
		$out = List.concat($out, "\",\n  \"byte_length\": ".to_utf8())
		$out = List.concat($out, U64.to_str(List.len(input)).to_utf8())
		$out = List.concat($out, "\n  \"crc32\": \"".to_utf8())
		$out = List.concat($out, crc32_hex(input))
		$out = List.concat($out, "\",\n  \"crc32_encoded\": \"".to_utf8())
		$out = List.concat($out, encoded_crc)
		$out = List.concat($out, "\",\n  \"data\": \"".to_utf8())
		$out = List.concat($out, data)
		List.concat($out, "\"\n}\n".to_utf8())
	}

	decode : List(U8), List(List(U8)) -> ContainerResult
	decode = |document, mapping| {
		match json_string(document, "format".to_utf8()) {
			Found(format) =>
				if format != "printable-binary-file".to_utf8() {
					Err(InvalidFormat)
				} else {
					decode_document(document, mapping)
				}
			Missing => Err(InvalidFormat)
		}
	}
}

ContainerResult : [
	Ok({ bytes : List(U8), ignored_formatting_spaces : Bool }),
	Err(ContainerError),
]

ContainerError : [InvalidFormat, MissingData, EncodedCrcMismatch, DecodedCrcMismatch]

crc_byte : U32, U8 -> U32
crc_byte = |crc, bit| {
	if bit == 8 {
		crc
	} else if U32.bitwise_and(crc, 1) == 1 {
		crc_byte(U32.bitwise_xor(U32.shr_zf_wrap(crc, 1), 0xEDB88320), bit + 1)
	} else {
		crc_byte(U32.shr_zf_wrap(crc, 1), bit + 1)
	}
}

decode_document : List(U8), List(List(U8)) -> ContainerResult
decode_document = |document, mapping| {
	match json_string(document, "data".to_utf8()) {
		Missing => Err(MissingData)
		Found(data) =>
			match decode_payload(data, json_string(document, "crc32_encoded".to_utf8()), mapping) {
				Err(err) => Err(err)
				Ok(result) =>
					match json_string(document, "crc32".to_utf8()) {
						Found(want) =>
							if crc32_hex(result.bytes) == want {
								Ok(result)
							} else {
								Err(DecodedCrcMismatch)
							}
						Missing => Ok(result)
					}
			}
	}
}

decode_payload : List(U8), JsonString, List(List(U8)) -> ContainerResult
decode_payload = |data, encoded_crc, mapping| {
	clean = canonical_payload(data, True)
	match encoded_crc {
		Missing => Ok({ bytes: Codec.decode(clean, mapping, True, True), ignored_formatting_spaces: False })
		Found(want) =>
			if crc32_hex(clean) == want {
				Ok({ bytes: Codec.decode(clean, mapping, True, True), ignored_formatting_spaces: False })
			} else {
				stripped = canonical_payload(data, False)
				if crc32_hex(stripped) == want {
					Ok({ bytes: Codec.decode(stripped, mapping, False, True), ignored_formatting_spaces: True })
				} else {
					Err(EncodedCrcMismatch)
				}
			}
	}
}

JsonString : [Found(List(U8)), Missing]

json_string : List(U8), List(U8) -> JsonString
json_string = |document, key| {
	field = List.concat(List.concat([34], key), [34])
	field_index = find_sequence(document, field, 0)
	if field_index < 0 {
		Missing
	} else {
		colon_index = find_byte(document, 58, I64.to_u64_wrap(field_index) + List.len(field))
		if colon_index < 0 {
			Missing
		} else {
			value_index = skip_json_whitespace(document, I64.to_u64_wrap(colon_index) + 1)
			if List.get(document, value_index) == Ok(34) {
				read_json_string(document, value_index + 1, [])
			} else {
				Missing
			}
		}
	}
}

find_sequence : List(U8), List(U8), U64 -> I64
find_sequence = |document, needle, index| {
	if index + List.len(needle) > List.len(document) {
		-1
	} else if List.starts_with(List.drop_first(document, index), needle) {
		U64.to_i64_wrap(index)
	} else {
		find_sequence(document, needle, index + 1)
	}
}

find_byte : List(U8), U8, U64 -> I64
find_byte = |document, needle, index| {
	if index >= List.len(document) {
		-1
	} else if List.get(document, index) == Ok(needle) {
		U64.to_i64_wrap(index)
	} else {
		find_byte(document, needle, index + 1)
	}
}

skip_json_whitespace : List(U8), U64 -> U64
skip_json_whitespace = |document, index| {
	match List.get(document, index) {
		Ok(byte) =>
			if byte == 9 or byte == 10 or byte == 13 or byte == 32 {
				skip_json_whitespace(document, index + 1)
			} else {
				index
			}
		Err(_) => index
	}
}

read_json_string : List(U8), U64, List(U8) -> JsonString
read_json_string = |document, index, out| {
	match List.get(document, index) {
		Ok(34) => Found(out)
		Ok(92) =>
			match List.get(document, index + 1) {
				Ok(34) => read_json_string(document, index + 2, List.append(out, 34))
				Ok(92) => read_json_string(document, index + 2, List.append(out, 92))
				Ok(110) => read_json_string(document, index + 2, List.append(out, 10))
				Ok(114) => read_json_string(document, index + 2, List.append(out, 13))
				Ok(116) => read_json_string(document, index + 2, List.append(out, 9))
				_ => Missing
			}
		Ok(byte) => read_json_string(document, index + 1, List.append(out, byte))
		Err(_) => Missing
	}
}

canonical_payload : List(U8), Bool -> List(U8)
canonical_payload = |data, keep_spaces| {
	var $out = List.with_capacity(List.len(data))
	for byte in data {
		if byte != 9 and byte != 10 and byte != 13 and (keep_spaces or byte != 32) {
			$out = List.append($out, byte)
		}
	}
	$out
}

json_escape : List(U8) -> List(U8)
json_escape = |input| {
	var $out = List.with_capacity(List.len(input))
	for byte in input {
		if byte == 34 or byte == 92 {
			$out = List.append($out, 92)
			$out = List.append($out, byte)
		} else if byte == 10 {
			$out = List.concat($out, [92, 110])
		} else if byte == 13 {
			$out = List.concat($out, [92, 114])
		} else if byte == 9 {
			$out = List.concat($out, [92, 116])
		} else {
			$out = List.append($out, byte)
		}
	}
	$out
}

crc32_hex : List(U8) -> List(U8)
crc32_hex = |input| {
	crc = Container.crc32(input)
	[
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 28), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 24), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 20), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 16), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 12), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 8), 15)),
		hex_digit(U32.bitwise_and(U32.shr_zf_wrap(crc, 4), 15)),
		hex_digit(U32.bitwise_and(crc, 15)),
	]
}

hex_digit : U32 -> U8
hex_digit = |nibble| {
	if nibble < 10 {
		U32.to_u8_wrap(nibble + 48)
	} else {
		U32.to_u8_wrap(nibble - 10 + 97)
	}
}
