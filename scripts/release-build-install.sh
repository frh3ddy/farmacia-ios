#!/bin/bash
# Archive (Release), export .ipa, and install on a connected physical iPhone.
# Free/personal Apple Developer account: uses "development" distribution only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FarmaciaApp.xcodeproj"
SCHEME="FarmaciaApp"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/FarmaciaApp.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions.plist"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✘ %s\033[0m\n' "$1"; exit 1; }

run_logged() {
  local log="$1"; shift
  if ! "$@" 2>&1 | tee "$log"; then
    fail "Command failed. Full output above, saved to $log"
  fi
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

step "Finding a connected, available iPhone"
DEVICE_LINE="$(xcrun devicectl list devices 2>/dev/null | grep -i "iPhone" | grep -E "connected|available \(paired\)" | head -n1 || true)"
[ -n "$DEVICE_LINE" ] || fail "No connected/available iPhone found. Is it connected, unlocked, and trusted?"
DEVICE_UDID="$(echo "$DEVICE_LINE" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')"
ok "Using device: $DEVICE_UDID"
echo "$DEVICE_LINE"

step "Archiving $SCHEME (Release)"
run_logged "$BUILD_DIR/archive.log" xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates
ok "Archive created at $ARCHIVE_PATH"

step "Exporting .ipa"
run_logged "$BUILD_DIR/export.log" xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates
IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name "*.ipa" | head -n1)"
[ -n "$IPA_PATH" ] || fail "No .ipa found in $EXPORT_DIR after export"
ok "Exported $IPA_PATH"

step "Unpacking .ipa for install (devicectl requires a .app bundle)"
UNZIP_DIR="$EXPORT_DIR/unzipped"
rm -rf "$UNZIP_DIR" && mkdir -p "$UNZIP_DIR"
unzip -q "$IPA_PATH" -d "$UNZIP_DIR" || fail "Failed to unzip $IPA_PATH"
APP_PATH="$(find "$UNZIP_DIR/Payload" -maxdepth 1 -name "*.app" | head -n1)"
[ -n "$APP_PATH" ] || fail "No .app bundle found inside $IPA_PATH"
ok "App bundle: $APP_PATH"

step "Installing on device $DEVICE_UDID"
run_logged "$BUILD_DIR/install.log" xcrun devicectl device install app \
  --device "$DEVICE_UDID" \
  "$APP_PATH"
ok "Installed successfully on $DEVICE_UDID"
