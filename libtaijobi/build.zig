const std = @import("std");

pub fn build(b: *std.Build) void {
    // MCP build toggle: when true, produces libtaijobi-mcp.wasm with a much
    // smaller persistent allocator. The Cloudflare Worker hosting the MCP
    // server caps at 128MB per invocation; the full 128MB persist buffer used
    // by the web client (for endict + dedict + strokes + cedict + decomp)
    // doesn't fit. MCP tools don't touch dictionaries, so 16MB is plenty.
    const mcp = b.option(bool, "mcp", "Compact build for MCP server (no dictionaries)") orelse false;

    // Default target: wasm32-freestanding for the web build. Pass
    // `-Dtarget=aarch64-ios` or `-Dtarget=aarch64-ios-simulator` to produce
    // the static library that the SwiftUI shell links against. Tests resolve
    // to the host architecture regardless of -Dtarget.
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });
    const optimize = b.standardOptimizeOption(.{});
    const is_wasm = target.result.cpu.arch == .wasm32;

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

    if (is_wasm) {
        // WASM-only: use custom VFS, omit autoinit
        const wasm_sqlite_flags: []const []const u8 = common_sqlite_flags ++ &[_][]const u8{
            "-DSQLITE_OS_OTHER",
            "-DSQLITE_OMIT_AUTOINIT",
        };

        const wasm_mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
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
        // WebAssembly.instantiate(). MCP build stays small to fit the 128MB
        // Worker cap. Web build needs to host: persist 256MB + fba 64MB +
        // vfs 4×32MB + heap 16MB + stack 1MB ≈ 465MB of BSS, plus headroom
        // for sqlite + JSON scratch growth → 768MB.
        // MCP budget: fba 16MB + persist 16MB + vfs 32MB + heap 4MB + stack 1MB ≈ 69MB.
        wasm_exe.max_memory = if (mcp) 96 * 1024 * 1024 else 768 * 1024 * 1024;

        // Install to zig-out/bin/ — use scripts/build-wasm.sh to copy to taijobi-web
        b.installArtifact(wasm_exe);
    } else {
        // --- Apple native static library (iOS / iOS simulator / macOS) ---
        //
        // The WASM-specific VFS and libc shim are skipped here: Apple targets
        // have a real filesystem and a real libc, so SQLite uses the stock
        // unix backend and Zig links against the platform libc via the SDK
        // detected by `addAppleSdkPaths`.
        if (!target.result.os.tag.isDarwin()) {
            @panic("Unsupported -Dtarget. Use the default (WASM) or aarch64-ios{,-simulator}.");
        }

        const native_mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        // Native iOS build never participates in the MCP compaction toggle —
        // dictionaries are available, the share extension just doesn't load
        // them. Force mcp=false so any `-Dmcp=true` on the CLI is ignored.
        const native_opts = b.addOptions();
        native_opts.addOption(bool, "mcp", false);
        native_mod.addOptions("build_options", native_opts);

        native_mod.addCSourceFile(.{
            .file = b.path("vendor/sqlite3.c"),
            .flags = common_sqlite_flags,
        });
        native_mod.addIncludePath(b.path("vendor"));

        const lib = b.addLibrary(.{
            .name = "taijobi",
            .linkage = .static,
            .root_module = native_mod,
        });

        addAppleSdkPaths(b, lib) catch @panic("Apple SDK not found — is Xcode installed?");

        b.installArtifact(lib);

        // Ship the C header alongside the static lib so
        // `xcodebuild -create-xcframework -headers ...` can pick it up.
        b.installFile("include/libtaijobi.h", "include/libtaijobi.h");
    }

    // --- Tests (always native host, ignoring -Dtarget) ---
    const test_target = b.resolveTargetQuery(.{});
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = test_target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Tests always build with the full (non-MCP) config.
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

/// Detect Apple SDK via xcrun and configure include/framework/library paths.
/// Adapted from ghostty-org/ghostty pkg/apple-sdk/build.zig.
fn addAppleSdkPaths(b: *std.Build, step: *std.Build.Step.Compile) !void {
    const target_val = step.rootModuleTarget();

    const libc = try std.zig.LibCInstallation.findNative(.{
        .allocator = b.allocator,
        .target = &target_val,
        .verbose = false,
    });

    // Render libc.txt compatible with Zig's --libc flag
    var stream: std.io.Writer.Allocating = .init(b.allocator);
    defer stream.deinit();
    try libc.render(&stream.writer);

    const wf = b.addWriteFiles();
    const path = wf.add("libc.txt", stream.written());
    step.setLibCFile(path);

    // Framework path: go up from sys_include_dir to find System/Library/Frameworks
    if (libc.sys_include_dir) |sys_include| {
        const down1 = std.fs.path.dirname(sys_include).?;
        const down2 = std.fs.path.dirname(down1).?;
        const framework_path = try std.fs.path.join(b.allocator, &.{
            down2, "System", "Library", "Frameworks",
        });
        const library_path = try std.fs.path.join(b.allocator, &.{
            down1, "lib",
        });

        step.root_module.addSystemFrameworkPath(.{ .cwd_relative = framework_path });
        step.root_module.addSystemIncludePath(.{ .cwd_relative = sys_include });
        step.root_module.addLibraryPath(.{ .cwd_relative = library_path });
    }
}
