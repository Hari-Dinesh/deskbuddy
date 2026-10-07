#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/cache
sdk=${DESKBUDDY_SDK:-$(xcrun --show-sdk-path)}
if [[ -z "${DESKBUDDY_SDK:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk ]]; then sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk; fi
xcrun swiftc Sources/ReminderEngine.swift Tests/EngineTests.swift -module-cache-path .build/cache -o .build/engine-tests
.build/engine-tests
xcrun swiftc Sources/CompanionScene.swift Tests/SceneTests.swift -module-cache-path .build/cache -o .build/scene-tests
.build/scene-tests
fixtures=$(mktemp -d)
trap 'rm -rf "$fixtures"' EXIT
xcrun swiftc Sources/CharacterSprites.swift Sources/AvatarFiles.swift Sources/Integrations.swift Tests/AvatarIntegrationTests.swift -sdk "$sdk" -module-cache-path .build/cache -o .build/avatar-tests
.build/avatar-tests "$fixtures"
xcrun swiftc Sources/CharacterSprites.swift Sources/AvatarFiles.swift Tests/AssetTests.swift -sdk "$sdk" -module-cache-path .build/cache -o .build/asset-tests
.build/asset-tests "$fixtures/animation-sheet.png"
