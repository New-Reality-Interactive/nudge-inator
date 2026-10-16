Status: resolved

# Lock due time, repeat, strength and Break through Focus while Nudging

## What to build

While a reminder has a Nudging occurrence, four of its fields are **Locked**: due time, repeat, strength and Break through Focus. An Edit event that changes any of them is rejected whole, with no change to state or plan, and the result names the locked fields so the screen can say why. Decision and trade-offs: ADR 0002.

Title, notes and tags stay editable. A new title applies from the next nudge: later plan items carry it, nudges already delivered don't. Notes and tags never reach a plan item.

The lock lifts the moment the occurrence closes (Done, Missed or Skipped). A reminder that is paused, finished, or whose next occurrence is not yet due is never locked. The ways to change a locked field are:

- **Done**, then edit. For a repeating reminder the next occurrence is in the future, so the edit applies to it.
- **Pause**, edit, **Resume** (ticket 11).
- **Delete**.

The engine exposes the lock as a query ("which fields are locked for this reminder now?") so the form (ticket 24) and the details screen (ticket 27) show it without copying the rule. An Edit that sets a locked field to its current value is accepted, because the form saves the whole reminder.

## Acceptance criteria

- [x] An Edit that changes due time, repeat, strength or Break through Focus on a Nudging reminder is rejected: occurrence state and plan are unchanged, and the result names the locked fields.
- [x] An Edit that changes a locked field together with the title is rejected as a whole (no partial apply).
- [x] An Edit that leaves every locked field at its current value is accepted.
- [x] Editing the title changes the title in all later plan items and none of the already-passed ones.
- [x] Notes and tag edits are accepted while Nudging and never reach any plan item text.
- [x] The same Edit that was rejected is accepted once the occurrence is Done, Missed or Skipped, and applies from the next occurrence.
- [x] A paused reminder, and a reminder whose next occurrence is not yet due, report nothing locked.
- [x] Pause, edit a locked field, Resume works end to end: the field changes and the reminder returns at its next future time.
- [x] The lock query is the only place the rule lives (the form and details tests read it from the engine).

Blocked by: 07, 11

## Comments

