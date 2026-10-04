Status: ready-for-agent

# Onboarding, permission prompts and banners

## What to build

First launch: a short onboarding explaining how nudges reach you (the mockup's First launch and How It Nudges), then the notification permission request, then the alarm permission request, each with a reason before the system prompt. Banners: notifications denied (red, says what can still reach you), alarms denied ("Urgent nudges now come as Time Sensitive notifications"). **How It Nudges** page previews the ladder per strength. Banners appear on Now and My Day.

## Docs basis

- Alarm permission is requested by `requestAuthorization()`; denial makes every schedule attempt fail ([requestAuthorization()](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization())). The system prompt shows the `NSAlarmKitUsageDescription` text ([key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription)). Docs say to make clear in the UI that the alarm won't be scheduled when denied ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)).
- Onboarding wording and layout: HIG, not fetched here; check the mockup and the HIG "Onboarding" and "Privacy" pages via apple-rag-mcp before finalising.

## Acceptance criteria

- [ ] First launch shows onboarding once; second launch does not.
- [ ] The notification request happens before the alarm request, each only after its explanation screen.
- [ ] Denied alarms show the alarms banner; denied notifications show the notifications banner; both can show together.
- [ ] Banners disappear when permission is granted (observe updates without relaunch).
- [ ] How It Nudges values match the engine's ladder constants (read from the engine, not retyped).
- [ ] Matches the mockup's First launch screens.

Blocked by: 20, 21
