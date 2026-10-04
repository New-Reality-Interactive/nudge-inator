Status: ready-for-human

# AlarmKit device spike: alarm limit, Open silencing, Open on a locked phone

Throwaway. A tiny debug screen (or a separate throwaway app) run on a **physical iPhone on iOS 26** for the final answers. Record the answers under `## Answer` in this file; do not carry the spike code into the product.

## Simulator pass first (optional, untested)

Apple's docs say nothing about AlarmKit in the Simulator, so whether it works there is unknown. Spend a few minutes running the debug screen on an iOS 26 simulator before the device run:

- If alarms schedule and Open runs, questions A, B and F can be answered provisionally. Mark any simulator-only answer "simulator, unconfirmed" and repeat it on the device.
- If scheduling throws, nothing fires, or the Open intent never runs, record that in `## Answer` and go straight to the device.
- C (locked and before first unlock), D (silent mode and Focus) and E (Lock Screen look) cannot be reproduced in a simulator and are device-only. Treat a simulator limit number for A as provisional only.

The device run is still required for the final answers to A to F.

## What to build

A debug screen with buttons that schedule AlarmKit alarms with an alert-only presentation: title, tint, system Stop, and a custom secondary button **Open** (`secondaryButtonBehavior: .custom`) bound to a `secondaryIntent` that opens the app.

## Questions and docs basis

| # | Question | What the docs say | Status |
|---|---|---|---|
| A | What is the system alarm limit? Schedule alarms one by one (fixed-date, far in the future) until `schedule` throws `AlarmManager.AlarmError.maximumLimitReached`; record the count. Also check whether the limit counts per app or across apps, and whether fired/stopped alarms free slots. | `maximumLimitReached`: "A maximum number of alarms is already scheduled." No number is given. [maximumLimitReached](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmerror/maximumlimitreached). `AlarmManager.alarms` drops alarms once they fire and stop ([alarms](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarms)). | **Device check** (number, per-app vs global, slot reuse) |
| B | Does tapping **Open** silence the ring? | The docs I could read don't say. The spec quotes the secondary intent as running "without mutating the alarm state"; I did not find that sentence in the pages I fetched, so treat it as unconfirmed. WWDC25-230 shows the Open intent with `openAppWhenRun = true` and says the system handles stop/countdown for system buttons only ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230), [sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)). `AlarmManager.stop(id:)` stops an alarm; a one-shot is then deleted ([stop(id:)](https://developer.apple.com/documentation/alarmkit/alarmmanager/stop(id:))). | **Device check.** Also test: does calling `AlarmManager.shared.stop(id:)` from inside the Open intent silence it? |
| C | How does **Open** behave on a locked phone: does the button show, does the intent run, does the app open, does it require unlock? Test: (1) locked after first unlock, (2) locked right after a reboot before first unlock. | "This is only available after first unlock." ([AlarmConfiguration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration)). Behaviour when locked after first unlock is not documented. | **Device check** |
| D | With the (empty) widget extension from ticket 01 present, does an alert-only alarm (no countdown) ring reliably through silent mode and a Focus? Optional comparison: the same alarm in a build without the extension, to learn whether it was ever needed. | Alert breaks through silent mode and the current Focus ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)). The extension is expected for countdown presentations ([sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)); the docs don't say what happens to alert-only alarms either way. | Docs answer silent/Focus; the extension question is a **device check** |
| F | Does the Open intent work when it is compiled into the shared module used by both the app and the extension? (It will live there per ticket 01.) | Intent runs with `openAppWhenRun = true` ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)). Which process runs a shared intent is not stated in the pages I read. | **Device check** |
| E | Does the alarm show only the title (plus app name) on the Lock Screen, with the app's tint? | Alert shows the custom title and the app name ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)). | Docs answer; confirm by eye |

## Acceptance criteria

- [ ] A: the measured limit (from the device; a simulator number alone does not count) is written down as a number (or "no limit up to N"), with whether it is per app and whether stopped/fired alarms free slots.
- [ ] B: written answer "Open silences / does not silence the ring", and, if it does not, whether `stop(id:)` inside the intent silences it.
- [ ] C: written answer for both locked cases (after first unlock; before first unlock), describing what the person sees and whether the app opens on the reminder.
- [ ] D, E and F: yes/no with notes. D records whether the extension made any difference (if not, say so; the extension stays anyway, decided in ticket 01).
- [ ] The answers are summarised at the top of `## Answer` in a form tickets 14, 18 and 19 can quote (chain length recommendation, Open-intent behaviour, locked-phone behaviour).
- [ ] Device model and iOS build number recorded, plus whether a simulator pass was tried and what it showed.

Blocked by: 01
