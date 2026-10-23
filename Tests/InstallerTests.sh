#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/bin" "$root/data/Avatar" "$root/preferences"
version=$(cat VERSION)
export DESKBUDDY_INSTALL_DIR="$root/Applications"
export DESKBUDDY_DATA_DIR="$root/data"
export DESKBUDDY_PREFERENCES_DIR="$root/preferences"
export TEST_FIXTURE_ZIP="$root/DeskBuddy-$version-universal.zip"
export TEST_FIXTURE_SUMS="$root/SHA256SUMS"
export TEST_PROCESS_STATUS=1
ditto -c -k --keepParent .build/DeskBuddy.app "$TEST_FIXTURE_ZIP"
(cd "$root" && shasum -a 256 "DeskBuddy-$version-universal.zip" > SHA256SUMS)
cat > "$root/bin/curl" <<'SH'
#!/bin/bash
set -eu
url= output=
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output=$2; shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */SHA256SUMS) cp "$TEST_FIXTURE_SUMS" "$output" ;;
  *.zip) cp "$TEST_FIXTURE_ZIP" "$output" ;;
  *) exit 1 ;;
esac
SH
cat > "$root/bin/pgrep" <<'SH'
#!/bin/bash
exit "$TEST_PROCESS_STATUS"
SH
chmod +x "$root/bin/"*
export PATH="$root/bin:$PATH"
printf '%s' 'notes and scheduled reminders' > "$root/data/workspace.json"
cp "$1/idle.png" "$root/data/Avatar/idle.png"
cp "$1/animation-sheet.png" "$root/data/Avatar/animation-sheet.png"
printf '%s' 'old preferences' > "$root/preferences/local.dinesh.DeskBuddy.plist"
printf '%s' 'current preferences' > "$root/preferences/io.github.hari-dinesh.deskbuddy.plist"
bash scripts/install.sh --version "v$version" > "$root/install.log"
test -d "$root/Applications/DeskBuddy.app"
test "$(cat "$root/data/workspace.json")" = 'notes and scheduled reminders'
cmp "$1/idle.png" "$root/data/Avatar/idle.png"
backup=$(find "$root/data/Backups" -maxdepth 1 -type d -name 'update-*' | head -n 1)
test -f "$backup/workspace.json"
test -f "$backup/local.dinesh.DeskBuddy.plist"
test -f "$backup/Avatar/idle.png"
echo 'PASS installer preserves notes/preferences/avatar and creates a backup'

for status in 0 3; do
  export TEST_PROCESS_STATUS=$status
  if bash scripts/install.sh --version "v$version" > "$root/refusal.log" 2>&1; then echo 'Installer must refuse a running app or failed process inspection' >&2; exit 1; fi
  test -d "$root/Applications/DeskBuddy.app"
done
export TEST_PROCESS_STATUS=1
echo 'PASS running-app and unavailable-process checks fail safely'

/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.dinesh.DeskBuddy' "$root/Applications/DeskBuddy.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.3' "$root/Applications/DeskBuddy.app/Contents/Info.plist"
resources="$root/Applications/DeskBuddy.app/Contents/Resources"
cp "$1/idle.png" "$resources/personal-avatar.png"
cp "$1/animation-sheet.png" "$resources/animation-sheet.png"
bash scripts/install.sh --version "v$version" > "$root/legacy-kept.log"
test ! -e "$root/data/LegacyAvatar"
echo 'PASS legacy upgrade preserves an existing custom avatar'

rm -rf "$root/data/Avatar"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.dinesh.DeskBuddy' "$root/Applications/DeskBuddy.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.3' "$root/Applications/DeskBuddy.app/Contents/Info.plist"
cp "$1/idle.png" "$resources/personal-avatar.png"
cp "$1/animation-sheet.png" "$resources/animation-sheet.png"
bash scripts/install.sh --version "v$version" > "$root/legacy.log"
test -f "$root/data/LegacyAvatar/idle.png"
test -f "$root/data/LegacyAvatar/animation-sheet.png"
echo 'PASS legacy bundled images staged for next-launch recovery'

/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 99.0.0' "$root/Applications/DeskBuddy.app/Contents/Info.plist"
if bash scripts/install.sh --version "v$version" > "$root/downgrade.log" 2>&1; then echo 'Downgrade must be refused' >&2; exit 1; fi
grep -q 'Refusing a downgrade' "$root/downgrade.log"
bash scripts/install.sh --uninstall > "$root/uninstall.log"
test ! -d "$root/Applications/DeskBuddy.app"
test -f "$root/data/workspace.json"
echo 'PASS downgrade protection and uninstall data preservation'
