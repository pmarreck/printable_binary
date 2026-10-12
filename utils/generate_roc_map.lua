#!/usr/bin/env luajit
-- Generate Roc's compile-time glyph table from the shared mapping source.

local input_path = assert(arg[1], "usage: generate_roc_map.lua CHARACTER_MAP OUTPUT")
local output_path = assert(arg[2], "usage: generate_roc_map.lua CHARACTER_MAP OUTPUT")

local input = assert(io.open(input_path, "rb"))
local source = input:read("*a")
input:close()

local glyphs = {}
for line in source:gmatch("[^\r\n]+") do
	if not line:match("^##") then
		local glyph = line:match("^([^%s]+)")
		if glyph then
			glyphs[#glyphs + 1] = glyph
		end
	end
end

assert(#glyphs == 256, ("expected 256 glyphs, got %d"):format(#glyphs))

local control_names = {
	"NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL",
	"BS", "TAB", "LF", "VT", "FF", "CR", "SO", "SI",
	"DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB",
	"CAN", "EM", "SUB", "ESC", "FS", "GS", "RS", "US",
}

local ascii_names = {}
for byte = 0, 255 do
	if byte <= 31 then
		ascii_names[#ascii_names + 1] = control_names[byte + 1]
	elseif byte == 32 then
		ascii_names[#ascii_names + 1] = "SPACE"
	elseif byte == 127 then
		ascii_names[#ascii_names + 1] = "DEL"
	elseif byte <= 126 then
		local char = string.char(byte)
		if char == "'" or char == "\\" then
			char = "\\" .. char
		end
		ascii_names[#ascii_names + 1] = "'" .. char .. "'"
	else
		ascii_names[#ascii_names + 1] = string.format("0x%02X", byte)
	end
end

local function roc_string(text)
	return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local output = assert(io.open(output_path, "wb"))
output:write("## Generated from character_map.txt by utils/generate_roc_map.lua.\n")
output:write("## Do not edit by hand.\n\n")
output:write("Map := {}.{\n\tglyphs : List(List(U8))\n\tglyphs = [\n")
for _, glyph in ipairs(glyphs) do
	output:write("\t\t", roc_string(glyph), ".to_utf8(),\n")
end
output:write("\t]\n\n\tascii_names : List(List(U8))\n\tascii_names = [\n")
for _, ascii_name in ipairs(ascii_names) do
	output:write("\t\t", roc_string(ascii_name), ".to_utf8(),\n")
end
output:write("\t]\n}\n")
output:close()
