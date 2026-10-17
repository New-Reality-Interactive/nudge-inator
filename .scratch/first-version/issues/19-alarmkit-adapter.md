Status: resolved

# AlarmKit adapter

## What to build

Extend the scheduler adapter to apply the plan's **alarm** items through `AlarmManager`:

- Alert-only `AlarmPresentation` with the reminder **title only**, the system Stop button, a custom secondary button **Open** (`AlarmButton`, `secondaryButtonBehavior: .custom`) and the app's tint (`AlarmAttributes(presentation:metadata:tintColor:)`). No countdown or paused presentation. The `AlarmMetadata` type comes from the shared module (ticket 01); an empty type is fine as long as it is `Codable`, `Hashable` and `Sendable`.
- Build the configuration with `AlarmManager.AlarmConfiguration.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` (iOS 26.0+, "behaves like a traditional alarm"), then `AlarmManager.shared.schedule(id:configuration:)`. Don't use the countdown-style `init`.
- **Minimum is iOS 26.1**, so use `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` (iOS 26.1+; the system provides the Stop button). Don't use the deprecated `init(title:stopButton:...)`, and don't copy Apple's sample's `stopButton:` argument. No `#available` branch is needed.
- A one-shot schedule per alarm item: `Alarm.Schedule.fixed(Date)` (not relative to the time zone). The alarm ID derives from occurrence and nudge number so a re-plan can cancel and replace.
- `secondaryIntent` is the Open intent from ticket 20, and its type is `(any LiveActivityIntent)?`. Stop uses the system default (ADR 0001: Stop needs no app code; the later nudges are already pre-scheduled).
- Remove not-yet-fired alarms with `cancel(id:)` ("deletes the alarm from the system"). `stop(id:)` is for a ringing alarm and deletes a one-shot.
- Authorization: request through `requestAuthorization()` when onboarding asks (ticket 31), read `authorizationState`, observe `authorizationUpdates`, report to the engine. If the app never asks, AlarmKit asks by itself on the first `schedule` call, so make sure onboarding has asked first (or the prompt appears mid-plan).
- Scheduling errors: map `AlarmManager.AlarmError.maximumLimitReached` to the engine's "alarm limit" event (ticket 15) and apply the plan it returns.
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

- [x] Unit tests over a fake `AlarmManager` protocol wrapper: a plan with 4 alarm items yields 4 schedule calls with title-only presentation (assert the title and that no notes/tags/count text is passed), unique IDs, correct fire dates.
- [x] Replacing a plan cancels alarms not in the new plan and schedules the new ones.
- [x] A simulated `maximumLimitReached` is reported to the engine and the returned plan is applied.
- [x] Denied authorization is reported to the engine as "alarms denied" and no schedule call is made.
- [x] Device (human): a scheduled alarm rings through silent mode and a Focus, shows title only, Stop silences it, and the next planned alarm still rings on time.

Blocked by: 02, 15, 18

## Comments

**The ticket's wording is out of date in four places, changed by the decisions below:** IDs no longer derive from the occurrence and nudge number, nothing is persisted in the store, `alarmUpdates` isn't observed, and the Open button waits for ticket 20's intent.

