//! Pure diagnostic rendering and its thin streaming stderr adapter.
const std = @import("std");
const pb = @import("printable_binary");

pub fn eventHeader(buffer: []u8, value: pb.recovery.ErrorEvent, ndjson: bool) ![]const u8 {
	return if (ndjson)
		std.fmt.bufPrint(buffer, "{{\"type\":\"error\",\"input_offset\":{d},\"output_offset\":{d},\"input_length\":{d},\"output_length\":{d},\"hex\":\"", .{ value.input_offset, value.output_offset, value.input_length, value.output_length })
	else
		std.fmt.bufPrint(buffer, "Error: invalid encoded input input_offset={d} output_offset={d} input_length={d} output_length={d} hex=", .{ value.input_offset, value.output_offset, value.input_length, value.output_length });
}

pub const Stats = struct {
	summary: pb.recovery.Summary,
	input_bytes: usize,
	output_bytes: usize,
	elapsed_seconds: f64,
	debug: bool,
	warnings: []const []const u8 = &.{},
	warnings_omitted: usize = 0,
};

pub fn summaryLine(allocator: std.mem.Allocator, value: Stats) ![]u8 {
	const mbps = @as(f64, @floatFromInt(value.input_bytes)) / 1_000_000.0 / @max(value.elapsed_seconds, 0.0005);
	return std.json.Stringify.valueAlloc(allocator, .{ .type = "summary", .invalid_events = value.summary.invalid_events,
		.invalid_bytes = value.summary.invalid_bytes, .input_bytes = value.input_bytes, .output_bytes = value.output_bytes,
		.complete = true, .elapsed_seconds = value.elapsed_seconds, .input_mbps = mbps, .debug = value.debug,
		.warnings = value.warnings, .warnings_omitted = value.warnings_omitted }, .{});
}

pub const Sink = struct {
	io: std.Io,
	ndjson: bool,
	input_base: usize = 0,
	pub fn event(self: *@This(), original: pb.recovery.ErrorEvent) !void {
		var value = original;
		value.input_offset = try std.math.add(usize, value.input_offset, self.input_base);
		var buffer: [512]u8 = undefined;
		const stderr = std.Io.File.stderr();
		try stderr.writeStreamingAll(self.io, try eventHeader(&buffer, value, self.ndjson));
		const hex = "0123456789abcdef";
		var offset: usize = 0;
		while (offset < value.bytes.len) {
			// @min can infer a narrow integer; hex length must also hold 512.
			const count: usize = @min(buffer.len / 2, value.bytes.len - offset);
			for (value.bytes[offset..][0..count], 0..) |byte, index| {
				buffer[index * 2] = hex[byte >> 4]; buffer[index * 2 + 1] = hex[byte & 15];
			}
			try stderr.writeStreamingAll(self.io, buffer[0 .. count * 2]);
			offset += count;
		}
		try stderr.writeStreamingAll(self.io, if (self.ndjson) "\"}\n" else "\n");
	}
};
