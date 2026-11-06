//! Byte-preserving recovery with bounded token lookahead and borrowed events.
const std = @import("std");

pub fn Codec(comptime map: [256][]const u8) type {
	return struct {
		const Textual = @import("textual.zig").Codec(map);
		pub const Options = struct { spaces: bool = false, strip_whitespace: bool = false, input_base: usize = 0 };
		pub const Summary = struct {
			invalid_events: usize = 0,
			invalid_bytes: usize = 0,
			pub fn exitCode(self: @This()) u8 { return @intCast(@min(self.invalid_events, 255)); }
		};
		pub const ErrorEvent = struct {
			input_offset: usize, output_offset: usize, input_length: usize, output_length: usize, bytes: []const u8,
		};
		pub const Decoded = struct { bytes: []u8, summary: Summary };
		const reverse = std.StaticStringMap(u8).initComptime(blk: {
			var pairs: [256]struct { []const u8, u8 } = undefined;
			for (map, 0..) |entry, byte| pairs[byte] = .{ entry, @intCast(byte) };
			break :blk pairs;
		});
		const Token = struct { consumed: usize, bytes: [4]u8, length: usize };
		const Pending = struct { input: usize, output: usize };
		const Events = struct {
			pending: ?Pending = null,
			summary: Summary = .{},
			fn reject(self: *@This(), input: usize, output: usize) void {
				if (self.pending == null) self.pending = .{ .input = input, .output = output };
			}
			fn close(self: *@This(), input: []const u8, end: usize, output_end: usize, base: usize, sink: anytype) !void {
				if (self.pending) |start| {
					const length = end - start.input;
					try sink.event(ErrorEvent{ .input_offset = base + start.input, .output_offset = start.output,
						.input_length = length, .output_length = output_end - start.output, .bytes = input[start.input..end] });
					self.summary.invalid_events += 1; self.summary.invalid_bytes += length;
					self.pending = null;
				}
			}
		};
		fn width(byte: u8) usize {
			return if (byte < 128) 1 else if (byte < 0xe0) 2 else if (byte < 0xf0) 3 else 4;
		}
		fn scalar(input: []const u8) ?usize {
			const length = std.unicode.utf8ByteSequenceLength(input[0]) catch return null;
			if (length > input.len) return null;
			_ = std.unicode.utf8Decode(input[0..length]) catch return null;
			return length;
		}
		const Mapping = struct { byte: u8, length: usize };
		fn mapped(input: []const u8) ?Mapping {
			const length = width(input[0]);
			if (length > input.len) return null;
			const byte = reverse.get(input[0..length]) orelse return null;
			return .{ .byte = byte, .length = length };
		}
		pub fn decodeBytewise(allocator: std.mem.Allocator, input: []const u8, options: Options, sink: anytype) !Decoded {
			_ = try std.math.add(usize, options.input_base, input.len);
			const output = try allocator.alloc(u8, input.len);
			errdefer allocator.free(output);
			var source: usize = 0; var target: usize = 0; var events: Events = .{};
			while (source < input.len) {
				const byte = input[source];
				const ignored = options.strip_whitespace and (byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n') and !(options.spaces and byte == ' ');
				const known: ?Mapping = if (options.spaces and byte == ' ') .{ .byte = ' ', .length = 1 } else mapped(input[source..]);
				if (ignored or known != null) {
					try events.close(input, source, target, options.input_base, sink);
					if (ignored) source += 1 else if (known) |entry| { output[target] = entry.byte; target += 1; source += entry.length; }
				} else {
					events.reject(source, target); output[target] = byte; target += 1; source += 1;
				}
			}
			try events.close(input, source, target, options.input_base, sink);
			return .{ .bytes = try allocator.realloc(output, target), .summary = events.summary };
		}
		fn token(input: []const u8) Token {
			var result: Token = .{ .consumed = 1, .bytes = .{ input[0], 0, 0, 0 }, .length = 1 };
			const length = scalar(input) orelse return result;
			const bytes = input[0..length];
			result.consumed = length; result.length = length;
			@memcpy(result.bytes[0..length], bytes);
			if (std.mem.eql(u8, bytes, Textual.marker)) {
				if (length < input.len) {
					if (scalar(input[length..])) |next_length| {
						const next = input[length..][0..next_length];
						const quoted = reverse.get(next);
						if (std.mem.eql(u8, next, Textual.marker) or (next_length > 1 and quoted != null and quoted.? != ' ')) {
							result.consumed += next_length; result.length = next_length; @memcpy(result.bytes[0..next_length], next);
						}
					}
				}
			} else if (reverse.get(bytes)) |byte| {
				if (byte != ' ') { result.bytes[0] = byte; result.length = 1; }
			}
			return result;
		}
		fn unit(input: []const u8) Token {
			const first = token(input);
			if (first.length != 1 or first.bytes[0] < 128) return first;
			const wanted = std.unicode.utf8ByteSequenceLength(first.bytes[0]) catch return first;
			var combined = first;
			while (combined.length < wanted) {
				if (combined.consumed == input.len) return first;
				const next = token(input[combined.consumed..]);
				if (next.length != 1 or next.bytes[0] & 0xc0 != 0x80) return first;
				combined.bytes[combined.length] = next.bytes[0]; combined.length += 1; combined.consumed += next.consumed;
			}
			_ = std.unicode.utf8Decode(combined.bytes[0..wanted]) catch return first;
			return combined;
		}
		fn textualAt(allocator: std.mem.Allocator, input: []const u8, base: usize, sink: anytype) !Decoded {
			_ = try std.math.add(usize, base, input.len);
			const output = try allocator.alloc(u8, input.len);
			errdefer allocator.free(output);
			var source: usize = 0; var target: usize = 0; var events: Events = .{};
			while (source < input.len) {
				const current = unit(input[source..]);
				const canonical = Textual.encodeUnit(current.bytes[0..current.length]);
				if (std.mem.eql(u8, canonical.bytes[0..canonical.length], input[source..][0..current.consumed]))
					try events.close(input, source, target, base, sink)
				else events.reject(source, target);
				@memcpy(output[target..][0..current.length], current.bytes[0..current.length]);
				target += current.length; source += current.consumed;
			}
			try events.close(input, source, target, base, sink);
			return .{ .bytes = try allocator.realloc(output, target), .summary = events.summary };
		}
		pub fn decodeTextualPayload(allocator: std.mem.Allocator, input: []const u8, sink: anytype) !Decoded {
			return textualAt(allocator, input, 0, sink);
		}
		pub fn decodeTextual(allocator: std.mem.Allocator, input: []const u8, sink: anytype) !Decoded {
			const frame = try Textual.frame(input) orelse return error.MissingTag;
			if (frame.kind != .textual) return error.MismatchedTag;
			return textualAt(allocator, frame.payload, @intFromPtr(frame.payload.ptr) - @intFromPtr(input.ptr), sink);
		}
		pub fn decodeAuto(allocator: std.mem.Allocator, input: []const u8, options: Options, sink: anytype) !Decoded {
			if (try Textual.frame(input)) |frame| {
				const base = try std.math.add(usize, options.input_base, @intFromPtr(frame.payload.ptr) - @intFromPtr(input.ptr));
				if (frame.kind == .textual) return textualAt(allocator, frame.payload, base, sink);
				var bytewise_options = options; bytewise_options.input_base = base;
				return decodeBytewise(allocator, frame.payload, bytewise_options, sink);
			}
			return decodeBytewise(allocator, input, options, sink);
		}
	};
}
