const std = @import("std");
const util = @import("util");
var trash_dir: []const u8 = undefined;

const OverwriteStyle = enum(u3) {
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

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debug_allocator.allocator();
    const args = try std.process.argsAlloc(allocator);
    trash_dir = try std.process.getEnvVarOwned(allocator, "trash");

    if (trash_dir.len == 0) {
        return util.exit("$trash env must be set", .{});
    }
    if (args.len < 2) {
        util.exit("", .{});
        return util.exit("noting to do :(", .{});
    }

    var flag_help = false;
    var flag_overwrite_style: OverwriteStyle = .NoClobberError;
    var path_list: [2][:0]const u8 = undefined;
    var path_index: usize = 0;

    for (args[1..]) |arg| {
        var is_flag = false;
        if (std.mem.eql(u8, "--trash", arg) or std.mem.eql(u8, "-t", arg)) {
            flag_overwrite_style.prioritySet(.Trash);
            is_flag = true;
        }
        if (std.mem.eql(u8, "--backup", arg) or std.mem.eql(u8, "-b", arg)) {
            flag_overwrite_style.prioritySet(.Backup);
            is_flag = true;
        }
        if (std.mem.eql(u8, "--force", arg) or std.mem.eql(u8, "-f", arg)) {
            flag_overwrite_style.prioritySet(.Force);
            is_flag = true;
        }
        if (std.mem.eql(u8, "--help", arg) or std.mem.eql(u8, "-h", arg)) {
            flag_help = true;
        }
        if (!is_flag and path_index == path_list.len) {
            return util.exit("ERROR: a non-flag occured and there are allready two paths ({s})", .{arg});
        }
        if (!is_flag and path_index < path_list.len) {
            path_list[path_index] = arg;
            path_index += 1;
        }
    }

    if (flag_help) {
        const help =
            \\Usage: move src dest [flags] 
            \\  Clobber Style:
            \\    (default)  error with warning
            \\    -f --force    overwrite the file
            \\    -t --trash    move to trash         $trash/TRASH_{unixtimesamp}__{dest_basename}
            \\    -b --backup   rename the dest file  {dest}.backup~
            \\
            \\    if mulitiple clober flags the presidence is (backup > trash > force > default)
            \\  
            \\  Other:
            \\    --help     print this help
        ;
        return util.exit("{s}", .{help});
    }

    if (path_index != path_list.len) {
        return util.exit("USAGE: move src dest [--flags]", .{});
    }

    var cwd = util.WorkDir.init();
    const path_to_move = path_list[0];
    const path_destinaton = path_list[1];

    if (!try cwd.exists(path_to_move)) {
        return util.exit("FILE NOT FOUND! {s}", .{path_to_move});
    }
    if (try cwd.exists(path_destinaton)) {
        if (try cwd.isPathEqual(path_to_move, path_destinaton)) {
            return util.exit("ERROR: src and dest cannot be the same location.", .{});
        }
        switch (flag_overwrite_style) {
            .NoClobberError => util.exit("ERROR: destination file exists. Use --trash --overwrite or --backup", .{}),
            .Trash => util.log("dest trashed: {s}", .{try cwd.trash(path_destinaton)}),
            .Backup => {
                const path_destinaton_backup = try util.path.backupPathFromPath(path_destinaton);
                if (try cwd.exists(path_destinaton_backup)) {
                    util.log("previous backup trashed: {s}", .{try cwd.trash(path_destinaton_backup)});
                }
                try cwd.move(path_destinaton, path_destinaton_backup);
                util.log("dest backup: {s}", .{path_destinaton_backup});
            },
            .Force => {},
        }
    }
    try cwd.move(path_to_move, path_destinaton);
}
