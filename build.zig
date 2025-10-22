const std = @import("std");

const Exec = struct {
    path: []const u8,
    name: []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("util", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    var opts = b.addOptions();
    const opt_version = b.option([]const u8, "version", "version");
    const opt_date = b.option([]const u8, "date", "date");
    const opt_git_hash = b.option([]const u8, "git_hash", "git hash");

    opts.addOption([]const u8, "version", opt_version orelse "v?");
    opts.addOption([]const u8, "date", opt_date orelse "yymmdd hh:mm");
    opts.addOption([]const u8, "git_hash", opt_git_hash orelse "debug");

    const exec_list: [2]Exec = .{
        .{
            .name = "move",
            .path = "./src/exec/move.zig",
        },
        .{
            .name = "trash",
            .path = "./src/exec/trash.zig",
        },
    };

    for (exec_list) |exec| {
        const exe = b.addExecutable(.{
            .name = exec.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(exec.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "util", .module = mod },
                    .{ .name = "build", .module = opts.createModule() },
                },
            }),
        });
        b.installArtifact(exe);
        var buffer: [1024]u8 = undefined;
        const run_step = b.step(std.fmt.bufPrint(&buffer, "run_{s}", .{exec.name}) catch unreachable, "Run the app");
        const run_cmd = b.addRunArtifact(exe);
        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
    }
}
