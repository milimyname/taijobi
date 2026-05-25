#!/bin/bash
set -euo pipefail

# Build libtaijobi for iOS targets (device + simulator), bundle into an
# XCFramework, and copy it into taijobi-ios/Frameworks/ for the SwiftUI shell.
#
# Outputs:
#   libtaijobi/build-ios/ios/libtaijobi.a            (aarch64-apple-ios)
#   libtaijobi/build-ios/sim/libtaijobi.a            (aarch64-apple-ios-simulator)
#   libtaijobi/build-ios/libtaijobi.xcframework      (universal bundle)
#   taijobi-ios/Frameworks/libtaijobi.xcframework    (consumed by Xcode project)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/libtaijobi"
BUILD_DIR="$LIB/build-ios"
INCLUDE_DIR="$LIB/include"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{ios,sim}

cd "$LIB"

# Zig 0.16 uses llvm-ar for static-library output, which writes archive
# member offsets at 4-byte alignment. Apple's `ld` (and `xcodebuild
# archive`) require 8-byte alignment for 64-bit Mach-O members and fail
# with "not 8-byte aligned in '.../libtaijobi.a'". Re-pack with macOS's
# `libtool -static` after each zig build — libtool writes correct
# alignment and produces a Mach-O-friendly archive. Drop this workaround
# when the Zig issue (tracked upstream) lands a fix.
repack_archive() {
    local src
    src="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    local dest="$2"
    local tmp
    tmp=$(mktemp -d)
    (cd "$tmp" && /usr/bin/ar -x "$src")
    # Zig 0.16's llvm-ar stores members with mode 0, so `ar -x` writes
    # them as ----------. libtool then refuses to read them. Force
    # rw-r--r-- before re-archiving.
    chmod 644 "$tmp"/*.o
    /usr/bin/xcrun libtool -static -o "$dest" "$tmp"/*.o
    rm -rf "$tmp"
}

echo "=== Building for aarch64-ios (device) ==="
zig build -Dtarget=aarch64-ios --release=small
repack_archive zig-out/lib/libtaijobi.a "$BUILD_DIR/ios/libtaijobi.a"

echo "=== Building for aarch64-ios-simulator ==="
zig build -Dtarget=aarch64-ios-simulator --release=small
repack_archive zig-out/lib/libtaijobi.a "$BUILD_DIR/sim/libtaijobi.a"

echo "=== Creating XCFramework ==="
rm -rf "$BUILD_DIR/libtaijobi.xcframework"
xcodebuild -create-xcframework \
  -library "$BUILD_DIR/ios/libtaijobi.a" -headers "$INCLUDE_DIR" \
  -library "$BUILD_DIR/sim/libtaijobi.a" -headers "$INCLUDE_DIR" \
  -output "$BUILD_DIR/libtaijobi.xcframework"

# Copy into taijobi-ios/Frameworks/ if the iOS shell exists yet
IOS_FRAMEWORKS="$ROOT/taijobi-ios/Frameworks"
if [ -d "$ROOT/taijobi-ios" ]; then
    mkdir -p "$IOS_FRAMEWORKS"
    rm -rf "$IOS_FRAMEWORKS/libtaijobi.xcframework"
    cp -R "$BUILD_DIR/libtaijobi.xcframework" "$IOS_FRAMEWORKS/"
    echo "=== Copied to $IOS_FRAMEWORKS/libtaijobi.xcframework ==="
else
    echo "=== taijobi-ios/ not present — XCFramework left at $BUILD_DIR/libtaijobi.xcframework ==="
fi
