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

Docs: <https://developer.apple.com/design/human-interface-guidelines/layout> (Adaptability, iOS), <https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations>. Verify tab bar behavior in landscape on iOS 26 with `apple-rag-mcp` before building it. The mockup's shrink-on-scroll tab bar may or may not match the system's.

## Acceptance criteria

- [ ] `UISupportedInterfaceOrientations` in the generated `Info.plist` has Portrait, Landscape Left and Landscape Right and nothing else, and the device family is still iPhone only.
- [ ] Every tab's empty state fits and stays readable in landscape, rotated left and rotated right, at the default and the largest Dynamic Type size.
- [ ] Nothing sits under the Dynamic Island, notch or home indicator in either landscape direction.
- [ ] Tab titles aren't truncated in landscape.
- [ ] Rotating keeps the selected tab and scroll position.
- [ ] Simulator screenshots of each tab in both landscape directions are attached or described in Comments, compared with the mockup.
- [ ] AGENTS.md has the adaptive layout rule. `scripts/test.sh` still passes.

Blocked by: 21
