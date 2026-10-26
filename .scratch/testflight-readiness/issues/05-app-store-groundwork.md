# 05: App Store groundwork

**What to build:** The App Store groundwork that the beta's results won't change, decided now so the App Store submission spec cites it instead of deciding it again:
- the support page;
- the age rating;
- price and countries;
- drafts of the App Store name, subtitle and keywords.

Spec stories 34–41.

**Blocked by:** None (can start immediately).

**Status:** ready-for-human

- [x] The redone website spec publishes the support page at `https://newrealityinteractive.com/nudge-inator/support/`, with how to reach Brian and no beta section (the beta is invite-only). Brian records the URL under the spec's Further Notes.
- [x] Brian submits the age-rating questionnaire with None or No for every topic (confirmed on 2026-10-25), and the resulting rating is recorded under Further Notes.
- [x] The price is free and availability is the United States only, and the Free Apps agreement is confirmed as the only agreement needed.
- [x] The spec notes that premium add-ons later need the Paid Apps agreement, banking and tax, and a new country needs its localization first (already under Implementation Decisions, "Pricing and countries"; checked, not rewritten).
- [x] The agent drafts the App Store name, subtitle and keywords in English (U.S.) from `GLOSSARY.md`: the name 2–30 characters, the subtitle at most 30, the keywords at most 100 characters in total. The drafts say which is the App Store name and which is the home-screen name (`CFBundleDisplayName`, "Nudge-inator").
- [x] Brian edits the drafts, and the result is recorded in Comments.

## Before you start

- Builds on: spec Implementation Decisions, "Age rating", "Pricing and countries", "App Store name, subtitle and keywords" and "App Store URL fields". The name on the app record comes from ticket 04. If it isn't "Nudge-inator", the drafts follow it.
- Watch for: the support URL can't be changed without a new version submission once the app is submitted, so publish the support page exactly at `/nudge-inator/support/`. All text is plain English (U.S.) with no idioms (story 35). Nothing here blocks the beta.
- Developer stops: Brian's App Store Connect steps; Brian's edits to the drafts.

## Comments

- 2026-10-25 (agent): Docs-only: no `tdd`, no `scripts/test.sh`, no code review. Status stays `ready-for-human`. Open: criteria 1, 2, 3 and 6 are Brian's steps (website, App Store Connect, his edits to the drafts).

  **Criterion 4 (checked, not rewritten).** Spec Implementation Decisions, "Pricing and countries", says: premium add-ons later need the Paid Apps agreement, banking and tax; a new country needs its localization, metadata and pages first. Ticked.

  **Criterion 5, drafts (agent, English U.S.).** The app record's name is "Nudge-inator" (ticket 04), so the drafts follow it. Lengths counted with the shell.

  | Field | Draft | Length | Limit |
  |---|---|---|---|
  | App Store name (what App Store Connect lists) | `Nudge-inator` | 12 | 2–30 |
  | Subtitle | `Reminders that keep nudging` | 27 | 30 |
  | Keywords (comma-separated, no spaces) | `alarm,repeat,recurring,focus,silent,task,todo,habit,timer,persistent,urgent,alert,notify,schedule` | 97 | 100 |

  The home-screen name is separate: `CFBundleDisplayName`, "Nudge-inator" (the widget's is "Nudge-inator Widgets"). The two match today, and the App Store name can change without touching the home-screen name.

  Notes for Brian's edit: "reminder" and "nudge" come from `GLOSSARY.md`; the keywords leave them out because the name and subtitle already carry them. "alarm", "focus" and "silent" name what Relentless and Break through Focus do. "task", "todo", "habit" and "timer" are the words people may search for instead of "reminder"; the glossary avoids "task" for the app's own screens, so these are search terms only. Alternate subtitle, 26: `Nudges until you mark Done`. Plain words, no idioms (story 35).

  **Criterion 6.** _(Brian: edit the drafts; the result is recorded here.)_

- 2026-10-25 (Brian, via agent): Pricing and Availability checked in App Store Connect. Price is Free and availability is the United States only. Apple Silicon Mac and Apple Vision Pro availability are off, distribution is Public with the Apple School Manager reduced price off, tax category is App Store software, last-compatible versions are iOS, All. Criterion 3 stays open: the Free Apps agreement is not yet confirmed as the only agreement needed (Business tab). Canada was considered and left out for now.

- 2026-10-25 (Brian, via agent): Business tab checked. The Free Apps Agreement is Active (Oct 14, 2026 – Oct 13, 2027), so it meets what a free app needs. The Paid Apps Agreement is also Active (Oct 16, 2026), with a bank account and a U.S. W-9 on file, so the later premium add-ons won't wait on those. Nothing is pending. Criterion 3 ticked.

- 2026-10-25 (Brian, via agent): Age ratings are set. The Age Ratings page shows Age 4+ for 172 countries or regions (the lowest rating, as the spec expected), General Audiences for Brazil, and All Ages for South Korea and Vietnam. The rating is recorded under the spec's Further Notes. Criterion 2 ticked. The screenshot was cropped: it didn't show the United States in the list, and it didn't show the questionnaire answers, so those rest on Brian's confirmation of None or No for every topic.

- 2026-10-25 (Brian, via agent): Support page published. The agent fetched `https://newrealityinteractive.com/nudge-inator/support/`: HTTP 200, no redirect, how to reach Brian by email, and no mention of the beta or TestFlight. The URL is recorded in the spec's Further Notes. Criterion 1 ticked.

- 2026-10-25 (Brian, via agent): Final text, entered in App Store Connect (English U.S.) and read back from his PDF of the iOS App Version 1.1.0 page. Brian kept all three drafts unchanged. The version page now holds the matching version, 1.1.0.
  - App Store name: `Nudge-inator` (App Information; the home-screen name stays `CFBundleDisplayName`, "Nudge-inator").
  - Subtitle: `Reminders that keep nudging` (27 of 30).
  - Keywords: `alarm,repeat,recurring,focus,silent,task,todo,habit,timer,persistent,urgent,alert,notify,schedule` (97 of 100).
  - Support URL: `https://newrealityinteractive.com/nudge-inator/support/`.
  - Marketing URL: `https://newrealityinteractive.com/nudge-inator/` on the version page, the same as ticket 04's TestFlight entry (Brian first entered it without the slash, then changed it). Criterion 6 ticked.
  - Left for the App Store submission spec: description, promotional text, copyright, screenshots, release option (agent suggests manual), App Review contact and notes.
