# Currency / reality-check review: ARCHITECTURE-SPINE.md

Lens: was every committed decision checked against the web, Apple's docs or the project, rather than asserted from training data?
Date: 2026-10-03. Sources: apple-rag-mcp (Apple docs and WWDC transcripts), web search, GitHub. Local docs/apple holds only HIG design PDFs, so it couldn't be used for API checks.

**Verdict:** The versions and most named APIs hold up. The memlog records real checks for GRDB, Xcode/Swift, Tab(role: .search), CryptoKit, BGAppRefresh, AlarmManager.alarms, SceneStorage, WWDC26-278 and appEntityIdentifier. Two decisions that nothing records as checked conflict with current reality: `swift test` on macOS over the whole NudgeKit package, and which process runs intents from a shared package. Several smaller assumptions were never checked either.

Counts: critical 0 · high 2 · medium 4 · low 6

---

## High

### H1. `swift test` on macOS can't build NudgeKit as structured
- **Location:** Conventions › Testing; Structural Seed (`Sources/NudgeCore/ # ... swift test on macOS`, CI node "swift test"); memlog Q9.
- **Claim:** NudgeCore (and NudgeStore) tests run with `swift test` on macOS, no simulator. All non-UI code is one package, NudgeKit.
- **Evidence:** AlarmKit is iOS 26 / iPadOS 26 / Mac Catalyst 26 only, with no macOS (Apple docs: AlarmManager, Alarm.Schedule, AlarmError and others). ActivityKit has no macOS either, and the BackgroundTasks scheduler isn't a macOS framework. NudgeShell imports AlarmKit and BackgroundTasks, and NudgeLiveActivity imports AlarmKit. `swift test` (and `swift build --build-tests`) builds every target in the package for the host, so those two targets fail to compile on macOS. That fails the engine test job too. Swift 6.4 also makes `swiftbuild` the default build system for `swift build`, which nobody checked against this layout. Nothing in the memlog records checking the layout against platform availability.
- **Fix:** Pick one and record it:
  - (a) Split NudgeCore and NudgeStore into their own package (or a package whose targets are all macOS-buildable). Run `swift test` on that package only.
  - (b) Guard the iOS-only targets with `#if canImport(AlarmKit)` / `#if os(iOS)` so they compile empty on macOS.
  - (c) Drop "swift test on macOS" and run engine tests with `xcodebuild test -destination 'platform=macOS'` on a scheme that holds only the Core and Store test targets.

  Also declare `platforms:` in Package.swift.

### H2. The process that runs intents from a shared package isn't verified on iOS 26
- **Location:** AD-5 (intents run in the app process; the widget links NudgeLiveActivity), Structural Seed › First spike.
- **Claim:** The alarm's stop and secondary intents and the Live Activity Done are `LiveActivityIntent`s that run in the app process, and the widget links the same target.
- **Evidence:**
  - Apple's WidgetKit article "Adding interactivity to widgets and Live Activities" says a `LiveActivityIntent` runs in the app's process. That supports AD-5.
  - WWDC26 session 345 ("Discover new capabilities in the App Intents framework") says that when intents live in a shared package linked by the app and its extensions, "the system has to decide which process runs each intent… if the app is already running, it prefers the app, and if not, it launches the extension". It introduces `IntentExecutionTargets` to pin the process.
  - `IntentExecutionTargets` is **iOS 27.0+** (Apple docs, `IntentExecutionTargets.widgetKitExtension`).
  - The memlog's first spike covers only `AppIntentsPackage` packaging, not where the code runs. If a stop intent ever ran in the widget process, there would be no `CommandSubmitting` dependency there (`AppDependencyManager` is registered by the app). AD-5's "never opens the database" would still hold, but the command would be lost.
- **Fix:** Widen the first spike to confirm that NudgeLiveActivity's intents run in the app process on iOS 26 and 27, both with the app running and with the app not running. On iOS 27, declare the app as the execution target explicitly (`IntentExecutionTargets`) inside an availability wrapper (AD-18). Record the result in the memlog. If iOS 26 picks the widget, have the intents fail closed: no dependency means no-op plus journaling, or `openAppWhenRun`.

## Medium

