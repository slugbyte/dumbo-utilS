const std = @import("std");
const Config = @This();
const build_pkg = @import("./root.zig");

target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
build: *std.Build,

version: []const u8,
git_hash: []const u8,
date: []const u8,

pub fn init(b: *std.Build) Config {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const git_hash = build_pkg.run(b, .Pipe, .Ignore, &.{
        "git",
        "-C",
        b.build_root.path orelse ".",
        "rev-parse",
        "--short",
        "HEAD",
    }).stdout orelse "no-git-hash";

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
        .git_hash = std.mem.trim(u8, git_hash, "\n\t "),
    };
}

pub fn createOptionsModule(self: Config) *std.Build.Module {
    var config = self.build.addOptions();
    config.addOption([]const u8, "date", self.date);
    config.addOption([]const u8, "version", self.version);
    config.addOption([]const u8, "git_hash", self.git_hash);
    return config.createModule();
}
