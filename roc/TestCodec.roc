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
