Status: resolved

# Landscape support in the app shell

Visual spec: `docs/mockups/2026-10-04-first-version/` (open `index.html`, set **Orientation** to Landscape; the README describes it).

Design spec: `docs/design/DESIGN.md` (Layout & Spacing). Where it and the mockup disagree, see its Precedence note.

## What to build

Turn on landscape for the iPhone app and make the shell adapt to it, so every screen built after this one starts out landscape-aware instead of being reworked later. Ticket 01 left the app portrait-only on purpose (the spikes don't need landscape). Apple's HIG says people "expect your experience to work well and remain familiar when they rotate their device," and that a portrait-only app is for experiences that need it. Nudge-inator doesn't.

- `UISupportedInterfaceOrientations` in `project.yml` lists Portrait, Landscape Left and Landscape Right. Upside-down stays off. Landscape-only code paths must work when the phone turns either way.
- The shell from ticket 22 adapts as the mockup shows: inline navigation titles, safe-area insets respected on both sides (Dynamic Island or notch on either edge), and a tab bar that fits beside its titles.
- Sheets and forms are presented so they work in landscape. The mockup shows full-screen sheets; check the SwiftUI presentation against it and note what you chose.
- Establish the convention for later tickets: use SwiftUI's adaptive layout (size classes, safe areas, `ScrollView`), never fixed screen sizes, so tickets 24 to 31 get landscape without per-screen work. Add a one-line rule to the "SwiftUI" part of AGENTS.md.

Why here: the shell (21) is the last thing built before the screens (22 to 28) multiply the layouts to adapt. Doing it any later means revisiting every screen. Doing it earlier has nothing to adapt. It needs no engine, store or adapter work, so it doesn't wait on the spikes.

Docs: <https://developer.apple.com/design/human-interface-guidelines/layout> (Adaptability, iOS), <https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations>. The mockup's tab bar shrinks to the current tab while scrolling down in landscape. iOS 26 has this built in: `TabView { Tab("Now", systemImage: ...) { ... } }.tabBarMinimizeBehavior(.onScrollDown)` ([tabBarMinimizeBehavior(_:)](https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)), iOS 26+; Apple's example says "on iPhone"). Use it rather than building a custom bar. The docs don't say whether it applies in portrait too, and the mockup shrinks only in landscape: check on the simulator, and if it also shrinks in portrait, either accept that and record it, or limit it to landscape (a size-class check, no fixed sizes). Don't rebuild the mockup's custom tab bar by hand.

## Acceptance criteria

- [x] `UISupportedInterfaceOrientations` in the generated `Info.plist` has Portrait, Landscape Left and Landscape Right and nothing else, and the device family is still iPhone only.
- [x] Every tab's empty state fits and stays readable in landscape, rotated left and rotated right, at the default and the largest Dynamic Type size.
- [x] Nothing sits under the Dynamic Island, notch or home indicator in either landscape direction.
- [x] Tab titles aren't truncated in landscape.
- [x] The tab bar uses `TabView` with `Tab` and `tabBarMinimizeBehavior`; what it does in portrait vs landscape is recorded in Comments.
- [x] Rotating keeps the selected tab and scroll position.
- [x] Simulator screenshots of each tab in both landscape directions are attached or described in Comments, compared with the mockup.
- [x] AGENTS.md has the adaptive layout rule. `scripts/test.sh` still passes.

Blocked by: 22

## Comments

**Decisions (2026-10-17), settled with the user before coding.** Apple's docs, read through apple-rag, confirm: the three orientation keys; `tabBarMinimizeBehavior(.onScrollDown)` is iOS 26 and works "on only iPhone", and the docs are silent on portrait vs landscape; `navigationSubtitle` is iOS 26.0+; a sheet over a vertically compact view "uses a full-screen-cover appearance by default" (`presentationCompactAdaptation`); `XCUIDevice.orientation` rotates the device under test.

1. **Orientations:** Portrait, Landscape Left, Landscape Right; upside-down off. `OrientationTests` reads `Bundle(for: AppDelegate.self).infoDictionary` and checks `UISupportedInterfaceOrientations` is exactly those three and `UIDeviceFamily == [1]`.
2. **Adaptive rule:** size classes and geometry, never screen sizes. `TabScreen` applies `centeredInReadableColumn()` (App/Design/ReadableWidth.swift) to each tab's content when ready. It adds safe-area padding of `ReadableColumn.margin(availableWidth:)`, measured with `onGeometryChange`. Padding, not a frame or `contentMargins`: a frame cut the background, and `contentMargins` didn't move a List's sections. The measured width is already inside the safe areas (750 pt with 62 pt insets on the iPhone 17 simulator), so the insets are not subtracted again.
3. **Titles:** large in portrait; the system makes them inline in compact height with no code. My Day shows its date as `navigationSubtitle` in compact height (`verticalSizeClass == .compact`) and as the list header in portrait.
4. **Tab bar:** the system `TabView` with `.tabBarMinimizeBehavior(.onScrollDown)`, unchanged from ticket 22. On the simulator it did not minimize in portrait or in landscape with these short, empty tabs, so the portrait behavior is not recorded from the simulator; the phone check passed, and the portrait detail is worth noting when tickets 26 to 28 bring real content.
5. **Sheets and forms:** the system default, full-screen in compact height, matching the mockup. Later tickets must not pass `presentationCompactAdaptation(.none)`.
6. **Test seams:** `OrientationTests` (Info.plist) and `ReadableColumnTests` (the margin, against hand-worked values). Not tested on the constant `readableWidth == 672`: it already existed and passes, so it could not go red. Layout, safe areas, truncation, rotation and the subtitle are screenshot and device checks.
7. **AGENTS.md:** one rule in the SwiftUI part.

**Screenshots** (iPhone 17 simulators, a throwaway XCUITest rotating with `XCUIDevice.orientation`, deleted afterwards). iOS 26.5, light, each tab in portrait, Landscape Left and Landscape Right at the default text size, and the four tabs at accessibility-xxxl in Landscape Left. Compared with the mockup: inline title, tab bar beside its titles as a floating pill, content centered at 672 with the background to the edges, and My Day's date as a subtitle all match. The mockup's pill shrinks to the current tab while scrolling; the simulator's did not (item 4). The iOS 26.1 simulator ran the test suite but was not screenshotted. Rotating Now (scrolled) and My Day (selected) kept the tab and the scroll position on a round trip.

**Device (iPhone 15, iOS 27.0.1).** The app tests passed on the phone from a fresh install (118 tests; two permission prompts), run per AGENTS.md's device rule. **Manual checks, done by Brian on the phone (all passed, reported without details):** rotate both ways with the Dynamic Island on each side and nothing under it or the home indicator; the largest text size in landscape; the tab bar minimizing; and that My Day's portrait empty subtitle adds no extra line. Whether the bar minimizes in portrait on the device was not recorded separately.

**Code review** (standards and spec, two agents). Fixed: the modifier was renamed from `readableWidth()` (it clashed with `Design.Spacing.readableWidth`) to `centeredInReadableColumn()`; a landscape preview for My Day; the AGENTS.md line shortened; a margin test added. One finding, to subtract the safe-area insets from the measured width, was wrong (it collapsed the margin to zero); the measured width is already inside the safe areas, and a screenshot confirmed it. Not changed: the empty subtitle in portrait (no extra line in the screenshot; device check).
