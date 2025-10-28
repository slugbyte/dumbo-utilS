const std = @import("std");
const util = @import("util");
const config = @import("config");
const Sha256 = std.crypto.hash.sha2.Sha256;
const Args = util.Args;

pub const help_msg =
    \\USAGE: trash files.. (--flags)
    \\  Move files to $trash.
    \\
    \\  --version      print version
    \\  --s --silent   dont print trash paths
    \\  --h --help     display help
;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    if (!try util.env.exists("trash")) {
        return util.exit("ERROR: $trash must be set", .{});
    }

    var flag = Flags{};
    const args = try Args.init(allocator, &flag.flag_parser);

    if (flag.help) {
        util.log("{s}\n\n  Version:\n   {s} {s} {s} ({s})", .{ help_msg, config.version, config.change_id[0..8], config.commit_id[0..8], config.date });
        return;
    }

    if (flag.version) {
        util.log("trash {s} {s} {s} ({s})", .{ config.version, config.change_id[0..8], config.commit_id[0..8], config.date });
        return;
    }

    if (args.positional.len == 0) {
        return util.exit("USAGE: trash [file]...", .{});
    }

    const wd = util.WorkDir.initCWD();
    for (args.positional) |arg| {
        if (try wd.exists(arg)) {
            const stat = try wd.stat(arg);
            const trash_path = wd.trashKind(arg, stat.kind) catch |err| switch (err) {
                error.TrashFileKindNotSupported => {
                    return util.exit("ERROR: can't trah kind ({s}). {s}", .{ @tagName(stat.kind), arg });
                },
                else => return err,
            };
            if (!flag.silent) util.log("{s} > $trash/{s}", .{ arg, std.fs.path.basename(trash_path) });
        } else {
            util.log("file not found: {s}", .{arg});
        }
    }
}

const Flags = struct {
    help: bool = false,
    version: bool = false,
    silent: bool = false,
    flag_parser: Args.FlagParser = .{
        .parseFn = Flags.implParseFn,
    },

    pub fn implParseFn(flag_parser: *Args.FlagParser, arg: [:0]const u8, _: *Args.ArgIterator) Args.FlagParser.Error!bool {
        var self = @as(*Flags, @fieldParentPtr("flag_parser", flag_parser));

        if (Args.eqlFlag(arg, "--help", "-h")) {
            self.help = true;
            return true;
        }
        if (Args.eqlFlag(arg, "--silent", "-s")) {
            self.silent = true;
            return true;
        }
        if (Args.eql(arg, "--version")) {
            self.version = true;
            return true;
        }
        return false;
    }
};
