# nudge-inator
iOS application that nudges you about Reminders and Alarms.

## Requirements

iPhone only, **iOS 26.1 or later**. Automated tests run on the 26.1 and 26.5 simulators. Device checks run on a physical iPhone (record its iOS version).

## Run the tests

```sh
scripts/test.sh
```

Runs `swift test` for the `NudgeEngine` package, then `xcodebuild test` for the app on **both** the iOS 26.1 and iOS 26.5 simulators (the oldest and the newest we test on; run every automated test against both). The widget extension is built along with the app. Exits non-zero on any failure, and also fails if `NudgeEngine` imports anything but Foundation.

The simulator is chosen by name: `SIMULATOR_NAME` (default `iPhone 17`). The iOS versions are `SIMULATOR_OSES`, a space-separated list (default `26.1 26.5`); the script fails with an install hint if a runtime is missing. Install one with `xcodebuild -downloadPlatform iOS -buildVersion 26.1`, or in Xcode > Settings > Components > Add Platforms. Don't pick an iOS 18 simulator.

## Project layout

- `project.yml`: the project definition. The project uses **XcodeGen**, so `NudgeInator.xcodeproj` is generated and git-ignored. Run `xcodegen generate` (`scripts/test.sh` does it for you) after editing `project.yml` or adding files.
- `Packages/NudgeEngine`: the pure-Swift nudge engine and its tests.
- `Packages/NudgeShared`: code compiled into both the app and the widget extension (AlarmKit metadata and the Open intent, later).
- `App/`: the SwiftUI app. `NudgeWidgets/`: the empty widget extension. `NudgeInatorTests/`: app-level tests.
- App Group: `group.com.newrealityinteractive.nudgeinator`, shared by the app and the extension.

## Signing

Device builds need a development team. Set `DEVELOPMENT_TEAM` in `project.yml`, and register the App Group above for both bundle IDs. Simulator builds and tests need neither.
