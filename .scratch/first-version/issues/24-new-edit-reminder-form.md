Status: ready-for-agent

# New / Edit Reminder form

Visual spec: mockup New Reminder and Edit screens. For the locked state, turn on **Lock nudging reminders** in the mockup controls, then edit a nudging reminder. The switch exists only so the mockup can compare the two: the app always locks (ticket 13).

Design spec: `docs/design/DESIGN.md` (Components: Buttons, Tags, Sheet bar buttons). Where it and the mockup disagree, see its Precedence note.

## What to build

The form: Title, Notes, Tags (any number, create a tag inline, one word shown as `#name`, case-insensitive unique), start date and time, Repeat (the seven presets, plus **Custom** in its own section, which opens the page from ticket 25 and may be disabled until then), Strength (Gentle, Firm, Relentless) and the **Break through Focus** switch. Save creates or edits through the app model (ticket 21). While the reminder is Nudging, due time, Repeat, Strength and the switch are shown disabled, each with a `lock` glyph, and a note at the top gives the reason: "Nudging now. Start, repeat, strength and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them. A new title shows from the next nudge." Each locked control's accessibility hint includes that note. Title, Notes and Tags stay editable. Ticket 13 owns the rule and the form reads it from the engine. The new reminder appears on the screen the person came from.

## Acceptance criteria

- [ ] Saving with an empty title is blocked with a visible reason.
- [ ] A new reminder with tags, Relentless and the switch on is saved and appears under Coming Up (needs ticket 26 to display; until then verify via the store in a UI/unit test).
- [ ] Typing `Home` when `#home` exists attaches the existing tag.
- [ ] Editing a Nudging reminder shows due time, Repeat, Strength and the switch disabled with the reason as text (not colour alone), and Title, Notes and Tags still save.
- [ ] Editing a paused, finished or not-yet-due reminder shows every field enabled.
- [ ] **Custom** on the Repeat page opens the ticket 25 page, and with a custom rule the Repeat row reads Custom and the footer gives its summary.
- [ ] Form works with VoiceOver labels on every control and at the largest Dynamic Type size.

Blocked by: 13, 17, 22, 23
