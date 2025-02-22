const std = @import("std");
const Request = @import("Request.zig");

const Client = @This();

allocator: std.mem.Allocator,
stream: std.net.Stream,
address: std.net.Address,

open_callback: ?*const fn () void,
close_callback: ?*const fn () void,
message_callback: ?*const fn ([]const u8) void,
error_callback: ?*const fn ([]const u8) void,

pub fn init(allocator: std.mem.Allocator, addr: [4]u8, port: u16) !Client {
    const address = std.net.Address.initIp4(addr, port);
    const stream = try std.net.tcpConnectToAddress(address);
    errdefer stream.close();

    return Client{
        .allocator = allocator,
        .stream = stream,
        .address = address,
        .open_callback = null,
        .close_callback = null,
        .message_callback = null,
        .error_callback = null,
    };
}

pub fn handshake(self: Client) !void {
    const http_handshake = try std.fmt.allocPrint(self.allocator, "GET / HTTP/1.1\r\nHost: {}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n", .{self.address.in});
    defer self.allocator.free(http_handshake);

    _ = try self.stream.write(http_handshake);

    var raw_response: [1024]u8 = undefined;
    @memset(&raw_response, 0);
    _ = self.stream.read(&raw_response) catch |err| {
        if (self.error_callback) |callback| {
            callback(@errorName(err));
        }
        return;
    };

    var response = try Request.parse(self.allocator, &raw_response);
    defer response.deinit();
    std.log.info("data from server: {any}", .{response});
}

pub fn on_open(self: *Client, callback: fn () void) void {
    self.open_callback = callback;
}

pub fn on_close(self: *Client, callback: fn () void) void {
    self.close_callback = callback;
}

pub fn on_message(self: *Client, callback: fn ([]const u8) void) void {
    self.message_callback = callback;
}

pub fn on_error(self: *Client, callback: fn ([]const u8) void) void {
    self.error_callback = callback;
}
