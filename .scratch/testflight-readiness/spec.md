Status: needs-triage
Version: 1.1.0

# Nudge-inator: TestFlight readiness

The version is the release this work serves, not a new one. It delivers enhancement-pace's story 48 (`.scratch/enhancement-pace/spec.md`, "Beta install") and the What to Test text in `docs/release-notes/1.1.0-testflight.md`. That spec isn't edited.

## Problem Statement

1.1.0 is meant for my two beta testers through TestFlight, but no Nudge-inator build has ever been uploaded to App Store Connect. There is no app record. The app has no privacy manifest though it uses `UserDefaults`, a required reason API, so App Store Connect would turn the first upload away. Export compliance isn't declared, so every upload would stop at a questionnaire. Both Info.plists hard-code version 1.0 and build 1, so setting a version in `project.yml` wouldn't reach the build. Nothing in App Store Connect is set up for testers, Beta App Review or, later, the App Store.

## Solution

Close the gaps in the project that block an upload, then archive and upload a 1.1.0 build through Organizer › Distribute App › "TestFlight & App Store". Set up App Store Connect for external testing: the app record, test information, an external group with my two testers, and Beta App Review. Check on my iPhone that the TestFlight build behaves like the debug build: alarms, Time Sensitive notifications, the widget, the Open intent, and the clean reinstall from story 48.

Alongside it, do four pieces of App Store groundwork that the beta's results won't change: the privacy policy and support pages, the age rating, pricing and countries, and drafts of the name, subtitle and keywords. The later App Store submission spec cites these instead of deciding them again.

Steps that need my developer account, App Store Connect, my website or my testers are mine. The agent drafts text for them where it can. Each story says who does it.

## User Stories

### Tracking this work

1. As the developer, I want AGENTS.md's Issue tracker section to say in one line that `testflight-readiness` runs alongside the open feature `enhancement-pace`, so that an agent finds this folder and doesn't file pace tickets here. (Agent)

### Gaps that block the first upload

2. As the developer, I want a privacy manifest in the app, so that App Store Connect accepts the first upload. Apple's "Describing use of required reason API": since May 1, 2024, apps that don't describe their use of required reason API "aren't accepted by App Store Connect". (Agent)
3. As the developer, I want the manifest to give `CA92.1` for `UserDefaults`, because both uses (the Default Pace record and the onboarding record) read the app's own standard defaults, not the App Group's suite. `1C8F.1` would apply only to defaults shared through the App Group, and there are none. (Agent)
4. As the developer, I want the manifest to say there is no tracking, no tracking domains and no collected data, because the app makes no network connections and keeps everything on the phone. (Agent)
5. As the developer, I want it confirmed that the widget extension uses no required reason API, so that it doesn't need a manifest of its own. As of 2026-10-24 it reads no `UserDefaults`. (Agent)
6. As the developer, I want a check in `scripts/test.sh` that fails if code starts reading defaults from a suite or from the widget, so that the manifest can't silently go stale. (Agent)
7. As the developer, I want export compliance declared as `ITSAppUsesNonExemptEncryption` `NO`, so that no upload stops at the export questionnaire and Beta App Review doesn't wait for an encryption declaration. Apple's App Encryption Declarations page: builds marked as using non-exempt encryption "must link to an app encryption declaration before the app can be submitted for beta app review". (Agent)
8. As the developer, I want the reason for `NO` recorded in the ticket: the only cryptography is `Insecure.SHA1` hashing in the alarm adapter, used to derive stable alarm IDs. It encrypts nothing, nothing goes over a network, and Apple's "Complying with Encryption Export Regulations" allows `NO` for no encryption or only exempt encryption. I confirm the answer before it merges. (Agent drafts, Brian confirms)
9. As the developer, I want the version set to 1.1.0 and the build number to start at 1 in `project.yml`, read by both the app's and the widget's Info.plist, so that the archive says 1.1.0 and the widget's version matches the app's. (Agent)
10. As the developer, I want the build number never bumped by hand after that, because the Organizer's "Manage version and build number" sets the build number "of all the content in your archive" on upload. (Agent, recorded in Implementation Decisions)
11. As the developer, I want a Release archive built locally before I archive, so that a Release-only warning (warnings are errors) or a signing problem is found by the agent, not in the Organizer. Archive only, no export or upload. (Agent)

