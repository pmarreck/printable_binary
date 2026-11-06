//! C ABI (FFI) surface for printable_binary.
//!
//! This file is the root of the static FFI library (libprintable_binary.a) and
//! is the ONLY place the `export fn pb_*` C symbols are defined. The pure Zig
//! API lives in printable_binary.zig, which downstream Zig packages import
//! directly. Keeping the C exports out of the importable module is what lets
//! multiple static (musl) consumers link without colliding on
//! `duplicate symbol: pb_*` (see tests/test_module_no_ffi_symbols, and the difz
//! static-link failure that motivated this split).
const std = @import("std");
const pb = @import("printable_binary.zig");

const allocation = @import("ffi_allocator");

const DecodeEvent = extern struct {
	input_offset: usize, output_offset: usize, input_length: usize, output_length: usize,
	bytes: [*]const u8,
};
const DecodeReport = extern struct {
	output: pb.FFIResult,
	invalid_events: usize,
	invalid_bytes: usize,
};
const DecodeEventFn = *const fn (?*anyopaque, *const DecodeEvent) callconv(.c) c_int;

/// Reporting variant. Event pointers/spans are borrowed only during callback.
/// error_code 2 denotes callback failure; other fatal failures use code 1.
export fn pb_decode_report(input: ?[*]const u8, input_len: usize, flags: c_uint,
	input_base: usize, callback: ?DecodeEventFn, context: ?*anyopaque) callconv(.c) DecodeReport
{
	const failed: DecodeReport = .{ .output = .{ .data = null, .len = 0, .error_code = 1 }, .invalid_events = 0, .invalid_bytes = 0 };
	if (input == null and input_len != 0) return failed;
	const Sink = struct {
		callback: ?DecodeEventFn,
		context: ?*anyopaque,
		pub fn event(self: *@This(), value: pb.recovery.ErrorEvent) !void {
			if (self.callback) |emit| {
				const borrowed: DecodeEvent = .{ .input_offset = value.input_offset, .output_offset = value.output_offset,
					.input_length = value.input_length, .output_length = value.output_length, .bytes = value.bytes.ptr };
				if (emit(self.context, &borrowed) != 0) return error.SinkFailed;
			}
		}
	};
	var sink: Sink = .{ .callback = callback, .context = context };
	const bytes = if (input_len != 0) input.?[0..input_len] else &.{};
	const decoded = pb.recovery.decodeBytewise(allocation.allocator, bytes, .{
		.spaces = flags & @intFromEnum(pb.DecodeFlags.spaces_mode) != 0,
		.strip_whitespace = flags & @intFromEnum(pb.DecodeFlags.strip_whitespace) != 0,
		.input_base = input_base,
	}, &sink) catch |err| {
		var result = failed;
		if (err == error.SinkFailed) result.output.error_code = 2;
		return result;
	};
	return .{ .output = .{ .data = decoded.bytes.ptr, .len = decoded.bytes.len, .error_code = 0 },
		.invalid_events = decoded.summary.invalid_events, .invalid_bytes = decoded.summary.invalid_bytes };
}

/// C ABI export for double-encoding detection
export fn pb_detect_double_encode(input: ?[*]const u8, input_len: usize, threshold: f32) callconv(.c) pb.DoubleEncodeInfo {
	if (input == null and input_len > 0) {
		return pb.DoubleEncodeInfo{ .detected = 0, .confidence = 0.0 };
	}
	const slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	return pb.detectDoubleEncode(slice, threshold);
}

/// C ABI export for hexlike encoding. Caller must call pb_free() on result.data.
export fn pb_hexlike_encode(input: ?[*]const u8, input_len: usize, spaces: c_int) callconv(.c) pb.FFIResult {
	if (input == null and input_len > 0) {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	}
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	const result = pb.hexlikeEncode(allocation.allocator, input_slice, .{ .spaces = spaces != 0 }) catch {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	};
	return pb.FFIResult{ .data = result.ptr, .len = result.len, .error_code = 0 };
}

/// C ABI export for hexlike decoding. Caller must call pb_free() on result.data.
export fn pb_hexlike_decode(input: ?[*]const u8, input_len: usize, spaces: c_int) callconv(.c) pb.FFIResult {
	if (input == null and input_len > 0) {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	}
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	const result = pb.hexlikeDecode(allocation.allocator, input_slice, .{ .spaces = spaces != 0 }) catch {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	};
	return pb.FFIResult{ .data = result.data.ptr, .len = result.data.len, .error_code = 0 };
}

