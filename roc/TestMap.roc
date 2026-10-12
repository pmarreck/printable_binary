import Codec
import Map

all_bytes = (0.U64).until(256).map(|index| U64.to_u8_wrap(index)) |> List.from_iter

expect List.len(Map.glyphs) == 256

expect Codec.decode(Codec.encode(all_bytes, Map.glyphs), Map.glyphs, False, False) == all_bytes

expect List.get(Map.glyphs, 0) == Ok("·".to_utf8())

expect List.get(Map.glyphs, 32) == Ok("␣".to_utf8())

expect List.get(Map.glyphs, 255) == Ok("Ż".to_utf8())

expect List.get(Map.ascii_names, 0) == Ok("NUL".to_utf8())

expect List.get(Map.ascii_names, 32) == Ok("SPACE".to_utf8())

expect List.get(Map.ascii_names, 255) == Ok("0xFF".to_utf8())
