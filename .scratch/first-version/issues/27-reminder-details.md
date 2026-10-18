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
- [ ] Device (human): editing a Nudging reminder shows the lock note at the top, and VoiceOver reads the lock note as the hint of each disabled control, the Strength segments included. The Repeat and Custom pages lock, with the note, if the reminder starts nudging while they're open. *(Moved here from tickets 24 and 25, which have no Edit entry point.)*

Blocked by: 09, 24, 26

## Comments

**From ticket 26 (Now tab), decided 2026-10-17.** Until this ticket, nothing on Now opens a reminder: a nudge card's title, a Coming Up row and a Last 24 Hours row aren't buttons, and the rows have no chevron. This ticket makes each one open the details (the mockup's `data-open`) and adds the rows' `chevron.right` in `tertiaryLabel` (DESIGN.md › Reminder row). The card's title becomes the link, with no chevron, as DESIGN.md › Nudge card says. The rows are `NowRowLayout` in `App/Now/NowRows.swift`; the card is `NudgeCardView`, whose summary is one VoiceOver element, so it would get the button trait.
