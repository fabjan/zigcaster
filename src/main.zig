const std = @import("std");
const fs = std.fs;
const math = std.math;

const graphics = @import("./graphics.zig");
const map = @import("./map.zig");

fn float(n: usize) f32 {
    return @intToFloat(f32, n);
}

fn int(x: f32) usize {
    return @floatToInt(usize, x);
}

fn byte(x: f32) u8 {
    return @floatToInt(u8, x);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const win_w: usize = 512;
    const win_h: usize = 512;

    var framebuffer = try allocator.create([win_w * win_h]u32);

    // consts for now
    const player_x: f32 = 3.456;
    const player_y: f32 = 2.345;
    const player_a: f32 = 1.523;

    // draw backdrop gradient
    for (framebuffer) |_, x| {
        const i = x % win_w;
        const j = x / win_h;
        const r = 255.0 * float(j) / float(win_h);
        const g = 255.0 * float(i) / float(win_w);
        const b = 0.0;

        framebuffer[x] = graphics.pack_color(byte(r), byte(g), byte(b), 255);
    }

    const rect_w = win_w / map.width;
    const rect_h = win_h / map.height;
    const cyan = graphics.pack_color(0, 255, 255, 255);
    const white = graphics.pack_color(255, 255, 255, 255);

    // draw map walls
    {
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

    // draw the player
    const px = math.trunc(player_x * float(rect_w));
    const py = math.trunc(player_y * float(rect_h));
    graphics.draw_rectangle(framebuffer, win_w, win_h, int(px), int(py), 5, 5, white);

    // camera calculations
    var c: f32 = 0.0;
    while (c < 20.0) : (c += 0.05) {
        const cx = player_x + c * math.cos(player_a);
        const cy = player_y + c * math.sin(player_a);
        if (map.data[int(cx) + int(cy) * map.width] != ' ') break;

        const pix_x = int(cx * float(rect_w));
        const pix_y = int(cy * float(rect_h));
        framebuffer[pix_x + pix_y * win_w] = white;
    }

    // render output
    const imageFile = try fs.cwd().createFile("out_4.ppm", .{});
    defer imageFile.close();
    try graphics.drop_ppm_image(imageFile.writer(), framebuffer[0..], win_w, win_h);
}
