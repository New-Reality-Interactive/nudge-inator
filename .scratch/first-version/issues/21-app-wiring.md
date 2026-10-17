Status: resolved

# App wiring: engine, store and adapters together

## What to build

The composition root. On launch, on foreground, on notification actions and on every user event, build the engine's inputs from the store, the clock and the adapters' permission states; feed the event; persist the resulting occurrence state; hand the plan to the notification and AlarmKit adapters. The "app opened" event runs reconciliation (ticket 07) and tops up the notification plan to the adapter's pending cap (ticket 18: the system keeps only the soonest 64). Use SwiftUI's `scenePhase` for foreground, and set the `UNUserNotificationCenterDelegate` at launch, before the first notification call, or custom actions are never delivered. Done from a notification action goes through here. Expose an observable app model the screens bind to.

## Acceptance criteria

- [x] Integration test (fake clock, in-memory store, fake adapters): create a Relentless reminder, advance time, see the plan applied to both fakes; send Done, see both fakes cleared and the store updated.
- [x] Relaunch test: tear down and rebuild the model from the store; occurrence state and plan are the same.
- [x] Permission change from an adapter re-plans.
- [x] Notification Done action and Open intent both end up as events through this one path.
- [x] No Apple framework types leak into `NudgeEngine`.

Blocked by: 17, 18, 19

## Comments

**Decisions settled with the user before coding (2026-10-16).** Apple's docs, read through apple-rag, confirm the following:
- From the `App`, `scenePhase` is the combined phase, and `.active` means "in the foreground and interactive". The `UIApplicationDelegateAdaptor` page says to prefer `ScenePhase` over delegate callbacks.
- The notification center's delegate must be set "before your app finishes launching".
- An `@Observable` model goes in `.environment(_:)` and is read with `@Environment(Type.self)`.
- `authorizationUpdates` "emits events when authorization to use alarms changes".
- `ModelConfiguration` has **no** file-protection option. Core Data's and the system's documented default is `completeUntilFirstUserAuthentication`, and SwiftData's isn't stated, so it became a device check (below).

The decisions:
1. **The app model** is `AppModel`, an `@Observable @MainActor final class` in `App/AppModel/`. It owns the engine, the store and both adapters.
   - **What the screens read:**
     - `engine` (`private(set)`): every read-out comes from the engine, for example `nudgingOccurrences()`, `comingUp()`, `closedInLast24Hours()`, `myDay(tagFilter:)`, `tagSummaries()`, `reach`, `lockedFields` and `isPaused`.
     - `launchState` (`.launching`, `.ready`, `.storeUnreadable(Error)`).
     - `saveError`.
     - `permissions`, which was added in review for Settings' status rows (ticket 30), since `reach` can't say not determined.
     - `route`.
   - **Events:**
     - `add(_:)`: the engine has no add, so this is `update(reminders: reminders + [new])`;
     - `edit(_:) throws(EditError)`, `markDone(_:)`, `pause(_:)`, `resume(_:) throws(ResumeError)`, `delete(_:)`;
     - `createTag(named:) -> Tag?`, `renameTag(_:to:)`, `deleteTag(_:)`;
     - `appOpened()`, `showReminder(_:)`.
   - It conforms to `NotificationAdapterEvents` and `AlarmAdapterEvents`.
   - **For tickets 26 and 28:** read-outs change as time passes with no engine change, so the screens need their own refresh (for example a `TimelineView`).
