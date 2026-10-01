const std = @import("std");
const Stdio = @import("stdio.zig").Stdio;
const run = @import("run.zig").run;

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
