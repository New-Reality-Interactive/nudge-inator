Status: ready-for-agent

# Local store for reminders, tags and occurrence state

## What to build

Persist reminders, tags and each occurrence's state on the device (SwiftData or Core Data; pick one and record why in the ticket's Comments). No account, no server, no sync. The store file lives in the **App Group container** set up in ticket 01, so a widget extension can read it in a later version. With SwiftData that is `ModelConfiguration(groupContainer: .identifier("group.com.newrealityinteractive.nudgeinator"), cloudKitDatabase: .none)`. Set `cloudKitDatabase: .none` explicitly: its default is `.automatic`, which Apple says combines "your app's entitlements with the type's default values", so it would start syncing if a CloudKit entitlement were ever added. Use `isStoredInMemoryOnly: true` for tests.

**Blocked on an entitlement.** Ticket 01 deferred the App Group entitlement until the Apple Developer Program approves the account, and the group container needs it. Until then, keep the store location behind one configuration value so the code is final when the entitlement lands, and mark the "inside the App Group container" test as pending (skipped, with the reason) rather than failing or faking it. Whether the simulator needs the entitlement for the container is not stated in the docs: record what you observe. The engine stays pure: the store maps to and from the engine's plain types. Include a "delete all data" operation (used by ticket 28).

## Acceptance criteria

- [ ] Create a reminder with tags and a repeat, relaunch the store from disk in a test, and read back an equal value.
- [ ] Occurrence state (Nudging at nudge 4, Missed with reason, Skipped, Done) round-trips.
- [ ] Deleting a tag keeps the reminders and removes the tag from them.
- [ ] Delete-all-data empties reminders, tags and occurrences.
- [ ] Tests use an in-memory or temporary on-disk store and run under `scripts/test.sh`.
- [ ] The store location is inside the App Group container (assert the path in a test; pending until ticket 01's entitlement exists).
- [ ] No network access, and `cloudKitDatabase` is `.none` in the configuration.

Blocked by: 12, 15
