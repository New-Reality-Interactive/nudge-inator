Status: ready-for-agent

# Onboarding, permission prompts and banners

Design spec: `docs/design/DESIGN.md` (Components: Permission banner, How It Nudges). Where it and the mockup disagree, see its Precedence note.

## What to build

First launch: a short onboarding explaining how nudges reach you (the mockup's First launch and How It Nudges), then the notification permission request, then the alarm permission request, each with a reason before the system prompt. Banners: notifications denied (red, says what can still reach you), alarms denied ("Urgent nudges now come as Time Sensitive notifications"). **How It Nudges** page previews the ladder per strength. Banners appear on Now and My Day.

## Docs basis

- Alarm permission is requested by `requestAuthorization()`; denial makes every schedule attempt fail ([requestAuthorization()](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization())). The system prompt shows the `NSAlarmKitUsageDescription` text ([key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription)). Docs say to make clear in the UI that the alarm won't be scheduled when denied ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)).
- **AlarmKit asks for itself.** If the app hasn't called `requestAuthorization()`, AlarmKit requests authorization on the first `schedule` call ([sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)). Call it here, after the explanation, so the prompt never appears in the middle of scheduling a plan.
- **Notifications:** request with `[.alert, .sound]` only (see ticket 18). Don't pass `.timeSensitive` (deprecated; it's the entitlement).
- **HIG, Onboarding:** aim for "fast, fun, and optional". If people can skip it, don't show it again on later launches, and keep it findable later (that is the How It Nudges link in Settings). Make the permission request during onboarding only where it explains why and what it's for; this app's whole point needs the permissions, so asking here is reasonable ([Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)).
- **HIG, Privacy, pre-alert screens:** a custom screen before a system prompt should have one button titled like "Continue" or "Next" (not "Allow", which can be mistaken for the system's allow button), and no way to close or cancel it without reaching the system prompt. No imagery of the system alert, no incentives ([Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)). The HIG's examples list camera, location and similar; notifications and alarms aren't named, so treat this as the safe default.
- **HIG, Managing notifications:** Time Sensitive is for events "happening now or will happen within an hour"; the first Time Sensitive notification makes the system explain it and offer to turn it off, so the Time Sensitive banner must follow `timeSensitiveSetting`, not what was granted at onboarding.
- Copy for the system prompt strings (`NSAlarmKitUsageDescription` already exists from ticket 01): brief, complete sentence, sentence case, active voice, ending with a period (HIG, Privacy).

- **Don't read `AlarmManager.authorizationState` around the prompt** (found in ticket 22). Reading it on the main thread right after the prompt was answered froze the app for 69 s, and once for good. Use the adapter: `requestAuthorization()` returns the answer and records it, and `permissions(updating:)` gives the state without reading AlarmKit again. Ticket 22's device run also left a check for here: whether a change made in Settings while the app is suspended arrives through `authorizationUpdates` when it returns, since the adapter no longer re-reads the state.

## Acceptance criteria

- [ ] First launch shows onboarding once; second launch does not.
- [ ] The notification request happens before the alarm request, each only after its explanation screen, whose single button reads "Continue" (or "Next") and which has no close or cancel.
- [ ] `requestAuthorization()` for alarms is called here; no schedule call can be the first thing that triggers the alarm prompt.
- [ ] Denied alarms show the alarms banner; denied notifications show the notifications banner; both can show together.
- [ ] Banners disappear when permission is granted (observe updates without relaunch).
- [ ] How It Nudges values match the engine's ladder constants (read from the engine, not retyped).
- [ ] Matches the mockup's First launch screens.

Blocked by: 21, 22, 23
