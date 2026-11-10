#!/bin/bash
# Free Apple ID profiles last 7 days. Run daily by launchd (scripts/install-renew-agent.sh):
# when the release profile has under RENEW_HOURS left, reinstall the release on each phone
# (a fresh build gets a fresh profile) and post a Mac notification with the result.
# A failed phone gets an alert with the time left, and tomorrow's run tries again.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_NAME="iOS Team Provisioning Profile: com.farmacia.ios"
RENEW_HOURS="${RENEW_HOURS:-48}"
PHONES=("00008110-001E04A92631801E:iPhone 13 Pro" "00008130-000815941122001C:iPhone lolita")

notify() { osascript -e "display notification \"$2\" with title \"Farmacia\" subtitle \"$1\""; }
alert()  { osascript -e "display alert \"Farmacia: $1\" message \"$2\" as critical giving up after 43200" >/dev/null; }

# Latest expiry (epoch seconds) of the release profile, 0 if none.
expiry() {
  local latest=0 f name exp t
  for f in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"/*.mobileprovision; do
    [ -e "$f" ] || continue
    name="$(security cms -D -i "$f" 2>/dev/null | plutil -extract Name raw -o - - 2>/dev/null)"
    [ "$name" = "$PROFILE_NAME" ] || continue
    exp="$(security cms -D -i "$f" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null)"
    t="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$exp" +%s 2>/dev/null || echo 0)"
    [ "$t" -gt "$latest" ] && latest="$t"
  done
  echo "$latest"
}

hours_left() { echo $(( ($(expiry) - $(date +%s)) / 3600 )); }

echo "== $(date) =="
left="$(hours_left)"
echo "Profile: ${left}h left"
if [ "${FORCE:-0}" != 1 ] && [ "$left" -ge "$RENEW_HOURS" ]; then exit 0; fi

failed=()
for phone in "${PHONES[@]}"; do
  udid="${phone%%:*}"; label="${phone#*:}"
  ok=0
  for try in 1 2 3; do
    if DEVICE_UDID="$udid" "$ROOT/scripts/release-build-install.sh"; then ok=1; break; fi
    echo "$label: try $try failed"
    if grep -q "No Accounts" "$ROOT/build/archive.log" 2>/dev/null; then
      alert "Xcode is signed out" "Xcode has no Apple ID, so it can't renew the profile (${left}h left). Open Xcode → Settings → Accounts, sign in, then run: FORCE=1 scripts/renew-profile.sh"
      exit 1
    fi
    sleep 30
  done
  [ "$ok" = 1 ] && echo "$label installed" || failed+=("$label")
done

left="$(hours_left)"
if [ ${#failed[@]} -eq 0 ]; then
  notify "App renewed" "Installed on both iPhones. The profile lasts ${left}h more."
else
  if [ "$left" -le 0 ]; then when="The app has expired on them."; else when="The app stops opening in ${left}h."; fi
  alert "couldn't renew ${failed[*]}" "$when Unlock the phone, put it on this Wi-Fi (or plug it in), then run: FORCE=1 scripts/renew-profile.sh. Otherwise the daily run tries again tomorrow."
fi
