const std = @import("std");
// const rl = @import("raylib");
const CHIP8 = @import("chip8.zig");

const screenWidth = 800;
const screenHeight = 600;
const SCALE = 16;

var cpu: CHIP8 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    cpu.init();

    if (args.len > 1) {
        try loadRom(allocator, args[1]);
    } else {
        std.debug.print("Usage: {s} <rom_file>\n", .{args[0]});

        // Load a simple test program
        // const test_program = [_]u8{
        //     0xA2, 0x2A, // Set I to 0x22A
        //     0x60, 0x0C, // Set V0 to 12
        //     0x61, 0x08, // Set V1 to 8
        //     0xD0, 0x1F, // Draw sprite at (V0, V1) with height F
        //     0x12, 0x00, // Jump to 0x200 (infinite loop)
        // };

        const simple_game = [_]u8{
            // Initialize variables
            0xA2, 0x2A, // Set I to sprite location (0x22A)
            0x60, 0x10, // Set V0 = 16 (X position)
            0x61, 0x08, // Set V1 = 8  (Y position)
            0x62, 0x01, // Set V2 = 1  (X velocity)
            0x63, 0x01, // Set V3 = 1  (Y velocity)
            0x64, 0x3C, // Set V4 = 60 (X boundary)
            0x65, 0x1C, // Set V5 = 28 (Y boundary)

            // Main loop (starts at 0x20E)
            0x00, 0xE0, // Clear screen
            0xD0, 0x14, // Draw sprite at (V0, V1) with height 4

            // Update X position
            0x80, 0x24, // V0 = V0 + V2 (add X velocity)

            // Check X boundaries
            0x40, 0x00, // Skip next if V0 != 0
            0x62, 0x01, // Set V2 = 1 (bounce right)
            0x50, 0x40, // Skip next if V0 != V4
            0x62, 0xFF, // Set V2 = -1 (bounce left)

            // Update Y position
            0x81, 0x34, // V1 = V1 + V3 (add Y velocity)

            // Check Y boundaries
            0x41, 0x00, // Skip next if V1 != 0
            0x63, 0x01, // Set V3 = 1 (bounce down)
            0x51, 0x50, // Skip next if V1 != V5
            0x63, 0xFF, // Set V3 = -1 (bounce up)

            // Small delay
            0x66, 0x02, // Set V6 = 2
            0xF6, 0x15, // Set delay timer = V6

            // Wait for timer
            0xF6, 0x07, // V6 = delay timer
            0x36, 0x00, // Skip next if V6 != 0
            0x12, 0x0E, // Jump back to main loop
            0x12, 0x28, // Jump to wait loop

            // Sprite data (4x4 pixel ball)
            0xF0, // 1111 0000
            0xF0, // 1111 0000
            0xF0, // 1111 0000
            0xF0, // 1111 0000
        };
        cpu.loadRom(&simple_game);
    }
}

fn loadRom(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("File could not be opened or file not available : {any}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const file_size_usize: usize = @intCast(file_size);
    const rom_data = try allocator.alloc(u8, file_size_usize);
    defer allocator.free(rom_data);

    _ = try file.readAll(rom_data);
    cpu.loadRom(rom_data);
}

export fn init() void {
    cpu.init();
}

export fn cycle() void {
    cpu.cycle();
}

export fn load_rom(ptr: [*]const u8, len: usize) void {
    const rom = ptr[0..len];
    cpu.loadRom(rom);
}

export fn getDisplayBuffer() [*]const u8 {
    return &cpu.display;
}

export fn set_key(key: u8, pressed: bool) void {
    cpu.setKey(key, pressed);
}
