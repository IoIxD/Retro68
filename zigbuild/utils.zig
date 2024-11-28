const std = @import("std");

const allocator = std.heap.page_allocator;

pub const InterfaceType = enum {
    universal,
    multiversal,
    unknown,
};

// shorthand for debug.print, with no args support
pub fn echo(msg: []const u8) void {
    std.debug.print("{s}\n", .{msg});
}

pub fn uname() ![]const u8 {
    return try cmd(&[_][]const u8{"uname"});
}
pub fn machine() ![]const u8 {
    return try cmd(&[_][]const u8{ "uname", "-m" });
}

pub fn concat(items: anytype) ![]const u8 {
    var final = std.ArrayList([]const u8).init(allocator);

    switch (@typeInfo(@TypeOf(items))) {
        .Struct => |struc| {
            inline for (struc.fields) |field| {
                const what = @field(items, field.name);
                try final.append(what);
            }
        },
        else => {
            unreachable();
        },
    }

    return try std.mem.concat(allocator, u8, try final.toOwnedSlice());
}

pub fn streql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a, b) |a_elem, b_elem| {
        if (a_elem != b_elem) return false;
    }
    return true;
}

pub fn dir_exists(dir: []const u8) bool {
    return std.fs.openDirAbsolute(dir, .{}) != std.fs.Dir.OpenError.FileNotFound;
}

pub fn mkdir(dir: []const u8) !void {
    if (!dir_exists(dir)) {
        try std.fs.makeDirAbsolute(dir);
    }
}

pub fn get_env(key: []const u8) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    return env.get(key).?;
}

pub fn env_export(key: []const u8, value: []const u8) !void {
    var env = try std.process.getEnvMap(allocator);
    try env.put(key, value);
}

pub fn env_unset(key: []const u8) !void {
    var env = try std.process.getEnvMap(allocator);
    env.remove(key);
}

pub fn make(dir: []const u8) !void {
    try cmd_with_wd(&[_][]const u8{"make"}, dir);
}

pub fn install(dir: []const u8) !void {
    try cmd_with_wd(&[_][]const u8{"make install"}, dir);
}

// mv get_env("PREFIX")/bin/m68k-apple-macos-ld get_env("PREFIX")/bin/m68k-apple-macos-ld.real
pub fn cp(wildcard_a: []const u8, wildcard_b: []const u8) !void {
    _ = try cmd(&.{ "cp", wildcard_a, wildcard_b });
}

pub fn mv(a: []const u8, b: []const u8) !void {
    try std.fs.renameAbsolute(a, b);
}

pub fn ln(a: []const u8, b: []const u8) !void {
    try std.fs.symLinkAbsolute(a, b, .{});
}

pub fn rm(a: []const u8) !void {
    try std.fs.deleteDirAbsolute(a);
}

pub fn cmake(dir: []const u8, args: [][]const u8) !void {
    const argstr = try std.mem.concat(allocator, u8, args);
    const ok = ([1][]const u8){try concat(.{ "cmake", argstr })};
    try cmd_with_wd(&ok, dir);
}

// cmake --build build-host --target install
pub fn cmake_install(dir: []const u8, out_dir: []const u8) !void {
    const ok = ([1][]const u8){try concat(.{ "cmake", "--build", out_dir, " --target install" })};
    try cmd_with_wd(&ok, dir);
}

pub fn which(file: []const u8) ![]const u8 {
    var whichcmd = ([2][]const u8){ "which", file };
    return try cmd(&whichcmd);
}

pub fn cmd(argv: []const []const u8) ![]const u8 {
    std.debug.print("Running {s}\n", .{try std.mem.concat(allocator, u8, argv)});
    var cmd_ = std.process.Child.init(argv, allocator);
    try cmd_.spawn();
    // in a real application you'd not want to ignore the status here probably
    _ = try cmd_.wait();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = std.mem.zeroes([std.fs.MAX_PATH_BYTES]u8);

    const out = cmd_.stdout;
    if (out != null) {
        _ = try out.?.read(&buf);
        std.debug.print("{any}\n", .{buf});
    }
    return &buf;
}

pub fn cmd_with_wd(argv: []const []const u8, wd: []const u8) !void {
    std.debug.print("Running {s} in {s}", .{ try std.mem.concat(allocator, u8, argv), wd });
    var cmd_ = std.process.Child.init(argv, allocator);
    cmd_.cwd_dir = try std.fs.cwd().openDir(wd, .{});
    try cmd_.spawn();
    _ = try cmd_.wait();
    if (cmd_.stderr != null) {
        var buffer: [1 << 10]u8 = undefined;
        _ = try cmd_.stderr.?.readAll(&buffer);
        std.debug.print("ERROR executing {any}: {any}", .{ try std.mem.concat(allocator, u8, argv), buffer });
    }
}
