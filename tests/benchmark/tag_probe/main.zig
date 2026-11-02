const std = @import("std");
const baseline = @import("baseline");
const observed = @import("observed");
const probe = @import("tag_probe");
const fixtures = @import("fixtures.zig");
const oracle = @import("oracle.zig");
const sample_count = 5;
const warmup_count = 3;
extern "c" fn pb_probe_clock_ns(cpu: c_int, result: *u64) c_int;

fn clock(cpu: bool) !u64 {
	var result: u64 = undefined;
	if (pb_probe_clock_ns(@intFromBool(cpu), &result) != 0) return error.ClockFailed;
	return result;
}

const SystemClock = struct {
	fn read(_: @This(), cpu: bool) !u64 {
		return clock(cpu);
	}
};

fn elapsed(start: u64, end: u64) !u64 {
	if (end <= start) return error.InvalidClockInterval;
	return end - start;
}

const Sample = struct { cpu_ns: u64, wall_ns: u64 };
const Samples = struct { cpu_ns: [sample_count]u64 = undefined, wall_ns: [sample_count]u64 = undefined };

fn run(comptime instrumented: bool, allocator: std.mem.Allocator, input: []const u8, fixture: fixtures.Case, repetitions: usize, clock_reader: anytype) !Sample {
	probe.candidates = 0;
	const cpu_start = try clock_reader.read(true);
	const wall_start = try clock_reader.read(false);
	const output = if (instrumented) try observed.decode(allocator, input, .{}) else try baseline.decode(allocator, input, .{});
	defer allocator.free(output);
	const wall_end = try clock_reader.read(false);
	const cpu_end = try clock_reader.read(true);
	std.mem.doNotOptimizeAway(output);
	const count = try std.fmt.parseInt(usize, std.mem.trim(u8, fixture.count, "\n"), 10);
	try oracle.verify(input, output, fixture.expected, repetitions, probe.candidates, if (instrumented) count * repetitions else 0);
	return .{ .cpu_ns = try elapsed(cpu_start, cpu_end), .wall_ns = try elapsed(wall_start, wall_end) };
}

fn repeat(allocator: std.mem.Allocator, pattern: []const u8, repetitions: usize) ![]u8 {
	const result = try allocator.alloc(u8, pattern.len * repetitions);
	for (0..repetitions) |index| @memcpy(result[index * pattern.len ..][0..pattern.len], pattern);
	return result;
}

pub fn main(init: std.process.Init) !void {
	if (@import("builtin").mode != .ReleaseFast) return error.OptimizedBuildRequired;
	const allocator = std.heap.c_allocator;
	const args = try init.minimal.args.toSlice(init.arena.allocator());
	if (args.len != 4) return error.ExpectedCaseSizeSeed;
	const size = try std.fmt.parseInt(usize, args[2], 10);
	const seed: []const u8 = args[3];
	if (size < 1024 or size > 64 * 1024 * 1024) return error.SizeOutOfBounds;
	var selected: ?fixtures.Case = null;
	for (fixtures.cases) |fixture| {
		if (std.mem.eql(u8, args[1], fixture.name) or
			(std.mem.startsWith(u8, args[1], fixture.name) and args[1].len > fixture.name.len and args[1][fixture.name.len] == '-')) selected = fixture;
	}
	const fixture = selected orelse return error.UnknownCase;
	const repetitions = @max(1, size / fixture.input.len);
	const input = try repeat(allocator, fixture.input, repetitions);
	defer allocator.free(input);
	for (0..warmup_count) |_| {
		_ = try run(false, allocator, input, fixture, repetitions, SystemClock{});
		_ = try run(true, allocator, input, fixture, repetitions, SystemClock{});
	}
	var original: Samples = .{};
	var candidate: Samples = .{};
	for (0..sample_count) |index| {
		var a: Sample = undefined;
		var b: Sample = undefined;
		if (index % 2 == 0) {
			a = try run(false, allocator, input, fixture, repetitions, SystemClock{});
			b = try run(true, allocator, input, fixture, repetitions, SystemClock{});
		} else {
			b = try run(true, allocator, input, fixture, repetitions, SystemClock{});
			a = try run(false, allocator, input, fixture, repetitions, SystemClock{});
		}
		original.cpu_ns[index] = a.cpu_ns;
		original.wall_ns[index] = a.wall_ns;
		candidate.cpu_ns[index] = b.cpu_ns;
		candidate.wall_ns[index] = b.wall_ns;
	}
	const record = .{
		.schema = "performance-measurement/v1",
		.correct = true,
		.build_mode = "ReleaseFast",
		.toolchain = "Zig 0.16.0",
		.compiler_target = @tagName(@import("builtin").cpu.arch) ++ "-" ++ @tagName(@import("builtin").os.tag) ++ "-" ++ @tagName(@import("builtin").abi),
		.worker_threads = 1,
		.method = "paired-alternating-owned-decode/v1; allocation+shrink included; verification+free excluded",
		.clocks = "clock_gettime: CLOCK_PROCESS_CPUTIME_ID and CLOCK_MONOTONIC",
		.warmups = warmup_count,
		.seed = seed,
		.fixture = "deterministic-canonical-patterns/v1 (seed does not alter fixtures)",
		.scope = "namespace observer on raw decoder misses; not framing/version/quote/passthrough parsing",
		.rows = .{.{
			.size = size,
			.input_bytes = input.len,
			.decoded_bytes = fixture.expected.len * repetitions,
			.namespace_candidates = (try std.fmt.parseInt(usize, std.mem.trim(u8, fixture.count, "\n"), 10)) * repetitions,
			.samples = candidate,
			.baseline_samples = original,
		}},
	};
	const json = try std.json.Stringify.valueAlloc(allocator, record, .{});
	defer allocator.free(json);
	try std.Io.File.stdout().writeStreamingAll(init.io, json);
	try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

test "all generated fixture outputs and candidate counts survive repetition" {
	const FixtureClock = struct {
		calls: [4]bool = undefined,
		index: usize = 0,
		fn read(self: *@This(), cpu: bool) !u64 {
			self.calls[self.index] = cpu;
			self.index += 1;
			return self.index;
		}
	};
	for (fixtures.cases) |fixture| {
		const input = try repeat(std.testing.allocator, fixture.input, 3);
		defer std.testing.allocator.free(input);
		inline for (.{ false, true }) |instrumented| {
			var fixture_clock: FixtureClock = .{};
			const sample = try run(instrumented, std.testing.allocator, input, fixture, 3, &fixture_clock);
			try std.testing.expectEqual(@as(usize, 4), fixture_clock.index);
			try std.testing.expectEqualSlices(bool, &.{ true, false, false, true }, &fixture_clock.calls);
			try std.testing.expectEqual(Sample{ .cpu_ns = 3, .wall_ns = 1 }, sample);
		}
	}
}

test "invalid clock intervals fail rather than emitting zero measurements" {
	try std.testing.expectError(error.InvalidClockInterval, elapsed(2, 1));
	try std.testing.expectError(error.InvalidClockInterval, elapsed(2, 2));
	try std.testing.expectEqual(@as(u64, 3), try elapsed(2, 5));
}
