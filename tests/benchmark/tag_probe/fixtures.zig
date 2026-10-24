pub const Case = struct { name: []const u8, input: []const u8, expected: []const u8, count: []const u8 };
pub const cases = [_]Case{
	.{ .name = "ascii", .input = @embedFile("fixtures/ascii.input"), .expected = @embedFile("fixtures/ascii.expected"), .count = @embedFile("fixtures/ascii.count") },
	.{ .name = "spaces", .input = @embedFile("fixtures/spaces.input"), .expected = @embedFile("fixtures/spaces.expected"), .count = @embedFile("fixtures/spaces.count") },
	.{ .name = "alphabet", .input = @embedFile("fixtures/alphabet.input"), .expected = @embedFile("fixtures/alphabet.expected"), .count = @embedFile("fixtures/alphabet.count") },
	.{ .name = "unicode", .input = @embedFile("fixtures/unicode.input"), .expected = @embedFile("fixtures/unicode.expected"), .count = @embedFile("fixtures/unicode.count") },
	.{ .name = "sparse", .input = @embedFile("fixtures/sparse.input"), .expected = @embedFile("fixtures/sparse.expected"), .count = @embedFile("fixtures/sparse.count") },
	.{ .name = "dense", .input = @embedFile("fixtures/dense.input"), .expected = @embedFile("fixtures/dense.expected"), .count = @embedFile("fixtures/dense.count") },
	.{ .name = "encoded_header", .input = @embedFile("fixtures/encoded_header.input"), .expected = @embedFile("fixtures/encoded_header.expected"), .count = @embedFile("fixtures/encoded_header.count") },
};
