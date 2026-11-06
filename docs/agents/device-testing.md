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

The recipe for a story's visual criteria (AGENTS.md, Testing), and for checking a mockup against the app. `scripts/screenshots.sh` takes a screenshot of every screen on each simulator in the matrix, in portrait, landscape and the largest text size (`accessibility-extra-extra-extra-large`), light appearance. The iOS 26.5 simulator skips landscape: it doesn't turn for the UI test, so every "landscape" shot it took was portrait (#109, 2026-10-30, three runs), and landscape is checked on iOS 27.0 alone:

1. Run `scripts/screenshots.sh`. It writes `docs/screenshots/<today>/<simulator>/<variant>/<screen>.png` (git-ignored), the variant being `portrait`, `landscape` or `largest-text`, or one of those with an `rtl-` prefix (below). `SHOTS_OUT` changes the folder, `SHOTS_VARIANTS` runs fewer variants (`SHOTS_VARIANTS=portrait`), and `SIMULATORS` works as in `scripts/test.sh`. The simulators are shot at the same time, each one's variants one after the other, so a run takes as long as the slower simulator plus the build. Each simulator's progress lines start with `[<simulator>]`, and a failure names the simulator and variant. Each variant's folder is emptied first, unless `SHOTS_TESTS` names the tests to run (`SHOTS_TESTS="testSettings testForm"`): then the other tests' images stay, so one test can be rerun alone, and the run lists the images it wrote, since those kept may be older than the code.
   - Which variants, and when (Brian's trial from #140; #139 took about 15 runs for one app bug, found at the largest text):
     - While building: iOS 27.0 alone, `SHOTS_VARIANTS="largest-text portrait"`. Largest text comes first because it finds the most, app bugs and test problems alike. A new UI test runs this way before anything wider.
     - Final pass, before the iPhone run, so the phone gets the final code: only the tests the change touches, on iOS 26.5 with `SHOTS_VARIANTS="portrait largest-text"` and on iOS 27.0 with `SHOTS_VARIANTS=landscape`. Fix and re-test anything it finds.
     - Landscape is skipped only for a change that alters no layout and no text on screen, such as logic alone. The PR says so.
     - Once per release, not per ticket: the right-to-left pass (Brian's call, #122). `SHOTS_VARIANTS=rtl` runs the whole walk under Xcode's Right-to-Left Pseudolanguage, on both simulators: `rtl-portrait`, `rtl-largest-text`, and `rtl-landscape` on iOS 27.0 only, as for the other variants. Any variant takes the `rtl-` prefix (`SHOTS_VARIANTS=rtl-portrait`) to rerun one. The app stays in English with its layout mirrored. Look for: the layout mirrored (back buttons, row content and swipe actions on the opposite side from the left-to-right shots); chevrons and arrows pointing the way the layout runs (a row's disclosure chevron points left, a Back chevron right); nothing clipped or overlapping, at the largest text especially. A direction-specific symbol that doesn't flip, or a fixed `.leading`/`.trailing` that should have been `left`/`right` (or the reverse), shows here and nowhere else, since the app ships only in English. It runs from `release.md`'s release PR step, last, so it covers every screen of the release.
     - A criterion about a transition, which no screenshot shows: record it with `xcrun simctl io <simulator> recordVideo <file>` and show the person, or check it on the phone. Say what a transition does only once it has been seen.
   - Why these two simulators: App Store Connect's beta testers (1.2.0, 2026-11-01) split evenly by device between iOS 26.6.x and iOS 27.0.1. iOS 27.0 matches the second group. This Mac has no iOS 26.6 runtime, so iOS 26.5 is the nearest to the first.
   - Which tests a change needs: trace each changed view to the screens that use it, and from them to the `ShotsUITests` methods that reach them. A component in `App/Design/` is traced the same way, to its call sites. Add any screen that shows a string whose value changed. Run the whole walk only for a change with no call sites to trace: the design tokens, a shared view modifier, or the harness's seed. It runs once before the PR, not before review.
   - Debugging a failed run: rerun only the failing test, on the one simulator and variant that failed (`SHOTS_TESTS`, `SIMULATORS`, `SHOTS_VARIANTS`). A row below the fold or a chip with no hit point fails only at the largest text (#116, three runs).
2. It builds a throwaway harness from `scripts/screenshots/` into `.build/screenshots`: the app's sources with a stand-in `@main` (`Harness/ShotsApp.swift`) over the test fakes and an in-memory store, seeded with the mockup's reminders, and a UI test (`UITests/ShotsUITests.swift`) that walks the screens. `SHOT_SCENARIO` picks the permissions, one test per scenario: everything allowed, first launch (onboarding), and notifications, alarms or Time Sensitive off (the banners).
3. The real app, its install and its data are never touched. The right-to-left variants change nothing on the simulator: the walk passes the pseudolanguage to the harness app as launch arguments (`-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`, the ones Xcode's scheme option passes), which last only that launch, and its swipes and side-dependent taps follow the direction. The harness has its own bundle ID, and it and its UI-test runner are uninstalled at the end, and each simulator's text size and appearance are put back, even after a failure or an interrupt (the script stops every simulator's run first, then cleans up).
4. Compare each screenshot with the mockup's screen. `scripts/mockup-shots.py <mockup folder> <out>` takes the mockup's screens under the same names, and `scripts/contact-sheet.sh` puts pairs side by side in one image to view. A screen the walk doesn't reach, add to `ShotsUITests` (and the seed, if it needs data), and to `mockup-shots.py`'s `SCREENS`.

What the harness can't do: the times are now plus or minus the mockup's gaps, so they differ from the mockup's fixed 8:20 AM, and the system's own UI (notifications, the alarm, permission prompts) isn't in it.

A sideways drag on a list row with no action on that edge can act as a tap and open the row. In UI tests every right swipe did, at any speed, on Tags, Reminders and Settings on the iOS 27.0 simulator; on the iPhone (iOS 27.0.1) some did, on Tags and Reminders (#139). Apple's docs are silent. So a UI test that swipes right expects the row may have opened.

Two simulator quirks it works around (iOS 26.5 simulator, Xcode 27.1, before landscape was skipped there): in landscape, a tap on a navigation bar button never lands and `swipeUp()` doesn't scroll, though rows and tabs take taps. So bar buttons are tapped after turning the phone to portrait and back, and scrolling is a coordinate drag. The simulator's first keyboard also shows a tip over the sheet, which the walk dismisses. That can't be undone: the tip doesn't come back on that simulator, for any app.

## Manual device checks: build, install, clean up

For checks the person drives by hand (VoiceOver, landscape, tapping through screens), not `-only-testing` runs. Used for ticket 29 on an iPhone 15, iOS 27.0.1; the device id comes from `xcrun devicectl list devices`.

1. Before installing, note whether the app is there: `xcrun devicectl device info apps --device <id> --bundle-id com.newrealityinteractive.nudgeinator` (an empty "Apps installed:" means it isn't).
2. Build: `xcodebuild -project NudgeInator.xcodeproj -scheme NudgeInator -destination 'id=<id>' -derivedDataPath .build/derived-device -allowProvisioningUpdates -quiet build` (`.build` is git-ignored; the first build takes a few minutes).
3. Install and launch: `xcrun devicectl device install app --device <id> .build/derived-device/Build/Products/Debug-iphoneos/NudgeInator.app`, then `xcrun devicectl device process launch --terminate-existing --device <id> com.newrealityinteractive.nudgeinator`. After a code fix, repeat 2 and 3; the install keeps the app's data, so the person doesn't re-enter their test data.
4. Load the check's test data with a seed (below) rather than asking the person to type it in. Data they make by hand still needs step 6.
5. Tell the person their starting settings before you ask them to change any (for example text size: Settings > Accessibility > Display & Text Size > Larger Text, noting the notch and whether Larger Accessibility Sizes is on), and have them restore it at the end.
6. Clean up: reminders with Break Through Focus on schedule AlarmKit alarms, and uninstalling doesn't remove those. Ask the person to delete every reminder they made (Done may not cancel the alarm) before you uninstall. If the app wasn't installed at the start, uninstall it with `xcrun devicectl device uninstall app --device <id> com.newrealityinteractive.nudgeinator`, then check with step 1.

### Seeding test data

A Debug build loads a named set of reminders, tags and settings when it is launched with `NUDGE_SEED`, and removes them when launched with `NUDGE_SEED=clean` (#134). A launch without the variable does nothing, and Release builds contain no seed code: every seed file is wrapped in `#if DEBUG`, and `scripts/check-release-has-no-seed.sh` checks a Release build in `scripts/test.sh` and the archive in `scripts/archive-and-upload.sh`. The seed is for manual checks; automated tests never trigger it, and the test host has no model for it to act on.

```
xcrun devicectl device process launch --terminate-existing --device <id> \
  -e '{"NUDGE_SEED":"search"}' com.newrealityinteractive.nudgeinator      # load the "search" set
xcrun devicectl device process launch --terminate-existing --device <id> \
  -e '{"NUDGE_SEED":"clean"}' com.newrealityinteractive.nudgeinator       # remove what was loaded
```

- Install the Debug build first (steps 2 and 3). Add `--console` to the launch to see the app's output; the seed logs `loaded(...)` or `cleaned` under the `DeviceSeed` category.
- The data goes through the model's own add and delete, so it is stored and scheduled like data made by hand, and it survives a force-quit. Loading a set again replaces its reminders, so one copy is left.
- A seeded reminder keeps the creation date its set gives it: `createdAgo` seconds before the load, so the Created sort has different dates to sort by (#248). The app's add stamps a reminder made by hand with now and ignores the date it carries, so the seed adds through `AppModel.addKeepingCreationDate`, a Debug-only add that skips the stamp. A set that leaves `createdAgo` out gets the load time.
- Removal reads a record the load kept in the app's `UserDefaults`, and acts only on what is in it: the reminders by their fixed IDs, and the tags the seed created. A tag the person already had under a set's tag name is used but never recorded, so removal leaves it, and so it does a tag a reminder of theirs now uses. Their own reminders are never touched, whatever their titles.
- A set can change settings (the Reminders tab's sort, the Default Pace). The first load records each one's earlier value, and removal puts it back. The record holds nothing between the launches but this; **Delete All Data** in Settings does not clear it, so a `clean` after it finds the reminders already gone and only restores the settings.
- A set's reminders have Break Through Focus off and none is Relentless, so no set schedules an AlarmKit alarm, which uninstalling would leave behind. A test guards that.
- Removal deletes each reminder through the model's own delete, so it cancels the reminders' pending notifications and alarms through the same plan a delete makes, and removes their delivered notifications from Notification Center (#156). After the `clean` launch, check the phone is as it was: the Reminders tab holds only the person's own, and the sort is the one they had.
- The seed does not undo data the person added to a set's reminders by hand, or changes they made while it was loaded; the `clean` removes the set's reminders whatever state they are in.

Add a set: copy `Packages/NudgeEngine/Sources/NudgeDeviceSeed/SearchSet.swift` to a new file, change its name, tags, settings and reminders (give each reminder a new fixed UUID; due times and creation dates are seconds from the load, a due time rounded down to the whole minute), and add it to `SeedSet.all` in `SeedSet.swift`. The tests check every listed set: unique name and IDs, no alarm, tags declared, and a clean load and removal. A new setting needs a case in `SeedSetting` and in `ModelSeedTarget` (`App/DeviceSeed/DeviceSeedLaunch.swift`). The target's tests run with the engine's: `cd Packages/NudgeEngine && xcodebuild test -scheme NudgeEngine -destination 'platform=macOS'`, or `scripts/test.sh`.

The sets: `search` (#112's Reminders search check): seven reminders over two tags with titles and notes that differ in case, diacritics and word order ("Take Pills", "Café meeting with Sam", "Buy milk today", "Milk: buy"), one already due so it is nudging, and the Reminders tab's sort set to due date, earliest first. `due-dates` (#114's Due Date check): seven reminders from one already nudging to one due a month ahead, so a range has days to include and leave out, sorted the same way. `swipe-tiles` (#126's swipe tile shape check): two Nudging reminders, one with only a one-word title, the shortest a row gets, and one with a long title, four tags and a long note, the tallest, so the tiles can be compared on Now, My Day and Reminders. `tag-search` (#141's Tags search check): four tags, one with a diacritic (#café), one whose name holds another (#home, #homework), and one with no reminders (#travel), with every reminder days away so nothing rings; load it after `search` to check both tabs. `last-tag` (#141's check of the last tag going): one tag and no reminders, loaded after a `clean`. `delivered-nudges` (#156's check that a delete removes a reminder's delivered notifications): two Gentle reminders due about two minutes after the load, so their first nudges arrive together; the delivered notifications, not the list, are what the check reads.

Lessons from ticket 29:

- Simulator screenshots missed a failure that only showed on the phone: at the largest text size in landscape the keyboard covered the rename sheet's error. Check landscape plus largest text on the device whenever a sheet has a text field with a message under it.
- A Form section footer sits below its field and goes behind the keyboard; in compact height put such a message in the section header.
- VoiceOver speaks "#" as "number sign".

## Archive and upload (TestFlight)

How a release's build reaches App Store Connect (`icon-badge` #99; 1.1.0 went through the Organizer). The build comes last, from the release itself: the release PR has merged, and `v<version>` is tagged, pushed and has its GitHub Release (`docs/agents/release.md`). The release PR set `MARKETING_VERSION`; `CURRENT_PROJECT_VERSION` stays 1, and the export step raises it.

1. Check out the tag (`git switch --detach v<version>`) and run `scripts/test.sh` on both simulators there.
2. `scripts/archive-and-upload.sh` regenerates the project, archives (Release, scheme `NudgeInator`, warnings as errors from `project.yml`) into `.build/release/`, checks that the app and the widget report `MARKETING_VERSION`, and stops. It refuses anything but a clean checkout of `v<MARKETING_VERSION>` that is pushed to origin.
3. On the developer's go, `scripts/archive-and-upload.sh upload` uploads that archive with `scripts/export-options.plist`: App Store Connect method, automatic signing, symbols uploaded, version and build number managed, `testFlightInternalTestingOnly` off. App Store Connect checks the build as it takes it; there is no separate validation, since `xcodebuild`'s `validation` method also uploads (1.2.0, #99). It uses the Apple ID signed into Xcode; no API key or secret exists.
4. The developer confirms in App Store Connect that the build processed, pastes What to Test (the fenced block in `docs/release-notes/`, whose COMING SOON section the release PR drew from GitHub), and adds the build to the internal group.

The release PR gets a trial archive first, so a build or signing failure shows before the tag exists: `ALLOW_DIRTY=1 scripts/archive-and-upload.sh` on its branch, after `MARKETING_VERSION` is set. A trial archive can't be uploaded. If the upload fails after the tag, the fix is a patch release (`1.x.1`); a pushed tag never moves.

Organizer fallback, if a command-line step fails: check out the tag, Product > Archive, then Distribute App with **TestFlight & App Store**, never **TestFlight Internal Only**, whose build can never go to the App Store. Keep automatic signing, symbol upload and "Manage version and build number" on (Xcode 27 may skip the options screen).

The TestFlight install replaces the Xcode copy on the phone: note what was installed first, and leave the phone as found.

## Device-check walkthrough

When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time, so none is missed. Inside a check, send one numbered item at a time and wait for its answer before the next. Each item holds what to do and what to report from it, together, since a list of steps above a list of questions got a step skipped (#139). Describe a gesture by where the finger starts and which way it moves: "right swipe" was read both ways in #139. For each check:

1. Say what it checks, what they'll do and when (prompts to answer, what to tap), and the longest it can take.
2. Confirm the `-only-testing` filter matches that one test without touching the phone. Swift Testing's identifier ends in `()`. A run that matches no test still launches the app, and a prompt it shows vanishes when the run ends.
3. Wait for their go, then run it.
4. Report the result and confirm it with them before the next check.

If a run doesn't do what you said it would, stop and explain before running anything else. Once the last check is done, list every check and its result, so the person can see none is left.

A check that runs the app's model sets the Icon badge from its own store, and the badge can't be read back to restore it. If the app was installed before the run, have the person open it once at the end: App opened sets their own count again.
