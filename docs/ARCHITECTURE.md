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
| Integrations.swift | Generic provider contract and opt-in quiet-time policy |
| WorkspaceData.swift | Durable notes, scheduled alerts, calendar occurrence merge and due selection |
| WorkspaceModel.swift | Workspace UI actions and cancellable Microsoft sign-in/sync coordination |
| WorkspaceViews.swift | Notes editor, quick-reminder composer and calendar connection UI |
| MicrosoftCalendar.swift | Device-code OAuth, Keychain, refresh and read-only Graph transport |

Workspace notifications and input-idle duration feed a five-second reminder check. A due reminder launches a finite animation state sequence; answer actions update local state. A separate animation timer runs only during finite scenes, using screen-refresh limits and easing. Idle visual bobbing and the reminder check remain active; idle does not imply zero CPU.

Preferences use UserDefaults under the app bundle identifier. Custom images are independent of the app bundle so update/install does not overwrite them. The original personal development build uses a different preferences domain and is not bundled here.

Tests exercise deterministic reminder rules, scene transitions, sprite bounds, generated transparent test fixtures, safe avatar replacement and integration opt-in policy. Compilation is separate from real GUI/device validation. An ad-hoc signature confirms bundle integrity, not Apple Developer ID trust or notarization.

Workspace state is atomically written to owner-only JSON. The Microsoft client is injectable through URLSession for deterministic transport tests. Calendar sync is independent from animation, bounded/paginated, generation-guarded on disconnect, and rate-limit aware. Notes do not enter Microsoft requests. Avatar scheduled alerts share the original single-scene coordinator and preserve their durable completion/snooze state.
