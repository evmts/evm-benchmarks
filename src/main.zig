const std = @import("std");
const clap = @import("clap");
const fixture = @import("fixture.zig");

const c = @cImport({
    @cInclude("foundry_wrapper.h");
});

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

fn runBenchmarkForFixture(allocator: std.mem.Allocator, fixture_data: fixture.Fixture, bytecode: []const u8) !void {
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
    
    // Prepare commands for REVM, ethrex, and guillotine runners
    const revm_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(
            allocator,
            "./target/release/evm-runner --evm revm --bytecode {s} --calldata {s} --gas-limit {}",
            .{ bytecode, fixture_data.calldata, fixture_data.gas_limit }
        )
    else
        try std.fmt.allocPrint(
            allocator,
            "./target/release/evm-runner --evm revm --bytecode {s} --gas-limit {}",
            .{ bytecode, fixture_data.gas_limit }
        );
    defer allocator.free(revm_cmd);
    
    const ethrex_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(
            allocator,
            "./target/release/evm-runner --evm ethrex --bytecode {s} --calldata {s} --gas-limit {}",
            .{ bytecode, fixture_data.calldata, fixture_data.gas_limit }
        )
    else
        try std.fmt.allocPrint(
            allocator,
            "./target/release/evm-runner --evm ethrex --bytecode {s} --gas-limit {}",
            .{ bytecode, fixture_data.gas_limit }
        );
    defer allocator.free(ethrex_cmd);
    
    const guillotine_cmd = if (fixture_data.calldata.len > 0 and !std.mem.eql(u8, fixture_data.calldata, ""))
        try std.fmt.allocPrint(
            allocator,
            "./zig-out/bin/guillotine-runner --bytecode {s} --calldata {s} --gas-limit {}",
            .{ bytecode, fixture_data.calldata, fixture_data.gas_limit }
        )
    else
        try std.fmt.allocPrint(
            allocator,
            "./zig-out/bin/guillotine-runner --bytecode {s} --gas-limit {}",
            .{ bytecode, fixture_data.gas_limit }
        );
    defer allocator.free(guillotine_cmd);
    
    // Build hyperfine command to compare implementations
    var hyperfine_args: std.ArrayList([]const u8) = .empty;
    hyperfine_args.ensureTotalCapacity(allocator, 20) catch unreachable;
    defer hyperfine_args.deinit(allocator);
    
    try hyperfine_args.append(allocator, "hyperfine");
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

    const params = comptime clap.parseParamsComptime(
        \\-h, --help              Display this help and exit.
        \\-v, --version           Output version information and exit.
        \\-f, --fixture <STR>     Run specific fixture by name.
        \\-d, --dir <STR>         Directory containing fixtures. [default: "./fixtures"]
        \\-c, --compile-only      Only compile contracts, don't run benchmarks.
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
        
        if (compile_only == 0) {
            try runBenchmarkForFixture(allocator, fixture_data, bytecode);
        }
    } else {
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
            
            if (compile_only == 0) {
                try runBenchmarkForFixture(allocator, fixture_data, bytecode);
            }
        }
    }
}