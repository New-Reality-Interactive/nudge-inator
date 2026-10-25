# 02: Settings › About

**What to build:** Settings gets an About row that opens an About screen with three parts:
- a Privacy Policy row that opens `https://newrealityinteractive.com/nudge-inator/privacy/` in the system browser;
- a Support row that opens `https://newrealityinteractive.com/nudge-inator/support/` the same way;
- a section showing the app's version and build number, read from the running app's bundle, so a tester's feedback names the build that was tested.

This meets Guideline 5.1.1(i)'s in-app privacy link before the first archive. A new dated mockup comes first. Spec stories 43 and 46.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] A new dated mockup under `docs/mockups/` shows Settings with the About row and the About screen, and Brian approves it before anything is built.
- [x] Settings has an About row that opens the About screen, as in the mockup.
- [x] The Privacy Policy and Support rows each open their URL in the system browser (manual check on a simulator).
- [x] The build section shows the version and build number from the bundle. A unit test checks the shown values against the bundle's `CFBundleShortVersionString` and `CFBundleVersion`.
- [x] Every label is a String Catalog string, and the screen meets `docs/design/DESIGN.md`.
- [x] Simulators (26.5 and 27.x): Settings and About in portrait, landscape and the largest text size, and the screenshot harness walks to About.
- [ ] On the iPhone (phone and iOS version recorded): both rows open their pages, the build section reads correctly, and VoiceOver reads each link row as a link and reads the version and build.
- [x] `scripts/test.sh` passes on both simulators.

## Before you start

- Builds on: Settings is `App/Shell/SettingsTab.swift`, with a Nudges section and a Data section built from `SettingsRow` (`App/Shell/SettingsRow.swift`). The Default Pace page (`App/Shell/DefaultPacePage.swift`) is prior art for a page pushed from a Settings row. Mockups are frozen: make a new dated folder, and don't edit an old one. Spec: Implementation Decisions, "Settings › About", and Testing Decisions.
- Watch for: the two pages may not be live yet. The redone website spec publishes them, so a link can land on a 404 during the simulator check. That still passes, as long as the right URL opens. The build number on a TestFlight install is the Organizer's, not the repo's 1, so read it at runtime and never hard-code it. Where the About row sits in Settings, and in which section, is settled on the mockup.
- Developer stops: Brian's approval of the mockup; agree the `tdd` seam for the version text; the simulator pass in `scripts/screenshots.sh`; VoiceOver; the offered iPhone run.

## Comments

- 2026-10-25, mockup: `docs/mockups/2026-10-25-settings-about`. Brian approved it with one change:
  the About row is in a **General** section above Nudges, not a headerless section at the end. The
  permission banners stay under the title, so in the app they moved from the Nudges header to the
  General header. DESIGN.md now lists the About, Privacy Policy and Support tiles (gray) and the
  link row (accent label, `arrow.up.forward`, read as a link).
- 2026-10-25, `tdd` seam (agreed with Brian): `AppBuild` (`App/Shell/AppBuild.swift`), read through
  `Bundle.object(forInfoDictionaryKey:)`. `AppBuildTests` checks it against the running bundle's
  `CFBundleShortVersionString` and `CFBundleVersion`, and that a missing or non-text value is nil.
  About then shows "Unknown", a state the mockup doesn't draw (its README says so).
- 2026-10-25, simulators (26.5 and 27.0): `SHOTS_TESTS=testSettings scripts/screenshots.sh` walks
  to About (`settings-about`). Settings and About match the mockup in portrait, landscape and the
  largest text size, where the rows stack like the other Settings rows. The harness shows version
  1.0, build 1: its own bundle's, which shows the value is read at runtime.
- 2026-10-25, links (manual, iPhone 15 - iOS 27.0 simulator, Brian): Privacy Policy and Support
  each opened Safari, on a 404 since the pages aren't published yet. The simulator's log shows the
  URLs opened: `https://newrealityinteractive.com/nudge-inator/privacy/` and
  `https://newrealityinteractive.com/nudge-inator/support/`. About showed version 1.1.0, build 1.
- 2026-10-25, criteria changed (agreed with Brian): the VoiceOver check moved from the simulators
  (criterion 6) to the iPhone run (criterion 7), since checking it in Accessibility Inspector on
  the simulator took too long. Brian took the offered iPhone run, so criterion 7 is a check, not
  an offer. It runs in a fresh session (review.md, Session size).
- Open: criterion 7, the iPhone run.
