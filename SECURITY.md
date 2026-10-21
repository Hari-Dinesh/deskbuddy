# Security and privacy reports

Please do not include tokens, private photographs or chat content in public issues. Report non-sensitive reproduction steps through a GitHub issue; use GitHub private vulnerability reporting if the repository maintainer has enabled it.

Current releases are ad-hoc signed and not notarized. The installer verifies release checksums and bundle integrity, does not disable macOS security controls, and does not require sudo. Checksums downloaded from the same release do not provide independent publisher authentication.

Microsoft calendar is opt-in in v2.1.0, uses delegated Calendars.ReadBasic/offline_access, and stores access/refresh tokens in Keychain. Local notes/reminders and cached meeting metadata are owner-readable JSON. No chat/message/calendar-write APIs are used. Disconnect removes local tokens/cache; Microsoft consent revocation is separate. Device codes must only be entered on Microsoft sign-in pages. Actual tenant sign-in still requires configured public-client registration and consent.
