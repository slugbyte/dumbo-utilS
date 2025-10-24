const std = @import("std");
const Config = @This();
const build_pkg = @import("./root.zig");

target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
build: *std.Build,

version: []const u8,
change_id: []const u8,
commit_id: []const u8,
date: []const u8,

pub fn init(b: *std.Build) Config {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    //
    const commit_id = build_pkg.run(b, .Pipe, .Ignore, &.{
        "jj",
        "--no-graph",
        "-r",
        "@",
        "-T",
        "commit_id",
    }).stdout orelse "no_git_hash";

    const change_id = build_pkg.run(b, .Pipe, .Ignore, &.{
        "jj",
        "--no-graph",
        "-r",
        "@",
        "-T",
        "change_id",
    }).stdout orelse "no_git_hash";

    // TODO: make my own date formatter
    const date = build_pkg.run(b, .Pipe, .Ignore, &.{
        "date",
        "+%y.%m.%d %H:%M",
    }).stdout orelse "yy.mm.dd hh:mm";

    const build_zon = @import("../../build.zig.zon");

    return .{
        .build = b,
        .target = target,
        .optimize = optimize,
        .version = build_zon.version,
        .date = std.mem.trim(u8, date, "\n\t "),
        .commit_id = std.mem.trim(u8, commit_id, "\n\t "),
        .change_id = std.mem.trim(u8, change_id, "\n\t "),
    };
}

pub fn createOptionsModule(self: Config) *std.Build.Module {
    var config = self.build.addOptions();
    config.addOption([]const u8, "date", self.date);
    config.addOption([]const u8, "commit_id", self.commit_id);
    config.addOption([]const u8, "change_id", self.change_id);
    config.addOption([]const u8, "version", self.version);
    return config.createModule();
}
