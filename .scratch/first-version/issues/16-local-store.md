Status: ready-for-agent

# Local store for reminders, tags and occurrence state

## What to build

Persist reminders, tags and each occurrence's state on the device (SwiftData or Core Data; pick one and record why in the ticket's Comments). No account, no server, no sync. The store file lives in the **App Group container** set up in ticket 01, so a widget extension can read it in a later version. The engine stays pure: the store maps to and from the engine's plain types. Include a "delete all data" operation (used by ticket 27).

## Acceptance criteria

- [ ] Create a reminder with tags and a repeat, relaunch the store from disk in a test, and read back an equal value.
- [ ] Occurrence state (Nudging at nudge 4, Missed with reason, Skipped, Done) round-trips.
- [ ] Deleting a tag keeps the reminders and removes the tag from them.
- [ ] Delete-all-data empties reminders, tags and occurrences.
- [ ] Tests use an in-memory or temporary on-disk store and run under `scripts/test.sh`.
- [ ] The store location is inside the App Group container (assert the path in a test).
- [ ] No network access and no CloudKit configuration.

Blocked by: 12, 15
