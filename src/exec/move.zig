const std = @import("std");
const util = @import("util");
const config = @import("config");

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
    \\    -s --silent   dont print clobber info
    \\    -v --verbose  print the move paths
    \\    -h --help     print this help
;

pub fn main() !void {
    if (!try util.env.exists("trash")) {
        return util.exit("ERROR: $trash must be set", .{});
    }

    var flag = FlagParser{};
    var args = util.ArgIterator.initWithFlags(&flag);

    if (flag.help) {
        util.log("{s}\n\n  Version:\n    {s} {s} ({s})", .{ help_msg, config.version, config.git_hash, config.date });
        return;
    }

    if (flag.version) {
        util.log("move {s} {s} ({s})", .{ config.version, config.git_hash, config.date });
        return;
    }

    _ = args.skip();
    const wd = util.WorkDir.initCWD();
    const path_count = args.len - args.flag_index_cache.items.len - 1;
    switch (path_count) {
        0, 1 => {
            return util.exit("USAGE: move src dest [--flags]", .{});
        },
        2 => {
            return try move(
                flag,
                wd,
                args.nextNonFlag().?, // src_path
                args.nextNonFlag().?, // dest_path
            );
        },
        else => {
            var dest_path: [:0]const u8 = undefined;
            for (0..path_count) |_| {
                dest_path = args.nextNonFlag().?;
            }
            if (!try wd.exists(dest_path) or (try wd.stat(dest_path)).kind != .directory) {
                return util.exit("ERROR: dest must be a directory. {s}", .{dest_path});
            }
            args.reset();
            _ = args.skip();
            for (0..path_count - 1) |_| {
                try move(flag, wd, args.nextNonFlag().?, dest_path);
            }
        },
    }
}

pub fn move(flag: FlagParser, cwd: util.WorkDir, src: [:0]const u8, dest: [:0]const u8) !void {
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
                if (!flag.silent) util.log("dest trashed: {s}", .{trash_path});
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
                    if (!flag.silent) util.log("backup trashed: {s}", .{trash_path});
                }
                try cwd.move(dest_path, path_destinaton_backup);
                if (!flag.silent) util.log("backup created: {s}", .{path_destinaton_backup});
            },
            .Force => {},
        }
    }
    try cwd.move(src, dest_path);
    if (flag.verbose) {
        util.log("{s} -> {s}", .{ src, dest_path });
    }
}

const FlagParser = struct {
    help: bool = false,
    version: bool = false,
    rename: bool = false,
    silent: bool = false,
    verbose: bool = false,
    overwrite_style: OverwriteStyle = .NoClobberError,
    index_cache_buffer: [20]usize = undefined,

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

    pub fn parse(self: *FlagParser, arg: [:0]const u8) bool {
        if (util.ArgIterator.isArgFlag(arg, "--trash", "-t")) {
            self.overwrite_style.prioritySet(.Trash);
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--backup", "-b")) {
            self.overwrite_style.prioritySet(.Backup);
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--force", "-f")) {
            self.overwrite_style.prioritySet(.Force);
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--verbose", "-v")) {
            self.verbose = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--silent", "-s")) {
            self.silent = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--rename", "-r")) {
            self.rename = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--version", null)) {
            self.version = true;
            return true;
        }
        if (util.ArgIterator.isArgFlag(arg, "--help", "-h")) {
            self.help = true;
            return true;
        }
        return false;
    }
};
