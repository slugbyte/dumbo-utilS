const std = @import("std");

const Version = @This();

version: []const u8,
git_hash: []const u8,
date: []const u8,

pub fn init(b: *std.Build) Version {
    const git_hash: []const u8 = blk: {
        var out_code: u8 = undefined;
        const result = b.runAllowFail(&.{ "git", "-C", b.build_root.path orelse ".", "rev-parse", "--short", "HEAD" }, &out_code, .Ignore) catch {
            break :blk "no_git_hash";
        };
        break :blk std.mem.trim(u8, result, " \t\n");
    };

    const date: []const u8 = blk: {
        var out_code: u8 = undefined;
        const result = b.runAllowFail(&.{ "date", "+%y.%m.%d %H:%M" }, &out_code, .Ignore) catch {
            break :blk "yy.mm.dd hh:mm";
        };
        break :blk std.mem.trim(u8, result, " \t\n");
    };

    const build_zon = @import("../../build.zig.zon");

    return .{
        .git_hash = git_hash,
        .version = build_zon.version,
        .date = date,
    };
}
