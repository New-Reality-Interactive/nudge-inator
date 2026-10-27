# Nudge-inator iOS mockup: 1.1.0

The app as built at 1.1.0 (`v1.1.0`): `first-version` (1.0.0), then `enhancement-pace` and
`testflight-readiness` (1.1.0). The first version mockup, made after the release from the
[mockup template](../2026-10-26-mockup-template/README.md). Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What it draws

The template's screens, plus the two changes the template doesn't have, carried over from their
mockups (at the `tickets-archive` tag):

- **Custom checkmark:** the Custom repeat page saves its choices with a checkmark
  (enhancement-pace ticket 17).
- **Repeat checkmark:** the Repeat page saves its choice with a checkmark (enhancement-pace
  ticket 22).

One fix to draw the app as built: My Day's filter sheet showed a "Match" label beside a small
segmented control. The app's system segmented `Picker` (DESIGN.md › Tags) fills its own section
with no visible label, so the mockup does too. At accessibility sizes the app's menu sits in its
own section with "Match" over the choice, in the label color even when disabled, and the mockup
now draws it that way. VoiceOver reads the label either way.

Known difference, left as the template draws it: at the largest text sizes a checkmark row's
checkmark wraps under its title in the mockup, where the app keeps it trailing.

`scripts/mockup-shots.py` opens Repeat and Custom by tapping the form's Repeat row, since the
checkmark changes copy the repeat on the way in.

Checked against the app with the screenshot walk on both simulators (`iPhone 15 Pro - iOS 26.5`,
`iPhone 15 - iOS 27.0`) on 2026-10-26.
