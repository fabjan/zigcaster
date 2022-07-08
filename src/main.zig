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
const Sprite = @import("./sprite.zig").Sprite;

const byte = convert.byte;
const float = convert.float;
const int = convert.int;
const size = convert.size;

const win_w: usize = 1024;
const win_h: usize = 512;
const tile_w = win_w / (map.width * 2);
const tile_h = win_h / map.height;
const max_dist: f32 = math.sqrt(2.0 * float(map.width * map.width));

const Resources = struct {
    allocator: mem.Allocator,
    window: Pixmap,
    walltext: Pixmap,
    monstertext: Pixmap,
    zbuffer: []f32,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // initialize resources
    var window = try Pixmap.init(allocator, win_w, win_h);
    defer window.deinit();

    var walltext = try Pixmap.init(allocator, 6 * 64, 64);
    defer walltext.deinit();

    var monstertext = try Pixmap.init(allocator, 4 * 64, 64);
    defer monstertext.deinit();

    const walltext_file = try fs.cwd().openFile("assets/walltext.ppm", .{});
    defer walltext_file.close();

    const monstertext_file = try fs.cwd().openFile("assets/monsters.ppm", .{});
    defer monstertext_file.close();

    // load textures
    try graphics.slurp_ppm_image(walltext_file.reader(), &walltext, false);
    try graphics.slurp_ppm_image(monstertext_file.reader(), &monstertext, true);

    var zbuffer = try allocator.alloc(f32, 512);
    defer allocator.free(zbuffer);

    var resources = Resources{
        .allocator = allocator,
        .window = window,
        .walltext = walltext,
        .monstertext = monstertext,
        .zbuffer = zbuffer,
    };

    // initialize the game
    var player = Player.init(3.456, 2.345, 1.523, math.pi / 3.0);
    var sprites = ([_]Sprite{
        Sprite.init(3.123, 5.112, 2),
        Sprite.init(1.834, 8.765, 0),
        Sprite.init(5.323, 5.365, 1),
        Sprite.init(4.123, 10.265, 1),
    })[0..];

    // play the game
    update_sprites(player, sprites);

    // render the game
    try render(resources, player, sprites);

    const imageFile = try fs.cwd().createFile("out_16.ppm", .{});
    defer imageFile.close();

    try graphics.drop_ppm_image(allocator, imageFile.writer(), window);
}

fn render(resources: Resources, player: Player, sprites: []Sprite) !void {
    resources.window.fill(graphics.pack_color(255, 255, 255, 255));
    for (resources.zbuffer) |_, x| {
        resources.zbuffer[x] = 10000;
    }

    try draw_view(resources, player, sprites);
    draw_map(resources, player, sprites);
}

fn draw_map(resources: Resources, player: Player, sprites: []Sprite) void {
    const window = resources.window;
    const walltext = resources.walltext;

    var x: usize = 0;
    while (x < map.width) : (x += 1) {
        var y: usize = 0;
        while (y < map.height) : (y += 1) {
            const cell = map.data[x + y * map.width];
            if (cell == ' ') continue;
            const rect_x = x * tile_w;
            const rect_y = y * tile_h;
            const texid = cell - '0';
            const color = walltext.pixels[texid * walltext.height];
            window.fill_rect(rect_x, rect_y, tile_w, tile_h, color);
        }
    }

    const px = math.trunc(player.x * float(tile_w));
    const py = math.trunc(player.y * float(tile_h));
    window.fill_rect(size(px) - 2, size(py) - 2, 5, 5, graphics.pack_color(2, 200, 20, 255));

    for (sprites) |sprite| {
        const sx = math.trunc(sprite.x * float(tile_w));
        const sy = math.trunc(sprite.y * float(tile_h));
        window.fill_rect(size(sx) - 2, size(sy) - 2, 5, 5, graphics.pack_color(255, 0, 0, 255));
    }
}

