const std = @import("std");
const Stdio = @import("stdio.zig").Stdio;
const atari2600 = @import("atari2600");

pub fn runDecode(init: std.process.Init, stdio: *Stdio, file_path: []const u8) !u8 {
    const allocator = init.arena.allocator();
    const stdout = stdio.stdout();
    const stderr = stdio.stderr();

    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, file_path, allocator, .unlimited);
    var org = atari2600.MOS6502.Addr.zero;
    org.lo = source[0];
    org.hi = source[1];

    try stdout.writeAll("    processor 6502\n");
    try stdout.print("    org ${f}\n", .{org});

    var index: usize = 2;
    while (true) {
        const instr, const bytes_read = atari2600.MOS6502.Instruction.decode(source[index..]) catch |err| switch (err) {
            atari2600.MOS6502.Instruction.DecodeError.EndOfSource => break,
            atari2600.MOS6502.Instruction.DecodeError.InvalidOpcode => {
                try stderr.print("Invalid OpCode: {x:02}", .{source[index]});
                return 1;
            },
            atari2600.MOS6502.Instruction.DecodeError.SourceCutoff => {
                try stderr.print("Source Cutoff at index {}", .{index});
                return 1;
            },
        };
        index += bytes_read;

        try stdout.print("    {f}\n", .{instr});
    }

    return 0;
}
