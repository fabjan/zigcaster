pub const Player = struct {
    x: f32,
    y: f32,
    a: f32,
    fov: f32,

    pub fn init(x: f32, y: f32, a: f32, fov: f32) Player {
        return Player{
            .x = x,
            .y = y,
            .a = a,
            .fov = fov,
        };
    }
};
