Status: resolved

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

- [x] Unit test: the intent carries the alarm's and the reminder's IDs, and its `perform()`, through the app's opener, stops that alarm and posts a "show reminder" route to that reminder's details; an unknown reminder ID shows "Reminder Not Found", and IDs that aren't UUIDs don't crash. (Reworded 2026-10-18; see Comments.)
- [x] The app opens on the reminder's details with the occurrence's Done action available.
- [x] The intent conforms to `LiveActivityIntent`, declares `supportedModes` (not `openAppWhenRun`), and builds without warnings about either.
- [x] The intent type lives in the shared module and both the app and the extension build with it.
- [x] Behaviour matches ticket 02's recorded answers B and C (cite them in the code comment).
- [x] Device (human): tapping Open from the Lock Screen and from the Dynamic Island/banner lands on the reminder, and the ring state matches the spike.

Blocked by: 02, 19, 27

## Comments

**Resolved 2026-10-18.** Every criterion is ticked. Criterion 1 is reworded as agreed below; the rest stand as written.

**Agreed before coding (the user, 2026-10-18).**
- **Unknown ID.** Criterion 1 said an unknown ID routes to Now. Ticket 27's ruling is that `AppModel.showReminder` pushes the details for any ID, and the details say "Reminder Not Found". The user confirmed the criterion is reworded to match.
- **Alarm ID to reminder.** `AlarmAdapter.alarmID(for:)` is a one-way hash of the reminder, fire time and title, so it can't be turned back into a reminder. The adapter builds one intent per nudge, so the intent carries both: the alarm ID for `stop(id:)` and the reminder ID for the route. The app resolves them in its own process (ticket 02 F). No pure mapping exists to put in the engine.
- **`AppIntentsPackage`.** Not declared. WWDC25-244 says to use it "when referencing code not compiled into a static library", and NudgeShared is static. The device build put `OpenReminderIntent` in both `NudgeInator.app` and `NudgeWidgets.appex` `Metadata.appintents` without it, and the device checks below passed.
- **Order.** Stop first, then read the store, then route. The stop needs nothing from the store. A route set before the store is read would show "Reminder Not Found" until it loads. A route set before the shell exists is followed by `RootView`'s `onChange(initial: true)` (ticket 27).
- **Device checks.** Three, one at a time. Before first unlock was skipped: it needs a restart, spike C recorded it, and ticket 32 owns that state. Unlocked, an alert-only alarm shows as a banner, not in the Dynamic Island (spike E), so check (a) covers "Dynamic Island/banner".

**Design.**
- `OpenReminderIntent` (NudgeShared): `LiveActivityIntent`, `supportedModes = .foreground`, `isDiscoverable = false` (kept from Siri, Spotlight and Shortcuts, where an alarm's IDs mean nothing), with `alarmID` and `reminderID` as `String` parameters, as in the spike. Its doc comment cites ticket 02 B, C and F.
- It reaches the app through `@Dependency var opener: AlarmOpener`, a `Sendable` struct around an async closure. The model builds its own (`AppModel.alarmOpener`, which calls `open`), and `AppDelegate.application(_:didFinishLaunchingWithOptions:)` registers it with `AppDependencyManager` right after building the model. Apple: a dependency means the system "can't run the app intent until the specified object is available".
- `AppModel.open(alarmID:reminderID:)` calls `AlarmAdapter.stop(_:)` (new, through `AlarmManaging.stop(id:)`). It then reads the store, trying again if a Done before first unlock left it unread, and calls `showReminder`. A `stop` that throws is logged, and the route still follows.
- `AlarmAdapter`'s `openIntent` closure now takes the alarm ID as well as the plan item. `AppDelegate.makeModel` passes `OpenReminderIntent`, so every alarm now has the Open button (ticket 19's adapter adds it only when there is an intent).
- The intent's title and parameter titles are not in a String Catalog: the intent isn't discoverable, and the alert's button text is the app's own `AlarmButton` string, which is in the catalog.

**Found while building.**
- `@Dependency` resolves only inside the system's own run of an intent. Calling `perform()` directly traps ("Dependency values can only be accessed inside of the intent perform flow … unless the value of the dependency is manually set"). App Intents Testing would run it properly but needs iOS 27 (see AGENTS.md › Toolchain). So `opener` is internal, and `OpenReminderIntentTests` sets it by hand through `@testable import NudgeShared`. The system's resolution of the registered opener is covered by the device checks.
- The extracted metadata records `supportedModes = 2` and `isDiscoverable = false` for both bundles. It also shows `openAppWhenRun = true`, which the code doesn't set; the build writes it, apparently from `.foreground`. The build has no warning about either; the only warning is `MyDayTab`'s existing preview one.

