const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;

const assert = std.debug.assert;

pub fn draw_rectangle(image: []u32, img_w: usize, img_h: usize, x: usize, y: usize, w: usize, h: usize, color: u32) void {
    assert(image.len == img_w * img_h);
    assert(x + w <= img_w);
    assert(y + h <= img_h);

    var i: usize = 0;
    while (i < w) : (i += 1) {
        var j: usize = 0;
        while (j < h) : (j += 1) {
            const cx = x + i;
            const cy = y + j;
            image[cx + cy * img_w] = color;
        }
    }
}

pub fn texture_column(atlas: []u32, texsize: usize, ntextures: usize, texid: usize, texcoord: usize, column: []u32) void {
    const atlas_w: usize = texsize * ntextures;
    const atlas_h: usize = texsize;
    assert(atlas.len == atlas_w * atlas_h and texcoord < texsize and texid < ntextures);

    var y: usize = 0;
    while (y < column.len) : (y += 1) {
        const pix_x: usize = texid * texsize + texcoord;
        const pix_y: usize = (y * texsize) / column.len;
        column[y] = atlas[pix_x + pix_y * atlas_w];
    }
}

pub fn pack_color(r: u8, g: u8, b: u8, a: u8) u32 {
    const buf = [4]u8{ r, g, b, a };
    const color = mem.bytesToValue(u32, &buf);
    return mem.bigToNative(u32, color);
}

pub fn unpack_color(color: u32) [4]u8 {
    const tmp = mem.nativeToBig(u32, color);
    return mem.toBytes(tmp);
}

pub fn drop_ppm_image(allocator: mem.Allocator, writer: anytype, image: []u32, w: usize, h: usize) !void {
    assert(image.len == w * h);

    try writer.print("P6\n{} {}\n255\n", .{ w, h });

    var rgbBytes = try allocator.alloc(u8, 3 * image.len);
    defer allocator.free(rgbBytes);

    for (image) |color, i| {
        const pixel = unpack_color(color);
        mem.copy(u8, rgbBytes[(i * 3)..], pixel[0..3]);
    }

    try writer.writeAll(rgbBytes);
}

pub fn slurp_ppm_image(reader: anytype, image: []u32, w: usize, h: usize) !void {
    assert(image.len == w * h);

    // assert netpbm variant
    assert('P' == try reader.readByte());
    assert('6' == try reader.readByte());
    assert('\n' == try reader.readByte());

    // read size header
    var wbuf = [4]u8{ 0, 0, 0, 0 };
    var hbuf = [4]u8{ 0, 0, 0, 0 };
    const width = try reader.readUntilDelimiter(wbuf[0..], ' ');
    const height = try reader.readUntilDelimiter(hbuf[0..], '\n');

    // assert color header
    assert('2' == try reader.readByte());
    assert('5' == try reader.readByte());
    assert('5' == try reader.readByte());
    assert('\n' == try reader.readByte());

    // header reading is complete, let's parse the data
    assert(w == try fmt.parseUnsigned(usize, width, 10));
    assert(h == try fmt.parseUnsigned(usize, height, 10));

    var i: usize = 0;
    while (i < w * h) : (i += 1) {
        const r = try reader.readByte();
        const g = try reader.readByte();
        const b = try reader.readByte();
        image[i] = pack_color(r, g, b, 255);
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
