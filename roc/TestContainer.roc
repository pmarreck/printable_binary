import Container
import Map

sample = [0, 9, 10, 13, 32, 65, 255]

expect {
	json = Container.encode(sample, "sample.bin".to_utf8(), False, Map.glyphs)
	match Container.decode(json, Map.glyphs) {
		Ok(result) => result.bytes == sample and result.ignored_formatting_spaces == False
		Err(_) => False
	}
}

expect {
	glyph_zero = List.get(Map.glyphs, 0) ?? []
	wrapped_prefix = List.concat("{\"format\":\"printable-binary-file\",\"crc32_encoded\":\"ed10811c\",\"data\":\"\n\t".to_utf8(), glyph_zero)
	wrapped = List.concat(wrapped_prefix, " \n\"}".to_utf8())
	match Container.decode(wrapped, Map.glyphs) {
		Ok(result) => result.bytes == [0] and result.ignored_formatting_spaces == True
		Err(_) => False
	}
}

expect {
	corrupt = "{\"format\":\"printable-binary-file\",\"crc32_encoded\":\"00000000\",\"data\":\"A\"}".to_utf8()
	match Container.decode(corrupt, Map.glyphs) {
		Ok(_) => False
		Err(_) => True
	}
}
