const std = @import("std");

pub fn build(b: *std.Build) void {
    // MCP build toggle: when true, produces libtaijobi-mcp.wasm with a much
    // smaller persistent allocator. The Cloudflare Worker hosting the MCP
    // server caps at 128MB per invocation; the full 128MB persist buffer used
    // by the web client (for endict + dedict + strokes + cedict + decomp)
    // doesn't fit. MCP tools don't touch dictionaries, so 16MB is plenty.
    const mcp = b.option(bool, "mcp", "Compact build for MCP server (no dictionaries)") orelse false;

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

    // --- WASM target (web or MCP) ---
    const wasm_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });

    // Expose `mcp` to Zig as an @import("build_options") constant. root.zig
    // reads it at comptime to pick PERSIST_SIZE.
    const build_opts = b.addOptions();
    build_opts.addOption(bool, "mcp", mcp);
    wasm_mod.addOptions("build_options", build_opts);

    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/sqlite3.c"),
        .flags = wasm_sqlite_flags,
    });
    // VFS static buffers (mem_storage[MAX_MEM_FILES][MAX_FILE_SIZE]) dominate
    // the WASM's initial linear memory. Web needs 4×32MB for dictionary DBs;
    // MCP fits in Cloudflare's 128MB Worker cap with 2×16MB.
    const vfs_flags: []const []const u8 = if (mcp)
        &.{ "-DMAX_FILE_SIZE=(16*1024*1024)", "-DMAX_MEM_FILES=2" }
    else
        &.{"-DMAX_FILE_SIZE=(32*1024*1024)"};
    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/wasm_vfs.c"),
        .flags = vfs_flags,
    });
    // libc heap: web loads dictionaries and SQLite result buffers through it;
    // MCP handlers are small so 4MB is plenty.
    const libc_flags: []const []const u8 = if (mcp)
        &.{"-DHEAP_SIZE=(4*1024*1024)"}
    else
        &.{"-DHEAP_SIZE=(16*1024*1024)"};
    wasm_mod.addCSourceFile(.{
        .file = b.path("vendor/libc_shim.c"),
        .flags = libc_flags,
    });
    wasm_mod.addIncludePath(b.path("vendor"));
    wasm_mod.addSystemIncludePath(b.path("vendor/libc"));

    const wasm_exe = b.addExecutable(.{
        .name = if (mcp) "libtaijobi-mcp" else "libtaijobi",
        .root_module = wasm_mod,
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    wasm_exe.stack_size = 1 * 1024 * 1024;
    // V8 on Cloudflare Workers reserves max_memory upfront at
    // WebAssembly.instantiate(). 512MB > 128MB Worker cap → OOM.
    // MCP budget: persist 16MB + vfs 32MB + heap 4MB + stack 1MB ≈ 53MB.
    wasm_exe.max_memory = if (mcp) 64 * 1024 * 1024 else 512 * 1024 * 1024;

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
    // Native tests always build with the full (non-MCP) config.
    const test_opts = b.addOptions();
    test_opts.addOption(bool, "mcp", false);
    test_mod.addOptions("build_options", test_opts);
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
