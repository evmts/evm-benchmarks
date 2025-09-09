const std = @import("std");
const evm_module = @import("evm");
const primitives = @import("primitives");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <bytecode_hex> <calldata_hex>\n", .{args[0]});
        std.process.exit(1);
    }

    // Parse bytecode from hex
    const bytecode_hex = args[1];
    const bytecode = try hexToBytes(allocator, bytecode_hex);
    defer allocator.free(bytecode);

    // Parse calldata from hex
    const calldata_hex = args[2];
    const calldata = try hexToBytes(allocator, calldata_hex);
    defer allocator.free(calldata);

    // Initialize EVM components
    const config = evm_module.EvmConfig{
        .max_bytecode_size = 65536,
        .max_call_depth = 1024,
        .max_stack_height = 1024,
        .max_memory_size = 1024 * 1024 * 32, // 32MB
        .WordType = u256,
        .enable_fusion = false,
    };

    const Evm = evm_module.Evm(config);
    
    // Create database
    var database = evm_module.Database.init(allocator);
    defer database.deinit();

    // Deploy the bytecode to an address
    const contract_address = primitives.Address{ .bytes = [_]u8{1} ++ [_]u8{0} ** 19 };
    
    // Store the bytecode
    const code_hash = try database.set_code(bytecode);
    
    // Create an account with the bytecode
    const account = evm_module.Account{
        .balance = 0,
        .nonce = 1,
        .code_hash = code_hash,
        .storage_root = [_]u8{0} ** 32,
        .code_version = .EVM_VERSION_CANCUN,
        .has_code = true,
        .eip_7702_delegated_address = null,
    };
    
    try database.set_account(contract_address.bytes, account);

    // Create the EVM instance
    const hardfork = evm_module.Hardfork.CANCUN;
    const block_info = evm_module.BlockInfo{
        .number = 1,
        .timestamp = 1000000,
        .gas_limit = 30_000_000,
        .gas_used = 0,
        .coinbase = primitives.Address.ZERO_ADDRESS,
        .difficulty = 0,
        .prev_randao = 0,
        .base_fee = 1_000_000_000, // 1 gwei
        .blob_gas_used = null,
        .excess_blob_gas = null,
    };
    
    const tx_context = evm_module.TransactionContext{
        .chain_id = 1,
        .nonce = 0,
        .gas_price = 1_000_000_000,
        .gas_limit = 30_000_000,
        .to = contract_address,
        .value = 0,
        .input = calldata,
        .access_list = &.{},
        .blob_hashes = &.{},
        .max_fee_per_blob_gas = null,
    };

    var access_list = evm_module.AccessList.init(allocator);
    defer access_list.deinit();

    const caller_address = primitives.Address{ .bytes = [_]u8{2} ++ [_]u8{0} ** 19 };
    
    // Give the caller some balance
    const caller_account = evm_module.Account{
        .balance = 1_000_000_000_000_000_000, // 1 ETH
        .nonce = 0,
        .code_hash = [_]u8{0} ** 32,
        .storage_root = [_]u8{0} ** 32,
        .code_version = .EVM_VERSION_CANCUN,
        .has_code = false,
        .eip_7702_delegated_address = null,
    };
    
    try database.set_account(caller_address.bytes, caller_account);

    var evm = Evm.init(
        allocator,
        &database,
        &access_list,
        block_info,
        tx_context,
        1_000_000_000, // gas_price
        caller_address, // origin
        hardfork,
    );
    defer evm.deinit();

    // Create call parameters
    const call_params = Evm.CallParams{
        .call = .{
            .caller = caller_address,
            .to = contract_address,
            .value = 0,
            .input = calldata,
            .gas = 30_000_000,
        },
    };

    // Execute the call
    const start_time = std.time.nanoTimestamp();
    const result = evm.call(call_params);
    const end_time = std.time.nanoTimestamp();

    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;

    // Print results
    if (result.success) {
        std.debug.print("Success\n", .{});
        std.debug.print("Gas used: {}\n", .{30_000_000 - result.gas_left});
        std.debug.print("Execution time: {d:.3}ms\n", .{duration_ms});
        if (result.output.len > 0) {
            std.debug.print("Output: 0x", .{});
            for (result.output) |byte| {
                std.debug.print("{x:0>2}", .{byte});
            }
            std.debug.print("\n", .{});
        }
    } else {
        std.debug.print("Failed\n", .{});
        std.debug.print("Gas left: {}\n", .{result.gas_left});
        if (result.error_info) |err| {
            std.debug.print("Error: {s}\n", .{err});
        }
    }
}

fn hexToBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    var input = hex;
    
    // Skip "0x" prefix if present
    if (input.len >= 2 and input[0] == '0' and (input[1] == 'x' or input[1] == 'X')) {
        input = input[2..];
    }
    
    if (input.len % 2 != 0) {
        return error.InvalidHexLength;
    }
    
    const bytes = try allocator.alloc(u8, input.len / 2);
    
    var i: usize = 0;
    while (i < input.len) : (i += 2) {
        const byte_str = input[i..i + 2];
        bytes[i / 2] = try std.fmt.parseInt(u8, byte_str, 16);
    }
    
    return bytes;
}