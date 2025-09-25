const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Benchmarks must always use maximum performance optimization
    const optimize = std.builtin.OptimizeMode.ReleaseFast;

    // Build Guillotine - build both shared and static libraries
    const guillotine_build_cmd = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build",
        "-Doptimize=ReleaseFast",
    });
    guillotine_build_cmd.setCwd(b.path("guillotine"));
    guillotine_build_cmd.step.name = "Build Guillotine shared library";

    // Also build the static library
    const guillotine_static_cmd = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build",
        "static",
        "-Doptimize=ReleaseFast",
    });
    guillotine_static_cmd.setCwd(b.path("guillotine"));
    guillotine_static_cmd.step.name = "Build Guillotine static library";

    const guillotine_build = &guillotine_build_cmd.step;
    guillotine_static_cmd.step.dependOn(guillotine_build);

    // Add Cargo build step for Rust-based runners (REVM and Guillotine)
    const cargo_build = b.addSystemCommand(&[_][]const u8{
        "cargo",
        "build",
        "--release",
    });
    cargo_build.setCwd(b.path("."));
    cargo_build.step.name = "Build Rust runners (REVM & Guillotine)";
    cargo_build.step.dependOn(&guillotine_static_cmd.step);

    // Create a step that other steps can depend on
    const cargo_build_step = b.step("rust-runners", "Build the Rust-based EVM runners");
    cargo_build_step.dependOn(&cargo_build.step);

    // Add zig-clap dependency
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });

    // Build guillotine Bun SDK
    const guillotine_bun_build = b.addSystemCommand(&[_][]const u8{
        "bash",
        "./build.sh",
    });
    guillotine_bun_build.setCwd(b.path("guillotine/sdks/bun"));
    guillotine_bun_build.step.name = "Build guillotine Bun SDK";
    guillotine_bun_build.step.dependOn(guillotine_build);

    const guillotine_bun_build_step = b.step("build-guillotine-bun", "Build the guillotine Bun SDK");
    guillotine_bun_build_step.dependOn(&guillotine_bun_build.step);

    // Build Go runner executable
    const go_build = b.addSystemCommand(&[_][]const u8{
        "go",
        "build",
        "-o",
        "zig-out/bin/guillotine-go-runner",
        "src/guillotine_go_runner.go",
    });
    go_build.setCwd(b.path("."));
    go_build.step.name = "Build Go runner";

    const go_build_step = b.step("build-go", "Build the Go runner");
    go_build_step.dependOn(&go_build.step);

    // Build Geth runner executable
    const geth_runner_build = b.addSystemCommand(&[_][]const u8{
        "go",
        "build",
        "-o", "zig-out/bin/geth-runner",
        "src/geth_runner.go",
    });
    geth_runner_build.setCwd(b.path("."));
    geth_runner_build.step.name = "Build Geth runner";

    const geth_runner_build_step = b.step("build-geth-runner", "Build the Geth runner");
    geth_runner_build_step.dependOn(&geth_runner_build.step);

    // Build py-evm dependencies and copy runner
    const py_evm_setup = b.addSystemCommand(&[_][]const u8{
        "sh", "-c",
        "mkdir -p zig-out/bin && pip3 install py-evm eth-utils && chmod +x src/py_evm_runner.py && cp src/py_evm_runner.py zig-out/bin/py-evm-runner",
    });
    py_evm_setup.step.name = "Setup py-evm runner";

    const py_evm_setup_step = b.step("setup-py-evm", "Setup the py-evm runner");
    py_evm_setup_step.dependOn(&py_evm_setup.step);

    // Build ethereumjs dependencies and copy runner
    const ethereumjs_setup = b.addSystemCommand(&[_][]const u8{
        "sh", "-c",
        "mkdir -p zig-out/bin && npm install @ethereumjs/vm @ethereumjs/common @ethereumjs/util @ethereumjs/statemanager && chmod +x src/ethereumjs_runner.js && cp src/ethereumjs_runner.js zig-out/bin/ethereumjs-runner",
    });
    ethereumjs_setup.step.name = "Setup ethereumjs runner";

    const ethereumjs_setup_step = b.step("setup-ethereumjs", "Setup the ethereumjs runner");
    ethereumjs_setup_step.dependOn(&ethereumjs_setup.step);
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("bench", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // business logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "bench" is the name you will use in your source code to
                // import this module (e.g. `@import("bench")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "bench", .module = mod },
                .{ .name = "clap", .module = clap.module("clap") },
            },
        }),
    });

    // Make the executable depend on the Cargo build, Bun SDK, and all runner builds
    exe.step.dependOn(&cargo_build.step);
    exe.step.dependOn(&guillotine_bun_build.step);
    // exe.step.dependOn(&go_build.step); // Temporarily disabled - Go import issue
    exe.step.dependOn(&geth_runner_build.step);
    exe.step.dependOn(&py_evm_setup.step);
    exe.step.dependOn(&ethereumjs_setup.step);
    // Link with guillotine foundry compiler
    exe.root_module.addIncludePath(b.path("guillotine/lib/foundry-compilers"));
    // Determine the correct target directory based on the build target
    const rust_target_path = if (target.result.os.tag == .macos)
        if (target.result.cpu.arch == .aarch64)
            "guillotine/target/aarch64-apple-darwin/release-fast"
        else
            "guillotine/target/x86_64-apple-darwin/release-fast"
    else if (target.result.os.tag == .linux)
        if (target.result.cpu.arch == .aarch64)
            "guillotine/target/aarch64-unknown-linux-gnu/release-fast"
        else
            "guillotine/target/x86_64-unknown-linux-gnu/release-fast"
    else
        "guillotine/target/release";

    exe.root_module.addLibraryPath(b.path(rust_target_path));
    exe.root_module.linkSystemLibrary("foundry_wrapper", .{});
    exe.linkLibC();

    // Build guillotine runner executable using C API
    // Build blst library (from guillotine's c-kzg-4844 submodule)
    const blst_build_cmd = b.addSystemCommand(&.{
        "sh", "-c", "cd guillotine/lib/c-kzg-4844/blst && ./build.sh",
    });

    const blst_lib = b.addLibrary(.{
        .name = "blst",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    blst_lib.linkLibC();
    blst_lib.step.dependOn(&blst_build_cmd.step);
    blst_lib.addCSourceFiles(.{
        .files = &.{
            "guillotine/lib/c-kzg-4844/blst/src/server.c",
        },
        .flags = &.{ "-std=c99", "-D__BLST_PORTABLE__", "-fno-sanitize=undefined" },
    });
    blst_lib.addAssemblyFile(b.path("guillotine/lib/c-kzg-4844/blst/build/assembly.S"));
    blst_lib.addIncludePath(b.path("guillotine/lib/c-kzg-4844/blst/bindings"));

    // Build c-kzg-4844 library
    const c_kzg_lib = b.addLibrary(.{
        .name = "c-kzg-4844",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    c_kzg_lib.linkLibC();
    c_kzg_lib.linkLibrary(blst_lib);
    c_kzg_lib.addCSourceFiles(.{
        .files = &.{
            "guillotine/lib/c-kzg-4844/src/ckzg.c",
        },
        .flags = &.{ "-std=c99", "-fno-sanitize=undefined" },
    });
    c_kzg_lib.addIncludePath(b.path("guillotine/lib/c-kzg-4844/src"));
    c_kzg_lib.addIncludePath(b.path("guillotine/lib/c-kzg-4844/blst/bindings"));

    // Create build options for guillotine
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_precompiles", false);
    build_options.addOption(bool, "enable_bn254", false);
    build_options.addOption(bool, "no_bn254", true);
    build_options.addOption(bool, "no_precompiles", true);
    build_options.addOption(bool, "enable_fusion", true);
    build_options.addOption(bool, "enable_tracing", false);
    build_options.addOption([]const u8, "evm_hardfork", "CANCUN");
    build_options.addOption(bool, "disable_gas_checks", false);
    const build_options_mod = build_options.createModule();

    // Create c_kzg module
    const c_kzg_mod = b.createModule(.{
        .root_source_file = b.path("guillotine/lib/c-kzg-4844/bindings/zig/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    c_kzg_mod.linkLibrary(c_kzg_lib);
    c_kzg_mod.linkLibrary(blst_lib);
    c_kzg_mod.addIncludePath(b.path("guillotine/lib/c-kzg-4844/src"));
    c_kzg_mod.addIncludePath(b.path("guillotine/lib/c-kzg-4844/blst/bindings"));

    // Create primitives module
    const primitives_mod = b.createModule(.{
        .root_source_file = b.path("guillotine/src/primitives/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create crypto module
    const crypto_mod = b.createModule(.{
        .root_source_file = b.path("guillotine/src/crypto/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    crypto_mod.addImport("primitives", primitives_mod);
    crypto_mod.addImport("c_kzg", c_kzg_mod);
    crypto_mod.addImport("build_options", build_options_mod);

    // Primitives needs crypto for circular dependency
    primitives_mod.addImport("crypto", crypto_mod);

    // Create main guillotine module
    const guillotine_mod = b.createModule(.{
        .root_source_file = b.path("guillotine/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    guillotine_mod.addImport("primitives", primitives_mod);
    guillotine_mod.addImport("crypto", crypto_mod);
    guillotine_mod.addImport("build_options", build_options_mod);
    guillotine_mod.addImport("c_kzg", c_kzg_mod);

    // Create zbench module dependency
    const zbench_dep = b.dependency("zbench", .{ .target = target, .optimize = optimize });
    guillotine_mod.addImport("zbench", zbench_dep.module("zbench"));

    // Build the guillotine runner executable
    const guillotine_exe = b.addExecutable(.{
        .name = "guillotine-runner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/guillotine_runner.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "guillotine", .module = guillotine_mod },
                .{ .name = "primitives", .module = primitives_mod },
            },
        }),
        .use_llvm = true, // Force LLVM for tail calls
    });

    // Link libraries
    guillotine_exe.linkLibrary(c_kzg_lib);
    guillotine_exe.linkLibrary(blst_lib);
    guillotine_exe.linkLibC();

    // Make sure guillotine is built first
    guillotine_exe.step.dependOn(guillotine_build);

    b.installArtifact(guillotine_exe);

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Add benchmark step that runs all benchmarks
    const benchmark_step = b.step("benchmark", "Run all benchmarks and generate results.md");
    const benchmark_cmd = b.addRunArtifact(exe);
    benchmark_cmd.addArg("--results"); // Generate results.md with real data
    benchmark_step.dependOn(&benchmark_cmd.step);

    // Add benchmark-single step for running a specific benchmark
    const single_bench = b.option([]const u8, "bench", "Specific benchmark to run");
    if (single_bench) |bench_name| {
        const single_bench_step = b.step("benchmark-single", "Run a specific benchmark");
        const single_bench_cmd = b.addRunArtifact(exe);
        single_bench_cmd.addArg("-f");
        single_bench_cmd.addArg(bench_name);
        single_bench_step.dependOn(&single_bench_cmd.step);
    }
}
