# 13: VoiceOver says why a locked segment is dimmed

**What to build:** A bug fix. While a reminder is Nudging, VoiceOver on the Edit form's Strength and Pace segments gives the lock's reason, as it does on every other locked field.

**Blocked by:** none.

**Status:** needs-triage

Found during ticket 08's VoiceOver check, on Brian's iPhone (iPhone 15, iOS 27.0.1), 2026-10-22. Brian asked for this ticket.

## The bug

On a Nudging reminder's Edit form, VoiceOver reads the locked Repeat, Every and Break Through Focus rows as "label, value, dimmed", then the hint "Locked while it's nudging. Mark it Done or pause it to change it." The Strength and Pace segments never read the hint:

- "Selected, Gentle, button, 1 of 3", "Firm, dimmed, button, 2 of 3", "Relentless, dimmed, button, 3 of 3"
- "Escalating, dimmed, button, 1 of 2", "Selected, Consistent, button, 2 of 2"

So a VoiceOver user hears "dimmed" with no reason, and the selected segment doesn't say "dimmed" at all. `SegmentedChoiceSection` (`App/ReminderForm/ReminderFormSheet.swift`) puts `lockedWhileNudging`, and its hint, on the `Picker`, and VoiceOver reads the segments one by one, without the picker's hint. It's been there since first-version's ticket 13 for Strength; ticket 08 gave Pace the same section.

## What it should do

- [ ] VoiceOver on each locked Strength and Pace segment, the selected one too, reads the lock's reason (`LockNote.hint`), on an iPhone (phone and iOS version recorded).
- [ ] At accessibility sizes, where the segments become a menu, the locked menu reads the reason too.
- [ ] Unlocked, the segments read as they do now, with no hint.

## Comments
