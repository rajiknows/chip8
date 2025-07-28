const std = @import("std");
const chip8 = @import("chip8.zig");

var cpu: chip8.CHIP8 = undefined;

export fn _start() void {} // Needed for WASM

pub export fn init() void {
    cpu.init();
}

pub export fn load_rom(ptr: [*]const u8, len: usize) void {
    const rom = ptr[0..len];
    cpu.loadRom(rom);
}

pub export fn tick() void {
    cpu.cycle();
}

pub export fn get_display() [*]const u8 {
    return &cpu.display;
}

pub export fn key_down(key: u8) void {
    cpu.setKey(key, true);
}

pub export fn key_up(key: u8) void {
    cpu.setKey(key, false);
}
