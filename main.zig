const std = @import("std");

const CodeSize = u12;
pub fn main() !void {
    const path = "./compress_me.txt";
    const fd = try std.posix.open(path, .{ .ACCMODE = .RDONLY }, 0);
    defer std.posix.close(fd);

    const stat = try std.posix.fstat(fd);

    std.debug.print("{s} is {} bytes!\n", .{ path, stat.size });
    std.debug.print("Lets compress this shit\n", .{});

    // Read the file into buffer
    const buffer = try std.heap.page_allocator.alloc(u8, @intCast(stat.size));
    defer std.heap.page_allocator.free(buffer);

    // Read the file contents into the buffer
    const bytes_read = try std.posix.read(fd, buffer);
    if (bytes_read != stat.size) {
        return error.IncompleteRead;
    }

    const iter = std.mem.window(u8, buffer, @intCast(stat.size), @sizeOf(u8));
    var compressed_data = try compress(iter);
    defer compressed_data.deinit();
}

fn compress(iter: std.mem.WindowIterator(u8)) !std.ArrayList(CodeSize) {
    var dict = Dictionary{};
    var curr_seq = std.ArrayList(u8).init(std.heap.page_allocator);
    defer curr_seq.deinit();

    var compressed = std.ArrayList(u16).init(std.heap.page_allocator);
    defer compressed.deinit();

    while (iter.next()) |byte| {
        var next_seq = try curr_seq.clone();
        try next_seq.append(byte);
        // If the next sequence is in the dictionary, append the byte and continue
        if (dict.map.get(next_seq.items)) {
            try curr_seq.append(byte);
            continue;
        }

        // Sequence not found, output code for current sequence
        if (dict.map.get(curr_seq.items)) |code| {
            try compressed.append(code);
        }

        // Add new sequence to dictionary
        dict.counter += 1;
        try dict.map.put(next_seq.items, dict.counter);

        // Reset current sequence to just the current byte
        curr_seq.clearAndFree();
        try curr_seq.append(byte);
    }

    // If we still have a sequence in progress, output its code
    if (curr_seq.items.len > 0) {
        if (dict.map.get(curr_seq.items)) |code| {
            try compressed.append(code);
        }
    }

    for (compressed.items) |code| {
        std.debug.print("{} ", .{code});
    }

    return compressed;
}

const Dictionary = struct {
    map: std.AutoHashMap([]u8, CodeSize),
    counter: CodeSize = 0,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) !Self {
        var map = try std.AutoHashMap([]u8, CodeSize).init(allocator);
        const counter: CodeSize = 0;

        // Fill the initial dictionary with all the UTF-8 characters
        for (0..256) |i| {
            const key = &[_]u8{u8(i)};
            try map.put(key, i);
        }

        return Self{ .map = map, .counter = counter };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }

    pub fn add(self: *Self, curr_seq: std.ArrayList(u8), next_char: u8) CodeSize {
        const entry = self.map.get(curr_seq);
        if (entry != null) {
            curr_seq.append(next_char);
            self.counter += 1;
            self.map.put(curr_seq, self.counter);
            return self.counter;
        } else {
            return entry;
        }
    }

    pub fn get(self: *Self, curr_seq: []u8) ?u8 {
        return self.map.get(curr_seq);
    }
};
