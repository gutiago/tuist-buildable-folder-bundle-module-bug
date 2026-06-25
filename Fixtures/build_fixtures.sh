#!/usr/bin/env bash
# Builds MathCore.xcframework: a STATIC C library packaged as an xcframework with a
# hand-written clang module map whose header (`math_core.h`) does NOT match the
# xcframework basename (`MathCore`). This mimics a C archive (e.g. a cgo / autotools
# library) vendored as a binary xcframework via SwiftPM.
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(pwd)"
SRC="$OUT/src"
BUILD="$OUT/.build"; rm -rf "$BUILD" MathCore.xcframework; mkdir -p "$BUILD/include"

SDK_IOS="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"
CLANG="$(xcrun -f clang)"; AR="$(xcrun -f ar)"

# Device slice (arm64) + universal simulator slice (arm64 + x86_64).
"$CLANG" -c "$SRC/math_core.c" -target arm64-apple-ios16.0 -isysroot "$SDK_IOS" -o "$BUILD/ios.o"
"$AR" rcs "$BUILD/libMathCore_ios.a" "$BUILD/ios.o"
"$CLANG" -c "$SRC/math_core.c" -target arm64-apple-ios16.0-simulator -isysroot "$SDK_SIM" -o "$BUILD/sim_arm64.o"
"$AR" rcs "$BUILD/sim_arm64.a" "$BUILD/sim_arm64.o"
"$CLANG" -c "$SRC/math_core.c" -target x86_64-apple-ios16.0-simulator -isysroot "$SDK_SIM" -o "$BUILD/sim_x86.o"
"$AR" rcs "$BUILD/sim_x86.a" "$BUILD/sim_x86.o"
lipo -create "$BUILD/sim_arm64.a" "$BUILD/sim_x86.a" -output "$BUILD/libMathCore_sim.a"

# Headers: the header is `math_core.h` (snake_case) — it does NOT match the
# xcframework name "MathCore". The module map points at that header.
cp "$SRC/math_core.h" "$BUILD/include/math_core.h"
cat > "$BUILD/include/module.modulemap" <<'MM'
module MathCore {
    header "math_core.h"
    export *
}
MM

xcodebuild -create-xcframework \
  -library "$BUILD/libMathCore_ios.a" -headers "$BUILD/include" \
  -library "$BUILD/libMathCore_sim.a" -headers "$BUILD/include" \
  -output "$OUT/MathCore.xcframework" >/dev/null

echo "Built MathCore.xcframework. Headers:"; ls "$OUT/MathCore.xcframework/ios-arm64/Headers"
