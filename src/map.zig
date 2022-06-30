const std = @import("std");

pub const width: usize = 16;
pub const height: usize = 16;
pub const data: *const [width * height:0]u8 =
    "0000222222220000" ++
    "1              0" ++
    "1      11111   0" ++
    "1     0        0" ++
    "0     0  1110000" ++
    "0     3        0" ++
    "0   10000      0" ++
    "0   0   11100  0" ++
    "0   0   0      0" ++
    "0   0   1  00000" ++
    "0       1      0" ++
    "2       1      0" ++
    "0       0      0" ++
    "0 0000000      0" ++
    "0              0" ++
    "0002222222200000";
