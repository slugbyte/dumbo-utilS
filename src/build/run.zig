const std = @import("std");

pub const RunResult = struct {
    status: u8,
    stdout: []const u8,
    stderr: []const u8,
    terminated: bool,
};

pub fn run(
    b: *std.Build,
    argv: []const []const u8,
    stdout_behavior: std.process.Child.StdIo,
    stderr_behavior: std.process.Child.StdIo,
) !RunResult {
    std.debug.assert(argv.len != 0);

    if (!std.process.can_spawn)
        return error.ExecNotSupported;

    const max_output_size = 400 * 1024;
    var child = std.process.Child.init(argv, b.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = stdout_behavior;
    child.stderr_behavior = stderr_behavior;
    child.env_map = &b.graph.env_map;

    try std.Build.Step.handleVerbose2(b, null, child.env_map, argv);
    try child.spawn();

    const stdout = if (stdout_behavior != .Pipe) "" else child.stdout.?.deprecatedReader().readAllAlloc(b.allocator, max_output_size) catch {
        return error.ReadFailure;
    };
    errdefer b.allocator.free(stdout);

    const stderr = if (stderr_behavior != .Pipe) "" else child.stderr.?.deprecatedReader().readAllAlloc(b.allocator, max_output_size) catch {
        return error.ReadFailure;
    };
    errdefer b.allocator.free(stdout);

    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            return .{
                .status = @as(u8, @truncate(code)),
                .stdout = stdout,
                .stderr = stderr,
                .terminated = false,
            };
        },
        .Signal, .Stopped, .Unknown => |code| {
            return .{
                .status = @as(u8, @truncate(code)),
                .stdout = stdout,
                .stderr = stderr,
                .terminated = true,
            };
        },
    }
}
