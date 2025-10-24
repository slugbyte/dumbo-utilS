const std = @import("std");

pub const RunResult = struct {
    status: u8,
    stdout: ?[]const u8,
    stderr: ?[]const u8,
    terminated: bool,
};

pub fn run(
    b: *std.Build,
    stdout_behavior: std.process.Child.StdIo,
    stderr_behavior: std.process.Child.StdIo,
    argv: []const []const u8,
) RunResult {
    std.debug.assert(argv.len != 0);

    if (!std.process.can_spawn)
        return error.ExecNotSupported;

    const max_output_size = 400 * 1024;
    var child = std.process.Child.init(argv, b.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = stdout_behavior;
    child.stderr_behavior = stderr_behavior;
    child.env_map = &b.graph.env_map;

    std.Build.Step.handleVerbose2(b, null, child.env_map, argv) catch @panic("OOM");
    child.spawn() catch @panic("build_pkg.run() spawn failed");

    const stdout = if (stdout_behavior != .Pipe) "" else child.stdout.?.deprecatedReader().readAllAlloc(b.allocator, max_output_size) catch {
        @panic("build_pkg.run() read stdout error");
    };
    errdefer b.allocator.free(stdout);

    const stderr = if (stderr_behavior != .Pipe) "" else child.stderr.?.deprecatedReader().readAllAlloc(b.allocator, max_output_size) catch {
        @panic("build_pkg.run() read stderr error");
    };
    errdefer b.allocator.free(stdout);

    const term = child.wait() catch @panic("build_pkg.run() wait failed");
    switch (term) {
        .Exited => |code| {
            return .{
                .terminated = false,
                .status = @as(u8, @truncate(code)),
                .stdout = if (stdout.len == 0) null else stdout,
                .stderr = if (stderr.len == 0) null else stderr,
            };
        },
        .Signal, .Stopped, .Unknown => |code| {
            return .{
                .terminated = true,
                .status = @as(u8, @truncate(code)),
                .stdout = if (stdout.len == 0) null else stdout,
                .stderr = if (stderr.len == 0) null else stderr,
            };
        },
    }
}
