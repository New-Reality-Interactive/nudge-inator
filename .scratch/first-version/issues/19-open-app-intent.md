Status: ready-for-agent

# Open app intent

## What to build

The App Intent the alarm's **Open** button runs. It is defined in the shared module from ticket 01 so both the app and the extension compile it. It carries the alarm identifier (mapped to occurrence), opens the app (`openAppWhenRun = true`) on that reminder's details screen (ticket 24), where Done is. If ticket 02 showed Open does not silence the ring, the intent also stops the alarm (`AlarmManager.shared.stop(id:)`). If it showed the intent does not run, or does not open the app, on a locked phone, the behaviour required by the answer is implemented here (for example the alarm keeps ringing until unlocked, noted in the Open button's absence or in the details screen).

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| Intent includes the alarm ID and sets `openAppWhenRun`; the app then shows the detail for that ID | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230) | Docs answer |
| Secondary intent is "only available after first unlock" | [AlarmConfiguration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration) | Docs answer |
| Open silences the ring or not; stopping inside the intent | Not stated | **Device check, answered by ticket 02 B** |
| Locked-phone behaviour | Not stated beyond first unlock | **Device check, answered by ticket 02 C** |

## Acceptance criteria

- [ ] Unit test: the intent resolves an alarm ID to its occurrence and posts a "show reminder" route; an unknown ID routes to Now without crashing.
- [ ] The app opens on the reminder's details with the occurrence's Done action available.
- [ ] The intent type lives in the shared module and both the app and the extension build with it.
- [ ] Behaviour matches ticket 02's recorded answers B and C (cite them in the code comment).
- [ ] Device (human): tapping Open from the Lock Screen and from the Dynamic Island/banner lands on the reminder, and the ring state matches the spike.

Blocked by: 02, 18, 24
