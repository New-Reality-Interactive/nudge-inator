Status: ready-for-agent

# Pause and Resume

## What to build

- **Pause**: the reminder stops nudging without being lost. A Nudging occurrence closes as **Skipped** (not Missed); the plan for the reminder is empty. A paused reminder creates no occurrences.
- **Resume**: the reminder returns at its **next future** due time (for a repeat, the next preset time after now; for Never whose due time is past, the engine rejects the Resume with "needs a new due time" and the reminder stays paused; the screen sends the person to the edit form, where the due time is editable because a paused reminder is not locked). Pause, edit, Resume is the supported way to change a locked field while nudging (ticket 13, ADR 0002), so this path must be solid.

## Acceptance criteria

- [ ] Pausing a Nudging reminder: occurrence state Skipped, plan empty.
- [ ] While paused, time passing creates no occurrences and no plan items.
- [ ] Resuming a repeating reminder schedules its next future occurrence, not a past one.
- [ ] Skipped does not count as Missed in the counts used by My Day (see ticket 16).
- [ ] Pausing a reminder with no open occurrence just flips paused state.
- [ ] Resuming a Never reminder whose due time is past is rejected with "needs a new due time" and leaves it paused; after the due time is edited to the future, Resume succeeds.

Blocked by: 07, 08
