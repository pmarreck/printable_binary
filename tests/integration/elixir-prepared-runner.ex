defmodule PrintableBinary.PreparedTests do
	@retained_case_names [
		"test runtime uses UTF-8 native file names",
		"~PB decodes passthrough ASCII to itself",
		"~PB decodes control-char glyphs (byte 0 -> ·)",
		"whitespace inside the sigil is ignored (heredoc/wrapping-safe)",
		"decode/1 round-trips all 256 single-byte glyphs",
		"unrecognized glyph raises"
	]

	def run([all_encoded, all_raw, random_encoded, random_raw]) do
		ExUnit.start(autorun: false, seed: 0, max_cases: 2)
		Code.ensure_loaded!(PrintableBinaryTest)
		declared_tests = PrintableBinaryTest.__ex_unit__().tests
		names = MapSet.new(declared_tests, &Atom.to_string(&1.name))
		unless Enum.all?(@retained_case_names, &MapSet.member?(names, "test " <> &1)) and
			Enum.count(names, &String.starts_with?(&1, "doctest ")) == 1 do
			raise "missing original Elixir ExUnit/doctest coverage: #{inspect(names)}"
		end

		expected_total = length(declared_tests)
		stats = ExUnit.run([PrintableBinaryTest])

		unless stats == %{total: expected_total, failures: 0, excluded: 0, skipped: 0} do
			raise "expected all #{expected_total} declared Elixir ExUnit/doctest cases, got #{inspect(stats)}"
		end

		for {encoded, raw} <- [{all_encoded, all_raw}, {random_encoded, random_raw}] do
			unless PrintableBinary.decode(File.read!(encoded)) == File.read!(raw) do
				raise "Elixir decode(Zig encode) mismatch"
			end
		end

		IO.puts("PASS: retained Elixir tests and independent Zig fixtures")
	end
end
