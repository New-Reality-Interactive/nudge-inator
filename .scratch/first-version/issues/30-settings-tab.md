Status: ready-for-agent

# Settings tab

Design spec: `docs/design/DESIGN.md` (Components: Settings row). Where it and the mockup disagree, see its Precedence note.

## What to build

Minimal Settings: status rows for notifications, alarms and Time Sensitive (from the adapters, with a way to open iOS Settings when denied: `UIApplication.openNotificationSettingsURLString` (iOS 16+) deep links to the app's notification settings, where the notification and Time Sensitive switches live; `UIApplication.openSettingsURLString` opens the app's page in Settings, which is the one to use for alarms. Pass the URL to `UIApplication.shared.open`. The docs say AlarmKit authorization can be changed in the Settings app but don't name the screen: check on a device which link lands where), **Send a Test Nudge** (a real nudge through the adapters, so the person can check it works), and **Delete All Data** (confirmation, then ticket 17's delete-all and cancel of everything pending). Also a link to How It Nudges (ticket 31).

## Acceptance criteria

- [ ] Status rows reflect fake permission states in a test (allowed, denied, not determined).
- [ ] Denied rows offer an Open Settings action that uses the URL strings above (assert the URL, not the system behavior); on a device it lands on the right Settings page (human check).
- [ ] Send a Test Nudge schedules one nudge via the plan path and is cancelled by Done.
- [ ] Delete All Data requires confirmation; after it the store and all pending items are empty.
- [ ] Matches the mockup's Settings screen.

Blocked by: 21, 23
