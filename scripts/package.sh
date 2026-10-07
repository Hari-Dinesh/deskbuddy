#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
bash scripts/build.sh --universal
ditto -c -k --sequesterRsrc --keepParent .build/DeskBuddy.app ".build/DeskBuddy-$version-universal.zip"
(cd .build && shasum -a 256 "DeskBuddy-$version-universal.zip" > SHA256SUMS)
echo "Release files are in .build/"
