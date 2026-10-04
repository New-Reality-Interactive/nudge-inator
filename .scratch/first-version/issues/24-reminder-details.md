Status: ready-for-agent

# Reminder details

## What to build

Details screen with the reminder's title, notes, tags, due time, repeat, strength, Break through Focus and the current occurrence state. Actions: **Done** (when Nudging), Edit (opens ticket 22 form), Pause or Resume, and Delete with a confirmation. Reachable from Now, My Day, a tag's list, and the Open intent (ticket 19).

## Acceptance criteria

- [ ] Done is shown only while Nudging and ends the occurrence.
- [ ] Pause on a Nudging reminder shows it as Skipped (not Missed) afterwards; Resume returns it at its next future time.
- [ ] Delete asks for confirmation; Cancel keeps it; Confirm removes it and its pending items.
- [ ] A route-to-reminder entry point exists for ticket 19 and an unknown ID shows a "reminder not found" state.
- [ ] Notes and tags appear here and nowhere in notification or alarm content.

Blocked by: 22, 23
