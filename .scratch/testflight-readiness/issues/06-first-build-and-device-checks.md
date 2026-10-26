# 06: First 1.1.0 build to TestFlight, and its device checks

**What to build:** Brian archives and uploads the first 1.1.0 build, installs it on his iPhone, and checks that the TestFlight build behaves like the debug build. The checks cover alarms, Time Sensitive nudges, the widget, the Open intent and the clean reinstall. The build then goes through Beta App Review to the external group, and the testers install it from What to Test, knowing what TestFlight shares. Spec stories 17–30 and 42.

**Blocked by:** 01, 02, 03, 04, 07.

**Status:** ready-for-human

- [x] What to Test in `docs/release-notes/1.1.0-testflight.md` says, in plain words: that the build lasts 90 days; what TestFlight shares with the developer (crash logs and usage information collected automatically with no opt-out, plus any feedback sent); and that a feedback screenshot shows whatever is on screen, reminder text included. Brian approves it.
- [x] `scripts/test.sh` passes on both simulators on the commit that's archived.
- [x] Brian archives the `NudgeInator` scheme, runs Validate App, and distributes with "TestFlight & App Store", with automatic signing, symbol upload and "Manage version and build number" on. A validation failure's message goes in Comments.
- [x] Comments has one line per uploaded build: build number, date, commit, and what changed since the last build.
- [x] Brian pastes What to Test into the build.
- [x] Device check: a Relentless reminder rings as an alarm at its due time under a Focus on the TestFlight install.
- [x] Device check: a Gentle reminder's Time Sensitive nudge arrives on the TestFlight install.
- [x] Device check: the widget extension's alarm presentation and its Open button work.
- [x] Device check: the Open intent opens the reminder from the alarm. If it doesn't, the `AppIntentsPackage` fix becomes a ticket of its own (spec, "App Intents in the archive").
- [x] Device check: Delete All Data, uninstall, then install from TestFlight leaves no AlarmKit alarms behind.
- [x] Settings › About on the TestFlight install shows 1.1.0 and the Organizer's build number.
- [x] After the first build uploads, an external group exists with the two testers, invited by email (moved from ticket 04, criterion 7; an internal group already exists, which App Store Connect Help says must come first).
- [x] The build is submitted to Beta App Review, approved, and added to the external group. Whatever Beta App Review asks about alarms that ring through silent mode and Focus is recorded in the spec (story 23).
- [ ] A tester sends feedback from the TestFlight app, and Brian reads it in the Organizer or App Store Connect.

## Before you start

- Builds on: tickets 01–04 (the manifest, encryption key, version numbers, About screen, published privacy page and App Store Connect setup). Spec Implementation Decisions, "Distribution", "Where build numbers live", "Testers" and "Feedback". Testing Decisions, "Device checks". Help findings (spec story 31): 90-day builds, up to 10,000 external testers, review usually under 24 hours.
- Watch for: never use "TestFlight Internal Only", whose build can't go to the App Store. Brian installs from TestFlight before Beta App Review finishes. The TestFlight install replaces any Xcode-installed copy, so note what was installed first and leave the phone as found. Every reminder made for a check is deleted, cancelling its alarms, before the next check. A fix a tester's finding needs is an `enhancement-pace` ticket, not one here.
- Developer stops: every App Store Connect and Organizer step is Brian's; each device check is walked through one at a time per `docs/agents/device-testing.md`, waiting for Brian's go before each.

## Comments

