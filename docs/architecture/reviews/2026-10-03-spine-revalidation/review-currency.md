---
review: currency
target: docs/architecture/ARCHITECTURE-SPINE.md @ acb3a01
date: 2026-10-03
lens: every committed decision web-researched or reality-checked; versions current; named technologies exist and fit
verdict: PASS WITH FIXES — 0 critical, 1 high, 3 medium, 3 low
---

# Currency review — ARCHITECTURE-SPINE.md (revalidation)

Sources used: Apple's live documentation JSON (`developer.apple.com/tutorials/data/documentation/…`), the
Apple Xcode support matrix, WWDC26 session pages, `gh` against GRDB.swift and actions/runner-images,
xcodereleases.com, and web search. The apple-rag-mcp server answered one query, then returned
"Error POSTing to endpoint" on every later call, so most Apple checks went to the live doc JSON instead.
That comparison also showed that the RAG index lags the live docs on beta labels (see M3).

## Findings

### H1 — AD-18 names an API that doesn't exist: `UIAccessibility.isAssistiveAccessEnabled` [high]

- **Location:** AD-18 › UIKit ("`UIAccessibility.isAssistiveAccessEnabled`"), and the Layer table (the UI row
  imports "all of the above", which doesn't include the Accessibility framework).
- **Claim:** UIKit is allowed for `UIAccessibility.isAssistiveAccessEnabled`.
- **Evidence:** UIKit's `UIAccessibility` has no Assistive Access member. Its members include
  `isAssistiveTouchRunning` and `AssistiveTechnologyIdentifier`, but nothing for Assistive Access
  (https://developer.apple.com/documentation/uikit/uiaccessibility). The real API is
  `AccessibilitySettings.isAssistiveAccessEnabled` in the **Accessibility** framework, iOS 18.0+
  (https://developer.apple.com/documentation/accessibility/accessibilitysettings/isassistiveaccessenabled).
  SwiftUI also offers `EnvironmentValues.accessibilityAssistiveAccessEnabled`, iOS 18.0+
  (https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityassistiveaccessenabled).
  Code written to the spine as it stands won't compile, and the iOS 18 Assistive Access path
  (EXPERIENCE › Assistive Access) is the code that uses it.
- **Fix:** In AD-18, replace the item with the SwiftUI environment value `accessibilityAssistiveAccessEnabled`,
  or with `AccessibilitySettings.isAssistiveAccessEnabled` (Accessibility framework). Then drop it from the
  UIKit allowance. If you choose `AccessibilitySettings`, add `Accessibility` to the import column of the
  target that reads it.

### M1 — The CI plan for an iOS 18 simulator on Xcode 27.0 is still unconfirmed, and the runner image is a preview [medium]

- **Location:** Structural Seed › Environments › CI; Conventions › Testing ("iOS 18 and 26/27 simulators").
- **Claim:** The workflow names a runner image that has Xcode 27.0 and downloads an iOS 18 runtime pinned by
  version with `xcodebuild -downloadPlatform iOS -buildVersion <version>`.
- **Evidence:**
  - GitHub's only image with Xcode 27.0 is `xcode-27`, labeled **preview**. Its software list has
    iOS 27.0, 27.1 and 27.2 simulator runtimes only, with no iOS 18 or iOS 26 runtime
    (https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md;
    https://github.com/actions/runner-images/issues/14404). The `macos-26` image has no Xcode 27 at all.
  - Apple's matrix says Xcode 27.0 supports simulators for iOS 17 and later, so an iOS 18 runtime is allowed
    in principle (https://developer.apple.com/support/xcode/).
  - On Xcode 26.x, `-buildVersion` alone fails with "not available for download" unless
    `-architectureVariant` is also passed (https://developer.apple.com/forums/thread/812146).
  - A web search returned a claim that Xcode 27.0 (and 27.1/27.2 betas) can't download iOS 18.6 from the command
    line, leaving only Xcode's GUI "Add Platforms…". I could not find a primary source for it, so it's
    **unconfirmed**, but it bears directly on this step.
  - If "26/27" means the brief's three tested versions (18, 26, 27), the iOS 26 runtime must also be
    downloaded, and the spine doesn't say so.
- **Fix:** Name the `xcode-27` label and record that it's a preview. Add `-architectureVariant arm64` to the
  download command. Say whether CI covers 26 as well as 27. Give the fallback if the headless iOS 18
  download fails on Xcode 27: import a runtime `.dmg` exported once (`-exportPath` / `xcodebuild -importPlatform`)
  and cached, or leave the iOS 18 leg to the device checklist. Keep "the first run confirms" as the check.

### M2 — The first spike doesn't test the case where App Intents in a Swift package are known to fail [medium]

- **Location:** Structural Seed › First spike; AD-5 › Packaging.
- **Claim:** App Intents declared in `NudgeKit` targets with an `AppIntentsPackage` in each work from the app
  and the widget; the fallback is a framework target.
- **Evidence:** A project merged on 2026-09-18 moved its intents out of a Swift package because "installed from
  Xcode the app showed its actions in the Shortcuts app; installed from TestFlight it showed none". The
  archive's metadata extraction had left out the package's intents, even with an `AppIntentsPackage`
  bridge (https://github.com/as19git67/fk-encore/pull/1271). Older reports describe the same metadata-extraction
  gap for package targets (https://developer.apple.com/forums/thread/759160). A spike run from Xcode on a
  debug build would pass and miss this. Siri, the alarm's Stop and Snooze, and Live Activity Done would then
  silently do nothing in the shipped app, which goes against brief §4/§6. `AppIntentsPackage` itself is
  iOS 17.0+ (https://developer.apple.com/documentation/appintents/appintentspackage), and the WWDC25
  "Get to know App Intents" session announces package support
  (https://developer.apple.com/videos/play/wwdc2025/244/), but neither covers archives.
- **Fix:** Add pass criteria to the first spike: an **archived build installed through TestFlight** shows the
  App Shortcuts and runs the alarm intents. Run it on iOS 18 as well as 26 and 27 for `NudgeIntents`. If the
  archive drops the intents, the framework-target fallback applies.

### M3 — The Deferred note says `appEntityIdentifier` is still beta, but Apple's live docs no longer say so [medium]

- **Location:** Deferred › "iOS 27 `appEntityIdentifier` on alarms".
- **Claim:** It is "still marked beta in Apple's docs on 2026-10-03"; adopt it once it isn't, and re-check with the
  iOS 27.1 SDK.
- **Evidence:** Today the live documentation JSON shows `beta: false`, introduced iOS 27.0, for all three
  `AlarmConfiguration` factories that take `appEntityIdentifier`:
  `alarm(schedule:attributes:appEntityIdentifier:stopIntent:secondaryIntent:sound:)`,
  `init(countdownDuration:schedule:attributes:appEntityIdentifier:…)` and
  `timer(duration:attributes:appEntityIdentifier:…)`
  (https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration). The apple-rag index
  still shows a stale "[Beta]" on a sibling iOS 27 symbol that the live docs list as non-beta
  (`IntentValueQuery.allowedExecutionTargets`). The earlier check probably read that stale index.
- **Fix:** Reword the deferral. The API is out of beta (iOS 27.0+), so it now needs a decision instead of a
  revisit date: adopt it in the AD-18 iOS 27 wrapper as an optional link to the Occurrence entity, or keep it
  deferred for a reason other than beta status. Note in .memlog.md that apple-rag beta labels can lag the
  live docs.

### L1 — Swift Testing has no performance-measurement API for "the 50 ms benchmark" [low]

- **Location:** Conventions › Testing; AD-14 › Cost.
- **Claim:** `NudgeCore` tests use Swift Testing "including … the 50 ms benchmark".
- **Evidence:** Swift Testing in Xcode 27 / Swift 6.4 has no `measure` equivalent. Performance tests stay in
  XCTest (`measure`, `XCTClockMetric`)
  (https://medium.com/@dinkar1708/ios-testing-in-2026-every-test-type-explained-xctest-swift-testing-and-code-coverage-done-53a99ed2120f;
  https://swiftwithmajid.com/2023/03/15/performance-testing-in-swift-using-xctest-framework/).
- **Fix:** Say the benchmark is an XCTest `measure` test, or a Swift Testing test that times `evaluate` with
  `ContinuousClock` and asserts on the median of N runs.

### L2 — GRDB's `SharedValueObservation` has an open deadlock [low]

- **Location:** AD-20 › "on store change"; Stack › GRDB.swift 7.11.1.
- **Evidence:** GRDB 7.11.1 (2026-06-18) is still the latest release, and there has been no release since Xcode 27
  shipped. Issue #1888, opened 2026-09-28 and still open, reports "SharedValueObservation deadlocks when a client is
  cancelled while a value is being notified" (https://github.com/groue/GRDB.swift/issues/1888). The spine
  doesn't name the observation API, so this is a hazard to know about, not an error.
- **Fix:** Optional. Add a note under AD-20, or in the first story, to use plain `ValueObservation` (or
  `DatabaseRegionObservation`) for the store-change signal until #1888 is fixed.

### L3 — The iOS 27 SDK requires the scene life cycle; the spine relies on it without saying so [low]

- **Location:** AD-18 › UIKit (`UIApplicationDelegateAdaptor`, "the `UIApplication` notifications").
- **Evidence:** Apps built with the iOS 27 SDK must adopt the scene-based life cycle or they fail to launch
  (https://blakecrosley.com/blog/ios-27-release-notes, summarizing Apple's iOS 27 release notes). A SwiftUI
  `App` already meets this. The risk is that someone puts foreground or active triggers in app-delegate life
  cycle callbacks, which aren't called under scenes.
- **Fix:** One clause in AD-18: foreground triggers come from `scenePhase` or the `UIApplication` notifications,
  never from `UIApplicationDelegate` life cycle methods.

## Confirmed

| Claim | Source |
|---|---|
| Xcode 27.0 is build 27A266a, released 2026-09-14 (RC on 09-09, same build), ships Swift 6.4 with language mode 6 | https://xcodereleases.com/data.json; https://developer.apple.com/support/xcode/ |
| Xcode 27.0 supports deployment targets, devices and simulators back to iOS 17, so the iOS 18.0 target and iOS 18 simulators are allowed | https://developer.apple.com/support/xcode/ |
| Newer Xcodes (27.1 beta, 27.2 beta 2) exist; pinning 27.0 is a deliberate choice, not stale | xcodereleases.com |
| GRDB.swift 7.11.1 is the latest release (2026-06-18); swift-tools-version 6.1 | `gh api repos/groue/GRDB.swift/releases`; Package.swift @ v7.11.1 |
| GRDB 7.11.1's PrivacyInfo.xcprivacy declares no tracking, no collected data and no accessed API types | GRDB/PrivacyInfo.xcprivacy @ v7.11.1 |
| GRDB #1875 closed 2026-09-27; the reporter says the Xcode 27 RC doesn't have the issue | https://github.com/groue/GRDB.swift/issues/1875 |
| `AppIntent.allowedExecutionTargets` and `IntentExecutionTargets` (`.main`, `.appIntentsExtension`, `.widgetKitExtension`) are iOS 27.0+, non-beta | https://developer.apple.com/documentation/appintents/intentexecutiontargets |
| WWDC26-345 says intents in a shared package run in the app when it's running, otherwise the system may launch the extension | https://developer.apple.com/videos/play/wwdc2026/345 |
| WWDC26-278 ("Modernize your UIKit app"): iPhone apps are fully resizable on iPad and in iPhone Mirroring; don't use idiom or orientation for layout; Mirroring reports portrait | https://developer.apple.com/videos/play/wwdc2026/278/ |
| AlarmKit, iOS 26.0+: `AlarmManager.alarms` (`get throws`; "As soon as an alarm fires and stops it's deleted"), `alarmUpdates`, `authorizationUpdates`, `AuthorizationState` (.notDetermined/.denied/.authorized), `schedule(id:configuration:) async throws -> Alarm`, `AlarmError.maximumLimitReached`, `Alarm.State` (.scheduled/.countdown/.alerting/.paused), `Alarm.Schedule.fixed`, `CountdownDuration(preAlert:postAlert:)`, `AlarmAttributes`, `AlarmPresentation` (alert/countdown/paused), `SecondaryButtonBehavior` (.countdown/.custom), `AlarmPresentationState` | developer.apple.com/documentation/alarmkit/… (live JSON) |
| `AlarmConfiguration`: "secondary intent … is only available after first unlock"; nothing similar is said of `stopIntent` (matches AD-16) | https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration |
| `Alarm` exposes only `id`, `schedule`, `countdownDuration` and `state` (matches AD-6's "the app can't read when Snooze was tapped") | https://developer.apple.com/documentation/alarmkit/alarm |
| `tabBarMinimizeBehavior` iOS 26.0, `navigationSubtitle` iOS 26.0, SwiftUI `AssistiveAccess` scene iOS 26.0, `TabRole.search` iOS 18.0, `SceneBuilder.buildLimitedAvailability` iOS 16.1 | live doc JSON |
| `AppDependencyManager` iOS 16.0, `AppIntentsPackage` iOS 17.0, `LiveActivityIntent` iOS 17.0 | live doc JSON |
| `UNNotificationCategoryOptions.customDismissAction` iOS 10, `UNCalendarNotificationTrigger.nextTriggerDate()` iOS 10, `BGAppRefreshTask` iOS 13, `URLResourceValues.isExcludedFromBackup` iOS 8 | live doc JSON |
| Info.plist keys: `NSAlarmKitUsageDescription` iOS 26.0, `UISupportsAssistiveAccess` iOS 26.0, `UISupportsFullScreenInAssistiveAccess` iOS 17.0 | live doc JSON |
| App Store upload SDK floor: iOS 27 SDK required from April 2027, so building with Xcode 27.0 meets current and announced rules | https://blakecrosley.com/blog/xcode-27-release |

Relied on from .memlog.md without re-checking (no reason to doubt): the `.clock` App Intents domain needs every
schema; `isExcludedFromBackup` is called a hint; `CA92.1` is the reason code for `UserDefaults`; `BGTaskScheduler` has no
macOS; WWDC25-230 says a pre-alert countdown shows before a fixed alarm fires; Apple has no UUIDv5 API, so
CryptoKit's SHA-1 is used; App Store uploads have needed the iOS 26 SDK since 2026-04-28.
