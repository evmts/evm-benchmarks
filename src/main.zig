const std = @import("std");
const clap = @import("clap");
const fixture = @import("fixture.zig");

const c = @cImport({
    @cInclude("foundry_wrapper.h");
});

const BenchmarkResult = struct {
    name: []const u8,
    revm_mean: f64,
    ethrex_mean: f64,
    guillotine_mean: f64,
    guillotine_bun_mean: f64,
    guillotine_python_mean: f64,
    guillotine_go_mean: f64,
    pyrevm_mean: f64,
};

fn checkHyperfine(allocator: std.mem.Allocator) !bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "which", "hyperfine" },
    }) catch {
        return false;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term.Exited == 0;
}

fn printHyperfineInstallInstructions() !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(&buf);

    try writer.interface.print("\n", .{});
    try writer.interface.print("Error: hyperfine is not installed!\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("Please install hyperfine using one of the following methods:\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("  macOS (Homebrew):\n", .{});
    try writer.interface.print("    brew install hyperfine\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("  Linux (Cargo):\n", .{});
    try writer.interface.print("    cargo install hyperfine\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("  Ubuntu/Debian:\n", .{});
    try writer.interface.print("    wget https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb\n", .{});
    try writer.interface.print("    sudo dpkg -i hyperfine_1.18.0_amd64.deb\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("For more installation options, visit: https://github.com/sharkdp/hyperfine\n", .{});
    try writer.interface.print("\n", .{});

    try writer.interface.flush();
}

fn compileSolidity(allocator: std.mem.Allocator, contract_path: []const u8) ![]u8 {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(&buf);

    try writer.interface.print("Compiling {s} with guillotine compiler...\n", .{contract_path});
    try writer.interface.flush();

    // Get absolute path for proper import resolution
    var abs_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try std.fs.cwd().realpath(contract_path, &abs_path_buf);

    // Convert path to C string
    const contract_path_c = try allocator.dupeZ(u8, abs_path);
    defer allocator.free(contract_path_c);

    // Set up compiler settings
    var settings = c.foundry_CompilerSettings{
        .optimizer_enabled = true,
        .optimizer_runs = 200,
        .evm_version = null,
        .remappings = null,
        .cache_enabled = false,
        .cache_path = null,
        .output_abi = true,
        .output_bytecode = true,
        .output_deployed_bytecode = true,
        .output_ast = false,
    };

    // Call the compiler
    var result_ptr: ?*c.foundry_CompilationResult = null;
    var error_ptr: ?*c.foundry_FoundryError = null;

    const success = c.foundry_compile_file(
        contract_path_c.ptr,
        &settings,
        &result_ptr,
        &error_ptr,
    );

    if (success == 0) {
        if (error_ptr) |err| {
            defer c.foundry_free_error(err);
            const err_msg = c.foundry_get_error_message(err);
            try writer.interface.print("Compilation failed: {s}\n", .{err_msg});
            try writer.interface.flush();
            return error.CompilationFailed;
        }
        return error.CompilationFailed;
    }

    if (result_ptr == null) {
        return error.NoCompilationResult;
    }
    defer c.foundry_free_compilation_result(result_ptr);

    // Extract bytecode from first contract
    if (result_ptr.?.contracts_count == 0) {
        try writer.interface.print("No contracts compiled\n", .{});
        try writer.interface.flush();
        return error.NoContractsCompiled;
    }

    const first_contract = result_ptr.?.contracts[0];

    // Use deployed_bytecode for contract execution (runtime code)
    // This is the code that actually runs after the contract is deployed
    const bytecode_c = first_contract.deployed_bytecode;

    if (bytecode_c == null) {
        try writer.interface.print("No deployed bytecode found\n", .{});
        try writer.interface.flush();
        return error.NoDeployedBytecode;
    }

    // Convert C string to Zig string and make a copy
    const bytecode_slice = std.mem.span(bytecode_c);
    const bytecode = try allocator.dupe(u8, bytecode_slice);

    // Add 0x prefix if not present
    if (!std.mem.startsWith(u8, bytecode, "0x")) {
        const prefixed = try allocator.alloc(u8, bytecode.len + 2);
        prefixed[0] = '0';
        prefixed[1] = 'x';
        @memcpy(prefixed[2..], bytecode);
        allocator.free(bytecode);
        return prefixed;
    }

    return bytecode;
}

fn runBenchmarkWithResult(allocator: std.mem.Allocator, fixture_data: fixture.Fixture, bytecode: []const u8, internal_runs: u32) !BenchmarkResult {
    // Print progress
    const stdout = std.fs.File.stdout();
    var buf: [1024]u8 = undefined;
    var writer = stdout.writer(&buf);
    try writer.interface.print("  Running {s} benchmark ({} internal runs)...\n", .{ fixture_data.name, internal_runs });
    try writer.interface.flush();

    // Create temp file for JSON output
    const tmp_json = try std.fmt.allocPrint(allocator, "/tmp/bench_{s}.json", .{fixture_data.name});
    defer allocator.free(tmp_json);

    // Build commands with internal runs
    const revm_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(revm_cmd);

    const ethrex_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm ethrex --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm ethrex --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(ethrex_cmd);

    const guillotine_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-runner --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-runner --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_cmd);

    const guillotine_bun_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "bun src/guillotine_bun_runner.ts --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "bun src/guillotine_bun_runner.ts --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_bun_cmd);

    const guillotine_python_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "python3 src/guillotine_python_runner.py --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "python3 src/guillotine_python_runner.py --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_python_cmd);

    const guillotine_go_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-go-runner --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-go-runner --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_go_cmd);

    // Add pyrevm runner command
    const pyrevm_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "python3 src/pyrevm_runner.py --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "python3 src/pyrevm_runner.py --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(pyrevm_cmd);

    // Run hyperfine quietly with JSON export
    const hyperfine_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "hyperfine",
            "--shell=none",
            "--warmup",
            "2",
            "--runs",
            "5",
            "--show-output",
            "--export-json",
            tmp_json,
            "-n",
            "revm",
            revm_cmd,
            "-n",
            "ethrex",
            ethrex_cmd,
            "-n",
            "guillotine",
            guillotine_cmd,
            "-n",
            "guillotine-bun",
            guillotine_bun_cmd,
            "-n",
            "guillotine-python",
            guillotine_python_cmd,
            "-n",
            "guillotine-go",
            guillotine_go_cmd,
            "-n",
            "pyrevm",
            pyrevm_cmd,
        },
    });
    defer allocator.free(hyperfine_result.stdout);
    defer allocator.free(hyperfine_result.stderr);

    // Debug: print hyperfine stderr if not empty
    if (hyperfine_result.stderr.len > 0) {
        try writer.interface.print("Hyperfine stderr: {s}\n", .{hyperfine_result.stderr});
        try writer.interface.flush();
    }

    // Read and parse JSON - simple parsing for the mean values
    const json_content = try std.fs.cwd().readFileAlloc(allocator, tmp_json, 1024 * 1024);
    defer allocator.free(json_content);

    // Quick and dirty JSON parsing for the mean times
    // Look for "mean": X.XXX pattern
    var revm_mean: f64 = 0;
    var ethrex_mean: f64 = 0;
    var guillotine_mean: f64 = 0;
    var guillotine_bun_mean: f64 = 0;
    var guillotine_python_mean: f64 = 0;
    var guillotine_go_mean: f64 = 0;
    var pyrevm_mean: f64 = 0;

    // Find the results array
    if (std.mem.indexOf(u8, json_content, "\"results\":")) |results_start| {
        var search_pos = results_start;
        var evm_index: usize = 0;

        // Find each mean value in order
        while (std.mem.indexOf(u8, json_content[search_pos..], "\"mean\":")) |mean_offset| {
            const mean_start = search_pos + mean_offset + 7; // Skip "mean":
            search_pos = mean_start;

            // Skip whitespace
            var pos = mean_start;
            while (pos < json_content.len and (json_content[pos] == ' ' or json_content[pos] == '\t')) : (pos += 1) {}

            // Find the end of the number
            var end = pos;
            while (end < json_content.len and (json_content[end] == '.' or (json_content[end] >= '0' and json_content[end] <= '9') or json_content[end] == 'e' or json_content[end] == 'E' or json_content[end] == '-')) : (end += 1) {}

            const mean_str = json_content[pos..end];
            const mean_value = std.fmt.parseFloat(f64, mean_str) catch 0;

            // Convert to milliseconds and normalize by internal runs
            const mean_ms = (mean_value * 1000.0) / @as(f64, @floatFromInt(internal_runs));

            if (evm_index == 0) revm_mean = mean_ms else if (evm_index == 1) ethrex_mean = mean_ms else if (evm_index == 2) guillotine_mean = mean_ms else if (evm_index == 3) guillotine_bun_mean = mean_ms else if (evm_index == 4) guillotine_python_mean = mean_ms else if (evm_index == 5) guillotine_go_mean = mean_ms else if (evm_index == 6) pyrevm_mean = mean_ms;

            evm_index += 1;
            if (evm_index >= 7) break;
        }
    }

    // Clean up temp file
    std.fs.cwd().deleteFile(tmp_json) catch {};

    return BenchmarkResult{
        .name = try allocator.dupe(u8, fixture_data.name),
        .revm_mean = revm_mean,
        .ethrex_mean = ethrex_mean,
        .guillotine_mean = guillotine_mean,
        .guillotine_bun_mean = guillotine_bun_mean,
        .guillotine_python_mean = guillotine_python_mean,
        .guillotine_go_mean = guillotine_go_mean,
        .pyrevm_mean = pyrevm_mean,
    };
}

