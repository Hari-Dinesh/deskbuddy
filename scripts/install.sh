#!/bin/bash
# Download an immutable GitHub release, verify its checksum, then install per user.
set -euo pipefail
repository=Hari-Dinesh/deskbuddy
destination=${DESKBUDDY_INSTALL_DIR:-"$HOME/Applications"}
mode=${1:-}
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
  [[ "$installed_id" == "$bundle_id" ]] || { echo "Another app occupies the destination." >&2; exit 1; }
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
