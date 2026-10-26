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

- [x] The app record exists for `com.newrealityinteractive.nudgeinator`: name "Nudge-inator", SKU `nudgeinator`, primary language English (U.S.). If the name is taken, Brian records the name chosen instead, and ticket 05's name drafts follow it.
- [x] The App Privacy label is "Data Not Collected", and the agent confirms it still matches the app and the manifest.
- [x] The agent drafts the beta app description, in plain English (U.S.), with the TestFlight-sharing line from spec story 42.
- [x] Brian enters the test information: the description, the feedback email, the marketing URL `https://newrealityinteractive.com/nudge-inator/`, and the privacy policy URL from ticket 03.
- [ ] The agent drafts Beta App Review notes (at most 4,000 characters) that name each behavior and how to see it: a reminder nudges until it's marked Done; Relentless reminders ring as AlarmKit alarms through silent mode and Focus; Break through Focus; Time Sensitive nudges; the onboarding permission requests. No sign-in or demo account.
- [ ] Brian enters the Beta App Review contact details and the notes.
- [ ] An external group exists with the two testers, invited by email.

## Before you start

- Builds on: spec Implementation Decisions, "TestFlight test information and Beta App Review details", "Privacy label basis" and "Testers", and Guideline 2.3.1(a) (generic notes are rejected). The vocabulary for the notes is in `GLOSSARY.md`.
- Watch for: the feedback email and the Beta App Review contact are Brian's and never go in the repo, so the drafts use placeholders (decided on 2026-10-25). A test-information field that has data can be changed but not cleared, so each URL is entered once. The beta app localization has no support URL field: the support URL belongs to the App Store listing (ticket 05).
- Developer stops: every App Store Connect step is Brian's; the agent writes the drafts and records what he reports.

## Comments

