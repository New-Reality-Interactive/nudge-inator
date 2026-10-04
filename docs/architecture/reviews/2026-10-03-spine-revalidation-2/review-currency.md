# Currency review — ARCHITECTURE-SPINE.md @ 8c2ce98

- **Lens:** every committed decision is web-researched or reality-checked (versions, existence, fit), not asserted from training data.
- **Date:** 2026-10-03
- **Sources used:** Apple's live documentation JSON (`developer.apple.com/tutorials/data/documentation/<path>.json`), apple-rag-mcp (docs and WWDC transcripts), Apple Developer Releases page, `gh` against GitHub (GRDB, actions/runner-images, swift-testing, swift-evolution, as19git67/fk-encore), local `xcodebuild -help` (Xcode 26.6), web search.
- **Verdict:** **PASS with minor findings.** Nothing found would make a unit fail to build or behave against the brief. One medium: an AlarmKit API split inside iOS 26 that neither the spine nor the memlog records. Three lows.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 1 |
| Low | 3 |

## Findings

### M1 — AlarmKit's alert presentation splits at iOS 26.1, and neither the spine nor the memlog records it

- **Location:** AD-18 (AlarmKit "behind `@available(iOS 26, *)`"), AD-12 (every alarm's configuration and secondary button), Stack ("AlarmKit … iOS 26.0+").
- **Claim:** AlarmKit is one iOS 26.0+ surface, so a single `@available(iOS 26, *)` boundary covers the adapter.
- **Evidence:** `AlarmPresentation.Alert.init(title:stopButton:secondaryButton:secondaryButtonBehavior:)` is iOS 26.0 and **deprecated in 26.1** ("stopButton is deprecated and will no longer be used"). Its replacement, `init(title:secondaryButton:secondaryButtonBehavior:)`, is **iOS 26.1+**. A crawl of all 128 AlarmKit doc pages found no other AlarmKit symbol that is newer than 26.0 or deprecated, apart from the iOS 27 `appEntityIdentifier` overloads, which Deferred already covers.
  - https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct/init(title:stopbutton:secondarybutton:secondarybuttonbehavior:)
  - https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct/init(title:secondarybutton:secondarybuttonbehavior:)
- **Impact:** with a deployment target of iOS 18 and AlarmKit used from 26.0, the adapter must either call the deprecated initializer (which produces a deprecation warning and fails the build if warnings are treated as errors) or branch on `#available(iOS 26.1, *)`. On 26.0 the stop button is configured by the app. On 26.1 and later the system supplies it. The AD-12 rule ("intents only submit commands", stop submits `done(source: .alarm)`) does not depend on the button's look, so behavior holds either way. That is why this is not high. The adapter's hash input (AD-7: "presentations") also differs between the two initializers, which is harmless because IDs never get reused.
- **Fix:** add one line to AD-18: inside the AlarmKit adapter, build the alert with `init(title:secondaryButton:secondaryButtonBehavior:)` under `#available(iOS 26.1, *)`, and use the deprecated stop-button initializer only on 26.0. Alternatively, raise AlarmKit's floor to 26.1 and treat 26.0 as "alarms unavailable" (AD-11). Log the choice and its source in the memlog.

### L1 — `NSCurrentLocaleDidChange` isn't the API's name

- **Location:** AD-6 › Triggers.
- **Claim:** reconcile on `NSCurrentLocaleDidChange`.
- **Evidence:** the Foundation symbol is `NSLocale.currentLocaleDidChangeNotification` (iOS 2.0+). `NSSystemTimeZoneDidChange` in the line above is correct as written (`NSNotification.Name.NSSystemTimeZoneDidChange`).
  - https://developer.apple.com/documentation/foundation/nslocale/currentlocaledidchangenotification
  - https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemtimezonedidchange
- **Fix:** write `NSLocale.currentLocaleDidChangeNotification`.

### L2 — The iOS 18 runtime pin is a placeholder, the memlog says otherwise, and an arm64 variant for iOS 18 is unconfirmed

- **Location:** Structural Seed › Environments › CI (`-buildVersion <version> -architectureVariant arm64`).
- **Claim:** the memlog (gate, currency lows) says "the CI step pins a real iOS 18 runtime version instead of '18.x'", but the spine still shows `<version>`. The spine also passes `-architectureVariant arm64` for every leg.
- **Evidence:** both flags exist (`xcodebuild -help` on Xcode 26.6: `-downloadPlatform … -buildVersion <osversion> -architectureVariant <universal|arm64>`, and `-importPlatform`). No source checked here confirms that Apple publishes an arm64-only variant of an iOS 18 simulator runtime. Forum reports describe arm64-only runtimes for iOS 26.x, and "not available" errors fixed by switching variant (https://developer.apple.com/forums/thread/812146). The `xcode-27` image ships only iOS 27.0, 27.1 and 27.2 simulators (https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
- **Impact:** small. The spine already falls back to `-importPlatform`, and then to the device checklist.
- **Fix:** name the iOS 18 and iOS 26 runtime versions, or say the workflow's author picks them and records them in `ci.yml`. Allow `-architectureVariant universal` for the iOS 18 leg if `arm64` isn't offered. Make the memlog and the spine agree.

### L3 — "CryptoKit's SHA-1" should name `Insecure.SHA1`

- **Location:** AD-7 › AlarmKit IDs.
- **Evidence:** CryptoKit's SHA-1 lives at `Insecure.SHA1` (iOS 13.0+). It's correct for UUIDv5 (RFC 9562 §5.5) and not a security use. https://developer.apple.com/documentation/cryptokit/insecure/sha1
- **Fix:** optional. Name `Insecure.SHA1` so nobody reaches for a third-party hash or `CC_SHA1`.

## Confirmed (with source)

**Toolchain and dependencies**
- **Xcode 27.0 (27A266a):** released 2026-09-14. It is the current release (27.1 and 27.2 are still beta). https://developer.apple.com/news/releases/
- **Swift 6.4:** ships with the Xcode 27 line (confirmed for the 27.1 beta notes; the memlog records it for 27.0). https://developer.apple.com/news/releases/?id=09182026a
- **GRDB.swift 7.11.1:** still the latest release (2026-06-18; no newer tag as of 2026-10-03). `gh release list -R groue/GRDB.swift`
- **GRDB #1888** (SharedValueObservation deadlock): still **open**. https://github.com/groue/GRDB.swift/issues/1888
- **GRDB #1875** (UI tests crash on Xcode 27 beta 4): closed 2026-09-27. https://github.com/groue/GRDB.swift/issues/1875
- **GitHub `xcode-27` runner label:** exists and is a public preview (runner-images README and issue #14404). Its default Xcode is 27.0 (27A266a), matching the pin. It has only iOS 27.x simulators. https://github.com/actions/runner-images/issues/14404
- **`xcodebuild -downloadPlatform … -buildVersion … -architectureVariant`** and **`-importPlatform`** exist (local `xcodebuild -help`, Xcode 26.6). Xcode 27 wasn't available locally to check, so this rests on the earlier version.
- **Swift Testing has no performance API:** swift-testing issue #492 is still open, and none of swift-evolution testing proposals 0001–0029 adds one. https://github.com/swiftlang/swift-testing/issues/492
- **First-spike source:** as19git67/fk-encore PR #1271, merged 2026-09-18. Package intents were missing from the archive and TestFlight build, as the spine says. https://github.com/as19git67/fk-encore/pull/1271

**AlarmKit (all iOS 26.0, not beta, not deprecated unless noted)**
- `AlarmManager.alarms`, `alarmUpdates`, `authorizationUpdates`, `AlarmManager.AlarmError.maximumLimitReached`, `AuthorizationState` (`.authorized`, `.denied`, `.notDetermined`).
- `Alarm.Schedule.fixed(_:)`, `Alarm.State.countdown`, `Alarm.CountdownDuration.postAlert`, `AlarmPresentation.Alert.SecondaryButtonBehavior` (`.countdown`, `.custom`), `AlarmAttributes`, `AlarmMetadata`.
- `AlarmManager.AlarmConfiguration` keeps `stopIntent` and `secondaryIntent` on every initializer. Its overview says only the secondary intent "is only available after first unlock".
- Framework platforms: iOS, iPadOS and Mac Catalyst only (no macOS). This supports the decision not to run tests on macOS.

**App Intents**
- `AppIntent.allowedExecutionTargets`: iOS 27.0, not beta.
- `AppIntentsPackage`: iOS 17.0. `LiveActivityIntent`: iOS 17.0. `AppDependencyManager`: iOS 16.0.
- WWDC26 session 345, "Discover new capabilities in the App Intents framework", says the system picks the app if it's running and otherwise launches the extension for intents in a shared package, and that ExecutionTargets overrides this. https://developer.apple.com/videos/play/wwdc2026/345/
- The `.clock` domain requires every schema in the group, which Xcode validates at build time. https://developer.apple.com/documentation/appintents/app-schema-domain-clock
- WWDC26 session 278 is "Modernize your UIKit app" and exists. https://developer.apple.com/videos/play/wwdc2026/278/

**UIKit, SwiftUI and Accessibility**
- **Scene life cycle required with the iOS 27 SDK** ("apps built with the latest SDK must adopt the scene-based life cycle or they fail to launch"). https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle
- `tabBarMinimizeBehavior(_:)`, `navigationSubtitle(_:)` and the SwiftUI `AssistiveAccess` scene: iOS 26.0.
- `AccessibilitySettings.isAssistiveAccessEnabled`: iOS 18.0.
- `UIApplication.significantTimeChangeNotification` and `protectedDataDidBecomeAvailableNotification` exist.

**UserNotifications**
- `UNNotificationCategoryOptions.customDismissAction` and `UNCalendarNotificationTrigger.nextTriggerDate()`: iOS 10.

**Info.plist keys**
- `NSAlarmKitUsageDescription`: iOS 26.0. `UISupportsAssistiveAccess`: iOS 26.0. `UISupportsFullScreenInAssistiveAccess`: iOS 17.0, so it covers the iOS 18 full-screen path. `NSSupportsLiveActivities`: iOS 16.1.

**Other platform APIs**
- `BGTaskScheduler`: iOS, iPadOS, Mac Catalyst, tvOS and visionOS, with no macOS. ActivityKit: iOS, iPadOS and Mac Catalyst, with no macOS.

**Relied on from the memlog's recorded checks (not re-run):** `Tab(role: .search)` iOS 18; the nil trigger delivering at once; `isExcludedFromBackup` wording; `PrivacyInfo` reason CA92.1, and GRDB's manifest with no required-reason APIs; `SceneBuilder.buildLimitedAvailability` iOS 16.1; `appEntityIdentifier` not beta; App Store's iOS 26 SDK requirement since 2026-04-28.

**Spot-checked against the memlog:** GRDB 7.11.1, #1888, #1875, `allowedExecutionTargets`, `isAssistiveAccessEnabled`, the WWDC26-345 claim, the `xcode-27` preview label, and the fk-encore PR. All matched.
