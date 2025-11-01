const std = @import("std");
const util = @import("./root.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

const WorkDir = @This();

dir: std.fs.Dir,

pub fn init(dir: std.fs.Dir) WorkDir {
    return .{
        .dir = dir,
    };
}

pub fn initCWD() WorkDir {
    return init(std.fs.cwd());
}

pub fn openFile(self: WorkDir, path: []const u8, open_flags: std.fs.File.OpenFlags) !std.fs.File {
    return try self.dir.openFile(path, open_flags);
}

pub fn hashFileSha256(self: WorkDir, file: std.fs.File, digest_buffer: *[Sha256.digest_length]u8) !void {
    _ = self;
    const Hashing = std.Io.Writer.Hashing(Sha256);
    var hashing_buffer: [1024]u8 = undefined;
    var hashing = Hashing.initHasher(Sha256.init(.{}), &hashing_buffer);

    var read_buffer: [1024]u8 = undefined;
    var file_reader = file.readerStreaming(&read_buffer);
    _ = try file_reader.interface.streamRemaining(&hashing.writer);
    try hashing.writer.flush();

    hashing.hasher.final(digest_buffer);
}

pub fn hashFilePathSha256(self: WorkDir, path: []const u8, digest_buffer: *[Sha256.digest_length]u8) !void {
    const file = try self.openFile(path, .{});
    defer file.close();

    try self.hashFileSha256(file, digest_buffer);
}

pub fn stat(self: WorkDir, path: []const u8) !std.fs.File.Stat {
    return self.dir.statFile(path);
}

pub fn exists(self: WorkDir, path: []const u8) !bool {
    _ = self.stat(path) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

pub fn trashKind(self: WorkDir, path: []const u8, kind: std.fs.File.Kind) ![]const u8 {
    switch (kind) {
        .file => {
            const file_name = std.fs.path.basename(path);
            var digest: [Sha256.digest_length]u8 = undefined;
            try self.hashFilePathSha256(path, &digest);
            const trash_path = try util.path.trashPathNameDigest(file_name, &digest);
            try self.move(path, trash_path);
            return trash_path;
        },
        .directory, .sym_link => {
            const file_name = std.fs.path.basename(path);
            var trash_path = try util.path.trashPathNameTimestamp(file_name);
            if (try self.exists(trash_path)) {
                trash_path = try util.path.trashPathNameTimestampRandom(file_name);
            }
            try self.move(path, trash_path);
            return trash_path;
        },
        else => {
            return error.TrashFileKindNotSupported;
        },
    }
}

pub fn trashAutoKind(self: WorkDir, path: []const u8) ![]const u8 {
    const path_stat = try self.stat(path);
    return self.trashKind(path, path_stat.kind);
}

/// Asserts both paths exist
pub fn isPathEqual(self: WorkDir, path_a: []const u8, path_b: []const u8) !bool {
    var buf_realpath_a: [std.fs.max_path_bytes]u8 = undefined;
    var buf_realpath_b: [std.fs.max_path_bytes]u8 = undefined;
    const realpath_a = try self.dir.realpath(path_a, &buf_realpath_a);
    const realpath_b = try self.dir.realpath(path_b, &buf_realpath_b);
    if (std.mem.eql(u8, realpath_a, realpath_b)) {
        return true;
    }
    return false;
}

pub fn move(self: WorkDir, path_source: []const u8, path_destination: []const u8) !void {
    try self.dir.rename(path_source, path_destination);
}
