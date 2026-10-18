Status: resolved

# Now tab

Design spec: `docs/design/DESIGN.md` (Components: Nudge card, Nudge meter, Status label). Where it and the mockup disagree, see its Precedence note.

## What to build

Nudging cards each with the title, nudge count and urgency, and a **Done** button; Coming Up (next 7 days); Last 24 Hours. Data comes from the app model (queries from ticket 16). Tapping a card opens the reminder details (ticket 27). Done ends the occurrence and removes the card.

## Acceptance criteria

- [x] With fixtures, the three sections show the right items, in the mockup's order.
- [x] Tapping Done on a card closes the occurrence as Done and cancels its pending items (assert via fake adapters).
- [x] A Missed occurrence appears under Last 24 Hours with its reason ("the next one took over" distinct).
- [x] Empty state when nothing is nudging.
- [x] Matches the mockup's Now screen (screenshot comparison noted in Comments).
- [x] Device (human): on a cold launch, the first `.active` refills the plan (`initial: true`), and Now shows it. *(Moved here from ticket 21, whose empty screens couldn't show a plan.)*

Blocked by: 21, 24

## Comments

**Decisions settled with the user before coding (2026-10-17).** Apple's docs, read through apple-rag, confirm:
- `swipeActions(edge:allowsFullSwipe:content:)` takes `allowsFullSwipe: false`, and `.tint` colors the button.
- `TimelineView` has `.everyMinute` (at the start of each minute), `.periodic`, `.explicit` and custom schedules.
- `.onChange(of:initial:)` on `scenePhase` (already ticket 21's).
- `borderedProminent`.
- `accessibilityValue` is for a value that differs from the label.
- `ViewThatFits` picks a child by its ideal size, not by a width threshold.
- `.combine` merges children, and a button inside "may become a named action".
- `Tab.badge(_:)` takes a count, and 0 hides it.

The docs don't say how VoiceOver presents a List swipe action, whether `.accessibilityHidden` hides it, or whether a TimelineView takes a new schedule value. The first two became device checks.

The decisions:
1. **The card reads an engine read-out.** `Engine.nudgingStatus(of:) -> NudgingStatus?` (`NudgingStatus.swift`) gives:
   - `dueTime`, `nudgesSent`, `nudgesInAll` and `urgency` (of the latest nudge sent);
   - `nextNudge` (`NextNudge`: `nudgeNumber`, `fireTime`, `urgency`, `delivery`);
   - `missedAt`, when it gives up or the next occurrence takes over.

   `NudgeDelivery` is `.alarm`, `.notification(weakerBecause: Reason?)` or `.cannotArrive`. `Reason` is `.alarmsOff`, `.alarmsAndTimeSensitiveOff`, `.timeSensitiveOff`, `.breakThroughFocusOff` or `.pastAlarmLimit`.
   - It works from the ladder, not the plan, since the plan drops a nudge that can't arrive and the card still says "Notifications off".
   - The plan and the card share one internal `delivery(of:firingAt:urgency:)`, so they can't disagree.
   - A nudge at or after the take-over isn't "next".
   - After the last nudge the card reads "That was the last nudge. It closes as Missed at 11:17 AM."

   The engine also exposes the repeat summary's own `dayLabel(of:)`, `timeOfDay(of:)` and `shortDate(of:)`, so Now's times and dates are in the engine's locale and time zone.
2. **Test seams:**
   - `NudgingStatusTests` (engine, macOS): 7 tests, 14 delivery cases.
   - `NowScreenTests` (app, through the real `AppModel`, in-memory store, real adapters over the fakes): 11 tests on `NowScreen(engine:)`, the plain value `NowTab` draws. Previews build it from an engine with no model.
   - Layout, the wide card, AX5, the swipe, VoiceOver and the cold launch are screenshot and device checks.
3. **Refresh:**
   - Now's list sits in a `TimelineView(.everyMinute)`, and the read-outs use the engine's clock, so a nudge, a due time or a give-up shows within a minute.
   - The tab's badge (deferred from ticket 22) is redrawn by a `@State` minute that a `.task` in `RootView` ticks. A `TimelineView` wrapping the `TabView` held up main-actor work in the test host until each minute's start: `NowScreenTests` went from 2 s to 300 s. So the shell doesn't use one.
4. **Taps:** nothing on Now opens a reminder until ticket 27. Cards and rows aren't buttons and have no chevron; ticket 27 has the note.
5. **Last 24 Hours wording** (the mockup's `closedLabel` and `closedWhy`):
   - "Done after %lld nudges", with a plural;
   - "Missed: gave up after the limit";
   - "Missed: the next one took over";
   - "Skipped: the reminder was paused";
   - status labels Done (green, `checkmark.circle.fill`), Missed (red) and Skipped (secondary).
6. **Swipe and wide card:**
   - The swipe is trailing Done on cards only, with no full swipe, `tileGreen`, and hidden from VoiceOver.
   - A card at least `wideCard` (540 pt) wide, and not at accessibility sizes, puts Done and its footer in a side column. At accessibility sizes Done sits directly under the title.
7. **DESIGN.md over the mockup for the card's top row:** the strength badge, then the urgency word with its glyph (none for Normal), then "Nudge 3 of 20". The details line keeps the tags and due time and drops the mockup's "Urgency High".
8. **VoiceOver:** the top row and title are one element. Its label is the title, and its value is the strength, count, urgency, details and next nudge. Done is a separate button, "Done, stop nudging: ‹title›".

**How criterion 3 is met.** With the shipped give-up limit (20 nudges, Gentle's ending at +8 h) and daily as the fastest repeat, every occurrence gives up before the next falls due. So no fixture can reach a take-over through the model. "Missed: the next one took over" is tested on the row's text for each closing state (`aClosedRowSaysHowItClosed`). The give-up and Skipped wording are also tested through the model, and the engine's take-over closing is ticket 16's.

**Tests.** `scripts/test.sh` passes: 230 engine tests, and 160 app tests on each of the iOS 26.1 and 26.5 simulators.
- **Red first:**
  - the card's status, each delivery, the last nudge and the take-over cut-off;
  - the day and time labels;
  - the sections and their order;
  - "Done after N nudges" and its plural;
  - the closing wording;
  - the via label;
  - the subhead and its plural;
  - the times read through the engine;
  - each review fix: the badge count, the status words, the subhead's day, the last-nudge line, and the VoiceOver value with the strength.
- **Passed on their first run, kept as acceptance coverage:**
  - the past-alarm-limit case;
  - Done cancelling only that reminder's items (it passed once `detail` compiled);
  - the empty state.
- **Mutation-checked:**
  - dropping the take-over cut-off fails `aNudgeTheNextOccurrenceWouldTakeOverIsntComing`;
  - dating the subhead from the device fails `theSubheadDateIsTheEnginesDay` (the simulator runs on the Mac's Central time).

**Screenshots** (iPhone 17 simulator, iOS 26.5). They came from a throwaway XCUITest project in the scratchpad, whose app ran the real shell and model over the test fakes, seeded with reminders due in the past. Nothing was committed. The simulator was put back to `large` text and light appearance. Compared with the mockup's Now screen:
- the subhead with the count in red, then the Nudging heading;
- cards with the urgency stripe, the strength badge with its bars, the urgency word and glyph (High, Urgent), "Nudge N of 20", the title, the tags and due time, "Next nudge 7:06 PM (in 5 min.): 🔔 Notification · High", the meter, Done and its footer;
- Coming Up with the time and day column, the repeat summary and the strength badge, and Last 24 Hours with the status labels;
- the tab's badge.

All match the mockup's layout. Differences:
- The urgency is in the top row, as DESIGN.md has it (decision 7).
- iOS 26 draws the swipe action as a green circle with "Done" under it, not the mockup's full-height tile. That's the system's `swipeActions`.
- Foundation's short relative time reads "in 5 min." with a period.

Also checked in the screenshots:
- Dark mode: black on cyan Done.
- AX5: cards stack with Done under the title, and rows stack.
- Landscape left and right: the wide card's side column, centered at the readable width.
- After the screenshots, the Done button became the system's large size (it was 58 pt) and the relative time stopped reading "in 18m".

**Code review** (two axes, against main). Fixed:
- **Standards:**
  - literal sizes in views, now `Design` constants: `line`, `cardVertical`, `sideColumnGap`, `sideColumn`, `timeColumn` and the badge's padding;
  - the badge built a whole `NowScreen` in `body`, and now counts `nudgingOccurrences()` (`NowScreen.badgeCount(of:)`);
  - `Fallback` named Break through Focus off a fallback, which GLOSSARY.md doesn't. It is now `NudgeDelivery.Reason`;
  - the via label's repeated switch is now one template plus a glyph;
  - the last-nudge line was held twice;
  - the summary writer was built three times;
  - `StatusLabel` reached into `ClosedRow`, and now uses `OccurrenceState.statusName`;
  - `PreviewScheduler` is now in `App/Design/PreviewSupport.swift`;
  - Time Sensitive was read as of now, not as of the nudge's fire time.
- **Spec:** the subhead's date used the device's time zone, not the engine's.
- **Kept, as judgement calls:**
  - the items carry strings the engine formatted, so every time is in its zone and testable;
  - `nowBadge(in:at:)` takes the minute it's redrawn by.
- **Changed after the review, at the user's direction (2026-10-17):** the review noted that the card counted out of 20 even when the 24-hour span or a take-over would close the occurrence sooner. I had kept that because the mockup's `cap.maxAttempts` does it. The user's ruling: the mockup shows how the app looks, and its data isn't fact; the real app shows the actual data. `nudgeLimit` is now `nudgesInAll`, the nudges this occurrence really sends before it closes as Missed. "Nudge 3 of N" and the meter count out of it. With today's ladders every strength reaches 20 well inside 24 hours, so cards still read "of 20". Tested by `aSpanThatEndsFirstCutsTheNudgesInAll` (a 1-hour span: "2 of 5") and the take-over test (281 of 281), both red first.

**Device run (2026-10-17), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Before:** Nudge-inator was not installed. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator. Every reminder made by hand was Gentle, so no alarm was scheduled.
- **All 159 app tests passed on the phone** from a fresh install (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`, two prompts, 58 s). The checks that need a person were skipped, as they are by default. The VoiceOver fix that followed added one simulator test (160).
- **Manual checks Brian ran:**
  1. **The cold launch: pass.** Cold launch check (Gentle, due 7:33 PM) was saved, and the app was force-quit. Nudge 1 arrived, and the app was opened from its icon. The first `.active` ran App opened, and Now showed the card at "Nudge 1 of 20" with "Next nudge 8:33 PM (in 1 hr.)", a badge of 1 and "1 reminder nudging you".
  2. **Done on a card: pass.** The card went at once, not at the minute's refresh. The badge went, the subhead read "Nothing is nudging you", and Last 24 Hours showed "Cold launch check, Done after 1 nudge, ✓ Done".
  3. **Done from the swipe: pass.** The swipe showed Done, and a long full swipe only revealed it. Tapping it closed Swipe check, the badge went to 1, and Last 24 Hours listed it.
  4. **The wide card in landscape: pass.** Done and its footer were in a side column.
  5. **The largest text size, portrait and landscape: pass.** The subhead wrapped, the card stacked with Done under the title, the next-nudge line and the rows wrapped, and nothing was cut off.
  6. **VoiceOver on a card: pass after a fix.** The first run read the card as one element but left out the strength, because the badge sits inside an element whose value is written by hand. The value now starts with it (`aCardsVoiceOverValueSaysItsStrengthCountUrgencyAndNextNudge`). Rechecked on the phone:
     - the card reads its title, strength, count, urgency, details and next nudge;
     - Done is a separate button, "Done, stop nudging: Card check";
     - VoiceOver offers no swipe action.

**Left alone:**
- reminder details and opening them from Now (27);
- My Day (28), Tags (29), Settings (30);
- onboarding and the permission banners, including the mockup's `permBanner` on Now (31);
- the Open intent (20);
- keeping a Done before the first unlock (32);
- iPad.
