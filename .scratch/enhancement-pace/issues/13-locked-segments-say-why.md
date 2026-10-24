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
- [ ] Ticket 12's iPhone check, below, is done on the iPhone, with each step's result and the phone and iOS version recorded in Comments.

## Ticket 12's iPhone check

Carried over from ticket 12 at Brian's request (2026-10-23). Ticket 12 made a permission banner, at accessibility text sizes, put its icon above the text and stretch Open Settings across the banner's width (`{rounded.control}` corners, grey fill), its label wrapping if it must. The simulators passed; this checks it on the phone, where it can run in the same session as this ticket's VoiceOver check. Apple's docs don't say how a `List` section header sizes a banner whose button wraps, which is why it's on the phone.

Brian drives it by hand, one step at a time, with a go before each (`docs/agents/device-testing.md`, Device-check walkthrough). Before it starts, note whether the app is installed (`xcrun devicectl device info apps`); if it wasn't, uninstall it afterwards. Brian puts back every setting he changes. If a step doesn't look as described, stop and say so before the next.

1. **One banner, largest text.** On the app's page in the Settings app, turn notifications off. Set the largest text size (Larger Text, accessibility sizes on, slider to the right). Open the app's Now tab.
   - Portrait: the banner's icon sits above its text. Open Settings spans the banner's width with rounded corners, grey fill and teal text, and reads whole ("Open / Settings" on two lines). Nothing spills past the banner's border.
   - Landscape: the same, with "Open Settings" on one line.
2. **Two banners.** Also turn the app's alarms off. Back on Now, both banners show, one under the other, each with its own full-width Open Settings, neither cut.
3. **Text size while a banner shows.** With Now open, step the text size from the largest down to the default and back, using the Text Size control in Control Center so Now stays on screen. At accessibility sizes the banner is stacked with the full-width button; below them the icon sits beside the text and Open Settings is the small pill under the text. No step clips or overlaps.
4. **VoiceOver.** Turn VoiceOver on and swipe through Now's banners. Each button reads its own label: "Open Settings for notifications, button", then "Open Settings for alarms, button". Double-tapping one opens Settings.
5. **Put back.** VoiceOver off, the text size as it was, notifications and alarms on again.

## Comments
