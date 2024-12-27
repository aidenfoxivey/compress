const std = @import("std");

pub fn main() !void {
    const path = "./compress_me.txt";
    const fd = try std.posix.open(path, .{ .ACCMODE = .RDONLY }, 0);
    const stat = try std.posix.fstat(fd);

    std.debug.print("{} is {} bytes!\n", .{path,stat.size});
}