**Decisions settled with the user before coding (2026-10-16).**
- **The fake manager.** `AlarmManaging` is a `@MainActor` protocol over the calls the adapter makes:
  - `schedule(id:schedule:attributes:secondaryIntent:)`
  - `cancel(id:)`
  - `alarms()`, which returns `AlarmSnapshot`s (ID and state). `Alarm` has no public init, so a fake can't make one.
  - `authorizationState`
  - `requestAuthorization()`
  - `authorizationUpdates()`

  It takes the schedule and the `AlarmAttributes` rather than an `AlarmConfiguration`, which has no readable properties (checked in the iOS 26.5 SDK's `AlarmKit.swiftinterface`). `SystemAlarmManager` builds `.alarm(schedule:attributes:stopIntent: nil, secondaryIntent:sound:)` and calls `AlarmManager.shared` on each call: `AlarmManager` isn't `Sendable`, so a stored one can't be sent into its own async methods under Swift 6. `FakeAlarmManager` keeps each alarm's real schedule and attributes, so tests read back the title, buttons, tint and fire date. The `.alarm(...)` call is the one line no fake covers; `AlarmDeviceCheck` covers it on the iPhone.
- **Alarm IDs** are name-based UUIDs (RFC 9562 version 5, SHA-1) of `nudge.<reminder UUID>.<fire time ms>.<title>`, under a fixed namespace.
  - The fire time names the nudge, not the nudge number, because a plan can hold two ladders for one reminder (ticket 15).
  - The title is in the name because AlarmKit can't say what a scheduled alarm shows. A title Edit gives a new ID, so the diff cancels the old alarm and schedules the new one.
  - The same nudge always gets the same ID, so the diff is safe after a relaunch.
  - A test pins one ID to a value worked out independently with Python's `uuid.uuid5`.
  - A `maximumLimitReached` needs no lookup: the adapter holds the plan item when `schedule` throws, and reports its reminder ID and fire time.
- **Two adapters.** `AlarmAdapter` is separate from `NotificationAdapter`, built the same way:
  - a `@MainActor final class` with an `@MainActor SchedulerAdapter` conformance;
  - a task chained per apply, and `waitUntilApplied()`;
  - an `AlarmAdapterEvents` protocol back to the app model.
- **Reconciling.** Each apply diffs against `alarms()`.
  - It keeps every alarm item in the plan, passed ones too. It cancels the app's alarms that the plan doesn't hold and that are still `scheduled`. It never cancels a ringing one: Stop and Open end a ring.
  - It schedules the plan's alarms whose fire time is after now (ticket 13) and that are missing. It goes soonest first, ties by reminder ID as in the engine's cap, and schedules a repeated nudge once.
  - **Nothing is persisted.** Apple's "persist your alarms in your own store and compare" exists to learn which one-shots fired. The engine already knows that from the clock, and Stop needs no app code (ADR 0001). For the same reason **`alarmUpdates` isn't wrapped**: nothing would use it, and ticket 02 found every cancel re-delivers the whole list.
  - Every alarm the app holds counts as the adapter's. If Send a Test Nudge (ticket 30) ever uses an alarm, it should go through this adapter.
- **Authorization.**
  - There is no gate on not determined: it plans as allowed (ticket 14), and onboarding (ticket 31) asks first, or AlarmKit prompts by itself mid-plan.
  - `permissions(updating:) -> PermissionStates` is synchronous and sets only `alarms`: `authorized` → `.allowed`, `denied` → `.denied`, `notDetermined` → `.notDetermined`.
  - `requestAuthorization() -> Bool` is for ticket 31.
  - `init` observes `authorizationUpdates` (holding the adapter weakly) and calls `events.alarmAuthorizationChanged()`.
  - While denied, the adapter still cancels stale alarms, schedules none, and reports `AlarmAdapterError.alarmsNotAllowed` once if the plan holds alarms to schedule.
- **Errors.**
  - Each `maximumLimitReached` → `events.markAlarmLimitReached(_:firingAt:)`.
  - Any other refusal, from `schedule` or `cancel`, → one `schedulingFailed(_:)` per plan.
  - If `alarms()` throws, the adapter reports it and changes nothing, since it has nothing to diff against.
- **The Open button until ticket 20.** The adapter takes `openIntent: (SchedulePlan.Item) -> (any LiveActivityIntent)?`, nil by default. With nil, the alert has no secondary button: the title, the tint and the system Stop. With an intent, it shows an Open `AlarmButton` (`arrow.up.forward.app`, black text, DESIGN.md's `on-accent-dark`) with `.custom` behaviour. A button with no intent would do nothing, and ticket 02 showed that Open without `stop(id:)` can leave a locked phone ringing.
- **Metadata and tint.**
  - `NudgeAlarmMetadata` is an empty `AlarmMetadata` in NudgeShared.
  - The tint is DESIGN.md's `alarm-tint`, #07DDE6, pinned and written in the adapter, because the app has no asset catalog yet. It should move to a colour set when one arrives (ticket 22).
  - The alert's title is passed interpolated, so it is never looked up as a localization key.

**Found while building.**
- **A superseded plan.** Each limit report makes the engine re-plan and hand the adapter a new plan. Plans that had queued behind the current one then tried every overflowing alarm again: 15 overflow reports became 120. So only the latest plan is applied. A plan replaced while it waits does nothing. One replaced part-way through stops scheduling (that half came from review). With a limit of 2 and 17 alarms, the adapter makes 17 schedule calls and 15 reports.
- **`waitUntilApplied()` loops** until no newer apply has arrived, so it also waits for the plans the engine hands back after a report.

**Tests.** `AlarmAdapterTests` (27 tests, 32 cases) in NudgeInatorTests, over `FakeAlarmManager`, `FakeAlarmEvents`, `FakeClock`, a `RecordingScheduler` between engine and adapter, and a test `LiveActivityIntent`. Four of them run through a real `Engine`: the limit and the plan the engine hands back, denied, privacy, and Done. `only` moved to Fakes.swift so both adapter suites share it.
- **Red first:**
  - four alarms giving four schedules;
  - the tint;
  - the Open button with an intent;
  - replacing a plan;
  - passed fire times;
  - a ringing alarm kept;
  - soonest first;
  - the limit report and the returned plan (twice, the second time for the superseded-plan bug);
  - the permission table;
  - denied with a stale plan;
  - other errors once per plan;
  - unreadable alarms;
  - requesting authorization;
  - an authorization change;
  - in review: an alarm at its fire time not cancelled, a plan replaced part-way through, a repeated nudge, and a refused cancel.
- **Passed on their first run, kept as acceptance coverage:**
  - no Open button without an intent;
  - after a relaunch nothing changes;
  - a new title replaces the alarm;
  - the ID pinned to Python's value;
  - notification items left alone;
  - denied through the engine;
  - privacy through the engine (17 alarms, every attributes field checked: the title alone, no button, no countdown or paused presentation, empty metadata);
  - Done cancelling every alarm.
- **Written with its fix, then mutation-checked:** a plan replaced before its turn.
- **Mutation-checked:**
  - the title left out of the ID fails the title and pinned-ID tests;
  - dropping the superseded-plan guard fails the limit and superseded tests;
  - random IDs fail four tests;
  - dropping the delivery-kind filter fails three;
  - not determined as allowed fails the permission table.

**Code review (two axes, against main).**
- **Spec.** Fixed, each with a red test:
  - **An alarm at its fire time could be cancelled** while it still read `scheduled`, so the nudge never rang. The plan's passed nudges now count as kept (`anAlarmAtItsFireTimeThatHasntRungYetIsNotCancelled`).
  - **A replaced plan kept scheduling** after a newer one arrived mid-loop. The loop now stops (`aPlanReplacedPartWayThroughStopsScheduling`).
  - **The same nudge twice** made two schedule calls under one ID (`theSameNudgeTwiceInAPlanIsScheduledOnce`).
  - **Refused cancels were swallowed.** They are now reported (`aRefusedCancelIsReported`).
  - **The device check could change a permission it can't undo.** It now shows the AlarmKit prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`). Otherwise it fails with a message.
  - **Recorded, not changed: Done while an alarm rings.** The adapter never cancels a ringing alarm, so Done in the app leaves the ring to Stop, or to ticket 20's Open, which calls `stop(id:)`. Done from the Open destination comes after Open has already stopped it.
- **Standards: no hard violations.** Fixed:
  - `ScheduledAlarm` → `AlarmSnapshot`, since it also holds ringing alarms;
  - `planCount` → `latestPlanNumber`;
  - the fake's `answer` → `promptAnswer`;
  - a `LimitReport` type instead of reusing `DeliveredNudge`;
  - `SystemClock` moved to Fakes.swift;
  - IDs worked out once per item;
  - sorted imports;
  - the tint's comment points to ticket 22.
- **Kept, as judgement calls:**
  - The apply chain and the one-report-per-plan pattern are copied from `NotificationAdapter`. Extract them if a third adapter appears.
  - The `(reminderID, fireTime)` pair mirrors the engine's API.
  - The `openIntent` and `requestAuthorization()` hooks are for tickets 20 and 31, and are tested.

**Device run (2026-10-16), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Found: uninstalling doesn't remove an app's AlarmKit alarms on a device.**
  - The first run's `AlarmDeviceCheck` stopped at its guard: on a fresh install, the app held **4,001 alarms**. 4,000 were `scheduled` `.fixed` alarms, dated 2026-10-15 to 2027-08-14. One had been `alerting` since 2026-10-15 01:55 UTC.
  - These were ticket 02's spike alarms from check 7, under the same bundle ID, and they had survived two uninstalls. Ticket 02's "uninstalling the app removed all its alarms" was seen in the simulator only.
  - With the user's approval, Brian cleared them with the spike branch's own "Stop or cancel all" button ("0 failures"). The spike build was then uninstalled.
  - AGENTS.md now says this, and says how device tests handle it.
- **Before:** Nudge-inator was not installed.
- **After:** it was uninstalled. `xcrun devicectl device info apps` shows the same empty list as before.
- **Result:** with `TEST_RUNNER_NUDGE_FRESH_INSTALL=1`, all 73 app tests pass on the phone.
  - `AlarmDeviceCheck` passed: through the real `AlarmManager`, a plan's two alarms a day out appeared in `alarms` as `scheduled`, and an empty plan then cancelled both.
  - `PendingLimitDeviceCheck` again: 64 of 70.
- **The ring check (`AlarmRingDeviceCheck`, opt-in with `TEST_RUNNER_NUDGE_RING_CHECK=1`): passed.** The phone was in silent mode, **unlocked, and with no Focus**.
  - Two alarms one minute apart.
  - The first rang out loud, showing only "Nudge-inator ring check", 0.06 s after its time. Brian stopped it with Stop.
  - The second still rang, 0.23 s after its time.
  - Both were gone afterwards.
- **The ring check again, locked and in a Focus: passed.** The phone was in silent mode with a one-hour Focus on, and locked before the first alarm. The app was installed fresh with `TEST_RUNNER_NUDGE_FRESH_INSTALL=1` and uninstalled afterwards.
  - Both alarms rang out loud as full-screen alerts, each showing only "Nudge-inator ring check" with the system slide to stop. There was no Open button, as expected until ticket 20.
  - The first rang 0.14 s after its time. Brian slid to stop it, and the phone stayed locked.
  - The second still rang, 0.21 s after its time. Slide to stop left the phone locked too.
  - Both were gone afterwards, so the acceptance criterion is ticked.
- **The ring check in Sleep Focus, locked: passed.** The spec says alarms ring through "every Focus, Sleep Focus included", and it's the Focus most likely on when a nudge rings after midnight.
  - Both alarms rang out loud over the Sleep lock screen, showing only the title with slide to stop. The first rang 0.08 s after its time and the second 0.22 s after its. The phone stayed locked after each stop, and both alarms were gone afterwards.
  - **For ticket 31: under Sleep Focus the AlarmKit prompt didn't show.** On a fresh install with Sleep on, `requestAuthorization()` showed nothing on the phone, which displayed only the app. The first attempt returned with the state still `notDetermined` after about 10 s. The prompt did show with no Focus and with a one-hour Focus. Onboarding should expect it may not appear during Sleep, and show the denied/not-asked state rather than wait. A second attempt somehow ended up authorized without Brian seeing a prompt, so how the prompt behaves under Sleep is still unclear. Recheck it when 31 is built.
  - **Uninstalling resets the alarm permission:** a fresh install with no prompt read `notDetermined`. Only the alarms survive an uninstall (see above).
  - To get round the prompt, the run granted the permission with Sleep off (`AlarmDeviceCheck`, two alarms a day out, cancelled), kept the app installed, then turned Sleep on for the ring. The app was uninstalled afterwards.

**Device checks.** Record the iOS version when they are run.
1. ~~The acceptance criterion's Focus part, on a locked phone~~: done, see above.
2. **Open:** moved to ticket 20, whose criteria include it.
3. **The alarm limit and slot reuse: answered as not measurable.** Ticket 02 A scheduled 4,000 alarms without a `maximumLimitReached`, so no limit was reached and slot reuse can't be observed. The fallback stays as the safety net.
4. ~~Sleep Focus~~: done, see above.
5. **The AlarmKit prompt under Sleep Focus:** moved to ticket 31's criteria. It didn't show on the first attempt; recheck it with onboarding.

**For ticket 20.**
- Pass the intent in with `AlarmAdapter(manager:clock:openIntent:)`, for example `{ OpenIntent(reminderID: $0.reminderID, fireTime: $0.fireTime) }`.
- The alarm ID is a one-way hash, so the intent can't recover the nudge from it. Carry the reminder ID and fire time, and the alarm ID itself for `stop(id:)` (`AlarmAdapter.alarmID(for:)`, which needs the title too).
- Ticket 02 B: the intent must call `stop(id:)`.

**For ticket 21.**
- **At launch:** build `AlarmAdapter(manager: SystemAlarmManager(), clock:)` and set `adapter.events` to the app model.
- **At launch and on every foreground:** `engine.update(permissions: await notifications.permissions(updating: alarms.permissions(updating: states)))`.
- **The combining adapter** hands each plan to both adapters, and must be `@MainActor`.
- **On `markAlarmLimitReached`:** call `engine.markAlarmLimitReached(_:firingAt:)`. The plan it returns reaches the adapter through the combiner.
- **On `schedulingFailed` and `alarmAuthorizationChanged`:** read both adapters' permissions again and call `engine.update(permissions:)`.
- **Leftover alarms:** the first apply cancels every scheduled alarm the app holds that the plan doesn't. After the spike that was 4,000. The phone is clear now.

**Left alone:**
- the Open intent and `stop(id:)` (20);
- wiring, the combining adapter and the foreground refill (21);
- the onboarding prompt (31);
- every UI;
- the device checks above.
