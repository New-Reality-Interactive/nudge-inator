Status: ready-for-agent

# Pause and Resume

## What to build

- **Pause**: the reminder stops nudging without being lost. A Nudging occurrence closes as **Skipped** (not Missed); the plan for the reminder is empty. A paused reminder creates no occurrences.
- **Resume**: the reminder returns at its **next future** due time (for a repeat, the next preset time after now; for Never, if the due time is past, state what happens, e.g. stays paused-ended or asks for a new time, and write it into the test).

## Acceptance criteria

- [ ] Pausing a Nudging reminder: occurrence state Skipped, plan empty.
- [ ] While paused, time passing creates no occurrences and no plan items.
- [ ] Resuming a repeating reminder schedules its next future occurrence, not a past one.
- [ ] Skipped does not count as Missed in the counts used by My Day (see ticket 15).
- [ ] Pausing a reminder with no open occurrence just flips paused state.

Blocked by: 07, 08
