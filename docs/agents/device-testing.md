# Device testing and toolchain reference

Reference moved out of `AGENTS.md`. The rules that change behaviour stay in `AGENTS.md`; this file holds the rationale, the history and the walkthrough procedure.

## Toolchain rationale

The project builds with **Xcode 26.6 and the iOS 26.5 SDK**, the newest the development Mac (Intel) can run: Apple's Xcode 27 release notes say "Xcode 27 will only install and run on Apple silicon Macs." So there is no iOS 27 SDK or simulator here. Physical-device checks can still run on a newer iOS (Xcode 26.6 installs on an iOS 27 iPhone). Revisit this when the project moves to an Apple silicon Mac.

## AlarmKit alarms survive uninstall

Uninstalling does **not** remove the app's AlarmKit alarms on a device (iPhone 15, iOS 27.0.1; it does in the simulator). Ticket 02's spike left 4,001 behind that survived two uninstalls. So a device test cancels every alarm it schedules, and doesn't assume a fresh install holds none: an apply cancels every alarm of the app's that isn't in its plan, so `AlarmDeviceCheck` first requires the app to hold no alarms. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`), since uninstalling is what resets the answer.

## Simulator media analysis is switched off

The iOS 26.5 simulator's own `mediaanalysisd` (the Photos analysis daemon inside the simulator, not macOS's) ran at 700-870% of a CPU from about 20-60 s after every boot, for as long as the simulator was up. It happened with no app, test or screenshot running (2026-10-18, ticket 29: a boot-only run and an idle Mac were the controls), and it forced a restart of the development Mac. The iOS 26.1 simulator didn't do it. Apple's docs say nothing about it. Nothing in the app uses Photos, Vision or Live Text, so `scripts/test.sh` switches the daemon off in each simulator before testing it (`launchctl disable` and `bootout` through `xcrun simctl spawn`). That persists across boots, and a new or erased simulator needs it again, which the script does. Set `KEEP_MEDIA_ANALYSIS=1` to leave it on, or run `xcrun simctl spawn <udid> launchctl enable system/com.apple.mediaanalysisd` to turn it back on. If the Mac runs hot during simulator work, check `ps -Ao %cpu,comm | grep mediaanalysisd` first, and whether the path is under a `.simruntime`.

## Device-check walkthrough

When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time, so none is missed. For each check:

1. Say what it checks, what they'll do and when (prompts to answer, what to tap), and the longest it can take.
2. Confirm the `-only-testing` filter matches that one test without touching the phone. Swift Testing's identifier ends in `()`. A run that matches no test still launches the app, and a prompt it shows vanishes when the run ends.
3. Wait for their go, then run it.
4. Report the result and confirm it with them before the next check.

If a run doesn't do what you said it would, stop and explain before running anything else. Once the last check is done, list every check and its result, so the person can see none is left.
