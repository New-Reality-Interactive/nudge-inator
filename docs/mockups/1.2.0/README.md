# Nudge-inator iOS mockup: 1.2.0

The app as built at 1.2.0 (`v1.2.0`): the [1.1.0 mockup](../1.1.0/README.md), then `icon-badge`
(spec #80). Made in the release PR from the Settings badges change mockup (#85), which it takes in
and replaces. Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since 1.1.0

- **A Badges row** in Settings › Nudges, under Alarms (#85, #86).
- **A Badges control** under the mockup's Permissions (iOS Settings): Allowed, Not determined,
  Provisional, Denied (off in Settings). It stands for `getNotificationSettings()`: its
  `badgeSetting` with its `authorizationStatus`, never `requestAuthorization`'s result.
- **Onboarding:** Allow on the notification prompt also allows badges, since the prompt names icon
  badges.
- `scripts/mockup-shots.py` has the screens `settings-badges-off` and `settings-badges-not-set`.

Nothing else in the app refers to the badge setting: no line or banner on Now or My Day. The Now
badge on the tab bar is the app's own and shows whatever the setting is; the setting governs only
the Icon badge on the home screen, which the mockup doesn't draw.

## The Badges row

- **Tile:** red with `app.badge`, as part of notifications, the way iOS's own Settings groups them.
- **Status:** always in the secondary label color, "Off" included. Unlike the other rows, badges off
  isn't a problem to flag (spec #80, decision 5).
- **A status, not a switch** (decision 5: no Settings toggle).
- **Open iOS Settings:** the row under it shows when badges are off, as it does for the other
  permissions, and goes to the app's notification settings
  (`UIApplication.openNotificationSettingsURLString`), where the Badges switch is.
- **No footer sentence:** the footer says how nudges arrive, and a badge isn't a Nudge.

| Badge state | Notifications | Badges row | Why |
|---|---|---|---|
| Allowed (`badgeSetting` enabled) | Allowed | On | Badges show. |
| Denied (`badgeSetting` disabled) | Allowed | Off | The person turned Badges off in iOS Settings. |
| Provisional (`authorizationStatus` provisional) | Delivered quietly | Off | iOS gives a provisional app no badge permission. To the person it's the same as denied, with the same fix. The app doesn't ask for provisional, so this is a fallback. |
| Not determined, before onboarding | Not asked | Not Set | Onboarding's prompt asks for badges. Alarms says Not Set before its prompt too. |
| Not determined: `notSupported` while notifications are authorized (an upgrade from 1.1.0) | Allowed | Not Set | The app asks again with `.badge` at launch and on coming to the foreground. iOS doesn't prompt, and turns badges on (#82). "Off" would point at a switch that isn't there. |
| Any | Off | Off | Badges can't show without notifications. |

## Checked

Against the app with the screenshot walk (`testSettings`, `testBadges`) on both simulators
(`iPhone 15 Pro - iOS 26.5`, `iPhone 15 - iOS 27.0`), in portrait, landscape and the largest text
size, on 2026-10-29: Settings, and Settings with the Badges row Off. They match.

Known differences:

- **Not Set:** the walk's `settings-badges-not-set` screen reads On. Since #89 the app asks again
  for `.badge` at launch when notifications are authorized and the badge setting is
  `notSupported`, and the harness's fake notification center grants it, as iOS did on the iPhone
  (#89). The app shows Not Set only until that request returns, so the mockup keeps drawing it.
- **Largest text:** a row's chevron wraps under its title in the mockup, where the app keeps it
  trailing, as in the 1.1.0 mockup.
