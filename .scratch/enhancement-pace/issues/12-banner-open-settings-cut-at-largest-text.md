# 12: Banners' Open Settings is cut to "Open…" at the largest text

**What to build:** A bug fix. At the accessibility text sizes a permission banner's Open Settings button shows its whole label, wrapping if it must, so a person can read where it goes.

**Blocked by:** none.

**Status:** ready-for-agent

Found during ticket 06's simulator check, in `scripts/screenshots.sh` screenshots on `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` at the largest text size (AX5), 2026-10-22. Brian asked for this ticket.

## The bug

At AX5 in portrait, the Open Settings button under each permission banner's text reads "Open…": the notifications-off banner (`banner-notifications-off-4`) and the alarms-off banner (`banner-alarms-off-3`). The label is truncated rather than wrapped, so the button no longer says what it opens. VoiceOver isn't affected: it reads the button's own label ("Open Settings for notifications").

The banner (`App/Permissions/PermissionBannerView.swift`) puts the button in the narrow column beside its icon, and the button uses `SmallBorderedButtonStyle` (`App/Design/StatusComponents.swift`), a capsule with horizontal padding whose label truncates when the column is too narrow. Ticket 06 changed the banners' words, not the button or the layout, so the bug was there before. The same style is used in `App/Tags/TagsList.swift` and `App/MyDay/MyDayRows.swift`, which may have it too.

## What it should do

DESIGN.md's Permission banner: "**Open Settings** as a small bordered button." Its label should read whole at every text size.

At accessibility text sizes the banner puts its icon above the text, with `SizeAdaptiveStack`, as Tags' rows do in Edit mode, and Open Settings fills the banner's width with `{rounded.control}` corners, as a nudge card's Done does, keeping its grey fill; its label wraps if it still doesn't fit. DESIGN.md's Permission banner says so.

- [x] At AX5, in portrait and landscape, each banner's Open Settings label reads whole, with no truncation. Shot on both simulators with `SHOTS_TESTS="testNotificationsOff testAlarmsOff testTimeSensitiveOff"` and `SHOTS_VARIANTS="largest-text largest-text-landscape"`; Brian looks at the `banner-*` shots.
- [x] The other uses of `SmallBorderedButtonStyle` read whole at AX5, in the same shots of `testTags` (`tags-edit`, Rename) and `testMyDay` (`myday`, Done). `DoneSlot` only wraps them; Now's Done button has its own style.
- [x] At the default size the banners are unchanged: the `banner-*` shots from this branch look the same as from `main`.

## Before you start

- Builds on: ticket 11: `scripts/screenshots.sh` now has an opt-in `largest-text-landscape` variant (`SHOTS_VARIANTS="portrait landscape largest-text largest-text-landscape"`), which this ticket's first criterion needs; the default variants shoot AX5 in portrait only. Ticket 11's AX5 shots (its Comments, 2026-10-23) showed My Day's Done button, which uses `SmallBorderedButtonStyle`, reading whole on its own line, so that use may already pass the second criterion; check it again rather than assume. `SizeAdaptiveStack` (`App/Design/SizeAdaptiveStack.swift`) is the repo's way to stack a row at accessibility sizes, and drops a `Spacer` there as `SettingsRow` does.
- Watch for: on the `iPhone 15 - iOS 27.0` simulator in `largest-text-landscape`, `testMyDay` can't find the bar's Filter button, so `myday-filter` isn't shot there and that run reports FAIL; the phone shows the button works (ticket 11's Comments). Shoot only the tests you need with `SHOTS_TESTS` and a `SHOTS_OUT` of its own.
- Developer stops: agree the `tdd` seams (likely none: a layout fix inside the view, so say so); the simulator pass with `scripts/screenshots.sh`, portrait and landscape, AX5 and the default size against the proposed mockup; then the offer of an iPhone run.

## Comments

### 2026-10-23: triage

- Still reproduces on `main` at AX5, portrait, on both simulators: `banner-notifications-off-4` and `banner-alarms-off-3` read "Open…". Tags' Rename reads whole there, because its row already stacks at accessibility sizes.
- Brian chose to stack the banner at accessibility sizes (icon above the text) over letting the label wrap inside the capsule, and agreed the criteria above: the screenshot runs named, the other uses listed, and "unchanged" measured against `main`'s shots, as ticket 11 did. Status `ready-for-agent`.
- No `tdd` seam: a layout change inside the view, checked with screenshots.

### 2026-10-23: the fix, and the simulator pass

- Stacking alone wasn't enough: with the full width, AX5 portrait still read "Open Setti…". Brian then chose to stack and let the label wrap ("Open / Settings" on two lines). `.fixedSize(horizontal: false, vertical: true)` sits on the button, after its style, so the capsule grows with the label; on the label alone the text spilled out of the capsule and the banner.
- The wrap is in the banner, not in `SmallBorderedButtonStyle`: Tags' Rename and My Day's Done already read whole at AX5, because their rows stack.
- Shots, both simulators, `SHOTS_TESTS="testNotificationsOff testAlarmsOff testTimeSensitiveOff"`. AX5 portrait: the icon sits above the text and Open Settings reads "Open / Settings" in a taller capsule inside the border. AX5 landscape: "Open Settings" on one line. Default size, portrait and landscape: each banner pixel-compared with `main`'s shots; the only difference is a sub-pixel shift in the button label's glyphs, which looks the same.
- Criterion 2: on `main`, `testTags` and `testMyDay` at AX5 (portrait and landscape, both simulators) show Rename and Done whole. The shared style is unchanged.
- Both mockups gain an AX rule that stacks `.banner`, to match.

### 2026-10-23: full-width button, and criterion 1

- Brian looked at the first AX5 shots and asked for Open Settings to be like Done there: as wide as the banner. Agreed: full width with `{rounded.control}` (10 pt) corners, the grey fill and teal text kept, only at accessibility sizes. `SmallBorderedButtonStyle` gains `fillsWidth` (default off), which only the banner turns on, so Rename, My Day's Done and the default-size banner are unchanged. DESIGN.md and both mockups' AX rules say so.
- The iOS 26.5 simulator had stopped turning to landscape: every iOS 26.5 "landscape" shot since ticket 09's run (07:41) was portrait, ticket 10's and 11's included. Restarting the simulator fixed it; this ticket's iOS 26.5 landscape shots were taken after the restart.
- `testTimeSensitiveOff` now shoots three pages: with one, the banner's button was never in the shot at AX5.
- Criterion 1: Brian signed off the AX5 shots of all three banners, portrait and landscape, on both simulators. Ticked.- Criterion 2: Brian signed off this branch's AX5 shots of Tags' Rename (`tags-edit`) and My Day's Done (`myday`), portrait and landscape, on both simulators. Ticked. (On iOS 27.0 in `largest-text-landscape`, `myday-filter` again wasn't shot, as in ticket 11.)- Criterion 3: Brian signed off the default-size shots of each banner's first page, `main` beside this branch, portrait and landscape, on both simulators. Ticked.
