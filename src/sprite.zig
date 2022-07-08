pub const Sprite = struct {
    x: f32,
    y: f32,
    texid: usize,
    player_dist: f32,

    pub fn init(x: f32, y: f32, texid: usize) Sprite {
        return Sprite{
            .x = x,
            .y = y,
            .texid = texid,
            .player_dist = 40000,
        };
    }

    pub fn lessThan(_: void, a: Sprite, b: Sprite) bool {
        return b.player_dist < a.player_dist;
    }
};
