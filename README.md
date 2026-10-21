# DeskBuddy

A small native macOS companion for water and meal breaks, quick notes, one-off reminders, and Microsoft 365 / Teams calendar alerts. It works across applications, pauses for sleep and inactivity, walks in for reminders, and reacts to your answer.

**macOS 13+ · Apple silicon and Intel · Swift + SwiftUI + AppKit · MIT license**

## Install from Terminal

No Xcode, Node.js, Python, sudo, account or API key is needed for the prebuilt app.

```sh
curl -fsSL https://raw.githubusercontent.com/Hari-Dinesh/deskbuddy/v2.1.0/scripts/install.sh -o /tmp/deskbuddy-install.sh
bash /tmp/deskbuddy-install.sh --version v2.1.0
open "$HOME/Applications/DeskBuddy.app"
```

You can inspect the downloaded script before executing it. The installer downloads a universal release, verifies its SHA-256 checksum and code signature, then installs into `~/Applications`. It leaves your preferences and custom avatar in place on updates. Quit DeskBuddy before updating; the installer does not terminate running applications.

This release is **ad-hoc signed, not Apple notarized**. Some Macs or organization policies may block it. Where permitted, use Apple's normal Privacy & Security → Open Anyway process; the installer does not remove quarantine or disable Gatekeeper. Source builds are also available below. Windows and Linux are not supported.

To install the latest release, run the installer without `--version`. For another folder, set `DESKBUDDY_INSTALL_DIR` before invoking it.

## Use

Find the drop icon in the menu bar → Settings or Preview animation.

- Water defaults to 45 minutes of inferred active computer time. Reading without input counts as away after the configurable idle threshold (default five minutes).
- Breakfast, lunch and dinner default to 09:00, 13:00 and 20:00 in your Mac's local time. Meals have a two-hour window and are completed once per day.
- Sleep/screen-off/session inactivity pauses timing. The app does not wake your Mac.
- Yes, I did → record completion, thumbs-up and exit right.
- Not yet → playful reaction, exit left and snooze for ten minutes.
- Preview animation is a demonstration: answers do not record a real break. Regular reminders respect Reduce Motion; explicitly requested preview plays the full sequence.
- Drag the avatar, double-click for Settings or right-click for actions. Use Quiet for one hour for focused work.
- Open at login is optional and can require macOS approval.

The public release defaults to a locally drawn robot. **No contributor's personal photo or avatar is included.** Custom eight-pose cartoon avatars are supported.

## Quick notes, reminders and Teams calendar

The menu-bar drop has **Quick notes**, **Quick reminders**, and **Calendar / Teams** shortcuts.

- Notes: create/edit/delete plain-text notes, save locally, or turn the current note into a reminder in ten minutes. Save/discard edits before switching notes.
- Quick reminders: enter text and a future date/time, use the 5/30-minute shortcuts, then mark done, snooze or delete. Overdue reminders survive restarts and wake. The app must remain running.
- Calendar: connect a Microsoft Entra public-client app using a device code, read your default Microsoft 365 calendar, choose 1–30 minutes of lead time, and open Teams/Outlook meeting links. Notes and local reminders are never uploaded.
- No client ID is bundled yet. Follow the complete [Microsoft setup steps](docs/INTEGRATIONS.md), including public-client configuration and read-only delegated calendar permission. Your organization may require approval. No client secret is used.
- Meeting and quick-reminder alerts use the avatar. Water/meal prompts can pause during scheduled meetings; this does not detect live call attendance.

## Make your own avatar

Use the copy-ready [avatar prompts](docs/AVATAR_PROMPTS.md), attach a photo in your preferred image-generation tool, and export two transparent PNG files:

```text
my-avatar/
  idle.png
  animation-sheet.png
```

Open Settings → Import custom avatar and select that folder. The sheet must have **four equal columns × two equal rows**, containing four walk poses, lift glass, sip, thumbs-up and shrug. PNGs must have transparent corners and be under 20 MB each. The app validates images before replacing your existing avatar. Generated layout consistency is not guaranteed; inspect the sheet before import.

Custom avatar files live in `~/Library/Application Support/DeskBuddy/Avatar`; they survive app updates. Reset to robot removes only that custom avatar. A local photo-in-robot option is also available. Creating a cartoon is a separate external image-generation step; the running app has no image-generation API or key.

## Build from source

Install Apple's Xcode command-line tools if not already installed:

```sh
xcode-select --install
git clone https://github.com/Hari-Dinesh/deskbuddy.git
cd deskbuddy
bash scripts/build.sh
bash scripts/test.sh
open .build/DeskBuddy.app
```

Wait for command-line-tool installation to finish before building. `bash scripts/build.sh --universal` builds both architectures; `bash scripts/package.sh` makes a release ZIP and checksum. Set `DESKBUDDY_SDK` to override SDK selection; the script prefers an installed CLT 15.5 SDK as a workaround for a header error encountered in the original development environment.

## Architecture and future integrations

See [architecture](docs/ARCHITECTURE.md) and [integration plan](docs/INTEGRATIONS.md). UI, reminder logic, animation phases, custom assets and provider contracts are separate files. The Microsoft calendar provider is implemented; a real account connection requires your client ID, sign-in and consent. Transport and scheduling are tested with mocked responses; live tenant behavior must be verified after setup. The generic provider boundary remains available for future integrations.

## Privacy and limits

The app stores settings and today's counters in local macOS preferences. It does not record keystrokes, read chat messages or capture screens. Local notes/reminders and cached calendar details use `~/Library/Application Support/DeskBuddy/workspace.json`; unreadable files are preserved rather than overwritten. Microsoft tokens use macOS Keychain. Network calls occur only when connecting/syncing Microsoft calendar; disconnect removes local tokens and cached meetings. The installer contacts GitHub; an external avatar tool processes photos you choose to give it.

Animation targets the screen's maximum refresh rate, capped at 120 updates/second. This is timer-based movement, not a measured FPS guarantee or 120 unique body poses. The eight-pose asset constrains gesture detail. Daily counters are not a long-term history database. Actual battery use, multi-monitor behavior, login startup and sleep transitions need broader device testing.

## Uninstall

Quit the app, turn off Open at login, then:

```sh
bash /tmp/deskbuddy-install.sh --uninstall
```

Settings, local notes/reminders, and custom images are preserved. Disconnect Microsoft first to remove its Keychain tokens. To remove them explicitly, delete the custom Avatar folder and the preferences domain `io.github.hari-dinesh.deskbuddy` after quitting.

## Contributing and releases

See [CONTRIBUTING](CONTRIBUTING.md). Pull requests run macOS build/tests. Tags matching `VERSION` build universal release artifacts and publish them through GitHub Actions. Future Developer ID signing/notarization requires the maintainer's Apple credentials; do not commit signing keys. Licensed under [MIT](LICENSE).
