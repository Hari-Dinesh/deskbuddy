#!/bin/bash
# Download an immutable GitHub release, verify its checksum, then install per user.
set -euo pipefail
repository=Hari-Dinesh/deskbuddy
destination=${DESKBUDDY_INSTALL_DIR:-"$HOME/Applications"}
mode=${1:-}
data_root=${DESKBUDDY_DATA_DIR:-"$HOME/Library/Application Support/DeskBuddy"}
preferences_root=${DESKBUDDY_PREFERENCES_DIR:-"$HOME/Library/Preferences"}
if [[ "$(uname -s)" == Darwin ]]; then
  if pgrep -x DeskBuddy >/dev/null 2>&1; then
    echo "Save your notes and quit DeskBuddy from its menu-bar icon before updating or uninstalling. Your current app and data were not changed." >&2
    exit 1
  else
    process_status=$?
    if [[ "$process_status" -ne 1 ]]; then
      echo "Could not verify that DeskBuddy is closed. Run this installer from your normal macOS Terminal after quitting DeskBuddy; nothing was changed." >&2
      exit 1
    fi
  fi
fi
if [[ "$mode" == "--uninstall" ]]; then
  if [[ -d "$destination/DeskBuddy.app" ]]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/DeskBuddy.app/Contents/Info.plist")
    [[ "$bundle_id" == "io.github.hari-dinesh.deskbuddy" ]] || { echo "Refusing to remove a different app." >&2; exit 1; }
    rm -rf "$destination/DeskBuddy.app"
  fi
  echo "App removed. Settings and custom avatars are preserved. Disable its Login Item in System Settings if enabled."
  exit 0
fi
[[ "$mode" == "" || "$mode" == "--version" ]] || { echo "Usage: install.sh [--version v2.0.0 | --uninstall]" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || { echo "DeskBuddy requires macOS 13 or later." >&2; exit 1; }
os_version=$(sw_vers -productVersion)
[[ "${os_version%%.*}" -ge 13 ]] || { echo "DeskBuddy requires macOS 13 or later." >&2; exit 1; }
if [[ "$mode" == "--version" ]]; then
  tag=${2:?Provide a release tag such as v2.0.0}
else
  tag=$(curl --fail --silent --show-error --location "https://api.github.com/repos/$repository/releases/latest" | plutil -extract tag_name raw -o - -)
fi
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release tag." >&2; exit 1; }
version=${tag#v}
archive="DeskBuddy-$version-universal.zip"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
base="https://github.com/$repository/releases/download/$tag"
curl --fail --silent --show-error --location "$base/$archive" -o "$temporary/$archive"
curl --fail --silent --show-error --location "$base/SHA256SUMS" -o "$temporary/SHA256SUMS"
expected=$(awk -v filename="$archive" '$2 == filename { print $1 }' "$temporary/SHA256SUMS")
[[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "Missing or invalid checksum." >&2; exit 1; }
actual=$(shasum -a 256 "$temporary/$archive" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || { echo "Checksum verification failed; nothing installed." >&2; exit 1; }
ditto -x -k "$temporary/$archive" "$temporary/unpacked"
app="$temporary/unpacked/DeskBuddy.app"
codesign --verify --strict "$app"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
[[ "$bundle_id" == "io.github.hari-dinesh.deskbuddy" ]] || { echo "Unexpected app identity." >&2; exit 1; }
mkdir -p "$destination"
if [[ -d "$destination/DeskBuddy.app" ]]; then
  installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/DeskBuddy.app/Contents/Info.plist")
  [[ "$installed_id" == "$bundle_id" || "$installed_id" == "local.dinesh.DeskBuddy" ]] || { echo "Another app occupies the destination." >&2; exit 1; }
  installed_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$destination/DeskBuddy.app/Contents/Info.plist")
  if awk -v old="$installed_version" -v new="$version" 'BEGIN { split(old,a,/[.]/); split(new,b,/[.]/); for(i=1;i<=3;i++) { if(a[i]+0>b[i]+0) exit 0; if(a[i]+0<b[i]+0) exit 1; } exit 1; }'; then
    echo "A newer DeskBuddy version is installed. Refusing a downgrade that could damage newer saved data." >&2
    exit 1
  fi
fi
# Back up user data before replacing an existing application. Keychain tokens are never exported.
if [[ -d "$destination/DeskBuddy.app" || -f "$data_root/workspace.json" || -d "$data_root/Avatar" ]]; then
  mkdir -p "$data_root/Backups"
  recovery=$(mktemp -d "$data_root/Backups/update-$version-XXXXXXXX")
  chmod 700 "$recovery"
  for domain in local.dinesh.DeskBuddy io.github.hari-dinesh.deskbuddy; do
    source_preferences="$preferences_root/$domain.plist"
    if [[ -f "$source_preferences" ]]; then cp -p "$source_preferences" "$recovery/$domain.plist"; fi
  done
  if [[ -f "$data_root/workspace.json" ]]; then cp -p "$data_root/workspace.json" "$recovery/workspace.json"; fi
  if [[ -d "$data_root/Avatar" ]]; then ditto "$data_root/Avatar" "$recovery/Avatar"; fi
  if [[ -d "$destination/DeskBuddy.app" ]]; then
    ditto "$destination/DeskBuddy.app" "$recovery/DeskBuddy.app"
    resources="$destination/DeskBuddy.app/Contents/Resources"
    if [[ "$installed_id" == "local.dinesh.DeskBuddy" && -f "$resources/personal-avatar.png" && -f "$resources/animation-sheet.png" && ! -e "$data_root/LegacyAvatar" && ! -e "$data_root/Avatar" ]]; then
      mkdir -p "$data_root/LegacyAvatar"
      cp "$resources/personal-avatar.png" "$data_root/LegacyAvatar/idle.png"
      cp "$resources/animation-sheet.png" "$data_root/LegacyAvatar/animation-sheet.png"
    fi
  fi
  echo "Setup and previous app backed up at: $recovery"
fi
# Quit DeskBuddy yourself before an update; the installer does not kill applications.
staging="$destination/.DeskBuddy-install-$$.app"
backup="$destination/.DeskBuddy-backup-$$.app"
ditto "$app" "$staging"
if [[ -d "$destination/DeskBuddy.app" ]]; then mv "$destination/DeskBuddy.app" "$backup"; fi
if ! mv "$staging" "$destination/DeskBuddy.app"; then
  [[ ! -d "$backup" ]] || mv "$backup" "$destination/DeskBuddy.app"
  exit 1
fi
[[ ! -d "$backup" ]] || rm -rf "$backup"
echo "Installed DeskBuddy $version at $destination/DeskBuddy.app"
echo "Launch it with: open \"$destination/DeskBuddy.app\""
echo "This local-use build is ad-hoc signed, not Apple notarized; organization policies may restrict launching it."
