Status: ready-for-agent

# Notification adapter over UNUserNotificationCenter

## What to build

A thin adapter in the app target that applies the engine's schedule plan for **notification** items (ordinary and Time Sensitive) through `UNUserNotificationCenter`, and reports permission states and scheduling errors back to the engine. It conforms to the scheduler-adapter protocol the engine's fake already implements.

- Content: title, body "Nudge N of 20 · Urgency". No notes, no tags.
- Ordinary items use the default interruption level; Time Sensitive items use `.timeSensitive`.
- One notification category with a single **Done** action. Handling Done sends the engine a Done event for that occurrence (via the wiring in ticket 20; here, a protocol callback).
- Applying a plan replaces what this adapter has pending (identifiers derived from occurrence and nudge number), and cancels items no longer in the plan.
- Reports: authorization status, Time Sensitive setting, and errors.

## Docs basis

| Criterion | Docs | Status |
|---|---|---|
| Time Sensitive items break through Focus when allowed; user can turn them off; needs the Time Sensitive capability | [timeSensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive), [WWDC21-10091](https://developer.apple.com/videos/play/wwdc2021/10091) (set `interruptionLevel` on the content; enable the capability in Xcode) | Docs answer |
| Reading whether Time Sensitive is on | [timeSensitiveSetting](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/timesensitivesetting) | Docs answer |
| Scheduling while not authorized fails with `notificationsNotAllowed` | [UNError.Code.notificationsNotAllowed](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed) | Docs answer |
| Authorization states | [UNAuthorizationStatus](https://developer.apple.com/documentation/usernotifications/unauthorizationstatus), [UNNotificationSettings](https://developer.apple.com/documentation/usernotifications/unnotificationsettings) | Docs answer |
| How many local notifications can be pending at once | Apple docs search returned no number | **Device check** (schedule until requests stop appearing in `getPendingNotificationRequests`; record the limit, feeds ticket 14's chain length) |
| Done action does not need to open the app (non-foreground action) and works on a locked phone | Not confirmed in the pages fetched | **Device check** |

Verify the action option names (`foreground`, `authenticationRequired`) against the `UNNotificationAction` docs via apple-rag-mcp before relying on them; I did not fetch that page.

## Acceptance criteria

- [ ] Unit tests with a fake notification-center protocol: a plan with 3 notification items results in 3 requests with the expected identifiers, fire dates, body text and interruption levels.
- [ ] Applying a smaller plan removes the stale requests; applying an empty plan removes all of this adapter's requests.
- [ ] No request content contains notes or tag text (assert on content).
- [ ] Authorization and Time Sensitive status are read and delivered to the engine as permission inputs.
- [ ] Device (human, or noted as pending): Done from a banner and from the Lock Screen reaches the engine; Time Sensitive nudge shows during a Focus that allows Time Sensitive; pending limit recorded.

Blocked by: 13, 16
