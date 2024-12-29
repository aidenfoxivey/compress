const std = @import("std");

/// `CodeSize` represents the dictionary code width. In more memory constrained
/// circumstances, it would increase from 9 bits to 12 bits, but here we opt to
/// stay at 12 bits from the start for consistency.
pub const CodeSize = u12;

/// `LZW_Dict` represents the mapping between byte sequences and codes used in
/// the Lempel-Ziv-Welch compression scheme. The first 256 elements are all
/// possible 1 byte values with a mapping to indices [0, 255].
pub const LZW_Dict = struct {
    map: std.StringHashMap(CodeSize),
    allocator: std.mem.Allocator,

    /// `counter` represents the size of the dictionary and code for a sequence
    counter: CodeSize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var map = std.StringHashMap(CodeSize).init(allocator);

        // Populate LZW_Dict with all single byte values
        for (0..256) |i| {
            const key_slice = try allocator.alloc(u8, 1);
            key_slice[0] = @intCast(i);
            try map.put(key_slice, @intCast(i));
        }

        // Set the counter to 256, since we have exhausted codes [0, 255]
        return Self{ .map = map, .allocator = allocator, .counter = 256 };
    }

    pub fn deinit(self: *Self) void {
        var it = self.map.keyIterator();

        while (it.next()) |key| {
            self.allocator.free(key.*);
        }

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

    /// Put the current
    pub fn put(self: *Self, curr_seq: std.ArrayList(u8)) void {
        self.map.put(curr_seq, self.counter);
        self.counter += 1;
    }

    /// Given a sequence of bytes, find the corresponding code.
    pub fn get(self: *Self, curr_seq: []u8) ?CodeSize {
        return self.map.get(curr_seq);
    }
};

// /// LSB (GIF) vs MSB (TIFF, PDF)
// /// Given a stream of bytes `uncompressed`, compress it using LZW compression strategy.
// /// Caller is expected to deallocate the returned array.
// export fn compress(uncompressed: []const u8, allocator: std.mem.Allocator) ![]CodeSize {
//     var dict = try LZW_Dict.init(allocator);
//     defer dict.deinit();

//     // Represents the largest observed sequence so far
//     var sequence = std.ArrayList(u8).init(allocator);
//     defer sequence.deinit();

//     // Since we call `.toOwnedSlice`, we have no need to `.deinit`.
//     var compressed = std.ArrayList(CodeSize).init(allocator);

//     for (uncompressed) |byte| {
//         try sequence.append(byte);

//         // If the next sequence is in the dictionary, append the byte and continue
//         if (!dict.map.get(sequence.items)) {
//             dict.counter += 1;

//             try dict.map.put(sequence.items, dict.counter);

//             sequence.clearAndFree();
//             try sequence.append(byte);
//         }

//         // Sequence not found, output code for current sequence
//         if (dict.map.get(sequence.items)) |code| {
//             try compressed.append(code);
//         }

//         // Add new sequence to dictionary
//         dict.counter += 1;
//         try dict.map.put(next_seq.items, dict.counter);

//         // Reset current sequence to just the current byte
//         curr_seq.clearAndFree();
//         try curr_seq.append(byte);
//     }

//     // If we still have a sequence in progress, output its code
//     if (curr_seq.items.len > 0) {
//         if (dict.map.get(curr_seq.items)) |code| {
//             try compressed.append(code);
//         }
//     }

//     return compressed.toOwnedSlice(allocator);
// }
