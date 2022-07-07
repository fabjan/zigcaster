const std = @import("std");
const fs = std.fs;
const math = std.math;
const mem = std.mem;

const assert = std.debug.assert;

const graphics = @import("./graphics.zig");
const map = @import("./map.zig");

const win_w: usize = 1024;
const win_h: usize = 512;
const rect_w = win_w / (map.width * 2);
const rect_h = win_h / map.height;
const fov: f32 = math.pi / 3.0;
const max_dist: f32 = math.sqrt(2.0 * float(map.width * map.width));
const walltext_size: usize = 64;
const walltext_count: usize = 6;

const grey = graphics.pack_color(160, 160, 160, 255);
const white = graphics.pack_color(255, 255, 255, 255);
const cyan = graphics.pack_color(0, 255, 255, 255);

fn float(n: usize) f32 {
    return @intToFloat(f32, n);
}

fn int(x: f32) i32 {
    return @floatToInt(i32, x);
}

fn size(x: f32) usize {
    return @floatToInt(usize, x);
}

fn byte(x: f32) u8 {
    return @floatToInt(u8, x);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // initialize player
    const player_x: f32 = 3.456;
    const player_y: f32 = 2.345;
    var player_a: f32 = 1.523;

    // initialize textures
    const walltext_file = try fs.cwd().openFile("assets/walltext.ppm", .{});
    defer walltext_file.close();
    var walltext = try allocator.alloc(u32, walltext_count * walltext_size * walltext_size);
    try graphics.slurp_ppm_image(walltext_file.reader(), walltext, walltext_count * walltext_size, walltext_size);

    var framebuffer = try allocator.alloc(u32, win_w * win_h);
    defer allocator.free(framebuffer);

    // clear frame
    for (framebuffer) |_, i| {
        framebuffer[i] = white;
    }

    // draw the game
    draw_map(framebuffer, walltext);
    draw_player(framebuffer, player_x, player_y);
    try draw_view(allocator, framebuffer, walltext, player_x, player_y, player_a);

    // render output
    const imageFile = try fs.cwd().createFile("out_11.ppm", .{});
    defer imageFile.close();
    try graphics.drop_ppm_image(allocator, imageFile.writer(), framebuffer[0..], win_w, win_h);
}

fn draw_map(framebuffer: []u32, walltext: []u32) void {
    var x: usize = 0;
    while (x < map.width) : (x += 1) {
        var y: usize = 0;
        while (y < map.height) : (y += 1) {
            const cell = map.data[x + y * map.width];
            if (cell == ' ') continue;
            const rect_x = x * rect_w;
            const rect_y = y * rect_h;
            const texid = cell - '0';
            graphics.draw_rectangle(framebuffer, win_w, win_h, rect_x, rect_y, rect_w, rect_h, walltext[texid * walltext_size]);
        }
    }
}

fn draw_player(framebuffer: []u32, player_x: f32, player_y: f32) void {
    const px = math.trunc(player_x * float(rect_w));
    const py = math.trunc(player_y * float(rect_h));
    graphics.draw_rectangle(framebuffer, win_w, win_h, size(px), size(py), 5, 5, white);
}

fn draw_view(allocator: mem.Allocator, framebuffer: []u32, walltext: []u32, player_x: f32, player_y: f32, player_a: f32) !void {
    var i: usize = 0;
    while (i < win_w / 2) : (i += 1) {
        const ray_offset = fov * float(i) / float(win_w / 2);
        const angle = player_a - fov / 2 + ray_offset;

        var t: f32 = 0.0;
        while (t < max_dist) : (t += 0.01) {
            const cx = player_x + t * math.cos(angle);
            const cy = player_y + t * math.sin(angle);

            {
                // visibility cone
                const pix_x = size(cx * float(rect_w));
                const pix_y = size(cy * float(rect_h));
                framebuffer[pix_x + pix_y * win_w] = grey;
            }

            // "3D" view
            const cell = map.data[size(cx) + size(cy) * map.width];

            // march through empty space
            if (cell == ' ') {
                continue;
            }

            // if we're still here, we hit something
            const column_height = size(float(win_h) / (t * math.cos(angle - player_a)));
            const texid = cell - '0';
            const hitx: f32 = cx - math.floor(cx + 0.5);
            const hity: f32 = cy - math.floor(cy + 0.5);

            var x_texcoord: i32 = int(hitx * float(walltext_size));
            if (math.fabs(hitx) < math.fabs(hity)) {
                x_texcoord = int(hity * float(walltext_size));
            }
            if (x_texcoord < 0) {
                x_texcoord += walltext_size;
            }
            assert(0 <= x_texcoord and x_texcoord < walltext_size);

            const column = try allocator.alloc(u32, column_height);
            defer allocator.free(column);

            graphics.texture_column(walltext, walltext_size, walltext_count, texid, @intCast(usize, x_texcoord), column);
            var pix_x: usize = win_w / 2 + i;
            var pix_y: usize = 0;
            for (column) |wall_color, j| {
                pix_y = j + win_h / 2 - column_height / 2;
                if (pix_y < 0 or win_h <= pix_y) continue;
                framebuffer[pix_x + pix_y * win_w] = wall_color;
            }

            // we already hit a wall, abort ray
            break;
        }
    }
}
