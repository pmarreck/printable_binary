-- Generate small input/reference patterns outside the timed benchmark kernel.
local map_path = assert(arg[1], "usage: generate-fixtures.lua MAP OUTPUT_DIRECTORY")
local output_dir = assert(arg[2], "missing output directory")
local glyphs = {}
for line in io.lines(map_path) do
	if not line:match("^##") then
		local glyph = line:match("^([^%s]+)")
		if glyph then glyphs[#glyphs + 1] = glyph end
	end
end
assert(#glyphs == 256, "expected the canonical 256-glyph mapping")

local bytes = {}
for byte = 0, 255 do bytes[#bytes + 1] = string.char(byte) end
local alphabet, raw = table.concat(glyphs), table.concat(bytes)
local martini = string.char(0xef, 0x80, 0x80)
local greek_letters = string.char(0xcf, 0x81, 0xce, 0x92)
local namespace = martini .. greek_letters
local opener, bare_opener = namespace .. "1_", namespace .. "_"
local closer = martini .. "/" .. greek_letters
local header_image = {}
for index = 1, #opener do
	header_image[#header_image + 1] = glyphs[opener:byte(index) + 1]
end

local cases = {
	{ "ascii", "ASCII_vector_0123456789", "ASCII_vector_0123456789" },
	{ "spaces", "ASCII vector 0123456789 ", "ASCII vector 0123456789 " },
	{ "alphabet", alphabet, raw },
	{ "unicode", "Greek " .. greek_letters .. " and supplementary 🔣", "Greek " .. greek_letters .. " and supplementary 🔣" },
	{ "sparse", alphabet:rep(32) .. opener .. closer .. "X", raw:rep(32) .. opener .. closer .. "X" },
	{ "dense", opener .. alphabet .. closer .. bare_opener .. alphabet .. closer .. "X", opener .. raw .. closer .. bare_opener .. raw .. closer .. "X" },
	{ "encoded_header", table.concat(header_image), opener },
}

local function write_new_or_identical(name, content)
	local path = output_dir .. "/" .. name
	local existing = io.open(path, "rb")
	if existing then
		local previous = existing:read("*a")
		existing:close()
		assert(previous == content, "refusing to overwrite a different fixture: " .. name)
		return
	end
	-- C11 exclusive mode also refuses existing or dangling-symlink destinations.
	local output = assert(io.open(path, "wbx"))
	assert(output:write(content))
	assert(output:close())
end

for _, case in ipairs(cases) do
	local name, input, expected = case[1], case[2], case[3]
	local position, candidates = 1, 0
	while true do
		local first, last = input:find(namespace, position, true)
		if not first then break end
		candidates, position = candidates + 1, last + 1
	end
	write_new_or_identical(name .. ".input", input)
	write_new_or_identical(name .. ".expected", expected)
	write_new_or_identical(name .. ".count", string.format("%d\n", candidates))
end
