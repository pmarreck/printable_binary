import Codec
import Map

mini_map = [[10], [20, 21], [30, 31, 32]]

expect Codec.encode([0, 1, 2, 1], mini_map) == [10, 20, 21, 30, 31, 32, 20, 21]

expect Codec.encode_spaces([0, 32, 1], mini_map, True) == [10, 32, 20, 21]

expect Codec.encode_with([32, 9, 10, 13, 33], Map.glyphs, True, True, True, "!".to_utf8()) == [32, 9, 10, 13, 33]

expect Codec.is_likely_double_encoded("······aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_utf8(), Map.glyphs)

expect Bool.not(Codec.is_likely_double_encoded("This is mostly ASCII with one middot · character in a very long string of text".to_utf8(), Map.glyphs))

expect Codec.decode([10, 20, 21, 30, 31, 32, 99], mini_map, False, False) == [0, 1, 2, 99]

expect Codec.decode([10, 32, 9, 13, 20, 21], mini_map, False, True) == [0, 1]

expect Codec.decode([10, 32, 9, 13, 20, 21], mini_map, True, True) == [0, 32, 1]

expect {
	decoded = Codec.decode_report([224, 194, 182, 255, 65, 128], Map.glyphs, False, False)
	decoded.bytes == [224, 10, 255, 65, 128]
		and decoded.report == { invalid_events: 3, invalid_bytes: 3 }
}

expect {
	decoded = Codec.decode_report([194, 32, 182], Map.glyphs, False, True)
	decoded.bytes == [194, 182] and decoded.report == { invalid_events: 2, invalid_bytes: 2 }
}

expect {
	decoded = Codec.decode_report(" A␣".to_utf8(), Map.glyphs, True, False)
	decoded.bytes == " A ".to_utf8() and decoded.report == { invalid_events: 0, invalid_bytes: 0 }
}

expect {
	input = "¶\u(ffff)A".to_utf8()
	match Codec.next_event(input, Map.glyphs, False, False, 7, { input_offset: 0, output_offset: 0 }) {
		Event(event, cursor) => event == { input_offset: 9, output_offset: 1, input_length: 3, output_length: 3 }
			and Codec.next_event(input, Map.glyphs, False, False, 7, cursor) == Done
		Done => False
	}
}
