const std = @import("std");
const util = @import("util");
const build = @import("build");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub fn main() !void {
    if (!try util.env.exists("trash")) {
        return util.exit("ERROR: $trash must be set", .{});
    }

    var flag = FlagParser{};
    var args = util.ArgIterator.initWithFlags(&flag);
    if (args.len < 2) {
        return util.exit("USAGE ERROR: trash [file]...", .{});
    }

    if (flag.help) {
        const help =
            \\USAGE: trash [files].. (--flags)
            \\  --version      print version
            \\  --s --silent   dont print trash paths
            \\  --h --help     display help
        ;
        util.log("{s}\n\n  Version:\n    {s} {s} ({s})", .{ help, build.version, build.git_hash, build.date });
        return;
    }

    if (flag.version) {
        util.log("trash {s} {s} ({s})", .{ build.version, build.git_hash, build.date });
        return;
    }

    const cwd = util.WorkDir.init();
    _ = args.skip();
    while (args.nextNonFlag()) |arg| {
        if (try cwd.exists(arg)) {
            const stat = try cwd.stat(arg);
            const trash_path = cwd.trashKind(arg, stat.kind) catch |err| switch (err) {
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
