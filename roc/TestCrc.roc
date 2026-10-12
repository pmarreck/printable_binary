import Container

expect Container.crc32([]) == 0

expect Container.crc32("123456789".to_utf8()) == 0xCBF43926

expect Container.crc32("a".to_utf8()) == 0xE8B7BE43

expect Container.crc32([0, 1, 255, 10]) == 0x5377A147
