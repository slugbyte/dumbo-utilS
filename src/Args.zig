const std = @import("std");

const Args = @This();

args: [][:0]const u8,
positional: [][:0]const u8,
program_path: [:0]const u8,

pub fn init(allocator: std.mem.Allocator, flag_parser: *FlagParser) !Args {
    var iter = try ArgIterator.init(allocator);
    defer iter.deinit();
    const program_path = try allocator.dupeZ(u8, iter.next().?);
    var args = std.ArrayList([:0]const u8).empty;
    var positional = std.ArrayList([:0]const u8).empty;
    while (iter.next()) |arg| {
        try args.append(allocator, try allocator.dupeZ(u8, arg));
        if (!try flag_parser.parseFn(flag_parser, arg, &iter)) {
            try positional.append(allocator, try allocator.dupeZ(u8, arg));
        }
    }
    return .{
        .program_path = program_path,
        .args = try args.toOwnedSlice(allocator),
        .positional = try positional.toOwnedSlice(allocator),
    };
}

pub fn deinit(self: *Args, allocator: std.mem.Allocator) void {
    allocator.free(self.program_path);
    allocator.free(self.args);
    allocator.free(self.positional);
    self.* = undefined;
}

pub const FlagParser = struct {
    pub const Error = error{ MissingValue, ParseFailed } || std.mem.Allocator.Error || std.fs.Dir.StatFileError;
    parseFn: *const fn (*FlagParser, [:0]const u8, *ArgIterator) Error!bool,
};

pub const ArgIterator = struct {
    inner: std.process.ArgIterator,

    pub fn init(allocator: std.mem.Allocator) !ArgIterator {
        return .{
            .inner = try std.process.argsWithAllocator(allocator),
        };
    }

    pub fn deinit(self: *ArgIterator) void {
        self.inner.deinit();
        self.* = undefined;
    }

    pub inline fn next(self: *ArgIterator) ?[:0]const u8 {
        return self.inner.next();
    }

    pub inline fn nextOrFail(self: *ArgIterator) ![:0]const u8 {
        return self.inner.next() orelse FlagParser.Error.MissingValue;
    }

    pub inline fn nextInt(self: *ArgIterator, T: type, base: u8) !T {
        const arg = try self.nextOrFail();
        return std.fmt.parseInt(T, arg, base) catch return FlagParser.Error.ParseFailed;
    }

    pub inline fn nextFloat(self: *ArgIterator, T: type) !T {
        const arg = try self.nextOrFail();
        return std.fmt.parseFloat(T, arg) catch FlagParser.Error.ParseFailed;
    }

    pub const FilePath = struct {
        stat: std.fs.File.Stat,
        path: [:0]const u8,
    };

    pub inline fn nextFilePath(self: *ArgIterator) !FilePath {
        const arg = try self.nextOrFail();
        const stat = try std.fs.cwd().statFile(arg);
        return .{
            .path = arg,
            .stat = stat,
        };
    }

    pub inline fn skip(self: *ArgIterator) ?[:0]const u8 {
        return self.inner.skip();
    }
};

pub inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub inline fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

pub inline fn eqlAny(value: []const u8, needles: [][]const u8) bool {
    for (needles) |needle| {
        if (eql(value, needle)) {
            return true;
        }
    }
    return false;
}

pub inline fn eqlAnyIgnoreCase(value: []const u8, needles: [][]const u8) bool {
    for (needles) |needle| {
        if (eqlIgnoreCase(value, needle)) {
            return true;
        }
    }
    return false;
}

pub inline fn eqlFlag(value: []const u8, a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, value, a) or std.mem.eql(u8, value, b);
}

pub inline fn startsWith(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

pub inline fn startsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(haystack, needle);
}

pub inline fn endsWith(haystack: []const u8, needle: []const u8) bool {
    return std.mem.endsWith(u8, haystack, needle);
}

pub inline fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return std.ascii.endsWithIgnoreCase(haystack, needle);
}

pub inline fn endsWithAny(haystack: []const u8, needles: [][]const u8) bool {
    for (needles) |needle| {
        if (endsWith(haystack, needle)) {
            return true;
        }
    }
    return false;
}

pub inline fn endsWithAnyIgnoreCase(haystack: []const u8, needles: [][]const u8) bool {
    for (needles) |needle| {
        if (endsWithIgnoreCase(haystack, needle)) {
            return true;
        }
    }
    return false;
}

pub const noop_flag_parser: FlagParser = .{
    .parseFn = implNoopParseFn,
};

pub fn implNoopParseFn(_: *FlagParser, _: [:0]const u8, _: *ArgIterator) bool {
    return false;
}
