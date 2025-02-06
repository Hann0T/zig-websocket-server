const std = @import("std");

const Header = @This();

key: []const u8,
value: []const u8,

pub fn parse(raw: []const u8) !?Header {
    var iter = std.mem.splitScalar(u8, raw, ':');
    const key = std.mem.trim(u8, iter.next().?, " ");
    const value = std.mem.trim(u8, iter.next().?, " ");
    return .{ .key = key, .value = value };
}
