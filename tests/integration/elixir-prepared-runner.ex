defmodule PrintableBinary.PreparedTests do
	def run([all_encoded, all_raw, random_encoded, random_raw]) do
		ExUnit.start(autorun: false, seed: 0, max_cases: 2)
		Code.ensure_loaded!(PrintableBinaryTest)
		stats = ExUnit.run([PrintableBinaryTest])

		unless match?(%{total: 7, failures: 0, excluded: 0, skipped: 0}, stats) do
			raise "expected all seven original ExUnit/doctest cases, got #{inspect(stats)}"
		end

		for {encoded, raw} <- [{all_encoded, all_raw}, {random_encoded, random_raw}] do
			unless PrintableBinary.decode(File.read!(encoded)) == File.read!(raw) do
				raise "Elixir decode(Zig encode) mismatch"
			end
		end

		IO.puts("PASS: retained Elixir tests and independent Zig fixtures")
	end
end
