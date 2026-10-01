const ifc = @import("interface.zig");
const Byte = ifc.Byte;
const ReadWrite = ifc.ReadWrite;
const SevenBits = ifc.SevenBits;

/// MEMORY, I/O, TIMER ARRAY
pub const MOS6532 = struct {
    address_bus: SevenBits = .zero,
    data_bus: Byte = .zero,
    memory: [128]Byte = undefined,
    inputs: packed struct(u5) {
        clock: u1 = 0,
        read_write: ReadWrite = .write,
        select: packed struct(u3) {
            chip_select: packed struct(u2) {
                cs1: u1 = 0,
                cs2: u1 = 0,

                pub const zero = @This(){};

                pub const select_ram = @This(){
                    .cs1 = 1,
                    .cs2 = 0,
                };
            },
            ram_select: u1 = 0,

            pub const zero = @This(){};

            pub const select_ram = @This(){
                .chip_select = .select_ram,
                .ram_select = 0,
            };
        } = .zero,

        pub const zero = @This(){};

        pub const read_ram = @This(){
            .clock = 1,
            .read_write = .read,
            .select = .select_ram,
        };

        pub const write_ram = @This(){
            .clock = 1,
            .read_write = .write,
            .select = .select_ram,
        };

        pub fn toInt(self: @This()) u4 {
            return @bitCast(self);
        }

        pub fn is(self: @This(), other: @This()) bool {
            return self.toInt() == other.toInt();
        }
    } = .zero,

    pub fn update(self: *@This()) void {
        if (self.inputs.is(.read_ram)) {
            self.readRam();
        } else if (self.inputs.is(.write_ram)) {
            self.writeRam();
        }
    }

    fn readRam(self: *@This()) void {
        const addr = self.address_bus.toInt();
        const mem = self.memory[addr];
        self.data_bus = mem;
    }

    fn writeRam(self: *@This()) void {
        const addr = self.address_bus.toInt();
        const mem = &self.memory[addr];
        mem.* = self.data_bus;
    }
};
