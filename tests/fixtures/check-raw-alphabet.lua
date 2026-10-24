-- Classify stdin using the independently supplied canonical glyph set.
local alphabet = {}
for line in io.lines(assert(arg[1])) do
	if not line:match("^##") then
		local glyph = line:match("^([^%s]+)")
		if glyph then alphabet[glyph] = true end
	end
end
local input, covered = io.read("*a"), 0
for glyph in input:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
	if not alphabet[glyph] then os.exit(1) end
	covered = covered + #glyph
end
if covered ~= #input then os.exit(1) end
