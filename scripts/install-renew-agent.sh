#!/bin/bash
# Schedules scripts/renew-profile.sh every day at 9:00 (missed runs fire on wake).
# Log: ~/Library/Logs/farmacia-renew.log. Remove: launchctl bootout gui/$(id -u)/com.farmacia.renew-profile
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.farmacia.renew-profile.plist"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.farmacia.renew-profile</string>
  <key>ProgramArguments</key><array><string>$ROOT/scripts/renew-profile.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/farmacia-renew.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/farmacia-renew.log</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/com.farmacia.renew-profile" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Scheduled daily at 9:00: $PLIST"
