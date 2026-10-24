const std = @import("std");
const builtin = @import("builtin");

pub fn platformName(os: std.Target.Os.Tag, arch: std.Target.Cpu.Arch) error{UnsupportedPlatform}![]const u8 {
    return switch (os) {
        .linux => switch (arch) {
            .x86_64 => "linux-amd64",
            .aarch64 => "linux-arm64",
            else => error.UnsupportedPlatform,
        },
        .macos => if (arch == .aarch64) "macos-arm64" else error.UnsupportedPlatform,
        .windows => switch (arch) {
            .x86_64 => "mswin-amd64",
            .aarch64 => "mswin-arm64",
            else => error.UnsupportedPlatform,
        },
        else => error.UnsupportedPlatform,
    };
}

pub fn variantName(abi: std.Target.Abi) ?[]const u8 {
    return switch (abi) {
        .gnu => "gnu",
        .musl => "musl",
        else => null,
    };
}

pub const pf = platformName(builtin.os.tag, builtin.cpu.arch) catch @compileError("Unsupported PrintableBinary platform");
pub const variant = variantName(builtin.abi);
pub const fields = "PF=" ++ pf ++ if (variant) |v| " VARIANT=" ++ v else "";

test "platform classifier accepts exactly the five declared pairs" {
    const operating_systems = [_]std.Target.Os.Tag{ .linux, .macos, .windows, .freebsd };
    const architectures = [_]std.Target.Cpu.Arch{ .x86_64, .aarch64, .x86, .arm };
    for (operating_systems) |os| {
        for (architectures) |arch| {
            const expected: ?[]const u8 = switch (os) {
                .linux => if (arch == .x86_64) "linux-amd64" else if (arch == .aarch64) "linux-arm64" else null,
                .macos => if (arch == .aarch64) "macos-arm64" else null,
                .windows => if (arch == .x86_64) "mswin-amd64" else if (arch == .aarch64) "mswin-arm64" else null,
                else => null,
            };
            if (expected) |value| {
                try std.testing.expectEqualStrings(value, try platformName(os, arch));
            } else {
                try std.testing.expectError(error.UnsupportedPlatform, platformName(os, arch));
            }
        }
    }
    try std.testing.expectEqualStrings("gnu", variantName(.gnu).?);
    try std.testing.expectEqualStrings("musl", variantName(.musl).?);
    try std.testing.expect(variantName(.none) == null);
    try std.testing.expect(variantName(.msvc) == null);
}
