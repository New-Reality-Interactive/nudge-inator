# 04: App Store Connect setup for external testing

**What to build:** Brian creates the app record and fills in everything App Store Connect needs before a build can reach external testers. The agent drafts the text. That means:
- the app record;
- the App Privacy label;
- TestFlight's test information;
- Beta App Review's contact details and notes;
- an external group with the two testers.

Spec stories 12–16.

**Blocked by:** 03 (the privacy policy URL is entered once, at its final, published address).

**Status:** ready-for-human

- [ ] The app record exists for `com.newrealityinteractive.nudgeinator`: name "Nudge-inator", SKU `nudgeinator`, primary language English (U.S.). If the name is taken, Brian records the name chosen instead, and ticket 05's name drafts follow it.
- [ ] The App Privacy label is "Data Not Collected", and the agent confirms it still matches the app and the manifest.
- [ ] The agent drafts the beta app description, in plain English (U.S.), with the TestFlight-sharing line from spec story 42.
- [ ] Brian enters the test information: the description, the feedback email, the marketing URL `https://newrealityinteractive.com/nudge-inator/`, and the privacy policy URL from ticket 03.
- [ ] The agent drafts Beta App Review notes (at most 4,000 characters) that name each behavior and how to see it: a reminder nudges until it's marked Done; Relentless reminders ring as AlarmKit alarms through silent mode and Focus; Break through Focus; Time Sensitive nudges; the onboarding permission requests. No sign-in or demo account.
- [ ] Brian enters the Beta App Review contact details and the notes.
- [ ] An external group exists with the two testers, invited by email.

## Before you start

- Builds on: spec Implementation Decisions, "TestFlight test information and Beta App Review details", "Privacy label basis" and "Testers", and Guideline 2.3.1(a) (generic notes are rejected). The vocabulary for the notes is in `GLOSSARY.md`.
- Watch for: the feedback email and the Beta App Review contact are Brian's and never go in the repo, so the drafts use placeholders (decided on 2026-10-25). A test-information field that has data can be changed but not cleared, so each URL is entered once. The beta app localization has no support URL field: the support URL belongs to the App Store listing (ticket 05).
- Developer stops: every App Store Connect step is Brian's; the agent writes the drafts and records what he reports.

## Comments
