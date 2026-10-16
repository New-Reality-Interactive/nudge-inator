Status: resolved

# Delete a reminder

## What to build

A Delete event removes the reminder and cancels everything pending for it: the plan has no items for it, and any open occurrence is removed (not left as Missed). Tags it used are kept (tag rules in ticket 16). The confirmation dialog is a screen concern (ticket 27).

## Acceptance criteria

- [x] After Delete of a Nudging reminder the plan has zero items for it.
- [x] Other reminders' plans are unchanged.
- [x] Delete of an unknown or already-deleted reminder is a no-op, not a crash.
- [x] Tags the reminder used still exist. (Delete touches only the deleted reminder; the tag rule itself is tested in ticket 16. See Comments.)

Blocked by: 07

## Comments

**Decisions settled with the user before coding (2026-10-15).**
- **Delete is its own engine event: `delete(_ reminderID:)`.** It is not `update(reminders:)` without the reminder. Dropping a reminder from `update` keeps its Done records (ticket 07) and pause spans (ticket 11). A reminder that came back under the same ID, for example reloaded by the store, would then read old due times as Done or Skipped and still be paused. `delete` does four things:
  - removes the reminder;
  - clears its Done records;
  - clears its pause spans;
  - re-applies the plan.

  This matches the mockup's `deleteReminder`, which drops the reminder and its `occurrences` together ("This deletes its history too"). The confirmation sheet (`del`) belongs to the screen (ticket 27).
- **After Delete every occurrence query returns `nil`.** That covers `openOccurrence`, `latestOccurrence` and `occurrence(of:dueAt:)`. Each one starts from the held reminder, so a deleted reminder's open occurrence is removed, not left as Missed or Skipped. `isPaused` returns false.
- **"Tags it used still exist" is mostly ticket 16's.** Tags are plain strings on `Reminder`, and the engine has no tag entity and no public way to read reminders back. No tag entity was built, and no getter was added for a test alone. Delete touches nothing but the deleted reminder: `deletingOneReminderLeavesAnothersPlanItemsUnchanged` shows another reminder's plan items unchanged. When ticket 16 adds tag rules, it should test that deleting a reminder keeps its tags. That is the reverse of the mockup's `deleteTag`, which keeps the reminders.
- **Delete of an unknown or already-deleted ID is ignored, not reported.** It neither crashes nor applies a new plan, in the same spirit as Done with nothing open (07) and Resume when not paused (11).
- **Delete All Data (Settings, ticket 30) has no engine entry point.** It stays out of scope.

**Tests** are in `DeleteReminderTests.swift` (7 tests).
- **Red first:**
  - Delete of a Nudging reminder: there was no `delete`.
  - Delete twice and Delete of an unknown ID: a plan was re-applied.
  - Re-adding after Done: it came back Done.
  - Re-adding after Pause: it came back paused and Skipped, with an empty plan.
  - Delete of a reminder already dropped by `update`: found in review.
- **Passed on their first run, kept as acceptance coverage:** another reminder's plan items unchanged.

**Code review (two axes, against main).**
- **Spec: one bug, fixed.** The first version returned early for a reminder the engine didn't hold, before clearing anything. If the app pushed the store's new list through `update(reminders:)` before sending Delete, the Done records and pause spans survived. A reminder re-added under that ID then came back Done and paused. Now `delete` clears both records unconditionally and re-applies the plan only when it removed a held reminder. Tested by `deletingAReminderAlreadyDroppedFromTheListStillClearsItsHistory`. The reviewer confirmed each other line of `delete` is caught by a test when removed. Nothing is missing beyond the deferred tag criterion, and there is no scope creep.
- **Standards: no hard violations.** Fixed: `throws` dropped from four tests that never `try`, matching `StopAndDoneTests`.
- **Kept, as judgement calls:**
  - Per-reminder records now live in two places, plus the reminder list, keyed by reminder ID. Any new per-reminder record must also be cleared in `delete`; the re-add tests are the pattern to copy. Bundling them into one per-reminder record can wait until a third record appears.
  - `DeleteReminderTests` has its own `pills` fixture and `engine(for:)` helper, as each suite does.
- **For the store and wiring (tickets 17, 21, 27):** `update(reminders:)` replaces the whole list. If the app sends a stale list that still holds a deleted reminder, the reminder comes back, without its history. The store and the engine's Delete must agree, so delete from the store and call `engine.delete` together. The store must also drop the reminder's persisted Done records and pause spans.

**Left alone:** the lock while nudging (13), the fallbacks (14, 15), tags and My Day's counts (16), the store (17), the adapters (18–20), and every UI, including the delete confirmation (27) and Delete All Data (30).