fn generateResultsMarkdown(allocator: std.mem.Allocator, results: []const BenchmarkResult, internal_runs: u32) !void {
    const file = try std.fs.cwd().createFile("results.md", .{});
    defer file.close();

    try file.writeAll("# EVM Benchmark Results\n\n");

    // Add note about internal runs
    const runs_note = try std.fmt.allocPrint(allocator, "_Times shown are per-execution averages from {} internal runs per benchmark._\n\n", .{internal_runs});
    defer allocator.free(runs_note);
    try file.writeAll(runs_note);

    try file.writeAll("## Performance Comparison\n\n");
    try file.writeAll("| Benchmark | REVM (ms) | ethrex (ms) | Guillotine (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Guillotine-Go (ms) | PyREVM (ms) | Fastest |\n");
    try file.writeAll("|-----------|-----------|-------------|-----------------|---------------------|------------------------|--------------------|---------|---------|-\n");

    for (results) |res| {
        // Find fastest
        var fastest: []const u8 = "REVM";
        var fastest_time = res.revm_mean;
        if (res.ethrex_mean < fastest_time) {
            fastest = "ethrex";
            fastest_time = res.ethrex_mean;
        }
        if (res.guillotine_mean < fastest_time) {
            fastest = "Guillotine";
            fastest_time = res.guillotine_mean;
        }
        if (res.guillotine_bun_mean < fastest_time) {
            fastest = "Guillotine-Bun";
            fastest_time = res.guillotine_bun_mean;
        }
        if (res.guillotine_python_mean < fastest_time) {
            fastest = "Guillotine-Python";
            fastest_time = res.guillotine_python_mean;
        }
        if (res.guillotine_go_mean < fastest_time) {
            fastest = "Guillotine-Go";
            fastest_time = res.guillotine_go_mean;
        }
        if (res.pyrevm_mean < fastest_time) {
            fastest = "PyREVM";
        }

        const row = try std.fmt.allocPrint(allocator, "| {s} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {s} |\n", .{
            res.name,
            res.revm_mean,
            res.ethrex_mean,
            res.guillotine_mean,
            res.guillotine_bun_mean,
            res.guillotine_python_mean,
            res.guillotine_go_mean,
            res.pyrevm_mean,
            fastest,
        });
        defer allocator.free(row);
        try file.writeAll(row);
    }

    try file.writeAll("\n## Summary Statistics\n\n");

    // Calculate averages
    var total_revm: f64 = 0;
    var total_ethrex: f64 = 0;
    var total_guillotine: f64 = 0;
    var total_guillotine_bun: f64 = 0;
    var total_guillotine_python: f64 = 0;
    var total_guillotine_go: f64 = 0;
    var total_pyrevm: f64 = 0;

    for (results) |res| {
        total_revm += res.revm_mean;
        total_ethrex += res.ethrex_mean;
        total_guillotine += res.guillotine_mean;
        total_guillotine_bun += res.guillotine_bun_mean;
        total_guillotine_python += res.guillotine_python_mean;
        total_guillotine_go += res.guillotine_go_mean;
        total_pyrevm += res.pyrevm_mean;
    }

    const n = @as(f64, @floatFromInt(results.len));
    const summary = try std.fmt.allocPrint(allocator, "- **Average REVM time**: {d:.2} ms\n- **Average ethrex time**: {d:.2} ms\n- **Average Guillotine time**: {d:.2} ms\n- **Average Guillotine-Bun time**: {d:.2} ms\n- **Average Guillotine-Python time**: {d:.2} ms\n- **Average Guillotine-Go time**: {d:.2} ms\n- **Average PyREVM time**: {d:.2} ms\n", .{ total_revm / n, total_ethrex / n, total_guillotine / n, total_guillotine_bun / n, total_guillotine_python / n, total_guillotine_go / n, total_pyrevm / n });
    defer allocator.free(summary);
    try file.writeAll(summary);

    try file.writeAll("\n---\n*Generated by EVM Benchmark Suite*\n");
}

