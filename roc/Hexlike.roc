Hexlike := {}.{
	encode : List(U8), Bool -> List(U8)
	encode = |input, spaces| {
		var $out = List.with_capacity(List.len(input) * 3)
		var $in_hex = False
		for byte in input {
			if passthrough(byte, spaces) {
				if $in_hex {
					$out = List.append($out, 32)
				}
				$out = List.append($out, byte)
				$in_hex = False
			} else {
				if Bool.not($in_hex) {
					if List.len($out) > 0 {
						$out = List.append($out, 32)
					}
					$out = List.concat($out, prefix)
				}
				$out = List.append($out, hex_digit(byte // 16))
				$out = List.append($out, hex_digit(byte % 16))
				$in_hex = True
			}
		}
		$out
	}

	decode : List(U8) -> List(U8)
	decode = |input| {
		var $out = List.with_capacity(List.len(input))
		var $index = 0
		while $index < List.len(input) {
			byte = List.get(input, $index) ?? crash "Hexlike decode index"
			marker_index = if byte == 32 and at_prefix(input, $index + 1) {
				$index + 1
			} else {
				$index
			}
			if at_prefix(input, marker_index) {
				$index = marker_index + 4
				var $reading = True
				while $reading and $index + 1 < List.len(input) {
					high = hex_value(List.get(input, $index) ?? 255)
					low = hex_value(List.get(input, $index + 1) ?? 255)
					if high < 16 and low < 16 {
						$out = List.append($out, high * 16 + low)
						$index = $index + 2
					} else {
						$reading = False
					}
				}
				if (List.get(input, $index) ?? 0) == 32 {
					$index = $index + 1
				}
			} else {
				$out = List.append($out, byte)
				$index = $index + 1
			}
		}
		$out
	}

	has_prefix : List(U8) -> Bool
	has_prefix = |input| {
		var $index = 0
		var $found = False
		while $index < List.len(input) and Bool.not($found) {
			$found = at_prefix(input, $index)
			$index = $index + 1
		}
		$found
	}

	detect : List(U8) -> Bool
	detect = |input| {
		var $index = 0
		var $found = False
		while $index + 5 < List.len(input) and Bool.not($found) {
			$found = at_prefix(input, $index)
				and hex_value(List.get(input, $index + 4) ?? 255) < 16
					and hex_value(List.get(input, $index + 5) ?? 255) < 16
			$index = $index + 1
		}
		$found
	}
}

prefix = "Οχ".to_utf8()

at_prefix : List(U8), U64 -> Bool
at_prefix = |input, index| List.starts_with(List.drop_first(input, index), prefix)

passthrough : U8, Bool -> Bool
passthrough = |byte, spaces| {
	byte == 46 or byte == 64 or byte == 94 or byte == 95
		or (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122) or (spaces and byte == 32)
}

hex_digit : U8 -> U8
hex_digit = |nibble| if nibble < 10 {
	nibble + 48
} else {
	nibble + 55
}

hex_value : U8 -> U8
hex_value = |byte| {
	if byte >= 48 and byte <= 57 {
		byte - 48
	}
		else if byte >= 65 and byte <= 70 {
			byte - 55
		}
			else if byte >= 97 and byte <= 102 {
				byte - 87
			}
				else {
					255
				}
}
