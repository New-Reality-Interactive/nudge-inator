Status: resolved

# Tags tab

Design spec: `docs/design/DESIGN.md` (Components: Tags, Settings row). Where it and the mockup disagree, see its Precedence note.

## What to build

Tags only. A list of tags, each with counts of reminders, due today and nudging. **+** adds a tag. Edit mode renames or deletes a tag; deleting warns how many reminders use it and never deletes those reminders. Tapping a tag pushes a screen of that tag's reminders; its **+** opens the New Reminder form (ticket 24) with that tag already chosen. No multi-tag filtering here.

## Acceptance criteria

- [x] Counts match ticket 16's fixtures.
- [x] Adding `Home` when `#home` exists is rejected with a message.
- [x] Delete of a tag used by 3 reminders shows "3 reminders use this tag" and, after confirming, the reminders still exist without the tag.
- [x] Rename to an existing tag (ignoring case) is rejected.
- [x] + on a tag's screen opens the form with that tag preselected.
- [x] Empty state when there are no tags.

Blocked by: 16, 24

## Comments

**Decisions (agreed with Brian)**
- New tag and rename use a sheet. Delete is an alert with a visible Cancel and Delete. A `confirmationDialog` replaced after feedback: Apple's docs confirm it is a popover in regular size classes; they don't say how it renders from a button on iOS 26. On the simulator it showed as a popover with no Cancel.
- One error for a taken name: "You already have the tag #work." (add and rename, ignoring case).
- A tag's screen has Today / Later / Paused / Completed sections, reached by a new `tagPath` in `ShellNavigation`. A deleted tag's screen says "This tag was deleted."
- The tag sheet shows its error as the section header in compact height (landscape) and as the footer otherwise, because the keyboard covered the footer in landscape at the largest text size (found on the device, below).

**Tests**: `scripts/test.sh` passes (231 package tests; 240 each on the iOS 26.1 and 26.5 simulators; catalog check passes). Criteria by test: counts (`TagsScreenTests`), Home vs `#home` and rename to an existing name (`TagActionsTests`, `TagNameDraftTests`), delete of a 3-reminder tag keeps them (`TagActionsTests`, `TagsScreenTests` for the question), empty state (`TagsScreenTests`), preselect and no changes (`ReminderFormTests`).

**Screenshots** against the mockup on both simulators: portrait and landscape, default and largest text, light and dark.

**Device checks** (iPhone 15, iOS 27.0.1; app was not installed beforehand, uninstalled afterwards; the person deleted their test reminders so no alarms were left):
1. Edit mode with VoiceOver: each row reads its summary, then "Rename #x" and "Delete #x" as separate buttons. Passed.
2. Delete alert with VoiceOver: announced, message "3 reminders use this tag. It's removed from them, and they aren't deleted." read, Cancel and Delete reachable, Cancel kept the tag, Delete removed it, reminders stayed without it. VoiceOver then read the list footer on its own. Passed.
3. Landscape: list, Edit mode and the rename sheet passed at default size. At the largest text the rename error was behind the keyboard (the simulator screenshots had not reached this). Fixed (error above the field in compact height), re-reviewed (only `TagSheet.swift`), re-checked on the device. Passed.
4. + on a tag's screen preselects that tag; cancelling untouched asks nothing. Passed.

**Review**: one full review (fixed point `main`) with fixes; later a re-review of `TagSheet.swift` only. The Form header may take space with no error showing; checked on the device, no blank gap.

**`scripts/test.sh`**: now switches off the simulator's `mediaanalysisd` (it ran at 700-870% CPU in the 26.5 simulator and forced a Mac restart). Own commit; note in `docs/agents/device-testing.md`. Not verified: why it began today; macOS's own `mediaanalysisd` still bursts while PNGs are written (hypothesis only).

**Follow-up (not this ticket)**: My Day, Now and Details have the same row/column layout switch; moving them to `SizeAdaptiveStack` is a possible ticket.
