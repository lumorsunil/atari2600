const std = @import("std");
const Stdio = @import("stdio.zig").Stdio;
const parseOptions = @import("options.zig").parseOptions;
const printUsage = @import("options.zig").printUsage;
const runDecode = @import("decode.zig").runDecode;

pub fn run(init: std.process.Init, stdio: *Stdio) !u8 {
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
