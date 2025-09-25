const std = @import("std");
const guillotine = @import("guillotine");
const primitives = @import("primitives");

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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Simple argument parsing
    var bytecode_hex: ?[]const u8 = null;
    var calldata_hex: []const u8 = "";
    var gas_limit: u64 = 30_000_000;
    var internal_runs: u64 = 1;
    var measure_startup: bool = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--bytecode")) {
            if (i + 1 < args.len) {
                bytecode_hex = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--calldata")) {
            if (i + 1 < args.len) {
                calldata_hex = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--gas-limit")) {
            if (i + 1 < args.len) {
                gas_limit = try std.fmt.parseInt(u64, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--internal-runs")) {
            if (i + 1 < args.len) {
                internal_runs = try std.fmt.parseInt(u64, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--measure-startup")) {
            measure_startup = true;
        }
    }

    // Execute the call multiple times
    var run: u64 = 0;
    while (run < internal_runs) : (run += 1) {
        const bytecode_input = bytecode_hex orelse return error.MissingBytecode;

        // Decode hex inputs
        const bytecode = try decodeHex(allocator, bytecode_input);
        defer allocator.free(bytecode);

        const calldata = if (calldata_hex.len > 0)
            try decodeHex(allocator, calldata_hex)
        else
            try allocator.alloc(u8, 0);
        defer allocator.free(calldata);

        // Set up addresses
        const sender_address = primitives.Address.fromBytes(&([_]u8{0} ** 19 ++ [_]u8{0x01})) catch unreachable;
        const contract_address = primitives.Address.fromBytes(&([_]u8{0} ** 19 ++ [_]u8{0x42})) catch unreachable;
        const origin = sender_address;
        // Create block info
        const block_info = guillotine.BlockInfo{
            .number = 1,
            .timestamp = 1,
            .gas_limit = 30_000_000,
            .coinbase = primitives.Address.zero(),
            .base_fee = 1_000_000_000,
            .chain_id = 1,
            .difficulty = 0,
            .prev_randao = [_]u8{0} ** 32,
            .blob_base_fee = 0,
            .blob_versioned_hashes = &.{},
        };

        // Create transaction context
        const tx_context = guillotine.TransactionContext{
            .gas_limit = gas_limit,
            .coinbase = primitives.Address.zero(),
            .chain_id = 1,
            .blob_versioned_hashes = &.{},
            .blob_base_fee = 0,
        };

        // Create database inside loop for fresh state each run
        var database = guillotine.Database.init(allocator);
        defer database.deinit();

        // Set sender balance (100 ETH)
        const balance: u256 = 100_000_000_000_000_000_000; // 100 ETH in wei
        const sender_account = guillotine.Account{
            .balance = balance,
            .code_hash = [_]u8{0} ** 32,
            .storage_root = [_]u8{0} ** 32,
            .nonce = 0,
            .delegated_address = null,
        };
        try database.set_account(sender_address.bytes, sender_account);

        // Store the bytecode as contract code
        const code_hash = try database.set_code(bytecode);
        const contract_account = guillotine.Account{
            .balance = 0,
            .code_hash = code_hash,
            .storage_root = [_]u8{0} ** 32,
            .nonce = 0,
            .delegated_address = null,
        };
        try database.set_account(contract_address.bytes, contract_account);

        // Create EVM instance
        var evm = try guillotine.MainnetEvm.init(
            allocator,
            &database,
            block_info,
            tx_context,
            1_000_000_000, // gas_price
            origin,
        );
        defer evm.deinit();

        // Create call parameters
        const call_params = guillotine.MainnetEvm.CallParams{
            .call = .{
                .caller = sender_address,
                .to = contract_address,
                .value = 0,
                .input = calldata,
                .gas = gas_limit,
            },
        };

        // Execute the call
        const result = evm.simulate(call_params);
        defer result.deinit(allocator);
    }
}
