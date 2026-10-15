Status: ready-for-agent

# Create the Xcode project with a scripted test run

Spec: `../spec.md`. Glossary: `/GLOSSARY.md`.

## What to build

An empty Nudge-inator iPhone app that builds, plus a way to run all unit tests from one command, with no Xcode UI.

- SwiftUI app target, **iOS 26.1 minimum** (raised from 26.0: AlarmKit's non-deprecated `Alert` initializer is iOS 26.1+, and 26.1 is the oldest version the tests run on), iPhone only (no iPad, no iOS 18 variants).
- The nudge engine lives in a **local Swift package** (`NudgeEngine`, no Apple framework imports, so it also builds and tests on macOS) with its own test target. The app target depends on it.
- An app-level unit-test target for the code that does touch Apple frameworks (store, adapters).
- `scripts/test.sh` runs the package tests (`swift test`) and the app tests (`xcodebuild test` against iOS 26 simulators), prints a pass/fail summary and exits non-zero on any failure. The simulator is chosen by name from an env var with a default, not by a hard-coded UUID. The app tests run against **both** the iOS 26.1 and iOS 26.5 simulators (a list in an env var with that default); a missing runtime is a failure with an install hint.
- A **widget extension target** (iOS 26, iPhone only), empty for now: no widgets and no Live Activity content. It exists because AlarmKit expects one (see "Extension decision"), and so a later version can add widgets without a project migration.
- An **App Group** shared by the app and the extension (the store in ticket 17 will live in its container), and a small shared module (framework or package) for code both targets compile: the AlarmKit `AlarmMetadata` type and the Open intent (ticket 20). `NudgeEngine` stays pure and separate.
- `NSAlarmKitUsageDescription` and the Time Sensitive capability are set up (needed by later tickets).
- Keep the project definition reproducible: either a checked-in `project.yml` for XcodeGen (installed at `/usr/local/bin/xcodegen`) or a hand-kept `.xcodeproj`. Pick one and note it in a short `README` section.

### Extension decision

Decided: the project includes a widget extension, empty in the first version. Apple's AlarmKit sample says "AlarmKit expects a widget extension if an app supports a countdown presentation. Otherwise, the system may unexpectedly dismiss alarms and fail to alert." Our alarms are alert-only, so the docs don't strictly require it; having it removes that risk and leaves room for v2 candidates (a Now widget, a countdown Live Activity), listed under the spec's "Candidates for a later version". Ticket 02 checks on a device that alert-only alarms behave with the extension present.

Docs: <https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit>, <https://developer.apple.com/videos/play/wwdc2025/230>.

## Acceptance criteria

- [x] `xcodebuild -scheme <app> -destination 'generic/platform=iOS' build` succeeds.
- [x] Deployment target is iOS 26.1 and the device family is iPhone only.
- [x] The widget extension target builds and is embedded in the app; the app and extension share an App Group (entitlement present in both).
- [x] The shared module compiles into both targets, and `scripts/test.sh` also builds the extension.
- [x] A placeholder test in the package and one in the app test target both exist and pass.
- [x] `scripts/test.sh` from a clean checkout runs both and exits 0; with a deliberately failing test it exits non-zero (check, then revert).
- [x] `NudgeEngine` has no `import` of any Apple framework (`Foundation` only, if needed), checked by a grep in `scripts/test.sh` or a comment-documented rule.
- [x] `Info.plist` has a non-empty `NSAlarmKitUsageDescription`.
- [x] README states the one command to run tests.
- [x] The app target bundles the Icon Composer file `App/AppIcon.icon`, and `ASSETCATALOG_COMPILER_APPICON_NAME` in `project.yml` is `AppIcon`. There is no `AppIcon` asset catalog.
- [x] On the iPhone 15 simulator, the icon looks right in the Default, Dark, Clear and Tinted Home Screen appearances.
- [x] Device check: the icon looks right on a physical iPhone in all four appearances, in a folder and at small sizes (Spotlight, Settings). Record the iOS version. (iPhone 15, iOS 27.0.1: looks right in all of them.)

## Entitlements and signing

Added after approval into the Apple Developer Program (team `B9QHGF334U`, New Reality Interactive, LLC). `project.yml` declares the entitlements under each target's `entitlements.properties`, because `xcodegen generate` rewrites the `.entitlements` files from there: `com.apple.security.application-groups` (`group.com.newrealityinteractive.nudgeinator`) in the app and the extension, and `com.apple.developer.usernotifications.time-sensitive` in the app. Signing is automatic with `DEVELOPMENT_TEAM` set in the project's base settings.

The signed `generic/platform=iOS` build succeeds after registering an iPhone 15 on iOS 27.0.1 (connect it, turn on Developer Mode, then build once with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration` so Xcode registers the device, App IDs, App Group and Time Sensitive). `codesign -d --entitlements` on the signed app and extension shows team `B9QHGF334U`, the App Group in both, and Time Sensitive in the app. The app installs and launches on that iPhone.

Blocked by: none
