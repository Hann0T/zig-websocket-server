const std = @import("std");
const assert = std.debug.assert;
const Request = @import("request.zig");

pub fn main() !void {
    // use Arena allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 3000);
    //const socket = try std.posix.socket(address.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
    var server = try address.listen(.{ .reuse_port = true });

    std.log.info("Server started: {any}\n", .{address});

    var connection = try server.accept();
    defer connection.stream.close();

    //const reader = connection.stream.reader();

    const buff = try allocator.alloc(u8, 1024);
    defer allocator.free(buff);
    @memset(buff, 0);

    _ = try connection.stream.read(buff);

    var request = try Request.parse(allocator, buff);
    defer request.deinit();

    std.debug.print("Request: \n", .{});
    std.debug.print("method: {any}\n", .{request.method});
    std.debug.print("uri: {s}\n", .{request.uri});
    std.debug.print("version: {s}\n", .{request.version});

    std.debug.print("Headers: \n", .{});
    for (request.headers) |header| {
        std.debug.print("{s} : {s}\n", .{ header.key, header.value });
    }

    if (request.header_get("Sec-WebSocket-Key")) |key| {
        try upgrade_protocol(connection, key);
    }

    //std.debug.print("\n", .{});
    var buffer: [4096]u8 = undefined;
    @memset(&buffer, 0);
    std.log.info("waiting for messages..\n", .{});

    // Can't get to work this
    while (true) {
        const bytes = try connection.stream.read(&buffer);
        std.log.info("Read {d} bytes\n", .{bytes});

        if (bytes <= 0) {
            std.log.info("No data received or connection closed\n", .{});
            break;
        }

        std.log.info("Raw Data: {any}\n", .{buffer[0..bytes]});
    }
}

fn upgrade_protocol(connection: std.net.Server.Connection, key: []const u8) !void {
    var buf = [_]u8{ 'H', 'T', 'T', 'P', '/', '1', '.', '1', ' ', '1', '0', '1', ' ', 'S', 'w', 'i', 't', 'c', 'h', 'i', 'n', 'g', ' ', 'P', 'r', 'o', 't', 'o', 'c', 'o', 'l', 's', '\r', '\n', 'U', 'p', 'g', 'r', 'a', 'd', 'e', ':', ' ', 'w', 'e', 'b', 's', 'o', 'c', 'k', 'e', 't', '\r', '\n', 'C', 'o', 'n', 'n', 'e', 'c', 't', 'i', 'o', 'n', ':', ' ', 'U', 'p', 'g', 'r', 'a', 'd', 'e', '\r', '\n', 'S', 'e', 'c', '-', 'W', 'e', 'b', 'S', 'o', 'c', 'k', 'e', 't', '-', 'A', 'c', 'c', 'e', 'p', 't', ':', ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '\r', '\n', '\r', '\n' };
    const key_pos = buf.len - 32;

    var h: [20]u8 = undefined;
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(key);
    hasher.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    hasher.final(&h);

    _ = std.base64.standard.Encoder.encode(buf[key_pos .. key_pos + 28], h[0..]);
    const writer = connection.stream.writer();
    _ = try writer.write(&buf);
}

//fn send_frame() void {
//    std.log.info("Sending frame..", .{});
//}

fn send_frame(connection: std.net.Server.Connection, allocator: std.mem.Allocator, message: []const u8) !void {
    const frame_size = 2 + message.len;
    var frame = try allocator.alloc(u8, frame_size);
    defer allocator.free(frame);

    frame[0] = 0x81; // FIN + Text Frame (Opcode: 0x1)
    frame[1] = @intCast(message.len); // Payload length (assuming it's < 126 bytes)
    @memcpy(frame[2..], message);

    const writer = connection.stream.writer();
    _ = try writer.write(frame);
}
