# Device testing and toolchain reference

Reference moved out of `AGENTS.md`. The rules that change behaviour stay in `AGENTS.md`; this file holds the rationale, the history and the walkthrough procedure.

## Toolchain rationale

Since the pace enhancement's ticket 01 (2026-10-21) the development Mac is an Apple M5 (macOS 26.6) with **Xcode 27.1** (27A9275), the iOS 27.1 SDK and Swift 6.4.

The matrix's simulators were created by hand on that Mac, which is why `scripts/test.sh` picks them by name. The Mac also has `iPhone 15 - iOS 26.1` and `iPhone Duo - iOS 27.1` simulators, left out of the matrix for now (run them with `SIMULATORS`). With 26.1 dropped, nothing runs automatically at the minimum, so a change that leans on an API newer than 26.1 is worth a run there.

### Test iPhones

An iPhone 15 on iOS 27.2.1 (updated from 27.0.1 on 2026-11-09; "Brian's iPhone" in `xcrun devicectl list devices`). It is the only one, which is why the iOS 26 path behind `if #available` is covered only by the tests `scripts/test.sh` runs on the iOS 26.5 simulator. Since the developer retired the simulator screenshot runs (2026-11-09), nothing looks at that path on screen: a known gap, accepted. If a phone on iOS 26.x arrives, record it here and change that rule.

The iPhone is the developer's personal phone, signed in to their own Apple Account: only Nudge-inator's data on it is disposable. A check that needs an iCloud sign-out, a sign-in or another account-level change runs on the iPad instead: an iPad (10th generation) on iPadOS 27.2.1 ("Brian's iPad"), signed in to the test Apple Account, with Developer Mode on and registered in the developer account (2026-11-13, #216). The iPhone-only app runs there in compatibility mode. Its first build needs `-allowProvisioningDeviceRegistration` beside `-allowProvisioningUpdates` to register a new device.

### History: the Intel Mac

Until then the project built with **Xcode 26.6 and the iOS 26.5 SDK**, the newest the development Mac (Intel) could run: Apple's Xcode 27 release notes say "Xcode 27 will only install and run on Apple silicon Macs." So there was no iOS 27 SDK or simulator, and the matrix was the iOS 26.1 and 26.5 simulators. Physical-device checks still ran on an iOS 27 iPhone (Xcode 26.6 installs on one).

## AlarmKit alarms survive uninstall

Uninstalling does **not** remove the app's AlarmKit alarms on a device (iPhone 15, iOS 27.0.1; it does in the simulator). Ticket 02's spike left 4,001 behind that survived two uninstalls. So a device test cancels every alarm it schedules, and doesn't assume a fresh install holds none: an apply cancels every alarm of the app's that isn't in its plan, so `AlarmDeviceCheck` first requires the app to hold no alarms. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`), since uninstalling is what resets the answer.

## Simulator media analysis is switched off

The iOS 26.5 simulator's own `mediaanalysisd` (the Photos analysis daemon inside the simulator, not macOS's) ran at 700-870% of a CPU from about 20-60 s after every boot, for as long as the simulator was up. It happened with no app, test or screenshot running (2026-10-18, ticket 29: a boot-only run and an idle Mac were the controls), and it forced a restart of the development Mac. The iOS 26.1 simulator didn't do it. Apple's docs say nothing about it. Nothing in the app uses Photos, Vision or Live Text, so `scripts/test.sh` switches the daemon off in each simulator before testing it (`launchctl disable` and `bootout` through `xcrun simctl spawn`). That persists across boots, and a new or erased simulator needs it again, which the script does. Set `KEEP_MEDIA_ANALYSIS=1` to leave it on, or run `xcrun simctl spawn <udid> launchctl enable system/com.apple.mediaanalysisd` to turn it back on. If the Mac runs hot during simulator work, check `ps -Ao %cpu,comm | grep mediaanalysisd` first, and whether the path is under a `.simruntime`.

## Test metrics

