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

var path_buffer_trash: [std.fs.max_path_bytes]u8 = undefined;
pub fn pathForTrash(self: WorkDir, path: []const u8) ![]const u8 {
    _ = self;
    const basename = std.fs.path.basename(path);
    var trash_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const trash_dir = try util.bufEnv(&trash_dir_buffer, "trash") orelse {
        return error.EnvTrashNotSet;
    };
    return std.fmt.bufPrint(&path_buffer_trash, "{s}/TRASH_{d}__{s}", .{ trash_dir, std.time.milliTimestamp(), basename }) catch {
        return error.FailedToCreateTrashPath;
    };
}

var path_buffer_backup: [std.fs.max_path_bytes]u8 = undefined;
pub fn pathForBackup(self: WorkDir, path: []const u8) ![]const u8 {
    _ = self;
    return std.fmt.bufPrint(&path_buffer_backup, "{s}.backup~", .{path}) catch {
        return error.FailedToCreateBackupPath;
    };
}

pub fn trash(self: WorkDir, path: []const u8) ![]const u8 {
    const trash_path = try self.pathForTrash(path);
    try self.cwd.rename(path, trash_path);
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
