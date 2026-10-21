# Microsoft 365 calendar and Teams meeting reminders

Status in v2.1.0: native device-code sign-in, Keychain token storage, read-only calendar sync, upcoming meetings, reminder lead time, snooze/dismiss, safe Teams/Outlook links and scheduled-meeting quiet time are implemented. Tests use mocked Microsoft responses. A real tenant sign-in must still be performed by the user; no shared client ID is bundled in the default release.

## What you get

Open the drop icon → Calendar / Teams. The app reads your default Microsoft 365 calendar for the next 24 hours and refreshes about once a minute while awake. It resolves recurring occurrences through Graph calendarView. Default reminders appear five minutes before each event; choose 1–30 minutes. Dismiss acknowledges that occurrence, Not yet snoozes for one minute, and Open meeting opens a validated Teams or Outlook HTTPS URL. Calendar alerts and quick reminders take priority over water/meal prompts.

This reads calendar meetings associated with Teams; it does not connect to Teams chat, send messages, create calendar events, record calls or detect actual call participation. All-day events are excluded. No OnlineMeetings.Read or chat permission is requested. An Exchange/Outlook calendar accessible through Microsoft Graph is required.

## First-time setup (no client ID yet)

You or your Microsoft administrator must register a public-client application. Organization policies may restrict app registration, consent or device-code sign-in; DeskBuddy cannot override those policies.

1. Sign in to [Microsoft Entra admin center](https://entra.microsoft.com/) with your work account.
2. Open **Identity → Applications → App registrations → New registration**. Name it `DeskBuddy Calendar`.
3. For a personal/workplace setup, choose **Accounts in this organizational directory only**. Register the app. Copy **Application (client) ID** and **Directory (tenant) ID** from Overview.
4. Open **Authentication → Advanced settings → Allow public client flows**, set **Yes**, and save. Device-code flow does not need a redirect URI. Do not create a client secret.
5. Open **API permissions → Add a permission → Microsoft Graph → Delegated permissions**. Add **Calendars.ReadBasic** and **offline_access**. DeskBuddy requests exactly `offline_access Calendars.ReadBasic`; remove unrelated permissions from a dedicated app if your administrator agrees. Microsoft may require administrator consent under your tenant policy.
6. In DeskBuddy, open **Calendar / Teams**. Paste the client ID and tenant ID. Click **Connect Microsoft calendar**.
7. Copy the displayed one-time code. Click **Open Microsoft sign-in** (https://microsoft.com/devicelogin), enter the code, sign in and approve the requested read-only access. Do not share the device code in chat or enter it anywhere except Microsoft's sign-in page.
8. Return to DeskBuddy. Wait for **Connected · calendar updated**, then check the upcoming list and last-sync time. Use **Sync now** after making a calendar change. A real upcoming meeting is needed to validate live delivery.

For a public multi-tenant deployment, the maintainer can register and verify one multi-tenant app, satisfy Microsoft/tenant consent policies, and distribute its public client ID. Build with `DESKBUDDY_MICROSOFT_CLIENT_ID=<public-client-uuid> bash scripts/build.sh`. The public ID is configuration, not a secret; no account tokens belong in build variables. Users still sign in and consent individually. The current public binary leaves this ID blank.

## Data and behavior

- Access and refresh tokens are stored only in macOS Keychain under the app's service/account, never in JSON or UserDefaults. Refresh-token rotation is saved.
- Meeting titles/times and join URLs are cached locally in `~/Library/Application Support/DeskBuddy/workspace.json`, with owner-only file permissions. Quick notes never go to Microsoft.
- Offline/server failures retain the last successful calendar and label it cached. Cancellations cannot be known while offline. A successful full sync removes cancelled/removed occurrences; rescheduled occurrences can notify again.
- Expired/revoked authorization disables meeting alerts and clears cached meetings. Reconnect to resume. 429 Retry-After is respected, including manual sync requests.
- The app requests UTC from Graph, then displays local time. Unrecognized timestamps fail the sync rather than silently replacing the previous schedule.
- Water and meal prompts can be deferred during scheduled meeting intervals. This is calendar-based quiet time, not live Teams presence.
- After waking, a meeting alert is shown only if that meeting has not ended. Quick reminders remain overdue until completed/deleted and can alert again after ten minutes if unanswered.
- Due alerts wait while another avatar scene is active or Quiet for one hour is on. The app must be running; it does not wake a sleeping Mac or deliver notifications after Quit.
- Disconnect removes local Microsoft tokens and cached meetings. To revoke the consent grant on Microsoft's side, also use your Microsoft account/organization's app-access settings.

## Troubleshooting

- **Client ID / tenant invalid**: use GUIDs copied from Overview, not the application name or a secret. For single-tenant registrations, use the actual directory GUID. `organizations` is for appropriately configured work/school multi-tenant apps; `common` requires compatible account support.
- **Public client blocked / code flow blocked**: enable public-client flows or ask the administrator. Conditional Access may disallow device flow; the app currently does not offer an alternate interactive flow.
- **Consent / HTTP 403**: verify delegated calendar permission, mailbox availability and organization approval.
- **Code expired / cancelled**: click Connect again; do not reuse an old code.
- **Keychain error**: allow the app's normal Keychain access if appropriate. Rebuilt/ad-hoc apps may prompt again. Tokens are never copied into a workaround file.
- **No meetings**: check your default Outlook calendar, time window and last-sync status. Other shared/delegated calendars are not included in this version.

## Extension boundaries

`MicrosoftCalendarClient` implements the transport; `WorkspaceModel` coordinates sign-in/sync; `WorkspaceData` owns durable notes/reminders and merge policy. `ReminderIntegration` remains the generic contract for future providers. No network request runs inside the animation loop.

## Primary references

- [Microsoft device authorization protocol](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)
- [CalendarView API and least-privileged permissions](https://learn.microsoft.com/en-us/graph/api/calendar-list-calendarview?view=graph-rest-1.0)
- [Meeting join information through the calendar event](https://learn.microsoft.com/en-us/graph/outlook-calendar-online-meetings)
