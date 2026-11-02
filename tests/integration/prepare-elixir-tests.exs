[project, output] = System.argv()
File.cd!(project)
ExUnit.start(autorun: false, seed: 0)
File.mkdir_p!(output)

for file <- ["test/printable_binary_test.exs", "prepared_runner.ex"],
	{module, beam} <- Code.compile_file(file) do
	File.write!(Path.join(output, Atom.to_string(module) <> ".beam"), beam)
end
