const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get the guillotine dependency
    const guillotine_dep = b.dependency("guillotine", .{
        .target = target,
        .optimize = optimize,
    });
    
    const exe = b.addExecutable(.{
        .name = "guillotine-runner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add all the modules from guillotine
    exe.root_module.addImport("evm", guillotine_dep.module("evm"));
    exe.root_module.addImport("primitives", guillotine_dep.module("primitives"));
    exe.root_module.addImport("log", guillotine_dep.module("log"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    
    exe_unit_tests.root_module.addImport("evm", guillotine_dep.module("evm"));
    exe_unit_tests.root_module.addImport("primitives", guillotine_dep.module("primitives"));
    exe_unit_tests.root_module.addImport("log", guillotine_dep.module("log"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}