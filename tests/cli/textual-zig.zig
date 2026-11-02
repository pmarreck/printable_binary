//! Test/example adapter, deliberately separate from the installed CLI.
const std = @import("std");
const pb = @import("printable_binary");

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;
	const args = try init.minimal.args.toSlice(init.arena.allocator());
	if (args.len != 2) return error.ExpectedMode;
	var buffer: [4096]u8 = undefined;
	var reader = std.Io.File.stdin().readerStreaming(init.io, &buffer);
	const input = try reader.interface.allocRemaining(allocator, .unlimited);
	defer allocator.free(input);
	const output = if (std.mem.eql(u8, args[1], "encode-payload"))
		try pb.textual.encodePayload(allocator, input)
	else if (std.mem.eql(u8, args[1], "decode-payload"))
		try pb.textual.decodePayload(allocator, input)
	else if (std.mem.eql(u8, args[1], "encode"))
		try pb.textual.encode(allocator, input)
	else if (std.mem.eql(u8, args[1], "decode"))
		try pb.decodeAuto(allocator, input, .{})
	else
		return error.ExpectedMode;
	defer allocator.free(output);
	try std.Io.File.stdout().writeStreamingAll(init.io, output);
}
