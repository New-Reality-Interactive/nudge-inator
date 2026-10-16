Status: resolved

# Notification adapter over UNUserNotificationCenter

## What to build

A thin adapter in the app target that applies the engine's schedule plan for **notification** items (ordinary and Time Sensitive) through `UNUserNotificationCenter`, and reports permission states and scheduling errors back to the engine. It conforms to the scheduler-adapter protocol the engine's fake already implements.

- Content: title, body "Nudge N of 20 · Urgency". No notes, no tags.
- Ordinary items use the default interruption level; Time Sensitive items use `.timeSensitive`.
- One notification category with a single **Done** action. Handling Done sends the engine a Done event for that occurrence (via the wiring in ticket 21; here, a protocol callback).
- Applying a plan replaces what this adapter has pending (identifiers derived from occurrence and nudge number), and cancels items no longer in the plan.
- Keep at most **64** notification requests pending across all reminders, soonest first (a named constant, easy to change after the device check below). Apple documents that the system keeps "the soonest-firing 64 notifications ... and discards the rest", though only on the deprecated `UILocalNotification` page; the `UNUserNotificationCenter` pages give no number. Without a cap, a few Relentless reminders (20 nudges each) would be dropped silently. Items past the cap are scheduled later, when the app opens or the plan is next applied (ticket 21 refills on foreground).
- Request authorization with `[.alert, .sound]`. Do **not** pass `.timeSensitive`: `UNAuthorizationOptions.timeSensitive` is deprecated. Time Sensitive is enabled by the capability (entitlement) plus `interruptionLevel`, so it is not part of the permission prompt (see ticket 01's deferred entitlements).
- Register the category with `UNUserNotificationCenter.setNotificationCategories(_:)` and set a `UNUserNotificationCenterDelegate` at launch, before anything else touches the center. Apple: "If you do not implement [`userNotificationCenter(_:didReceive:)`], your app never responds to custom actions." Set each request's `content.categoryIdentifier` to the category.
- The **Done** action uses **empty options**: no `.foreground` (it "brings the app to the foreground, asking the user to unlock the device") and no `.authenticationRequired` (it "can be performed only on an unlocked device"), so Done can run from a locked phone. Whether it really runs without unlocking is still a device check below. The system shows at most two actions when space is limited, so keep one.
- The first time a Time Sensitive notification arrives, the system explains it and lets the person turn Time Sensitive off (HIG, Managing notifications). Re-read `timeSensitiveSetting` on every foreground and treat it as an input, not a constant.
- Reports: authorization status, Time Sensitive setting, and errors.

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| Time Sensitive items break through Focus when allowed; user can turn them off; needs the Time Sensitive capability | [timeSensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive), [WWDC21-10091](https://developer.apple.com/videos/play/wwdc2021/10091) (set `interruptionLevel` on the content; enable the capability in Xcode) | Docs answer |
| Reading whether Time Sensitive is on | [timeSensitiveSetting](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/timesensitivesetting) | Docs answer |
| Scheduling while not authorized fails with `notificationsNotAllowed` | [UNError.Code.notificationsNotAllowed](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed) | Docs answer |
| Authorization states | [UNAuthorizationStatus](https://developer.apple.com/documentation/usernotifications/unauthorizationstatus), [UNNotificationSettings](https://developer.apple.com/documentation/usernotifications/unnotificationsettings) | Docs answer |
| How many local notifications can be pending at once | "The system keeps the soonest-firing 64 notifications ... and discards the rest" ([UILocalNotification](https://developer.apple.com/documentation/uikit/uilocalnotification), deprecated; the `UNUserNotificationCenter` pages give no number) | **Device check** (schedule until requests stop appearing in `pendingNotificationRequests()`; confirm 64 and that the soonest are kept; record it, feeds ticket 15's chain length) |
| Done action does not need to open the app and works on a locked phone | `foreground` and `authenticationRequired` options are documented ([foreground](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/foreground), [authenticationRequired](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/authenticationrequired)); an action with neither is implied to run without unlocking but the docs don't say so | **Device check** |
| Notification actions are delivered through the delegate | [userNotificationCenter(_:didReceive:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:didreceive:withcompletionhandler:)) | Docs answer |

## Acceptance criteria

- [x] Unit tests with a fake notification-center protocol: a plan with 3 notification items results in 3 requests with the expected identifiers, fire dates, body text and interruption levels.
- [x] Applying a smaller plan removes the stale requests; applying an empty plan removes all of this adapter's requests.
- [x] No request content contains notes or tag text (assert on content).
- [x] Authorization and Time Sensitive status are read and delivered to the engine as permission inputs.
- [x] Never more than 64 requests are pending after applying any plan (fake center, several reminders with full ladders); the soonest 64 are kept.
- [x] Authorization is requested with `.alert` and `.sound` only.
- [x] The Done action has empty options and the category is attached to every request.
- [ ] Device (human, or noted as pending): Done from a banner and from the Lock Screen reaches the engine; Time Sensitive nudge shows during a Focus that allows Time Sensitive; pending limit recorded.

Blocked by: 14, 17

## Comments

**The setup notes are out of date.** The Time Sensitive entitlement (`com.apple.developer.usernotifications.time-sensitive`) is already in `project.yml` for the app target, from ticket 01. The mentions of "ticket 01's deferred entitlements" above no longer apply.

**Decisions settled with the user before coding (2026-10-16).**
- **The fake center.** `UserNotificationCenter` is a `@MainActor` protocol over the center calls the adapter makes:
  - `add`
  - `pendingNotificationRequests`
  - `removePendingNotificationRequests(withIdentifiers:)`
  - `setNotificationCategories`
  - `setDelegate`
  - `requestAuthorization(options:)`
  - `notificationSettings()`, which returns a `NotificationSettingsSnapshot` holding `authorizationStatus` and `timeSensitiveSetting`. Apple: "You don't create instances of [`UNNotificationSettings`] directly."

  `SystemNotificationCenter` wraps `.current()`. `FakeNotificationCenter` keeps real `UNNotificationRequest`s, so the tests assert on real content, triggers and interruption levels. It replaces a request added under the same identifier and holds the delegate weakly, as the real center does.
- **Async calls and Swift 6.** `NotificationAdapter` is a `@MainActor final class` with a main-actor conformance, `@MainActor SchedulerAdapter`. The engine stays free of actor isolation. The engine holding the adapter has to live on the main actor, as ticket 21's app model does. `apply(_:)` stays synchronous and starts a `Task` that awaits the previous apply's task, so plans reach the center in order. Tests await `waitUntilApplied()`. A prototype type-checked under Swift 6 against the 26.5 SDK before any code was written.
- **Request identifiers** are `nudge.<reminder UUID>.<fire time in ms since 1970>`.
  - The fire time names the nudge, not the nudge number, because a plan can hold two ladders for one reminder (ticket 15).
  - The `nudge.` prefix means an apply never removes a request it didn't make, such as Send a Test Nudge (30).
  - Each request's `userInfo` holds `reminderID` and `fireTime`. Done reads them through `NotificationAdapter.deliveredNudge(in:)` rather than parsing the identifier.
- **Permission mapping:** `permissions(updating:) async -> PermissionStates` sets notifications and Time Sensitive and leaves alarms for ticket 19.
  - `denied` → notifications `.denied`.
  - `notDetermined`, `authorized`, `provisional` and `ephemeral` → `.allowed`. `NotificationPermission` has no not-determined case, so the engine plans not determined as allowed.
  - `timeSensitiveSetting` `.enabled` → `.on`; `.disabled` and `.notSupported` → `.off`.
  - While the status is `notDetermined`, Time Sensitive reads `.on`, matching the engine's fresh-install default, so High nudges don't plan as ordinary before the prompt.
- **Replacing what's pending is a diff against `pendingNotificationRequests()`.** No in-memory record is kept, so it is safe after a relaunch.
  - **What it wants:**
    - only `.notification` and `.timeSensitiveNotification` items (alarms are 19's);
    - only fire times after now (ticket 13), with the clock read once per apply;
    - sorted soonest first, ties by reminder ID as in the engine's alarm cap;
    - the first 64 (`pendingLimit`) less any other pending requests (found in review).
  - It removes the adapter's requests that aren't wanted.
  - It adds a wanted request if it's missing, or if its title, body or interruption level changed (a title Edit, a permission change). Re-applying an unchanged plan adds nothing.
- **Content.** The title, and `item.body` ("Nudge N of 20 · Urgency"). Ordinary nudges are `.active` and Time Sensitive ones `.timeSensitive`. Every request carries the `nudge` category. The trigger is `UNTimeIntervalNotificationTrigger(fireTime − now)`, a fixed instant like the engine's `Date`s. A calendar trigger reads its components as wall-clock time, and the docs don't say whether it honours `DateComponents.timeZone`.
- **Launch setup is in `init`,** so ticket 21 can't build an adapter without it.
  - `init` registers one category, `nudge`, with a single `done` action titled "Done" with empty options.
  - It sets the delegate: a `Sendable` `NotificationResponder` with a `weak let` back to the adapter, which keeps it, since the center holds it weakly.
  - `didReceive` hands the action identifier and the `DeliveredNudge` to `handleResponse(actionIdentifier:nudge:)`. `userInfo` isn't `Sendable`, so it is read before the hop to the main actor.
  - `willPresent` returns `[.banner, .list, .sound]`. Without it, a nudge that fires while the app is open isn't shown.
- **Reports go through the `NotificationAdapterEvents` protocol:** `markDone(_:nudgeFiredAt:)`, and `schedulingFailed(_:)`, sent once per apply with the first error.
- **Authorization:** `requestAuthorization()` asks for `[.alert, .sound]` only.

**Found while building.** `UNTimeIntervalNotificationTrigger` raises `NSInternalInconsistencyException` ("time interval must be greater than 0") for an interval of zero or less. A nudge firing exactly now crashed the test host. Passed fire times are filtered out with the same clock reading the triggers use.

**Tests.** `NotificationAdapterTests` (20 tests, 31 cases) in NudgeInatorTests, over `FakeNotificationCenter`, `FakeNotificationEvents` and `FakeClock`. There are also 2 engine tests (3 cases) in `StopAndDoneTests`. `SchedulePlan` and `SchedulePlan.Item` gained public inits so the app tests can build plans.
- **Red first:**
  - three items giving three requests;
  - a smaller plan, and an empty plan leaving other requests alone;
  - alarms and passed fire times (the latter was the crash);
  - the 64 cap;
  - re-applying adds nothing;
  - the category, and the category and `userInfo` on every request;
  - the delegate set and kept alive;
  - Done;
  - the authorization options;
  - the permission table;
  - one error report per plan;
  - the engine's earlier-occurrence Done (review).
- **Passed on their first run, kept as acceptance coverage:**
  - a new title replacing the content;
  - opening or dismissing not being Done;
  - no notes or tags in any content, checked through a real `Engine`;
  - Time Sensitive turned off reaching the engine and making High nudges ordinary, also through a real `Engine`;
  - the engine's open-occurrence Done.
- **Written with the fix, then mutation-checked** (red not seen first): a Done held until someone listens, and room left for another pending request.
- **Mutation-checked:**
  - Done ignoring the action identifier fails;
  - the content diff ignoring the title fails (the title test first also changed the level, so it survived; the test now changes only the title);
  - the cap keeping the latest fails;
  - dropping the not-determined Time Sensitive rule fails;
  - reporting per request fails;
  - the cap ignoring other requests fails;
  - Done not held fails;
  - the engine's `>=` as `>` fails;
  - dropping the engine's guard fails.

**Code review (two axes, against main).**
- **Spec.** Fixed, each with a test:
  - **Done closed whatever occurrence was open.** Yesterday's banner left in Notification Center would have closed today's occurrence. The spec says "a Done event for that occurrence". The engine now has `markDone(_:nudgeFiredAt:)`, which ignores a Done whose nudge fired before the open occurrence's due time (`doneFromANudgeOfAnEarlierOccurrenceIsIgnored`, `doneFromANudgeOfTheOpenOccurrenceClosesIt`). The adapter carries the fire time in `userInfo` and reports it.
  - **A Done could be lost.** It is dropped if it arrives before the app model sets `events`, for example on the background launch the Done action itself causes. The adapter now holds it until `events` is set (`aDoneBeforeAnyoneListensIsReportedOnceSomeoneDoes`).
  - **The cap counted only the adapter's own requests.** A pending Send a Test Nudge would have made 65, and the system would have dropped the latest nudge. Room is now 64 minus the other pending requests (`anotherPendingRequestLeavesRoomForSixtyThreeNudges`).
  - Fixed: the clock is now read after the pending fetch, so re-added triggers drift less.
  - Kept: the public plan inits, which are for tests and documented, and `willPresent`, which was agreed before coding.
- **Standards: no hard violations.** Fixed:
  - The responder was a non-Sendable class with a mutable `weak var`, read off the main actor. It is now `Sendable` with a `weak let`, set in its `init`.
  - The reminder ID went through the delegate as a `String`. It is now a `DeliveredNudge` value (reminder ID and fire time).
  - The repeated identifier literals in the tests are now shared constants.
  - The adapter's constants are grouped, and the fake's stray blank line is gone.
  - The isolated conformance's reason is in the doc comment.
  - Kept: `SystemNotificationCenter` only passes calls on (Middle Man). It is the test seam.

**For ticket 21.**
- **At launch:** build `NotificationAdapter(center: SystemNotificationCenter(), clock:)` in `application(_:didFinishLaunchingWithOptions:)`, through a `UIApplicationDelegateAdaptor`. Apple says the delegate must be set "before your app finishes launching", and `init` sets it. Then set `adapter.events` to the app model.
- **At launch and on every foreground:** call `engine.update(permissions:)` with `await notifications.permissions(updating: await alarms.permissions(...))`, or whatever shape 19 gives the alarm side. Repeats are free. Then hand the engine the reminders, which applies the plan and refills the 64.
- **On `schedulingFailed`:** read the permissions again. `notificationsNotAllowed` means notifications were turned off.
- **On `markDone(_:nudgeFiredAt:)`:** call `engine.markDone(_:nudgeFiredAt:)`, not `markDone(_:)`.
- **The engine holds one `SchedulerAdapter`,** so 21 needs a small adapter that hands each plan to both this one and 19's. It must be `@MainActor` too.
- **The store:** Apple warns that "users can respond to actions while the device is locked", when files with `complete` protection are unreadable. The store saved after a Done needs protection no stronger than `completeUntilFirstUserAuthentication`.
- **Delivered notifications:** Done cancels pending requests, through the next plan, but leaves delivered banners in Notification Center. The engine now ignores a stale Done. Clearing delivered banners is not asked for.

**Device checks: pending, not run on the iPhone.** Record the iOS version when they are run.
1. **Done reaches the engine** from a banner and from the Lock Screen, without unlocking.
2. **A Time Sensitive nudge shows during a Focus** that allows Time Sensitive notifications, and an ordinary nudge is held.
3. **The pending limit.** Schedule requests until they stop appearing in `pendingNotificationRequests()`. Confirm 64 and that the soonest are kept, record it, and adjust `pendingLimit` if needed.
4. **Interval triggers.** Check that one survives a reboot before it fires and fires on time. The docs don't say.
5. **A nudge in the foreground** shows as a banner (`willPresent`).

**Left alone:** AlarmKit (19), the Open intent (20), wiring and the foreground refill (21), every UI including the banners (31) and Settings (30), and the device checks above.
