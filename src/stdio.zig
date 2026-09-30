const std = @import("std");

pub const Stdio = struct {
    stdin_buffer: [1024]u8 = undefined,
    stdin_file_reader: std.Io.File.Reader = undefined,
    stdout_file_writer: std.Io.File.Writer = undefined,
    stderr_file_writer: std.Io.File.Writer = undefined,

    pub fn init() @This() {
        return .{};
    }

    pub fn setup(self: *@This(), io: std.Io) void {
        self.stdin_file_reader = std.Io.File.stdin().reader(io, &self.stdin_buffer);
        self.stdout_file_writer = std.Io.File.stdout().writer(io, &.{});
        self.stderr_file_writer = std.Io.File.stderr().writer(io, &.{});
    }

    pub fn stdin(self: *@This()) *std.Io.Reader {
        return &self.stdin_file_reader.interface;
    }

    pub fn stdout(self: *@This()) *std.Io.Writer {
        return &self.stdout_file_writer.interface;
    }

    pub fn stderr(self: *@This()) *std.Io.Writer {
        return &self.stderr_file_writer.interface;
    }
};
