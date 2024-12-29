const std = @import("std");
const lzw = @import("lib.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip(); // skip past the initial argument
    const path_opt = args.next();

    if (path_opt == null) {
        try help_msg();
    }

    const path = path_opt.?;

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("MEMORY LEAK\n", .{});
    }

    var l = try lzw.LZW_Dict.init(allocator);
    defer l.deinit();

    const contents = try file.reader().readAllAlloc(
        allocator,
        1073741824, // about 1 Gibibyte
    );
    defer allocator.free(contents);

    try stdout.print("{s}\n", .{contents});

    try bw.flush();
}

fn help_msg() !void {
    std.debug.print("Usage: zcompress [file]\n", .{});
    std.process.exit(64);
}
