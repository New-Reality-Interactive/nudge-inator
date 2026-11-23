# Nudge-inator iOS mockup: Settings rows open iOS Settings (#372)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Quiet hours banner mockup](../2026-11-22-quiet-hours-banner/README.md) with Settings' Notifications,
Alarms and Badges rows made tappable, and nothing else changed. It is deleted when the 1.6.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. Settings is the
last tab; the three rows are at the top of its Nudges section.

## What changed since the banner mockup

- **Notifications, Alarms and Badges each end in a chevron** (`chevron.forward`, tertiary label),
  after the status they already show, as Default Pace and Quiet Hours do. Nothing else about the rows
  moves: tile, label, status and its colors (red when off, Badges gray) are as before.
- **Where they go:** Notifications and Badges open the app's notification settings in iOS Settings;
  Alarms opens the app's own page there, since alarms are reached only from it. In the mockup a tap
  shows a note saying where it would land.
- **VoiceOver:** each row is one button that reads its label and status, then a short hint:
  "Notifications, On. Opens notification settings." (Alarms: "Opens the app's settings."; Badges: the
  same as Notifications.) The hint is in the mockup as `aria-description`.
- **The Open iOS Settings row is gone** (the developer's call, 2026-11-23): the three rows now go
  to iOS Settings themselves, so a row that appeared only while something was off, to do the same,
  is redundant. Nothing else in Settings changes. The permission banners keep their Open Settings
  button, as they were.
