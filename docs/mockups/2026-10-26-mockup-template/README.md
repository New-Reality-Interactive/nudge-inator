# Nudge-inator iOS mockup: template

The framework every new mockup starts from: the phone frame, the mockup controls, Apple's system
look (colors, type, lists, sheets, the Lock Screen and alarm), the made-up data and the screens'
JavaScript. It was the Settings About mockup of testflight-readiness ticket 02 (at the
`tickets-archive` tag), so its screens are the app's at 1.1.0 less the Custom and Repeat
checkmarks. For how the app looks at a version, open that version's mockup instead
(`docs/mockups/<version>/`).

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## Using it

- **A version mockup** (`docs/mockups/<version>/`, such as `1.2.0`): made in a feature's release
  PR, before `v<version>` is tagged and pushed (`docs/agents/release.md`). Copy the latest version mockup, which already draws the app as it was, or this
  template if none exists, and bring every screen to the app as built. Its README lists what
  changed since the version before. Check the screens the release changed against the app with
  the screenshot walk (`docs/agents/device-testing.md`, Simulator screenshots). Once merged it's
  frozen.
- **A change mockup** (`docs/mockups/<YYYY-MM-dd>-<change>/`): a visual change proposed during a
  feature. Copy the latest version mockup and change only what the change needs, so the two can be
  compared screen by screen. Its README lists what changed and names its ticket (`#<n>`). It's
  deleted when the release's version mockup takes the change in.
- **The template itself** changes only for the framework: a new control, a fix to the system look,
  or a screen the walk needs. Its screens aren't kept up to date with the app.

Every copy keeps the `<title>` naming the mockup, the controls panel, and the screen names that
`scripts/mockup-shots.py` drives. A screen that script doesn't know goes in its `SCREENS`.

## How the file is laid out

The CSS sections, in order: Colors (dynamic tokens for light, dark and Increase Contrast),
Typography (Dynamic Type sizes), the stage (the phone and the controls), navigation and tab bars,
inset grouped lists, buttons and controls, nudge cards, sheets and alerts, the simulated Lock
Screen and alarm, landscape, and iOS 26 sheet bars. Then the JavaScript: the fixed clock, SF
Symbols redrawn, strengths and escalation, the made-up data, repeat rules, app state and
navigation, the views, the reminder form, the simulated system UI, actions, rendering and events.

## The mockup controls

A panel beside the phone, marked "Not part of the app". The clock is fixed at Mon, Sep 28,
8:20 AM.

- **Show what the iPhone does:** the next early nudge as a notification, the next Urgent nudge as
  an alarm, and first launch (onboarding).
- **Pace and strength:** set the New Reminder form's strength (Gentle, Firm, Relentless) and pace
  (Escalating, Consistent, and Consistent's wait), so each How It Nudges can be seen.
- **Permissions (iOS Settings):** Notifications, Alarms and Time Sensitive allowed or not, for the
  permission banners.
- **iPhone:** screen size in points and orientation.
- **My Day's Filter badge:** the badge's color and number.
- **iPhone settings:** 24-Hour Time, Appearance, Text Size (xSmall to AX5), Bold Text, Increase
  Contrast and Reduce Transparency.
- **Reset the mockup.**
