# 01: Toolchain: Xcode 27.x and the 26.5 + 27.x simulators

**What to build:** The project moves to the new development Mac, which runs Xcode 27.x. The automated tests run on the iOS 26.5 simulator and the newest iOS 27.x simulator that Mac's Xcode offers, and no longer on 26.1. The project's written rules (AGENTS.md's Toolchain and Testing sections, `docs/agents/device-testing.md`) describe the new setup, so every later ticket works to it. The app's minimum stays iOS 26.1. Spec: `.scratch/enhancement-pace/spec.md`, Testing Decisions.

**Blocked by:** None (can start immediately, on the new Mac).

**Status:** resolved

- [x] The project builds with the new Mac's Xcode 27.x; the Xcode and SDK versions found there are recorded in this ticket's Comments.
- [x] The test script's default simulators are `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` (reworded from "the newest installed iOS 27.x": see Comments), and the full suite passes on both (counts recorded).
- [x] The deployment target is still iOS 26.1.
- [x] AGENTS.md's Toolchain rule names Xcode 27.x and the iOS 27 SDK, and says an iOS 27-only API is allowed only behind `if #available` with an iOS 26 path.
- [x] AGENTS.md's Testing rule names the 26.5 and 27.x simulators (26.1 dropped for now), and says a story that changes something on screen is checked on both simulators first, after which the person is offered a run on a physical iPhone and decides.
- [x] The device-testing doc records the one test iPhone for now, on iOS 27.x (reworded from two phones: see Comments): a device check names which phone it ran on, and the iOS 26 path of anything behind `if #available` is checked on the iOS 26.5 simulator until there is a 26.x phone. Its rationale for the old Intel Mac toolchain is kept as history.
- [x] Any new compiler warnings or test failures under Xcode 27.x are fixed or listed in Comments with a reason.

## Comments

**2026-10-21, the new Mac.** Apple M5, macOS 26.6 (25G72). Xcode 27.1 (27A9275), iOS 27.1 SDK (device and simulator), Swift 6.4 (swiftlang-6.4.0.34.1). XcodeGen 2.46.0. Simulator runtimes installed: iOS 26.1, 26.5, 27.0 and 27.1. Connected: one iPhone 15 (iPhone15,4) on iOS 27.0.1 (24A446). `xcode-select -p` printed `/Library/Developer/CommandLineTools`, where `xcodebuild`, `simctl` and `devicectl` aren't found, so the runs here set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. AGENTS.md, the README and the device-testing doc say to select Xcode. The developer then ran `sudo xcode-select -s /Applications/Xcode.app`. Rechecked with no `DEVELOPER_DIR`: `xcode-select -p` prints `/Applications/Xcode.app/Contents/Developer`, `xcodebuild -version` reports 27.1 (27A9275), and `simctl` and `devicectl` resolve inside Xcode.app.

**Criteria changed, agreed with the developer (2026-10-21).**
- Matrix: the developer chose `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0`, not the newest 27.x (27.1, which has only `iPhone Duo` simulators). The `iPhone 15 - iOS 26.1` and `iPhone Duo - iOS 27.1` simulators stay on the Mac outside the matrix. The spec's Testing Decisions line now names the two.
- Test iPhones: only one phone for now, the iPhone 15 on iOS 27.0.1. The iOS 26 path behind `if #available` is checked on the iOS 26.5 simulator until a 26.x phone exists.

**Script.** `scripts/test.sh` now picks simulators by exact name (`SIMULATORS`, `;`-separated) and runs each by UDID, since the Mac's simulators are named per OS (`iPhone 15 - iOS 27.0`) and the old default, `iPhone 17` at a given OS, has no iOS 27.1 simulator. `SIMULATOR_NAME` and `SIMULATOR_OSES` are gone. Xcode 27 names a package target's build folder `NudgeEngine-t.build` (Xcode 26: `NudgeEngine.build`), so `scripts/sync-strings.sh` found no engine `.stringsdata` and the catalog check failed. It now looks for both.

**Fixed under Xcode 27.1 / Swift 6.4.**
- Build error: `BreakThroughFocusTests.switchOnDeliversEachNudgeByItsUrgency`'s `@Test(arguments:)` literal hit "unable to type-check this expression in reasonable time". The cases moved to a typed `static let`.
- `SettingsRow`: `alignmentGuide`'s closure is `Sendable` in the new SDK, so reading `dynamicTypeSize` and `scaledTile` in it warned. The inset is now computed in `body` and captured, with the same values (0 at accessibility sizes, tile + `s3` otherwise). There was no visual check, since the inset math is unchanged.
- `ColorSetTests`: setting `UIMutableTraits` in `UITraitCollection(mutations:)` from a nonisolated test warned. The test is now `@MainActor`. Apple's docs show `TraitMutations` as a plain non-escaping closure and say nothing about isolation.
- `ReminderFormTests.theCustomPageShowsAnExistingCustomRepeat`: "`#require` is redundant". Passed inline to the optional `repeatRule:`, it inferred an optional result, so it unwrapped nothing, and a `nil` rule would have passed silently. It's on its own line now.
- Three `var intent` in `AppModelTests` and `OpenReminderIntentTests` became `let`: the new SDK's `@Parameter` and `@Dependency` setters don't mutate.

**Run (clean build, `scripts/test.sh`).** 238 engine tests on macOS; 299 app tests in 33 suites on `iPhone 15 Pro - iOS 26.5` and on `iPhone 15 - iOS 27.0`; color sets, imports and String Catalogs pass. No compiler warnings left. The only one is appintentsmetadataprocessor's note for the engine package, which has no App Intents. Before the matrix was settled, an earlier run also passed 299 on the 26.1, 26.5 (iPhone 15), 27.0 and 27.1 simulators.

**Review (2026-10-21, `code-review` from 0084efd).** Standards: no breaches; five judgement calls, all fixed: test.sh's mediaanalysisd comment had drifted above `simulator_udid`, each UDID was looked up twice, the missing-simulator hint always named the iPhone 15 Pro on 26.5, the README still described one `xcodebuild test` per simulator, and the spec's visual-check line still said "the newest iOS 27.x". Spec skipped: every criterion ticked and the change mechanical (review.md). After the fixes: 238 engine tests, 299 app tests on each simulator.
