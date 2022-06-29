const std = @import("std");
const mem = std.mem;

const assert = std.debug.assert;

/// Pack the given color components in one integer value.
/// 
pub fn pack_color(r: u8, g: u8, b: u8, a: u8) u32 {
    const buf = [4]u8{ r, g, b, a };
    const color = mem.bytesToValue(u32, &buf);
    return mem.bigToNative(u32, color);
}

pub fn unpack_color(color: u32) [4]u8 {
    const tmp = mem.nativeToBig(u32, color);
    return mem.toBytes(tmp);
}

pub fn drop_ppm_image(writer: anytype, image: []u32, w: usize, h: usize) anyerror!void {
    assert(image.len == w * h);

    try writer.print("P6\n{} {}\n255\n", .{ w, h });

    for (image) |color| {
        const pixel = unpack_color(color);
        try writer.writeAll(pixel[0..3]);
    }
}

test "can unpack black" {
    const zero: u8 = 0;
    const pixel = unpack_color(0x00000000);
    try std.testing.expectEqual(zero, pixel[0]);
    try std.testing.expectEqual(zero, pixel[1]);
    try std.testing.expectEqual(zero, pixel[2]);
    try std.testing.expectEqual(zero, pixel[3]);
}

test "can pack white" {
    const color = pack_color(255, 255, 255, 255);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), color);
}

test "can pack red" {
    const color = pack_color(255, 0, 0, 255);
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), color);
}

test "can pack salmon" {
    const color = pack_color(0xFA, 0x80, 0x72, 0xFF);
    try std.testing.expectEqual(@as(u32, 0xFA8072FF), color);
}

test "can unpack salmon" {
    const pixel = unpack_color(0xFA8072FF);
    try std.testing.expectEqual(@as(u8, 0xFA), pixel[0]);
    try std.testing.expectEqual(@as(u8, 0x80), pixel[1]);
    try std.testing.expectEqual(@as(u8, 0x72), pixel[2]);
    try std.testing.expectEqual(@as(u8, 0xFF), pixel[3]);
}
