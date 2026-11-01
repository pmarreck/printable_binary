import Hexlike

expect Hexlike.encode([], False) == []
expect Hexlike.decode([]) == []
expect Hexlike.encode([0, 1, 255], False) == "Οχ0001FF".to_utf8()
expect Hexlike.decode("Οχ0001ff".to_utf8()) == [0, 1, 255]
expect Hexlike.encode("A ,B".to_utf8(), True) == "A  Οχ2C B".to_utf8()
expect Hexlike.decode("A  Οχ2C B".to_utf8()) == "A ,B".to_utf8()
expect Hexlike.decode("Οχ".to_utf8()) == []
expect Hexlike.decode("ΟχF".to_utf8()) == "F".to_utf8()
expect Hexlike.decode("ΟχGG".to_utf8()) == "GG".to_utf8()
expect Hexlike.decode("Οχ00  A".to_utf8()) == [0, 32, 65]
expect Hexlike.decode("ΟχCE9FCF87".to_utf8()) == "Οχ".to_utf8()
expect Hexlike.has_prefix("A Οχ".to_utf8())
expect Bool.not(Hexlike.detect("A Οχ".to_utf8()))
expect Hexlike.detect("A Οχ00".to_utf8())
expect Bool.not(Hexlike.detect("A ΟχGG".to_utf8()))

expect {
	var $input = []
	for index in (0.U64).until(256) {
		$input = List.append($input, U64.to_u8_wrap(index))
	}
	var $correct = True
	for spaces in [False, True] {
		encoded = Hexlike.encode($input, spaces)
		$correct = $correct and Hexlike.decode(encoded) == $input
			and Hexlike.encode(Hexlike.decode(encoded), spaces) == encoded
	}
	$correct
}
