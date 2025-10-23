const std = @import("std");
const util = @import("./root.zig");

var buffer_trash_dir: [std.fs.max_path_bytes]u8 = undefined;
var buffer_trash_path: [std.fs.max_path_bytes]u8 = undefined;
var buffer_backup_path: [std.fs.max_path_bytes]u8 = undefined;

pub fn trashDir() ![]const u8 {
    return try util.env.getBuf(&buffer_trash_dir, "trash") orelse {
        return error.EnvNotFoundTrash;
    };
}

pub fn trashPathNameTimestamp(file_name: []const u8) ![]const u8 {
    const trash_dir = try trashDir();
    return std.fmt.bufPrint(&buffer_trash_path, "{s}/{s}__{d}.trash", .{ trash_dir, file_name, std.time.milliTimestamp() }) catch {
        return error.FailedToCreatePath;
    };
}

pub fn trashPathNameTimestampRandom(file_name: []const u8) ![]const u8 {
    const trash_dir = try trashDir();
    var rand_buffer: [4]u8 = undefined;
    std.crypto.random.bytes(&rand_buffer);
    return std.fmt.bufPrint(&buffer_trash_path, "{s}/{s}__{d}_{X}.trash", .{ trash_dir, file_name, std.time.milliTimestamp(), rand_buffer }) catch {
        return error.FailedToCreatePath;
    };
}

pub fn trashPathNameDigest(file_name: []const u8, digest: []const u8) ![]const u8 {
    const trash_dir = try trashDir();

    // truncating digest to 16 bites to shorten the output
    // b64_buffer len ==  22 == std.base64.url_safe_no_pad.Encoder.calcSize(16);
    var b64_buffer: [22]u8 = undefined;
    const b64_short_digest = std.base64.url_safe_no_pad.Encoder.encode(&b64_buffer, digest[0..16]);

    return std.fmt.bufPrint(&buffer_trash_path, "{s}/{s}__{s}.trash", .{ trash_dir, file_name, b64_short_digest }) catch {
        return error.FailedToCreatePath;
    };
}

pub fn trashPathFromPath(path: []const u8) ![]const u8 {
    const basename = std.fs.path.basename(path);
    return try trashPathNameTimestamp(basename);
}

pub fn backupPathFromPath(path: []const u8) ![]const u8 {
    return std.fmt.bufPrint(&buffer_backup_path, "{s}.backup~", .{path}) catch {
        return error.FailedToCreatePath;
    };
}
