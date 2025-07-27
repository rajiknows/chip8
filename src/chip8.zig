const std = @import("std");

const CHIP8 = @This();

// CHIP-8 specifications
const MEMORY_SIZE = 4096;
const REGISTER_COUNT = 16;
const STACK_SIZE = 16;
pub const DISPLAY_WIDTH = 64;
pub const DISPLAY_HEIGHT = 32;
const FONTSET_SIZE = 80;
const FONTSET_START_ADDRESS = 0x50;
const START_ADDRESS = 0x200;

// CHIP-8 fontset
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

// CHIP-8 system state
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
    // Initialize PC
    self.pc = START_ADDRESS;

    // Clear display, keypad, registers, and memory
    self.opcode = 0;
    self.index = 0;
    self.sp = 0;
    self.delay_timer = 0;
    self.sound_timer = 0;

    // Clear memory
    for (0..MEMORY_SIZE) |i| {
        self.memory[i] = 0;
    }

    // Clear registers
    for (0..REGISTER_COUNT) |i| {
        self.registers[i] = 0;
    }

    // Clear display
    for (0..DISPLAY_WIDTH * DISPLAY_HEIGHT) |i| {
        self.display[i] = 0;
    }

    // Clear stack
    for (0..STACK_SIZE) |i| {
        self.stack[i] = 0;
    }

    // Clear keypad
    for (0..16) |i| {
        self.keypad[i] = 0;
    }

    // Load fontset into memory
    for (0..FONTSET_SIZE) |i| {
        self.memory[FONTSET_START_ADDRESS + i] = fontset[i];
    }
}

pub fn loadRom(self: *CHIP8, rom_data: []const u8) void {
    std.debug.print("Loading ROM: {} bytes\n", .{rom_data.len});

    // Load ROM into memory starting at 0x200
    const start: usize = START_ADDRESS;
    const max_rom_size = MEMORY_SIZE - start;
    const bytes_to_load = @min(rom_data.len, max_rom_size);

    std.debug.print("Start address: 0x{X}, Max ROM size: {}, Bytes to load: {}\n", .{ start, max_rom_size, bytes_to_load });

    if (rom_data.len > max_rom_size) {
        std.debug.print("ROM size exceeds the max memory limit\n", .{});
        return;
    }

    // Bounds check
    if (start + bytes_to_load > MEMORY_SIZE) {
        std.debug.print("ERROR: Would write past memory bounds!\n", .{});
        return;
    }

    // Copy ROM data into memory using a simple loop for safety
    for (0..bytes_to_load) |i| {
        self.memory[start + i] = rom_data[i];
    }

    std.debug.print("Loaded {} bytes into memory at 0x{X}\n", .{ bytes_to_load, start });
}

pub fn cycle(self: *CHIP8) void {
    // Fetch opcode
    self.opcode = (@as(u16, self.memory[self.pc]) << 8) | self.memory[self.pc + 1];

    // Increment program counter
    self.pc += 2;

    // Decode and execute opcode
    self.executeOpcode();

    // Update timers
    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }

    if (self.sound_timer > 0) {
        self.sound_timer -= 1;
    }
}

fn executeOpcode(self: *CHIP8) void {
    const x = (self.opcode & 0x0F00) >> 8;
    const y = (self.opcode & 0x00F0) >> 4;
    const n = self.opcode & 0x000F;
    const nn = self.opcode & 0x00FF;
    const nnn = self.opcode & 0x0FFF;

    switch (self.opcode & 0xF000) {
        0x0000 => {
            switch (self.opcode) {
                0x00E0 => {
                    // Clear display
                    for (0..DISPLAY_WIDTH * DISPLAY_HEIGHT) |i| {
                        self.display[i] = 0;
                    }
                },
                0x00EE => {
                    // Return from subroutine
                    self.sp -= 1;
                    self.pc = self.stack[self.sp];
                },
                else => {
                    // Jump to machine code routine (ignored in modern interpreters)
                },
            }
        },
        0x1000 => {
            // Jump to address NNN
            self.pc = nnn;
        },
        0x6000 => {
            // Set register VX to NN
            self.registers[x] = @intCast(nn);
        },
        0x7000 => {
            // Add NN to register VX
            self.registers[x] = @intCast((@as(u16, self.registers[x]) + nn) & 0xFF);
        },
        0xA000 => {
            // Set index register to NNN
            self.index = nnn;
        },
        0xD000 => {
            // Draw sprite
            self.drawSprite(@intCast(x), @intCast(y), @intCast(n));
        },
        else => {
            // Unknown opcode
            std.debug.print("Unknown opcode: 0x{X}\n", .{self.opcode});
        },
    }
}

fn drawSprite(self: *CHIP8, vx: u8, vy: u8, height: u8) void {
    const x_pos = self.registers[vx] % DISPLAY_WIDTH;
    const y_pos = self.registers[vy] % DISPLAY_HEIGHT;

    self.registers[0xF] = 0; // Clear collision flag

    for (0..height) |row| {
        const sprite_byte = self.memory[self.index + row];

        for (0..8) |col| {
            const sprite_pixel = (sprite_byte >> @intCast(7 - col)) & 1;
            const screen_x = (x_pos + col) % DISPLAY_WIDTH;
            const screen_y = (y_pos + row) % DISPLAY_HEIGHT;
            const screen_index = screen_y * DISPLAY_WIDTH + screen_x;

            if (sprite_pixel == 1) {
                if (self.display[screen_index] == 1) {
                    self.registers[0xF] = 1; // Collision detected
                }
                self.display[screen_index] ^= 1;
            }
        }
    }
}

pub fn setKey(self: *CHIP8, key: u8, pressed: bool) void {
    if (key < 16) {
        self.keypad[key] = if (pressed) 1 else 0;
    }
}
