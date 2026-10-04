Status: ready-for-agent

# New / Edit Reminder form

Visual spec: mockup New Reminder and Edit screens.

## What to build

The form: Title, Notes, Tags (any number, create a tag inline, one word shown as `#name`, case-insensitive unique), start date and time, Repeat (the seven presets), Strength (Gentle, Firm, Relentless) and the **Break through Focus** switch. Save creates or edits through the app model (ticket 20). Editing a Nudging reminder shows the engine's preview warning before applying when the edit would skip the occurrence (ticket 12). The new reminder appears on the screen the person came from.

## Acceptance criteria

- [ ] Saving with an empty title is blocked with a visible reason.
- [ ] A new reminder with tags, Relentless and the switch on is saved and appears under Coming Up (needs ticket 23 to display; until then verify via the store in a UI/unit test).
- [ ] Typing `Home` when `#home` exists attaches the existing tag.
- [ ] Editing a Nudging reminder's due time to the future shows the skip warning, and Cancel leaves it unchanged.
- [ ] Form works with VoiceOver labels on every control and at the largest Dynamic Type size.

Blocked by: 16, 21
