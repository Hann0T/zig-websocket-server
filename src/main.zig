const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;
const Request = @import("request.zig");

const MessageType = enum {
    ContinuationFrame,
    TextFrame,
    BinaryFrame,
    ConnectionClose,
    Ping,
    Pong,
    NonControl,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const socket_flags: u16 = posix.SOCK.STREAM;
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
        std.log.info("Upgrading Protocol", .{});
        try upgrade_protocol(client_socket, key);
    }

    var buffer: [2048]u8 = undefined;
    @memset(&buffer, 0);
    std.log.info("Waiting for a message from the client\n", .{});

    while (true) {
        const bytes = try posix.read(client_socket, buffer[0..]);
        if (bytes == 0) {
            std.log.info("No message or connection closed", .{});
            break;
        }
        if (bytes < 2) {
            std.log.info("Invalid websocket message", .{});
            continue;
        }
        std.log.info("", .{});
        std.log.info("NEW FRAME", .{});

        const first_byte = buffer[0];
        const second_byte = buffer[1];
        const fin = (first_byte & 128) == 128;
        // const fin = (first_byte >> 7 & 1) == 1;

        const rsv1 = (first_byte & 64) == 64;
        const rsv2 = (first_byte & 32) == 32;
        const rsv3 = (first_byte & 16) == 16;
        if (rsv1 or rsv2 or rsv3) {
            std.log.info("Invalid, no extension was negotiated!", .{});
            break;
        }

        const opcode = first_byte & 15;

        const message_type: MessageType = switch (opcode) {
            0 => .ContinuationFrame,
            1 => .TextFrame,
            2 => .BinaryFrame,
            8 => .ConnectionClose,
            9 => .Ping,
            10 => .Pong,
            else => .NonControl,
        };

        const is_masked = (second_byte & 128) == 128;
        if (!is_masked) {
            std.log.info("Client didn't mask the payload data", .{});
            continue;
        }

        const payload_len = second_byte & 127;
        const extended_payload_len: u16 = switch (payload_len) {
            126 => 2, // 2 bytes
            127 => 8, // 4 bytes
            else => 0,
        };
        const message_len = switch (extended_payload_len) {
            2 => @as(u16, buffer[3]) | (@as(u16, buffer[2]) << 8),
            8 => (@as(u64, buffer[2]) << 56) | (@as(u64, buffer[3]) << 48) | (@as(u64, buffer[4]) << 40) | (@as(u64, buffer[5]) << 32) | (@as(u64, buffer[6]) << 24) | (@as(u64, buffer[7]) << 16) | (@as(u64, buffer[8]) << 8) | (@as(u64, buffer[9])),
            else => payload_len,
        };

        const masking_key = switch (extended_payload_len) {
            2 => buffer[4..8],
            8 => buffer[10..14],
            else => buffer[2..6],
        };

        const payload_data_encoded = switch (extended_payload_len) {
            2 => buffer[8 .. 8 + message_len],
            8 => buffer[14 .. 14 + message_len],
            else => buffer[6 .. 6 + message_len],
        };

        std.log.info("FIN: {any}", .{fin});
        std.log.info("bytes: {d}", .{bytes});
        std.log.info("frame type: {any}", .{message_type});
        std.log.info("is_masked: {any}", .{is_masked});
        std.log.info("message len: {d}", .{message_len});
        std.log.info("masking_key: {any}", .{masking_key});
        std.log.info("payload_data_encoded: {any}", .{payload_data_encoded.len});

        var decoded_data: [1024]u8 = undefined;

        for (payload_data_encoded, 0..) |byte, i| {
            decoded_data[i] = byte ^ masking_key[i % 4];
        }
        std.log.info("decoded data: {s}", .{decoded_data});
    }
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

    const bytes = try posix.write(fd, &buf);
    _ = bytes;
    // std.log.info("bytes wroten : {d}", .{bytes});
    // std.log.info("buf len      : {d}", .{buf.len});
}
