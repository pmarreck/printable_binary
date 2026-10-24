const std = @import("std");

// References come from the canonical map fixture generator, outside the probe.
pub fn verify(input: []const u8, output: []const u8, pattern: []const u8, repetitions: usize, actual_count: usize, expected_count: usize) !void {
	if (output.ptr == input.ptr) return error.BorrowedOutput;
	if (output.len != pattern.len * repetitions) return error.WrongLength;
	if (actual_count != expected_count) return error.WrongCount;
	for (0..repetitions) |index| {
		if (!std.mem.eql(u8, output[index * pattern.len ..][0..pattern.len], pattern)) return error.WrongBytes;
	}
}

test "work oracle rejects wrong, truncated, miscounted and skipped results" {
	const input = "XYXY";
	const valid = [_]u8{ 'A', 'B', 'A', 'B' };
	try verify(input, &valid, "AB", 2, 4, 4);
	try std.testing.expectError(error.WrongBytes, verify(input, "ABAC", "AB", 2, 4, 4));
	try std.testing.expectError(error.WrongLength, verify(input, "AB", "AB", 2, 4, 4));
	try std.testing.expectError(error.WrongCount, verify(input, &valid, "AB", 2, 0, 4));
	try std.testing.expectError(error.BorrowedOutput, verify(input, input, "XY", 2, 0, 0));
}
