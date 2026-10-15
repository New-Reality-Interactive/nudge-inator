Status: resolved

# AlarmKit device spike: alarm limit, Open silencing, Open on a locked phone

Throwaway. A tiny debug screen (or a separate throwaway app) run on a **physical iPhone** for the final answers. The test iPhone is an iPhone 15 on **iOS 27.0.1**; if it has been updated since, record the version it runs. Record the answers under `## Answer` in this file; do not carry the spike code into the product.

## Simulator pass first (optional, untested)

Apple's docs say nothing about AlarmKit in the Simulator, so whether it works there is unknown. Spend a few minutes running the debug screen on an iOS 26 simulator before the device run:

- If alarms schedule and Open runs, questions A, B and F can be answered provisionally. Mark any simulator-only answer "simulator, unconfirmed" and repeat it on the device.
- If scheduling throws, nothing fires, or the Open intent never runs, record that in `## Answer` and go straight to the device.
- C (locked and before first unlock), D (silent mode and Focus) and E (Lock Screen look) cannot be reproduced in a simulator and are device-only. Treat a simulator limit number for A as provisional only.

The device run is still required for the final answers to A to F.

## What to build

A debug screen with buttons that schedule AlarmKit alarms with an alert-only presentation: title, tint, system Stop, and a custom secondary button **Open** (`secondaryButtonBehavior: .custom`) bound to a `secondaryIntent` that opens the app.

API facts to build the spike with (checked against Apple's docs, Oct 2026):

- Schedule with `AlarmManager.shared.schedule(id:configuration:)`. For an alert-only alarm use the `AlarmManager.AlarmConfiguration.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` factory (iOS 26.0+, "behaves like a traditional alarm"), not the countdown-style `init`. The schedule is `Alarm.Schedule.fixed(Date)`: a one-shot at one moment, not relative to the time zone.
- `secondaryIntent` and `stopIntent` are typed `(any LiveActivityIntent)?`. The Open intent must conform to `LiveActivityIntent`, not only `AppIntent`.
- `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` is **iOS 26.1+**, which is the project minimum. Use it, and not the deprecated `init(title:stopButton:...)` that Apple's sample still uses. The system provides the Stop button. Record which iOS version the device runs.
- `openAppWhenRun` is **deprecated in iOS 26.0**, and Apple says setting it to `true` "generates an error if the app intent runs in an app extension". The replacement is `static var supportedModes: IntentModes`; `.foreground` means "bring the app to the foreground before the action runs". WWDC25-230 still shows `openAppWhenRun`, so for the spike try `supportedModes = .foreground` first and note what happens.
- Tint comes from `AlarmAttributes(presentation:metadata:tintColor:)`. `AlarmMetadata` may be an empty type, but it must be `Codable`, `Hashable` and `Sendable`.

## Questions and docs basis

| # | Question | What the docs say | Status |
|---|---|---|---|
| A | What is the system alarm limit? Schedule alarms one by one (fixed-date, far in the future) until `schedule` throws `AlarmManager.AlarmError.maximumLimitReached`; record the count. Also check whether the limit counts per app or across apps, and whether fired/stopped alarms free slots. | `maximumLimitReached`: "A maximum number of alarms is already scheduled." No number is given. [maximumLimitReached](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmerror/maximumlimitreached). `AlarmManager.alarms` drops alarms once they fire and stop ([alarms](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarms)). | **Device check** (number, per-app vs global, slot reuse) |
| B | Does tapping **Open** silence the ring? | The `secondaryButtonBehavior` docs say the button can "execute an intent without mutating the alarm state" ([secondaryButtonBehavior](https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct/secondarybuttonbehavior-swift.property)). That suggests Open does not stop the ring, but the docs don't say so outright. WWDC25-230 shows the Open intent with `openAppWhenRun = true` and says the system handles stop/countdown for system buttons only ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230), [sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)). `AlarmManager.stop(id:)` stops an alarm; a one-shot is then deleted ([stop(id:)](https://developer.apple.com/documentation/alarmkit/alarmmanager/stop(id:))). | **Device check.** Also test: does calling `AlarmManager.shared.stop(id:)` from inside the Open intent silence it? |
| C | How does **Open** behave on a locked phone: does the button show, does the intent run, does the app open, does it require unlock? Test: (1) locked after first unlock, (2) locked right after a reboot before first unlock. | "This is only available after first unlock." ([AlarmConfiguration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration)). Behaviour when locked after first unlock is not documented. | **Device check** |
| D | With the (empty) widget extension from ticket 01 present, does an alert-only alarm (no countdown) ring reliably through silent mode and a Focus? Optional comparison: the same alarm in a build without the extension, to learn whether it was ever needed. | Alert breaks through silent mode and the current Focus ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)). The extension is expected for countdown presentations ([sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)); the docs don't say what happens to alert-only alarms either way. | Docs answer silent/Focus; the extension question is a **device check** |
| F | Does the Open intent (a `LiveActivityIntent`) work when it is compiled into the shared module used by both the app and the extension? (It will live there per ticket 01.) | `LiveActivityIntent` docs: "the system launches your app process without opening the app" ([LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent)). `openAppWhenRun` is deprecated in iOS 26 and errors if the intent runs in an app extension; `supportedModes` replaces it ([supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)). Which process runs an intent compiled into both the app and the extension is not stated. | **Device check:** does Open launch the app UI with `supportedModes = .foreground`, and does the intent run in the app process rather than the extension? |
| E | Does the alarm show only the title (plus app name) on the Lock Screen, with the app's tint? | Alert shows the custom title and the app name ([WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230)). | Docs answer; confirm by eye |

