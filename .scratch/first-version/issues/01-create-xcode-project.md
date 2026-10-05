Status: ready-for-agent

# Create the Xcode project with a scripted test run

Spec: `../spec.md`. Glossary: `/CONTEXT.md`.

## What to build

An empty Nudge-inator iPhone app that builds, plus a way to run all unit tests from one command, with no Xcode UI.

- SwiftUI app target, **iOS 26.1 minimum** (raised from 26.0: AlarmKit's non-deprecated `Alert` initializer is iOS 26.1+, and 26.1 is the oldest version the tests run on), iPhone only (no iPad, no iOS 18 variants).
- The nudge engine lives in a **local Swift package** (`NudgeEngine`, no Apple framework imports, so it also builds and tests on macOS) with its own test target. The app target depends on it.
- An app-level unit-test target for the code that does touch Apple frameworks (store, adapters).
- `scripts/test.sh` runs the package tests (`swift test`) and the app tests (`xcodebuild test` against iOS 26 simulators), prints a pass/fail summary and exits non-zero on any failure. The simulator is chosen by name from an env var with a default, not by a hard-coded UUID. The app tests run against **both** the iOS 26.1 and iOS 26.5 simulators (a list in an env var with that default); a missing runtime is a failure with an install hint.
- A **widget extension target** (iOS 26, iPhone only), empty for now: no widgets and no Live Activity content. It exists because AlarmKit expects one (see "Extension decision"), and so a later version can add widgets without a project migration.
- An **App Group** shared by the app and the extension (the store in ticket 16 will live in its container), and a small shared module (framework or package) for code both targets compile: the AlarmKit `AlarmMetadata` type and the Open intent (ticket 19). `NudgeEngine` stays pure and separate.
- `NSAlarmKitUsageDescription` and the Time Sensitive capability are set up (needed by later tickets).
- Keep the project definition reproducible: either a checked-in `project.yml` for XcodeGen (installed at `/usr/local/bin/xcodegen`) or a hand-kept `.xcodeproj`. Pick one and note it in a short `README` section.

### Extension decision

Decided: the project includes a widget extension, empty in the first version. Apple's AlarmKit sample says "AlarmKit expects a widget extension if an app supports a countdown presentation. Otherwise, the system may unexpectedly dismiss alarms and fail to alert." Our alarms are alert-only, so the docs don't strictly require it; having it removes that risk and leaves room for v2 candidates (a Now widget, a countdown Live Activity), listed under the spec's "Candidates for a later version". Ticket 02 checks on a device that alert-only alarms behave with the extension present.

Docs: <https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit>, <https://developer.apple.com/videos/play/wwdc2025/230>.

## Acceptance criteria

- [ ] `xcodebuild -scheme <app> -destination 'generic/platform=iOS' build` succeeds.
- [x] Deployment target is iOS 26.1 and the device family is iPhone only.
- [ ] The widget extension target builds and is embedded in the app; the app and extension share an App Group (entitlement present in both).
- [x] The shared module compiles into both targets, and `scripts/test.sh` also builds the extension.
- [x] A placeholder test in the package and one in the app test target both exist and pass.
- [x] `scripts/test.sh` from a clean checkout runs both and exits 0; with a deliberately failing test it exits non-zero (check, then revert).
- [x] `NudgeEngine` has no `import` of any Apple framework (`Foundation` only, if needed), checked by a grep in `scripts/test.sh` or a comment-documented rule.
- [x] `Info.plist` has a non-empty `NSAlarmKitUsageDescription`.
- [x] README states the one command to run tests.

## Deferred: entitlements

The App Group and Time Sensitive entitlements are not added yet. They wait on approval into the Apple Developer Program. Until then both `.entitlements` files stay empty, and the "entitlement present in both" criterion above stays open. Apple's docs don't say whether these capabilities work with a free Personal Team, so check that on a device once approved. When approved: add `com.apple.security.application-groups` (`group.com.newrealityinteractive.nudgeinator`) to both entitlements files and `com.apple.developer.usernotifications.time-sensitive` to the app's, then tick the criterion.

Blocked by: none
