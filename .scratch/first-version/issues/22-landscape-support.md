Status: ready-for-agent

# Landscape support in the app shell

Visual spec: `docs/mockups/2026-10-04-first-version/` (open `index.html`, set **Orientation** to Landscape; the README describes it).

## What to build

Turn on landscape for the iPhone app and make the shell adapt to it, so every screen built after this one starts out landscape-aware instead of being reworked later. Ticket 01 left the app portrait-only on purpose (the spikes don't need landscape). Apple's HIG says people "expect your experience to work well and remain familiar when they rotate their device," and that a portrait-only app is for experiences that need it. Nudge-inator doesn't.

- `UISupportedInterfaceOrientations` in `project.yml` lists Portrait, Landscape Left and Landscape Right. Upside-down stays off. Landscape-only code paths must work when the phone turns either way.
- The shell from ticket 21 adapts as the mockup shows: inline navigation titles, safe-area insets respected on both sides (Dynamic Island or notch on either edge), and a tab bar that fits beside its titles.
- Sheets and forms are presented so they work in landscape. The mockup shows full-screen sheets; check the SwiftUI presentation against it and note what you chose.
- Establish the convention for later tickets: use SwiftUI's adaptive layout (size classes, safe areas, `ScrollView`), never fixed screen sizes, so tickets 23 to 29 get landscape without per-screen work. Add a one-line rule to the "SwiftUI" part of AGENTS.md.

Why here: the shell (21) is the last thing built before the screens (22 to 28) multiply the layouts to adapt. Doing it any later means revisiting every screen. Doing it earlier has nothing to adapt. It needs no engine, store or adapter work, so it doesn't wait on the spikes.

Docs: <https://developer.apple.com/design/human-interface-guidelines/layout> (Adaptability, iOS), <https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations>. The mockup's tab bar shrinks to the current tab while scrolling down in landscape. iOS 26 has this built in: `TabView { Tab("Now", systemImage: ...) { ... } }.tabBarMinimizeBehavior(.onScrollDown)` ([tabBarMinimizeBehavior(_:)](https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)), iOS 26+; Apple's example says "on iPhone"). Use it rather than building a custom bar. The docs don't say whether it applies in portrait too, and the mockup shrinks only in landscape: check on the simulator, and if it also shrinks in portrait, either accept that and record it, or limit it to landscape (a size-class check, no fixed sizes). Don't rebuild the mockup's custom tab bar by hand.

## Acceptance criteria

- [ ] `UISupportedInterfaceOrientations` in the generated `Info.plist` has Portrait, Landscape Left and Landscape Right and nothing else, and the device family is still iPhone only.
- [ ] Every tab's empty state fits and stays readable in landscape, rotated left and rotated right, at the default and the largest Dynamic Type size.
- [ ] Nothing sits under the Dynamic Island, notch or home indicator in either landscape direction.
- [ ] Tab titles aren't truncated in landscape.
- [ ] The tab bar uses `TabView` with `Tab` and `tabBarMinimizeBehavior`; what it does in portrait vs landscape is recorded in Comments.
- [ ] Rotating keeps the selected tab and scroll position.
- [ ] Simulator screenshots of each tab in both landscape directions are attached or described in Comments, compared with the mockup.
- [ ] AGENTS.md has the adaptive layout rule. `scripts/test.sh` still passes.

Blocked by: 21
