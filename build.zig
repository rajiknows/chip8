// const std = @import("std");
//
// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//
//     // Create the executable
//     const exe = b.addExecutable(.{
//         .name = "chip-8",
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });
//
//     b.installArtifact(exe);
//
//     // Create run step
//     const run_cmd = b.addRunArtifact(exe);
//     run_cmd.step.dependOn(b.getInstallStep());
//
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }
//
//     const run_step = b.step("run", "Run the app");
//     run_step.dependOn(&run_cmd.step);
//
//     // Tests
//     const unit_tests = b.addTest(.{
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });
//
//     const run_unit_tests = b.addRunArtifact(unit_tests);
//
//     const test_step = b.step("test", "Run unit tests");
//     test_step.dependOn(&run_unit_tests.step);
// }

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "chip8_wasm",
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    // exe.addExport("init");
    // exe.addExport("cycle");
    // exe.addExport("loadRom");
    // exe.addExport("getDisplayBuffer");

    // exe.entry = null; // no main
    b.installArtifact(exe);
}