/// C ABI export for hexlike detection. Returns 1 if input appears hexlike, else 0.
export fn pb_detect_hexlike(input: ?[*]const u8, input_len: usize) callconv(.c) c_int {
	if (input == null and input_len > 0) return 0;
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	return if (pb.detectHexlike(input_slice)) 1 else 0;
}

/// C ABI export for validation function
export fn pb_validate(input: ?[*]const u8, input_len: usize, ws_flags: c_uint) callconv(.c) pb.ValidationResult {
	if (input == null and input_len > 0) {
		return pb.ValidationResult{ .is_valid = 0, .error_position = 0, .error_codepoint = 0 };
	}
	const slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	return pb.validate(slice, ws_flags);
}

/// C ABI export for range resolution function
export fn pb_apply_range(input_len: usize, has_start: c_int, start: i64, has_end: c_int, end: i64) callconv(.c) pb.RangeResult {
	const opt_start: ?i64 = if (has_start != 0) start else null;
	const opt_end: ?i64 = if (has_end != 0) end else null;
	return pb.applyRange(input_len, opt_start, opt_end);
}

/// Free memory allocated by pb_encode, pb_decode, or pb_format
export fn pb_free(ptr: ?[*]u8, len: usize) callconv(.c) void {
	if (ptr) |p| {
		allocation.allocator.free(p[0..len]);
	}
}

/// C ABI export for encode function
/// Caller must call pb_free() on result.data when done
export fn pb_encode(
	input: ?[*]const u8,
	input_len: usize,
	flags: c_uint,
	preserve_chars: ?[*]const u8,
	preserve_chars_len: usize,
) callconv(.c) pb.FFIResult {
	if (input == null and input_len > 0) {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	}
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};
	const preserve_slice = if (preserve_chars != null and preserve_chars_len > 0)
		preserve_chars.?[0..preserve_chars_len]
	else
		&[_]u8{};

	const options = pb.EncodeOptions{
		.spaces = (flags & @intFromEnum(pb.EncodeFlags.preserve_spaces)) != 0,
		.tabs = (flags & @intFromEnum(pb.EncodeFlags.preserve_tabs)) != 0,
		.crlf = (flags & @intFromEnum(pb.EncodeFlags.preserve_crlf)) != 0,
		.preserve_chars = preserve_slice,
	};

	const result = pb.encode(allocation.allocator, input_slice, options) catch {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	};

	return pb.FFIResult{
		.data = result.ptr,
		.len = result.len,
		.error_code = 0,
	};
}

/// C ABI export for decode function
/// Caller must call pb_free() on result.data when done
export fn pb_decode(
	input: ?[*]const u8,
	input_len: usize,
	flags: c_uint,
) callconv(.c) pb.FFIResult {
	if (input == null and input_len > 0) {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	}
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};

	const options = pb.DecodeOptions{
		.spaces = (flags & @intFromEnum(pb.DecodeFlags.spaces_mode)) != 0,
		.strip_whitespace = (flags & @intFromEnum(pb.DecodeFlags.strip_whitespace)) != 0,
	};

	const result = pb.decode(allocation.allocator, input_slice, options) catch {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	};

	return pb.FFIResult{
		.data = result.ptr,
		.len = result.len,
		.error_code = 0,
	};
}

/// C ABI export for format function
/// Caller must call pb_free() on result.data when done
export fn pb_format(
	input: ?[*]const u8,
	input_len: usize,
	group_size: usize,
	groups_per_line: usize,
	use_tabs: c_int,
) callconv(.c) pb.FFIResult {
	if (input == null and input_len > 0) {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	}
	const input_slice = if (input_len > 0) input.?[0..input_len] else &[_]u8{};

	const options = pb.FormatOptions{
		.group_size = if (group_size > 0) group_size else 8,
		.groups_per_line = if (groups_per_line > 0) groups_per_line else 10,
		.use_tabs = use_tabs != 0,
	};

	const result = pb.format(allocation.allocator, input_slice, options) catch {
		return pb.FFIResult{ .data = null, .len = 0, .error_code = 1 };
	};

	return pb.FFIResult{
		.data = result.ptr,
		.len = result.len,
		.error_code = 0,
	};
}

