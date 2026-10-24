# 13: VoiceOver says why a locked segment is dimmed

**What to build:** A bug fix. While a reminder is Nudging, VoiceOver on the Edit form's Strength and Pace segments gives the lock's reason, as it does on every other locked field.

**Blocked by:** none.

**Status:** resolved

Found during ticket 08's VoiceOver check, on Brian's iPhone (iPhone 15, iOS 27.0.1), 2026-10-22. Brian asked for this ticket.

## The bug

On a Nudging reminder's Edit form, VoiceOver reads the locked Repeat, Every and Break Through Focus rows as "label, value, dimmed", then the hint "Locked while it's nudging. Mark it Done or pause it to change it." The Strength and Pace segments never read the hint:

- "Selected, Gentle, button, 1 of 3", "Firm, dimmed, button, 2 of 3", "Relentless, dimmed, button, 3 of 3"
- "Escalating, dimmed, button, 1 of 2", "Selected, Consistent, button, 2 of 2"

So a VoiceOver user hears "dimmed" with no reason, and the selected segment doesn't say "dimmed" at all. `SegmentedChoiceSection` (`App/ReminderForm/ReminderFormSheet.swift`) puts `lockedWhileNudging`, and its hint, on the `Picker`, and VoiceOver reads the segments one by one, without the picker's hint. It's been there since first-version's ticket 13 for Strength; ticket 08 gave Pace the same section.

## What it should do

- [x] VoiceOver on each locked Strength and Pace segment, the selected one too, reads the lock's reason (`LockNote.hint`), on an iPhone (phone and iOS version recorded).
- [x] At accessibility sizes, where the segments become a menu, the locked menu reads the reason too.
- [x] Unlocked, the segments read as they do now, with no hint.
- [x] Ticket 12's iPhone check, below, is done on the iPhone, with each step's result and the phone and iOS version recorded in Comments.

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

## Before you start