### M1. A Keychain `ThisDeviceOnly` marker doesn't detect a restore to the same device
- **Location:** AD-15 › Restore detection; memlog gate fix ("a Keychain ThisDeviceOnly install marker detects a restore").
- **Evidence:** Apple's "Restricting keychain item accessibility" says: "If the attribute ends with the string ThisDeviceOnly, the item can be restored to the same device that created a backup, but it isn't migrated when restoring another device's backup data." So after erase-and-restore on the same iPhone, the marker comes back and matches the database. Pending notifications and alarms are still gone (the memlog's own assumption), so `scheduled` rows aren't marked `lost`. History then shows nudges that never fired during the gap.
- **Fix:** Add a second signal. Options: a marker stored in a file excluded from backup (`isExcludedFromBackup`), whose absence next to a present database means a restore; or compare against what the OS reports (no pending requests and no alarms while the ledger expects some means mark future rows `lost`). Add same-device restore to the brief §10 device checklist.

### M2. The stop intent may not run before the first unlock, and AD-16's journal path for Stop depends on it
- **Location:** AD-16 › The journal (Stop posts `followup/<key>` before the first unlock); AD-6 › Uncounted snoozes.
- **Evidence:** Apple's `AlarmManager.AlarmConfiguration` overview says the secondary intent "is only available after first unlock". The spine already relies on this for snoozes (AD-6). The docs say nothing either way about `stopIntent`. The WWDC25-230 transcript also says the Live Activity "cannot be shown… after device restarts and before it's first unlocked".
- **Fix:** Treat "stop intent doesn't run before the first unlock" as the likely case, not an edge case. Define what AD-16 and AD-6 do when an alarm for an open occurrence simply vanishes before the first unlock (today it goes uncounted). Keep it on the device checklist, but write the fallback into AD-16 now.

