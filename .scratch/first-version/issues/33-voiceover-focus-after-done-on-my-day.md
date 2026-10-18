Status: ready-for-agent
Type: bug

# VoiceOver's cursor lingers and cuts off the announcement after Done on a My Day row

Found while closing ticket 28 (My Day tab), device check 4, on Brian's iPhone 15, iOS 27.0.1, 2026-10-18. It doesn't block ticket 28: Done works with VoiceOver, and the behavior is a rough edge. Brian asked for it to be tracked as a bug and worked on in a fresh context.

## The bug

A Nudging row on My Day has a **Done** button beside the row's own button (`MyDayRowView` in `App/MyDay/MyDayRows.swift`). With VoiceOver on, focus the Done button and double-tap it. The reminder is marked Done correctly, and the button goes away. Then:

1. **The cursor stays where the button was.** VoiceOver's black rounded outline stays drawn over the spot where the Done button was, on top of the new "✓ Done" status. In the first builds it stayed until VoiceOver was turned off or something else was focused, and it washed out the green ✓.
2. **The announcement is cut off.** With the fix in place (below), the cursor moves to the row after about a second, and VoiceOver says: "Done, stop nudging. 3:56PM Z Done at 3:56 PM after 1 nudge. Done, button. Opens the reminder's details." Brian's words: it is like VoiceOver doesn't finish saying the action of double-tapping Done before it jumps to the row and reads its contents. So the activation feedback is truncated, and the row's text follows at once.

Neither shows without VoiceOver. Tapping Done with VoiceOver off is clean (checked on the phone and in the simulator).

## What is already in place (commit `6ad0d73`)

- `MyDayRowView` sets `@AccessibilityFocusState private var isOpenerFocused` and, in the Done button's action, sets `isOpenerFocused = true` before `markDone()`. Apple's docs (apple-rag, "AccessibilityFocusState") say that setting the bound value to `true` moves VoiceOver's focus to that element. The outline still shows for about a second first, and the announcement is cut off.
- The Done button is its own VoiceOver element, a sibling of the row's button (not nested in a `NavigationLink`: nested, VoiceOver merged it into the row and listed Done twice).
- While VoiceOver is running, the row's swipe-Done action is not added (`@Environment(\.accessibilityVoiceOverEnabled)`), because VoiceOver lists a row's swipe actions among its actions whatever `accessibilityHidden` says (seen on the phone). Brian chose this so VoiceOver offers Done once.

## What was tried and did not fix it

All of these were wrong about the cause. The outline is VoiceOver's own cursor, not a leftover layer.

- Drawing the Done button with DESIGN.md's `button-bordered` look (`SmallBorderedButtonStyle`) instead of `.bordered`. This stays: it matches the design token.
- Not animating the swap from button to status (`.animation(nil, value:)`). Removed.
- Giving the row's content a new identity when it stops nudging (`.id(item.offersDone)`). Removed.

## Ideas not yet tried

Check each against Apple's docs through apple-rag before building it (AGENTS.md). None is confirmed.

- Move the focus after a short delay, so VoiceOver finishes announcing the activation, instead of at once.
- Post an accessibility announcement of the outcome (`AccessibilityNotification.Announcement`, or `UIAccessibility.post(notification: .announcement, …)`), and leave focus where it is or move it later.
- Post `.layoutChanged` with the row as the argument, instead of using the focus state.
- Keep the Done button in the accessibility tree after it is done (for example replaced in place by a non-interactive status element) so VoiceOver has nothing to lose.
- Whether the same happens on **Now's nudge cards** (Done button removed when the occurrence closes) and on the **reminder details** Done. Ticket 26's and 27's device checks passed their Done checks, but not necessarily with VoiceOver, so check there first; a shared helper may be the right fix.

## Acceptance criteria

- [ ] With VoiceOver on, activating Done on a My Day row leaves no outline over the old button's place, even briefly, or the ticket records why a brief one can't be avoided (Brian to agree).
- [ ] VoiceOver finishes announcing the Done action, and the row's new state is read once afterwards, not on top of it. Record what VoiceOver says, word for word, and the iOS version.
- [ ] VoiceOver's focus ends on the Done row, so a person can carry on from there.
- [ ] Without VoiceOver, Done on a row is as clean as before, with no animation or layout change.
- [ ] The same check was made on Now's nudge card and the reminder details Done with VoiceOver on, and either they are fine or they get the same fix.
- [ ] Device (human): iPhone 15, iOS 27.0.1 or newer. Check one Done at a time, per AGENTS.md › Testing, and record whether the app was installed before the run.

## Out of scope

The swipe action, the tag filter and the counts (ticket 28, all checked). The permission banner (31).

## How to reproduce

1. Make a Gentle reminder that starts about 2 minutes from now, and wait until it is due.
2. Open **My Day**, turn VoiceOver on, focus the row's **Done** button (swipe right from the row), and double-tap.
3. Watch the cursor and listen. Turn VoiceOver off afterwards.
