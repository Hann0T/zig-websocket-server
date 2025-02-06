const std = @import("std");
const Map = std.static_string_map.StaticStringMap;

pub const Method = enum {
    GET,
    pub fn init(text: []const u8) !Method {
        return MethodMap.get(text).?;
    }
    pub fn is_supported(m: []const u8) bool {
        const method = MethodMap.get(m);
        if (method) |_| {
            return true;
        }
        return false;
    }
};

const MethodMap = Map(Method).initComptime(.{
    .{ "GET", Method.GET },
});