/// Get the mapping for a byte value (returns pointer to static data, do not free)
export fn pb_get_mapping(byte: u8) callconv(.c) [*]const u8 {
	return pb.character_map[byte].ptr;
}

/// Get the length of a mapping for a byte value
export fn pb_get_mapping_len(byte: u8) callconv(.c) usize {
	return pb.character_map[byte].len;
}

// =============================================================================
// Unit Tests (C ABI surface)
// =============================================================================

test "FFI: null input pointer with nonzero len returns error instead of crashing" {
	// A defensive C caller may pass NULL together with a stale, nonzero length.
	// Every C ABI entry point must report an error rather than dereference NULL.
	const enc = pb_encode(null, 100, 0, null, 0);
	try std.testing.expectEqual(@as(?[*]u8, null), enc.data);
	try std.testing.expect(enc.error_code != 0);

	const dec = pb_decode(null, 100, 0);
	try std.testing.expectEqual(@as(?[*]u8, null), dec.data);
	try std.testing.expect(dec.error_code != 0);

	const fmt = pb_format(null, 100, 8, 10, 0);
	try std.testing.expectEqual(@as(?[*]u8, null), fmt.data);
	try std.testing.expect(fmt.error_code != 0);

	const val = pb_validate(null, 100, 0);
	try std.testing.expect(val.is_valid == 0);
	try std.testing.expect(val.error_position == 0);

	const dbl = pb_detect_double_encode(null, 100, 0.5);
	try std.testing.expect(dbl.detected == 0);
	try std.testing.expect(dbl.confidence == 0.0);
}

test "FFI: report callback receives borrowed spans and failures release output" {
	const Callback = struct {
		count: usize = 0,
		fail: bool = false,
		fn emit(context: ?*anyopaque, event: *const DecodeEvent) callconv(.c) c_int {
			const self: *@This() = @ptrCast(@alignCast(context.?));
			self.count += 1;
			if (event.input_offset != 7 or event.output_offset != 0 or event.input_length != 1 or event.output_length != 1 or event.bytes[0] != 0xe0)
				return 1;
			return if (self.fail) 1 else 0;
		}
	};
	var callback: Callback = .{};
	const wire = "\xe0¶";
	const result = pb_decode_report(wire.ptr, wire.len, 0, 7, Callback.emit, &callback);
	try std.testing.expectEqual(@as(c_int, 0), result.output.error_code);
	defer pb_free(result.output.data, result.output.len);
	try std.testing.expectEqualStrings("\xe0\n", result.output.data.?[0..result.output.len]);
	try std.testing.expectEqual(@as(usize, 1), result.invalid_events);
	try std.testing.expectEqual(@as(usize, 1), result.invalid_bytes);
	try std.testing.expectEqual(@as(usize, 1), callback.count);
	callback.fail = true;
	const failed = pb_decode_report(wire.ptr, wire.len, 0, 7, Callback.emit, &callback);
	try std.testing.expectEqual(@as(c_int, 2), failed.output.error_code);
	try std.testing.expect(failed.output.data == null);
	const invalid = pb_decode_report(null, 1, 0, 0, null, null);
	try std.testing.expect(invalid.output.error_code != 0);
	const overflow = pb_decode_report(wire.ptr, wire.len, 0, std.math.maxInt(usize), null, null);
	try std.testing.expect(overflow.output.error_code != 0);
}

test "FFI: pb_hexlike_encode/decode roundtrip + detect + null safety" {
	const input = "Hi\xff!";
	const enc = pb_hexlike_encode(input.ptr, input.len, 0);
	try std.testing.expect(enc.error_code == 0);
	defer pb_free(enc.data, enc.len);
	try std.testing.expect(pb_detect_hexlike(enc.data, enc.len) == 1);
	const dec = pb_hexlike_decode(enc.data, enc.len, 0);
	try std.testing.expect(dec.error_code == 0);
	defer pb_free(dec.data, dec.len);
	try std.testing.expectEqualStrings(input, dec.data.?[0..dec.len]);
	// null safety
	const bad = pb_hexlike_encode(null, 100, 0);
	try std.testing.expect(bad.error_code != 0);
	try std.testing.expect(pb_detect_hexlike(null, 100) == 0);
}

/// FFI: CRC-32/ISO-HDLC of `len` bytes at `input`. Null ptr (or len 0) yields
/// the CRC of empty input (0). Delegates to the pure core `pb.crc32`.
export fn pb_crc32(input: ?[*]const u8, len: usize) callconv(.c) u32 {
	if (input == null or len == 0) return pb.crc32("");
	return pb.crc32(input.?[0..len]);
}

