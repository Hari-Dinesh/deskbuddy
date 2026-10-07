#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
sdk=${DESKBUDDY_SDK:-$(xcrun --show-sdk-path)}
if [[ -z "${DESKBUDDY_SDK:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk ]]; then
  sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk
fi
mkdir -p .build/cache .build/DeskBuddy.app/Contents/MacOS .build/DeskBuddy.app/Contents/Resources
architectures=("$(uname -m)")
if [[ "${1:-}" == "--universal" ]]; then architectures=(arm64 x86_64); fi
binaries=()
for architecture in "${architectures[@]}"; do
  binary=".build/DeskBuddy-$architecture"
  xcrun swiftc Sources/*.swift -sdk "$sdk" -target "$architecture-apple-macos13.0" -module-cache-path .build/cache -framework AppKit -framework SwiftUI -framework CoreGraphics -framework ServiceManagement -o "$binary"
  binaries+=("$binary")
done
if [[ ${#binaries[@]} -eq 2 ]]; then
  lipo -create "${binaries[@]}" -output .build/DeskBuddy.app/Contents/MacOS/DeskBuddy
else
  cp "${binaries[0]}" .build/DeskBuddy.app/Contents/MacOS/DeskBuddy
fi
cat > .build/DeskBuddy.app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DeskBuddy</string>
<key>CFBundleIdentifier</key><string>io.github.hari-dinesh.deskbuddy</string>
<key>CFBundleName</key><string>DeskBuddy</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "${DESKBUDDY_SIGN_IDENTITY:--}" .build/DeskBuddy.app
codesign --verify --strict .build/DeskBuddy.app
echo "Built .build/DeskBuddy.app ($version)"
