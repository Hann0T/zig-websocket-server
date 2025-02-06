const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;
const Request = @import("request.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const socket_flags: u16 = posix.SOCK.STREAM;
    // socket_flags |= posix.SOCK.NONBLOCK;
    // socket_flags |= posix.SOCK.CLOEXEC;
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000);

    const server_socket = try posix.socket(address.any.family, socket_flags, posix.IPPROTO.TCP);
    defer posix.close(server_socket);

    try posix.setsockopt(server_socket, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(server_socket, &address.any, address.getOsSockLen());
    try posix.listen(server_socket, 1024);

    std.log.info("listening to {any}", .{address});

    var client_address: std.net.Address = undefined;
    var client_address_len: posix.socklen_t = @sizeOf(std.net.Address);
    const client_socket = try posix.accept(server_socket, &client_address.any, &client_address_len, 0);
    defer posix.close(client_socket);

    var buf: [1024]u8 = undefined;
    @memset(&buf, 0);
    _ = try posix.read(client_socket, &buf);

    var request = try Request.parse(allocator, &buf);
    defer request.deinit();

    if (request.header_get("Sec-WebSocket-Key")) |key| {
        try upgrade_protocol(client_socket, key);
    }

    //while (true) {
    var buffer: [1024]u8 = undefined;
    @memset(&buffer, 0);
    const timeout = posix.timeval{ .tv_sec = 2, .tv_usec = 500_000 };

    try posix.setsockopt(client_socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));
    try posix.setsockopt(client_socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

    const bytes = try posix.read(client_socket, &buffer);
    if (bytes <= 0) {
        std.log.info("No message or connection closed", .{});
        //break;
    }
    std.log.info("bytes read: {d}", .{bytes});
    //}
}

fn upgrade_protocol(fd: posix.socket_t, key: []const u8) !void {
    var buf = [_]u8{ 'H', 'T', 'T', 'P', '/', '1', '.', '1', ' ', '1', '0', '1', ' ', 'S', 'w', 'i', 't', 'c', 'h', 'i', 'n', 'g', ' ', 'P', 'r', 'o', 't', 'o', 'c', 'o', 'l', 's', '\r', '\n', 'U', 'p', 'g', 'r', 'a', 'd', 'e', ':', ' ', 'w', 'e', 'b', 's', 'o', 'c', 'k', 'e', 't', '\r', '\n', 'C', 'o', 'n', 'n', 'e', 'c', 't', 'i', 'o', 'n', ':', ' ', 'U', 'p', 'g', 'r', 'a', 'd', 'e', '\r', '\n', 'S', 'e', 'c', '-', 'W', 'e', 'b', 'S', 'o', 'c', 'k', 'e', 't', '-', 'A', 'c', 'c', 'e', 'p', 't', ':', ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '\r', '\n', '\r', '\n' };
    const key_pos = buf.len - 32;

    var h: [20]u8 = undefined;
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(key);
    hasher.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    hasher.final(&h);

    _ = std.base64.standard.Encoder.encode(buf[key_pos .. key_pos + 28], h[0..]);
    _ = try posix.write(fd, &buf);
}
