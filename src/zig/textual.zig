//! Canonical arbitrary-byte textual v1 codec.
const std = @import("std");

pub fn Codec(comptime map: [256][]const u8) type {
	return struct {
		pub const marker = "\u{f000}";
		pub const tag = "\u{f000}ρΤ1_";
		pub const Kind = enum { bytewise, textual };
		pub const Frame = struct { kind: Kind, payload: []const u8 };
		const textual_namespace = "\u{f000}ρΤ";
		const bytewise_namespace = "\u{f000}ρΒ";

		/// One tagged value. Library input is raw, including literal tag examples.
		pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
			const payload = try encodePayload(allocator, input);
			defer allocator.free(payload);
			return std.mem.concat(allocator, u8, &.{ tag, payload });
		}

		pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
			const value = try frame(input) orelse return error.MissingTag;
			if (value.kind != .textual) return error.MismatchedTag;
			return decodePayload(allocator, value.payload);
		}

		/// Whole-value transport parsing, not mixed-region excerpt expansion.
		pub fn frame(input: []const u8) !?Frame {
			const kind: Kind = if (std.mem.startsWith(u8, input, textual_namespace))
				.textual
			else if (std.mem.startsWith(u8, input, bytewise_namespace))
				.bytewise
			else
				return null;
			const namespace = if (kind == .textual) textual_namespace else bytewise_namespace;
			const version = input[namespace.len..];
			const suffix_length: usize = if (std.mem.startsWith(u8, version, "_"))
				1
			else if (std.mem.startsWith(u8, version, "1_"))
				2
			else if (version.len == 0 or std.mem.eql(u8, version, "1"))
				return error.MalformedTag
			else if (version[0] == '1' and !std.ascii.isDigit(version[1]))
				return error.MalformedTag
			else if (std.ascii.isDigit(version[0]))
				return error.UnsupportedVersion
			else
				return error.MalformedTag;
			const body = input[namespace.len + suffix_length..];
			const ending = if (kind == .textual) "\u{f000}/ρΤ" else "\u{f000}/ρΒ";
			const other_ending = if (kind == .textual) "\u{f000}/ρΒ" else "\u{f000}/ρΤ";
			if (std.mem.endsWith(u8, body, other_ending)) return error.MismatchedTag;
			const payload = if (std.mem.endsWith(u8, body, ending)) body[0 .. body.len - ending.len] else body;
			return .{ .kind = kind, .payload = payload };
		}
		const reverse = std.StaticStringMap(u8).initComptime(blk: {
			var pairs: [256]struct { []const u8, u8 } = undefined;
			for (map, 0..) |entry, byte| {
				pairs[byte] = .{ if (byte == ' ') " " else entry, @intCast(byte) };
			}
			break :blk pairs;
		});
		const max_expansion = blk: {
			var max: usize = 3; // A quote adds three bytes to a >=2-byte scalar.
			for (map) |entry| max = @max(max, entry.len);
			break :blk max;
		};

		fn glyph(byte: u8) []const u8 {
			return if (byte == ' ') " " else map[byte];
		}

		fn append(output: []u8, offset: *usize, bytes: []const u8) void {
			@memcpy(output[offset.*..][0..bytes.len], bytes);
			offset.* += bytes.len;
		}

		fn sensitive(cp: u21) bool {
			const ranges = @import("textual_policy.zig").sensitive_ranges;
			var low: usize = 0;
			var high: usize = ranges.len;
			while (low < high) {
				const middle = low + (high - low) / 2;
				if (cp < ranges[middle][0]) high = middle else if (cp > ranges[middle][1]) low = middle + 1 else return true;
			}
			return false;
		}

		fn scalar(input: []const u8) ?struct { len: usize, cp: u21 } {
			const len = std.unicode.utf8ByteSequenceLength(input[0]) catch return null;
			if (len > input.len) return null;
			const cp = std.unicode.utf8Decode(input[0..len]) catch return null;
			return .{ .len = len, .cp = cp };
		}

		/// Caller owns the result. Incomplete/invalid source bytes use PB glyphs.
		pub fn encodePayload(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
			const output = try allocator.alloc(u8, try std.math.mul(usize, input.len, max_expansion));
			errdefer allocator.free(output);
			var source: usize = 0;
			var target: usize = 0;
			while (source < input.len) {
				const unit = scalar(input[source..]) orelse {
					append(output, &target, glyph(input[source]));
					source += 1;
					continue;
				};
				const bytes = input[source..][0..unit.len];
				if (unit.cp < 128) {
					append(output, &target, glyph(@intCast(unit.cp)));
				} else if (unit.cp == 0xf000) {
					append(output, &target, marker);
					append(output, &target, bytes);
				} else if (sensitive(unit.cp)) {
					for (bytes) |byte| append(output, &target, glyph(byte));
				} else {
					if (reverse.has(bytes)) append(output, &target, marker);
					append(output, &target, bytes);
				}
				source += unit.len;
			}
			return allocator.realloc(output, target);
		}

		/// Reject invalid quoting, invalid UTF-8 and noncanonical alternate spellings.
		pub fn decodePayload(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
			const view = try std.unicode.Utf8View.init(input);
			var iterator = view.iterator();
			const output = try allocator.alloc(u8, input.len);
			errdefer allocator.free(output);
			var target: usize = 0;
			while (iterator.nextCodepointSlice()) |bytes| {
				if (std.mem.eql(u8, bytes, marker)) {
					const quoted = iterator.nextCodepointSlice() orelse return error.InvalidEscape;
					if (!std.mem.eql(u8, quoted, marker) and !(quoted.len > 1 and reverse.has(quoted))) return error.InvalidEscape;
					append(output, &target, quoted);
				} else if (reverse.get(bytes)) |byte| {
					output[target] = byte;
					target += 1;
				} else append(output, &target, bytes);
			}
			const canonical = try encodePayload(allocator, output[0..target]);
			defer allocator.free(canonical);
			if (!std.mem.eql(u8, canonical, input)) return error.NonCanonical;
			return allocator.realloc(output, target);
		}
	};
}
