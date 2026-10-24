const std = @import("std");

// Single-threaded benchmark state only; never imported by the shipping codec.
pub var candidates: usize = 0;
pub inline fn onMiss(remaining: []const u8) void {
	const namespace = "\xef\x80\x80\xcf\x81\xce\x92";
	if (remaining.len >= namespace.len and std.mem.eql(u8, remaining[0..namespace.len], namespace)) candidates += 1;
}

test "namespace observer classifies all prefix lengths and single-byte mutations" {
	const prefix = "\xef\x80\x80\xcf\x81\xce\x92";
	candidates = 0;
	for (0..prefix.len) |length| onMiss(prefix[0..length]);
	try std.testing.expectEqual(@as(usize, 0), candidates);
	onMiss(prefix);
	try std.testing.expectEqual(@as(usize, 1), candidates);
	for (0..prefix.len) |index| {
		for (0..256) |byte| {
			if (byte == prefix[index]) continue;
			var changed: [prefix.len]u8 = prefix.*;
			changed[index] = @intCast(byte);
			onMiss(&changed);
		}
	}
	try std.testing.expectEqual(@as(usize, 1), candidates);
}
