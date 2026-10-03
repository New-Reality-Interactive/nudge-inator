# Validation Report — Nudge-inator

> **Historical.** This review ran on 2026-10-03, before its findings were applied. The findings
> were applied to DESIGN.md and EXPERIENCE.md the same day (see [.memlog.md](.memlog.md), "Review
> findings applied"), and the mockup was brought in line afterwards. Read the spines for current
> behavior; this file records why they changed. The table under
> [Resolution status](#resolution-status) gives each critical and high finding's status.

- **DESIGN.md:** docs/design/DESIGN.md
- **EXPERIENCE.md:** docs/design/EXPERIENCE.md
- **Run at:** 2026-10-03

## Overall verdict

The pair is close to a usable contract. Both files follow the required section order, all 37 `{token}` references resolve, the color system is fully specified with light, dark and Increased Contrast values, and the state table is unusually thorough. It doesn't yet extract cleanly, for four reasons: two of Rosa's flows contradicted the brief §3 strength tables and her own schedule; component names differ between the two files, and the core custom component (How It Nudges) has no visual spec; two nudge surfaces and states that the brief requires are missing; and the iPhone-only decision is tagged as an assumption, without the decision log that backs it. About 10 targeted edits would fix all of the rubric's high findings, and none of them needs a redesign. One of them, Flow 2's timings, was already fixed before this synthesis: Flow 2 now says 8:17 AM.

The accessibility review changes that picture. The rubric found nothing critical; the accessibility reviewer found one critical defect in the product behavior the spines describe, not just in how they are written. The alarm's system **Stop** silently counts as Done. For Rosa's blood-pressure pill that is a missed dose the app records as taken, and the only recovery is a Not Done button she has to remember to go and find. The reviewer adds six highs that bear on the same audience: no in-place undo for Done, no Not Done in Assistive Access, a fixed snooze budget nobody can extend, High and Urgent that look alike to color-blind users, two different "Done"s told apart by hue, and VoiceOver focus that lands on the next destructive Done button. So the spines are structurally close, but they are not ready to build from until Done is made reversible where the person already is. Four of the seven Nutrition Labels the README claims (VoiceOver, Voice Control, Differentiate Without Color Alone, Sufficient Contrast) are only partly supported as specified.

## Resolution status

| Finding | Status | Where it's resolved |
|---|---|---|
| **Critical:** the alarm's Stop silently counts as Done | Resolved | Done follow-up notification with Not Done; rows read "Done (alarm stopped)" with Not Done; Assistive Access "Done today" (EXPERIENCE › Nudge Surfaces, Reminder row, Assistive Access) |
| Flow 2's timings | Resolved before synthesis | EXPERIENCE › Key Flows, Flow 2 |
| Rosa's schedule doesn't add up | Resolved | Flows rewritten (Morning 8:00, Evening 9:45 PM with Ignore Quiet Hours) |
| Same component, different names | Resolved | Canonical names in both spines |
| How It Nudges and History have no spec | Resolved | EXPERIENCE › How It Nudges, History; DESIGN › Components |
| Top-up notification and alarm-limit fallback missing | Resolved | Keep-nudging notice; alarm-limit Via label (wording still an owner assumption) |
| iPhone-only tagged as an assumption | Resolved | EXPERIENCE › Foundation states it as the owner's decision |
| Done has no in-place undo | Resolved in the spines | Undo in the status message; no full swipe. Not drawn in the mockup yet |
| Assistive Access has no Not Done | Resolved in the spines | "Done today" with Not done yet. Not drawn in the mockup yet |
| Snooze budget is fixed | Partly resolved | Snooze length per reminder (default or longer); the 3-snooze cap is kept on purpose |
| High and Urgent look alike | Resolved in the spines | Urgency word and glyph in the card's top row. Not drawn in the mockup yet |
| Two kinds of "Done" told apart by hue | Resolved | Status label leads with a glyph and the words differ ("Done (alarm stopped)") |
| VoiceOver focus lands on the next Done | Resolved | Focus moves to the next card's summary (EXPERIENCE › Accessibility); mockup matches |
| Nutrition Labels only partly supported (VoiceOver, Voice Control, Differentiate Without Color Alone, Sufficient Contrast) | Specified; declaring waits for the release gate | EXPERIENCE › Accessibility Floor release gate, and brief §10 › Device checklist |

For the medium and low findings, the memlog's "Review findings applied" entry lists what changed.

## Category verdicts

- Flow coverage — adequate (high 2, one already resolved; medium 2; low 3)
- Token completeness — adequate (medium 4; low 1)
- Component coverage — thin (high 2; medium 2)
- State coverage — adequate (high 1; medium 3; low 2)
- Visual reference coverage — adequate (low 4)
- Bloat & overspecification — strong (low 2)
- Inheritance discipline — adequate (high 1; medium 1; low 1)
- Shape fit — strong (low 2)
- Accessibility (reviewer) — 1 critical, 6 high, 17 medium, 11 low. Floor is solid, but Stop = Done silently, focus lands on the next Done, and High vs Urgent are not distinguishable. Four Nutrition Labels are only partly supported.

## Findings by severity

### Critical (1)

**[Accessibility]** — The alarm's system Stop silently counts as Done (EXPERIENCE.md › Nudge Surfaces; Key Flows › Flow 2; brief §3)
The only recovery is Not Done in Reminder details, which the person has to remember to look for. Flow 2 shows the failure itself: Rosa stops the alarm out of reflex and finds out only at lunch, by chance. VoiceOver users hear only "Stop", and a Watch stop is just as silent. For medication this is a missed dose the app records as taken.
Fix: Keep Stop = Done, but make it visible and reversible: a quiet "Marked done: … Not done yet?" notification with a Not Done action, expiring at the next occurrence; record "Done (alarm stopped)" in Last 24 Hours and My Day with Not Done on the row; Settings explainer; repeat "Stopping the alarm counts as Done" in How It Nudges; test with older users.

### High (12)

**[Flow coverage]** — RESOLVED before synthesis: Flow 2's timings were wrong for Relentless (EXPERIENCE.md L327–332)
First alarm comes at about 8:17:30, not 8:15. Already fixed: Flow 2 now reads 8:17 AM.
Fix: Done.

**[Flow coverage]** — Rosa's schedule doesn't add up (EXPERIENCE.md L305–339)
One "Every Day at 8:00 AM" reminder can't produce an 8 PM dose; a Relentless 8 PM occurrence ends by about 8:50 PM, so it never reaches 10 PM quiet hours.
Fix: Make the evening dose its own reminder overlapping quiet hours (for example 9:45 PM), or give another reason for Ignore Quiet Hours; align Flow 2's "next one due".

**[Component coverage]** — Same component, different names in each file (DESIGN.md L323–331; EXPERIENCE.md L121–130)
Banner / Permission banner; HUD / Status message (HUD); Search token / Tag token field; Filter token / Filter tokens; frontmatter keys add a third form.
Fix: One canonical name each, used in both files and the frontmatter key.

**[Component coverage]** — How It Nudges has no visual spec; History has neither spec (DESIGN.md › Components; EXPERIENCE.md L126, L197)
Story-dev doesn't know How It Nudges' row anatomy, urgency color, via glyphs or "Next one due" styling. History has no spec on either side.
Fix: DESIGN.md entries for both; a Component Patterns row for History.

**[State coverage]** — Top-up notification and alarm-limit fallback missing (EXPERIENCE.md L117, L227–233; brief §4)
"Open Nudge-inator to keep nudging" (64th slot) has no copy, actions or tap target; `maximumLimitReached` has no Via label string.
Fix: Nudge Surfaces row for the top-up; Via label "Notification: too many alarms scheduled".

**[Inheritance discipline]** — iPhone-only v1 tagged [ASSUMPTION] but is an owner decision (EXPERIENCE.md L31; memlog L11)
The brief still says iPad in v1 in §5, §6, §8, §11 Q1/Q10.
Fix: Restate as a decision citing `.memlog.md`, add the memlog to both `sources`, list the brief sections it overrides.

**[Accessibility]** — Done has no in-place undo (EXPERIENCE.md › Swipe actions, HUD)
A full swipe or tremor closes the occurrence and cancels its alarms; the HUD offers nothing to reverse it.
Fix: Undo on the Done HUD until the next interaction; consider `allowsFullSwipe: false`.

**[Accessibility]** — Assistive Access has no Not Done (EXPERIENCE.md › Assistive Access)
Its users are the most likely to stop an alarm by reflex, and a caregiver can't fix it from the AA screen.
Fix: "Done today" section with a large Not done yet button; specify alarm, Time Sensitive and Live Activity behavior under AA.

**[Accessibility]** — Snooze budget is fixed and can't be extended (EXPERIENCE.md › Inspiration & Anti-patterns; brief §3)
At most 15 minutes on Relentless before alarms every 2 min. Against the intent of WCAG 2.2.1.
Fix: Keep the 3-snooze cap; allow a per-reminder snooze length or a "Longer snoozes" option.

**[Accessibility]** — High and Urgent are almost indistinguishable (DESIGN.md › Colors; Nudge card)
ΔE2000 0.5 with deuteranopia, luminance ratio 1.03; DESIGN.md's card anatomy doesn't place the urgency word.
Fix: Require the urgency word plus glyph next to "Nudge 3 of 20".

**[Accessibility]** — Two kinds of "Done" told apart mainly by hue (DESIGN.md › Reminder row, Status label)
Tinted Done button vs green "Done 8:22 AM" are both bare text on My Day.
Fix: Bordered/glyph Done button or "Mark Done"; `checkmark.circle.fill` on the status label; honor Button Shapes.

**[Accessibility]** — After Done, VoiceOver focus lands on the next Done button (EXPERIENCE.md › Interaction Primitives)
The next double-tap marks a different reminder done and cancels its alarms.
Fix: Focus the next card's summary, or the Nudging heading. Never an action button.

### Medium (29)

**[Flow coverage]** — Brief §6 features with no flow and not on the journey-less list (EXPERIENCE.md L389–391)
Pause/Resume, Delete, tag delete, Quiet Hours, Siri & Shortcuts, Open iOS Settings.
Fix: Add to the journey-less list with State Patterns pointers.

**[Flow coverage]** — Every Urgent step assumes iOS 26+ (Flows 2, 3)
iOS 18 uses a notification chain silent mode can mute.
Fix: Add an iOS 18 variant line to Flow 3.

**[Token completeness]** — No `tile-orange` token and no tile-to-row mapping (DESIGN.md L58–64, L208–210)
Fix: Add `tile-orange: '#C55300'` and a mapping.

**[Token completeness]** — Status-color contrast pairs have no stated target (DESIGN.md L231)
quiet-dark on elevated 4.05:1; status colors on tertiary fill 4.40–4.49:1.
Fix: Full pair table; state the large-text exemption.

**[Token completeness]** — No rule for how components resolve dark and IC values (DESIGN.md L105–158)
Fix: State the suffix convention; `alarm-tint` is the pinned exception.

**[Token completeness]** — Values components need but no token carries (DESIGN.md L307)
Elevated tertiary-fill, tertiary label, meter track, badge dark, on-accent IC.
Fix: Add tokens or "same as light" / "system by name".

**[Component coverage]** — Components that appear in only one file (both files)
7 visual-only, 6 behavior-only.
Fix: One-line DESIGN.md rows for system controls; behavior rows for Markers and Sheet bar buttons.

**[Component coverage]** — On-screen elements named in neither file (mockup L1993–2021, L2322–2331)
Settings rows, Welcome feature rows, Recent Searches, nudge meter.
Fix: Add rows or fold into parents.

**[State coverage]** — Form states missing (State Patterns)
Inexpressible repeat rule, notes 2,000-char limit, duplicate New Tag.
Fix: Add 3 rows.

**[State coverage]** — Settings states aren't committed (mockup L1249, L1996, L3233)
Quiet-hours default, Test Nudge disabled, Export result, Delete All Data copy.
Fix: Add the rows; state the quiet-hours default.

**[State coverage]** — Siri "most urgent" undefined, no nothing-nudging response (EXPERIENCE.md L253–255)
Fix: Define the order; add the empty response.

**[Inheritance discipline]** — Keyboard shortcuts with no source or tag (EXPERIENCE.md L185)
Fix: Tag [ASSUMPTION] or remove; scope Return-to-save.

**[Accessibility]** — Too many concepts and too much jargon (Voice and Tone; State Patterns)
Fix: Grade 6–8 target; consequence-first banners; "What's this?" disclosures.

**[Accessibility]** — "Not Done" reads like a status, not an action (State Patterns)
Fix: "Mark as Not Done" with a footer.

**[Accessibility]** — Permission banners can't be acknowledged and push Done down (Permission banner)
Fix: Collapse after acknowledgement; never above the first Done.

**[Accessibility]** — Alarm that rings out untouched is unspecified (Nudge Surfaces)
Fix: Add "ended without Stop or Snooze → still nudging"; confirm on device.

**[Accessibility]** — Lagoon vs neutral gray collapses for protanopes/deuteranopes (DESIGN.md › Buttons)
Fix: Require Button Shapes; tertiary actions in their own row or with a glyph.

**[Accessibility]** — Light status/secondary text on tertiary fill fails 4.5:1 (DESIGN.md › Contrast targets; Counts)
Fix: Full matrix; darken light status values; #8A87FF+ for quiet-dark on elevated; re-run audit.

**[Accessibility]** — Selected-tab contrast measured on an approximation (DESIGN.md › Contrast targets)
Fix: [to measure on device]; release gate.

**[Accessibility]** — No states for cards arriving, changing or vanishing while open (Nudge Surfaces)
Fix: Queued announcement for new cards; silent count ticks; focus rule on removal.

**[Accessibility]** — Nudge card accessibility structure unspecified (Nudge card, both files)
Fix: Title-first summary element plus separate Done and Snooze.

**[Accessibility]** — "One heading per screen" drops section headers (Accessibility Floor)
Fix: Header trait on every section header.

**[Accessibility]** — Notification tap opens Now with no focus target (Nudge Surfaces)
Fix: Scroll to the card, focus its summary.

**[Accessibility]** — Glyph-only iOS 26+ buttons need input labels (Responsive & Platform)
Fix: `accessibilityInputLabels` for each.

**[Accessibility]** — HUD and glass bars can cover the focused control (DESIGN.md › HUD)
Fix: HUD insets content; scroll-to-focus accounts for bars.

**[Accessibility]** — At AX3–AX5 Done can fall below the fold (DESIGN.md › Layout)
Fix: Done and Snooze right after the title at AX sizes.

**[Accessibility]** — "Every nudge vibrates too" can't be guaranteed (Interaction Primitives › Sounds)
Fix: "when the system allows it"; suggest LED Flash and Watch haptics.

**[Accessibility]** — WCAG 2.2 additions not covered (Accessibility Floor; README)
Fix: State 2.2 AA; add a fixed "How Nudges Work" row.

**[Accessibility]** — No evidence gate for the Nutrition Labels (Accessibility Floor)
Fix: Inspector audit plus manual AT runs as a release gate.

### Low (26)

**[Flow coverage]** — Flow 4 misstates when a strength change applies (Flow 4 step 6)
Fix: Quote the real footer.

**[Flow coverage]** — Dynamic Island alarm stated as fact (Flow 3 step 5)
Fix: Add "[to confirm on device]".

**[Flow coverage]** — Flow 5 has no failure path (EXPERIENCE.md L371–379)
Fix: Add the All Tags no-match failure.

**[Token completeness]** — Unit and naming nits in frontmatter (DESIGN.md L84–93)
Fix: "1px = 1pt"; rename to `family`; drop unused radii.

**[State coverage]** — Tag-line wrapping not stated (EXPERIENCE.md L197)
Fix: State wrap behavior.

**[State coverage]** — Welcome presentation and promises unclear (EXPERIENCE.md L59)
Fix: Confirm presentation; list or point to the 4 promises.

**[Visual reference coverage]** — "Spines win on conflict" stated three times
Fix: Keep one, link the others.

**[Visual reference coverage]** — "The mockup's audit" cited without a link (DESIGN.md L231)
Fix: Link README anchors.

**[Visual reference coverage]** — Stale placeholder-icon description (DESIGN.md L174)
Fix: Update to Lagoon gradient.

**[Visual reference coverage]** — Flows never point to mockup controls (Flows 2–4)
Fix: Add "→ mockup:" pointers.

**[Bloat & overspecification]** — Tag token field restates system behavior (EXPERIENCE.md L121)
Fix: Mark system vs app rules.

**[Bloat & overspecification]** — Same material in several places (EXPERIENCE.md L64, L218, L251–255, L282)
Fix: One home each, linked.

**[Inheritance discipline]** — Filters-reset assumption is an architecture decision (EXPERIENCE.md L75)
Fix: List as an open item for architecture.

**[Shape fit]** — Extra frontmatter keys (DESIGN.md frontmatter)
Fix: Confirm resolver ignores them, or nest under `meta`.

**[Shape fit]** — SF Symbols inventory sits in Shapes (DESIGN.md L290–294)
Fix: Optional "Iconography" label.

**[Accessibility]** — Some tap targets aren't shown as tappable (Nudge card; Quiet-hours chip)
Fix: Chevron or accent text; button trait and hints.

**[Accessibility]** — Relentless alarms every 2 min can distress anxious users (Sounds)
Fix: Suggest Firm; one-tap step-down.

**[Accessibility]** — Teal Snooze and green Done tiles close under tritanopia (Swipe actions)
Fix: Glyph and word on each tile.

**[Accessibility]** — Chosen count's fill carries no contrast (Counts)
Fix: Checkmark or bold label.

**[Accessibility]** — Done's announcement, list change and focus move unordered (Interaction Primitives)
Fix: One announcement after the layout change.

**[Accessibility]** — Spoken forms not specified (Voice and Tone)
Fix: Explicit labels; spelled-out durations.

**[Accessibility]** — Notification actions need a long press (Interaction Primitives)
Fix: Acknowledge as system constraint; tap lands on the card.

**[Accessibility]** — No shortcut for the top nudge; Snooze vanishing shifts positions (Keyboard)
Fix: ⌘↩ / ⌘S; keep a disabled "No snoozes left".

**[Accessibility]** — Live Activity and alarm can't follow "nothing truncates" (DESIGN.md › Live Activity)
Fix: 2 lines then truncate; full title in the label.

**[Accessibility]** — "All of it is off with Reduce Motion" is inaccurate (Motion)
Fix: Correct the wording; honor Prefer Cross-Fade.

**[Accessibility]** — Concatenated labels and RTL mirroring (Localization)
Fix: Positional format strings; meter fills from leading edge.

## Reviewer files

- docs/design/review-rubric.md (rubric walker; its mechanical notes say medium 11, but its category sections list 12, which this report uses)
- docs/design/review-accessibility.md (accessibility reviewer)
- docs/design/validation-report.html