### App Store Connect setup (Brian)

12. As the developer, I want the app record created in App Store Connect for `com.newrealityinteractive.nudgeinator`, with English (U.S.) as its primary language, before the first upload. Apple's "Distributing your app for beta testing and releases": "Before you upload your app to the App Store for the first time, create an app record". (Brian)
13. As the developer, I want the App Privacy label set to "Data Not Collected", matching the privacy manifest and the privacy policy. (Brian, agent confirms it still matches the app)
14. As the developer, I want TestFlight's test information filled in: a beta app description, a feedback email, and the privacy policy and marketing (support) URLs, in English (U.S.). The agent drafts the description. (Brian)
15. As the developer, I want the Beta App Review contact details and review notes filled in, with notes that explain why reminders ring as alarms through silent mode and Focus, and that no sign-in is needed. The agent drafts the notes. (Brian)
16. As the developer, I want an external group with my two testers, invited by email, so that they install through TestFlight without joining the App Store Connect team. (Brian)

### First build

17. As the developer, I want `scripts/test.sh` to pass on both simulators on the commit I archive, so that the build the testers get is the one the tests passed. (Agent runs, Brian archives)
18. As the developer, I want to archive with Product › Archive on the `NudgeInator` scheme, run Validate App in the Organizer, then distribute with "TestFlight & App Store" (never "TestFlight Internal Only", whose build can't go to the App Store). (Brian)
19. As the developer, I want each uploaded build's number, date and commit recorded in the upload ticket's Comments, because the repo never holds the number the Organizer chose. (Brian, the agent writes the line)
20. As the developer, I want the What to Test text from `docs/release-notes/1.1.0-testflight.md` pasted into the build, so that testers read the clean-reinstall steps before installing. (Brian)
21. As the developer, I want to install the build on my own iPhone from TestFlight before Beta App Review finishes, so that I find a broken build before my testers do. (Brian)
22. As the developer, I want the first 1.1.0 build submitted to Beta App Review and, once approved, added to the external group. The Beta App Review Details page: "Before an app can be distributed to external testers, it must be reviewed by Apple". (Brian)
23. As the developer, I want whatever Beta App Review asks about alarms that ring through silent mode and Focus recorded in this spec, so that the App Store spec's reviewer notes answer it up front. (Brian, agent records)

### Checks on the TestFlight build (device checks)

24. As the developer, I want a Relentless reminder to ring as an alarm at its due time under a Focus on the TestFlight install, as on the debug build. (Device check)
25. As the developer, I want a Gentle reminder's Time Sensitive nudge to arrive on the TestFlight install, so that the entitlement survived distribution signing. (Device check)
26. As the developer, I want the widget extension's alarm presentation, and its Open button, to work on the TestFlight install. (Device check)
27. As the developer, I want the Open intent from `NudgeShared` to open the reminder from the alarm on the TestFlight install, because an earlier plan in this repo noted package intents missing from archived builds though they worked from Xcode. (Device check)
28. As the developer, I want story 48's sequence (Delete All Data, uninstall, install from TestFlight) to leave no AlarmKit alarms behind, because uninstalling doesn't remove them. (Device check)
29. As a beta tester, I want to install the build from my TestFlight invitation and follow What to Test, so that I start 1.1.0 with no old reminders or leftover alarms. (Testers, story 48)
30. As a beta tester, I want to send a screenshot and a comment from the TestFlight app, and the developer to read them in the Organizer or App Store Connect, so that what I find reaches the developer. (Testers and Brian)

### Things the docs don't confirm (Brian checks in App Store Connect Help)

31. As the developer, I want the external tester limit, how long a build stays installable, and Beta App Review's usual turnaround looked up in App Store Connect Help and recorded here, because apple-rag-mcp doesn't cover App Store Connect Help. (Brian)
32. As the developer, I want to know whether TestFlight's test information requires a privacy policy URL for external testing. The App Store Connect API's beta app localization has a `privacyPolicyUrl` field and calls it "recommended for all apps that collect user or device-related data", but doesn't say whether App Store Connect requires it. If Help says it's required, the privacy policy page (story 33) blocks the external group (story 22). (Brian)

### App Store groundwork (Brian, agent drafts)

33. As the developer, I want a privacy policy page on my website that says Nudge-inator collects no data, makes no network connections, and keeps reminders on the phone until Delete All Data or uninstall, matching the manifest and the "Data Not Collected" label. The agent drafts it; I publish it and record the URL here. (Brian)
34. As the developer, I want a support page on my website with how to reach me and the clean-reinstall steps. The agent drafts it; I publish it and record the URL here. (Brian)
35. As a person reading another language later, I want both pages written in short, plain sentences with no idioms or wordplay, so that they translate cleanly. (Agent)
36. As the developer, I want the age-rating questionnaire answered from proposed answers the agent drafts, each one confirmed by me, with the answers and resulting rating recorded here. Apple's Age Ratings page: "You must fill out this information before submitting your app for review." (Brian)
37. As the developer, I want the price set to free, availability set to the United States only, and the Free Apps agreement confirmed as the only agreement needed. (Brian)
38. As the developer, I want this spec to note that premium add-ons later need the Paid Apps agreement, banking and tax, and that a new country needs its localization first. (Agent)
39. As the developer, I want the App Store name, subtitle and keywords drafted in English (U.S.) from `GLOSSARY.md` and the specs, so that I edit rather than start from nothing. They are drafts. (Agent drafts, Brian edits)
40. As the developer, I want the drafts to say which name is the App Store name and which is the home-screen name (`CFBundleDisplayName`, "Nudge-inator"), because they can differ. (Agent)
41. As the developer, I want the name, subtitle and keyword character limits checked in App Store Connect Help, because apple-rag-mcp doesn't cover them. (Brian)

## Implementation Decisions

- **Order.** Stories 2–11 (privacy manifest, export compliance, version numbers, local Release archive) merge before the first archive. The app record (12) exists before the first upload. The first archive is the first time App Store Connect checks any of them, so they go first. `scripts/test.sh` passes on both simulators before any archive.
- **Who does what.** Anything needing the developer account, App Store Connect, the website or the testers is a Brian story (`ready-for-human`). The agent drafts the text for those stories and records what Brian reports. Changes to the repo are agent stories.
- **Privacy manifest.** One `PrivacyInfo.xcprivacy` in the app target's resources, added through `project.yml` and then `xcodegen generate`. `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty, `NSPrivacyCollectedDataTypes` empty, and one `NSPrivacyAccessedAPITypes` entry: `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. Apple's "Privacy manifest files" sets the file name and keys. The widget extension gets none while it uses no required reason API ("Describing use of required reason API": each bundle whose executable uses one needs its own manifest).
- **What the manifest is based on (2026-10-24).** `UserDefaults` is read only through `.standard`, by the Default Pace record and the onboarding record, both in the app. The queued Dones file is in the app's own Application Support and is only checked for existence, read and deleted, with no file-timestamp API. The SwiftData store is in the App Group container with CloudKit off. Nothing uses `URLSession` or the network. The ticket re-checks this before merging.
- **Guard in `scripts/test.sh`.** Like its existing source checks (the engine's framework imports, the direct AlarmKit authorization read), it fails on `UserDefaults(suiteName:` anywhere and on any `UserDefaults` in the widget's sources, with a message pointing at the privacy manifest.
- **Export compliance.** `ITSAppUsesNonExemptEncryption` = `NO` in the app's Info.plist properties in `project.yml`. Reason: `Insecure.SHA1` hashing for alarm IDs only, no encryption, no network. If a later feature adds networking or encryption, it revisits this.
- **Version and build numbers.** `MARKETING_VERSION: 1.1.0` and `CURRENT_PROJECT_VERSION: 1` go in the project-wide settings, so the app and the widget share them. Both targets' Info.plist properties read them (`$(MARKETING_VERSION)`, `$(CURRENT_PROJECT_VERSION)`) instead of the hard-coded 1.0 and 1 that are there today. The Organizer's "Manage version and build number" raises the build number on upload, for the app and the widget together, so the repo's build number stays 1. Setting `MARKETING_VERSION` now, ahead of release, satisfies `docs/agents/issue-tracker.md`'s release step early. At release it is only checked, and the `v1.1.0` tag still waits for the last pace ticket.
- **Where build numbers live.** Each upload gets one line in the Comments of the ticket that uploaded it: build number, date, commit, and what changed since the last build. A build uploaded later for a pace fix goes in that pace ticket's Comments, with the same line.
- **Distribution.** Organizer › Distribute App › "TestFlight & App Store", with automatic signing, symbol upload and "Manage version and build number" on. Never "TestFlight Internal Only": Apple's "Distributing your app for beta testing and releases" says it "restricts access to your team" and prevents the build from being submitted to the App Store.
- **App Intents in the archive.** `NudgeShared` defines the Open intent with no `AppIntentsPackage` type. Apple's `AppIntentsPackage` page and "Configuring the runtime behavior of your app intents" say a shared framework's intent metadata lands in the framework's bundle, and the app and extension must name it through `AppIntentsPackage.includedPackages`. The docs don't say how this applies to a Swift package linked statically. Story 27 decides: if the Open intent works on the TestFlight install, nothing changes. If it doesn't, the fix is an `AppIntentsPackage` in `NudgeShared` that the app and widget include, in a ticket of its own.
- **TestFlight test information and Beta App Review details** follow the App Store Connect API's beta app localization (description, feedback email, marketing URL, privacy policy URL) and Beta App Review details (contact name, email and phone, whether a demo account is needed, and notes of at most 4,000 characters). No demo account: the app has no sign-in. The notes explain that a reminder keeps nudging until it's marked Done, Relentless reminders ring as AlarmKit alarms through silent mode and Focus, and alarm and notification permission are asked for during onboarding.
- **Testers.** One external group, my two testers invited by email. The first build of each version goes through Beta App Review; I install it on my own iPhone in the meantime.
- **Feedback.** Testers use the TestFlight app's screenshot and comment feedback. I read it in Xcode's Organizer or App Store Connect (Beta feedback crash and screenshot submissions). A finding that needs a fix becomes a ticket in `enhancement-pace`, the open feature, not here.
- **Localization.** Everything this spec writes (pages, test information, metadata drafts) is plain English (U.S.) with no idioms, so it translates. App strings stay in the String Catalogs. Nothing written here hard-codes English in a way that blocks adding a language or country.
- **Pricing and countries.** Free, the United States only, English (U.S.). Only the Free Apps agreement is needed. Premium add-ons later need the Paid Apps agreement, banking and tax. A new country needs its localization, metadata and pages first.
- **Age rating.** The agent proposes answers for each question in App Store Connect's age-rating questionnaire. The App Store Connect API's age rating declaration lists the topics: advertising, gambling, contests, loot boxes, messaging and chat, social media, user-generated content, unrestricted web access, parental controls, age assurance, health or wellness topics, medical information, and the content themes (violence, sexual content, profanity, horror, mature themes, alcohol, tobacco and drugs, weapons). Proposed: none or No for every one. The app is a reminders app with no web access, no user-to-user content, no ads and no purchases. Health or wellness topics: No, since the app doesn't talk about health, even if someone sets a reminder to take medicine. The expected result is the lowest rating. I confirm each answer, and the answers and rating are recorded under Further Notes.
- **App Store name, subtitle and keywords.** Drafts only, in the ticket for me to edit, built from `GLOSSARY.md`'s words (reminder, nudge, alarm, Done, Focus, strength, pace). The App Store name is what App Store Connect lists. The home-screen name stays `CFBundleDisplayName`, "Nudge-inator". Limits are checked in App Store Connect Help.
- **Web pages.** On my website. The agent drafts the text in the ticket as plain prose with headings, no site-specific markup. I publish and record the URLs under Further Notes.

## Testing Decisions

- A good test checks what App Store Connect and the phone will see in the built product, not how `project.yml` spells it.
- **The built app bundle (one seam).** A suite in the app's unit tests reads the bundle the tests are hosted in, and the widget bundle inside it. It checks: the app's version is 1.1.0 and equals the widget's; the app's build number equals the widget's; `ITSAppUsesNonExemptEncryption` is false; the app bundle contains `PrivacyInfo.xcprivacy`, which says no tracking, no collected data, and `CA92.1` for `UserDefaults`. Prior art: the app's existing unit tests, run by `scripts/test.sh` on both simulators.
- **Source guard.** The `scripts/test.sh` check on defaults suites and the widget's `UserDefaults`. Prior art: its framework-import and AlarmKit authorization-read checks. Shown failing once on a scratch change before it merges.
- **Local Release archive (story 11).** `xcodebuild archive` of the `NudgeInator` scheme in Release, which compiles with warnings as errors. It never exports or uploads.
- **Organizer's Validate App** is Apple's "limited, automated initial validation" and runs before every upload. A failure stops the upload, and its message goes in the ticket.
- **Device checks (stories 24–28)** run on the TestFlight-installed build on my iPhone, recording its iOS version, one at a time per `docs/agents/device-testing.md`'s walkthrough. The TestFlight install replaces any Xcode-installed copy, so the walkthrough notes what was installed first and leaves the phone as it found it: every reminder made for a check is deleted (cancelling its alarms) before moving on.
- `scripts/test.sh` runs everything on the `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` simulators before any archive.

## Out of Scope

- The full App Store description, screenshots and app preview. The beta and enhancement-pace tickets 19 and 20 can still change the UI.
- Accessibility declarations.
- App Review information and reviewer notes for the App Store submission. Story 23 collects what Beta App Review raises, for that spec.
- Other countries and languages.
- Premium add-ons, the Paid Apps agreement, banking and tax.
- The App Store version submission and release.
- Automating uploads (Xcode Cloud, `altool`, the App Store Connect API).
- Internal testers on the App Store Connect team.

## Further Notes

- Apple pages used (through apple-rag-mcp): "Distributing your app for beta testing and releases", "Privacy manifest files", "Describing use of required reason API", "Complying with Encryption Export Regulations", `ITSAppUsesNonExemptEncryption`, `AppIntentsPackage`, "Configuring the runtime behavior of your app intents", and the App Store Connect API pages for Beta App Review, Beta App Localizations, Beta Groups, App Encryption Declarations, App Info Localizations and Age Ratings.
- apple-rag-mcp doesn't cover App Store Connect Help. Tester limits, build expiry, Beta App Review turnaround, whether the privacy policy URL is required for external testing, and the metadata character limits are Brian's checks there (stories 31, 32, 41), not guesses.
- The docs don't say whether App Store validation rejects a widget whose version differs from the app's. Sharing one setting makes the question moot. Validate App would report it if it mattered.
- Recorded here when known:
  - Privacy policy URL: _(Brian)_
  - Support URL: _(Brian)_
  - Age-rating answers and resulting rating: _(Brian)_
  - App Store Connect Help findings (stories 31, 32, 41): _(Brian)_
  - What Beta App Review asked: _(Brian)_
