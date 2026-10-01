const std = @import("std");

pub const SevenBits = packed struct(u7) {
    b0: u1 = 0,
    b1: u1 = 0,
    b2: u1 = 0,
    b3: u1 = 0,
    b4: u1 = 0,
    b5: u1 = 0,
    b6: u1 = 0,

    pub const zero = @This(){};

    pub fn fromInt(int: u7) @This() {
        return @bitCast(int);
    }

    pub fn toInt(self: @This()) u7 {
        return @bitCast(self);
    }

    pub fn setFromInt(self: *@This(), int: u7) void {
        self.* = .fromInt(int);
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{x:02}", .{self.toInt()});
    }
};

pub const Byte = packed struct(u8) {
    b0: u1 = 0,
    b1: u1 = 0,
    b2: u1 = 0,
    b3: u1 = 0,
    b4: u1 = 0,
    b5: u1 = 0,
    b6: u1 = 0,
    b7: u1 = 0,

    pub const zero = @This(){};

    pub fn fromInt(int: u8) @This() {
        return @bitCast(int);
    }

    pub fn toInt(self: @This()) u8 {
        return @bitCast(self);
    }

    pub fn toIntPtr(self: *@This()) *u8 {
        return @ptrCast(self);
    }

    pub fn setFromInt(self: *@This(), int: u8) void {
        self.* = .fromInt(int);
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{x:02}", .{self.toInt()});
    }
};

pub const Word = packed struct(u16) {
    lo: Byte = .zero,
    hi: Byte = .zero,

    pub const zero = @This(){};

    pub fn fromInt(int: u16) @This() {
        return @bitCast(int);
    }

    pub fn toInt(self: @This()) u16 {
        return @bitCast(self);
    }

    pub fn inc(self: *@This()) void {
        self.* = self.fromInt(self.toInt() +% 1);
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{f}{f}", .{ self.hi, self.lo });
    }
};

pub const ReadWrite = enum(u1) {
    read = 1,
    write = 0,
};
