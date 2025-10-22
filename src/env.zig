const std = @import("std");

pub fn getBuf(buffer: []u8, key: []const u8) !?[]u8 {
    var fbo = std.heap.FixedBufferAllocator.init(buffer);
    return try getAlloc(fbo.allocator(), key);
}

pub fn getAlloc(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    const result = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        else => return err,
    };

    if (result.len == 0) return null;
    return result;
}

pub fn exists(key: []const u8) !bool {
    var buffer: [1]u8 = undefined;
    const env = getBuf(&buffer, key) catch |err| switch (err) {
        error.OutOfMemory => return true,
        else => return err,
    };
    if (env == null) return false;
    return true;
}
