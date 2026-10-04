Status: ready-for-agent

# Settings tab

## What to build

Minimal Settings: status rows for notifications, alarms and Time Sensitive (from the adapters, with a way to open iOS Settings when denied), **Send a Test Nudge** (a real nudge through the adapters, so the person can check it works), and **Delete All Data** (confirmation, then ticket 16's delete-all and cancel of everything pending). Also a link to How It Nudges (ticket 28).

## Acceptance criteria

- [ ] Status rows reflect fake permission states in a test (allowed, denied, not determined).
- [ ] Send a Test Nudge schedules one nudge via the plan path and is cancelled by Done.
- [ ] Delete All Data requires confirmation; after it the store and all pending items are empty.
- [ ] Matches the mockup's Settings screen.

Blocked by: 20
