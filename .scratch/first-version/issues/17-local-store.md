Status: resolved

# Local store for reminders, tags and occurrence state

## What to build

Persist reminders, tags and each occurrence's state on the device (SwiftData or Core Data; pick one and record why in the ticket's Comments). No account, no server, no sync. The store file lives in the **App Group container** set up in ticket 01, so a widget extension can read it in a later version. With SwiftData that is `ModelConfiguration(groupContainer: .identifier("group.com.newrealityinteractive.nudgeinator"), cloudKitDatabase: .none)`. Set `cloudKitDatabase: .none` explicitly: its default is `.automatic`, which Apple says combines "your app's entitlements with the type's default values", so it would start syncing if a CloudKit entitlement were ever added. Use `isStoredInMemoryOnly: true` for tests.

**Blocked on an entitlement.** Ticket 01 deferred the App Group entitlement until the Apple Developer Program approves the account, and the group container needs it. Until then, keep the store location behind one configuration value so the code is final when the entitlement lands, and mark the "inside the App Group container" test as pending (skipped, with the reason) rather than failing or faking it. Whether the simulator needs the entitlement for the container is not stated in the docs: record what you observe. Store the repeat as the engine's repeat-rule value (a preset or a custom rule, ticket 09), not as a bare preset enum, so custom rules need no later migration. The engine stays pure: the store maps to and from the engine's plain types. Include a "delete all data" operation (used by ticket 30).

## Acceptance criteria

