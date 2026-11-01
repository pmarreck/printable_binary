const std = @import("std");

// The C ABI owns results until pb_free; no libc runtime is required.
pub const allocator = std.heap.page_allocator;
