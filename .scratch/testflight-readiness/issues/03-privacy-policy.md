# 03: Privacy policy text and page

**What to build:** The agent drafts the privacy policy in this repo from spec story 33's fact list, in short, plain English (U.S.) sentences that translate cleanly. Brian edits and approves it. The redone website spec (new-reality-interactive repo) publishes it at `https://newrealityinteractive.com/nudge-inator/privacy/` before the TestFlight launch, and Brian records the URL in the spec. Spec stories 45, 33 and 35.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] A draft policy is in this repo. It says Nudge-inator collects no data and makes no network connections. Reminders stay on the iPhone until Settings › Delete All Data and are included in the person's own iPhone backups. Deleting the app alone leaves its alarms scheduled, so the policy says to use Delete All Data first. It makes no claim about what uninstalling does to reminders.
- [x] The draft meets Guideline 5.1.1(i): it explains retention and deletion, and how a person deletes their data. It has a last-updated date and a contact for privacy questions (a placeholder, since contact details stay out of the repo).
- [x] The draft says what TestFlight shares with the developer during the beta (crash logs and usage information, collected automatically by Apple with no opt-out, plus any feedback sent), matching spec story 42 and Further Notes.
- [x] The draft matches the privacy manifest (ticket 01) and the "Data Not Collected" label, re-checked against the app before Brian approves it.
- [ ] Brian approves the text (recorded in Comments).
- [ ] Brian records the published privacy policy URL under the spec's Further Notes, at `/nudge-inator/privacy/`.

## Before you start

- Builds on: spec story 33 (the fact list), Implementation Decisions, "Privacy label basis" and "Web pages", and Further Notes, "What TestFlight shares with me". The draft is plain text or Markdown, not HTML: the website spec builds the page. Ticket 02: Settings › About's Privacy Policy row opens `https://newrealityinteractive.com/nudge-inator/privacy/` (`AboutPage.privacyPolicy`, `App/Shell/AboutPage.swift`), on a 404 until the page is published (its Comments, the iPhone run).
- Watch for: no contact details in the repo, so use placeholders (decided on 2026-10-25). The path can't change once it's in TestFlight, so the published URL must be exactly `/nudge-inator/privacy/`. Publishing happens in the other repo, so the last criterion waits on Brian. Ticket 04 waits for it, because the privacy URL is entered in TestFlight once.
- Developer stops: Brian's edit and approval of the text; Brian publishing and recording the URL.

## Comments

- 2026-10-25 (agent): Draft is `docs/privacy-policy.md`, with the date and contact as `[PLACEHOLDER]`s. Re-checked against the app: no networking or analytics code in the Swift sources; `App/Resources/PrivacyInfo.xcprivacy` has no tracking, no collected data and only `UserDefaults` `CA92.1`; Settings › Delete All Data's alert says it deletes every reminder, tag and all history and cancels every nudge and alarm. The policy says opening an About link starts the browser, and the app sends nothing. Docs-only: no `tdd`, no `scripts/test.sh` or code review run. Open: criterion 5 (Brian approves the text) and criterion 6 (Brian publishes at `/nudge-inator/privacy/` and records the URL in the spec's Further Notes). Status stays `ready-for-agent`.
