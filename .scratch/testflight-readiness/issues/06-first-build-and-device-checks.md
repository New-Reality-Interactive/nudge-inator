# 06: First 1.1.0 build to TestFlight, and its device checks

**What to build:** Brian archives and uploads the first 1.1.0 build, installs it on his iPhone, and checks that the TestFlight build behaves like the debug build. The checks cover alarms, Time Sensitive nudges, the widget, the Open intent and the clean reinstall. The build then goes through Beta App Review to the external group, and the testers install it from What to Test, knowing what TestFlight shares. Spec stories 17–30 and 42.

**Blocked by:** 01, 02, 03, 04, 07.

**Status:** ready-for-human

- [ ] What to Test in `docs/release-notes/1.1.0-testflight.md` says, in plain words: that the build lasts 90 days; what TestFlight shares with the developer (crash logs and usage information collected automatically with no opt-out, plus any feedback sent); and that a feedback screenshot shows whatever is on screen, reminder text included. Brian approves it.
- [ ] `scripts/test.sh` passes on both simulators on the commit that's archived.
- [ ] Brian archives the `NudgeInator` scheme, runs Validate App, and distributes with "TestFlight & App Store", with automatic signing, symbol upload and "Manage version and build number" on. A validation failure's message goes in Comments.
- [ ] Comments has one line per uploaded build: build number, date, commit, and what changed since the last build.
- [ ] Brian pastes What to Test into the build.
- [ ] Device check: a Relentless reminder rings as an alarm at its due time under a Focus on the TestFlight install.
- [ ] Device check: a Gentle reminder's Time Sensitive nudge arrives on the TestFlight install.
- [ ] Device check: the widget extension's alarm presentation and its Open button work.
- [ ] Device check: the Open intent opens the reminder from the alarm. If it doesn't, the `AppIntentsPackage` fix becomes a ticket of its own (spec, "App Intents in the archive").
- [ ] Device check: Delete All Data, uninstall, then install from TestFlight leaves no AlarmKit alarms behind.
- [ ] Settings › About on the TestFlight install shows 1.1.0 and the Organizer's build number.
- [ ] After the first build uploads, an external group exists with the two testers, invited by email (moved from ticket 04, criterion 7; an internal group already exists, which App Store Connect Help says must come first).
- [ ] The build is submitted to Beta App Review, approved, and added to the external group. Whatever Beta App Review asks about alarms that ring through silent mode and Focus is recorded in the spec (story 23).
- [ ] A tester sends feedback from the TestFlight app, and Brian reads it in the Organizer or App Store Connect.

## Before you start

- Builds on: tickets 01–04 (the manifest, encryption key, version numbers, About screen, published privacy page and App Store Connect setup). Spec Implementation Decisions, "Distribution", "Where build numbers live", "Testers" and "Feedback". Testing Decisions, "Device checks". Help findings (spec story 31): 90-day builds, up to 10,000 external testers, review usually under 24 hours.
- Watch for: never use "TestFlight Internal Only", whose build can't go to the App Store. Brian installs from TestFlight before Beta App Review finishes. The TestFlight install replaces any Xcode-installed copy, so note what was installed first and leave the phone as found. Every reminder made for a check is deleted, cancelling its alarms, before the next check. A fix a tester's finding needs is an `enhancement-pace` ticket, not one here.
- Developer stops: every App Store Connect and Organizer step is Brian's; each device check is walked through one at a time per `docs/agents/device-testing.md`, waiting for Brian's go before each.

## Comments

- Ticket 07 (rename `PreviewScheduler`, filed 2026-10-25 from ticket 01's review) is added to `Blocked by`, so it merges before the first archive. `Blocked by` still lists 01–04.
- 2026-10-25: Ticket 04's criterion 7 (the external group with the two testers) moved here, agreed with Brian. See ticket 04's Comments.
- 2026-10-25: What to Test drafted in `docs/release-notes/1.1.0-testflight.md` (90 days, what TestFlight shares, screenshots show reminder text). Awaiting Brian's approval, so criterion 1 stays open. `scripts/test.sh` passed on both simulators on the branch (docs-only change over `main`); criterion 2 stays open until it's confirmed on the commit Brian archives. The sentence on tapping Share Beta Feedback after a screenshot isn't confirmed by Apple's docs yet: Brian checks it on the TestFlight app.
