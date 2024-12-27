const std = @import("std");

const CodeSize = u16;
pub fn main() !void {
    const path = "./compress_me.txt";
    const fd = try std.posix.open(path, .{ .ACCMODE = .RDONLY }, 0);
    defer std.posix.close(fd);

    const stat = try std.posix.fstat(fd);

    std.debug.print("{s} is {} bytes!\n", .{ path, stat.size });
    std.debug.print("Lets compress this shit\n", .{});

    const file = std.fs.File{ .handle = fd };
    var buffered_reader = std.io.bufferedReader(file.reader());
    var file_iterator = FileIterator.init(buffered_reader.reader());

    var compressed_data = try compress(&file_iterator);
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

        if (dict.map.get(next_seq.items)) {
            // Sequence exists in dictionary, continue building it
            try curr_seq.append(byte);
        } else {
            // Sequence not found, output code for current sequence
            if (dict.map.get(curr_seq.items)) |code| {
                try compressed.append(code);
            }

            // Add new sequence to dictionary
            if (dict.counter >= 65535) {
                std.debug.panic("Dictionary is full! (Just expand code size and should be fine :)) \n", .{});
            }

            dict.counter += 1;
            try dict.map.put(next_seq.items, dict.counter);

            // Reset current sequence to just the current byte
            curr_seq.clearAndFree();
            try curr_seq.append(byte);
        }
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

const FileIterator = struct {
    reader: anytype,
    buffer: [1]u8 = undefined,

    const Self = @This();

    pub fn init(reader: anytype) Self {
        return Self{
            .reader = reader,
        };
    }

    pub fn next(self: *Self) !?u8 {
        const amt = self.reader.read(&self.buffer) catch |err| switch (err) {
            error.EndOfStream => return null,
            else => return err,
        };
        if (amt == 0) return null;
        return self.buffer[0];
    }
};

const Dictionary = struct {
    map: std.AutoHashMap([]u8, CodeSize),
    counter: CodeSize,

    const Self = @This();

    pub fn init(self: *Self) void {
        self.map = std.AutoHashMap([]u8, u16).init(std.heap.page_allocator);
        self.counter = 0;

        // Fill the initial dictionary with all the UTF-8 characters
        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            var char_seq = std.ArrayList(u8).init(std.heap.page_allocator);
            defer char_seq.deinit();
            char_seq.append(u8(i));
            self.map.put(char_seq.toOwnedSlice(), i);
        }
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
