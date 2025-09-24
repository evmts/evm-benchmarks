const std = @import("std");

pub const Fixture = struct {
    name: []const u8,
    num_runs: u32,
    solc_version: []const u8,
    contract: []const u8,
    calldata: []const u8,
    warmup: u32,
    gas_limit: u64,
};

pub fn parseFixture(allocator: std.mem.Allocator, json_text: []const u8) !Fixture {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_text, .{});
    defer parsed.deinit();
    
    const root = parsed.value.object;
    
    return Fixture{
        .name = try allocator.dupe(u8, root.get("name").?.string),
        .num_runs = @intCast(root.get("num_runs").?.integer),
        .solc_version = try allocator.dupe(u8, root.get("solc_version").?.string),
        .contract = try allocator.dupe(u8, root.get("contract").?.string),
        .calldata = try allocator.dupe(u8, root.get("calldata").?.string),
        .warmup = if (root.get("warmup")) |w| @intCast(w.integer) else 3,
        .gas_limit = if (root.get("gas_limit")) |g| @intCast(g.integer) else 30000000,
    };
}

pub fn freeFixture(allocator: std.mem.Allocator, fixture: Fixture) void {
    allocator.free(fixture.name);
    allocator.free(fixture.solc_version);
    allocator.free(fixture.contract);
    allocator.free(fixture.calldata);
}