pub const Sprite = struct {
    x: f32,
    y: f32,
    texid: usize,

    pub fn init(x: f32, y: f32, texid: usize) Sprite {
        return Sprite{
            .x = x,
            .y = y,
            .texid = texid,
        };
    }
};