**Tests.** `scripts/test.sh` passes: 231 engine tests on macOS, and 200 app tests on iOS 26.1 and 26.5 (iPhone 17). Seams:
- `AppModelTests`:
  - The intent's `perform()`, through `model.alarmOpener`, stops the alarm that rang and routes to its details.
  - `open` stops that alarm and routes, and Done then closes the occurrence.
  - An unknown reminder routes to the details, which say "Reminder Not Found".
  - A `stop` that throws still routes.
  - A cold launch stops the alarm before the store is read, and routes after.
  - An unread store is tried again.
- `AlarmAdapterTests`: the intent gets that alarm's ID.
- `OpenReminderIntentTests`: `perform()` hands both IDs to the opener; IDs that aren't UUIDs call nothing and don't crash; the intent is a `LiveActivityIntent`, `.foreground`, and not discoverable.

All 200 app tests passed on the iPhone 15 (iOS 27.0.1), re-run on 2026-10-18 after both reviews. This includes the four the reviews added and the device checks that need no person (`AlarmDeviceCheck`, `PendingLimitDeviceCheck`, `StoreProtectionDeviceCheck`). The app wasn't installed, so the run set `TEST_RUNNER_NUDGE_FRESH_INSTALL=1`; Brian allowed the alarm and notification prompts, and the app was uninstalled afterwards. An earlier run, before the reviews, passed all 196.

**Device checks** (iPhone 15, iOS 27.0.1, Debug build). The app wasn't installed at the start and was uninstalled afterwards. One Relentless reminder, due 11:02, rang its first alarm at 11:19:30 and then every 2 minutes; Done closed it after the checks.
1. (a) Unlocked, app in the background: Open on the banner brought the app forward on the reminder's details with the Nudging Now card and Done; the ring stopped by itself; the banner went away. Pass.
2. (b) Locked after first unlock: Open on the full-screen alert asked for Face ID or the passcode; the ring continued until authentication, then stopped by itself; the app opened on the details with Done. Pass. This matches spike C.
3. (c) App swiped away, locked: Open launched the app straight onto the details, with no "Reminder Not Found" flash; the ring stopped. Pass.
4. The app tests on the phone, run after Done: 196 passed. `AlarmDeviceCheck` requires the app to hold no alarms, so Done left none behind.

**Review.** Standards found no breach of AGENTS.md; Spec found nothing missing. Fixed:
- An Open now tries the store again if a Done before first unlock left it unread, as App opened does (`launchTryingAnUnreadStoreAgain`, tested).
- A test pins that a `stop` that throws still routes.
- `perform()` logs IDs that won't parse instead of returning silently.
- The opener is registered in `didFinishLaunching`, not in `makeModel`, so the factory the device checks call registers nothing global. It still happens right after the model is built, where it was during the device checks.

**Second review (2026-10-18).** Two findings from an independent review of the committed branch:
- **Missing `AppIntentsPackage` signposts (High): not changed.** Device checks (a)–(c) above ran Open without any signposts, unlocked, locked and from a cold launch. The ring stops and the route follows only inside `perform()`, so the system found and ran the intent each time. WWDC25-244: "use App Intents Package when referencing code not compiled into a static library", and NudgeShared is static.
- **Criterion 1 not met as written (Medium): partly agreed.** The wording had already been changed for the unknown ID (ticket 27's ruling, kept). It is now sharpened to say what the tests guarantee. Two gaps were real and are fixed:
  - Nothing tested `perform()` through the app's own opener. The closure moved from `didFinishLaunching` to `AppModel.alarmOpener`, and a test now runs intent → opener → stop and route.
  - IDs that aren't UUIDs had no test. They still only log: there is no alarm to stop and no reminder to show, and the app stays on what it was showing.
- The device checks ran before `alarmOpener` moved. The registered opener makes the same call (`model.open`) at the same moment, right after the model is built in `didFinishLaunching`.

**Judgement calls kept.**
- `(alarmID, reminderID)` travel together through `AlarmOpener` and `AppModel.open` (a possible data clump). Two sites didn't seem to earn a type.
- `AlarmAdapter.stop(_:)` only delegates, but it is the seam `AppModel` holds.
- `AppModel.open` takes a `UUID`, not `Alarm.ID`: the model doesn't import AlarmKit.
- **Watch item:** `stop(id:)` is a synchronous call to the alarm service on the main actor, right after the person authenticates. That is the moment ticket 22's `authorizationState` read froze the app. Apple's docs don't say `stop` can block, and none of the three device checks stalled, but it hasn't been measured.

**Left alone.** My Day (28), tag lists (29), Settings (30), onboarding, permission prompts and banners (31), a Done before first unlock (32), iPad. The details screen and the Edit form are unchanged.
