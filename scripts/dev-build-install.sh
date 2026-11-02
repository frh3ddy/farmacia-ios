#!/bin/bash
# Build the Debug app ("Farmacia Dev", com.farmacia.ios.dev) and install it on a
# connected physical iPhone, next to the production app.
# The dev app talks to the local API (AppConfiguration .development), so the phone
# must be on the same Wi-Fi as this Mac with farmacia-ops running.
# Free/personal Apple Developer account: development signing, re-run every 7 days.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FarmaciaApp.xcodeproj"
SCHEME="FarmaciaApp"
BUILD_DIR="$ROOT/build/dev"
# Kept between runs (unlike the release script) so rebuilds are incremental.
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/FarmaciaApp.app"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✘ %s\033[0m\n' "$1"; exit 1; }

run_logged() {
  local log="$1"; shift
  if ! "$@" 2>&1 | tee "$log"; then
    fail "Command failed. Full output above, saved to $log"
  fi
}

mkdir -p "$BUILD_DIR"

step "Finding a connected, available iPhone"
DEVICE_LINE="$(xcrun devicectl list devices 2>/dev/null | grep -i "iPhone" | grep -v "simulated" | grep -E "connected|available \(paired\)" | head -n1 || true)"
[ -n "$DEVICE_LINE" ] || fail "No connected/available iPhone found. Is it connected, unlocked, and trusted?"
DEVICE_UDID="$(echo "$DEVICE_LINE" | grep -oE '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{16}|[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})' || true)"
[ -n "$DEVICE_UDID" ] || fail "Couldn't read the device id from: $DEVICE_LINE"
ok "Using device: $DEVICE_UDID"
echo "$DEVICE_LINE"

step "Checking the local API the dev app uses"
API_IP="$(grep -oE 'localServerIP = "[0-9.]+"' FarmaciaApp/App/AppConfiguration.swift | grep -oE '[0-9.]+' || true)"
if [ -z "$API_IP" ]; then
  warn "Couldn't read localServerIP from AppConfiguration.swift — skipping the check"
elif nc -z -G 2 "$API_IP" 3000 2>/dev/null; then
  ok "API reachable at $API_IP:3000"
else
  warn "Nothing answering at $API_IP:3000 — start farmacia-ops, or update localServerIP if this Mac's IP changed. Installing anyway."
fi

step "Building $SCHEME (Debug) for the device"
run_logged "$BUILD_DIR/build.log" xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates
[ -d "$APP_PATH" ] || fail "No app bundle at $APP_PATH after the build"
ok "Built $APP_PATH"

step "Installing on device $DEVICE_UDID"
run_logged "$BUILD_DIR/install.log" xcrun devicectl device install app \
  --device "$DEVICE_UDID" \
  "$APP_PATH"
ok "Installed Farmacia Dev on $DEVICE_UDID"
