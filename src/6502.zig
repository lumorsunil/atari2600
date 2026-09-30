const std = @import("std");

pub const MOS6502 = struct {
    a: u8 = 0,
    x: u8 = 0,
    y: u8 = 0,
    pc: Addr = .zero,
    sp: u8 = 0,
    flags: Flags = .zero,
    cycle: usize = 0,

    pub fn init() @This() {
        return .{};
    }

    pub const Flags = packed struct(u8) {
        carry: u1 = 0,
        zero_: u1 = 0,
        irq_disable: u1 = 0,
        decimal_mode: u1 = 0,
        break_command: u1 = 0,
        _: u1 = 0,
        overflow: u1 = 0,
        negative: u1 = 0,

        pub const zero = @This(){};
    };
};

pub const Addr = packed struct(u16) {
    lo: u8 = 0,
    hi: u8 = 0,

    pub const zero = @This(){};

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{x:02}{x:02}", .{ self.hi, self.lo });
    }
};

// INSTRUCTION SET

pub const Instruction = struct {
    type: *const Type,
    mode: AddressingMode,

    pub fn decode(source: []const u8) DecodeError!struct { @This(), usize } {
        @setEvalBranchQuota(10000);

        if (source.len == 0) return DecodeError.EndOfSource;
        const opcode = source[0];
        const instr_type = opcode_type_table[opcode] orelse return DecodeError.InvalidOpcode;
        const mode = opcode_mode_table[opcode] orelse return DecodeError.InvalidOpcode;

        switch (mode) {
            inline else => |t| {
                const Instr = std.meta.fieldInfo(AddressingMode, t).type;
                const n_instr_bits = @bitSizeOf(Instr);
                const n_instr_bytes = comptime n_instr_bits / 8;

                if (source.len < n_instr_bytes) return DecodeError.SourceCutoff;

                const instr_bytes = source[0..n_instr_bytes];
                const instr_uint = std.mem.readInt(@Int(.unsigned, n_instr_bits), instr_bytes, .little);
                const instr: Instr = @bitCast(instr_uint);

                const addressing_mode = @unionInit(AddressingMode, @tagName(t), instr);

                return .{
                    .{
                        .type = instr_type,
                        .mode = addressing_mode,
                    },
                    n_instr_bytes,
                };
            },
        }
    }

    pub const DecodeError = error{ InvalidOpcode, EndOfSource, SourceCutoff };

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{s}", .{self.type.mnemonic});

        try switch (self.mode) {
            .implicit => {},
            .immediate => |s| writer.print(" #{x:02}", .{s.arg}),
            .absolute => |s| writer.print(" {f}", .{s.addr}),
            .zero => |s| writer.print(" {x:02}", .{s.addr}),
            .indexed_absolute_x => |s| writer.print(" {f},X", .{s.addr}),
            .indexed_absolute_y => |s| writer.print(" {f},Y", .{s.addr}),
            .indexed_zero_x => |s| writer.print(" {x:02},X", .{s.addr}),
            .indexed_zero_y => |s| writer.print(" {x:02},Y", .{s.addr}),
            .indirect_absolute => |s| writer.print(" ({f})", .{s.addr}),
            .pre_indexed_indirect_zero_x => |s| writer.print(" ({x:02},X)", .{s.addr}),
            .post_indexed_indirect_zero_y => |s| writer.print(" ({x:02}),Y", .{s.addr}),
            .relative => |s| writer.print(" {x:02}", .{s.addr}),
        };
    }

    pub const AddressingModeTag = enum {
        implicit,
        immediate,
        absolute,
        zero,
        indexed_absolute_x,
        indexed_absolute_y,
        indexed_zero_x,
        indexed_zero_y,
        indirect_absolute,
        pre_indexed_indirect_zero_x,
        post_indexed_indirect_zero_y,
        relative,
    };

    pub const AddressingMode = union(AddressingModeTag) {
        implicit: packed struct(u8) {
            opcode: u8,
        },
        immediate: packed struct(u16) {
            opcode: u8,
            arg: u8,
        },
        absolute: packed struct(u24) {
            opcode: u8,
            addr: Addr,
        },
        zero: packed struct(u16) {
            opcode: u8,
            addr: u8,
        },
        indexed_absolute_x: packed struct(u24) {
            opcode: u8,
            addr: Addr,
        },
        indexed_absolute_y: packed struct(u24) {
            opcode: u8,
            addr: Addr,
        },
        indexed_zero_x: packed struct(u16) {
            opcode: u8,
            addr: u8,
        },
        indexed_zero_y: packed struct(u16) {
            opcode: u8,
            addr: u8,
        },
        indirect_absolute: packed struct(u24) {
            opcode: u8,
            addr: Addr,
        },
        pre_indexed_indirect_zero_x: packed struct(u16) {
            opcode: u8,
            addr: u8,
        },
        post_indexed_indirect_zero_y: packed struct(u16) {
            opcode: u8,
            addr: u8,
        },
        relative: packed struct(u16) {
            opcode: u8,
            addr: i8,
        },
    };

    pub const Type = struct {
        mnemonic: *const [3:0]u8,
        description: []const u8,
        available_modes: AvailableModes,

        pub const AvailableModes = std.enums.EnumMap(AddressingModeTag, ModeOptions);
        pub const ModeOptions = struct {
            opcode: u8,
            base_cycles: u4,

            pub fn init(opcode: u8, base_cycles: u4) @This() {
                return .{ .opcode = opcode, .base_cycles = base_cycles };
            }
        };
    };
};

