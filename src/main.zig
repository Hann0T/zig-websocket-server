const std = @import("std");
const assert = std.debug.assert;
const Server = @import("Server.zig");
const Client = @import("Client.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // binary name
    _ = args.next().?;

    if (args.next()) |arg| {
        if (!std.mem.startsWith(u8, arg, "--")) {
            std.log.err("Invalid param", .{});
            return;
        }

        const mode = arg[2..];

        if (std.mem.eql(u8, mode, "server")) {
            var server = try Server.init(allocator, .{ 127, 0, 0, 1 }, 3000);
            std.log.info("Listen to: {any}", .{server.server.listen_address});
            try server.listen();
            return;
        }

        if (std.mem.eql(u8, mode, "client")) {
            var client = try Client.init(allocator, .{ 127, 0, 0, 1 }, 3000);

            client.on_open(on_open);
            client.on_message(on_message);
            client.on_close(on_close);
            client.on_error(on_error);

            try client.handshake();
            return;
        }

        std.log.err("Invalid mode", .{});
        return;
    }
}

fn on_open() void {
    std.log.info("connection open", .{});
}

fn on_close() void {
    std.log.info("connection was closed", .{});
}

fn on_message(message: []const u8) void {
    std.log.info("new message {s}", .{message});
}

fn on_error(err: []const u8) void {
    std.log.err("new error: {s}", .{err});
}