fn runBenchmarkForFixture(allocator: std.mem.Allocator, fixture_data: fixture.Fixture, bytecode: []const u8, internal_runs: u32) !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(&buf);

    try writer.interface.print("\n", .{});
    try writer.interface.print("=== Benchmark: {s} ===\n", .{fixture_data.name});
    try writer.interface.print("Contract: {s}\n", .{fixture_data.contract});
    try writer.interface.print("Calldata: {s}\n", .{fixture_data.calldata});
    try writer.interface.print("Gas limit: {}\n", .{fixture_data.gas_limit});
    try writer.interface.print("Warmup runs: {}\n", .{fixture_data.warmup});
    try writer.interface.print("Benchmark runs: {}\n", .{fixture_data.num_runs});
    try writer.interface.print("\n", .{});
    try writer.interface.flush();

    // Prepare commands for REVM, ethrex, and guillotine runners with internal runs
    const revm_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm revm --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm revm --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(revm_cmd);

    const ethrex_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm ethrex --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./target/release/evm-runner --evm ethrex --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(ethrex_cmd);

    const guillotine_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-runner --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-runner --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_cmd);

    const guillotine_bun_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "bun src/guillotine_bun_runner.ts --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "bun src/guillotine_bun_runner.ts --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_bun_cmd);

    const guillotine_python_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "python3 src/guillotine_python_runner.py --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "python3 src/guillotine_python_runner.py --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_python_cmd);

    const guillotine_go_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-go-runner --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "./zig-out/bin/guillotine-go-runner --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(guillotine_go_cmd);

    // Add pyrevm runner command
    const pyrevm_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(allocator, "python3 src/pyrevm_runner.py --bytecode {s} --calldata {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.calldata, fixture_data.gas_limit, internal_runs })
    else
        try std.fmt.allocPrint(allocator, "python3 src/pyrevm_runner.py --bytecode {s} --gas-limit {} --internal-runs {}", .{ bytecode, fixture_data.gas_limit, internal_runs });
    defer allocator.free(pyrevm_cmd);

    // Build hyperfine command to compare implementations
    var hyperfine_args: std.ArrayList([]const u8) = .empty;
    hyperfine_args.ensureTotalCapacity(allocator, 20) catch unreachable;
    defer hyperfine_args.deinit(allocator);

    try hyperfine_args.append(allocator, "hyperfine");
    try hyperfine_args.append(allocator, "--shell=none"); // More accurate benchmarks without shell overhead
    try hyperfine_args.append(allocator, "--warmup");
    const warmup_str = try std.fmt.allocPrint(allocator, "{}", .{fixture_data.warmup});
    defer allocator.free(warmup_str);
    try hyperfine_args.append(allocator, warmup_str);

    try hyperfine_args.append(allocator, "--runs");
    const runs_str = try std.fmt.allocPrint(allocator, "{}", .{fixture_data.num_runs});
    defer allocator.free(runs_str);
    try hyperfine_args.append(allocator, runs_str);

    try hyperfine_args.append(allocator, "--show-output");
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "revm");
    try hyperfine_args.append(allocator, revm_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "ethrex");
    try hyperfine_args.append(allocator, ethrex_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "guillotine");
    try hyperfine_args.append(allocator, guillotine_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "guillotine-bun");
    try hyperfine_args.append(allocator, guillotine_bun_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "guillotine-python");
    try hyperfine_args.append(allocator, guillotine_python_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "guillotine-go");
    try hyperfine_args.append(allocator, guillotine_go_cmd);
    try hyperfine_args.append(allocator, "-n");
    try hyperfine_args.append(allocator, "pyrevm");
    try hyperfine_args.append(allocator, pyrevm_cmd);

    // Execute hyperfine
    var child = std.process.Child.init(hyperfine_args.items, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get internal runs from environment variable, default to 20
    // const internal_runs = blk: {
    //     const env_value = std.process.getEnvVarOwned(allocator, "BENCHMARK_INTERNAL_RUNS") catch {
    //         break :blk @as(u32, 20);
    //     };
    //     defer allocator.free(env_value);
    //     break :blk std.fmt.parseInt(u32, env_value, 10) catch 20;
    // };
    const internal_runs: u32 = 1;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help              Display this help and exit.
        \\-v, --version           Output version information and exit.
        \\-f, --fixture <STR>     Run specific fixture by name.
        \\-d, --dir <STR>         Directory containing fixtures. [default: "./fixtures"]
        \\-c, --compile-only      Only compile contracts, don't run benchmarks.
        \\-r, --results           Generate results.md file with benchmark summary.
        \\
    );

    const parsers = comptime .{
        .STR = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.helpToFile(.stdout(), clap.Help, &params, .{});
    }

    if (res.args.version != 0) {
        const stdout = std.fs.File.stdout();
        var buf: [1024]u8 = undefined;
        var writer = stdout.writer(&buf);
        try writer.interface.print("bench version 0.1.0\n", .{});
        try writer.interface.flush();
        return;
    }

    // Check if hyperfine is installed (unless compile-only mode)
    const compile_only = res.args.@"compile-only";
    const generate_results = res.args.results != 0;

    if (compile_only == 0) {
        const has_hyperfine = try checkHyperfine(allocator);
        if (!has_hyperfine) {
            try printHyperfineInstallInstructions();
            return error.HyperfineNotInstalled;
        }
    }

    const fixtures_dir = res.args.dir orelse "./fixtures";

    // Open fixtures directory
    var dir = try std.fs.cwd().openDir(fixtures_dir, .{ .iterate = true });
    defer dir.close();

    const stdout = std.fs.File.stdout();
    var print_buf: [4096]u8 = undefined;
    var print_writer = stdout.writer(&print_buf);

    // Process specific fixture or all fixtures
    if (res.args.fixture) |specific_fixture| {
        // Process single fixture
        const fixture_filename = try std.fmt.allocPrint(allocator, "{s}.json", .{specific_fixture});
        defer allocator.free(fixture_filename);

        const json_text = try dir.readFileAlloc(allocator, fixture_filename, 1024 * 1024);
        defer allocator.free(json_text);

        const fixture_data = try fixture.parseFixture(allocator, json_text);
        defer fixture.freeFixture(allocator, fixture_data);

        // Construct full path to contract
        const contract_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ fixtures_dir, fixture_data.contract });
        defer allocator.free(contract_path);

        // Compile the contract on demand
        const bytecode = try compileSolidity(allocator, contract_path);
        defer allocator.free(bytecode);

        // Special check for snailtracer bytecode - use expected bytecode instead
        var actual_bytecode = bytecode;
        var expected_bytecode_alloc: ?[]u8 = null;
        defer if (expected_bytecode_alloc) |eb| allocator.free(eb);

        if (std.mem.eql(u8, fixture_data.name, "snailtracer")) {
            // Read expected bytecode
            const expected_file = try std.fs.cwd().openFile("expected-deployed-bytecode.txt", .{});
            defer expected_file.close();
            const expected_bytecode = try expected_file.readToEndAlloc(allocator, 100000);
            defer allocator.free(expected_bytecode);

            // Trim any whitespace from expected
            const trimmed_expected = std.mem.trim(u8, expected_bytecode, " \n\r\t");

            // Strip 0x prefix from bytecode if present
            const bytecode_to_compare = if (std.mem.startsWith(u8, bytecode, "0x") or std.mem.startsWith(u8, bytecode, "0X"))
                bytecode[2..]
            else
                bytecode;

            if (!std.mem.eql(u8, bytecode_to_compare, trimmed_expected)) {
                try print_writer.interface.print("\n!!! SNAILTRACER BYTECODE MISMATCH !!!\n", .{});
                try print_writer.interface.print("Using expected bytecode instead of compiled bytecode for testing.\n", .{});
                try print_writer.interface.print("Expected length: {}\n", .{trimmed_expected.len});
                try print_writer.interface.print("Got length: {}\n", .{bytecode_to_compare.len});
                try print_writer.interface.flush();

                // Use the expected bytecode with 0x prefix
                expected_bytecode_alloc = try allocator.alloc(u8, trimmed_expected.len + 2);
                expected_bytecode_alloc.?[0] = '0';
                expected_bytecode_alloc.?[1] = 'x';
                @memcpy(expected_bytecode_alloc.?[2..], trimmed_expected);
                actual_bytecode = expected_bytecode_alloc.?;
            } else {
                try print_writer.interface.print("✓ Snailtracer bytecode matches expected\n", .{});
                try print_writer.interface.flush();
            }
        }

        if (compile_only == 0) {
            try runBenchmarkForFixture(allocator, fixture_data, actual_bytecode, internal_runs);
        }
    } else {
        // Collect results if generating report
        var results: std.ArrayList(BenchmarkResult) = .empty;
        try results.ensureTotalCapacity(allocator, 20);
        defer results.deinit(allocator);

        // Process all JSON fixtures
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            try print_writer.interface.print("Processing fixture: {s}\n", .{entry.name});
            try print_writer.interface.flush();

            const json_text = try dir.readFileAlloc(allocator, entry.name, 1024 * 1024);
            defer allocator.free(json_text);

            const fixture_data = try fixture.parseFixture(allocator, json_text);
            defer fixture.freeFixture(allocator, fixture_data);

            // Construct full path to contract
            const contract_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ fixtures_dir, fixture_data.contract });
            defer allocator.free(contract_path);

            // Compile the contract on demand
            const bytecode = compileSolidity(allocator, contract_path) catch {
                try print_writer.interface.print("Skipping {s}: compilation failed\n", .{fixture_data.name});
                try print_writer.interface.flush();
                continue;
            };
            defer allocator.free(bytecode);

            // Special check for snailtracer bytecode - use expected bytecode instead
            var actual_bytecode = bytecode;
            var expected_bytecode_alloc: ?[]u8 = null;
            defer if (expected_bytecode_alloc) |eb| allocator.free(eb);

            if (std.mem.eql(u8, fixture_data.name, "snailtracer")) {
                // Read expected bytecode
                const expected_file = try std.fs.cwd().openFile("expected-deployed-bytecode.txt", .{});
                defer expected_file.close();
                const expected_bytecode = try expected_file.readToEndAlloc(allocator, 100000);
                defer allocator.free(expected_bytecode);

                // Trim any whitespace from expected
                const trimmed_expected = std.mem.trim(u8, expected_bytecode, " \n\r\t");

                // Strip 0x prefix from bytecode if present
                const bytecode_to_compare = if (std.mem.startsWith(u8, bytecode, "0x") or std.mem.startsWith(u8, bytecode, "0X"))
                    bytecode[2..]
                else
                    bytecode;

                if (!std.mem.eql(u8, bytecode_to_compare, trimmed_expected)) {
                    try print_writer.interface.print("\n!!! SNAILTRACER BYTECODE MISMATCH !!!\n", .{});
                    try print_writer.interface.print("Using expected bytecode instead of compiled bytecode for testing.\n", .{});
                    try print_writer.interface.print("Expected length: {}\n", .{trimmed_expected.len});
                    try print_writer.interface.print("Got length: {}\n", .{bytecode_to_compare.len});
                    try print_writer.interface.flush();

                    // Use the expected bytecode with 0x prefix
                    expected_bytecode_alloc = try allocator.alloc(u8, trimmed_expected.len + 2);
                    expected_bytecode_alloc.?[0] = '0';
                    expected_bytecode_alloc.?[1] = 'x';
                    @memcpy(expected_bytecode_alloc.?[2..], trimmed_expected);
                    actual_bytecode = expected_bytecode_alloc.?;
                } else {
                    try print_writer.interface.print("✓ Snailtracer bytecode matches expected\n", .{});
                    try print_writer.interface.flush();
                }
            }

            if (compile_only == 0) {
                if (generate_results) {
                    try print_writer.interface.print("Running benchmark with results for {s}...\n", .{fixture_data.name});
                    try print_writer.interface.flush();
                    const result = try runBenchmarkWithResult(allocator, fixture_data, actual_bytecode, internal_runs);
                    try results.append(allocator, result);
                } else {
                    try runBenchmarkForFixture(allocator, fixture_data, actual_bytecode, internal_runs);
                }
            }
        }

        // Generate results.md if requested
        if (generate_results and results.items.len > 0) {
            try print_writer.interface.print("\nGenerating results.md with {} benchmarks...\n", .{results.items.len});
            try print_writer.interface.flush();
            try generateResultsMarkdown(allocator, results.items, internal_runs);
            try print_writer.interface.print("Results saved to results.md\n", .{});
            try print_writer.interface.flush();

            // Free the duplicated names
            for (results.items) |result| {
                allocator.free(result.name);
            }
        }
    }
}
