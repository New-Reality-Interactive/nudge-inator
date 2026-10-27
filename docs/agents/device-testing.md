# Device testing and toolchain reference

Reference moved out of `AGENTS.md`. The rules that change behaviour stay in `AGENTS.md`; this file holds the rationale, the history and the walkthrough procedure.

## Toolchain rationale

Since the pace enhancement's ticket 01 (2026-10-21) the development Mac is an Apple M5 (macOS 26.6) with **Xcode 27.1** (27A9275), the iOS 27.1 SDK and Swift 6.4.

The matrix's simulators were created by hand on that Mac, which is why `scripts/test.sh` picks them by name. The Mac also has `iPhone 15 - iOS 26.1` and `iPhone Duo - iOS 27.1` simulators, left out of the matrix for now (run them with `SIMULATORS`). With 26.1 dropped, nothing runs automatically at the minimum, so a change that leans on an API newer than 26.1 is worth a run there.

### Test iPhones

An iPhone 15 on iOS 27.0.1 ("Brian's iPhone" in `xcrun devicectl list devices`). It is the only one, which is why AGENTS.md's Testing rule checks the iOS 26 path behind `if #available` on the iOS 26.5 simulator. If a phone on iOS 26.x arrives, record it here and change that rule.

### History: the Intel Mac

Until then the project built with **Xcode 26.6 and the iOS 26.5 SDK**, the newest the development Mac (Intel) could run: Apple's Xcode 27 release notes say "Xcode 27 will only install and run on Apple silicon Macs." So there was no iOS 27 SDK or simulator, and the matrix was the iOS 26.1 and 26.5 simulators. Physical-device checks still ran on an iOS 27 iPhone (Xcode 26.6 installs on one).

## AlarmKit alarms survive uninstall

Uninstalling does **not** remove the app's AlarmKit alarms on a device (iPhone 15, iOS 27.0.1; it does in the simulator). Ticket 02's spike left 4,001 behind that survived two uninstalls. So a device test cancels every alarm it schedules, and doesn't assume a fresh install holds none: an apply cancels every alarm of the app's that isn't in its plan, so `AlarmDeviceCheck` first requires the app to hold no alarms. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`), since uninstalling is what resets the answer.

## Simulator media analysis is switched off

The iOS 26.5 simulator's own `mediaanalysisd` (the Photos analysis daemon inside the simulator, not macOS's) ran at 700-870% of a CPU from about 20-60 s after every boot, for as long as the simulator was up. It happened with no app, test or screenshot running (2026-10-18, ticket 29: a boot-only run and an idle Mac were the controls), and it forced a restart of the development Mac. The iOS 26.1 simulator didn't do it. Apple's docs say nothing about it. Nothing in the app uses Photos, Vision or Live Text, so `scripts/test.sh` switches the daemon off in each simulator before testing it (`launchctl disable` and `bootout` through `xcrun simctl spawn`). That persists across boots, and a new or erased simulator needs it again, which the script does. Set `KEEP_MEDIA_ANALYSIS=1` to leave it on, or run `xcrun simctl spawn <udid> launchctl enable system/com.apple.mediaanalysisd` to turn it back on. If the Mac runs hot during simulator work, check `ps -Ao %cpu,comm | grep mediaanalysisd` first, and whether the path is under a `.simruntime`.

## Simulator screenshots

The recipe for a story's visual criteria (AGENTS.md, Testing), and for checking a mockup against the app. `scripts/screenshots.sh` takes a screenshot of every screen on each simulator in the matrix, in portrait, landscape and the largest text size (`accessibility-extra-extra-extra-large`), light appearance:

1. Run `scripts/screenshots.sh`. It writes `docs/screenshots/<today>/<simulator>/<portrait|landscape|largest-text>/<screen>.png` (git-ignored). `SHOTS_OUT` changes the folder, `SHOTS_VARIANTS` runs fewer variants (`SHOTS_VARIANTS=portrait`), and `SIMULATORS` works as in `scripts/test.sh`. The simulators are shot at the same time, each one's variants one after the other, so a run takes as long as the slower simulator plus the build. Each simulator's progress lines start with `[<simulator>]`, and a failure names the simulator and variant. `SHOTS_TESTS` runs only some of the walk's tests (`SHOTS_TESTS="testSettings testForm"`), with a `SHOTS_OUT` of its own, since each variant's folder is emptied first.
   - Which tests a change needs: trace each changed view to the screens that use it, and from them to the `ShotsUITests` methods that reach them. A component in `App/Design/` is traced the same way, to its call sites. Add any screen that shows a string whose value changed. Run the whole walk only for a change with no call sites to trace: the design tokens, a shared view modifier, or the harness's seed. It runs once before the PR, not before review.
