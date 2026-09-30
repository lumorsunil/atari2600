const std = @import("std");
const Allocator = std.mem.Allocator;
const Stdio = @import("stdio.zig").Stdio;

const Options = struct {
    allocator: Allocator,
    mode: ?union(enum) {
        decode: [:0]const u8,
    } = null,

    pub fn setDecode(self: *@This(), decode: [:0]const u8) !OptionEvent {
        if (self.mode) |mode| return try .invalidFmt(self.allocator, "Cannot use --decode with --{t}", .{mode});
        self.mode = .{ .decode = decode };
        return .valid;
    }

    pub const OptionEvent = union(enum) {
        valid,
        invalid_: []const u8,

        pub fn invalid(msg: []const u8) @This() {
            return .{ .invalid_ = msg };
        }

        pub fn invalidFmt(allocator: Allocator, comptime fmt: []const u8, args: anytype) !@This() {
            return .{ .invalid_ = try std.fmt.allocPrint(allocator, fmt, args) };
        }
    };
};

const Option = struct {
    command: []const u8,
    description: []const u8,

    pub fn init(command: []const u8, description: []const u8) @This() {
        return .{ .command = command, .description = description };
    }
};

const options_descriptions: []const Option = &.{
    .init("--decode <file>", "Decodes binary 6502 to dasm assembler code to stdout."),
};

pub fn printUsage(stdout: *std.Io.Writer) !void {
    try stdout.print("Usage: atari2600 [options]\n\n", .{});
    try stdout.print("Options:\n", .{});
    for (options_descriptions) |option| {
        try stdout.print("{s}\t{s}\n", .{ option.command, option.description });
    }
}

fn handleOptionEvent(event: Options.OptionEvent, stderr: *std.Io.Writer) !void {
    switch (event) {
        .valid => {},
        .invalid_ => |msg| {
            try stderr.print("Invalid options: {s}", .{msg});
            return error.InvalidOptions;
        },
    }
}

fn parseOption(
    allocator: Allocator,
    options: *Options,
    it: *std.process.Args.Iterator,
    arg: [:0]const u8,
) !Options.OptionEvent {
    if (std.mem.eql(u8, arg, "--decode")) {
        const decode = it.next() orelse return .invalid("--decode option requires a file path argument");
        return options.setDecode(decode);
    }

    return try .invalidFmt(allocator, "Unknown option \"{s}\"", .{arg});
}

pub fn parseOptions(allocator: Allocator, stdio: *Stdio, args: std.process.Args) !Options {
    const stderr = stdio.stderr();

    var it = try args.iterateAllocator(allocator);
    var options = Options{ .allocator = allocator };

    _ = it.next();
    while (it.next()) |arg| try handleOptionEvent(
        try parseOption(allocator, &options, &it, arg),
        stderr,
    );

    return options;
}
