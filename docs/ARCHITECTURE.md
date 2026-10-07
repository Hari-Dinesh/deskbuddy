# Architecture

Swift is the language; SwiftUI is the view framework. This is one native process with local business logic, not an HTTP frontend/backend pair.

| File | Responsibility |
| --- | --- |
| main.swift | Process entry point |
| AppDelegate.swift | macOS windows and menu lifecycle |
| BuddyModel.swift | Observable coordinator, sleep/idle signals and animation timer |
| Views.swift | SwiftUI views and built-in robot |
| ReminderEngine.swift | Pure reminder selection, completion and snooze rules |
| CompanionScene.swift | Scene states, pose indexes and easing |
| CharacterSprites.swift | Cached sprite decoding |
| AvatarFiles.swift | Validated custom-avatar install with rollback |
| Integrations.swift | Future provider contract and opt-in quiet-time policy |

Workspace notifications and input-idle duration feed a five-second reminder check. A due reminder launches a finite animation state sequence; answer actions update local state. A separate animation timer runs only during finite scenes, using screen-refresh limits and easing. Idle visual bobbing and the reminder check remain active; idle does not imply zero CPU.

Preferences use UserDefaults under the app bundle identifier. Custom images are independent of the app bundle so update/install does not overwrite them. The original personal development build uses a different preferences domain and is not bundled here.

Tests exercise deterministic reminder rules, scene transitions, sprite bounds, generated transparent test fixtures, safe avatar replacement and integration opt-in policy. Compilation is separate from real GUI/device validation. An ad-hoc signature confirms bundle integrity, not Apple Developer ID trust or notarization.
