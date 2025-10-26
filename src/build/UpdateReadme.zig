const std = @import("std");
step: std.Build.Step,

pub fn init(b: *std.Build) *@This() {
    const result = b.allocator.create(@This()) catch @panic("OOM");
    result.step = .init(.{
        .id = .custom,
        .name = "update readme",
        .makeFn = make,
        .owner = b,
    });
    return result;
}

pub fn make(b: *std.Build.Step, opt: std.Build.Step.MakeOptions) !void {
    _ = opt;
    const root_dir_path = b.owner.build_root.path.?;

    var root_dir = try std.fs.openDirAbsolute(root_dir_path, .{});
    defer root_dir.close();

    var readme_file = try root_dir.createFile("README.md", .{});
    defer readme_file.close();

    var write_buffer: [1024]u8 = undefined;
    var writer = readme_file.writer(&write_buffer);

    const move_help_msg = @import("../exec/move.zig").help_msg;
    const trash_help_msg = @import("../exec/trash.zig").help_msg;

    try writer.interface.print(README_CONTENT, .{ move_help_msg, trash_help_msg });
    try writer.interface.flush();
}

const README_CONTENT =
    \\# safeutils
    \\> coreutil replacements that aim to protect you from overwriting work.
    \\
    \\## about
    \\I lost work one too many times, by accidently overwriting data with coreutils. I made these utils to
    \\reduce the chances that would happen again. They provide much less dangerous clobber strats.
    \\ 
    \\### trash strategy
    \\* files become `$trash/(basename)__(hash).trash`
    \\* dirs and links `$trash/(basename)__(timestamp).trash`
    \\  * if there is a conflict it will be name `$trash/(basename)__(timestap)_(random).trash`
    \\
    \\## backup strategy
    \\* rename file `(original_path).backup~`
    \\  * if a backup exists it will be moved to trash
    \\
    \\## move (mv replacement)
    \\move or rename files without accidently replacing anything.
    \\```
    \\{s}
    \\```
    \\
    \\## trash (rm replacement)
    \\Move files into $trash with a naming strat that wont overwrite existing trashed files.
    \\```
    \\{s}
    \\```
;