const Instructions = struct {
    pub const ADC = Instruction.Type{
        .mnemonic = "ADC",
        .description = "add with carry",
        .available_modes = .init(.{
            .immediate = .init(0x69, 2),
            .zero = .init(0x65, 3),
            .indexed_zero_x = .init(0x75, 4),
            .absolute = .init(0x6D, 4),
            .indexed_absolute_x = .init(0x7D, 4),
            .indexed_absolute_y = .init(0x79, 4),
            .pre_indexed_indirect_zero_x = .init(0x61, 6),
            .post_indexed_indirect_zero_y = .init(0x71, 5),
        }),
    };
    pub const AND = Instruction.Type{
        .mnemonic = "AND",
        .description = "and (with accumulator)",
        .available_modes = .init(.{
            .immediate = .init(0x29, 2),
            .zero = .init(0x25, 3),
            .indexed_zero_x = .init(0x35, 4),
            .absolute = .init(0x2D, 4),
            .indexed_absolute_x = .init(0x3D, 4),
            .indexed_absolute_y = .init(0x39, 4),
            .pre_indexed_indirect_zero_x = .init(0x21, 6),
            .post_indexed_indirect_zero_y = .init(0x31, 5),
        }),
    };
    pub const ASL = Instruction.Type{
        .mnemonic = "ASL",
        .description = "arithmetic shift left",
        .available_modes = .init(.{
            .implicit = .init(0x0A, 2),
            .zero = .init(0x06, 5),
            .indexed_zero_x = .init(0x16, 6),
            .absolute = .init(0x0E, 6),
            .indexed_absolute_x = .init(0x1E, 7),
        }),
    };
    pub const BCC = Instruction.Type{
        .mnemonic = "BCC",
        .description = "branch on carry clear",
        .available_modes = .init(.{
            .relative = .init(0x90, 2),
        }),
    };
    pub const BCS = Instruction.Type{
        .mnemonic = "BCS",
        .description = "branch on carry set",
        .available_modes = .init(.{
            .relative = .init(0xB0, 2),
        }),
    };
    pub const BEQ = Instruction.Type{
        .mnemonic = "BEQ",
        .description = "branch on equal (zero set)",
        .available_modes = .init(.{
            .relative = .init(0xF0, 2),
        }),
    };
    pub const BIT = Instruction.Type{
        .mnemonic = "BIT",
        .description = "bit test",
        .available_modes = .init(.{
            .zero = .init(0x24, 3),
            .absolute = .init(0x2C, 4),
        }),
    };
    pub const BMI = Instruction.Type{
        .mnemonic = "BMI",
        .description = "branch on minus (negative set)",
        .available_modes = .init(.{
            .relative = .init(0x30, 2),
        }),
    };
    pub const BNE = Instruction.Type{
        .mnemonic = "BNE",
        .description = "branch on not equal (zero clear)",
        .available_modes = .init(.{
            .relative = .init(0xD0, 2),
        }),
    };
    pub const BPL = Instruction.Type{
        .mnemonic = "BPL",
        .description = "branch on plus (negative clear)",
        .available_modes = .init(.{
            .relative = .init(0x10, 2),
        }),
    };
    pub const BRK = Instruction.Type{
        .mnemonic = "BRK",
        .description = "break / interrupt",
        .available_modes = .init(.{
            .implicit = .init(0x00, 7),
        }),
    };
    pub const BVC = Instruction.Type{
        .mnemonic = "BVC",
        .description = "branch on overflow clear",
        .available_modes = .init(.{
            .relative = .init(0x50, 2),
        }),
    };
    pub const BVS = Instruction.Type{
        .mnemonic = "BVS",
        .description = "branch on overflow set",
        .available_modes = .init(.{
            .relative = .init(0x70, 2),
        }),
    };
    pub const CLC = Instruction.Type{
        .mnemonic = "CLC",
        .description = "clear carry",
        .available_modes = .init(.{
            .implicit = .init(0x18, 2),
        }),
    };
    pub const CLD = Instruction.Type{
        .mnemonic = "CLD",
        .description = "clear decimal",
        .available_modes = .init(.{
            .implicit = .init(0xD8, 2),
        }),
    };
    pub const CLI = Instruction.Type{
        .mnemonic = "CLI",
        .description = "clear interrupt disable",
        .available_modes = .init(.{
            .implicit = .init(0x58, 2),
        }),
    };
    pub const CLV = Instruction.Type{
        .mnemonic = "CLV",
        .description = "clear overflow",
        .available_modes = .init(.{
            .implicit = .init(0xB8, 2),
        }),
    };
    pub const CMP = Instruction.Type{
        .mnemonic = "CMP",
        .description = "compare (with accumulator)",
        .available_modes = .init(.{
            .immediate = .init(0xC9, 2),
            .zero = .init(0xC5, 3),
            .indexed_zero_x = .init(0xD5, 4),
            .absolute = .init(0xCD, 4),
            .indexed_absolute_x = .init(0xDD, 4),
            .indexed_absolute_y = .init(0xD9, 4),
            .pre_indexed_indirect_zero_x = .init(0xC1, 6),
            .post_indexed_indirect_zero_y = .init(0xD1, 5),
        }),
    };
    pub const CPX = Instruction.Type{
        .mnemonic = "CPX",
        .description = "compare with X",
        .available_modes = .init(.{
            .immediate = .init(0xE0, 2),
            .zero = .init(0xE4, 3),
            .absolute = .init(0xEC, 4),
        }),
    };
    pub const CPY = Instruction.Type{
        .mnemonic = "CPY",
        .description = "compare with Y",
        .available_modes = .init(.{
            .immediate = .init(0xC0, 2),
            .zero = .init(0xC4, 3),
            .absolute = .init(0xCC, 4),
        }),
    };
    pub const DEC = Instruction.Type{
        .mnemonic = "DEC",
        .description = "decrement",
        .available_modes = .init(.{
            .zero = .init(0xC6, 5),
            .indexed_zero_x = .init(0xD6, 6),
            .absolute = .init(0xCE, 6),
            .indexed_absolute_x = .init(0xDE, 7),
        }),
    };
    pub const DEX = Instruction.Type{
        .mnemonic = "DEX",
        .description = "decrement X",
        .available_modes = .init(.{
            .implicit = .init(0xCA, 2),
        }),
    };
    pub const DEY = Instruction.Type{
        .mnemonic = "DEY",
        .description = "decrement Y",
        .available_modes = .init(.{
            .implicit = .init(0x88, 2),
        }),
    };
    pub const EOR = Instruction.Type{
        .mnemonic = "EOR",
        .description = "exclusive or (with accumulator)",
        .available_modes = .init(.{
            .immediate = .init(0x49, 2),
            .zero = .init(0x45, 3),
            .indexed_zero_x = .init(0x55, 4),
            .absolute = .init(0x4D, 4),
            .indexed_absolute_x = .init(0x5D, 4),
            .indexed_absolute_y = .init(0x59, 4),
            .pre_indexed_indirect_zero_x = .init(0x41, 6),
            .post_indexed_indirect_zero_y = .init(0x51, 5),
        }),
    };
    pub const INC = Instruction.Type{
        .mnemonic = "INC",
        .description = "increment",
        .available_modes = .init(.{
            .zero = .init(0xE6, 5),
            .indexed_zero_x = .init(0xF6, 6),
            .absolute = .init(0xEE, 6),
            .indexed_absolute_x = .init(0xFE, 7),
        }),
    };
    pub const INX = Instruction.Type{
        .mnemonic = "INX",
        .description = "increment X",
        .available_modes = .init(.{
            .implicit = .init(0xE8, 2),
        }),
    };
    pub const INY = Instruction.Type{
        .mnemonic = "INY",
        .description = "increment Y",
        .available_modes = .init(.{
            .implicit = .init(0xC8, 2),
        }),
    };
    pub const JMP = Instruction.Type{
        .mnemonic = "JMP",
        .description = "jump",
        .available_modes = .init(.{
            .absolute = .init(0x4C, 3),
            .indirect_absolute = .init(0x6C, 5),
        }),
    };
    pub const JSR = Instruction.Type{
        .mnemonic = "JSR",
        .description = "jump subroutine",
        .available_modes = .init(.{
            .absolute = .init(0x20, 6),
        }),
    };
    pub const LDA = Instruction.Type{
        .mnemonic = "LDA",
        .description = "load accumulator",
        .available_modes = .init(.{
            .immediate = .init(0xA9, 2),
            .zero = .init(0xA5, 3),
            .indexed_zero_x = .init(0xB5, 4),
            .absolute = .init(0xAD, 4),
            .indexed_absolute_x = .init(0xBD, 4),
            .indexed_absolute_y = .init(0xB9, 4),
            .pre_indexed_indirect_zero_x = .init(0xA1, 6),
            .post_indexed_indirect_zero_y = .init(0xB1, 5),
        }),
    };
    pub const LDX = Instruction.Type{
        .mnemonic = "LDX",
        .description = "load X",
        .available_modes = .init(.{
            .immediate = .init(0xA2, 2),
            .zero = .init(0xA6, 3),
            .indexed_zero_y = .init(0xB6, 4),
            .absolute = .init(0xAE, 4),
            .indexed_absolute_y = .init(0xBE, 4),
        }),
    };
    pub const LDY = Instruction.Type{
        .mnemonic = "LDY",
        .description = "load Y",
        .available_modes = .init(.{
            .immediate = .init(0xA0, 2),
            .zero = .init(0xA4, 3),
            .indexed_zero_x = .init(0xB4, 4),
            .absolute = .init(0xAC, 4),
            .indexed_absolute_x = .init(0xBC, 4),
        }),
    };
    pub const LSR = Instruction.Type{
        .mnemonic = "LSR",
        .description = "logical shift right",
        .available_modes = .init(.{
            .implicit = .init(0x4A, 2),
            .zero = .init(0x46, 5),
            .indexed_zero_x = .init(0x56, 6),
            .absolute = .init(0x4E, 6),
            .indexed_absolute_x = .init(0x5E, 7),
        }),
    };
    pub const NOP = Instruction.Type{
        .mnemonic = "NOP",
        .description = "no operation",
        .available_modes = .init(.{
            .implicit = .init(0xEA, 2),
        }),
    };
    pub const ORA = Instruction.Type{
        .mnemonic = "ORA",
        .description = "or with accumulator",
        .available_modes = .init(.{
            .immediate = .init(0x09, 2),
            .zero = .init(0x05, 3),
            .indexed_zero_x = .init(0x15, 4),
            .absolute = .init(0x0D, 4),
            .indexed_absolute_x = .init(0x1D, 4),
            .indexed_absolute_y = .init(0x19, 4),
            .pre_indexed_indirect_zero_x = .init(0x01, 6),
            .post_indexed_indirect_zero_y = .init(0x11, 5),
        }),
    };
    pub const PHA = Instruction.Type{
        .mnemonic = "PHA",
        .description = "push accumulator",
        .available_modes = .init(.{
            .implicit = .init(0x48, 3),
        }),
    };
    pub const PHP = Instruction.Type{
        .mnemonic = "PHP",
        .description = "push processor status (SR)",
        .available_modes = .init(.{
            .implicit = .init(0x08, 3),
        }),
    };
    pub const PLA = Instruction.Type{
        .mnemonic = "PLA",
        .description = "pull accumulator",
        .available_modes = .init(.{
            .implicit = .init(0x68, 4),
        }),
    };
    pub const PLP = Instruction.Type{
        .mnemonic = "PLP",
        .description = "pull processor status (SR)",
        .available_modes = .init(.{
            .implicit = .init(0x28, 4),
        }),
    };
    pub const ROL = Instruction.Type{
        .mnemonic = "ROL",
        .description = "rotate left",
        .available_modes = .init(.{
            .implicit = .init(0x2A, 2),
            .zero = .init(0x26, 5),
            .indexed_zero_x = .init(0x36, 6),
            .absolute = .init(0x2E, 6),
            .indexed_absolute_x = .init(0x3E, 7),
        }),
    };
    pub const ROR = Instruction.Type{
        .mnemonic = "ROR",
        .description = "rotate right",
        .available_modes = .init(.{
            .implicit = .init(0x6A, 2),
            .zero = .init(0x66, 5),
            .indexed_zero_x = .init(0x76, 6),
            .absolute = .init(0x6E, 6),
            .indexed_absolute_x = .init(0x7E, 7),
        }),
    };
    pub const RTI = Instruction.Type{
        .mnemonic = "RTI",
        .description = "return from interrupt",
        .available_modes = .init(.{
            .implicit = .init(0x40, 6),
        }),
    };
    pub const RTS = Instruction.Type{
        .mnemonic = "RTS",
        .description = "return from subroutine",
        .available_modes = .init(.{
            .implicit = .init(0x60, 6),
        }),
    };
    pub const SBC = Instruction.Type{
        .mnemonic = "SBC",
        .description = "subtract with carry",
        .available_modes = .init(.{
            .immediate = .init(0xE9, 2),
            .zero = .init(0xE5, 3),
            .indexed_zero_x = .init(0xF5, 4),
            .absolute = .init(0xED, 4),
            .indexed_absolute_x = .init(0xFD, 4),
            .indexed_absolute_y = .init(0xF9, 4),
            .pre_indexed_indirect_zero_x = .init(0xE1, 6),
            .post_indexed_indirect_zero_y = .init(0xF1, 5),
        }),
    };
    pub const SEC = Instruction.Type{
        .mnemonic = "SEC",
        .description = "set carry",
        .available_modes = .init(.{
            .implicit = .init(0x38, 2),
        }),
    };
    pub const SED = Instruction.Type{
        .mnemonic = "SED",
        .description = "set decimal",
        .available_modes = .init(.{
            .implicit = .init(0xF8, 2),
        }),
    };
    pub const SEI = Instruction.Type{
        .mnemonic = "SEI",
        .description = "set interrupt disable",
        .available_modes = .init(.{
            .implicit = .init(0x78, 2),
        }),
    };
    pub const STA = Instruction.Type{
        .mnemonic = "STA",
        .description = "store accumulator",
        .available_modes = .init(.{
            .zero = .init(0x85, 3),
            .indexed_zero_x = .init(0x95, 4),
            .absolute = .init(0x8D, 4),
            .indexed_absolute_x = .init(0x9D, 5),
            .indexed_absolute_y = .init(0x99, 5),
            .pre_indexed_indirect_zero_x = .init(0x81, 6),
            .post_indexed_indirect_zero_y = .init(0x91, 6),
        }),
    };
    pub const STX = Instruction.Type{
        .mnemonic = "STX",
        .description = "store X",
        .available_modes = .init(.{
            .zero = .init(0x86, 3),
            .indexed_zero_y = .init(0x96, 4),
            .absolute = .init(0x8E, 4),
        }),
    };
    pub const STY = Instruction.Type{
        .mnemonic = "STY",
        .description = "store Y",
        .available_modes = .init(.{
            .zero = .init(0x84, 3),
            .indexed_zero_x = .init(0x94, 4),
            .absolute = .init(0x8C, 4),
        }),
    };
    pub const TAX = Instruction.Type{
        .mnemonic = "TAX",
        .description = "transfer accumulator to X",
        .available_modes = .init(.{
            .implicit = .init(0xAA, 2),
        }),
    };
    pub const TAY = Instruction.Type{
        .mnemonic = "TAY",
        .description = "transfer accumulator to Y",
        .available_modes = .init(.{
            .implicit = .init(0xA8, 2),
        }),
    };
    pub const TSX = Instruction.Type{
        .mnemonic = "TSX",
        .description = "transfer stack pointer to X",
        .available_modes = .init(.{
            .implicit = .init(0xBA, 2),
        }),
    };
    pub const TXA = Instruction.Type{
        .mnemonic = "TXA",
        .description = "transfer X to accumulator",
        .available_modes = .init(.{
            .implicit = .init(0x8A, 2),
        }),
    };
    pub const TXS = Instruction.Type{
        .mnemonic = "TXS",
        .description = "transfer X to stack pointer",
        .available_modes = .init(.{
            .implicit = .init(0x9A, 2),
        }),
    };
    pub const TYA = Instruction.Type{
        .mnemonic = "TYA",
        .description = "transfer Y to accumulator",
        .available_modes = .init(.{
            .implicit = .init(0x98, 2),
        }),
    };
};

