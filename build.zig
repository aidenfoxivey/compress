const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const zcompress = b.addExecutable(.{
        .name = "lzwc",
        .root_source_file = b.path("src/compress.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zuncompress = b.addExecutable(.{
        .name = "lzwun",
        .root_source_file = b.path("src/uncompress.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(zcompress);
    b.installArtifact(zuncompress);

    const run_cmd = b.addRunArtifact(zcompress);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
