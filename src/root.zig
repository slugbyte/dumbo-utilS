//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const WorkDir = @import("./WorkDir.zig");

pub fn bufEnv(buffer: []u8, key: []const u8) !?[]u8 {
    var fbo = std.heap.FixedBufferAllocator.init(buffer);
    const result = try std.process.getEnvVarOwned(fbo.allocator(), key);
    if (result.len == 0) return null;
    return result;
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buffer, fmt, args) catch return;
    std.debug.print("{s}\n", .{msg});
}

pub fn exit(comptime fmt: []const u8, arg: anytype) noreturn {
    log(fmt, arg);
    std.process.exit(1);
}
