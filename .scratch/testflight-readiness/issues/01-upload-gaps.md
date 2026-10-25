# 01: Close the gaps that block the first upload

**What to build:** Make the app ready for App Store Connect to accept its first upload:
- a privacy manifest that says no tracking and no collected data, and gives `CA92.1` for `UserDefaults`;
- export compliance declared as `NO`;
- version 1.1.0 and build 1, set once and read by both the app's and the widget's Info.plist;
- a `scripts/test.sh` guard that keeps the manifest true.

A local Release archive proves the build compiles with warnings as errors. A Release build installed from Xcode shows whether the Open intent survives a Release build. AGENTS.md points agents at this folder. Spec stories 1–11 and 44.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] AGENTS.md's Issue tracker section names `testflight-readiness` as the open feature and points at this folder (reworded, agreed with Brian 2026-10-25; see Comments).
- [x] The app bundle contains `PrivacyInfo.xcprivacy` with tracking false, no tracking domains, no collected data types, and one accessed-API entry: `UserDefaults`, reason `CA92.1`. It's added through `project.yml` and `xcodegen generate`.
- [x] The widget extension uses no required reason API, re-checked before merging, and has no manifest of its own.
- [x] `scripts/test.sh` fails on `UserDefaults(suiteName:` anywhere and on any `UserDefaults` in the widget's sources, with a message pointing at the privacy manifest. It has been shown failing once on a scratch change.
- [x] The app's Info.plist has `ITSAppUsesNonExemptEncryption` = `NO`, and Comments records why (Brian confirmed `NO` on 2026-10-25).
- [x] `MARKETING_VERSION` 1.1.0 and `CURRENT_PROJECT_VERSION` 1 are project-wide settings, and both Info.plists read them instead of the hard-coded 1.0 and 1.
- [x] A built-bundle suite in the app's unit tests checks: the app's version is 1.1.0 and equals the widget's; the build numbers match; the encryption key is false; the manifest's contents are as above. It passes on both simulators.
- [x] `xcodebuild archive` of the `NudgeInator` scheme in Release succeeds, with no export or upload.
- [x] Device check, offered to Brian: on a Release build installed from Xcode, an alarm's Open button opens its reminder (phone and iOS version recorded, phone left as found).
- [x] `scripts/test.sh` passes on both simulators.

## Before you start

- Builds on: `project.yml` sets each target's Info.plist through `info.properties`. Neither sets `CFBundleShortVersionString` or `CFBundleVersion`, so XcodeGen writes 1.0 and 1. `UserDefaults` is read through `.standard` by the Default Pace record and the onboarding record (`App/Shell/DefaultPace.swift`, `App/Onboarding/OnboardingRecord.swift`) and by `AppModel`. The only cryptography is `Insecure.SHA1` in `AlarmAdapter`, for alarm IDs. The new guard follows the shape of `scripts/test.sh`'s AlarmKit authorization-read check. Spec: Implementation Decisions, "Privacy manifest", "What the manifest is based on", "Guard", "Export compliance" and "Version and build numbers".
- Watch for: the build number in the repo stays 1 for good. The Organizer's "Manage version and build number" raises it on upload (story 10), so don't add a bump script. The test bundle is hosted in the app, so the suite reads the host app's bundle, not the test bundle's. `OpenReminderIntent` is a `LiveActivityIntent` with no URL representation, so Apple's `URLRepresentableIntent` advice doesn't apply (spec, "App Intents in the archive"). If the Open intent fails on the Release build, stop and tell Brian: the fix (`AppIntentsPackage`) is a ticket of its own.
- Developer stops: agree the `tdd` seam (the built-bundle suite); confirm the guard fails on a scratch change; the offered iPhone run for story 44, walked through per `docs/agents/device-testing.md`.

## Comments