const n_max_opcodes = 0x100;
const opcode_mode_table: [n_max_opcodes]?Instruction.AddressingModeTag = brk: {
    var ot: [n_max_opcodes]?Instruction.AddressingModeTag = .{null} ** n_max_opcodes;
    ot[0x00] = .implicit;
    ot[0x01] = .pre_indexed_indirect_zero_x;
    ot[0x05] = .zero;
    ot[0x06] = .zero;
    ot[0x08] = .implicit;
    ot[0x09] = .immediate;
    ot[0x0A] = .implicit;
    ot[0x0D] = .absolute;
    ot[0x0E] = .absolute;
    ot[0x10] = .relative;
    ot[0x11] = .post_indexed_indirect_zero_y;
    ot[0x15] = .indexed_zero_x;
    ot[0x16] = .indexed_zero_x;
    ot[0x18] = .implicit;
    ot[0x19] = .indexed_absolute_y;
    ot[0x1D] = .indexed_absolute_x;
    ot[0x1E] = .indexed_absolute_x;
    ot[0x20] = .absolute;
    ot[0x21] = .pre_indexed_indirect_zero_x;
    ot[0x24] = .zero;
    ot[0x25] = .zero;
    ot[0x26] = .zero;
    ot[0x28] = .implicit;
    ot[0x29] = .immediate;
    ot[0x2A] = .implicit;
    ot[0x2C] = .absolute;
    ot[0x2D] = .absolute;
    ot[0x2E] = .absolute;
    ot[0x30] = .relative;
    ot[0x31] = .post_indexed_indirect_zero_y;
    ot[0x35] = .indexed_zero_x;
    ot[0x36] = .indexed_zero_x;
    ot[0x38] = .implicit;
    ot[0x39] = .indexed_absolute_y;
    ot[0x3D] = .indexed_absolute_x;
    ot[0x3E] = .indexed_absolute_x;
    ot[0x40] = .implicit;
    ot[0x41] = .pre_indexed_indirect_zero_x;
    ot[0x45] = .zero;
    ot[0x46] = .zero;
    ot[0x48] = .implicit;
    ot[0x49] = .immediate;
    ot[0x4A] = .implicit;
    ot[0x4C] = .absolute;
    ot[0x4D] = .absolute;
    ot[0x4E] = .absolute;
    ot[0x50] = .relative;
    ot[0x51] = .post_indexed_indirect_zero_y;
    ot[0x55] = .indexed_zero_x;
    ot[0x56] = .indexed_zero_x;
    ot[0x58] = .implicit;
    ot[0x59] = .indexed_absolute_y;
    ot[0x5D] = .indexed_absolute_x;
    ot[0x5E] = .indexed_absolute_x;
    ot[0x60] = .implicit;
    ot[0x61] = .pre_indexed_indirect_zero_x;
    ot[0x65] = .zero;
    ot[0x66] = .zero;
    ot[0x68] = .implicit;
    ot[0x69] = .immediate;
    ot[0x6A] = .implicit;
    ot[0x6C] = .indirect_absolute;
    ot[0x6D] = .absolute;
    ot[0x6E] = .absolute;
    ot[0x70] = .relative;
    ot[0x71] = .post_indexed_indirect_zero_y;
    ot[0x75] = .indexed_zero_x;
    ot[0x76] = .indexed_zero_x;
    ot[0x78] = .implicit;
    ot[0x79] = .indexed_absolute_y;
    ot[0x7D] = .indexed_absolute_x;
    ot[0x7E] = .indexed_absolute_x;
    ot[0x81] = .pre_indexed_indirect_zero_x;
    ot[0x84] = .zero;
    ot[0x85] = .zero;
    ot[0x86] = .zero;
    ot[0x88] = .implicit;
    ot[0x8A] = .implicit;
    ot[0x8C] = .absolute;
    ot[0x8D] = .absolute;
    ot[0x8E] = .absolute;
    ot[0x90] = .relative;
    ot[0x91] = .post_indexed_indirect_zero_y;
    ot[0x94] = .indexed_zero_x;
    ot[0x95] = .indexed_zero_x;
    ot[0x96] = .indexed_zero_y;
    ot[0x98] = .implicit;
    ot[0x99] = .indexed_absolute_y;
    ot[0x9A] = .implicit;
    ot[0x9D] = .indexed_absolute_x;
    ot[0xA0] = .immediate;
    ot[0xA1] = .pre_indexed_indirect_zero_x;
    ot[0xA2] = .immediate;
    ot[0xA4] = .zero;
    ot[0xA5] = .zero;
    ot[0xA6] = .zero;
    ot[0xA8] = .implicit;
    ot[0xA9] = .immediate;
    ot[0xAA] = .implicit;
    ot[0xAC] = .absolute;
    ot[0xAD] = .absolute;
    ot[0xAE] = .absolute;
    ot[0xB0] = .relative;
    ot[0xB1] = .post_indexed_indirect_zero_y;
    ot[0xB4] = .indexed_zero_x;
    ot[0xB5] = .indexed_zero_x;
    ot[0xB6] = .indexed_zero_y;
    ot[0xB8] = .implicit;
    ot[0xB9] = .indexed_absolute_y;
    ot[0xBA] = .implicit;
    ot[0xBC] = .indexed_absolute_x;
    ot[0xBD] = .indexed_absolute_x;
    ot[0xBE] = .indexed_absolute_y;
    ot[0xC0] = .immediate;
    ot[0xC1] = .pre_indexed_indirect_zero_x;
    ot[0xC4] = .zero;
    ot[0xC5] = .zero;
    ot[0xC6] = .zero;
    ot[0xC8] = .implicit;
    ot[0xC9] = .immediate;
    ot[0xCA] = .implicit;
    ot[0xCC] = .absolute;
    ot[0xCD] = .absolute;
    ot[0xCE] = .absolute;
    ot[0xD0] = .relative;
    ot[0xD1] = .post_indexed_indirect_zero_y;
    ot[0xD5] = .indexed_zero_x;
    ot[0xD6] = .indexed_zero_x;
    ot[0xD8] = .implicit;
    ot[0xD9] = .indexed_absolute_y;
    ot[0xDD] = .indexed_absolute_x;
    ot[0xDE] = .indexed_absolute_x;
    ot[0xE0] = .immediate;
    ot[0xE1] = .pre_indexed_indirect_zero_x;
    ot[0xE4] = .zero;
    ot[0xE5] = .zero;
    ot[0xE6] = .zero;
    ot[0xE8] = .implicit;
    ot[0xE9] = .immediate;
    ot[0xEA] = .implicit;
    ot[0xEC] = .absolute;
    ot[0xED] = .absolute;
    ot[0xEE] = .absolute;
    ot[0xF0] = .relative;
    ot[0xF1] = .post_indexed_indirect_zero_y;
    ot[0xF5] = .indexed_zero_x;
    ot[0xF6] = .indexed_zero_x;
    ot[0xF8] = .implicit;
    ot[0xF9] = .indexed_absolute_y;
    ot[0xFD] = .indexed_absolute_x;
    ot[0xFE] = .indexed_absolute_x;
    break :brk ot;
};

