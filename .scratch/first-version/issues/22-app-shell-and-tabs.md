Status: resolved

# App shell: tab bar, theme, empty states

Visual spec: `docs/mockups/2026-10-04-first-version/` (open `index.html`; the README describes the screens).

Design spec: `docs/design/DESIGN.md` (Colors, Typography, Layout & Spacing, Mapping to code). Where it and the mockup disagree, see its Precedence note.

## What to build

Tab bar (SwiftUI `TabView` with `Tab(_:systemImage:)`, as in Apple's `tabBarMinimizeBehavior` example) with Now, My Day, Tags and Settings in the mockup's order, placeholder content with empty states, the app tint, and the shared styles (Light, Dark, Dynamic Type, Bold Text). The + button entry point on Now and My Day is present but may be disabled until ticket 24.

Also create the shared design constants once (asset-catalog color sets with Increased Contrast variants, `Color` statics, the radii and spacing `enum`), as described in DESIGN.md › Mapping to code.

## Acceptance criteria

- [x] Every custom color in DESIGN.md's frontmatter exists as a color set with light, dark and Increased Contrast values.
- [x] Four tabs with the mockup's titles and SF Symbols (verify symbol names against the mockup `index.html`).
- [x] Each empty tab shows a sensible empty state.
- [x] Previews exist for Light and Dark and the largest Dynamic Type size; no truncated tab titles.
- [x] A screenshot (simulator) of each tab is attached or described in the ticket's Comments, compared with the mockup.

Blocked by: 01

## Comments

**Decisions settled with the user before coding (2026-10-17).** Apple's docs, read through apple-rag, confirm the following:
- `Tab(_:systemImage:value:content:)` selects by value. `tabBarMinimizeBehavior(.onScrollDown)` is iOS 26, and minimizing is supported "on only iPhone".
- Color sets take dark and High Contrast appearances. `NSAccentColorName` (the Global Accent Color Name setting) makes a set the app's tint.
- `UIColor(named:in:compatibleWith:)` and `Color(_:bundle:)` load named colors.
- `legibilityWeight` is the Bold Text setting. `ContentUnavailableView` is for "a list without items".
- String Catalogs: SwiftUI literals and `LocalizedStringResource` are extracted. `LocalizedStringResource` is "the recommended type for representing and passing around localizable strings". Export needs "Use Compiler to Extract Swift Strings".
- apple-rag has nothing on the color set `Contents.json` format or on preview traits for Dynamic Type. The tests prove the JSON, and the previews use `.environment(\.dynamicTypeSize, .accessibility5)`.

The decisions:
1. **The tab shell** (`App/Shell/`):
   - `AppTab` is an enum: now, myDay, tags and settings, with the mockup's titles (`ROOTS`) and symbols (`TABS`): `bell`, `calendar`, `tag`, `gearshape`.
   - `RootView` is a `TabView(selection:)` with `.tabBarMinimizeBehavior(.onScrollDown)`. Ticket 23 records what that does in portrait and landscape.
   - **Route:** `.onChange(of: model?.route, initial: true)` calls the new `AppModel.takeRoute()`, which returns the route and clears it. `AppTab(route:)` maps both `.now` and `.reminderDetails` to Now, because the mockup's Open goes to Now with the reminder pushed. Ticket 27 pushes the details.
   - **Launch state:** `ScreenState(model:)` gives each tab one of three states:
     - `.loading` while launching, a spinner, so "All clear" never shows before the store is read;
     - `.storeUnreadable`, the "Can't Open Your Reminders" message on Now, My Day and Tags, which says nothing is lost and to unlock and reopen;
     - `.ready`, also used with no model (the test host and previews).
   - Settings doesn't read the store, so it is the same in every state.
2. **Color sets** (`App/Resources/Assets.xcassets`):
   - `scripts/generate-color-sets.sh` generates them from DESIGN.md's frontmatter and is kept. There are 12 sets, one per custom key: `AccentColor`, `OnAccent`, `Negative`, `Warning`, `Positive`, `Neutral`, `Badge`, and `TileRed`, `TileOrange`, `TileGray`, `TileBlue`, `TileGreen`.
   - Each has Any, Dark, High Contrast and Dark High Contrast. A missing variant falls back (badge has no dark value; a tile has one value).
   - `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` is `AccentColor`. Generated asset symbols are off.
   - The `Color` statics are written by hand in `App/Design/DesignColors.swift` (`.onAccent`, `.negative`, …). Accent is `Color.accentColor`.
   - Nothing goes in NudgeShared yet, because the widget is empty.
   - `scripts/test.sh` fails if the sets no longer match DESIGN.md.
3. **Constants:** `enum Design` (`App/Design/Design.swift`) holds:
   - `Spacing`: s1–s5 (4/8/12/16/24), `margin`, `controlGap`, `rowMin`, `readableWidth`, `wideCard`;
   - `Radius`: `control`, `card`, `token`, `sheet`, `full`;
   - `Size`: `stripeWidth`, `meterHeight`, `ringWidth`, `bannerBorder`.
4. **Test seams:**
   - `ColorSetTests`: every set, resolved in the four appearances, against DESIGN.md's hex values (a literal table); each `Color` static against its set in light and dark; and `NSAccentColorName`.
   - `AppTabTests`: order, titles and symbols; both routes select Now.
   - `AppModelTests`: `takeRoute()` hands the route over once; `ScreenState` for launching, ready, unreadable and no model.
   - The `AlarmAdapterTests` tint test is unchanged.
   - A bare environment resolves `Color.accentColor` to system blue, because the accent reaches views as the tint, so the accent is covered by the `NSAccentColorName` test and the screenshots.
   - Layout, copy and truncation are preview and screenshot checks.
5. **Empty states** use the mockup's copy:
   - **Now:** "‹date› · Nothing is nudging you", then Nudging with "**All clear.** Nothing needs you right now.", Coming Up (Next 7 days) with "Nothing scheduled this week.", and Last 24 Hours with "Nothing closed yet today.".
   - **My Day:** the long date, then "Nothing is due today.".
   - **Tags:** `ContentUnavailableView` reading "No Tags. Tap + to add a tag, or add tags to a reminder when you create or edit it.".
   - **Settings:** only the mockup's privacy footer until ticket 30.
   - The + on Now and My Day (New Reminder) is disabled until ticket 24. The + on Tags (New Tag) is disabled until tag creation exists (the user's call).
   - The copy is static. Tickets 26–30 replace it with the engine's read-outs, which need a time-driven refresh.
6. **Previews:** Light, Dark and `.accessibility5` for `RootView` and each tab, plus unreadable and loading. They take a `ScreenState`, so they need no `AppModel` and no real adapters.
7. **The alarm tint:** `AlarmAdapter.alarmTint` resolves the `AccentColor` set's dark, standard-contrast value once and passes it as a plain color. The alert is drawn in the system's process, and the docs don't say a named color from the app's catalog resolves there. So the alert shows the same #07DDE6 as before.
8. **Text, so the app can take more languages later** (added by the user):
   - **Catalogs:** every string a person sees is in a String Catalog.
     - The app's `Localizable.xcstrings` holds the shell and ticket 18/19's notification "Done" and alarm "Open".
     - `InfoPlist.xcstrings` holds the display name, the alarm usage description, and `CFBundleName`, marked not to translate.
     - `Untranslated.xcstrings` holds the alarm title's `%@`: the reminder's own words, never translated.
     - NudgeEngine has its own catalog (`bundle: .module`) for the notification body ("Nudge %lld of %lld · %@"), the urgency words, and the whole repeat summary.
   - **Templates:**
     - Each string has a translator comment.
     - Words that agree are kept in one template: "the first %@", "%@ when it's a %@", "%@ of every month".
     - Counts use plural variants ("Every day" / "Every %lld days", "once" / "%lld times").
     - Names, lists, ordinal numbers, and day-and-month come from Foundation in the engine's locale. The serial comma in en_US was accepted ("Monday, Wednesday, and Sunday"), and so was "February 29" in en_US.
   - **The engine's English output is otherwise unchanged:** every existing summary test passes as written.
   - **Tooling:**
     - `swift test` copies a package's catalog without compiling it, so `scripts/test.sh` runs the engine tests with `xcodebuild` on macOS.
     - Command-line builds don't update catalogs, so `scripts/sync-strings.sh` syncs them from the build's `.stringsdata`. `scripts/test.sh` fails if one is out of date, or if a build added a key to `InfoPlist.xcstrings`.
     - `xcodebuild -exportLocalizations` produced 79 entries across the four catalogs, with plural forms and the alarm title as `translate="no"`.
   - AGENTS.md has a new Localization section.

**Screenshots (simulator, iPhone 17, iOS 26.5),** each tab in Light, Dark and AX5 (accessibility-extra-extra-extra-large), compared with the mockup emptied of its data in headless Chrome:
- **Now** matches: subhead, Nudging heading (label color), Coming Up with Next 7 days at the trailing edge, Last 24 Hours, and the same empty lines. At AX5, Coming Up and Next 7 days stack.
- **My Day:** the date and "Nothing is due today." The mockup also shows Filter by Tags and four 0 counts (ticket 28).
- **Tags** matches. The system centers `ContentUnavailableView`; the mockup puts it higher up.
- **Settings:** the privacy footer only (rows are ticket 30).
- **Tab bar:** the selected tab is teal in light and cyan in dark, and no tab title is truncated at any size.
- Dates follow the locale: "Sat, Oct 17" on the en_US simulator, "Mon 28 Sep" in the en_GB mockup.
- The first look had found "Nudging" and the subheads too light, because a list header's style overrides `.primary` and `.secondary`. They now use `label` and `secondaryLabel` by name.
- The screenshots came from a throwaway UI test outside the repo. The simulator's text size was put back to what it was.

**Code review** (standards and spec, against main). It found the following, all fixed:
- **Bugs:**
  - A yearly rule on 30 February read "1 March", because the calendar rolled the date over. It now reads "the 30th of February".
  - The note's "28 February" was hand-written. It now comes from Foundation, so en_US reads "February 28".
- **Templates and catalogs:**
  - Fragment templates were glued together ("the" + "first" + weekday, "a" + list, "of" + "every month"). They are now whole templates.
  - Names were in their format forms; they now use the standalone forms.
  - The alarm title's `%@` sat in the main table. It now has its own table.
  - The unreadable-store message hard-coded the app's name. It now takes the display name.
  - `CFBundleName` had the build's placeholder comment. It now has a real one.
- **Scripts:**
  - The color check failed on any other asset. It now compares only the color sets.
  - `sync-strings.sh` leaked a temp folder and counted `.stringsdata` from deleted sources.
  - A relative output path in the color script was taken from the repo root.
  - `InfoPlist.xcstrings` wasn't checked.
- **Smells:** repeated buttons and subhead styles, now `DisabledAddButton` and `subheadStyle()`; unlabeled helpers; a formatter built on every call.
- New engine tests cover 30 February, three month days, a 6th-to-last weekday, both kinds of day-plus-weekday condition, and the en_US day and month.

**Tests:** `scripts/test.sh` passes. The engine has 204 tests, and the app has 112 on each of the iOS 26.1 and 26.5 simulators.

**Device run (2026-10-17), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Before:** Nudge-inator was not installed. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator.
- **All 112 app tests pass on the phone.** The checks that need a person (ring, notification actions) were skipped, as they are by default.
  - **The first run** (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`) stalled in `AlarmDeviceCheck` for 12 minutes, inside AlarmKit's `requestAuthorization()`. Brian had tapped Allow on the prompt he was shown. Ticket 21's first run stalled the same way. The run was stopped.
  - **The second run** (permissions already granted) passed everything, `AlarmDeviceCheck` included.
  - Brian saw a different approval prompt in the first run than in the second, as he did on ticket 21. Unconfirmed reading: the prompt answered in the first run wasn't AlarmKit's, and AlarmKit's prompt showed only in the second run. Ticket 31 requests alarm authorization for real, so check there which prompt appears when, and whether `requestAuthorization()` returns once it's answered.
- **Manual checks Brian ran with the app installed: all passed.**
  1. **Launch:** it opens on Now, with four tabs and their titles and symbols, an empty state on each, and the + dimmed on Now, My Day and Tags.
  2. **The selected tab on the glass bar** is readable in light, dark, and both with Increase Contrast. This is DESIGN.md's device check for the tab bar.
  3. **Bold Text:** the text is bolder, and no tab title is truncated.
  4. **The largest accessibility text size:** tab titles stay whole, text wraps, and Coming Up and Next 7 days stack.
  5. **VoiceOver:** each tab reads its name. The + reads "New Reminder, dimmed" on Now and My Day, and "New Tag, dimmed" on Tags.

**Device checks still pending:**
- Ticket 21's pending checks (App opened on a cold launch, a Done before the first unlock, interval triggers across a reboot) are unchanged. The empty shell doesn't show a plan yet, so check 1 waits for ticket 26's screens.
- The alarm's tint now comes from the color set. The value is the same, and the unit test pins it, but nobody watched an alarm ring this time. Ticket 20 or the next ring check can confirm it.

**Left alone:**
- landscape (23);
- the New/Edit form and enabling + (24);
- each tab's real content (26–30), including the Now tab's badge count, which needs the read-outs and a time-driven refresh;
- tag creation, which enables + on Tags;
- onboarding and banners (31);
- the Open intent (20).
