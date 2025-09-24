const std = @import("std");
const primitives = @import("primitives");

// Import the MinimalEvm which is simpler to use
const minimal_evm = @import("guillotine").tracer.minimal_evm;
const MinimalEvm = minimal_evm.MinimalEvm;
const CallResult = minimal_evm.CallResult;
const Hardfork = @import("guillotine").eips_and_hardforks.eips.Hardfork;

const Address = primitives.Address.Address;
const ZERO_ADDRESS = primitives.ZERO_ADDRESS;

// Constants for addresses
const SENDER_ADDRESS = Address.fromBytes([_]u8{0} ** 19 ++ [_]u8{0x01});
const CONTRACT_ADDRESS = Address.fromBytes([_]u8{0} ** 19 ++ [_]u8{0x42});

pub const GuillotineExecutor = struct {
    allocator: std.mem.Allocator,
    evm: *MinimalEvm,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const evm = try allocator.create(MinimalEvm);
        errdefer allocator.destroy(evm);
        
        evm.* = try MinimalEvm.init(allocator);
        
        // Set up blockchain context
        evm.hardfork = Hardfork.CANCUN;
        evm.chain_id = 1;
        evm.block_number = 1;
        evm.block_timestamp = 1;
        evm.block_gas_limit = 30_000_000;
        evm.block_base_fee = 1_000_000_000;
        evm.origin = SENDER_ADDRESS;
        evm.gas_price = 1_000_000_000;
        
        // Set up sender account with balance
        try evm.balances.put(SENDER_ADDRESS, 1_000_000_000_000_000_000);
        
        return Self{
            .allocator = allocator,
            .evm = evm,
        };
    }

    pub fn deinit(self: *Self) void {
        self.evm.deinit();
        self.allocator.destroy(self.evm);
    }

    pub fn execute(
        self: *Self,
        bytecode: []const u8,
        calldata: []const u8,
        gas_limit: u64,
    ) !struct {
        success: bool,
        gas_used: u64,
        output: []const u8,
    } {
        // Store the bytecode as the contract code
        try self.evm.code.put(CONTRACT_ADDRESS, bytecode);
        
        // Execute the call
        const result = try self.evm.execute(
            bytecode,
            @intCast(gas_limit),
            SENDER_ADDRESS,
            CONTRACT_ADDRESS,
            0, // value
            calldata,
        );
        
        // Calculate gas used
        const gas_used = gas_limit - @as(u64, @intCast(result.gas_left));
        
        return .{
            .success = result.success,
            .gas_used = gas_used,
            .output = result.output,
        };
    }
};

// Test the executor
test "GuillotineExecutor basic test" {
    const allocator = std.testing.allocator;
    
    var executor = try GuillotineExecutor.init(allocator);
    defer executor.deinit();
    
    // Simple bytecode that stores 1 and returns it
    const bytecode = [_]u8{ 0x60, 0x01, 0x60, 0x00, 0x52, 0x60, 0x20, 0x60, 0x00, 0xF3 };
    const calldata = [_]u8{};
    
    const result = try executor.execute(&bytecode, &calldata, 30_000_000);
    
    try std.testing.expect(result.success);
    try std.testing.expect(result.gas_used > 0);
    try std.testing.expect(result.output.len == 32);
    try std.testing.expect(result.output[31] == 1);
}