- Builds on: ticket 08: its Comments (2026-10-22, device checks passed) record the setup that showed the bug: a Gentle, Consistent · 30 min reminder Nudging, Break Through Focus off, on Brian's iPhone. They also give the hint's wording, now the short `LockNote.hint` ("Locked while it's nudging. Mark it Done or pause it to change it."). Ticket 12: the last criterion here, and the "Ticket 12's iPhone check" steps, carried over at Brian's request; run them in the same iPhone session as this ticket's VoiceOver check.
- Watch for: the iOS 26.5 simulator can stop turning to landscape, and its "landscape" screenshots are then portrait (ticket 12's Comments). Look at one before trusting a run, and restart it with `xcrun simctl shutdown` then `boot` if needed. On `iPhone 15 - iOS 27.0` in `largest-text-landscape`, `testMyDay` still can't find the Filter button (ticket 11). The status is `needs-triage`; Brian decides whether it's ready.
- Developer stops: agree the `tdd` seams (VoiceOver reading can't be unit-tested, so likely none: say so); the simulator pass if anything changes on screen; the device checks on the iPhone, one at a time: criteria 1-3 with VoiceOver, then ticket 12's iPhone check.

## Comments

### 2026-10-23: built, device checks to come

- Brian marked it `ready-for-agent` and agreed the approach and no `tdd` seams (VoiceOver reading can't be unit-tested).
- The fix: while locked, `SegmentedChoiceSection` makes the picker one VoiceOver element (`accessibilityElement(children: .ignore)`) with the section's label and the selected option's name (`selectedTitle`), so `lockedWhileNudging`'s hint lands on it. It's the same at accessibility sizes, where the picker is a menu. Unlocked, nothing changes. Nothing changes on screen, so there was no screenshot pass; `scripts/test.sh` passed on both simulators.
- Apple's docs confirm `.ignore` makes one new element whose label and value we set. They don't say whether the hint added after it lands on that element, whether VoiceOver still says "dimmed", or what happens to the menu's pop-up trait. All three are for the device check. Listen too for "Strength" read twice (heading, then element) at the default size. That's redundant, not wrong.
- Review: no hard violations and no spec gaps. Fixed: `value` renamed `selectedTitle`, and comments clarified. Left alone: the locked/unlocked `if` gives the picker a new identity when the lock flips mid-edit. Its state is the binding, so nothing is lost. Also left: callers pass the selection's title alongside it (only two callers).
- Out of scope, for Brian: the Custom page's Frequency and Ends pickers (`CustomRepeatPage.swift`) take `lockedWhileNudging` on a wrapping `Group`, so they probably have the same missing hint when a reminder starts nudging while that page is open. A follow-up ticket if wanted.

### 2026-10-23: VoiceOver checks passed on the iPhone

On Brian's iPhone (iPhone 15, iOS 27.0.1), fresh install (the app wasn't on the phone, so it's uninstalled after). Test reminder: Gentle, Consistent · 30 min, Break Through Focus off, Nudging.

- Criterion 1, segments (Larger Accessibility Sizes on, slider at +4; screenshot confirmed segments): "Strength, heading", then "Strength, Gentle, dimmed", then the hint "Locked while it's nudging. Mark it Done or pause it to change it." Pace the same: "Pace, Consistent, dimmed", then the hint. Strength and Pace are each read twice (heading, then element), as expected.
- Criterion 2, menu (largest size; screenshots confirmed menus with the up-down chevrons): "Strength, Gentle, dimmed" and "Pace, Consistent, dimmed", each with the hint. No separate heading, and no "button" or "pop-up button": the `.ignore` element doesn't carry the menu's traits, which fits a control that can't be used while locked.
- Criterion 3, unlocked (new reminder): the menus read "Strength, Firm, button, pop-up button", then "double-tap to activate the picker", with no lock hint. At +4 the segments read as before: "Gentle, button, 1 of 3", "Selected, Firm, button, 2 of 3", "Relentless, button, 3 of 3", "Escalating, button, 1 of 2", "Selected, Consistent, button, 2 of 2", with no "dimmed" and no hint.
- "button, pop-up button" on an unlocked menu is iOS's own reading. The Every picker, which this ticket doesn't touch, reads the same way, and so do Calendar's menus (Brian checked).

### 2026-10-23: ticket 12's iPhone check, steps 2 and 4 revised

With notifications and alarms both off, Now showed one banner, "Notifications are off. Nudges can't reach you.", in portrait and landscape. That's by design: the notifications-off banner replaces the others (`PermissionBanner.banners(for:)`), so step 2 as written can't produce two banners. Brian agreed this change to the check: step 2 is notifications on, alarms off and Time Sensitive off, which shows the alarms-off and Time Sensitive-off banners. Step 4's labels are then "Open Settings for alarms, button" and "Open Settings for Time Sensitive notifications, button". Step 5 also turns Time Sensitive back on.

- Step 1 passed: one banner at the largest size, portrait and landscape, laid out as described. With alarms off too, the single notifications-off banner (both-off wording) also looked right in both orientations.
- Step 2 (revised) passed: the alarms-off and Time Sensitive-off banners, one under the other, each with its own full-width Open Settings at accessibility sizes, neither cut.
- Step 3 passed: stepping the text size from Control Center, the banners are stacked with full-width buttons at accessibility sizes, and below them the icon sits beside the text with the small pill under it. Nothing clipped or overlapped at any step. (Brian first read the icon's narrow left column as "its own line"; the normal-size screenshot showed it beside the text.)
- Step 4 passed: "Open Settings for alarms, button" and "Open Settings for Time Sensitive notifications, button". Alarms' opens the app's Settings page; Time Sensitive's opens its notification settings.
- Step 5: Brian put back VoiceOver (off), text size (Larger Accessibility Sizes on, +4), alarms and Time Sensitive (on), and deleted his test reminders (Break Through Focus off, so no AlarmKit alarms). The app was then uninstalled, as it wasn't on the phone at the start, and `devicectl` confirmed it's gone.
- Every criterion is ticked, so the ticket is resolved.

### 2026-10-23: the Custom page, checked on the iPhone

Brian had the out-of-scope Custom page checked on the same phone. The Frequency and Ends segments and the Every stepper miss the lock's reason, and some locked controls don't look dimmed. That's ticket 16. While setting it up, Brian found that a Never reminder can't choose the Custom page's default weekly repeat. That's ticket 17. The app was uninstalled again afterwards (`devicectl` confirmed).
