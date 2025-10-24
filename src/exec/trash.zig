const std = @import("std");
const util = @import("util");
const config = @import("config");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const help_msg =
    \\USAGE: trash files.. (--flags)
    \\  Move files to $trash.
    \\
    \\  --version      print version
    \\  --s --silent   dont print trash paths
    \\  --h --help     display help
;

pub fn main() !void {
    if (!try util.env.exists("trash")) {
        return util.exit("ERROR: $trash must be set", .{});
    }

    var flag = FlagParser{};
    var args = util.ArgIterator.initWithFlags(&flag);
    if (args.len < 2) {
        return util.exit("USAGE: trash [file]...", .{});
    }

    if (flag.help) {
        util.log("{s}\n\n  Version:\n   {s} {s} {s} ({s})", .{ help_msg, config.version, config.change_id[0..8], config.commit_id[0..8], config.date });
        return;
    }

    if (flag.version) {
        util.log("trash {s} {s} {s} ({s})", .{ config.version, config.change_id[0..8], config.commit_id[0..8], config.date });
        return;
    }

    const wd = util.WorkDir.initCWD();
    _ = args.skip();
    while (args.nextNonFlag()) |arg| {
        if (try wd.exists(arg)) {
            const stat = try wd.stat(arg);
            const trash_path = wd.trashKind(arg, stat.kind) catch |err| switch (err) {
                error.TrashFileKindNotSupported => {
                    return util.exit("ERROR: can't trah kind ({s}). {s}", .{ @tagName(stat.kind), arg });
                },
                else => return err,
            };
            if (!flag.silent) util.log("{s}", .{trash_path});
        } else {
            util.log("file not found: {s}", .{arg});
        }
    }
}

const FlagParser = struct {
    help: bool = false,
    version: bool = false,
    silent: bool = false,
    index_cache_buffer: [20]usize = undefined,

    pub fn parse(self: *FlagParser, arg: [:0]const u8) bool {
        if (util.ArgIterator.isArgFlag(arg, "--help", "-h")) {
            self.help = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--version", null)) {
            self.version = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--silent", "-s")) {
            self.silent = true;
            return true;
        }
        return false;
    }
};
