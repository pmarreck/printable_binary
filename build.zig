const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode (default: ReleaseFast)") orelse .ReleaseFast;

    // =========================================================================
    // Core Library Module (for use by other Zig packages)
    // =========================================================================
    const lib_mod = b.addModule("printable_binary", .{
        .root_source_file = b.path("src/zig/printable_binary.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addAnonymousImport("character_map.txt", .{ .root_source_file = b.path("character_map.txt") });

    // =========================================================================
    // Static Library with C ABI (for FFI consumers like Cosmopolitan)
    // =========================================================================
    // Root is ffi.zig — the FFI-only file that holds every `export fn pb_*`.
    // It imports printable_binary.zig (relative), so the C ABI is emitted ONLY
    // here, never in the importable `printable_binary` module above. This is
    // what keeps static (musl) downstreams from colliding on duplicate pb_*
    // symbols. See src/zig/ffi.zig and tests/test_module_no_ffi_symbols.
    const static_lib_mod = b.createModule(.{
        .root_source_file = b.path("src/zig/ffi.zig"),
        .target = target,
        .optimize = optimize,
        // Position-independent so the static lib links into PIE executables
        // (the default on modern Linux) — required by FFI consumers.
        .pic = true,
    });
    static_lib_mod.addAnonymousImport("character_map.txt", .{ .root_source_file = b.path("character_map.txt") });
    static_lib_mod.addImport("ffi_allocator", b.createModule(.{
        .root_source_file = b.path("src/zig/ffi_allocator.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const static_lib = b.addLibrary(.{
        .name = "printable_binary",
        .linkage = .static,
        .root_module = static_lib_mod,
    });
    // C linkers do not supply Zig's stack-probe and arithmetic runtime symbols.
    static_lib.bundle_compiler_rt = true;

    // Install the static library
    b.installArtifact(static_lib);

    // Also install the header for convenience
    b.installFile("src/printable_binary.h", "include/printable_binary.h");

    // =========================================================================
    // CLI Executable (Zig 0.15 style with root_module)
    // =========================================================================
    // CLI uses std.Io.File.{stderr,stdout}().writeStreamingAll for all
    // stderr/stdout I/O (Zig 0.16 portable API), so libc is not required on
    // any platform — including Windows.
    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/zig/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "printable_binary", .module = lib_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "printable-binary",
        .root_module = cli_mod,
    });

    b.installArtifact(exe);

    // =========================================================================
    // Run Command
    // =========================================================================
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the CLI");
    run_step.dependOn(&run_cmd.step);

    // =========================================================================
    // Unit Tests (Zig 0.15 style with root_module)
    // =========================================================================
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/zig/printable_binary.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addAnonymousImport("character_map.txt", .{ .root_source_file = b.path("character_map.txt") });

    const lib_tests = b.addTest(.{
        .name = "test-core",
        .root_module = test_mod,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    const textual_example = b.addExecutable(.{
        .name = "textual-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/cli/textual-zig.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "printable_binary", .module = lib_mod }},
        }),
    });
    b.step("textual-example", "Prepare the textual codec differential adapter").dependOn(&b.addInstallArtifact(textual_example, .{
        .dest_dir = .{ .override = .{ .custom = "libexec" } },
    }).step);

    // FFI-surface tests (the C ABI wrappers now live in ffi.zig)
    const ffi_test_mod = b.createModule(.{
        .root_source_file = b.path("src/zig/ffi.zig"),
        .target = target,
        .optimize = optimize,
    });
    ffi_test_mod.addAnonymousImport("character_map.txt", .{ .root_source_file = b.path("character_map.txt") });
    const ffi_tests = b.addTest(.{
        .name = "test-ffi",
        .root_module = ffi_test_mod,
        .filters = &.{"FFI:"},
    });
    ffi_test_mod.addImport("ffi_allocator", b.createModule(.{
        .root_source_file = b.path("tests/unit/ffi-allocator.zig"),
        .target = target,
        .optimize = optimize,
    }));
    test_step.dependOn(&b.addRunArtifact(ffi_tests).step);

    const identity_tests = b.addTest(.{ .name = "test-platform-identity", .root_module = b.createModule(.{
        .root_source_file = b.path("src/zig/platform_identity.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    test_step.dependOn(&b.addRunArtifact(identity_tests).step);

    // The imported library's tests already run in test-core.
    const cli_textual_tests = b.addTest(.{ .name = "test-cli-textual", .filters = &.{"CLI textual:"}, .root_module = b.createModule(.{
        .root_source_file = b.path("src/zig/cli_textual.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "printable_binary", .module = lib_mod }},
    }) });
    test_step.dependOn(&b.addRunArtifact(cli_textual_tests).step);

    // Prepare exactly the same tests without executing them; Nix retains these
    // artifacts so fresh execution can be measured independently of compilation.
    const test_bins = b.step("test-bins", "Prepare unit-test executables without running them");
    for ([_]*std.Build.Step.Compile{ lib_tests, ffi_tests, identity_tests, cli_textual_tests }) |artifact| {
        test_bins.dependOn(&b.addInstallArtifact(artifact, .{
            .dest_dir = .{ .override = .{ .custom = "libexec" } },
        }).step);
    }

    // =========================================================================
    // Library-only step (for Makefile integration)
    // =========================================================================
    const lib_step = b.step("lib", "Build only the static library");
    lib_step.dependOn(&static_lib.step);

    // =========================================================================
    // Module-consumer static lib (FFI-symbol-leak regression test)
    // =========================================================================
    // Builds a downstream consumer that imports the `printable_binary` module
    // the way sibling Zig projects do. tests/test_module_no_ffi_symbols asserts
    // the resulting archive carries NO `pb_*` C symbols — they must originate
    // only in the FFI-root static library (libprintable_binary.a). See
    // tests/module_consumer.zig.
    const consumer_mod = b.createModule(.{
        .root_source_file = b.path("tests/module_consumer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "printable_binary", .module = lib_mod },
        },
    });
    const consumer_lib = b.addLibrary(.{
        .name = "module_consumer",
        .linkage = .static,
        .root_module = consumer_mod,
    });
    const consumer_lib_step = b.step("consumer-lib", "Build the module-consumer static lib (FFI-symbol-leak test fixture)");
    consumer_lib_step.dependOn(&b.addInstallArtifact(consumer_lib, .{}).step);

    // Benchmark-only generated core/fixtures are supplied by the Nix derivation.
    // Ordinary products never import the observer or acquire its mutable state.
    if (b.option(bool, "tag-probe", "Enable the benchmark-only namespace observer") orelse false) {
        const observer = b.createModule(.{ .root_source_file = b.path("tests/benchmark/tag_probe/observer.zig"), .target = target, .optimize = optimize });
        const instrumented = b.createModule(.{ .root_source_file = b.path("tests/benchmark/tag_probe/core.zig"), .target = target, .optimize = optimize });
        instrumented.addAnonymousImport("character_map.txt", .{ .root_source_file = b.path("character_map.txt") });
        instrumented.addImport("tag_probe", observer);
        const benchmark_module = b.createModule(.{
            .root_source_file = b.path("tests/benchmark/tag_probe/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{ .{ .name = "baseline", .module = lib_mod }, .{ .name = "observed", .module = instrumented }, .{ .name = "tag_probe", .module = observer } },
        });
        benchmark_module.addCSourceFile(.{ .file = b.path("tests/benchmark/tag_probe/clock.c"), .flags = &.{"-std=c11"} });
        const benchmark = b.addExecutable(.{ .name = "printable-binary-tag-probe", .root_module = benchmark_module });
        b.step("tag-probe", "Build the optimized tag namespace recognition experiment").dependOn(&b.addInstallArtifact(benchmark, .{}).step);
        const benchmark_tests = b.addTest(.{ .name = "test-tag-probe", .root_module = benchmark_module });
        b.step("test-tag-probe", "Verify recognition fixtures, work oracle and observer controls").dependOn(&b.addRunArtifact(benchmark_tests).step);
        b.step("tag-probe-test-bin", "Prepare the tag-probe tests without executing them").dependOn(&b.addInstallArtifact(benchmark_tests, .{
            .dest_dir = .{ .override = .{ .custom = "libexec" } },
        }).step);
    }
}
