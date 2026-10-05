Status: ready-for-agent

# Notification adapter over UNUserNotificationCenter

## What to build

A thin adapter in the app target that applies the engine's schedule plan for **notification** items (ordinary and Time Sensitive) through `UNUserNotificationCenter`, and reports permission states and scheduling errors back to the engine. It conforms to the scheduler-adapter protocol the engine's fake already implements.

- Content: title, body "Nudge N of 20 · Urgency". No notes, no tags.
- Ordinary items use the default interruption level; Time Sensitive items use `.timeSensitive`.
- One notification category with a single **Done** action. Handling Done sends the engine a Done event for that occurrence (via the wiring in ticket 20; here, a protocol callback).
- Applying a plan replaces what this adapter has pending (identifiers derived from occurrence and nudge number), and cancels items no longer in the plan.
- Keep at most **64** notification requests pending across all reminders, soonest first (a named constant, easy to change after the device check below). Apple documents that the system keeps "the soonest-firing 64 notifications ... and discards the rest", though only on the deprecated `UILocalNotification` page; the `UNUserNotificationCenter` pages give no number. Without a cap, a few Relentless reminders (20 nudges each) would be dropped silently. Items past the cap are scheduled later, when the app opens or the plan is next applied (ticket 20 refills on foreground).
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
| How many local notifications can be pending at once | "The system keeps the soonest-firing 64 notifications ... and discards the rest" ([UILocalNotification](https://developer.apple.com/documentation/uikit/uilocalnotification), deprecated; the `UNUserNotificationCenter` pages give no number) | **Device check** (schedule until requests stop appearing in `pendingNotificationRequests()`; confirm 64 and that the soonest are kept; record it, feeds ticket 14's chain length) |
| Done action does not need to open the app and works on a locked phone | `foreground` and `authenticationRequired` options are documented ([foreground](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/foreground), [authenticationRequired](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/authenticationrequired)); an action with neither is implied to run without unlocking but the docs don't say so | **Device check** |
| Notification actions are delivered through the delegate | [userNotificationCenter(_:didReceive:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:didreceive:withcompletionhandler:)) | Docs answer |

## Acceptance criteria

- [ ] Unit tests with a fake notification-center protocol: a plan with 3 notification items results in 3 requests with the expected identifiers, fire dates, body text and interruption levels.
- [ ] Applying a smaller plan removes the stale requests; applying an empty plan removes all of this adapter's requests.
- [ ] No request content contains notes or tag text (assert on content).
- [ ] Authorization and Time Sensitive status are read and delivered to the engine as permission inputs.
- [ ] Never more than 64 requests are pending after applying any plan (fake center, several reminders with full ladders); the soonest 64 are kept.
- [ ] Authorization is requested with `.alert` and `.sound` only.
- [ ] The Done action has empty options and the category is attached to every request.
- [ ] Device (human, or noted as pending): Done from a banner and from the Lock Screen reaches the engine; Time Sensitive nudge shows during a Focus that allows Time Sensitive; pending limit recorded.

Blocked by: 13, 16