test "FFI: pb_crc32 matches vectors + null safety" {
	const s = "123456789";
	try std.testing.expectEqual(@as(u32, 0xCBF43926), pb_crc32(s.ptr, s.len));
	try std.testing.expectEqual(@as(u32, 0), pb_crc32(null, 100));
}

test "FFI: every complete lifecycle returns all requested bytes" {
	const adapter = @import("ffi_allocator");
	var tracker = std.testing.FailingAllocator.init(std.testing.allocator, .{});
	adapter.allocator = tracker.allocator();
	defer adapter.allocator = std.testing.allocator;
	for (0..16) |_| {
		try exerciseFfiLifecycle(adapter.allocator);
		// Positive allocation evidence prevents an unwired adapter from passing.
		try std.testing.expect(tracker.allocated_bytes > 0);
		try std.testing.expectEqual(tracker.allocated_bytes, tracker.freed_bytes);
	}
}

test "FFI: allocation failures release every partially completed lifecycle" {
	try std.testing.checkAllAllocationFailures(std.testing.allocator, exerciseFfiLifecycle, .{});
}

fn ffiBytes(result: pb.FFIResult) ![]const u8 {
	if (result.error_code != 0) return error.OutOfMemory;
	return result.data.?[0..result.len];
}

fn exerciseFfiLifecycle(allocator: std.mem.Allocator) !void {
	const adapter = @import("ffi_allocator");
	const previous = adapter.allocator;
	adapter.allocator = allocator;
	defer adapter.allocator = previous;
	const input = try std.testing.allocator.alloc(u8, 8192);
	defer std.testing.allocator.free(input);
	for (input, 0..) |*byte, index| byte.* = @truncate(index);
	for ([_]usize{ 0, 1, 2, 255, 256, 257, 8192 }) |len| {
		const original = input[0..len];
		const encoded = pb_encode(original.ptr, len, 0, null, 0);
		const bytes = try ffiBytes(encoded);
		defer pb_free(encoded.data, encoded.len);
		var offset: usize = 0;
		for (original) |byte| {
			const glyph = pb.character_map[byte];
			try std.testing.expect(bytes.len >= offset + glyph.len);
			try std.testing.expectEqualSlices(u8, glyph, bytes[offset..][0..glyph.len]);
			offset += glyph.len;
		}
		try std.testing.expectEqual(offset, bytes.len);
		try std.testing.expectEqual(@as(c_int, 1), pb_validate(encoded.data, encoded.len, 0).is_valid);
		const decoded = pb_decode(encoded.data, encoded.len, 0);
		const decoded_bytes = try ffiBytes(decoded);
		defer pb_free(decoded.data, decoded.len);
		try std.testing.expectEqualSlices(u8, original, decoded_bytes);
		const report = pb_decode_report(encoded.data, encoded.len, 0, 0, null, null);
		const reported_bytes = try ffiBytes(report.output);
		defer pb_free(report.output.data, report.output.len);
		try std.testing.expectEqualSlices(u8, original, reported_bytes);
		try std.testing.expectEqual(@as(usize, 0), report.invalid_events);
		try std.testing.expectEqual(@as(usize, 0), report.invalid_bytes);
		const formatted = pb_format(encoded.data, encoded.len, 8, 10, 0);
		_ = try ffiBytes(formatted);
		defer pb_free(formatted.data, formatted.len);
		const unformatted = pb_decode(formatted.data, formatted.len, @intFromEnum(pb.DecodeFlags.strip_whitespace));
		const unformatted_bytes = try ffiBytes(unformatted);
		defer pb_free(unformatted.data, unformatted.len);
		try std.testing.expectEqualSlices(u8, original, unformatted_bytes);
		const hex = pb_hexlike_encode(original.ptr, len, 0);
		_ = try ffiBytes(hex);
		defer pb_free(hex.data, hex.len);
		const unhex = pb_hexlike_decode(hex.data, hex.len, 0);
		const unhex_bytes = try ffiBytes(unhex);
		defer pb_free(unhex.data, unhex.len);
		try std.testing.expectEqualSlices(u8, original, unhex_bytes);
		_ = pb_detect_double_encode(encoded.data, encoded.len, 0.05);
		_ = pb_detect_hexlike(hex.data, hex.len);
	}
}
