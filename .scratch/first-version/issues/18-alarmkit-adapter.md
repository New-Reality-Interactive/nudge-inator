Status: ready-for-agent

# AlarmKit adapter

## What to build

Extend the scheduler adapter to apply the plan's **alarm** items through `AlarmManager`:

- Alert-only `AlarmPresentation` with the reminder **title only**, the system Stop button, a custom secondary button **Open** (`AlarmButton`, `secondaryButtonBehavior: .custom`) and the app's tint (`AlarmAttributes(presentation:metadata:tintColor:)`). No countdown or paused presentation. The `AlarmMetadata` type comes from the shared module (ticket 01); an empty type is fine as long as it is `Codable`, `Hashable` and `Sendable`.
- Build the configuration with `AlarmManager.AlarmConfiguration.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` (iOS 26.0+, "behaves like a traditional alarm"), then `AlarmManager.shared.schedule(id:configuration:)`. Don't use the countdown-style `init`.
- **Minimum is iOS 26.1**, so use `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` (iOS 26.1+; the system provides the Stop button). Don't use the deprecated `init(title:stopButton:...)`, and don't copy Apple's sample's `stopButton:` argument. No `#available` branch is needed.
- A one-shot schedule per alarm item: `Alarm.Schedule.fixed(Date)` (not relative to the time zone). The alarm ID derives from occurrence and nudge number so a re-plan can cancel and replace.
- `secondaryIntent` is the Open intent from ticket 19, and its type is `(any LiveActivityIntent)?`. Stop uses the system default (ADR 0001: Stop needs no app code; the later nudges are already pre-scheduled).
- Remove not-yet-fired alarms with `cancel(id:)` ("deletes the alarm from the system"). `stop(id:)` is for a ringing alarm and deletes a one-shot.
- Authorization: request through `requestAuthorization()` when onboarding asks (ticket 29), read `authorizationState`, observe `authorizationUpdates`, report to the engine. If the app never asks, AlarmKit asks by itself on the first `schedule` call, so make sure onboarding has asked first (or the prompt appears mid-plan).
- Scheduling errors: map `AlarmManager.AlarmError.maximumLimitReached` to the engine's "alarm limit" event (ticket 14) and apply the plan it returns.
- Reconcile on launch using `alarms` (it `throws`) and `alarmUpdates` (an async sequence of the current `[Alarm]` whenever one alerts, snoozes or dismisses): a scheduled alarm missing from `alarms` has fired or been stopped. Persist what you scheduled in the store to compare against, as Apple's docs advise.

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| `NSAlarmKitUsageDescription` is required, or scheduling fails | [key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription) | Docs answer |
| Denied authorization makes all schedule attempts fail; state can be read and observed | [requestAuthorization()](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization()), [authorizationState](https://developer.apple.com/documentation/alarmkit/alarmmanager/authorizationstate-swift.property), [authorizationUpdates](https://developer.apple.com/documentation/alarmkit/alarmmanager/authorizationupdates) | Docs answer |
| Alert shows title and app name; breaks through silent mode and Focus | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230) | Docs answer |
| `.alarm(...)` factory, `stopIntent`/`secondaryIntent` typed `any LiveActivityIntent`, `AlarmMetadata` is Codable + Hashable + Sendable | [alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration/alarm(schedule:attributes:stopintent:secondaryintent:sound:)), [AlarmMetadata](https://developer.apple.com/documentation/alarmkit/alarmmetadata) | Docs answer |
| `Alert(title:secondaryButton:secondaryButtonBehavior:)` needs iOS 26.1; the stop-button init is deprecated | [Alert](https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct) | Docs answer; the project minimum is 26.1 for this reason |
| Custom secondary button via `.custom` behaviour and `secondaryIntent`; tint colours the secondary button and title | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230), [sample code](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit) | Docs answer |
| Fixed schedule is one date and does not move with time zone | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230) | Docs answer |
| Alarms that fired and stopped disappear from `alarms`; use your own store to know | [alarms](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarms) | Docs answer |
| `maximumLimitReached` is the error for too many alarms | [maximumLimitReached](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmerror/maximumlimitreached) | Docs answer for the error; **the number is a device check** (ticket 02) |
| Stop does not end the nudging and the later alarms still ring | Stop on a one-shot deletes that alarm only ([stop(id:)](https://developer.apple.com/documentation/alarmkit/alarmmanager/stop(id:))); that other pre-scheduled alarms are unaffected is not stated | **Device check** |
| Alert-only alarm works with the empty widget extension present | Sample says the extension is expected for countdown | **Device check** (ticket 02 D) |

## Acceptance criteria

- [ ] Unit tests over a fake `AlarmManager` protocol wrapper: a plan with 4 alarm items yields 4 schedule calls with title-only presentation (assert the title and that no notes/tags/count text is passed), unique IDs, correct fire dates.
- [ ] Replacing a plan cancels alarms not in the new plan and schedules the new ones.
- [ ] A simulated `maximumLimitReached` is reported to the engine and the returned plan is applied.
- [ ] Denied authorization is reported to the engine as "alarms denied" and no schedule call is made.
- [ ] Device (human): a scheduled alarm rings through silent mode and a Focus, shows title only, Stop silences it, and the next planned alarm still rings on time.

Blocked by: 02, 14, 17
