pub const packages = struct {
    pub const @"../evms/guillotine-go-sdk" = struct {
        pub const build_root = "/Users/williamcory/bench/guillotine/../evms/guillotine-go-sdk";
        pub const build_zig = @import("../evms/guillotine-go-sdk");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "zbench", "zbench-0.11.1-YTdc7zgmAQDtDcHPFwsLeawui27WjMLWmUwrfz7pIlB2" },
            .{ "clap", "clap-0.11.0-oBajB-HnAQDPCKYzwF7rO3qDFwRcD39Q0DALlTSz5H7e" },
        };
    };
    pub const @"clap-0.11.0-oBajB-HnAQDPCKYzwF7rO3qDFwRcD39Q0DALlTSz5H7e" = struct {
        pub const build_root = "/Users/williamcory/.cache/zig/p/clap-0.11.0-oBajB-HnAQDPCKYzwF7rO3qDFwRcD39Q0DALlTSz5H7e";
        pub const build_zig = @import("clap-0.11.0-oBajB-HnAQDPCKYzwF7rO3qDFwRcD39Q0DALlTSz5H7e");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zbench-0.11.1-YTdc7zgmAQDtDcHPFwsLeawui27WjMLWmUwrfz7pIlB2" = struct {
        pub const build_root = "/Users/williamcory/.cache/zig/p/zbench-0.11.1-YTdc7zgmAQDtDcHPFwsLeawui27WjMLWmUwrfz7pIlB2";
        pub const build_zig = @import("zbench-0.11.1-YTdc7zgmAQDtDcHPFwsLeawui27WjMLWmUwrfz7pIlB2");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "guillotine", "../evms/guillotine-go-sdk" },
};
