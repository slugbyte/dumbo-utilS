const std = @import("std");
const Version = @import("./src/build/Version.zig");
const UpdateReadme = @import("./src/build/UpdateReadme.zig");
const GitNoDirty = @import("./src/build/GitNoDirty.zig");
const addUtilExe = @import("./src/build/create_exe.zig").createExe;

const Exec = struct {
    path: []const u8,
    name: []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = Version.init(b);

    var build_mod = b.addOptions();
    build_mod.addOption([]const u8, "version", version.version);
    build_mod.addOption([]const u8, "date", version.date);
    build_mod.addOption([]const u8, "git_hash", version.git_hash);

    const util_mod = b.addModule("util", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const names: [2][]const u8 = .{ "move", "trash" };
    for (names) |exec| {
        _ = addUtilExe(b, target, optimize, exec, &.{
            .{ .name = "util", .module = util_mod },
            .{ .name = "build", .module = build_mod.createModule() },
        });
    }

    var install_step = b.getInstallStep();
    var update_readme = UpdateReadme.init(b);
    install_step.dependOn(&update_readme.step);
}
