//! Pure CLI mode policy; I/O and legacy feature selection stay in main.zig.
const std = @import("std");
const pb = @import("printable_binary");

test "CLI textual: recovery renderers are pure and JSON escapes warnings" {
	const diagnostics = @import("cli_recovery.zig");
	var buffer: [256]u8 = undefined;
	const event = pb.recovery.ErrorEvent{ .input_offset = 10, .output_offset = 3,
		.input_length = 6, .output_length = 2, .bytes = "abcdef" };
	try std.testing.expectEqualStrings("{\"type\":\"error\",\"input_offset\":10,\"output_offset\":3,\"input_length\":6,\"output_length\":2,\"hex\":\"",
		try diagnostics.eventHeader(&buffer, event, true));
	const line = try diagnostics.summaryLine(std.testing.allocator, .{ .summary = .{ .invalid_events = 1, .invalid_bytes = 6 },
		.input_bytes = 20, .output_bytes = 12, .elapsed_seconds = 2, .debug = true, .warnings = &.{"a\"b\nc"} });
	defer std.testing.allocator.free(line);
	const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, line, .{});
	defer parsed.deinit();
	try std.testing.expectEqualStrings("summary", parsed.value.object.get("type").?.string);
	try std.testing.expectEqual(@as(i64, 6), parsed.value.object.get("invalid_bytes").?.integer);
	try std.testing.expectEqualStrings("a\"b\nc", parsed.value.object.get("warnings").?.array.items[0].string);
}

pub const Options = struct {
	textual: bool = false,
	auto_decode: bool = false,
	untagged: bool = false,
	raw_input: bool = false,

	pub fn active(self: Options) bool {
		return self.textual or self.auto_decode or self.untagged or self.raw_input;
	}
};

pub fn validate(options: Options, decoding: bool) !void {
	if (options.textual and options.auto_decode) return error.IncompatibleCodecModes;
	if ((options.untagged or options.raw_input) and !options.textual) return error.TextualModeRequired;
	if (options.auto_decode and !decoding) return error.AutoRequiresDecode;
	if (options.raw_input and decoding) return error.RawInputEncodeOnly;
}

pub fn convert(allocator: std.mem.Allocator, input: []const u8, options: Options, decoding: bool, legacy: pb.DecodeOptions) ![]u8 {
	try validate(options, decoding);
	if (options.auto_decode) return pb.decodeAuto(allocator, input, legacy);
	if (!options.textual) return error.TextualModeRequired;
	if (decoding) return if (options.untagged) pb.textual.decodePayload(allocator, input) else pb.textual.decode(allocator, input);
	if (!options.untagged and !options.raw_input) {
		// Errors reserve the same namespace as valid openers; source examples can
		// always opt into literal encoding, without interpreting their bodies.
		const leading = pb.textual.frame(input) catch return error.AlreadyTaggedInput;
		if (leading != null) return error.AlreadyTaggedInput;
	}
	return if (options.untagged) pb.textual.encodePayload(allocator, input) else pb.textual.encode(allocator, input);
}

test "CLI textual: classify the complete option set" {
	for ([_]bool{ false, true }) |decoding| {
		const allowed: []const u8 = if (decoding) &.{ 0, 1, 2, 5 } else &.{ 0, 1, 5, 9, 13 };
		for (0..16) |mask| {
			const options = Options{
				.textual = mask & 1 != 0,
				.auto_decode = mask & 2 != 0,
				.untagged = mask & 4 != 0,
				.raw_input = mask & 8 != 0,
			};
			const actual = if (validate(options, decoding)) |_| true else |_| false;
			try std.testing.expectEqual(std.mem.indexOfScalar(u8, allowed, @intCast(mask)) != null, actual);
		}
	}
}

test "CLI textual: guard tagged encoding only, not explicit literal input" {
	const allocator = std.testing.allocator;
	for ([_][]const u8{ "\u{f000}ρΤ1_", "\u{f000}ρΒ_", "\u{f000}ρΤ2_", "\u{f000}ρΤ" }) |raw| {
		try std.testing.expectError(error.AlreadyTaggedInput, convert(allocator, raw, .{ .textual = true }, false, .{}));
		for ([_]Options{ .{ .textual = true, .raw_input = true }, .{ .textual = true, .untagged = true } }) |options| {
			const encoded = try convert(allocator, raw, options, false, .{});
			defer allocator.free(encoded);
			const decoded = try convert(allocator, encoded, .{ .textual = true, .untagged = options.untagged }, true, .{});
			defer allocator.free(decoded);
			try std.testing.expectEqualStrings(raw, decoded);
		}
	}
}
