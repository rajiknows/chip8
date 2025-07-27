const std = @import("std");
const rl = @import("raylib");
const CHIP8 = @import("chip8.zig");

const screenWidth = 800;
const screenHeight = 600;
const SCALE = 16;

var cpu: CHIP8 = undefined;

pub fn init() !void {
    rl.initWindow(screenWidth, screenHeight, "CHIP-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    cpu.init();

    // Initialize CHIP-8 CPU
    // cpu.init();

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Handle input
        handleInput();

        // Run CPU cycle
        cpu.cycle();

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        // Draw CHIP-8 display
        drawDisplay();

        // Draw info text
        // rl.drawText("CHIP-8 Emulator", 10, 10, 20, rl.Color.white);
        // rl.drawText("Press ESC to exit", 10, 35, 16, rl.Color.gray);
    }
}
// ok  so this is how the display is stored , it is stored in a array right
//
// display = [0,0,0,0,0,0,0.........]
//
// but to represent the screen we will imagine it to be like this
//
// display = [0,0,0,0.... SCREEN_WIDTH
//            0,0,0,0......
//            0
//            0
//            .
//            .
//            .
//            .
//            SCREEN_HEIGHT
//           ]

pub fn drawDisplay() void {
    for (0..CHIP8.DISPLAY_HEIGHT) |y| {
        for (0..CHIP8.DISPLAY_WIDTH) |x| {
            const pixel = cpu.display[y * CHIP8.DISPLAY_WIDTH + x];
            if (pixel == 1) {
                const rect = rl.Rectangle{
                    .x = @floatFromInt(x * SCALE),
                    .y = @floatFromInt(y * SCALE),
                    .width = SCALE,
                    .height = SCALE,
                };
                rl.drawRectangleRec(rect, rl.Color.white);
            }
        }
    }
}

pub fn deinit() void {
    rl.closeWindow();
}

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

    try init();
}

fn loadRom(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("File could not be opened or file not available : {any}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const rom_data = try allocator.alloc(u8, file_size);
    defer allocator.free(rom_data);

    _ = try file.readAll(rom_data);
    cpu.loadRom(rom_data);
}

fn handleInput() void {
    // CHIP-8 keypad mapping:
    // 1 2 3 C    ->    1 2 3 4
    // 4 5 6 D    ->    Q W E R
    // 7 8 9 E    ->    A S D F
    // A 0 B F    ->    Z X C V

    const key_mapping = [_]struct { raylib_key: rl.KeyboardKey, chip8_key: u8 }{
        .{ .raylib_key = rl.KeyboardKey.one, .chip8_key = 0x1 },
        .{ .raylib_key = rl.KeyboardKey.two, .chip8_key = 0x2 },
        .{ .raylib_key = rl.KeyboardKey.three, .chip8_key = 0x3 },
        .{ .raylib_key = rl.KeyboardKey.four, .chip8_key = 0xC },
        .{ .raylib_key = rl.KeyboardKey.q, .chip8_key = 0x4 },
        .{ .raylib_key = rl.KeyboardKey.w, .chip8_key = 0x5 },
        .{ .raylib_key = rl.KeyboardKey.e, .chip8_key = 0x6 },
        .{ .raylib_key = rl.KeyboardKey.r, .chip8_key = 0xD },
        .{ .raylib_key = rl.KeyboardKey.a, .chip8_key = 0x7 },
        .{ .raylib_key = rl.KeyboardKey.s, .chip8_key = 0x8 },
        .{ .raylib_key = rl.KeyboardKey.d, .chip8_key = 0x9 },
        .{ .raylib_key = rl.KeyboardKey.f, .chip8_key = 0xE },
        .{ .raylib_key = rl.KeyboardKey.z, .chip8_key = 0xA },
        .{ .raylib_key = rl.KeyboardKey.x, .chip8_key = 0x0 },
        .{ .raylib_key = rl.KeyboardKey.c, .chip8_key = 0xB },
        .{ .raylib_key = rl.KeyboardKey.v, .chip8_key = 0xF },
    };
    for (key_mapping) |mapping| {
        const pressed = rl.isKeyDown(mapping.raylib_key);
        cpu.setKey(mapping.chip8_key, pressed);
    }
}
