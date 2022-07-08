const std = @import("std");
const mem = std.mem;

const assert = std.debug.assert;

pub const Pixmap = struct {
    allocator: mem.Allocator,
    width: usize,
    height: usize,
    pixels: []u32,
    mask: ?u32,

    pub fn init(allocator: mem.Allocator, width: usize, height: usize) !Pixmap {
        const pixels = try allocator.alloc(u32, width * height);
        return Pixmap{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixels,
            .mask = null,
        };
    }

    pub fn deinit(self: Pixmap) void {
        self.allocator.free(self.pixels);
    }

    pub fn get(self: Pixmap, x: usize, y: usize) u32 {
        const i = x + y * self.width;
        assert(i < self.pixels.len);

        return self.pixels[i];
    }

    pub fn put(self: Pixmap, x: usize, y: usize, color: u32) void {
        const i = x + y * self.width;
        assert(i < self.pixels.len);

        self.pixels[i] = color;
    }

    pub fn fill(self: Pixmap, color: u32) void {
        for (self.pixels) |_, i| {
            self.pixels[i] = color;
        }
    }

    pub fn fill_rect(self: Pixmap, x: usize, y: usize, w: usize, h: usize, color: u32) void {
        assert(x + w <= self.width);
        assert(y + h <= self.height);

        var i: usize = 0;
        while (i < w) : (i += 1) {
            var j: usize = 0;
            while (j < h) : (j += 1) {
                const cx = x + i;
                const cy = y + j;
                self.pixels[cx + cy * self.width] = color;
            }
        }
    }

    pub fn texture_column(self: Pixmap, atlas: Pixmap, texid: usize, xoffset: usize) void {
        const texsize = atlas.height;
        const ntextures = atlas.width / texsize;

        assert(xoffset < texsize and texid < ntextures);

        const tex_x = texid * texsize + xoffset;

        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            const tex_y = (y * texsize) / self.height;
            const color = atlas.get(tex_x, tex_y);
            self.put(0, y, color);
        }
    }
};
