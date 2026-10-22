const std = @import("std");

const sqlite_dir = "../libtaijobi/vendor";

// One SQLite build for the whole binary. THREADSAFE=2 (multi-thread): each
// connection is used by a single thread at a time (Store via spinlock), but
// different connections run concurrently — so sqlite must protect its global
// state. Reuses libtaijobi's vendored amalgamation rather than a second copy.
const sqlite_flags: []const []const u8 = &.{
    "-DSQLITE_OMIT_LOAD_EXTENSION=1",
    "-DSQLITE_THREADSAFE=2",
    "-DSQLITE_TEMP_STORE=2",
    "-DSQLITE_OMIT_DEPRECATED=1",
    "-DSQLITE_OMIT_SHARED_CACHE=1",
    "-DSQLITE_DQS=0",
    "-DSQLITE_DEFAULT_MEMSTATUS=0",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "taijobi-sync",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    addSqlite(b, exe);
    nativeLibc(b, exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the sync server");
    run_step.dependOn(&run_cmd.step);

    // --- Tests ---
    const test_step = b.step("test", "Run unit tests");

    for ([_][]const u8{ "src/store.zig", "src/protocol.zig", "src/main.zig" }) |src| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
            }),
        });
        addSqlite(b, t);
        nativeLibc(b, t);
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}

fn addSqlite(b: *std.Build, step: *std.Build.Step.Compile) void {
    step.root_module.addIncludePath(b.path(sqlite_dir));
    step.root_module.addCSourceFile(.{
        .file = b.path(sqlite_dir ++ "/sqlite3.c"),
        .flags = sqlite_flags,
    });
}

/// Wire up libc. macOS needs the SDK (via xcrun) for headers; elsewhere
/// `link_libc` is enough.
fn nativeLibc(b: *std.Build, step: *std.Build.Step.Compile) void {
    if (step.rootModuleTarget().os.tag.isDarwin()) {
        addAppleSdkPaths(b, step) catch @panic("Apple SDK not found — is Xcode installed?");
    } else {
        step.root_module.link_libc = true;
    }
}

/// Detect Apple SDK via xcrun and configure include/framework/library paths.
/// Copied from libtaijobi/build.zig (Ghostty pattern).
fn addAppleSdkPaths(b: *std.Build, step: *std.Build.Step.Compile) !void {
    const target_val = step.rootModuleTarget();
    const libc = try std.zig.LibCInstallation.findNative(
        b.allocator,
        b.graph.io,
        .{
            .target = &target_val,
            .environ_map = &b.graph.environ_map,
            .verbose = false,
        },
    );

    var stream: std.Io.Writer.Allocating = .init(b.allocator);
    defer stream.deinit();
    try libc.render(&stream.writer);

    const wf = b.addWriteFiles();
    const path = wf.add("libc.txt", stream.written());
    step.setLibCFile(path);

    if (libc.sys_include_dir) |sys_include| {
        const down1 = std.fs.path.dirname(sys_include).?;
        const down2 = std.fs.path.dirname(down1).?;
        const framework_path = try std.fs.path.join(b.allocator, &.{ down2, "System", "Library", "Frameworks" });
        const library_path = try std.fs.path.join(b.allocator, &.{ down1, "lib" });
        step.root_module.addSystemFrameworkPath(.{ .cwd_relative = framework_path });
        step.root_module.addSystemIncludePath(.{ .cwd_relative = sys_include });
        step.root_module.addLibraryPath(.{ .cwd_relative = library_path });
    }
}
