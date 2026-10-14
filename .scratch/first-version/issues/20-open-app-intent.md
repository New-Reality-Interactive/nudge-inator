Status: ready-for-agent

# Open app intent

## What to build

The App Intent the alarm's **Open** button runs. It conforms to **`LiveActivityIntent`** (AlarmKit's `secondaryIntent` is typed `(any LiveActivityIntent)?`, so a plain `AppIntent` won't compile there). It is defined in the shared module from ticket 01 so both the app and the extension compile it. It carries the alarm identifier (mapped to occurrence) and opens the app on that reminder's details screen (ticket 27), where Done is. **Don't use `openAppWhenRun`**: it is deprecated in iOS 26.0, and Apple says setting it to `true` "generates an error if the app intent runs in an app extension", which is possible here because the intent is compiled into both targets. Declare `static var supportedModes: IntentModes = .foreground` instead ("bring the app to the foreground before the action runs"), and let ticket 02 F say which process actually runs it. WWDC25-230 still shows `openAppWhenRun`, so prefer the API docs. If ticket 02 showed Open does not silence the ring, the intent also stops the alarm (`AlarmManager.shared.stop(id:)`). If it showed the intent does not run, or does not open the app, on a locked phone, the behaviour required by the answer is implemented here (for example the alarm keeps ringing until unlocked, noted in the Open button's absence or in the details screen).

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| Intent includes the alarm ID and the app then shows the detail for that ID | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230) | Docs answer |
| Must conform to `LiveActivityIntent` | [AlarmConfiguration init](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration/init(countdownduration:schedule:attributes:stopintent:secondaryintent:sound:)) (`secondaryIntent: (any LiveActivityIntent)?`) | Docs answer |
| `openAppWhenRun` deprecated in iOS 26.0 and errors in an extension; use `supportedModes` | [openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun), [supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) | Docs answer |
| A `LiveActivityIntent` runs in the app process "without opening the app"; `.foreground` should bring it forward | [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent) | **Device check, answered by ticket 02 F** |
| Secondary intent is "only available after first unlock" | [AlarmConfiguration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration) | Docs answer |
| Open silences the ring or not; stopping inside the intent | Not stated | **Device check, answered by ticket 02 B** |
| Locked-phone behaviour | Not stated beyond first unlock | **Device check, answered by ticket 02 C** |

## Acceptance criteria

- [ ] Unit test: the intent resolves an alarm ID to its occurrence and posts a "show reminder" route; an unknown ID routes to Now without crashing.
- [ ] The app opens on the reminder's details with the occurrence's Done action available.
- [ ] The intent conforms to `LiveActivityIntent`, declares `supportedModes` (not `openAppWhenRun`), and builds without warnings about either.
- [ ] The intent type lives in the shared module and both the app and the extension build with it.
- [ ] Behaviour matches ticket 02's recorded answers B and C (cite them in the code comment).
- [ ] Device (human): tapping Open from the Lock Screen and from the Dynamic Island/banner lands on the reminder, and the ring state matches the spike.

Blocked by: 02, 19, 27
