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

    const win_w: usize = 1024;
    const win_h: usize = 512;
    const grey = graphics.pack_color(160, 160, 160, 255);
    const white = graphics.pack_color(255, 255, 255, 255);
    const cyan = graphics.pack_color(0, 255, 255, 255);

    var framebuffer = try allocator.create([win_w * win_h]u32);

    // consts for now
    const player_x: f32 = 3.456;
    const player_y: f32 = 2.345;
    const player_a: f32 = 1.523;
    const fov: f32 = math.pi / 3.0;
    const max_dist: f32 = math.sqrt(2.0 * float(map.width * map.width));

    // fill background
    for (framebuffer) |_, i| {
        framebuffer[i] = white;
    }

    const rect_w = win_w / (map.width * 2);
    const rect_h = win_h / map.height;

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
    var i: usize = 0;
    while (i < win_w / 2) : (i += 1) {
        const ray_offset = fov * float(i) / float(win_w / 2);
        const angle = player_a - fov / 2 + ray_offset;

        var t: f32 = 0.0;
        while (t < max_dist) : (t += 0.05) {
            const cx = player_x + t * math.cos(angle);
            const cy = player_y + t * math.sin(angle);

            // visibility cone
            const pix_x = int(cx * float(rect_w));
            const pix_y = int(cy * float(rect_h));
            framebuffer[pix_x + pix_y * win_w] = grey;

            // "3D" view
            if (map.data[int(cx) + int(cy) * map.width] != ' ') {
                const column_height = int(float(win_h) / t);
                graphics.draw_rectangle(
                    framebuffer, win_w, win_h,
                    win_w / 2 + i, win_h / 2 - column_height / 2,
                    1, column_height,
                    cyan
                );
                break;
            }
        }
    }

    // render output
    const imageFile = try fs.cwd().createFile("out_6.ppm", .{});
    defer imageFile.close();
    try graphics.drop_ppm_image(imageFile.writer(), framebuffer[0..], win_w, win_h);
}
