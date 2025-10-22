const std = @import("std");

const ArgIterator = @This();

len: usize,
index: usize,
iter: std.process.ArgIterator,
flag_index_cache: FlagIndexCache,

pub fn init() ArgIterator {
    var noop = NoopFlagParser{};
    return initWithFlags(&noop);
}

pub fn initWithFlags(flag_parser: anytype) ArgIterator {
    var flag_index_cache = FlagIndexCache.init(&flag_parser.index_cache_buffer);

    var iter = std.process.ArgIterator.init();
    var len: usize = 0;
    while (iter.next()) |arg| {
        if (flag_parser.parse(arg)) {
            flag_index_cache.push(len);
        }
        len += 1;
    }
    iter = std.process.ArgIterator.init();

    return .{
        .flag_index_cache = flag_index_cache,
        .iter = iter,
        .len = len,
        .index = 0,
    };
}

pub fn isArgFlag(arg: [:0]const u8, long: []const u8, short: ?[]const u8) bool {
    if (short) |short_flag| {
        return std.mem.eql(u8, arg, long) or std.mem.eql(u8, arg, short_flag);
    } else {
        return std.mem.eql(u8, arg, long);
    }
}

pub fn next(self: *ArgIterator) ?[:0]const u8 {
    if (self.iter.next()) |arg| {
        self.index += 1;
        return arg;
    }
    return null;
}

pub fn nextNonFlag(self: *ArgIterator) ?[:0]const u8 {
    if (self.flag_index_cache.contains(self.index)) {
        if (self.skip()) return self.nextNonFlag();
        return null;
    }

    return self.next();
}

pub fn skip(self: *ArgIterator) bool {
    if (self.iter.skip()) {
        self.index += 1;
        return true;
    }
    return false;
}

pub fn reset(self: *ArgIterator) void {
    self.iter = std.process.ArgIterator.init();
    self.index = 0;
}

pub const FlagIndexCache = struct {
    items: []usize,
    capacity: usize,

    pub fn init(buffer: []usize) FlagIndexCache {
        return .{
            .items = buffer[0..0],
            .capacity = buffer.len,
        };
    }

    pub fn push(self: *FlagIndexCache, index: usize) void {
        std.debug.assert(self.items.len < self.capacity);
        self.items.len += 1;
        self.items[self.items.len - 1] = index;
    }

    pub fn contains(self: FlagIndexCache, index: usize) bool {
        for (self.items) |i| {
            if (i == index) {
                return true;
            }
        }
        return false;
    }
};

/// A FlagParser requiers an index_cache_buffer and a parse fn
pub const NoopFlagParser = struct {
    index_cache_buffer: [0]usize = undefined,
    pub fn parse(arg: [:0]const u8) bool {
        _ = arg;
        return false;
    }
};