- 2026-10-25 (agent): Drafts and checks for Brian. Docs-only: no `tdd`, no `scripts/test.sh` or code review run. Open: criteria 1, 4, 6 and 7 are Brian's steps in App Store Connect; criterion 2 waits for his entry, and he enters the label himself. Status stays `ready-for-human`.

  **Criterion 2, label check (agent).** "Data Not Collected" still matches. `App/Resources/PrivacyInfo.xcprivacy` has no tracking, no tracking domains, no collected data, and one `UserDefaults` entry (`CA92.1`). The Swift sources in `App`, `NudgeWidgets` and `Packages` have no `URLSession`, `URLRequest`, `Network`, `WebKit`, analytics, ad or tracking-framework use. `UserDefaults` is used only in `DefaultPace.swift`, `AppModel.swift` and `OnboardingRecord.swift`. The SwiftData store has CloudKit off (`ReminderStore.swift:63`). The published privacy page says the same (ticket 03). Crash logs, usage information and feedback that TestFlight sends are Apple's collection, not the app's (spec, "Privacy label basis").

  **Criterion 3, beta app description (agent draft, English U.S.).** App Store Connect field, plain text. The TestFlight line is spec story 42. Feedback email and contact: Brian types them, they are not in the repo.

  ```text
  Nudge-inator keeps nudging you about a reminder until you mark it Done, the way an iPhone alarm keeps ringing.

  You set when a reminder starts, how often it repeats, and how hard it nudges: Gentle, Firm or Relentless. A Relentless reminder rings as an alarm, even when your iPhone is on silent or in a Focus. For Gentle and Firm reminders, you choose whether a nudge breaks through a Focus.

  Your reminders stay on your iPhone. The app has no account, no server and no tracking.

  What TestFlight shares with the developer: Apple collects crash logs and usage information from this beta and shares them with the developer. You can't turn this off. If you send feedback from TestFlight, the developer also gets your comment, your screenshot and details about your device, such as the model and iOS version. A screenshot shows whatever is on screen, including reminder text, so crop it first if you need to.

  Thank you for testing. Tell us what works and what doesn't.
  ```

  (About 1,000 characters; the field allows 4,000.)

  **Criterion 5, Beta App Review notes (agent draft, at most 4,000 characters).** Paste into the notes field. The contact name, email and phone go in the contact fields, never in the notes.

  ```text
  No sign-in or demo account is needed. The app has no accounts, no server and no network use. Reminders are stored on the iPhone.

  Nudge-inator keeps nudging about a reminder until the person marks it Done. A nudge is one alert: an alarm or a notification. Below are the behaviors a reviewer will meet and how to see each one.

  1. Permission requests (first launch). The first screen explains how the app nudges. Tap Continue. iOS then asks to allow notifications, then to allow alarms. Alarms use AlarmKit; the usage description is in NSAlarmKitUsageDescription. If the person denies a request, the app shows a permission banner that says what can still reach them, and it uses a weaker kind of nudge instead.

  2. A reminder nudges until it is marked Done. Tap the plus button (New Reminder), enter a title, set Starts to one or two minutes from now, and confirm. When the reminder comes due, it nudges, and it keeps nudging at its pace until the person taps Done on the reminder in the app. Stopping an alarm only silences that one ring; the next nudge still comes. After a set number of nudges or span of time, the reminder gives up and closes as Missed.

  3. Relentless reminders ring as AlarmKit alarms. In the New Reminder form, set Strength to Relentless. When it comes due, it rings as a system alarm, through silent mode and through Focus. The alarm has two buttons: Stop, which silences the ring, and Open, which opens the app on the reminder. Relentless reminders use only alarms. This is the reason for the alarm permission and for the behavior: the app is a reminder that the person wants to be hard to ignore.

  4. Break through Focus. Gentle and Firm reminders have a Break Through Focus switch in the form. On: the nudges are sent as alarms, which sound through silent mode and Focus. Off: the nudges are ordinary notifications that a Focus can hold. To see it, make one reminder with the switch on and one with it off, turn on a Focus (for example Do Not Disturb), and let both come due.

  5. Time Sensitive nudges. When a nudge is High or Urgent and alarms are not available, the app sends it as a Time Sensitive notification, which can break through a Focus. To see it, deny the alarm request, then make a Firm or Relentless reminder. Settings > Notifications shows whether Time Sensitive is on.

  6. Settings. Settings > How It Nudges explains each strength and repeats the onboarding text. Settings > Delete All Data deletes every reminder, tag and all history, and cancels every nudge and alarm. Settings > About has the privacy policy and support links and the build number.

  Strengths: Gentle, Firm and Relentless. Paces: Escalating (waits shrink as nudging goes on) and Consistent (one wait, from 2 minutes to 16 hours). To test quickly, use Consistent with a 2 minute wait.
  ```

  (About 3,000 characters.)

  **What Brian does next.** Criterion 1 (app record), then enter the label from criterion 2, the description and test information (criterion 4: description, feedback email, marketing URL `https://newrealityinteractive.com/nudge-inator/`, privacy policy URL `https://newrealityinteractive.com/nudge-inator/privacy/`), then the review contact and notes (criterion 6), then the external group (criterion 7). Enter each URL once: a field with data can be changed but not cleared. Report back what App Store Connect said, including whether the name was taken, and the agent records it here and in the spec's Further Notes.
- 2026-10-25 (Brian): Created the app record (criterion 1). He reported no name conflict, so the name stays "Nudge-inator".
- 2026-10-25 (Brian): Published the App Privacy label (criterion 2). His screenshot shows "Data Not Collected", "Data is not collected from this app", published by him, and the Privacy Policy URL `https://newrealityinteractive.com/nudge-inator/privacy/` set on the same page. The page lists the iOS App as "1.0 Prepare for Submission".
- 2026-10-25 (Brian): Entered the test information in English (U.S.) (criteria 3 and 4). His PDF of the Test Information page shows the description (965 of 4,000 characters used), a feedback email, the marketing URL and the privacy policy URL, with Save greyed out. The feedback email is not recorded here, by design. Not yet filled: the Beta App Review contact and notes (criterion 6).