- Ticket 07 (rename `PreviewScheduler`, filed 2026-10-25 from ticket 01's review) is added to `Blocked by`, so it merges before the first archive. `Blocked by` still lists 01–04.
- 2026-10-25: Ticket 04's criterion 7 (the external group with the two testers) moved here, agreed with Brian. See ticket 04's Comments.
- 2026-10-25: What to Test drafted in `docs/release-notes/1.1.0-testflight.md` (90 days, what TestFlight shares, screenshots show reminder text). Awaiting Brian's approval, so criterion 1 stays open. `scripts/test.sh` passed on both simulators on the branch (docs-only change over `main`); criterion 2 stays open until it's confirmed on the commit Brian archives. The sentence on tapping Share Beta Feedback after a screenshot isn't confirmed by Apple's docs yet: Brian checks it on the TestFlight app.
- 2026-10-25: Brian approved What to Test as drafted (criterion 1 ticked).
- 2026-10-25: `scripts/test.sh` passed on both simulators on b3c4406, the commit archived (criterion 2 ticked). Validate App succeeded. Brian chose Xcode 27's "App Store Connect" method (the "TestFlight & App Store" one; it showed no options screen), so criterion 3 stays open: automatic signing, symbol upload and "Manage version and build number" can't be confirmed from it.
- Build 1.1.0 (1), 2026-10-25, commit b3c4406: the first build; nothing earlier to compare with.
- 2026-10-25: Build 1.1.0 (1) is in the internal group (Brian installed it from TestFlight) and shows Waiting for Review in the external group. Brian invited the two testers by email (criterion 11 ticked). Beta App Review approval is still to come (criterion 12).
- 2026-10-25: Device check, Settings › About on the TestFlight install (iPhone 15, iOS 27.0.1) shows 1.1.0 and build 1, matching App Store Connect's 1.1.0 (1) (criterion 10 ticked).
- 2026-10-25: Device check on the TestFlight install (iPhone 15, iOS 27.0.1; Do Not Disturb on, silent switch on, volume 75%): a Relentless reminder with Break Through Focus rang audibly at its due time. The alarm showed title, time, app name, an Open button and a Stop slider. Open, then Face ID, opened the reminder's detail screen. That ticks criteria 6, 7 and 8; the `AppIntentsPackage` fix isn't needed. Brian cleaned up with Delete All Data.
- 2026-10-25: Device check on the TestFlight install (iPhone 15, iOS 27.0.1; Do Not Disturb on, silent switch on): a Gentle reminder with a Consistent 2 min pace and Break Through Focus on delivered its nudge 5 (first of the Time Sensitive nudges) through Do Not Disturb, with no sound because the silent switch was on (criterion 15 ticked). The first try, with Break Through Focus off, was held as an ordinary notification: with the switch off the engine never sends Time Sensitive (`NudgingStatus.nudgeDelivery`), so that run was a wrong setup, not a failure. The check's wording should have said Break Through Focus on.
- 2026-10-25: Device check on the TestFlight install (iPhone 15, iOS 27.0.1; Do Not Disturb on, silent switch on): a Relentless reminder due 9:46 PM, then Delete All Data, uninstall, reinstall from TestFlight. Nothing rang and no notification arrived afterwards, so no alarm was left behind (criterion 18 ticked).
- 2026-10-25: Brian confirmed criterion 3: the upload used automatic signing, symbol upload and "Manage version and build number" (the options screen didn't show them).
- 2026-10-25: Brian confirmed he pasted What to Test into the build (criterion 5 ticked).
- 2026-10-26: Brian asked for What to Test to separate steps for new users from steps for people who had the app before. Rewritten in `docs/release-notes/1.1.0-testflight.md`. The 2026-10-25 approval was of the earlier wording, so criterion 1 is open again for the new text, and criterion 5 (pasted) is open until Brian pastes the new text into build 1.1.0 (1), which App Store Connect lets him edit without a new build.
- 2026-10-26: Brian approved the new What to Test wording (criterion 1 ticked again). Criterion 5 stays open until he pastes it into the build.
- 2026-10-26: Brian pasted the new What to Test into build 1.1.0 (1) (Test Details, shown as Saved); criterion 5 ticked.
- 2026-10-26: Beta App Review approved build 1.1.0 (1) and it is in the external group, with six testers invited, one of whom had installed it. Apple asked nothing about alarms through silent mode and Focus, so there is nothing to record in the spec for story 23 (criterion 12 ticked).
