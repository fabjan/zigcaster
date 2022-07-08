const std = @import("std");
const fs = std.fs;
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

const convert = @import("./convert.zig");
const graphics = @import("./graphics.zig");
const map = @import("./map.zig");
const Pixmap = @import("./pixmap.zig").Pixmap;
const Player = @import("./player.zig").Player;

const byte = convert.byte;
const float = convert.float;
const int = convert.int;
const size = convert.size;

const win_w: usize = 1024;
const win_h: usize = 512;
const tile_w = win_w / (map.width * 2);
const tile_h = win_h / map.height;
const max_dist: f32 = math.sqrt(2.0 * float(map.width * map.width));
const walltext_size: usize = 64;
const walltext_count: usize = 6;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // initialize player
    const player = Player.init(3.456, 2.345, 1.523, math.pi / 3.0);

    // initialize resources
    var window = try Pixmap.init(allocator, win_w, win_h);
    defer window.deinit();

    var walltext = try Pixmap.init(allocator, walltext_count * walltext_size, walltext_size);
    defer walltext.deinit();

    const walltext_file = try fs.cwd().openFile("assets/walltext.ppm", .{});
    defer walltext_file.close();

    // load textures
    try graphics.slurp_ppm_image(walltext_file.reader(), walltext);

    try render(allocator, window, player, walltext);

    // save output
    const imageFile = try fs.cwd().createFile("out_12.ppm", .{});
    defer imageFile.close();
    try graphics.drop_ppm_image(allocator, imageFile.writer(), window);
}

fn render(allocator: mem.Allocator, window: Pixmap, player: Player, walltext: Pixmap) !void {
    window.fill(graphics.pack_color(255, 255, 255, 255));
    draw_map(window, walltext);
    draw_player(window, player);
    try draw_view(allocator, window, walltext, player);
}

fn draw_map(window: Pixmap, walltext: Pixmap) void {
    var x: usize = 0;
    while (x < map.width) : (x += 1) {
        var y: usize = 0;
        while (y < map.height) : (y += 1) {
            const cell = map.data[x + y * map.width];
            if (cell == ' ') continue;
            const rect_x = x * tile_w;
            const rect_y = y * tile_h;
            const texid = cell - '0';
            const color = walltext.pixels[texid * walltext_size];
            window.fill_rect(rect_x, rect_y, tile_w, tile_h, color);
        }
    }
}

fn draw_player(window: Pixmap, player: Player) void {
    const px = math.trunc(player.x * float(tile_w));
    const py = math.trunc(player.y * float(tile_h));
    window.fill_rect(size(px), size(py), 5, 5, graphics.pack_color(255, 255, 255, 255));
}

fn draw_view(allocator: mem.Allocator, window: Pixmap, walltext: Pixmap, player: Player) !void {
    var i: usize = 0;
    fov_sweep: while (i < win_w / 2) : (i += 1) {
        const ray_offset = player.fov * float(i) / float(win_w / 2);
        const angle = player.a - player.fov / 2 + ray_offset;

        var t: f32 = 0.0;
        ray_march: while (t < max_dist) : (t += 0.01) {
            const cx = player.x + t * math.cos(angle);
            const cy = player.y + t * math.sin(angle);

            // visibility cone
            {
                const pix_x = size(cx * float(tile_w));
                const pix_y = size(cy * float(tile_h));
                window.put(pix_x, pix_y, graphics.pack_color(160, 160, 160, 255));
            }

            const cell = map.data[size(cx) + size(cy) * map.width];
            // march through empty space
            if (cell == ' ') {
                continue :ray_march;
            }

            // if we're still here, we hit something
            const column_height = size(float(win_h) / (t * math.cos(angle - player.a)));
            const texid = cell - '0';

            // the loop below assumes wall_strip has width 1
            const wall_strip = try Pixmap.init(allocator, 1, column_height);
            defer wall_strip.deinit();

            const xoffset = wall_x_texcoord(cx, cy, walltext_size);
            wall_strip.texture_column(walltext, texid, xoffset);

            // assumes wall_strip has width 1
            wall_render: for (wall_strip.pixels) |wall_color, j| {
                const pix_x = win_w / 2 + i;
                const pix_y = j + win_h / 2 - column_height / 2;

                if (pix_y < 0) continue :wall_render;

                if (win_h <= pix_y) continue :ray_march;

                window.put(pix_x, pix_y, wall_color);
            }

            // we already rendered the wall, abort ray
            continue :fov_sweep;
        }
    }
}

fn wall_x_texcoord(x: f32, y: f32, texsize: usize) usize {
    const hitx: f32 = x - math.floor(x + 0.5);
    const hity: f32 = y - math.floor(y + 0.5);

    var x_texcoord: i32 = int(hitx * float(texsize));

    // for north-south walls, the x coord depends on the world y coord
    if (math.fabs(hitx) < math.fabs(hity)) {
        x_texcoord = int(hity * float(texsize));
    }

    // wrap around negative coords
    if (x_texcoord < 0) {
        x_texcoord += @intCast(i32, texsize);
    }

    assert(0 <= x_texcoord and x_texcoord < texsize);

    return @intCast(usize, x_texcoord);
}