2. **One test seam:** `AppModel` built from a `FakeClock`, a store opener (`.inMemory`, or `.file` for relaunch), and the **real** `NotificationAdapter` and `AlarmAdapter` over `FakeNotificationCenter` and `FakeAlarmManager`. There is no fake `SchedulerAdapter`, because one would skip the Done, permission and limit paths.
3. **The combining adapter** is `CombinedSchedulerAdapter`, an `@MainActor struct` over `[any SchedulerAdapter]`. It is the one adapter the engine holds. The integration tests cover it.
4. **Launch.**
   - `AppDelegate` is wired in through `@UIApplicationDelegateAdaptor`. Its `didFinishLaunching` builds the model, which builds both adapters, so the notification delegate is set in time. It then starts `model.launch()`. `model` is a `lazy var`, so `didFinishLaunching` or the scene, whichever comes first, builds it. The `App` hands it to `.environment(_:)` for ticket 22.
   - `launch()` runs once, and every caller waits for that one run:
     1. open the store;
     2. load it;
     3. read both adapters' permissions;
     4. build the engine **with** them, so no throwaway plan reaches the adapters;
     5. call `update(tags:)`, then `update(histories:)`, then `update(reminders:)`.
   - **If the store won't open or `load()` throws,** the error is logged, `launchState` becomes `.storeUnreadable`, and the model does nothing more: no plan, no saves, and every event is ignored. A save replaces the whole file, and an empty plan would cancel the nudges already pending, which are better left to come. App opened tries again (added in review).
   - **The test host:** when `XCTestConfigurationFilePath` is set, the delegate builds no model. Otherwise its launch, and its re-plan on every foreground, would cancel the device checks' alarms, and its delegate would replace theirs (`theAppDoesntBuildItsModelWhenItHostsTests`, which passes on both simulators and the iPhone).
5. **Foreground:** `.onChange(of: scenePhase, initial: true)` calls `appOpened()` on `.active`. It waits for launch, re-reads permissions, then calls `update(reminders:)`, which refills the 64. Repeats are fine: both adapters change only what differs from the plan.
6. **Saving:**
   - Every event runs through one private `perform`, which saves `StoredData(engine.reminders, engine.tags, engine.histories)` straight after.
   - Delete and tag delete also run the store's own `delete` and `deleteTag` first, as ticket 17 asks.
   - An event the engine turns down throws its typed error, and nothing is saved.
   - **On a save error,** the engine's state stands, because its plan has already reached the adapters. The error goes to `saveError`, which is cleared by the next save that works, since every save writes everything, and is logged with `Logger`.
