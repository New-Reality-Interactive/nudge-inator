# Nudge-inator iOS mockup: Settings badges

A change mockup for icon-badge ticket #85 (spec #80, decision 5): a Badges row in Settings, the only
place the app shows the badge setting. It's a copy of the [1.1.0 mockup](../1.1.0/README.md) built
on the [mockup template](../2026-10-26-mockup-template/README.md), so the two can be compared screen
by screen. Only the Badges row and its control differ. It's deleted when the 1.2.0 version mockup
takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **A Badges row** in Settings › Nudges, under Alarms.
- **A Badges control** under the mockup's Permissions (iOS Settings): Allowed, Not determined,
  Provisional, Denied (off in Settings). It stands for `getNotificationSettings()`: its
  `badgeSetting` with its `authorizationStatus`, never `requestAuthorization`'s result.
- **Onboarding:** Allow on the notification prompt also allows badges, since the prompt names icon
  badges.
- `scripts/mockup-shots.py` gains the screens `settings-badges-off` and `settings-badges-not-set`.
  Any other mockup draws them with no Badges row.

Nothing else in the app refers to the badge setting: no line or banner on Now or My Day. The Now
badge on the tab bar is the app's own and shows whatever the setting is; the setting governs only
the Icon badge on the home screen.

## The Badges row

- **Tile:** red with `app.badge`, as part of notifications, the way iOS's own Settings groups them.
- **Status:** always in the secondary label color, "Off" included. Unlike the other rows, badges off
  isn't a problem to flag (decision 5).
- **A status, not a switch** (decision 5: no Settings toggle).
- **Open iOS Settings:** the row under it shows when badges are off, as it does for the other
  permissions, and goes to the app's notification settings
  (`UIApplication.openNotificationSettingsURLString`), where the Badges switch is.
- **No footer sentence:** the footer says how nudges arrive, and a badge isn't a Nudge.

| Badge state | Notifications | Badges row | Why |
|---|---|---|---|
| Allowed (`badgeSetting` enabled) | Allowed | On | Badges show. |
| Denied (`badgeSetting` disabled) | Allowed | Off | The person turned Badges off in iOS Settings. |
| Provisional (`authorizationStatus` provisional) | Delivered quietly | Off | iOS gives a provisional app no badge permission (Apple, "Asking permission to use notifications"). To the person it's the same as denied, with the same fix. The app doesn't ask for provisional, so this is a fallback. |
| Not determined, before onboarding | Not asked | Not Set | Onboarding's prompt asks for badges. Alarms says Not Set before its prompt too. |
| Not determined: `notSupported` while notifications are authorized (an upgrade from 1.1.0) | Allowed | Not Set | The app asks again with `.badge` at launch and on coming to the foreground. iOS doesn't prompt, and turns badges on (#82). "Off" would point at a switch that isn't there. |
| Any | Off | Off | Badges can't show without notifications. |

## Checked

With `scripts/mockup-shots.py`, in portrait, landscape and the largest text size (AX5), on
2026-10-28: Settings with the Badges row Off (and Open iOS Settings) and Not Set.
