local saved_arg = arg
arg = nil
local pb = dofile('bin/printable-binary-luajit')
arg = saved_arg

local function check(input, expected, events, options)
  local seen = 0
  local output, summary = pb.decode_report(input, options, function(event)
    seen = seen + 1
    local want = events[seen]
    assert(want, 'unexpected event')
    assert(event.type == 'error')
    assert(event.input == input, 'diagnostics retain the original wire input, not copied spans')
    assert(event.input_offset == want[1] and event.output_offset == want[2])
    assert(event.input_length == #want[3] and event.output_length == #want[3])
    assert(input:sub(event.input_start, event.input_start + event.input_length - 1) == want[3])
  end)
  assert(output == expected, 'byte-preserving recovery')
  assert(seen == #events and summary.invalid_events == seen)
  local invalid_bytes = 0
  for _, event in ipairs(events) do invalid_bytes = invalid_bytes + #event[3] end
  assert(summary.invalid_bytes == invalid_bytes)
  assert(pb.decode(input, options) == output, 'convenience decoder shares recovery semantics')
end
check('\224\194\182', '\224\10', {{0, 0, '\224'}})
check('\255\128A\0', '\255\128A\0', {{0, 0, '\255\128'}, {3, 3, '\0'}})
check('\194 \182', '\194\182', {{0, 0, '\194'}, {2, 1, '\182'}}, {strip_whitespace = true})
check('\255 \128', '\255 \128', {{7, 0, '\255'}, {9, 2, '\128'}}, {spaces = true, input_offset = 7})
check('¶\239\191\191A', '\10\239\191\191A', {{2, 1, '\239\191\191'}})
check('', '', {})
local sentinel = {}
local ok, failure = pcall(pb.decode_report, '\255', {}, function() error(sentinel) end)
assert(not ok and failure == sentinel, 'diagnostic sink failures propagate')
local values = {}
for byte = 0, 255 do values[#values + 1] = string.char(byte) end
local all = table.concat(values)
assert(pb.decode(pb.encode(all)) == all, 'exhaustive byte-map inverse')
print('PASS: LuaJIT bytewise recovery, borrowed spans and sink failures')