7. **Open (for ticket 20):** `showReminder(_:)` sets `route = .reminderDetails(id)` if the engine holds the reminder, and `.now` otherwise. Done on the details screen is `markDone(_:)`, through the same `perform` as the notification's Done. Ticket 20's intent calls `showReminder` and `stop(id:)`. It can reach the model through the delegate, for example by registering it with `AppDependencyManager`. That needs checking in 20.
8. **File protection:** no code change, and a device check (below).
9. **Device checks:** an opt-in `NudgeActionDeviceCheck` (`TEST_RUNNER_NUDGE_ACTION_CHECK=1`) runs ticket 18's pending checks 1, 2 and 5 through the real model.
   - It uses only Gentle reminders, which never ring, so no alarm is scheduled.
   - Each check gives up a minute after its nudge fires (shortened after the first runs, at the user's request).

**Tests.**
- `AppModelTests`: 26 tests.
- `NotificationAdapterTests`: one new parameterized test (4 cases).
- `StoreProtectionDeviceCheck` and `NudgeActionDeviceCheck` (3): phone only.
- **Totals:** 203 engine tests, and 104 app tests on iOS 26.1 and on 26.5.
- **What the acceptance tests assert:**
  - **Integration:** a Relentless reminder puts 3 Time Sensitive requests and 17 alarms in the fakes. At 9:12 the occurrence is at nudge 2 and 1 request is left. Done empties both fakes, and the store loads Done.
  - **Relaunch:** a new model from the same file, with new adapters over the same fakes, has the same reminders and occurrences (one at nudge 2, one Done). It has the same pending identifiers and alarm IDs, and made no new `add` or `schedule` calls.
  - **Permission change:** alarms denied in Settings turn all 20 nudges into Time Sensitive notifications and cancel every alarm. A refused request makes notifications read as denied. Allowed again, the alarms come back even when an older read finishes last.
  - **One path:**
    - A notification's Done, while running, before launch finishes, and on a background launch where it must be saved and applied before the handler returns;
    - Open's `showReminder`, then Done;

    all go through `perform`.
  - **No Apple types in the engine:** `scripts/test.sh`'s import check.
  - **Also covered:**
    - an unopenable store, an unreadable store and a retried store;
    - a turned-down save;
    - the refill of the 64;
    - the alarm limit;
    - delete, pause, resume, edit (accepted and locked), and the tag events;
    - App opened before launch.
- **Red first:**
  - every event method;
  - the alarm and notification events;
  - `showReminder`;
  - the unreadable store, `saveError` and the store opener;
  - App opened launching;
  - the test-host check;
  - in review, the awaited Done, overlapping reads (once the test was turned the right way), the retry and `permissions`;
  - on the device, the fire time's exact round trip.
- **Passed on their first run, kept as acceptance coverage:**
  - the relaunch test, the refill and the held Done, all mutation-checked;
  - the integration test's assertions after the first slice.
- **Mutation-checked:**
  - dropping `update(histories:)` fails the relaunch test;
  - setting `events` before launch (with the synchronous Done) failed the held-Done test, and also showed an early save would wipe the store;
  - dropping App opened's re-plan fails the refill and integration tests;
  - dropping the wait after a notification's Done fails the background-launch test.

**Code review (two axes, against main).**
- **Spec.** Fixed, each with a test:
  - **A notification's Done could be lost on a background launch.** Apple says the response handler's return tells the system "you are done processing the user's response". The handler returned once the Done was queued, before it was saved or applied. `NotificationAdapterEvents.markDone` is now `async`: the model waits for launch, records the Done, saves, and waits for both adapters, and the handler returns only then. The model now sets both adapters' `events` in `init`, so no report waits for someone to listen, and every report waits for launch (`aDoneFromANotificationIsSavedAndAppliedBeforeTheResponseHandlerReturns`).
  - **Permission reads could finish out of order.** App opened read them outside the chain the adapters' reports use, so an older read could put alarms back to allowed or denied. It now reads through the same chain, and each read waits for launch, so a change reported during launch isn't dropped. `FakeNotificationCenter` gained a gate (`holdsSettingsReads`, `releaseLatestSettingsRead()`) to finish reads latest first (`permissionReadsTakeEffectInTheOrderTheyStarted`). With alarms being denied, the test passed even without the fix, because the alarm adapter's refusal starts another read. Alarms being allowed again is the case nothing else corrects, and it failed first.
  - **An unreadable store was never retried.** Before the first unlock after a restart, data protection keeps the file shut, and a Done action can launch the app then. The model now takes a store opener, and App opened, which comes once the phone is unlocked, launches again (`appOpenedTriesAStoreThatCouldntBeOpenedAgain`).
  - **The screens for tickets 30 and 31 had no permission states:** added `permissions` (`thePermissionStatesFollowWhatTheAdaptersRead`). Asking for permission and Delete All Data stay with tickets 31 and 30, which were out of scope.
  - **The first `.active` wasn't guaranteed to send App opened:** now `initial: true`. Launch plans anyway.
  - **The action check could cancel the person's alarms.** Its `deinit` cancelled every alarm even when the "holds no alarms" guard had failed, and it removed notifications in a task that might not run. It now cancels alarms only once it has seen the app held none, and removes notifications synchronously by identifiers recorded when they were scheduled. (Raised on both axes.)
- **Standards: no other hard violations.** Fixed:
  - The device check repeated the delegate's wiring. It now calls `AppDelegate.makeModel(openStore:)`, so the real wiring is what runs on the phone.
  - The store's side-file list was written three times. `TemporaryStoreFile` now takes a directory and lists its `files`.
- **Kept, as judgement calls:**
  - Screens read through `model.engine`, as agreed, rather than copies of each read-out.
  - `CombinedSchedulerAdapter` is thin, but the engine takes one adapter.
  - `waitUntilApplied()` is on the production model: the notification Done now uses it, and so do the tests.

**Device run (2026-10-16), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Before:** Nudge-inator was not installed. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator.
- **All 104 app tests pass on the phone.**
  - The first run (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`) passed everything else, but `AlarmDeviceCheck` timed out waiting on the AlarmKit prompt. The phone's crash report shows it killed inside AlarmKit's authorization call. Brian allowed alarms.
  - The second run (permissions already granted) passed all 103 that ran then, `AlarmDeviceCheck` included. Its guard found no leftover alarms.
- **Store protection: passed.** A store saved in the App Group container, and its `-wal` and `-shm` files, are `NSURLFileProtectionCompleteUntilFirstUserAuthentication`. Done can be saved on a locked phone after the first unlock (check 1 below did so). Before the first unlock the store can't be read, which App opened's retry covers.
- **Found on the phone: two bugs in ticket 18's adapter, both fixed.**
  - **A crash: "Call must be made on main thread", inside UIKit,** when the notification delegate's work finished. The responder's async `didReceive` and `willPresent` returned off the main thread, and so did the completion handler Swift calls for them. They can't be made `@MainActor`, because the center's arguments aren't `Sendable`. The responder now implements the completion-handler forms and calls each handler from a main-actor task. Apple's docs don't say which thread the handler needs. The banner check (below) confirms the fix. There is no unit test: `UNNotification` and `UNNotificationResponse` can't be built in a test.
  - **Done was ignored.** `userInfo` carried the fire time as seconds since 1970. `Date` keeps seconds since 2001, and the conversion lost a fraction of a second. The fire time came back just before the due time, and `Engine.markDone(_:nudgeFiredAt:)` read it as a banner from an earlier occurrence. The unit tests used whole seconds, so they never saw this. It now carries `timeIntervalSinceReferenceDate`, which round-trips exactly (`aDeliveredNudgeCarriesItsFireTimeExactly`, 4 fractions, 2 red first). **For ticket 20:** carry the Open intent's fire time the same way.
- **Ticket 18's pending checks, through the real model (`NudgeActionDeviceCheck`):**
  - **Check 5, a nudge in the foreground: passed.** With the app in front, "Nudge-inator banner check" showed as a banner (`willPresent`).
  - **Check 1, Done from a banner: passed.** Brian pulled the banner down and chose Done. It reached the model and the store, 63 s into the run.
  - **Check 1, Done from the Lock Screen: passed.** The phone was locked. Brian long-pressed the nudge and chose Done without unlocking. It reached the model and the store.
    - On the first run the screen didn't wake when the nudge arrived. It showed on Brian's Mac first, which was showing the iPhone's notifications through iPhone Mirroring, and on the Lock Screen only once he woke the phone. apple-rag has nothing on that; it's a support.apple.com topic.
    - With the Mac's iPhone Mirroring off, the second run woke the locked screen with the nudge, and Done worked again.
  - **Check 2, a Time Sensitive nudge during a Focus: passed.** Do Not Disturb was on, Nudge-inator was not allowed, and the phone was locked. "Nudge-inator Time Sensitive check" (Gentle's nudge 5, "Nudge 5 of 20 · High", `.timeSensitive`) showed on the Lock Screen, and Brian chose Done on it. "Nudge-inator held check" (ordinary) was held and didn't show.
    - The first attempt showed neither. The signed build had the Time Sensitive entitlement and the app read its own Time Sensitive switch as on, but Do Not Disturb's Apps › **Time Sensitive Notifications** had never been turned on.
    - The test then marked the second run failed, because Done takes a nudge out of Notification Center. Done now counts as proof it arrived; that change wasn't re-run on the phone.
    - **For ticket 31:** a Focus doesn't let Time Sensitive nudges through unless that setting is on, so the banners or How It Nudges could say so.

**Device checks.** Record the iOS version when they are run.
1. **App opened on a cold launch** (`initial: true`): moved to ticket 26's criteria, since Now is what makes the plan visible.
2. **A Done before the first unlock after a restart:** the store is shut then. The Done is lost and the occurrence keeps nudging. **Decided (2026-10-17):** keep it, by queuing it in a file readable before the first unlock and merging it once protected data is available. That is ticket 32.
3. ~~**Ticket 18's check 4, interval triggers across a reboot**~~: done (2026-10-17, iPhone 15, iOS 27.0.1), see ticket 18.
4. ~~**The 24-Hour Time switch** (ticket 09)~~: done (2026-10-17, iPhone 15, iOS 27.0.1): the app's times follow it.
5. **Repeats across a time-zone change (noted while checking ticket 25):** after a time-zone change a repeat keeps its moment, not its wall-clock time. A Saturday 6:00 PM start in Central time showed "Every Saturday at 8:00 AM" in Tokyo, with the weekday still Saturday. **Decided (2026-10-17): keep that.** A repeat keeps its moment when the person changes time zone.

**Left alone:**
- the Open intent itself (20);
- every screen and the tab shell (22–31);
- onboarding and its permission prompts (31);
- Settings' Delete All Data button (30);
- any change to the engine's rules.
