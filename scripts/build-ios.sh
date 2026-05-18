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

echo "=== Building for aarch64-ios (device) ==="
zig build -Dtarget=aarch64-ios --release=small
cp zig-out/lib/libtaijobi.a "$BUILD_DIR/ios/libtaijobi.a"

echo "=== Building for aarch64-ios-simulator ==="
zig build -Dtarget=aarch64-ios-simulator --release=small
cp zig-out/lib/libtaijobi.a "$BUILD_DIR/sim/libtaijobi.a"

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
