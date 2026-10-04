Status: ready-for-agent

# AlarmKit adapter

## What to build

Extend the scheduler adapter to apply the plan's **alarm** items through `AlarmManager`:

- Alert-only `AlarmPresentation` with the reminder **title only**, the system Stop button, a custom secondary button **Open** (`secondaryButtonBehavior: .custom`) and the app's tint. No countdown or paused presentation. The `AlarmMetadata` type comes from the shared module (ticket 01).
- A one-shot fixed schedule per alarm item; the alarm ID derives from occurrence and nudge number so a re-plan can cancel and replace.
- `secondaryIntent` is the Open intent from ticket 19. Stop uses the system default (ADR 0001: Stop needs no app code; the later nudges are already pre-scheduled).
- Authorization: request through `requestAuthorization()` when onboarding asks (ticket 28), read `authorizationState`, observe `authorizationUpdates`, report to the engine.
- Scheduling errors: map `AlarmManager.AlarmError.maximumLimitReached` to the engine's "alarm limit" event (ticket 14) and apply the plan it returns.
- Reconcile on launch using `alarms` / `alarmUpdates`: alarms no longer present have fired or been stopped.

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| `NSAlarmKitUsageDescription` is required, or scheduling fails | [key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription) | Docs answer |
| Denied authorization makes all schedule attempts fail; state can be read and observed | [requestAuthorization()](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization()), [authorizationState](https://developer.apple.com/documentation/alarmkit/alarmmanager/authorizationstate-swift.property), [authorizationUpdates](https://developer.apple.com/documentation/alarmkit/alarmmanager/authorizationupdates) | Docs answer |
| Alert shows title and app name; breaks through silent mode and Focus | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230) | Docs answer |
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
