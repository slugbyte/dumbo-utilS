const std = @import("std");
const util = @import("./root.zig");

var buffer_trash_path: [std.fs.max_path_bytes]u8 = undefined;
var buffer_backup_path: [std.fs.max_path_bytes]u8 = undefined;

pub fn trashPathFromName(file_name: []const u8) ![]const u8 {
    var trash_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const trash_dir = try util.bufEnv(&trash_dir_buffer, "trash") orelse {
        return error.EnvNotFoundTrash;
    };
    return std.fmt.bufPrint(&buffer_trash_path, "{s}/TRASH_{d}__{s}", .{ trash_dir, std.time.milliTimestamp(), file_name }) catch {
        return error.FailedToCreatePath;
    };
}

pub fn trashPathFromPath(path: []const u8) ![]const u8 {
    const basename = std.fs.path.basename(path);
    return try trashPathFromName(basename);
}

pub fn backupPathFromPath(path: []const u8) ![]const u8 {
    return std.fmt.bufPrint(&buffer_backup_path, "{s}.backup~", .{path}) catch {
        return error.FailedToCreatePath;
    };
}
