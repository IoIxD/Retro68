const std = @import("std");
const toolchain = @import("zigbuild/build-toolchain.zig");

pub fn build(b: *std.Build) !void {
    try toolchain.build(b);
}
