const std = @import("std");

const run = @import("./run.zig").run;

step: std.Build.Step,

pub fn init(b: *std.Build) *@This() {
    const result = b.allocator.create(@This()) catch @panic("OOM");
    result.step = std.Build.Step.init(.{
        .id = .custom,
        .owner = b,
        .makeFn = make,
        .name = "GitNoDirty",
    });
    return result;
}

pub fn make(step: *std.Build.Step, opt: std.Build.Step.MakeOptions) !void {
    _ = opt;
    const result = try run(step.owner, &.{
        "git",
        "-C",
        step.owner.build_root.path orelse ".",
        "diff",
        "--quiet",
    }, .Pipe, .Pipe);

    if (result.status != 0) {
        return error.GitDirty;
    }
}
