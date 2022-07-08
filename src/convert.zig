pub fn float(n: usize) f32 {
    return @intToFloat(f32, n);
}

pub fn int(x: anytype) i32 {
    return switch (@TypeOf(x)) {
        f32 => @floatToInt(i32, x),
        usize => @intCast(i32, x),
        else => unreachable,
    };
}

pub fn size(x: anytype) usize {
    return switch (@TypeOf(x)) {
        f32 => @floatToInt(usize, x),
        i32 => @intCast(usize, x),
        else => unreachable,
    };
}

pub fn byte(x: f32) u8 {
    return @floatToInt(u8, x);
}