Every `scripts/test.sh` run and every `scripts/screenshots.sh` run appends records of itself to `runs.jsonl`, one line of JSON each, in the folder **Nudge-inator Test Metrics** in iCloud Drive (#303). It is outside the repository, and visible in Files and Finder. This Mac has no Time Machine backup, so iCloud Drive is the only local place with a copy off the Mac. A record holds `time`, `ticket`, `commit`, `step`, `simulator`, `variant`, `tests`, `duration` (seconds), `result` and `failed`. The ticket is the number in the branch name (`<feature>-<n>-<slug>`), and null on any other branch.

- `test.sh` adds a record for the engine's tests (`engine-tests`), the app build (`app-build`), each simulator's app tests (`app-tests`) and the run as a whole (`test.sh`, with the failed steps, separated by spaces, in `failed`; elsewhere `failed` joins test names with `; `).
- `screenshots.sh` adds a record for the harness build (`screenshots-build`) and one for each variant run on each simulator (`screenshots`). A run that was cut short, because another failed or the script was interrupted, has the result `stopped`, not `fail`; the run that failed names its test in `failed`.
- A failure to write the metrics (no iCloud Drive, as on CI, or a folder that can't be made) is a warning and never fails or stops a run.
- `scripts/metrics.sh` sets the location in one place. `NUDGE_METRICS_DIR` overrides the folder (the scripts' own tests point it at a temporary one), `NUDGE_METRICS_TICKET` and `NUDGE_METRICS_COMMIT` the ticket and commit.

## Simulator screenshots

Moved to [simulator-screenshots.md](simulator-screenshots.md), so a session reads it only when it needs it.

## Manual device checks: build, install, clean up

For checks the person drives by hand (VoiceOver, landscape, tapping through screens), not `-only-testing` runs. Used for ticket 29 on an iPhone 15, iOS 27.0.1; the device id comes from `xcrun devicectl list devices`.

1. Before installing, note whether the app is there: `xcrun devicectl device info apps --device <id> --bundle-id com.newrealityinteractive.nudgeinator` (an empty "Apps installed:" means it isn't).
2. Build: `xcodebuild -project NudgeInator.xcodeproj -scheme NudgeInator -destination 'id=<id>' -derivedDataPath .build/derived-device -allowProvisioningUpdates -quiet build` (`.build` is git-ignored; the first build takes a few minutes).
3. Install and launch: `xcrun devicectl device install app --device <id> .build/derived-device/Build/Products/Debug-iphoneos/NudgeInator.app`, then `xcrun devicectl device process launch --terminate-existing --device <id> com.newrealityinteractive.nudgeinator`. After a code fix, repeat 2 and 3; the install keeps the app's data, so the person doesn't re-enter their test data.
4. Load the check's test data with a seed (below) rather than asking the person to type it in.
5. Tell the person their starting settings before you ask them to change any (for example text size: Settings > Accessibility > Display & Text Size > Larger Text, noting the notch and whether Larger Accessibility Sizes is on), and have them restore it at the end.
6. Clean up, automatically (decided 2026-11-09): the phone holds no data the developer needs kept, and a check uses seeded data only, never data the person makes by hand. At the end, launch with `NUDGE_SEED=clean`, so nothing is left for the person to delete. The app stays installed: uninstalling is never part of cleanup. A set schedules no AlarmKit alarm, which uninstalling wouldn't remove anyway, except the named ringing sets (Seeding test data). If a check needs data no set has, add it to a set.

### Seeding test data

Moved to [seeding-test-data.md](seeding-test-data.md), so a session reads it only when it needs it.

## Archive and upload (TestFlight)

How a release's build reaches App Store Connect (`icon-badge` #99; 1.1.0 went through the Organizer). The build comes last, from the release itself: the release PR has merged, and `v<version>` is tagged, pushed and has its GitHub Release (`docs/agents/release.md`). The release PR set `MARKETING_VERSION`; `CURRENT_PROJECT_VERSION` stays 1, and the export step raises it.

1. Check out the tag (`git switch --detach v<version>`) and run `scripts/test.sh` on both simulators there.
2. `scripts/archive-and-upload.sh` regenerates the project, archives (Release, scheme `NudgeInator`, warnings as errors from `project.yml`) into `.build/release/`, checks that the app and the widget report `MARKETING_VERSION`, and stops. It refuses anything but a clean checkout of `v<MARKETING_VERSION>` that is pushed to origin.
3. On the developer's go, `scripts/archive-and-upload.sh upload` uploads that archive with `scripts/export-options.plist`: App Store Connect method, automatic signing, symbols uploaded, version and build number managed, `testFlightInternalTestingOnly` off. App Store Connect checks the build as it takes it; there is no separate validation, since `xcodebuild`'s `validation` method also uploads (1.2.0, #99). It uses the Apple ID signed into Xcode; no API key or secret exists.
4. The developer confirms in App Store Connect that the build processed, pastes the Review Notes (`docs/release-notes/<version>-review-notes.md`) and What to Test (the fenced block in `docs/release-notes/`, whose COMING SOON section the release PR drew from GitHub), and adds the build to the internal group.

The release PR gets a trial archive first, so a build or signing failure shows before the tag exists: `ALLOW_DIRTY=1 scripts/archive-and-upload.sh` on its branch, after `MARKETING_VERSION` is set. A trial archive can't be uploaded. If the upload fails after the tag, the fix is a patch release (`1.x.1`); a pushed tag never moves.

Organizer fallback, if a command-line step fails: check out the tag, Product > Archive, then Distribute App with **TestFlight & App Store**, never **TestFlight Internal Only**, whose build can never go to the App Store. Keep automatic signing, symbol upload and "Manage version and build number" on (Xcode 27 may skip the options screen).

The TestFlight install replaces the Xcode copy on the phone: note what was installed first, and leave the phone as found.

## Device-check walkthrough

When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time, so none is missed. Inside a check, send one numbered item at a time and wait for its answer before the next. Each item holds what to do and what to report from it, together, since a list of steps above a list of questions got a step skipped (#139). Describe a gesture by where the finger starts and which way it moves: "right swipe" was read both ways in #139. For each check:

1. Say what it checks, what they'll do and when (prompts to answer, what to tap), and the longest it can take.
2. Confirm the `-only-testing` filter matches that one test without touching the phone. Swift Testing's identifier ends in `()`. A run that matches no test still launches the app, and a prompt it shows vanishes when the run ends.
3. Wait for their go, then run it.
4. Report the result and confirm it with them before the next check.

The phone check of a ticket that changes something on screen (`ticket-workflow.md`, step 7) goes the same way: one numbered step per message, then the developer's answer, never the whole list at once (the developer's rule, 2026-11-11, #198). VoiceOver checks and automated device runs also wait for the developer's go before each.

Every step names the exact control to tap and what the developer should see when they stop, such as "Tap Disconnect on Riley's page; stop when the sheet is open". A step that names only a screen sent the developer through a whole Disconnect twice on #197, and each time the data had to be seeded again.

If a run doesn't do what you said it would, stop and explain before running anything else. Once the last check is done, list every check and its result, so the person can see none is left.

A check that runs the app's model sets the Icon badge from its own store, and the badge can't be read back to restore it. If the app was installed before the run, have the person open it once at the end: App opened sets their own count again.

## Findings: an invite opened on an older version (#444, 2026-11-18)

Checked with the iPhone on TestFlight 1.4.0 (1), iOS 27.x, as sender, and the iPad (10th generation, iPadOS 27.2.1) on TestFlight 1.3.0 (1) with Automatic Updates off, signed in to the second Apple Account, as recipient. The invite went by email (Gmail on the iPhone, Mail on the iPad). The Messages channel was not run (the developer's call): the email result stands for the iCloud share link, and Messages' invite card (title, icon) is unchecked.

- **Before tapping** (Mail on the iPad): a plain email, "Invitation to Nudge-inator", with the iCloud link. No title card or icon.
- **After tapping the link:** a system prompt, *Open "Nudge-inator Reminders"? Brian Mericle wants to collaborate. You'll join as Brian Mericle (nudge-test@…).* with Not Now and Open. It names the app "Nudge-inator Reminders" and says nothing about versions.
- **After Open:** an alert, *Couldn't Open "Nudge-inator Reminders". You need a newer version of Nudge-inator to open this, but the required version couldn't be found in the App Store.* One OK button; OK leaves the person in Mail. No app opens. The text points at the App Store, which a TestFlight tester can't use.
- **Reopening 1.3.0:** nothing about the invite anywhere; the app is unchanged.
- **Sender, before and after the recipient's failed accept:** unchanged, "Invited · Waiting for them to accept", with Invite Again and Cancel Invite. Its "Didn't open for them?" help covered only a wrong address.
- **What changed (1.4.1):** that help, and How Sharing Works' note under Connect, now say both people need the latest Nudge-inator. An older build can't be changed, so the recipient's alert stays as above.
