# Future Microsoft Teams / calendar integration

Status: **provider contract and quiet-time policy only. No Teams connection, OAuth flow or Graph requests are implemented.**

`ReminderIntegration` supplies normalized meeting intervals. `IntegrationPolicy` considers only explicitly enabled provider IDs and current valid meetings. A future coordinator can use the returned end time to defer reminders. This boundary is not wired to any live provider today.

Recommended first scope: avoid reminders during calendar meetings, optionally remind shortly before an upcoming meeting. Do not infer live call attendance from scheduled calendar intervals. Reading or sending Teams messages is a separate feature and needs explicit user authorization.

Implementation checklist:

1. Register a native/public-client Microsoft application. Use a supported MSAL flow or authorization code with PKCE; never embed a client secret in the desktop app.
2. Start with delegated calendar read permissions. Microsoft lists `Calendars.ReadBasic` as least privileged for `calendarView`; verify the exact properties needed before adding permissions. Organization consent policies still apply.
3. Store OAuth tokens in macOS Keychain, not UserDefaults, avatar folders, Git or logs. Add disconnect/revoke and cache deletion behavior.
4. Handle expiry, cancellation, 401 reauthentication, 429 Retry-After, bounded polling, offline use, UTC conversion, overlapping meetings and recurring events.
5. Keep providers disabled until consent. Fetch on a separate schedule, never in the animation loop. Fail back to local reminders when provider data is unavailable; show provenance/status clearly.
6. Inject provider events into the coordinator and add tests for rate limiting, failure, quiet-time expiry and cancellation. Validate in a real tenant before calling it connected.

Primary references:

- [Microsoft desktop app configuration](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-configuration)
- [Graph calendarView permissions and API](https://learn.microsoft.com/en-us/graph/api/calendar-list-calendarview?view=graph-rest-1.0)
- [Desktop authorization-code flow with PKCE](https://learn.microsoft.com/en-us/entra/identity-platform/tutorial-v2-nodejs-desktop)

The PKCE tutorial is an Electron example; reuse the authentication requirements, not its JavaScript UI implementation, for the native Swift app.