### M3. CI image assumptions are shakier than the memlog's "assumption" entry suggests
- **Location:** Structural Seed (GitHub Actions macOS, simulator tests on iOS 18 and 26/27); memlog (assumption) on runners.
- **Evidence:**
  - Xcode 27 isn't on the `macos-26` image. It's on a separate `xcode-27` / `xcode-27-arm64` label. The 2026-09-01 image carried only Xcode 27 betas, on macOS 26.5.2, while Xcode 27.0 GM needs macOS 26.6+.
  - Nothing shows an iOS 18 simulator runtime on that image, and runner-images has removed older runtimes before (actions/runner-images #12900).
  - GRDB issue #1875: adding GRDB crashed UI tests on Xcode 27 beta 4 with the iOS 27 simulator. The issue is closed with no fix version given.
- **Fix:** Name the runner label in the spine (or leave it to the workflow, but drop "macOS" as if it were one image). Budget a step that downloads the iOS 18 runtime (`xcodebuild -downloadPlatform iOS -buildVersion 18.x`). Add a re-check of GRDB 7.11.1 UI tests on the Xcode 27.0 GM simulator to the first CI task.

### M4. A Countdown system presentation is needed, not just the Live Activity
- **Location:** AD-12 (the post-snooze alarm "has a pre-alert countdown so the Live Activity shows"), AD-5 › widget.
- **Evidence:** In WWDC25-230 and the sample, AlarmKit "expects a widget extension if an app supports a countdown presentation. Otherwise, the system may unexpectedly dismiss alarms and fail to alert." Before the first unlock the Live Activity can't render, so the system uses `AlarmPresentation.Countdown` / `.Paused` from the attributes. `countdownDuration` docs: the countdown UI "will appear at a time equal to the next scheduled alert date minus the duration", which confirms the fixed fire time stays the alert time. The spine never says the attributes carry the Countdown (and Paused, if pause is allowed) presentations.
- **Fix:** In AD-12 or AD-7, say that every alarm with a countdown sets `AlarmPresentation(alert:countdown:)` with localized titles. Also say that `postAlert` is the system's snooze length, the one the reconciler replaces (AD-12).

## Low

- **L1. UTC `DateComponents` in `UNCalendarNotificationTrigger` (AD-9).** Apple's docs don't document `DateComponents.timeZone` being honored. Community sources and Apple forum thread 811265 say it is, and that the trigger stays fixed to that zone. Nothing records a check. Fix: add a unit or simulator test that checks `nextTriggerDate()` across a zone change. A one-shot trigger could also keep the device zone with components converted, but say which one is used and why.
- **L2. The 64-pending limit (AD-14)** is documented only in the deprecated `UILocalNotification` page ("the system keeps the soonest-firing 64… and discards the rest"). It's already on the device checklist, so just cite the source in the memlog.
- **L3. Stack row "SwiftUI, UserNotifications, App Intents, BackgroundTasks, CryptoKit: iOS 18 SDK surface".** Builds use the iOS 27 SDK (Xcode 27). App Store uploads have required the iOS 26 SDK since 2026-04-28, which is confirmed. Reword the row as "API surface available on iOS 18 (deployment target)" so nobody pins an SDK. Also, App Intents in Swift packages arrived with the Xcode 26 toolchain (WWDC25-244). `AppIntentsPackage` itself is iOS 17+, so iOS 18 is fine at runtime. Record this as the reason the spike should pass.
- **L4. iOS 27 `appEntityIdentifier` "still beta on 2026-10-03" (Deferred).** Apple's docs still label the `AlarmConfiguration` initializers with `appEntityIdentifier` as "iOS 27.0+ [Beta]", even though iOS 27 shipped in September. That's probably a docs lag. Re-check at the 27.1 SDK rather than treating it as beta API.
- **L5. Assistive Access keys (Environments).** Both keys are real: `UISupportsAssistiveAccess` is iOS 26+, and `UISupportsFullScreenInAssistiveAccess` is iOS 17+. Apple presents them as two alternative paths. Note in AD-18 that iOS 18 gets the full-screen standard UI and iOS 26+ gets the `AssistiveAccess` scene. That scene can be wrapped with `if #available` in the scene body, because `SceneBuilder.buildLimitedAvailability` is iOS 16.1+ (confirmed). So "named wrapper" for a scene means that, and nothing more.
- **L6. Swift 6.4 / Xcode 27 source breaks.** These are the `@State` macro, SE-0508 and duplicate module names, and Instruments now needs iOS 17+ devices. None blocks the spine. Mention them in the setup story, since the stack pins 27.0 (27A266a).

---

## Confirmed (spot-checked against current sources)

- GRDB.swift 7.11.1 is the latest release (GitHub releases), and 7.9+ needs Swift 6.1+ / Xcode 16.3+.
- Xcode 27.0 is build 27A266a, shipped 2026-09-14, with Swift 6.4, and needs macOS Tahoe 26.6+ on Apple silicon. Debugging iOS 17+ includes iOS 18 simulators.
- App Store uploads have needed Xcode 26+ and the 26 SDKs since 2026-04-28 (Apple news, several sources).
- AlarmKit:
  - `AlarmManager.AlarmError.maximumLimitReached` exists.
  - `Alarm.Schedule.fixed(Date)` is absolute and doesn't change with the time zone.
  - `Alarm.State` has `.scheduled`, `.countdown` ("…or when a person snoozes the alarm"), `.paused` and `.alerting`.
  - `AlarmManager.alarms` deletes an alarm once it fires and stops.
  - `authorizationUpdates`, `AuthorizationState` (`.notDetermined`, `.authorized`, `.denied`), `alarmUpdates`, `SecondaryButtonBehavior` (`.countdown`, `.custom`), `stopIntent` / `secondaryIntent: LiveActivityIntent` and `NSAlarmKitUsageDescription` all exist.
  - `postAlert` is the snooze duration.
- WWDC26 session 278 says iPhone apps are fully resizable on iOS 27, iPhone Mirroring always reports portrait, and layout should never depend on idiom or orientation.
- `Tab(role: .search)` / `TabRole` is iOS 18.0+. `tabBarMinimizeBehavior` and `navigationSubtitle` are iOS 26.0+ on iOS.
- `AppIntentsPackage` is iOS 17+, `AppDependencyManager` is iOS 16+, and App Intents in Swift packages arrived with Xcode 26 (WWDC25-244). The `.clock` schema domain requires every schema, so the deferral is right.
- `customDismissAction` reports only an explicit dismiss.
- `SceneStorage` is per scene, destroyed with the scene, and Apple says not to use it for sensitive data.
- Foundation has no UUIDv5 generator: SF-0041 (in review in 2026) adds version support and leaves name-based v5 to a future proposal. That backs CryptoKit SHA-1.
- `NSSupportsLiveActivities` is the right key.
