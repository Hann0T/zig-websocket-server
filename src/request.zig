const std = @import("std");
const Method = @import("method.zig").Method;
const Header = @import("header.zig");

const Request = @This();

uri: []const u8,
version: []const u8,
method: Method,
headers: []Header,
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator, uri: []const u8, method: Method, version: []const u8, headers: []Header) Request {
    return .{ .alloc = alloc, .uri = uri, .method = method, .version = version, .headers = headers };
}

pub fn deinit(self: *Request) void {
    self.alloc.free(self.headers);
}

pub fn header_get(self: *Request, key: []const u8) ?[]const u8 {
    for (self.headers) |header| {
        if (std.mem.eql(u8, header.key, key)) {
            return header.value;
        }
    }

    return null;
}

pub fn parse(alloc: std.mem.Allocator, raw: []const u8) !Request {
    var iter = std.mem.splitAny(u8, raw, "\r\n");

    const request_line = iter.next().?;
    var request_line_iter = std.mem.splitScalar(u8, request_line, ' ');

    const method = try Method.init(request_line_iter.next().?);
    const uri = request_line_iter.next().?;
    const version = request_line_iter.next().?;

    var headers = std.ArrayList(Header).init(alloc);
    defer headers.deinit();

    while (iter.next()) |text| {
        // A better way to determine if the slice is zeroed?
        if (std.mem.allEqual(u8, text, 0) or std.mem.allEqual(u8, text, '\r')) {
            continue;
        }

        const parsed = try Header.parse(text);
        if (parsed) |header| {
            try headers.append(header);
        }
    }

    return Request{
        .alloc = alloc,
        .uri = uri,
        .method = method,
        .version = version,
        .headers = try headers.toOwnedSlice(),
    };
}
