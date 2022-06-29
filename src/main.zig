const std = @import("std");
const fs = std.fs;

const draw = @import("./draw.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const win_w: usize = 512;
    const win_h: usize = 512;

    var framebuffer = try allocator.create([win_w * win_h]u32);

    for (framebuffer) |_, x| {
        const i = x % win_w;
        const j = x / win_h;
        const r = 255.0 * @intToFloat(f32, j) / @intToFloat(f32, win_h);
        const g = 255.0 * @intToFloat(f32, i) / @intToFloat(f32, win_w);
        const b = 0.0;

        framebuffer[x] = draw.pack_color(
            @floatToInt(u8, r),
            @floatToInt(u8, g),
            @floatToInt(u8, b),
            255,
        );
    }

    const imageFile = try fs.cwd().createFile("out.ppm", .{});
    defer imageFile.close();

    try draw.drop_ppm_image(imageFile.writer(), framebuffer[0..], win_w, win_h);
}