- [x] Create a reminder with tags and a repeat, relaunch the store from disk in a test, and read back an equal value.
- [x] A custom repeat rule (for example every 2 weeks on Monday and Wednesday, 5 times) round-trips and reads back equal, and a preset reads back as the same preset.
- [x] Occurrence state (Nudging at nudge 4, Missed with reason, Skipped, Done) round-trips.
- [x] Deleting a tag keeps the reminders and removes the tag from them.
- [x] Delete-all-data empties reminders, tags and occurrences.
- [x] Tests use an in-memory or temporary on-disk store and run under `scripts/test.sh`.
- [x] The store location is inside the App Group container (assert the path in a test; pending until ticket 01's entitlement exists).
- [x] No network access, and `cloudKitDatabase` is `.none` in the configuration.

Blocked by: 09, 13, 16

## Comments

**Decisions settled with the user before coding (2026-10-16).**
- **SwiftData, not Core Data.** The ticket's own configuration is SwiftData, and it covers what 17 needs:
  - the group container (`groupContainer: .identifier(_:)`);
  - CloudKit off (`cloudKitDatabase: .none`);
  - an in-memory store (`isStoredInMemoryOnly`);
  - an explicit file (`init(_:schema:url:allowsSave:cloudKitDatabase:)`) for relaunch tests.

  apple-rag confirms all of these on iOS 17+, so they're available on 26.1. The `@Model` classes stay in the app target and map to the engine's plain values, so the engine stays pure. `ReminderStore` is a `@MainActor` struct over the container's `mainContext`, since ticket 21's app model is `@MainActor`.
- **The engine takes history back through a new public value, `ReminderHistory`:** closed occurrences (`Closing`: state, `closedAt`, `nudgesSent`), `editAppliesAfter`, pause spans (`PauseSpan`) and replaced titles (`Replaced<String>`). `Closing`, `PauseSpan` and `Replaced` are now public.
  - **Read-out:** `engine.histories`.
  - **Input:** `update(histories:)`. It replaces what the store saves for every reminder and keeps the alarm-limit records, which aren't saved (ticket 15). Like `update(tags:)`, it applies no plan.
  - The engine's private `History` now holds a `saved: ReminderHistory` beside the two alarm-limit sets, so Delete still clears one record.
  - **For ticket 21:** at launch, call `update(tags:)`, then `update(histories:)`, then `update(reminders:)`. That plans once, with the history in place.
  - **Also for ticket 21:** after every event, save the whole picture with `store.save(StoredData(reminders: engine.reminders, tags: engine.tags, histories: engine.histories))`.
  - On Delete, call `store.delete(id)` with `engine.delete(id)` (ticket 12).
  - On a tag delete, call `store.deleteTag(id)` with `engine.deleteTag(id)` (ticket 16).
- **Repeat: RRULE text plus a `missingDay` column**, not the rule's fields as columns. It reads back through `RepeatRule(rrule:)` with `missingDay` set, so Every Month (`FREQ=MONTHLY`, `.lastDayOfMonth`) reads back as the preset and not as the custom rule with the same text. A `.untilTime` end also keeps its exact instant in `repeatUntilTime`, because RRULE text keeps only whole seconds (found in review). Text that no longer parses makes `load()` throw `StoreError.unreadable`. Nothing is dropped quietly.
- **Tags: an ordered `[UUID]` on each reminder record**, not a relationship. SwiftData relationships come back unordered, and the engine's `tagIDs` has an order. `deleteTag(_:)` deletes the tag record and strips its ID from every reminder, which stays.
- **History records** are child models with a `.cascade` delete rule: `ClosedOccurrenceRecord`, `PauseSpanRecord` and `ReplacedTitleRecord`. Pause spans and titles carry a `position`, since relationships are unordered. A mutation run without the sort failed, so the order really does come back scrambled. Reminders and tags carry a `position` too, so the engine's list order is kept.
- **Not saved:** the alarm-limit reports and cap records (tickets 14, 15) and the replaced permissions (ticket 14).
- **Delete All Data** deletes every reminder, tag and history record with `ModelContext.delete(model:)` on each type. It returns nothing. `ModelContainer.deleteAllData()` is deprecated in the 26.5 SDK, and apple-rag doesn't give its replacement `erase` an availability. **For ticket 30:** call `store.deleteAllData()`, then hand the engine empty tags, histories and reminders. The plan then empties and the adapters cancel everything pending.
- **`save` replaces what the store held:**
  - anything left out is deleted, with its history;
  - a history whose reminder isn't in the save isn't saved;
  - a save that lists a reminder or tag ID twice throws `StoreError.duplicateID` and changes nothing.

**The App Group container check.** The "Blocked on an entitlement" paragraph above is out of date: ticket 01 added the App Group to the app and widget in `project.yml`. In a simulator test run (the test host is the app), `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` resolves on both iOS 26.1 and 26.5. It's under `…/CoreSimulator/Devices/<device>/data/Containers/Shared/AppGroup/<UUID>/`. So `theAppStoreLivesInTheAppGroupContainer` asserts the path and isn't pending. It reads `ReminderStore.configuration(for: .appGroup).url` without opening the real store.

With `groupContainer: .none`, the store went to the app's own `Library/Application Support/default.store` instead, and the test failed, as it should.

**No network.** `cloudKitDatabase` is `.none` for every location. `CloudKitDatabase` isn't `Equatable`, so the test compares descriptions, after checking that `.none` and `.automatic` describe differently. The store makes no network calls. Nothing else in the diff touches the network.

**Tests.**
- **Engine:** `RestoredHistoryTests` (7) in NudgeEngineTests. Each one relaunches into a new engine and checks the same result:
  - Done stays Done;
  - a pause stays paused, and a resumed pause stays ended;
  - passed nudges keep their old title;
  - an Edit's never-happened due times stay gone;
  - alarm-limit reports survive `update(histories:)`;
  - `update(histories:)` applies no plan.
- **Store:** `ReminderStoreTests` (17) and `StoredOccurrenceTests` (5) in NudgeInatorTests, with a temporary on-disk store and app-target fakes. They cover:
  - a reminder with tags and a repeat round-tripping;
  - every preset, Never and the ticket's custom rule;
  - a full history, including equal-time pauses and titles;
  - an exact UNTIL instant;
  - every strength and every closed state;
  - delete tag, delete reminder, replace on save, duplicate IDs and Delete All Data;
  - CloudKit off, in-memory, and the App Group path;
  - Nudging at nudge 4, Done, Missed at the give-up limit, Missed fixed by an Edit, and Skipped, each through store and engine.
- The placeholder app test is gone.
- **Red first:**
  - the engine slices for Done, pause, titles, `editAppliesAfter` and alarm reports;
  - the first round trip, Done and Skipped through the store;
  - the full history (titles and `editAppliesAfter`);
  - delete tag, Delete All Data, and the configuration tests;
  - the review's tie order, UNTIL and duplicate IDs.
- **Passed on their first run, kept as acceptance coverage:**
  - the repeat table, since the mapping came in with the first slice;
  - Nudging at nudge 4 and Missed at the give-up limit (clock-computed), and Missed fixed by an Edit (a saved closing);
  - replace on save;
  - `update(histories:)` applying no plan;
  - the strength and state tables.
- `delete(_:)` was written in the same step as its test, so its red wasn't seen.
- **Mutation-checked:**
  - dropping the `missingDay` restore fails Every Month and Every Year;
  - dropping the pause and title sort fails the history round-trip;
  - `groupContainer: .none` with `cloudKitDatabase: .automatic` fails the path and CloudKit tests.

**Code review (two axes, against main).**
- **Spec.** Fixed, each with a test:
  - **Equal-time pauses could come back reversed.** Pause, Resume and Pause in one instant leaves two spans with the same start. Sorting by `start` could put the open one first, and the reminder loaded as unpaused. Titles had the same tie. Both now save a `position` (`historyRecordsWithEqualTimesKeepTheirOrder`, run five times).
  - **UNTIL lost sub-seconds through RRULE text.** It's now saved exactly beside the text (`aRepeatEndingAtAnInstantKeepsItExactly`).
  - **A reminder ID listed twice** wrote two records under one unique ID. The save now throws `duplicateID`, and tag IDs are checked too (`aSaveWithAReminderIDTwiceIsTurnedDownAndChangesNothing`, `aSaveWithATagIDTwiceIsTurnedDown`).
  - **A history with no reminder was dropped quietly.** That's intended, and is now documented on `save` and tested (`aHistoryWithNoReminderIsNotSaved`).
  - **`Dictionary(uniqueKeysWithValues:)` would crash on bad data.** The fetches now keep the first record, and two closings for one due time throw `unreadable`.
  - Kept: the no-network check is the CloudKit setting plus the absence of network code. There's no runtime way to assert "no network" from a unit test.
- **Standards: no hard violations.** Fixed:
  - `ReminderStore` is a struct. AGENTS.md: `final class` only for identity or `@Observable`.
  - The engine's private `records` is now `historyByReminder`, so it doesn't clash with the store's `*Record` types.
  - `History` holds `saved: ReminderHistory`, so the field-by-field copies are gone. A new saved field now touches `ReminderHistory` and the store only.
  - `deleteReminder` is now `delete(_:)`, matching `engine.delete`.
  - `save` shares one `recordsByID(of:)` fetch.
  - `StoreError.unreadable` takes a `Field` enum, not a string.
  - The test helper is `store()`.
  - Every strength and every closed state now has a round-trip test, which covers the mirrored switches.
- **Kept, as judgement calls:**
  - The two-way switches for stored enum values. The engine's enums aren't `CaseIterable`, so the writing switch is the one the compiler checks, and the tables test the reading one. A comment says so.
  - The app tests' `Fakes.swift`, `NewYork` and `Tag` alias copy the engine tests' helpers, since the two test targets can't share files without a support target.
  - The launch order is written out in both test suites. Ticket 21 will write it once more, as the composition root.
  - `Replaced<Value>` stays generic. It was already shared by titles and permissions.

**Left alone:** the adapters (18–20), wiring the store into the app and saving after events (21), every UI including Settings' Delete All Data button (30), and sync, CloudKit and the network. A schema migration plan isn't needed until the schema changes after a release.