**Decisions settled with the user before coding (2026-10-15).**
- **Edit is its own engine event: `edit(_ reminder:) throws(EditError)`.** `update(reminders:)` stays unchecked. It is App opened and, later, the store's reload (17), and both report what is already true, not a change the person made. Checking them would reject the store's own data. **For the wiring and the form (tickets 21, 24):** the edit form must send `edit`, not a new list through `update`. Ticket 11's tests still edit a paused reminder through `update`, and they pass unchanged.
- **The lock query is `lockedFields(of:) -> Set<LockedField>`.** `LockedField` has four cases: `dueTime`, `repeatRule`, `strength` and `breakThroughFocus`. The query returns all four while the reminder has a Nudging occurrence, and none otherwise: paused, finished, not yet due, or an ID the engine doesn't hold. `edit` calls it, so the rule lives only there. The form and details tests (24, 27) should read it from the engine.
- **The rejection names the locked fields the Edit changed**, not all four: `EditError.locked([.strength])`. It is `Sendable` and `Equatable`, like `ResumeError`. The screen can read all four from `lockedFields(of:)`.
- **Equality.** The due time must match as an exact `Date`. The repeat uses `RepeatRule`'s synthesized `Equatable`, and two Never repeats (`nil` and `nil`) match. Strength and Break through Focus use plain `==`. The comparison is `LockedField.isChanged(from:to:)`.
- **The title criterion: passed nudges keep the old title (the user chose this over defining it on later items only).** The plan still holds the open ladder's passed nudge times, so the engine records each reminder's replaced titles with the time an Edit replaced them. A plan item keeps the title in force when it fired. A nudge firing exactly at the Edit counts as delivered (`fireTime <= replacedAt`). Tested by `editingTheTitleWhileNudgingChangesOnlyLaterPlanItems` and `eachPassedNudgeKeepsTheTitleItWasDeliveredWith` (two edits). A title that arrives through `update(reminders:)` makes no record.
- **Done, then an Edit that moves a repeat's due time: ticket 07's rule stands (the user's choice).** Done is keyed by due time, so moving today's 9:00 to 9:20 after Done at 9:30 makes 9:20 a new occurrence, which nudges at once (`anEditAfterDoneThatMovesTheDueTimeEarlierTodayOpensThatOccurrence`). The form shouldn't offer a past time (ticket 24).
- **An Edit of an unknown ID is ignored, not reported.** It neither throws nor applies a plan, like Done, Resume and Delete.

**Tests** are in `LockWhileNudgingTests.swift` (14 tests, 18 cases), plus one in `DeleteReminderTests.swift`.
- **Red first:**
  - The strength rejection: there was no `edit` or `EditError`.
  - The title applying only to later items: the edit applied nothing.
  - Delete clearing the earlier titles: a reminder added back under the same ID inherited them.
  - Both review findings (below).
- **Passed on their first run, kept as acceptance coverage:**
  - Each of the four locked fields.
  - A locked field changed together with the title, rejected whole.
  - Notes and tags never reaching plan text.
  - The rejected Edit accepted after Done, after Missed, and through Pause, edit, Resume.
  - Nothing locked when not yet due, finished or paused.
  - The Done and due-time rule.
  - The unknown ID.
  - The two-edit title test, added to pin which earlier title a passed nudge keeps.
- **Mutation-checked:** dropping the rejection guard fails the rejection tests, and looking up the last replaced title instead of the first fails the two-edit test.

**Code review (two axes, against main).**
- **Spec: one bug, fixed.** Missed and Skipped are computed from the reminder's current fields. Once the lock lifted after give-up, an Edit to a slower strength rewrote the past. A Firm reminder Missed at 11:30 and edited to Gentle came back as Nudging, locked again, with today's Gentle ladder in the plan. Paused after the Missed and then edited, it read as Skipped. The spec says the Edit "applies from the next occurrence". The fix: an accepted Edit fixes the reminder's latest occurrence in its closed state when it has already closed (Missed or Skipped), recorded by due time next to Done. Tested by `anEditToASlowerStrengthAfterMissedLeavesTheOccurrenceMissed` and `anEditWhilePausedLeavesAnOccurrenceMissedBeforeThePauseMissed`. Older occurrences under the shipped limits always closed by give-up, whatever the strength. An Edit that changes the repeat leaves old due times that are no longer due times, so `occurrence(of:dueAt:)` returns `nil` for them. Keeping that history is for the store and My Day (17, 28).
- **Standards: no hard violations.** Fixed:
  - Records spread across separate maps. Done records, pause spans and now replaced titles were three per-reminder records, which ticket 12 said to bundle at the third. They are now one private `History` per reminder (closed occurrences, pause spans, replaced titles), and `delete` clears it in one line. Done is a `.done` entry in the closed occurrences.
  - The field comparison was a `Reminder` method that only worked for locked fields. It moved onto `LockedField`.
  - `update(reminders:)` now has a doc comment saying it is not the Edit path.
- **Kept, as judgement calls:** the three after-close tests repeat their arrange block, matching the other suites. The `lockedFields(of:)` doc names its future callers (24, 27).

**For the store (ticket 17):** it must persist each reminder's history: closed occurrences (Done, and Missed or Skipped fixed by an Edit), pause spans and replaced titles. It must seed them into a new engine and drop them on Delete.
**For the adapters (ticket 18):** passed plan items are already delivered, so the adapter shouldn't schedule fire times that have passed.

**Left alone:** the fallbacks (14, 15), tags and My Day's counts (16), the store (17), the adapters (18–20), and every UI, including the form's disabled fields and LOCK_NOTE (24) and the details screen (27).
