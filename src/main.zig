const std = @import("std");
const Io = std.Io;

const atari2600 = @import("atari2600");

pub fn main(init: std.process.Init) !void {
    const file_path = "a.out";
    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, file_path, init.arena.allocator(), .unlimited);

    var index: usize = 2;
    while (true) {
        const instr, const bytes_read = atari2600.MOS6502.Instruction.decode(source[index..]) catch |err| switch (err) {
            atari2600.MOS6502.Instruction.DecodeError.EndOfSource => break,
            atari2600.MOS6502.Instruction.DecodeError.InvalidOpcode => {
                std.log.err("Invalid OpCode: {x:02}", .{source[index]});
                break;
            },
            atari2600.MOS6502.Instruction.DecodeError.SourceCutoff => {
                std.log.err("Source Cutoff at index {}", .{index});
                break;
            },
        };
        index += bytes_read;

        std.log.debug("{f}", .{instr});
    }
}
