Status: ready-for-agent

# Reminder details

Design spec: `docs/design/DESIGN.md` (Components: Reminder row, Via label, Buttons). Where it and the mockup disagree, see its Precedence note.

## What to build

Details screen with the reminder's title, notes, tags, due time, repeat (the engine's summary from ticket 09, for presets and custom rules alike), strength, Break through Focus and the current occurrence state. Actions: **Done** (when Nudging), Edit (opens ticket 24 form; the locked fields are disabled there while Nudging, ticket 13), Pause or Resume, and Delete with a confirmation. Reachable from Now, My Day, a tag's list, and the Open intent (ticket 20).

## Acceptance criteria

- [ ] Done is shown only while Nudging and ends the occurrence.
- [ ] Pause on a Nudging reminder shows it as Skipped (not Missed) afterwards; Resume returns it at its next future time.
- [ ] Edit stays available while Nudging, and the Schedule section ends with the `lock` glyph and "Start, repeat, strength and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them."
- [ ] A custom repeat shows its plain-language summary.
- [ ] Delete asks for confirmation; Cancel keeps it; Confirm removes it and its pending items.
- [ ] A route-to-reminder entry point exists for ticket 20 and an unknown ID shows a "reminder not found" state.
- [ ] Notes and tags appear here and nowhere in notification or alarm content.

Blocked by: 09, 24, 26
