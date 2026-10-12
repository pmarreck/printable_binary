import CliCore
import Map

expect {
	match CliCore.parse(["-d", "--spaces", "-S", "--range", "0x05-0x09", "input.bin"]) {
		Run(options) =>
			options.decode
				and options.spaces
					and options.strip_whitespace
						and options.range_start == Present(5)
							and options.range_end == Present(9)
								and options.input == Input("input.bin")
		_ => False
	}
}

expect {
	match CliCore.parse(["-stn"]) {
		Run(options) => options.spaces and options.tabs and options.crlf
		_ => False
	}
}

expect {
	base = CliCore.default_options
	options = { ..base, spaces: True, tabs: True, crlf: True, preserve: "!".to_utf8() }
	CliCore.transform([32, 9, 10, 13, 33], options, Map.glyphs) == [32, 9, 10, 13, 33]
}

expect {
	base = CliCore.default_options
	options = { ..base, decode: True, spaces: True, strip_whitespace: True }
	CliCore.transform("A B\nC\tD\rE".to_utf8(), options, Map.glyphs) == "A BCDE".to_utf8()
}

expect {
	base = CliCore.default_options
	options = { ..base, range_start: Present(-5) }
	CliCore.transform("abcdefghijklmnopqrstuvwxyz".to_utf8(), options, Map.glyphs) == "vwxyz".to_utf8()
}

expect CliCore.range_warning("abc".to_utf8(), Present(0), Present(99)) == RangeEndClamped

expect CliCore.range_warning("abc".to_utf8(), Present(99), Present(100)) == RangeStartExceedsInput

expect CliCore.range_warning("abcdefghijklmnopqrstuvwxyz".to_utf8(), Present(10), Present(5)) == EmptyRange

expect CliCore.has_indented_spaces_after_newline("A\n  B".to_utf8())

expect Bool.not(CliCore.has_indented_spaces_after_newline("A\nB C".to_utf8()))
