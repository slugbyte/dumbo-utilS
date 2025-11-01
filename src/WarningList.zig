const std = @import("std");
const util = @import("./root.zig");

// TODO: rename Reporter
// TODO: track success/failure/warning count

const WarningList = @This();
// accumulate warnings so that they can be reported at the end
allocator: std.mem.Allocator,
array_list: std.ArrayList([]const u8),

pub fn init(allocator: std.mem.Allocator) WarningList {
    return .{
        .allocator = allocator,
        .array_list = .empty,
    };
}

pub fn deinit(self: *WarningList) void {
    for (self.getAll()) |item| {
        self.allocator.free(item);
    }
    self.array_list.deinit(self.allocator);
    self.* = undefined;
}

pub fn PANIC(self: WarningList, comptime format: []const u8, args: anytype) noreturn {
    self.report();
    std.debug.panic(format, args);
}

pub fn EXIT(self: WarningList, status: ?u8) noreturn {
    std.process.exit(status orelse if (self.isEmpty()) 0 else 1);
}

pub inline fn report(self: WarningList) void {
    for (self.getAll()) |warning| {
        util.log("WARNING! {s}", .{warning});
    }
}

pub inline fn isEmpty(self: WarningList) bool {
    return self.array_list.items.len == 0;
}

pub inline fn getAll(self: WarningList) [][]const u8 {
    return self.array_list.items;
}

pub inline fn pushWarning(self: *WarningList, comptime format: []const u8, args: anytype) !void {
    try self.array_list.append(self.allocator, try std.fmt.allocPrint(self.allocator, format, args));
}
