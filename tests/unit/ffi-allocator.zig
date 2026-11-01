const std = @import("std");

// The build graph supplies this allocator adapter only to the FFI test module.
pub var allocator: std.mem.Allocator = std.testing.allocator;