2. It builds a throwaway harness from `scripts/screenshots/` into `.build/screenshots`: the app's sources with a stand-in `@main` (`Harness/ShotsApp.swift`) over the test fakes and an in-memory store, seeded with the mockup's reminders, and a UI test (`UITests/ShotsUITests.swift`) that walks the screens. `SHOT_SCENARIO` picks the permissions, one test per scenario: everything allowed, first launch (onboarding), and notifications, alarms or Time Sensitive off (the banners).
3. The real app, its install and its data are never touched. The harness has its own bundle ID, and it and its UI-test runner are uninstalled at the end, and each simulator's text size and appearance are put back, even after a failure or an interrupt (the script stops every simulator's run first, then cleans up).
4. Compare each screenshot with the mockup's screen. `scripts/mockup-shots.py <mockup folder> <out>` takes the mockup's screens under the same names, and `scripts/contact-sheet.sh` puts pairs side by side in one image to view. A screen the walk doesn't reach, add to `ShotsUITests` (and the seed, if it needs data), and to `mockup-shots.py`'s `SCREENS`.

What the harness can't do: the times are now plus or minus the mockup's gaps, so they differ from the mockup's fixed 8:20 AM, and the system's own UI (notifications, the alarm, permission prompts) isn't in it.

Two simulator quirks it works around (iOS 26.5 simulator, Xcode 27.1): in landscape, a tap on a navigation bar button never lands and `swipeUp()` doesn't scroll, though rows and tabs take taps. So bar buttons are tapped after turning the phone to portrait and back, and scrolling is a coordinate drag. The simulator's first keyboard also shows a tip over the sheet, which the walk dismisses. That can't be undone: the tip doesn't come back on that simulator, for any app.

## Manual device checks: build, install, clean up

For checks the person drives by hand (VoiceOver, landscape, tapping through screens), not `-only-testing` runs. Used for ticket 29 on an iPhone 15, iOS 27.0.1; the device id comes from `xcrun devicectl list devices`.

1. Before installing, note whether the app is there: `xcrun devicectl device info apps --device <id> --bundle-id com.newrealityinteractive.nudgeinator` (an empty "Apps installed:" means it isn't).
2. Build: `xcodebuild -project NudgeInator.xcodeproj -scheme NudgeInator -destination 'id=<id>' -derivedDataPath .build/derived-device -allowProvisioningUpdates -quiet build` (`.build` is git-ignored; the first build takes a few minutes).
3. Install and launch: `xcrun devicectl device install app --device <id> .build/derived-device/Build/Products/Debug-iphoneos/NudgeInator.app`, then `xcrun devicectl device process launch --terminate-existing --device <id> com.newrealityinteractive.nudgeinator`. After a code fix, repeat 2 and 3; the install keeps the app's data, so the person doesn't re-enter their test data.
4. The person seeds their own test data by hand; there is no seeding route.
5. Tell the person their starting settings before you ask them to change any (for example text size: Settings > Accessibility > Display & Text Size > Larger Text, noting the notch and whether Larger Accessibility Sizes is on), and have them restore it at the end.
6. Clean up: reminders with Break Through Focus on schedule AlarmKit alarms, and uninstalling doesn't remove those. Ask the person to delete every reminder they made (Done may not cancel the alarm) before you uninstall. If the app wasn't installed at the start, uninstall it with `xcrun devicectl device uninstall app --device <id> com.newrealityinteractive.nudgeinator`, then check with step 1.

Lessons from ticket 29:

- Simulator screenshots missed a failure that only showed on the phone: at the largest text size in landscape the keyboard covered the rename sheet's error. Check landscape plus largest text on the device whenever a sheet has a text field with a message under it.
- A Form section footer sits below its field and goes behind the keyboard; in compact height put such a message in the section header.
- VoiceOver speaks "#" as "number sign".

## Device-check walkthrough

When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time, so none is missed. For each check:

1. Say what it checks, what they'll do and when (prompts to answer, what to tap), and the longest it can take.
2. Confirm the `-only-testing` filter matches that one test without touching the phone. Swift Testing's identifier ends in `()`. A run that matches no test still launches the app, and a prompt it shows vanishes when the run ends.
3. Wait for their go, then run it.
4. Report the result and confirm it with them before the next check.

If a run doesn't do what you said it would, stop and explain before running anything else. Once the last check is done, list every check and its result, so the person can see none is left.

A check that runs the app's model sets the Icon badge from its own store, and the badge can't be read back to restore it. If the app was installed before the run, have the person open it once at the end: App opened sets their own count again.
