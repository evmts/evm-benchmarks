const std = @import("std");
const clap = @import("clap");
const primitives = @import("primitives");
const guillotine = @import("guillotine");

// Import types
const MinimalEvm = guillotine.tracer.minimal_evm.MinimalEvm;
const Hardfork = guillotine.eips_and_hardforks.eips.Hardfork;
const Address = primitives.Address.Address;

// Constants for addresses
const SENDER_ADDRESS = Address.fromBytes([_]u8{0} ** 19 ++ [_]u8{0x01});
const CONTRACT_ADDRESS = Address.fromBytes([_]u8{0} ** 19 ++ [_]u8{0x42});

fn decodeHex(allocator: std.mem.Allocator, hex_str: []const u8) ![]u8 {
    var str = hex_str;
    // Remove 0x prefix if present
    if (str.len >= 2 and (std.mem.eql(u8, str[0..2], "0x") or std.mem.eql(u8, str[0..2], "0X"))) {
        str = str[2..];
    }
    
    if (str.len % 2 != 0) {
        return error.OddNumberOfDigits;
    }
    
    const result = try allocator.alloc(u8, str.len / 2);
    errdefer allocator.free(result);
    
    for (result, 0..) |*byte, i| {
        const high = try std.fmt.charToDigit(str[i * 2], 16);
        const low = try std.fmt.charToDigit(str[i * 2 + 1], 16);
        byte.* = (high << 4) | low;
    }
    
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\--bytecode <STR>          Bytecode to execute (hex encoded).
        \\--calldata <STR>          Calldata for the transaction (hex encoded). [optional]
        \\--gas-limit <NUM>         Gas limit for execution. [default: 30000000]
        \\
    );

    const parsers = comptime .{
        .STR = clap.parsers.string,
        .NUM = clap.parsers.int(u64, 10),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.report(std.io.getStdErr().writer(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});
    }

    const bytecode_hex = res.args.bytecode orelse {
        try std.io.getStdErr().writer().print("Error: --bytecode is required\n", .{});
        return error.MissingBytecode;
    };
    
    const calldata_hex = res.args.calldata orelse "";
    const gas_limit = res.args.@"gas-limit" orelse 30_000_000;

    // Decode hex inputs
    const bytecode = try decodeHex(allocator, bytecode_hex);
    defer allocator.free(bytecode);
    
    const calldata = if (calldata_hex.len > 0) 
        try decodeHex(allocator, calldata_hex) 
    else 
        try allocator.alloc(u8, 0);
    defer allocator.free(calldata);

    // Create MinimalEvm instance
    var evm = try MinimalEvm.init(allocator);
    defer evm.deinit();
    
    // Set up blockchain context
    evm.hardfork = Hardfork.CANCUN;
    evm.chain_id = 1;
    evm.block_number = 1;
    evm.block_timestamp = 1;
    evm.block_gas_limit = 30_000_000;
    evm.block_base_fee = 1_000_000_000;
    evm.origin = SENDER_ADDRESS;
    evm.gas_price = 1_000_000_000;
    
    // Set up sender account with balance (1 ETH)
    try evm.balances.put(SENDER_ADDRESS, 1_000_000_000_000_000_000);
    
    // Store the bytecode as the contract code
    try evm.code.put(CONTRACT_ADDRESS, bytecode);
    
    // Execute the call
    const result = try evm.execute(
        bytecode,
        @intCast(gas_limit),
        SENDER_ADDRESS,
        CONTRACT_ADDRESS,
        0, // value
        calldata,
    );
    
    // Calculate gas used
    const gas_used = gas_limit - @as(u64, @intCast(result.gas_left));
    
    // Print results in same format as Rust runners
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Success: {}\n", .{result.success});
    try stdout.print("Gas used: {}\n", .{gas_used});
    try stdout.print("Output: 0x", .{});
    for (result.output) |byte| {
        try stdout.print("{x:0>2}", .{byte});
    }
    try stdout.print("\n", .{});
}