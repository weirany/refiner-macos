#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple"
APP_DIR="$ROOT_DIR/dist/Refiner.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$ROOT_DIR/App/Info.plist"
APP_ICON="$ROOT_DIR/App/AppIcon.icns"
MENU_BAR_ICON="$ROOT_DIR/Sources/Refiner/Resources/MenuBarIconTemplate@2x.png"

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

swift build \
  --configuration release \
  --product Refiner \
  --scratch-path "$BUILD_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/release/Refiner" "$MACOS_DIR/Refiner"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
cp "$APP_ICON" "$RESOURCES_DIR/AppIcon.icns"
cp "$MENU_BAR_ICON" "$RESOURCES_DIR/MenuBarIconTemplate@2x.png"

/usr/libexec/PlistBuddy -c "Clear dict" "$RESOURCES_DIR/BuildInfo.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $SHORT_VERSION" "$RESOURCES_DIR/BuildInfo.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$RESOURCES_DIR/BuildInfo.plist"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "Built $APP_DIR"
