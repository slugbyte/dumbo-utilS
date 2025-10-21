const std = @import("std");
const util = @import("./root.zig");

const WorkDir = @This();

cwd: std.fs.Dir,

pub fn init() WorkDir {
    return .{
        .cwd = std.fs.cwd(),
    };
}

pub fn exists(self: WorkDir, path: []const u8) !bool {
    self.cwd.access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

pub fn trash(self: WorkDir, path: []const u8) ![]const u8 {
    const trash_path = try util.path.trashPathFromPath(path);
    try self.move(path, trash_path);
    return trash_path;
}

/// Asserts both paths exist
pub fn isPathEqual(self: WorkDir, path_a: []const u8, path_b: []const u8) !bool {
    var buf_realpath_a: [std.fs.max_path_bytes]u8 = undefined;
    var buf_realpath_b: [std.fs.max_path_bytes]u8 = undefined;
    const realpath_a = try self.cwd.realpath(path_a, &buf_realpath_a);
    const realpath_b = try self.cwd.realpath(path_b, &buf_realpath_b);
    if (std.mem.eql(u8, realpath_a, realpath_b)) {
        return true;
    }
    return false;
}

pub fn move(self: WorkDir, path_source: []const u8, path_destination: []const u8) !void {
    try self.cwd.rename(path_source, path_destination);
}