- **Criterion 1 reworded and met (Brian agreed 2026-10-25).** AGENTS.md's Issue tracker section already names `testflight-readiness` as the open feature and says `enhancement-pace` is released (PR #67). The criterion's wording, "runs alongside the open feature `enhancement-pace`", is stale, and writing it would make AGENTS.md false. Reworded to: "AGENTS.md's Issue tracker section names `testflight-readiness` as the open feature and points at this folder" (already true). AGENTS.md needed no change.
- **Device check passed (criterion 9), 2026-10-25.** Brian's iPhone (iPhone 15), iOS 27.0.1. A Release build (`-configuration Release`, 1.1.0 build 1, automatic signing) installed from Xcode over the existing install, which kept its data. Brian made a Relentless reminder with Break Through Focus on, and tapped the alarm's Open button when it rang: the app opened the reminder's details page. So the Open intent survives a Release build, and no `AppIntentsPackage` ticket is needed from this check. Story 27 still decides on the TestFlight install, because the docs don't say a Xcode-installed Release build matches an archive. The archive contains `Metadata.appintents` in both the app and the widget. Brian deleted the reminder, which cancels its alarm. The app was installed before the run (1.0 build 1), so it was kept; the Debug build was reinstalled afterward.
- **Export compliance `NO`** (Brian confirmed 2026-10-25). The only cryptography is `Insecure.SHA1` in `AlarmAdapter`, used to derive stable alarm IDs. It encrypts nothing, and the app makes no network connections. Apple's "Complying with Encryption Export Regulations" allows `NO` for no encryption or only exempt encryption. A feature that adds networking or encryption revisits this.
- **Widget and manifest re-check (2026-10-25).** `NudgeWidgets` and `Packages/NudgeShared` use no `UserDefaults`. No source in `App/`, `NudgeWidgets/` or `Packages/` uses a file-timestamp, system-uptime, disk-space or active-keyboard API (`ProcessInfo` only reads an environment variable). `UserDefaults` is read only through `.standard`, in the Default Pace record and the onboarding record. So the manifest has one entry, `CA92.1`, and the widget has none.
- **Guard shown failing.** With `UserDefaults.standard` added to `NudgeWidgets/NudgeWidgets.swift` and `UserDefaults(suiteName:)` added to `App/Shell/DefaultPace.swift`, `SIMULATORS= scripts/test.sh` failed at "UserDefaults stays within the privacy manifest", listing both lines. Both were reverted. The guard covers shipped sources only (`DefaultPaceTests` makes a suite on purpose). It also covers `Packages/NudgeShared` for plain `UserDefaults`, since the widget links it. It matches comments too, so a comment that names `UserDefaults` in the widget or `NudgeShared` fails it.
- **Release archive found a Release-only failure.** `xcodebuild archive` first failed: 58 errors, `#Preview` blocks in 11 files used fixtures that exist only under `#if DEBUG`. Fix: the previews in 9 files now sit inside `#if DEBUG` (the repo's existing pattern, now in CODING_STANDARDS.md). `PreviewScheduler` lost its `#if DEBUG`, because `HowItNudgesPage` and `HowItNudgesSection` use it in non-preview code; `PreviewClock` stays inside `#if DEBUG`. Archive then succeeded with no warnings. Its app and widget both read 1.1.0 build 1; the manifest is at the app's root; `ITSAppUsesNonExemptEncryption` is false. For Brian: `PreviewScheduler` is now a shipping type with a preview name; a rename to `NoOpScheduler` touches the previews that use it, and is left for you to decide.
- **Built-bundle suite** (`NudgeInatorTests/BuiltBundleTests.swift`), written red first in slices: version, build numbers, encryption key, manifest. It also checks that the widget has no manifest. `scripts/test.sh` passed on both simulators (339 tests each; 261 engine tests).
- **Review.** Four reviewers (Standards, Spec, iOS/Apple, Smells). Fixed: `PreviewClock` back under `#if DEBUG`, dropped an extra `Int(build)` assertion, commented the version pin, added the preview rule to CODING_STANDARDS.md. Not done: parameterizing the version test; wrapping the 13 other previews (they compile in Release).
