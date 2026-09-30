const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Stdio = @import("stdio.zig").Stdio;
const OptionsError = @import("options.zig").OptionsError;
const parseOptions = @import("options.zig").parseOptions;
const printUsage = @import("options.zig").printUsage;
const runDecode = @import("decode.zig").runDecode;

const atari2600 = @import("atari2600");

pub fn main(init: std.process.Init) !void {
    var stdio = Stdio.init();
    stdio.setup(init.io);

    const exit_code = run(init, &stdio) catch |err| brk: {
        try stdio.stderr().print("Error: {}", .{err});
        break :brk 1;
    };

    if (exit_code == 0) {
        std.process.cleanExit(init.io);
    } else {
        std.process.exit(exit_code);
    }
}

fn run(init: std.process.Init, stdio: *Stdio) !u8 {
    const allocator = init.arena.allocator();
    const options = try parseOptions(allocator, stdio, init.minimal.args);

    return if (options.mode) |mode| switch (mode) {
        .decode => |file_path| try runDecode(init, stdio, file_path),
    } else try noModeSelected(stdio.stderr());
}

fn noModeSelected(stderr: *std.Io.Writer) !u8 {
    try printUsage(stderr);
    try stderr.print("No mode selected.", .{});
    return 1;
}
