//! Pure CLI mode policy; I/O and legacy feature selection stay in main.zig.
const std = @import("std");
const pb = @import("printable_binary");

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