const opcode_type_table: [n_max_opcodes]?*const Instruction.Type = brk: {
    var ot: [n_max_opcodes]?*const Instruction.Type = .{null} ** n_max_opcodes;
    ot[0x69] = &Instructions.ADC;
    ot[0x65] = &Instructions.ADC;
    ot[0x75] = &Instructions.ADC;
    ot[0x6D] = &Instructions.ADC;
    ot[0x7D] = &Instructions.ADC;
    ot[0x79] = &Instructions.ADC;
    ot[0x61] = &Instructions.ADC;
    ot[0x71] = &Instructions.ADC;
    ot[0x29] = &Instructions.AND;
    ot[0x25] = &Instructions.AND;
    ot[0x35] = &Instructions.AND;
    ot[0x2D] = &Instructions.AND;
    ot[0x3D] = &Instructions.AND;
    ot[0x39] = &Instructions.AND;
    ot[0x21] = &Instructions.AND;
    ot[0x31] = &Instructions.AND;
    ot[0x0A] = &Instructions.ASL;
    ot[0x06] = &Instructions.ASL;
    ot[0x16] = &Instructions.ASL;
    ot[0x0E] = &Instructions.ASL;
    ot[0x1E] = &Instructions.ASL;
    ot[0x90] = &Instructions.BCC;
    ot[0xB0] = &Instructions.BCS;
    ot[0xF0] = &Instructions.BEQ;
    ot[0x24] = &Instructions.BIT;
    ot[0x2C] = &Instructions.BIT;
    ot[0x30] = &Instructions.BMI;
    ot[0xD0] = &Instructions.BNE;
    ot[0x10] = &Instructions.BPL;
    ot[0x00] = &Instructions.BRK;
    ot[0x50] = &Instructions.BVC;
    ot[0x70] = &Instructions.BVS;
    ot[0x18] = &Instructions.CLC;
    ot[0xD8] = &Instructions.CLD;
    ot[0x58] = &Instructions.CLI;
    ot[0xB8] = &Instructions.CLV;
    ot[0xC9] = &Instructions.CMP;
    ot[0xC5] = &Instructions.CMP;
    ot[0xD5] = &Instructions.CMP;
    ot[0xCD] = &Instructions.CMP;
    ot[0xDD] = &Instructions.CMP;
    ot[0xD9] = &Instructions.CMP;
    ot[0xC1] = &Instructions.CMP;
    ot[0xD1] = &Instructions.CMP;
    ot[0xE0] = &Instructions.CPX;
    ot[0xE4] = &Instructions.CPX;
    ot[0xEC] = &Instructions.CPX;
    ot[0xC0] = &Instructions.CPY;
    ot[0xC4] = &Instructions.CPY;
    ot[0xCC] = &Instructions.CPY;
    ot[0xC6] = &Instructions.DEC;
    ot[0xD6] = &Instructions.DEC;
    ot[0xCE] = &Instructions.DEC;
    ot[0xDE] = &Instructions.DEC;
    ot[0xCA] = &Instructions.DEX;
    ot[0x88] = &Instructions.DEY;
    ot[0x49] = &Instructions.EOR;
    ot[0x45] = &Instructions.EOR;
    ot[0x55] = &Instructions.EOR;
    ot[0x4D] = &Instructions.EOR;
    ot[0x5D] = &Instructions.EOR;
    ot[0x59] = &Instructions.EOR;
    ot[0x41] = &Instructions.EOR;
    ot[0x51] = &Instructions.EOR;
    ot[0xE6] = &Instructions.INC;
    ot[0xF6] = &Instructions.INC;
    ot[0xEE] = &Instructions.INC;
    ot[0xFE] = &Instructions.INC;
    ot[0xE8] = &Instructions.INX;
    ot[0xC8] = &Instructions.INY;
    ot[0x4C] = &Instructions.JMP;
    ot[0x6C] = &Instructions.JMP;
    ot[0x20] = &Instructions.JSR;
    ot[0xA9] = &Instructions.LDA;
    ot[0xA5] = &Instructions.LDA;
    ot[0xB5] = &Instructions.LDA;
    ot[0xAD] = &Instructions.LDA;
    ot[0xBD] = &Instructions.LDA;
    ot[0xB9] = &Instructions.LDA;
    ot[0xA1] = &Instructions.LDA;
    ot[0xB1] = &Instructions.LDA;
    ot[0xA2] = &Instructions.LDX;
    ot[0xA6] = &Instructions.LDX;
    ot[0xB6] = &Instructions.LDX;
    ot[0xAE] = &Instructions.LDX;
    ot[0xBE] = &Instructions.LDX;
    ot[0xA0] = &Instructions.LDY;
    ot[0xA4] = &Instructions.LDY;
    ot[0xB4] = &Instructions.LDY;
    ot[0xAC] = &Instructions.LDY;
    ot[0xBC] = &Instructions.LDY;
    ot[0x4A] = &Instructions.LSR;
    ot[0x46] = &Instructions.LSR;
    ot[0x56] = &Instructions.LSR;
    ot[0x4E] = &Instructions.LSR;
    ot[0x5E] = &Instructions.LSR;
    ot[0xEA] = &Instructions.NOP;
    ot[0x09] = &Instructions.ORA;
    ot[0x05] = &Instructions.ORA;
    ot[0x15] = &Instructions.ORA;
    ot[0x0D] = &Instructions.ORA;
    ot[0x1D] = &Instructions.ORA;
    ot[0x19] = &Instructions.ORA;
    ot[0x01] = &Instructions.ORA;
    ot[0x11] = &Instructions.ORA;
    ot[0x48] = &Instructions.PHA;
    ot[0x08] = &Instructions.PHP;
    ot[0x68] = &Instructions.PLA;
    ot[0x28] = &Instructions.PLP;
    ot[0x2A] = &Instructions.ROL;
    ot[0x26] = &Instructions.ROL;
    ot[0x36] = &Instructions.ROL;
    ot[0x2E] = &Instructions.ROL;
    ot[0x3E] = &Instructions.ROL;
    ot[0x6A] = &Instructions.ROR;
    ot[0x66] = &Instructions.ROR;
    ot[0x76] = &Instructions.ROR;
    ot[0x6E] = &Instructions.ROR;
    ot[0x7E] = &Instructions.ROR;
    ot[0x40] = &Instructions.RTI;
    ot[0x60] = &Instructions.RTS;
    ot[0xE9] = &Instructions.SBC;
    ot[0xE5] = &Instructions.SBC;
    ot[0xF5] = &Instructions.SBC;
    ot[0xED] = &Instructions.SBC;
    ot[0xFD] = &Instructions.SBC;
    ot[0xF9] = &Instructions.SBC;
    ot[0xE1] = &Instructions.SBC;
    ot[0xF1] = &Instructions.SBC;
    ot[0x38] = &Instructions.SEC;
    ot[0xF8] = &Instructions.SED;
    ot[0x78] = &Instructions.SEI;
    ot[0x85] = &Instructions.STA;
    ot[0x95] = &Instructions.STA;
    ot[0x8D] = &Instructions.STA;
    ot[0x9D] = &Instructions.STA;
    ot[0x99] = &Instructions.STA;
    ot[0x81] = &Instructions.STA;
    ot[0x91] = &Instructions.STA;
    ot[0x86] = &Instructions.STX;
    ot[0x96] = &Instructions.STX;
    ot[0x8E] = &Instructions.STX;
    ot[0x84] = &Instructions.STY;
    ot[0x94] = &Instructions.STY;
    ot[0x8C] = &Instructions.STY;
    ot[0xAA] = &Instructions.TAX;
    ot[0xA8] = &Instructions.TAY;
    ot[0xBA] = &Instructions.TSX;
    ot[0x8A] = &Instructions.TXA;
    ot[0x9A] = &Instructions.TXS;
    ot[0x98] = &Instructions.TYA;
    break :brk ot;
};
