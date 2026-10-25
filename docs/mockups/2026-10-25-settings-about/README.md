# Nudge-inator iOS mockup: Settings About

Settings with an About row, and the About page it opens, as proposed in testflight-readiness
[ticket 02](../../../.scratch/testflight-readiness/issues/02-settings-about.md) (spec stories 43
and 46). It's a copy of the [Match always shown mockup](../2026-10-25-match-always-shown/README.md),
changed only for Settings, so the two can be compared screen by screen. Everything this README
doesn't list is as that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **About row:** Settings starts with a General section, above Nudges, holding one row: a gray
  tile with `iphone`, "About" and a chevron (Brian's call on 2026-10-25). The permission banners
  stay under the title, above General, so in the app they move from the Nudges header to the
  General header.
- **About page:** pushed from the row, titled "About", with two sections:
  - **Privacy Policy** (gray tile, `hand.raised`) and **Support** (gray tile,
    `questionmark.circle`), each in the accent color with a trailing `arrow.up.forward` in the
    tertiary label color, since they leave the app. They open
    `https://newrealityinteractive.com/nudge-inator/privacy/` and
    `https://newrealityinteractive.com/nudge-inator/support/` in the system browser; the mockup
    shows where with a message instead. Footer: "These pages open in your web browser."
  - **This Build:** Version and Build, each a plain row with the value trailing in the secondary
    label color. The app reads both from its bundle (`CFBundleShortVersionString`,
    `CFBundleVersion`), so a TestFlight build shows the number the Organizer set. The mockup shows
    1.1.0 and 1. If the app can't read one, it shows "Unknown"; the mockup has no such state.
    Footer: "When you send feedback, include the version and build."
- **Accessibility:** VoiceOver reads Privacy Policy and Support as links, and each build row as
  its label and value. The app's check is on the simulators and a device check.
- `scripts/mockup-shots.py` takes `settings-about`.
