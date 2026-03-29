const std = @import("std");

pub fn build(b: *std.Build) void {
    // SQLite compile flags shared between all targets
    const common_sqlite_flags: []const []const u8 = &.{
        "-DSQLITE_OMIT_WAL",
        "-DSQLITE_OMIT_LOAD_EXTENSION",
        "-DSQLITE_OMIT_DEPRECATED",
        "-DSQLITE_OMIT_UTF16",
        "-DSQLITE_OMIT_DESERIALIZE",
        "-DSQLITE_THREADSAFE=0",
        "-DSQLITE_DEFAULT_MEMSTATUS=0",
        "-DSQLITE_DQS=0",
        "-DSQLITE_LIKE_DOESNT_MATCH_BLOBS",
        "-DSQLITE_TEMP_STORE=3",
        "-DHAVE_USLEEP=0",
        "-DSQLITE_OMIT_LOCALTIME",
    };

    // WASM-only: use custom VFS, omit autoinit
    const wasm_sqlite_flags: []const []const u8 = common_sqlite_flags ++ &[_][]const u8{
        "-DSQLITE_OS_OTHER",
        "-DSQLITE_OMIT_AUTOINIT",
    };

    // --- WASM target (web) ---
    const wasm_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });
    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/sqlite3.c"),
        .flags = wasm_sqlite_flags,
    });
    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/wasm_vfs.c"),
        .flags = &.{"-DMAX_FILE_SIZE=(32*1024*1024)"},
    });
    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/libc_shim.c"),
        .flags = &.{"-DHEAP_SIZE=(16*1024*1024)"},
    });
    wasm_mod.addIncludePath(b.path("vendor"));
    wasm_mod.addSystemIncludePath(b.path("vendor/libc"));

    const wasm_exe = b.addExecutable(.{
        .name = "libtaijobi",
        .root_module = wasm_mod,
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    wasm_exe.stack_size = 1 * 1024 * 1024;
    wasm_exe.max_memory = 512 * 1024 * 1024;

    // Install to zig-out/lib/ — use scripts/build-wasm.sh to copy to taijobi-web
    b.installArtifact(wasm_exe);

    // --- Native target (testing) ---
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = native_target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addCSourceFile(.{
        .file = b.path("vendor/sqlite3.c"),
        .flags = common_sqlite_flags,
    });
    test_mod.addIncludePath(b.path("vendor"));

    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
