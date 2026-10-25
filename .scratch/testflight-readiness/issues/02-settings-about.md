# 02: Settings › About

**What to build:** Settings gets an About row that opens an About screen with three parts:
- a Privacy Policy row that opens `https://newrealityinteractive.com/nudge-inator/privacy/` in the system browser;
- a Support row that opens `https://newrealityinteractive.com/nudge-inator/support/` the same way;
- a section showing the app's version and build number, read from the running app's bundle, so a tester's feedback names the build that was tested.

This meets Guideline 5.1.1(i)'s in-app privacy link before the first archive. A new dated mockup comes first. Spec stories 43 and 46.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] A new dated mockup under `docs/mockups/` shows Settings with the About row and the About screen, and Brian approves it before anything is built.
- [ ] Settings has an About row that opens the About screen, as in the mockup.
- [ ] The Privacy Policy and Support rows each open their URL in the system browser (manual check on a simulator).
- [ ] The build section shows the version and build number from the bundle. A unit test checks the shown values against the bundle's `CFBundleShortVersionString` and `CFBundleVersion`.
- [ ] Every label is a String Catalog string, and the screen meets `docs/design/DESIGN.md`.
- [ ] Simulators (26.5 and 27.x): Settings and About in portrait, landscape and the largest text size, and the screenshot harness walks to About. VoiceOver reads each row as a link-like button and reads the version and build.
- [ ] Offered to Brian, after the simulator pass: on the iPhone, both rows open their pages and the build section reads correctly (phone and iOS version recorded).
- [ ] `scripts/test.sh` passes on both simulators.

## Before you start

- Builds on: Settings is `App/Shell/SettingsTab.swift`, with a Nudges section and a Data section built from `SettingsRow` (`App/Shell/SettingsRow.swift`). The Default Pace page (`App/Shell/DefaultPacePage.swift`) is prior art for a page pushed from a Settings row. Mockups are frozen: make a new dated folder, and don't edit an old one. Spec: Implementation Decisions, "Settings › About", and Testing Decisions.
- Watch for: the two pages may not be live yet. The redone website spec publishes them, so a link can land on a 404 during the simulator check. That still passes, as long as the right URL opens. The build number on a TestFlight install is the Organizer's, not the repo's 1, so read it at runtime and never hard-code it. Where the About row sits in Settings, and in which section, is settled on the mockup.
- Developer stops: Brian's approval of the mockup; agree the `tdd` seam for the version text; the simulator pass in `scripts/screenshots.sh`; VoiceOver; the offered iPhone run.

## Comments
