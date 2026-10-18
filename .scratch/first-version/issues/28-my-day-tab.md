Status: resolved

# My Day tab

Design spec: `docs/design/DESIGN.md` (Components: Counts, Reminder row, Swipe actions, Tags). Where it and the mockup disagree, see its Precedence note.

## What to build

Today's occurrences in time order with Done, Nudging, Missed and Left counts. Tapping a count filters the list to it (tap again clears). Tag filter with Match All / Match Any and No Tags. Swipe on a Nudging row for **Done**. Permission banners per the mockup (the banner view comes from ticket 31; leave a placeholder slot here).

## Acceptance criteria

- [x] Counts and list match the fixtures from ticket 16.
- [x] Tapping Missed filters to Missed rows; tapping it again shows all.
- [x] Tag filter: Match All and Match Any give different results on a fixture where they differ; No Tags shows untagged ones.
- [x] Swipe Done on a Nudging row closes it as Done; rows that are not Nudging have no Done swipe.
- [x] Matches the mockup's My Day screen at default and largest text size.

Blocked by: 16, 26

## Comments

**Resolved 2026-10-18.** Every criterion is ticked. One rough edge found with VoiceOver is ticket 33 (a bug, not blocking). Criterion 5 is met by simulator screenshots against the mockup at default and largest text, portrait and landscape, and by device check 6 below.

**What Apple's docs confirm** (apple-rag): `swipeActions(edge:allowsFullSwipe:)` with `.tint`; `accessibilityAction(named:)`; `NavigationLink(value:)` through a `navigationDestination(for:)`; a sheet becomes full screen in compact height by default; `accessibilityVoiceOverEnabled` (iOS 15+, changes as VoiceOver is turned on or off); `AccessibilityFocusState` (setting the bound value moves VoiceOver's focus); the `listRowSeparatorLeading` guide. **Docs silent, so device checks:** how VoiceOver treats a button inside a link row, and whether it lists a row's swipe actions (it does; see decision 3).

