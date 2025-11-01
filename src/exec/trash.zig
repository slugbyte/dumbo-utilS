const std = @import("std");
const util = @import("util");
const build_option = @import("build_option");
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
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();
    var warning_list: util.WarningList = .init(arena);

    if (util.env.exists("trash")) {
        util.log("ERROR: $trash must be set", .{});
        warning_list.EXIT(1);
    }

    var flag = Flags{};
    const args = try Args.init(arena, &flag.flag_parser);

    if (flag.help) {
        util.log("{s}\n\n  Version:\n   {s} {s} {s} ({s})", .{
            help_msg,
            build_option.version,
            build_option.change_id[0..8],
            build_option.commit_id[0..8],
            build_option.date,
        });
        return;
    }

    if (flag.version) {
        util.log("trash {s} {s} {s} ({s})", .{
            build_option.version,
            build_option.change_id[0..8],
            build_option.commit_id[0..8],
            build_option.date,
        });
        return;
    }

    if (args.positional.len == 0) {
        util.log("USAGE: trash [file]...", .{});
        warning_list.EXIT(1);
    }

    const wd = util.WorkDir.initCWD();
    for (args.positional) |path| {
        const stat = wd.stat(path) catch |err| switch (err) {
            else => warning_list.PANIC("unexpected error: {t}", .{err}),
            error.FileNotFound => {
                try warning_list.pushWarning("file not found: {s}", .{path});
                continue;
            },
        };
        const trash_path = wd.trashKind(path, stat.kind) catch |err| switch (err) {
            else => warning_list.PANIC("unexpected error: {t}", .{err}),
            error.TrashFileKindNotSupported => {
                try warning_list.pushWarning("trash does not support '{t}' files, unable to trash: {s}", .{ stat.kind, path });
                continue;
            },
        };
        if (!flag.silent) util.log("{s} > $trash/{s}", .{ path, std.fs.path.basename(trash_path) });
    }
    warning_list.report();
    warning_list.EXIT(null);
}

const Flags = struct {
    help: bool = false,
    version: bool = false,
    silent: bool = false,

    flag_parser: Args.FlagParser = .{
        .parseFn = Flags.implParseFn,
    },

    pub fn implParseFn(flag_parser: *Args.FlagParser, arg: [:0]const u8, _: *Args.ArgIterator) Args.Error!bool {
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
