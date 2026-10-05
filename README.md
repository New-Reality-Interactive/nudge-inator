# nudge-inator
iOS application that nudges you about Reminders and Alarms.

## Run the tests

```sh
scripts/test.sh
```

Runs `swift test` for the `NudgeEngine` package, then `xcodebuild test` for the app on an iOS 26 simulator. The widget extension is built along with the app. Exits non-zero on any failure, and also fails if `NudgeEngine` imports anything but Foundation.

The simulator is chosen by name: `SIMULATOR_NAME` (default `iPhone 17`) and `SIMULATOR_OS` (default `26.5`). Don't pick an iOS 18 simulator.

## Project layout

- `project.yml`: the project definition. The project uses **XcodeGen**, so `NudgeInator.xcodeproj` is generated and git-ignored. Run `xcodegen generate` (`scripts/test.sh` does it for you) after editing `project.yml` or adding files.
- `Packages/NudgeEngine`: the pure-Swift nudge engine and its tests.
- `Packages/NudgeShared`: code compiled into both the app and the widget extension (AlarmKit metadata and the Open intent, later).
- `App/`: the SwiftUI app. `NudgeWidgets/`: the empty widget extension. `NudgeInatorTests/`: app-level tests.
- App Group: `group.com.newrealityinteractive.nudgeinator`, shared by the app and the extension.

## Signing

Device builds need a development team. Set `DEVELOPMENT_TEAM` in `project.yml`, and register the App Group above for both bundle IDs. Simulator builds and tests need neither.
