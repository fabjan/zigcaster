const std = @import("std");
const fs = std.fs;

const graphics = @import("./graphics.zig");
const map = @import("./map.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const win_w: usize = 512;
    const win_h: usize = 512;

    var framebuffer = try allocator.create([win_w * win_h]u32);

    // draw backdrop gradient
    for (framebuffer) |_, x| {
        const i = x % win_w;
        const j = x / win_h;
        const r = 255.0 * @intToFloat(f32, j) / @intToFloat(f32, win_h);
        const g = 255.0 * @intToFloat(f32, i) / @intToFloat(f32, win_w);
        const b = 0.0;

        framebuffer[x] = graphics.pack_color(
            @floatToInt(u8, r),
            @floatToInt(u8, g),
            @floatToInt(u8, b),
            255,
        );
    }

    // draw map walls
    {
        const rect_w = win_w / map.width;
        const rect_h = win_h / map.height;
        const cyan = graphics.pack_color(0, 255, 255, 255);

        var x: usize = 0;
        while (x < map.width) : (x += 1) {
            var y: usize = 0;
            while (y < map.height) : (y += 1) {
                if (map.data[x + y * map.width] == ' ') continue;
                const rect_x = x * rect_w;
                const rect_y = y * rect_h;
                graphics.draw_rectangle(framebuffer, win_w, win_h, rect_x, rect_y, rect_w, rect_h, cyan);
            }
        }
    }

    const imageFile = try fs.cwd().createFile("out_2.ppm", .{});
    defer imageFile.close();

    try graphics.drop_ppm_image(imageFile.writer(), framebuffer[0..], win_w, win_h);
}