**Decisions** (the first five agreed with the user before coding; the rest as found):
1. **Own stack.** `ShellNavigation.dayPath`, with `reminderDetailsDestination()` reused. The alarm's Open still goes to Now and leaves My Day's stack alone (`routesLeaveMyDaysStackAlone`).
2. **The Done button is in the row**, as DESIGN.md (Reminder row) and the mockup's `dayTrail` have it, so the swipe is a shortcut, not the only way. The setup note said My Day had no Done button; the design docs say it does.
3. **The row is a plain button that opens the details, with Done as a sibling button**, and its own chevron, like Now's rows. The first build was a `NavigationLink` with a borderless Done inside, as agreed. On the phone VoiceOver merged the button into the row and listed Done twice, and `accessibilityHidden` did not hide the swipe's Done on a link row (it does on Now's cards). The restructure gave VoiceOver Done as its own button. A swipe action is still listed among a row's actions, so **the swipe is not added while VoiceOver runs** (user's choice): VoiceOver offers Done once. The swipe is the green tile with no full swipe, as on Now.
4. **Own row, not `NowRowLayout`.** It is private, and a My Day row needs a second button beside its own.
5. **The tag filter** is a sheet (Match All / Any Tag, tags, No Tags, applied as you change it, tokens on My Day). `MyDayFilter` is a value type holding the checked tags in order, Match, No Tags and the chosen count. State is `@State` in `MyDayTab`: it survives switching tabs (a TabView keeps its tabs), not a relaunch. **Not checked on the phone:** that it survives a tab switch.
6. **`MyDayScreen(engine:filter:now:)`** is the plain value the tab draws, like `NowScreen`. `MyDayFilterSheet` is the sheet's. Previews build them from an engine with no model. A tag deleted while checked is dropped from the filter (`MyDayFilter.keeping(tagsIn:)`), or Match All would show nothing.
7. **Copy and mockup differences.**
   - **Whole sentences only** (AGENTS.md): the empty list does not carry the filter's phrase ("Nothing is due today with #home"), since the tokens and summary line are on screen; "Showing only Missed" is a sentence per count; plural variants on every count.
   - **"Done at 7:04 AM after 1 nudge"** follows ticket 16; the mockup's `attempts > 1` omits it for one nudge.
   - **"in 3 hr."** is Foundation's short relative time (it drops the half hour the mockup's `rel` rounds); the nudge card shares the helper (`Date.shortRelative(to:)`).
   - **A "Now, 1:00 PM" marker** among the rows and a "Showing only X / Show All" bar, from the mockup.
   - **The permission banner** is a `PermissionBannerSlot` that draws nothing, for ticket 31.
8. **Layout.** The counts are a `Grid`, not a `LazyVGrid` (in a list row it reported too little height and cut off the bottom corners), two columns at accessibility sizes, capsules that wrap (`FlowLayout`) in landscape. The Done button is `SmallBorderedButtonStyle`, DESIGN.md's `button-bordered` (tertiary fill, accent text, at least 44 pt), not the system `.bordered`. The row's separator is pinned with `listRowSeparatorLeading`, or under a Done row it started at the status label.

**Tests.** `scripts/test.sh` passes: 231 engine tests, and 224 app tests on iOS 26.1 and 26.5 (up from 200). Seams: `MyDayFilterTests` (7), `MyDayScreenTests` (16, on ticket 16's fixture through the real `AppModel`), `ShellNavigationTests` (+1). Layout, the swipe, VoiceOver and the sheet are screenshot and device checks.
- **Red first:** the filter's toggling, No Tags, Match, count taps and Clear; the counts; the rows' order and times; the notes (Done, Missed, Skipped, Nudging, Paused, Left); the marker; the empty messages; the tokens and summary; the deleted tag; the sheet; each review fix.
- **Passed on their first run, kept as acceptance coverage:** Match All/Any/No Tags through the screen (the engine does the work), the screen's rows and time order, and the test-host empty screen.
- **Mutation-checked:** Match Any treated as Match All, Done offered on every row, deleted tags not pruned, and counts that ignore the tag filter each fail a test.
- **Seeding note:** a reminder whose first due time has a fractional second never matches the second-aligned due times a repeat computes, so it drops off My Day. The form only makes whole minutes, so this is not a product bug; fixtures and any seeding use whole minutes.

**Screenshots** (iPhone 17 simulator, iOS 26.5; a throwaway XCUITest project in the scratchpad ran the real shell and model over fakes; nothing committed). Compared with the mockup's `viewDay`, default and largest text, portrait and landscape, light and dark, with the sheet, tokens, a chosen count and the swipe. They found three bugs, all fixed: the "Filter by Tags" button cut off at the largest size, count tiles with square bottom corners (the `LazyVGrid`), and separators drawn only from the right under Done rows. The 26.5 simulator had been left at `accessibility-medium` by an earlier session; it is back at `large` and light.

**Code review** (two axes, against main). Fixed: a 44 pt filter button; semibold count captions; "No Tags" held in a `String` (the token's words are now the view's); "Showing only \(word)" built from a translated word; plural variants; literal sizes (`Design.Size.nowMarkerLine`, `Radius.countCell`); a toolbar that built a whole screen for a count (`MyDayFilter.checkedCount`); previews for each non-trivial view; the Paused label shared as `PausedLabel`; the "Done, stop nudging" catalog comment; duplicated tag labels and list formatting (`Tag.label`, `Engine.tag(withID:)`, `Match.list(of:)`). **Kept, as judgement calls:** the `" · "` joiner of the tags and note (a whole template, like Now's "%@ · due %@"); screens built from the engine in `body` (Now does the same); the empty banner slot; `MyDayScreen.Item.init` reading several engine queries; times held as formatted strings, as Now does.

**Device run (2026-10-18), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.** **Before:** Nudge-inator was not installed. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator. Every reminder made by hand was Gentle, so no alarm was scheduled.
1. **App tests: pass.** All 224 passed from a fresh install (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`, two prompts, 15 s). They passed again after each of the six later reinstalls (about 4 s each).
2. **Swipe Done: pass.** A Nudging row shows the green Done tile, a full swipe only reveals it, tapping it closes the row as Done and moves the counts, and a Left row and a Done row have no swipe.
3. **Tap targets: pass, twice.** The first build (nested button) passed; after the restructure again: the row's title, empty space and chevron open the details, Back returns to My Day, and the Done button closes the row without opening them.
4. **VoiceOver: pass, with ticket 33.**
   - **Reads:** Filter by Tags as a button; counts as "2 done, button", "0 missed, dimmed, button", a chosen count as "selected, 2, done"; a row as "2:51 PM, Voice Over test 3, nudging, 1 nudge, next 3:51pm, button, opens the reminder details"; Done as its own "Done, stop nudging, …, button", which marks the reminder Done.
   - **Actions:** with the swipe off while VoiceOver runs, the row lists none (a swipe up beeps), so Done is offered once. With VoiceOver off, the swipe works again.
   - **Open (ticket 33):** after Done, VoiceOver's cursor outline stays where the button was for about a second, and the announcement is cut off by the row being read.
5. **Tag filter: pass.** The Match control appears from two tags; All Tags shows only T2, Any Tag shows T1, T2 and T3; No Tags unchecks the tags and shows untagged rows; Clear and Done behave; tokens, the "Due today with…" line, token removal and Clear work.
6. **Largest text size, portrait and landscape: pass.** Nothing was cut off; rows stack and wrap; Match is a menu; in landscape the date is under the title and Filter is in the bar.

**Left alone:** Tag lists and the Tags tab (29), Settings (30), onboarding, permission prompts and the banner's content (31), a Done before first unlock (32), iPad; the Now tab, the details screen and the Edit form (Now's card only shares `shortRelative(to:)` and one catalog comment).