## Acceptance criteria

- [x] A: the measured limit (from the device; a simulator number alone does not count) is written down as a number (or "no limit up to N"), with whether it is per app and whether stopped/fired alarms free slots.
- [x] B: written answer "Open silences / does not silence the ring", and, if it does not, whether `stop(id:)` inside the intent silences it.
- [x] C: written answer for both locked cases (after first unlock; before first unlock), describing what the person sees and whether the app opens on the reminder.
- [x] D, E and F: yes/no with notes. D records whether the extension made any difference (if not, say so; the extension stays anyway, decided in ticket 01).
- [x] The answers are summarised at the top of `## Answer` in a form tickets 15, 19 and 20 can quote (chain length recommendation, Open-intent behaviour, locked-phone behaviour).
- [x] Device model and iOS build number recorded, plus whether a simulator pass was tried and what it showed.

Blocked by: 01

## Answer

Device: iPhone 15 (iPhone15,4), **iOS 27.0.1 (24A446)**, tested 2026-10-14 with a Debug build from Xcode 26.6 / iOS 26.5 SDK. The phone was in silent mode for every check. Simulator pass tried (iOS 26.5): alarms schedule and ring, but no App Intent runs there (details below).

### Summary for tickets 15, 19 and 20

- **A, alarm limit (ticket 15):** no `maximumLimitReached` up to **4,000** pending alarms in one app, and a second app could still schedule while the first held 4,000. AlarmKit does not constrain the chain length in practice; the 64-pending-notification cap (ticket 18) is the binding limit. Per-app vs global and slot reuse could not be measured because no limit was hit, so keep the `maximumLimitReached` fallback as a safety net and document slot reuse as unknown. One caution: the first ring right after bulk-scheduling 4,000 ignored touches until swiped away twice (not reproduced); don't bulk-schedule thousands.
- **B, Open and the ring (ticket 20):** tapping Open **does not silence** the ring. Calling `AlarmManager.shared.stop(id:)` inside the Open intent **does**: the ring stops and the alert goes away. The Open intent must call `stop(id:)`: on a locked phone, Open without it dismisses the alert UI and opens the app while the ring keeps going, with nothing left on screen to stop it.
- **C, locked phone (ticket 20):** Open shows on the full-screen alert in both locked cases. After first unlock, Open asks for Face ID (or passcode); before first unlock it asks for the passcode. The ring continues until authentication; then the app opens and the intent's `stop(id:)` silences it. Slide to stop works without unlocking and leaves the phone locked.
- **D, silent mode, Focus, extension (ticket 19):** alert-only alarms rang out loud through silent mode and Do Not Disturb every time. A build with **no widget extension** behaved identically, so the extension makes no observable difference for alert-only alarms; it stays per ticket 01.
- **E, look (ticket 19):** unlocked: a banner with the alarm icon, app name and title, all in the tint; Open is an **icon-only** tinted button (the `AlarmButton`'s `systemImageName`), Stop is a grey ✕. Locked: full-screen with the title (grey), a large clock, the app name, a full-width tinted **"Open"** button with its text, and "slide to stop"; the tint shows only on the Open button there.
- **F, Open intent in the shared module (ticket 20):** works. With `supportedModes = .foreground`, the intent compiled into NudgeShared ran **in the app process** (not the widget extension), `systemContext.currentMode` was `.foreground`, and the app came to the foreground. The spike declared `AppIntentsPackage` signposts (NudgeShared, app and extension); WWDC25-244 says they're for code "not compiled into a static library", so whether they're needed for a static SwiftPM package is untested. The deprecated `openAppWhenRun` variant was only tried in the simulator, where no intent runs. App Intents can't be tested in the simulator (ad-hoc signed builds are rejected by linkd), so Open behaviour is device-only.

Spike code: branch `prototype/alarmkit-spike` (debug screen in `App/PrototypeAlarmSpike/`, Open intent in `Packages/NudgeShared/Sources/NudgeShared/PrototypeAlarmSpike.swift`, plus a "Spike Twin" app target with its own bundle ID and no widget extension).

### Simulator pass (2026-10-14, iPhone 15 simulator, iOS 26.5 (25G83), Xcode 26.6)

- Authorization: the AlarmKit permission prompt shows and `requestAuthorization()` returns `authorized`.
- A (simulator, unconfirmed): no `maximumLimitReached` up to 1,200 far-future fixed alarms in one app (stopped by hand). Cancelling ~1,000 alarms one by one with `cancel(id:)` takes minutes because every cancel re-delivers the full list on `alarmUpdates`; uninstalling the app removed all its alarms.
- Alerts fire and the Open button shows, but **no custom intent runs in the simulator**: tapping Open (supportedModes, openAppWhenRun, and an intent compiled into the app target instead of NudgeShared) and Stop all fail with `LNPerformActionErrorCodeActionNotFound`. linkd logs `Rejecting invalid client due to requiresValidBundle`: simulator builds are ad-hoc signed (no team ID), so App Intents won't run. B and F cannot be answered in the simulator; the iOS 26.1 simulator was not run for the same reason.
- Docs note for F: WWDC25-244 says App Intents can now live in Swift packages and static libraries, and that `AppIntentsPackage` is for "code not compiled into a static library". The spike declares one anyway (`NudgeSharedIntents`, included by the app and the extension); the build puts the NudgeShared intents into both the app's and the extension's `Metadata.appintents`.

### Device run (iPhone 15 (iPhone15,4), iOS 27.0.1 (24A446), 2026-10-14, Xcode 26.6 / iOS 26.5 SDK build)

**Check 1: unlocked, app in background, Open = `supportedModes = .foreground`, no `stop(id:)` in the intent.**

- The alarm showed as a **banner** at the top of the Home Screen: alarm icon, app name "Nudge-inator", and the title ("Nudge: ring in 10s") below it, all in the orange tint. Open shows as an orange-tinted icon-only button (the `arrow.up.forward.app` symbol, no "Open" text); system Stop is a grey ✕.
- Tapping Open: the intent ran **in the app process** (`com.newrealityinteractive.nudgeinator`, same pid as the app, not the widget extension), with `systemContext.currentMode = .foreground`. The app came to the foreground (scene inactive → intent → active). **The alarm kept ringing** and the banner stayed; tapping Open again ran the intent again. Tapping ✕ stopped it, and the Stop intent also ran in the app process.

**Check 2: unlocked, app in background, Open = `supportedModes`, Open intent calls `AlarmManager.shared.stop(id:)`.**

- Tapping Open brought the app to the foreground and **the alarm stopped and was dismissed** with no other tap. So the Open intent can silence the ring by calling `stop(id:)` itself.

**Check 3: locked after first unlock, Open calls `stop(id:)`.**

- The alarm is a **full-screen** alert: alarm icon and title ("Nudge: ring in 15s") in grey at the top, a large current time, the app name "Nudge-inator" in grey under it, a full-width **orange "Open" button** (here the button has its text label), and the system **"slide to stop"** slider. The tint shows only on the Open button.
- Tapping Open asks for authentication (Face ID, then passcode when Face ID wasn't used). After unlocking, the app opened and **the ring stopped on its own** (the Open intent's `stop(id:)`).

**Check 4: locked before first unlock (alarm scheduled, phone restarted, not unlocked), Open calls `stop(id:)`.**

- The alarm **rang** after the reboot, and the full-screen alert looked the same as check 3, **with the Open button**.
- Tapping Open skipped Face ID (unavailable before first unlock) and asked for the **passcode**. The ring continued until the passcode was entered; after that the app opened and the ring stopped (the intent's `stop(id:)` ran once the app could launch).
- Repeat of check 4 with the Open intent **not** calling `stop(id:)` (the spike's toggle, kept only in memory, was presumably reset to off by the reboot): Open + passcode opened the app and **removed the full-screen alert, but the ring kept going**, with no alarm UI left to stop it from. The spike app's own "Stop or cancel all" button would have stopped it; the tester deleted the app instead. Contrast check 1 (unlocked), where the banner stayed after Open and ✕ still worked. **So on a locked phone, Open without `stop(id:)` leaves an unstoppable ring unless the app itself stops it.**
- Check 4 repeated with `stop(id:)` in the intent on (now the spike's default): same result as the first run. The ring stops after the passcode is entered, and the app opens. Reproducible.
- Same before-first-unlock scenario, using **slide to stop** instead of Open: the alarm stopped and was dismissed **without a passcode**, and the phone stayed locked.

**Check 5: silent mode + Do Not Disturb Focus, locked, widget extension present.**

- The phone's Ring/Silent switch was set to silent for **every** device check above (the tester's default), and every alarm rang out loud.
- With Do Not Disturb on as well: run 1 rang out loud with the full-screen alert; Open stopped the ring and opened the app. Run 2 rang the same; slide to stop stopped it and left the Lock Screen (notifications view). Alert-only alarms rang reliably through silent mode and a Focus with the empty widget extension present.

**Check 6: D comparison without a widget extension (Spike Twin: own bundle ID, no `PlugIns/`, purple tint), silent + Do Not Disturb, locked.**

- Run 1: rang out loud, full-screen alert with a purple Open button; Open stopped the ring and opened the Twin app. Run 2: same alert; slide to stop dismissed it. **No difference from the build with the extension**: for alert-only alarms (no countdown) the extension made no observable difference. It stays anyway (ticket 01 decision).

**Check 7: alarm limit (A).**

- Scheduling far-future `.fixed` alert-only alarms one by one in the main app: **no `maximumLimitReached` up to 4,000** (four presses of 1,000; "app now has 4000"). Because no limit was reached, "per app vs across apps" and "do fired/stopped alarms free a slot" could not be measured.
- With the 4,000 still scheduled, the **first** ring scheduled right afterwards showed the full-screen alert but **did not respond to touch** (neither Open nor slide to stop) and kept ringing until the tester swiped up twice. Several later rings with the 4,000 still scheduled behaved normally. Not reproduced; unconfirmed guess: the system was still processing the bulk schedule.
