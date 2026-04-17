#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple"
APP_DIR="$ROOT_DIR/dist/Refiner.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

swift build \
  --configuration release \
  --product Refiner \
  --scratch-path "$BUILD_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BUILD_DIR/release/Refiner" "$MACOS_DIR/Refiner"
cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "Built $APP_DIR"
