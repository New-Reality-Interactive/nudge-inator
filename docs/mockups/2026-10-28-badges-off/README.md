# Nudge-inator iOS mockup: badges off

A change mockup for icon-badge ticket #85 (spec #80, decision 5): the line the app shows when the
Icon badge can't show. It's a copy of the [1.1.0 mockup](../1.1.0/README.md) built on the
[mockup template](../2026-10-26-mockup-template/README.md), so the two can be compared screen by
screen. Only the badges-off line and its control differ. It's deleted when the 1.2.0 version mockup
takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **The badges-off line**, at the top of Now, My Day and Settings, under the permission banners.
  Each screen shows it where it shows the banners, including My Day's in landscape.
- **A Badges control** under the mockup's Permissions (iOS Settings): Allowed, Not determined,
  Provisional, Denied (off in Settings). It stands for `getNotificationSettings()`: its
  `badgeSetting` with its `authorizationStatus`, never `requestAuthorization`'s result.
- **Onboarding:** Allow on the notification prompt also allows badges, since the prompt names icon
  badges.
- `scripts/mockup-shots.py` gains the screens `badges-off`, `badges-off-provisional`,
  `badges-not-determined`, `badges-off-banners`, `myday-badges-off` and `settings-badges-off`.
  Any other mockup draws them with badges on.

## The line

> **Badges are off.** The app icon can't show how many reminders are nudging you.
>
> Open Settings

- **Open Settings** goes to the app's page in iOS Settings › Notifications
  (`UIApplication.openNotificationSettingsURLString`, the banners' `.notificationSettings`), which
  holds the Badges switch. VoiceOver calls it "Open Settings for badges", since a banner's Open
  Settings can show beside it.
- **It's its own line, not a banner:** a badge is not a Nudge, so it isn't a Reach item, and badges
  being off isn't an error. It has no card and no border, and no negative or warning color. The
  `app.badge` icon is in the secondary label color, the text in the label color, subhead, with the
  lead sentence bold, as a banner's is. Open Settings is a borderless button in the accent color,
  because it can be tapped (DESIGN.md › Color).
- **At accessibility text sizes** the icon goes above the text, as a banner's does. The text and
  Open Settings wrap rather than truncating.
- **Button Shapes:** Open Settings is a plain text button, so in the app it shows the system's
  button shape when Button Shapes is on (DESIGN.md › Color). The mockup has no Button Shapes
  control, so that's a check for the build.

## When it shows

| Badge state | Notifications | Line | Why |
|---|---|---|---|
| Allowed (`badgeSetting` enabled) | Allowed | None | Badges show. |
| Denied (`badgeSetting` disabled) | Allowed | Shows | The person turned Badges off in iOS Settings. |
| Provisional (`authorizationStatus` provisional) | Delivered quietly | Shows | iOS gives a provisional app no badge permission (Apple, "Asking permission to use notifications"). The app doesn't ask for provisional, so this is a fallback. |
| Not determined, before onboarding | Not asked | None | Onboarding's prompt asks for badges. The banners show nothing before the prompt either. |
| Not determined: `notSupported` while notifications are authorized (an upgrade from 1.1.0) | Allowed | None | The app asks again with `.badge` at launch and on coming to the foreground. iOS doesn't prompt, and turns badges on (#82). |
| Any | Off | None | The notifications-off banner already sends the person to the same Settings page. |

## Checked

With `scripts/mockup-shots.py`, in portrait, landscape and the largest text size (AX5), on
2026-10-28: the line alone, under the alarms-off and Time Sensitive-off banners, provisional,
not determined (no line), and on My Day and Settings.