fn draw_view(resources: Resources, player: Player, sprites: []Sprite) !void {
    const window = resources.window;
    const walltext = resources.walltext;

    var i: usize = 0;
    fov_sweep: while (i < win_w / 2) : (i += 1) {
        const ray_offset = player.fov * float(i) / float(win_w / 2);
        const angle = player.a - player.fov / 2 + ray_offset;

        var t: f32 = 0.0;
        ray_march: while (t < max_dist) : (t += 0.01) {
            const ray_x = player.x + t * math.cos(angle);
            const ray_y = player.y + t * math.sin(angle);

            // visibility cone
            {
                const pix_x = size(ray_x * float(tile_w));
                const pix_y = size(ray_y * float(tile_h));
                window.put(pix_x, pix_y, graphics.pack_color(160, 160, 160, 255));
            }

            const cell = map.data[size(ray_x) + size(ray_y) * map.width];
            // march through empty space
            if (cell == ' ') {
                continue :ray_march;
            }

            // if we're still here, we hit something
            const z = (t * math.cos(angle - player.a));
            const column_height = size(float(win_h) / z);
            const texid = cell - '0';

            resources.zbuffer[i] = z;

            // the loop below assumes wall_strip has width 1
            const wall_strip = try Pixmap.init(resources.allocator, 1, column_height);
            defer wall_strip.deinit();

            const xoffset = wall_x_texcoord(ray_x, ray_y, walltext.height);
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

    for (sprites) |sprite| {
        draw_sprite(resources, player, sprite);
    }
}

fn update_sprites(player: Player, sprites: []Sprite) void {
    var s: usize = 0;
    while (s < sprites.len) : (s += 1) {
        var sprite = &sprites[s];
        sprite.player_dist = math.sqrt(math.pow(f32, player.x - sprite.x, 2) + math.pow(f32, player.y - sprite.y, 2));
    }

    std.sort.sort(Sprite, sprites, {}, Sprite.lessThan);
}

fn draw_sprite(resources: Resources, player: Player, sprite: Sprite) void {
    const window = resources.window;
    const monstertext = resources.monstertext;
    const view_width: usize = window.width / 2;
    const view_height: usize = window.height;

    var sprite_dir: f32 = math.atan2(f32, sprite.y - player.y, sprite.x - player.x);
    while (math.pi < sprite_dir - player.a) {
        sprite_dir -= 2 * math.pi;
    }
    while (sprite_dir - player.a < -math.pi) {
        sprite_dir += 2 * math.pi;
    }

    const sprite_screen_size: usize = math.min(2000, view_height / size(sprite.player_dist));

    const h_offset: i32 = int((sprite_dir - player.a) * float(view_width) / player.fov +
        float(view_width) / 2 - float(sprite_screen_size) / 2);
    const v_offset: i32 = int(view_height / 2 - sprite_screen_size / 2);

    var i: i32 = 0;
    while (i < sprite_screen_size) : (i += 1) {
        if (h_offset + i < 0 or view_width <= h_offset + i) continue;
        if (resources.zbuffer[size(h_offset + i)] < sprite.player_dist) continue;
        var j: i32 = 0;
        while (j < sprite_screen_size) : (j += 1) {
            if (v_offset + j < 0 or view_height <= v_offset + j) continue;
            const u = float(i) / float(sprite_screen_size);
            const v = float(j) / float(sprite_screen_size);
            const text_x = sprite.texid * monstertext.height + size(u * float(monstertext.height));
            const text_y = size(v * float(monstertext.height));
            const color = monstertext.get(text_x, text_y);
            const screen_x: usize = view_width + size(h_offset + i);
            const screen_y: usize = size(v_offset + j);
            if (color != monstertext.mask) {
                window.put(screen_x, screen_y, color);
            }
        }
    }
}

fn wall_x_texcoord(hitx: f32, hity: f32, texsize: usize) usize {
    const x: f32 = hitx - math.floor(hitx + 0.5);
    const y: f32 = hity - math.floor(hity + 0.5);

    var x_texcoord: i32 = int(x * float(texsize));

    // for north-south walls, the x coord depends on the world y coord
    if (math.fabs(x) < math.fabs(y)) {
        x_texcoord = int(y * float(texsize));
    }

    // wrap around negative coords
    if (x_texcoord < 0) {
        x_texcoord += int(texsize);
    }

    assert(0 <= x_texcoord and x_texcoord < texsize);

    return size(x_texcoord);
}
