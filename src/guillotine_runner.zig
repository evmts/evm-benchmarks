const std = @import("std");
const clap = @import("clap");

// Guillotine C API declarations
const EvmHandle = opaque {};
const EvmResult = extern struct {
    success: bool,
    gas_left: u64,
    output: [*]const u8,
    output_len: usize,
    error_message: [*:0]const u8,
    // We only need these fields for basic execution
    logs: ?*anyopaque,
    logs_len: usize,
    selfdestructs: ?*anyopaque,
    selfdestructs_len: usize,
    accessed_addresses: ?*anyopaque,
    accessed_addresses_len: usize,
    accessed_storage: ?*anyopaque,
    accessed_storage_len: usize,
    created_address: [20]u8,
    has_created_address: bool,
    trace_json: ?*anyopaque,
    trace_json_len: usize,
};

const CallParams = extern struct {
    caller: [20]u8,
    to: [20]u8,
    value: [32]u8,
    input: [*]const u8,
    input_len: usize,
    gas: u64,
    call_type: u8,
    salt: [32]u8,
};

const BlockInfoFFI = extern struct {
    number: u64,
    timestamp: u64,
    gas_limit: u64,
    coinbase: [20]u8,
    base_fee: u64,
    chain_id: u64,
    difficulty: u64,
    prev_randao: [32]u8,
};

// External C functions from guillotine
extern fn guillotine_init() void;
extern fn guillotine_cleanup() void;
extern fn guillotine_evm_create_mainnet(block_info: *const BlockInfoFFI) ?*EvmHandle;
extern fn guillotine_evm_destroy(handle: *EvmHandle) void;
extern fn guillotine_set_balance(handle: *EvmHandle, address: *const [20]u8, balance: *const [32]u8) bool;
extern fn guillotine_set_code(handle: *EvmHandle, address: *const [20]u8, code: [*]const u8, code_len: usize) bool;
extern fn guillotine_call(handle: *EvmHandle, params: *const CallParams) ?*EvmResult;

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
        \\--internal-runs <NUM>     Number of internal runs for benchmarking. [default: 1]
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
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.helpToFile(.stdout(), clap.Help, &params, .{});
    }

    const bytecode_hex = res.args.bytecode orelse return error.MissingBytecode;
    
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

    // Initialize guillotine
    guillotine_init();
    defer guillotine_cleanup();

    // Create block info
    const block_info = BlockInfoFFI{
        .number = 1,
        .timestamp = 1,
        .gas_limit = 30_000_000,
        .coinbase = [_]u8{0} ** 20,
        .base_fee = 1_000_000_000,
        .chain_id = 1,
        .difficulty = 0,
        .prev_randao = [_]u8{0} ** 32,
    };

    // Create EVM instance
    const evm = guillotine_evm_create_mainnet(&block_info) orelse return error.EvmCreationFailed;
    defer guillotine_evm_destroy(evm);

    // Set up addresses
    const sender_address = [_]u8{0} ** 19 ++ [_]u8{0x01};
    const contract_address = [_]u8{0} ** 19 ++ [_]u8{0x42};

    // Set sender balance (100 ETH to cover high gas costs)
    var balance_bytes = [_]u8{0} ** 32;
    // 100 ETH = 100 * 10^18 = 0x56BC75E2D63100000
    balance_bytes[10] = 0x05;
    balance_bytes[11] = 0x6B;
    balance_bytes[12] = 0xC7;
    balance_bytes[13] = 0x5E;
    balance_bytes[14] = 0x2D;
    balance_bytes[15] = 0x63;
    balance_bytes[16] = 0x10;
    balance_bytes[17] = 0x00;
    balance_bytes[18] = 0x00;
    
    if (!guillotine_set_balance(evm, &sender_address, &balance_bytes)) {
        return error.SetBalanceFailed;
    }

    // Store the bytecode as contract code
    if (!guillotine_set_code(evm, &contract_address, bytecode.ptr, bytecode.len)) {
        return error.SetCodeFailed;
    }

    // Prepare call parameters
    const call_params = CallParams{
        .caller = sender_address,
        .to = contract_address,
        .value = [_]u8{0} ** 32,
        .input = calldata.ptr,
        .input_len = calldata.len,
        .gas = gas_limit,
        .call_type = 0, // CALL
        .salt = [_]u8{0} ** 32,
    };

    // Get internal runs count
    const internal_runs = res.args.@"internal-runs" orelse 1;
    
    // Output only essential benchmark data
    const stdout = std.fs.File.stdout();
    var buf: [256]u8 = undefined;
    var writer = stdout.writer(&buf);
    
    // Execute the call multiple times
    var i: u64 = 0;
    while (i < internal_runs) : (i += 1) {
        const result = guillotine_call(evm, &call_params) orelse return error.CallFailed;

        // Calculate gas used
        const gas_used = gas_limit - result.gas_left;

        // Output for each run
        try writer.interface.print("{}\n", .{result.success});
        try writer.interface.print("{}\n", .{gas_used});
        try writer.interface.flush();
    }
}