import CliOutput
import Map

expect Str.starts_with(Str.from_utf8_lossy(CliOutput.mapping_table(Map.glyphs, Map.ascii_names)), "Byte   Dec   ASCII        Mapping\n0x00")

expect Str.starts_with(Str.from_utf8_lossy(CliOutput.mapping_json(Map.glyphs, Map.ascii_names)), "[{\"byte\":0,\"hex\":\"0x00\",\"dec\":0,\"ascii\":\"NUL\",\"mapping\":\"·\"}")

expect Str.starts_with(Str.from_utf8_lossy(CliOutput.mapping_csv(Map.glyphs, Map.ascii_names)), "byte,hex,dec,ascii,mapping\n0,0x00,0,\"NUL\",\"·\"\n")

expect CliOutput.input_throughput(1_000_000, 1_000_000_000) == "Input throughput: 1.00 MB read in 1.000 s (1.00 MB/s)\n".to_utf8()

expect CliOutput.input_throughput(0, 0) == "Input throughput: 0.00 MB read in 0.001 s (0.00 MB/s)\n".to_utf8()
