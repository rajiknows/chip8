const std = @import("std");

pub const DISPLAY_WIDTH = 64;
pub const DISPLAY_HEIGHT = 32;

const MEMORY_SIZE = 4096;
const REGISTER_COUNT = 16;
const STACK_SIZE = 16;
const FONTSET_SIZE = 80;
const FONTSET_START_ADDRESS = 0x50;
const START_ADDRESS = 0x200;

const fontset = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub const CHIP8 = struct {
    opcode: u16,
    memory: [MEMORY_SIZE]u8,
    registers: [REGISTER_COUNT]u8,
    index: u16,
    pc: u16,
    display: [DISPLAY_WIDTH * DISPLAY_HEIGHT]u8,
    delay_timer: u8,
    sound_timer: u8,
    stack: [STACK_SIZE]u16,
    sp: u16,
    keypad: [16]u8,

    pub fn init(self: *CHIP8) void {
        self.* = .{
            .opcode = 0,
            .memory = [_]u8{0} ** MEMORY_SIZE,
            .registers = [_]u8{0} ** REGISTER_COUNT,
            .index = 0,
            .pc = START_ADDRESS,
            .display = [_]u8{0} ** (DISPLAY_WIDTH * DISPLAY_HEIGHT),
            .delay_timer = 0,
            .sound_timer = 0,
            .stack = [_]u16{0} ** STACK_SIZE,
            .sp = 0,
            .keypad = [_]u8{0} ** 16,
        };
        for (fontset, 0..) |b, i| {
            self.memory[FONTSET_START_ADDRESS + i] = b;
        }
    }

    pub fn loadRom(self: *CHIP8, rom: []const u8) void {
        const start = START_ADDRESS;
        const limit = MEMORY_SIZE - start;
        const size = @min(rom.len, limit);
        for (0..size) |i| {
            self.memory[start + i] = rom[i];
        }
    }

    pub fn cycle(self: *CHIP8) void {
        self.opcode = (@as(u16, self.memory[self.pc]) << 8) | self.memory[self.pc + 1];
        self.pc += 2;
        self.executeOpcode();
        if (self.delay_timer > 0) self.delay_timer -= 1;
        if (self.sound_timer > 0) self.sound_timer -= 1;
    }

    fn executeOpcode(self: *CHIP8) void {
        const x = (self.opcode & 0x0F00) >> 8;
        const y = (self.opcode & 0x00F0) >> 4;
        const n = self.opcode & 0x000F;
        const nn = self.opcode & 0x00FF;
        const nnn = self.opcode & 0x0FFF;

        switch (self.opcode & 0xF000) {
            0x0000 => switch (self.opcode) {
                0x00E0 => {
                    for (&self.display) |*p| p.* = 0;
                },
                0x00EE => {
                    self.sp -= 1;
                    self.pc = self.stack[self.sp];
                },
                else => {},
            },
            0x1000 => self.pc = nnn,
            0x2000 => {
                self.pc = nnn;
            },

            0x6000 => self.registers[x] = @intCast(nn),
            0x7000 => self.registers[x] = @intCast((@as(u16, self.registers[x]) + nn) & 0xFF),
            0x8000 => {
                switch (self.opcode) {
                    0x8001 => self.registers[x] = self.registers[y],
                    0x8001 => self.registers[x] = self.registers[x] | self.registers[y],
                    0x8002 => self.registers[x] = self.registers[x] & self.registers[y],
                    0x8003 => self.registers[x] = self.registers[x] ^ self.registers[y],
                    0x8004 => self.registers[x] = self.registers[x] + self.registers[y],
                    0x8005 => self.registers[x] = self.registers[x] - self.registers[y],
                    0x8007 => self.registers[x] = self.registers[y] - self.registers[x],
                }
            },
            0xA000 => self.index = nnn,
            0xC000 => {
                // generate a random number
                var prng = std.rand.DefaultPrng.init(@intCast(u64, std.time.nanoTimestamp()));
                const random = prng.random();
                const value = random.intRange(u32, 0, nn);
                self.registers[x] = value & self.registers[nn];
            },
            0xD000 => self.drawSprite(@intCast(x), @intCast(y), @intCast(n)),
            0xf000 => {
                switch (self.opcode) {
                    0xF007 => self.registers[x] = self.delay_timer,
                    0xF015 => self.delay_timer = self.registers[x],
                    0xF018 => self.registers[x] = self.sound_timer,
                }
            },
            else => {},
        }
    }

    fn drawSprite(self: *CHIP8, vx: u8, vy: u8, height: u8) void {
        const x = self.registers[vx] % DISPLAY_WIDTH;
        const y = self.registers[vy] % DISPLAY_HEIGHT;
        self.registers[0xF] = 0;

        for (0..height) |row| {
            const byte = self.memory[self.index + row];
            for (0..8) |col| {
                const pixel = (byte >> @intCast(7 - col)) & 1;
                const sx = (x + col) % DISPLAY_WIDTH;
                const sy = (y + row) % DISPLAY_HEIGHT;
                const idx = sy * DISPLAY_WIDTH + sx;
                if (pixel == 1) {
                    if (self.display[idx] == 1) self.registers[0xF] = 1;
                    self.display[idx] ^= 1;
                }
            }
        }
    }

    pub fn setKey(self: *CHIP8, key: u8, pressed: bool) void {
        if (key < 16) self.keypad[key] = if (pressed) 1 else 0;
    }
};
