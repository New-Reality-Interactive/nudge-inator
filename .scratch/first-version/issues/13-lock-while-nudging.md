Status: ready-for-agent

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

- [ ] An Edit that changes due time, repeat, strength or Break through Focus on a Nudging reminder is rejected: occurrence state and plan are unchanged, and the result names the locked fields.
- [ ] An Edit that changes a locked field together with the title is rejected as a whole (no partial apply).
- [ ] An Edit that leaves every locked field at its current value is accepted.
- [ ] Editing the title changes the title in all later plan items and none of the already-passed ones.
- [ ] Notes and tag edits are accepted while Nudging and never reach any plan item text.
- [ ] The same Edit that was rejected is accepted once the occurrence is Done, Missed or Skipped, and applies from the next occurrence.
- [ ] A paused reminder, and a reminder whose next occurrence is not yet due, report nothing locked.
- [ ] Pause, edit a locked field, Resume works end to end: the field changes and the reminder returns at its next future time.
- [ ] The lock query is the only place the rule lives (the form and details tests read it from the engine).

Blocked by: 07, 11
