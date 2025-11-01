const std = @import("std");
const util = @import("util");
const build_option = @import("build_option");
const Args = util.Args;
const basename = std.fs.path.basename;

pub const help_msg =
    \\Usage: move src.. dest (--flags)
    \\  Move or rename a file, or move multiple files into a directory.
    \\  When moveing files into a directory dest must have '/' at the end.
    \\  When moving multiple files last path must be a directory and have a '/' at the end.
    \\
    \\  Clobber Style:
    \\    (default)  error with warning
    \\    -f --force    overwrite the file
    \\    -t --trash    move to $trash
    \\    -b --backup   rename the dest file
    \\
    \\    If mulitiple clober flags the presidence is (backup > trash > force > default).
    \\  
    \\  Other Flags:
    \\    --version     print version
    \\    -r --rename   just replace the basename with dest
    \\    -s --silent   only print errors
    \\    -h --help     print this help
;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    if (!try util.env.exists("trash")) {
        return util.exit("ERROR: $trash must be set", .{});
    }

    var flag = Flags{};
    var args = try Args.init(allocator, &flag.flag_parser);

    if (flag.help) {
        util.log("{s}\n\n  Version:\n    {s} {s} {s} ({s})", .{ help_msg, build_option.version, build_option.change_id[0..8], build_option.commit_id[0..8], build_option.date });
        return;
    }

    if (flag.version) {
        util.log("move {s} {s} {s} ({s})", .{ build_option.version, build_option.change_id[0..8], build_option.commit_id[0..8], build_option.date });
        return;
    }

    const wd = util.WorkDir.initCWD();
    switch (args.positional.len) {
        0, 1 => {
            return util.exit("USAGE: move src dest [--flags]", .{});
        },
        2 => {
            return try move(
                flag,
                wd,
                args.positional[0],
                args.positional[1],
            );
        },
        else => {
            const dest_path: [:0]const u8 = args.positional[args.positional.len - 1];
            if (!try wd.exists(dest_path) or (try wd.stat(dest_path)).kind != .directory) {
                return util.exit("ERROR: dest must be a directory. {s}", .{dest_path});
            }
            for (args.positional[0 .. args.positional.len - 1]) |arg| {
                try move(flag, wd, arg, dest_path);
            }
        },
    }
}

pub fn move(flag: Flags, cwd: util.WorkDir, src: [:0]const u8, dest: [:0]const u8) !void {
    var dest_path = dest;
    var rename_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var into_dir = false;

    if (!try cwd.exists(src)) {
        return util.exit("FILE NOT FOUND! {s}", .{src});
    }
    if (std.mem.endsWith(u8, dest_path, "/")) {
        if (!try cwd.exists(dest_path) or (try cwd.stat(dest_path)).kind != .directory) {
            return util.exit("dir not found: {s}", .{dest_path});
        }
        const file_name = std.fs.path.basename(src);
        dest_path = try std.fmt.bufPrintZ(&rename_buffer, "{s}/{s}", .{ dest_path, file_name });
        into_dir = true;
    }
    if (flag.rename) {
        if (into_dir) {
            return util.exit("ERROR: --rename cannot be used when moving a file into a directiory.", .{});
        }
        const dest_dirname = std.fs.path.dirname(src) orelse "";
        dest_path = try std.fmt.bufPrintZ(&rename_buffer, "{s}/{s}", .{ dest_dirname, dest_path });
    }
    if (try cwd.exists(dest_path)) {
        if (try cwd.isPathEqual(src, dest_path)) {
            return util.exit("ERROR: src and dest cannot be the same location.", .{});
        }
        switch (flag.overwrite_style) {
            .NoClobberError => util.exit("ERROR: dest file exists. Use clobber flags or add '/' to move into dir.", .{}),
            .Trash => {
                const stat = try cwd.stat(dest_path);
                const trash_path = cwd.trashKind(dest_path, stat.kind) catch |err| switch (err) {
                    error.TrashFileKindNotSupported => {
                        return util.exit("ERROR: dest exists but kind ({s}) cannot be trashed", .{@tagName(stat.kind)});
                    },
                    else => return err,
                };
                if (!flag.silent) util.log("dest trashed: $trash/{s}", .{basename(trash_path)});
            },
            .Backup => {
                const path_destinaton_backup = try util.path.backupPathFromPath(dest_path);
                if (try cwd.exists(path_destinaton_backup)) {
                    const stat = try cwd.stat(path_destinaton_backup);
                    const trash_path = cwd.trashKind(path_destinaton_backup, stat.kind) catch |err| switch (err) {
                        error.TrashFileKindNotSupported => {
                            return util.exit("ERROR: prev backup exists but kind ({s}) cannot be trashed", .{@tagName(stat.kind)});
                        },
                        else => return err,
                    };
                    if (!flag.silent) util.log("backup trashed: $trash/{s}", .{basename(trash_path)});
                }
                try cwd.move(dest_path, path_destinaton_backup);
                if (!flag.silent) util.log("backup created: {s}", .{path_destinaton_backup});
            },
            .Force => {},
        }
    }
    try cwd.move(src, dest_path);
    if (!flag.silent) {
        util.log("{s} -> {s}", .{ src, dest_path });
    }
}

const Flags = struct {
    help: bool = false,
    version: bool = false,
    rename: bool = false,
    silent: bool = false,
    overwrite_style: OverwriteStyle = .NoClobberError,

    flag_parser: Args.FlagParser = .{
        .parseFn = Flags.implParseFn,
    },

    pub const OverwriteStyle = enum(u3) {
        NoClobberError = 0, // DEFAULT
        Force = 1,
        Trash = 2,
        Backup = 3,

        pub fn prioritySet(self: *OverwriteStyle, value: OverwriteStyle) void {
            if (@intFromEnum(self.*) < @intFromEnum(value)) {
                self.* = value;
            }
        }
    };

    pub fn implParseFn(flag_parser: *Args.FlagParser, arg: [:0]const u8, _: *Args.ArgIterator) Args.Error!bool {
        var self = @as(*Flags, @fieldParentPtr("flag_parser", flag_parser));

        if (Args.eqlFlag(arg, "--trash", "-t")) {
            self.overwrite_style.prioritySet(.Trash);
            return true;
        }
        if (Args.eqlFlag(arg, "--backup", "-b")) {
            self.overwrite_style.prioritySet(.Backup);
            return true;
        }
        if (Args.eqlFlag(arg, "--force", "-f")) {
            self.overwrite_style.prioritySet(.Force);
            return true;
        }
        if (Args.eqlFlag(arg, "--silent", "-s")) {
            self.silent = true;
            return true;
        }
        if (Args.eqlFlag(arg, "--rename", "-r")) {
            self.rename = true;
            return true;
        }
        if (Args.eql(arg, "--version")) {
            self.version = true;
            return true;
        }

        if (Args.eqlFlag(arg, "--help", "-h")) {
            self.help = true;
            return true;
        }

        return false;
    }
};
