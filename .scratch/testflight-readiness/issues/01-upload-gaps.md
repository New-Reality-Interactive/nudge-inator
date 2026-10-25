# 01: Close the gaps that block the first upload

**What to build:** Make the app ready for App Store Connect to accept its first upload:
- a privacy manifest that says no tracking and no collected data, and gives `CA92.1` for `UserDefaults`;
- export compliance declared as `NO`;
- version 1.1.0 and build 1, set once and read by both the app's and the widget's Info.plist;
- a `scripts/test.sh` guard that keeps the manifest true.

A local Release archive proves the build compiles with warnings as errors. A Release build installed from Xcode shows whether the Open intent survives a Release build. AGENTS.md points agents at this folder. Spec stories 1–11 and 44.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] AGENTS.md's Issue tracker section says in one line that `testflight-readiness` runs alongside the open feature `enhancement-pace`.
- [ ] The app bundle contains `PrivacyInfo.xcprivacy` with tracking false, no tracking domains, no collected data types, and one accessed-API entry: `UserDefaults`, reason `CA92.1`. It's added through `project.yml` and `xcodegen generate`.
- [ ] The widget extension uses no required reason API, re-checked before merging, and has no manifest of its own.
- [ ] `scripts/test.sh` fails on `UserDefaults(suiteName:` anywhere and on any `UserDefaults` in the widget's sources, with a message pointing at the privacy manifest. It has been shown failing once on a scratch change.
- [ ] The app's Info.plist has `ITSAppUsesNonExemptEncryption` = `NO`, and Comments records why (Brian confirmed `NO` on 2026-10-25).
- [ ] `MARKETING_VERSION` 1.1.0 and `CURRENT_PROJECT_VERSION` 1 are project-wide settings, and both Info.plists read them instead of the hard-coded 1.0 and 1.
- [ ] A built-bundle suite in the app's unit tests checks: the app's version is 1.1.0 and equals the widget's; the build numbers match; the encryption key is false; the manifest's contents are as above. It passes on both simulators.
- [ ] `xcodebuild archive` of the `NudgeInator` scheme in Release succeeds, with no export or upload.
- [ ] Device check, offered to Brian: on a Release build installed from Xcode, an alarm's Open button opens its reminder (phone and iOS version recorded, phone left as found).
- [ ] `scripts/test.sh` passes on both simulators.

## Before you start

- Builds on: `project.yml` sets each target's Info.plist through `info.properties`. Neither sets `CFBundleShortVersionString` or `CFBundleVersion`, so XcodeGen writes 1.0 and 1. `UserDefaults` is read through `.standard` by the Default Pace record and the onboarding record (`App/Shell/DefaultPace.swift`, `App/Onboarding/OnboardingRecord.swift`) and by `AppModel`. The only cryptography is `Insecure.SHA1` in `AlarmAdapter`, for alarm IDs. The new guard follows the shape of `scripts/test.sh`'s AlarmKit authorization-read check. Spec: Implementation Decisions, "Privacy manifest", "What the manifest is based on", "Guard", "Export compliance" and "Version and build numbers".
- Watch for: the build number in the repo stays 1 for good. The Organizer's "Manage version and build number" raises it on upload (story 10), so don't add a bump script. The test bundle is hosted in the app, so the suite reads the host app's bundle, not the test bundle's. `OpenReminderIntent` is a `LiveActivityIntent` with no URL representation, so Apple's `URLRepresentableIntent` advice doesn't apply (spec, "App Intents in the archive"). If the Open intent fails on the Release build, stop and tell Brian: the fix (`AppIntentsPackage`) is a ticket of its own.
- Developer stops: agree the `tdd` seam (the built-bundle suite); confirm the guard fails on a scratch change; the offered iPhone run for story 44, walked through per `docs/agents/device-testing.md`.

## Comments
