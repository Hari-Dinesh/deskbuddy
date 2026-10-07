# Contributing

Build and run `bash scripts/test.sh` on macOS. Keep the reminder engine independent of UI and network providers. Do not add private photographs, generated personal avatars, tokens, environment files or signing certificates. Tests use synthetic images.

Report platform, macOS version, app version, reminder type and whether Reduce Motion is on when reporting animation issues. No screen capture or personal image is required.

For a release: update VERSION and displayed UI version, run universal packaging and tests, commit, then tag with `v` followed by VERSION. The release workflow checks tag/version alignment and publishes ZIP plus SHA256SUMS. Developer ID signing and notarization should precede broad trusted distribution; the current workflow produces clearly documented ad-hoc builds.
