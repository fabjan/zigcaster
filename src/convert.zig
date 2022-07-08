pub fn float(n: usize) f32 {
    return @intToFloat(f32, n);
}

pub fn int(x: f32) i32 {
    return @floatToInt(i32, x);
}

pub fn size(x: f32) usize {
    return @floatToInt(usize, x);
}

pub fn byte(x: f32) u8 {
    return @floatToInt(u8, x);
}
