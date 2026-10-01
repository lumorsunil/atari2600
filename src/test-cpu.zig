const std = @import("std");
const Stdio = @import("stdio.zig").Stdio;
const atari2600 = @import("atari2600");

fn runInstruction(opcode: u8, cpu: *atari2600.MOS6502.MOS6502, stdout: *std.Io.Writer) !void {
    try stdout.print(
        "running opcode: {x:02}, type: {?f}\n",
        .{ opcode, atari2600.MOS6502.opcode_type_table[opcode] },
    );

    // opcode fetch cycle
    try cpu.update();

    cpu.data_bus = .fromInt(opcode);

    // execute cycle
    try cpu.update();

    try printCpu(cpu, stdout);
}

fn runInstruction2(opcode: u8, cpu: *atari2600.MOS6502.MOS6502, stdout: *std.Io.Writer, arg: u8) !void {
    try stdout.print(
        "running opcode: {x:02}, type: {?f}, arg: {x:02}\n",
        .{ opcode, atari2600.MOS6502.opcode_type_table[opcode], arg },
    );

    // opcode fetch cycle
    try cpu.update();

    cpu.data_bus = .fromInt(opcode);

    // execute cycle
    try cpu.update();

    cpu.data_bus = .fromInt(arg);

    try printCpu(cpu, stdout);
}

fn printCpu(cpu: *atari2600.MOS6502.MOS6502, stdout: *std.Io.Writer) !void {
    try stdout.print("a: 0b{b:08}\ts: 0b{b:08}\n", .{ cpu.registers.a.toInt(), cpu.registers.s.toInt() });
    try stdout.print("x: 0b{b:08}\ty: 0b{b:08}\n", .{ cpu.registers.x.toInt(), cpu.registers.y.toInt() });
    try stdout.print("pc: 0b{b:016}\n", .{cpu.registers.pc.toInt()});
    try stdout.print(
        "z: {} n: {} c: {} v: {} d: {} i: {}\n",
        .{ cpu.flags.zero_, cpu.flags.negative, cpu.flags.carry, cpu.flags.overflow, cpu.flags.decimal_mode, cpu.flags.irq_disable },
    );
}

fn getOpcode(
    comptime tag: std.meta.DeclEnum(atari2600.MOS6502.Instructions),
    comptime mode_tag: atari2600.MOS6502.Instruction.AddressingModeTag,
) u8 {
    return @field(
        atari2600.MOS6502.Instructions,
        @tagName(tag),
    ).available_modes.get(mode_tag).?.opcode;
}

pub fn runTestCPU(_: std.process.Init, stdio: *Stdio) !u8 {
    // const allocator = init.arena.allocator();
    const stdout = stdio.stdout();
    // const stderr = stdio.stderr();

    var cpu = atari2600.MOS6502.MOS6502.init();
    cpu.registers.a = .fromInt(1);
    cpu.registers.x = .fromInt(1);

    try printCpu(&cpu, stdout);
    try runInstruction(getOpcode(.ASL, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.LSR, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.LSR, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.CLC, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.CLV, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.CLD, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.CLI, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.INX, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.INY, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.DEX, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.DEY, .implicit), &cpu, stdout);
    cpu.registers.a = .fromInt(1);
    try runInstruction(getOpcode(.ROR, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.ROL, .implicit), &cpu, stdout);

    try runInstruction(getOpcode(.CLC, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.SEC, .implicit), &cpu, stdout);

    try runInstruction(getOpcode(.CLD, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.SED, .implicit), &cpu, stdout);

    try runInstruction(getOpcode(.CLI, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.SEI, .implicit), &cpu, stdout);

    cpu.registers.x = .fromInt(0b11110000);

    try runInstruction(getOpcode(.TXS, .implicit), &cpu, stdout);
    try runInstruction(getOpcode(.TXA, .implicit), &cpu, stdout);

    try runInstruction2(getOpcode(.ADC, .immediate), &cpu, stdout, 0x10);
    try runInstruction2(getOpcode(.ADC, .immediate), &cpu, stdout, 0x20);

    return 0;
}
