# nudge-inator
iOS application that nudges you about Reminders and Alarms.

## Requirements

iPhone only, **iOS 26.1 or later**. Built with **Xcode 27.x** (iOS 27 SDK) on an Apple silicon Mac.

The command line must use Xcode, not the Command Line Tools: `xcode-select -p` should print `/Applications/Xcode.app/Contents/Developer`. If it prints `/Library/Developer/CommandLineTools`, `xcodebuild`, `simctl` and `devicectl` aren't found; run `sudo xcode-select -s /Applications/Xcode.app` (or set `DEVELOPER_DIR` to that path).

After cloning, turn on the repo's git hooks (they check commit messages): `git config core.hooksPath .githooks`.

## Run the tests

```sh
scripts/test.sh
```

Tests the `NudgeEngine` package on macOS, then builds the app once with `build-for-testing` and runs its tests with `test-without-building` on each simulator in the test matrix (the `SIMULATORS` default at the top of the script; the rule is AGENTS.md's Testing section). The widget extension is built along with the app. Exits non-zero on any failure, and also fails if `NudgeEngine` imports anything but Foundation.

CI (`.github/workflows/checks.yml`) runs `SIMULATORS= scripts/test.sh`: with `SIMULATORS` set but empty, only the steps that need no simulator run (the engine, its imports, the color sets), since GitHub's runners don't have the named simulators. The full suite is a local run.

The simulators are chosen by their exact names: `SIMULATORS`, separated by `;` (for example `SIMULATORS="iPhone 15 - iOS 26.1" scripts/test.sh`). The script fails with a hint if one is missing. Create one with `xcrun simctl create "iPhone 15 Pro - iOS 26.5" "iPhone 15 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5`, after installing its runtime with `xcodebuild -downloadPlatform iOS -buildVersion 26.5` or in Xcode > Settings > Components.

## VS Code

`.vscode/` recommends the extensions (Swift, LLDB DAP, YAML) and keeps build output out of search and the file watcher. The Swift extension understands the two packages on its own. For the app, widget and test targets, which live in the generated Xcode project, it needs **xcode-build-server**, which hands it the flags from the last build:

```sh
brew install xcode-build-server
xcode-build-server config -project NudgeInator.xcodeproj -scheme NudgeInator --build_root "$PWD/.build/derived"
scripts/test.sh
```

`buildServer.json` is machine-specific and git-ignored. The server reads the newest build log under `.build/derived`, so after adding a file or changing `project.yml`, run `scripts/test.sh` (or any build into that folder) for the editor to see it. If completion still falls back to plain Swift, seed it from the full build once: `xcode-build-server parse -a -l <the newest .xcactivitylog under .build/derived/Logs/Build> -o <the compile_file under ~/Library/Caches/xcode-build-server>`.

## Project layout

- `project.yml`: the project definition. The project uses **XcodeGen**, so `NudgeInator.xcodeproj` is generated and git-ignored. Run `xcodegen generate` (`scripts/test.sh` does it for you) after editing `project.yml` or adding files.
- `Packages/NudgeEngine`: the pure-Swift nudge engine and its tests.
- `Packages/NudgeShared`: code compiled into both the app and the widget extension (AlarmKit metadata and the Open intent, later).
- `App/`: the SwiftUI app. `NudgeWidgets/`: the empty widget extension. `NudgeInatorTests/`: app-level tests.
- App Group: `group.com.newrealityinteractive.nudgeinator`, shared by the app and the extension.

## Signing

Device builds sign automatically with the team in `project.yml` (`DEVELOPMENT_TEAM`, New Reality Interactive). The entitlements are declared there too: the App Group above in the app and the widget extension, and Time Sensitive notifications in the app. Don't edit the `.entitlements` files, because `xcodegen generate` rewrites them from `project.yml`.

The first device build on a new Mac or iPhone needs the phone connected with Developer Mode on (Settings > Privacy & Security), then:

```sh
xcodebuild -scheme NudgeInator -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

That registers the iPhone with the team and creates the App IDs, the App Group and the Time Sensitive capability, so none of them need setting up by hand on the developer website. Simulator builds and tests need no signing.
