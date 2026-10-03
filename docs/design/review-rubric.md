# Spine Pair Review — Nudge-inator

Reviewed 2026-10-03: `DESIGN.md` and `EXPERIENCE.md` (both updated 2026-10-03). Checked against
`docs/product/brief.md`, `docs/product/addendum.md`, the mockup (`index.html` was searched, not read
in full, plus `README.md`) and `docs/design/.memlog.md`. Line numbers are from the files as reviewed.

## Overall verdict

The pair is close to a usable contract. Both files follow the required section order, all 37 `{token}`
references resolve, the color system is fully specified with light, dark and Increased Contrast
values, and the state table is unusually thorough. It doesn't yet extract cleanly, for four reasons:
- Two of Rosa's flows contradict the brief §3 strength tables, and her own schedule.
- Component names differ between the two files, and the core custom component (How It Nudges) has
  no visual spec.
- Two nudge surfaces and states that the brief requires are missing.
- The iPhone-only decision is tagged as an assumption, without the decision log that backs it.

About 10 targeted edits would fix all of the high findings. None of them needs a redesign.

## 1. Flow coverage — adequate

Each brief §6 screen was mapped to a Key Flow or to the journey-less list (EXPERIENCE.md L389–391):
- **Covered by flows:** Now (1, 2, 3), My Day (4), Tags (5), Search (6), Reminder details (2, 4),
  New/Edit (1, 4), First launch (1).
- **Listed as journey-less:** Assistive Access, Rename Tag, and some of the Settings actions.

All 6 flows have a named protagonist, numbered steps and a marked climax, and 5 of the 6 have a
failure path. The timings were checked against the brief §3 strength tables.

### Findings
- **[high]** Flow 2's timings are wrong for Relentless. The intervals are 10, 5 and 2.5 min, so
  nudge 3 (still High) comes at 8:15 and the first alarm (nudge 4, Urgent) at about 8:17:30, not
  8:15. That makes "Done 8:15 AM" in step 4 wrong too. Brief §7 makes the nudges "fully determined…
  testable with a fixed clock", and QA and story-dev will copy these times into test fixtures
  (EXPERIENCE.md L327–332). *Fix:* use 8:17 AM (or say "about 8:18") in steps 2 and 4, or start the
  flow at nudge 4.
- **[high]** Rosa's schedule doesn't add up:
  - She takes pills "at 8 AM and 8 PM", but step 4 sets one reminder, "Every Day at 8:00 AM".
    Flow 2 step 5 then says "the next one isn't due until 8 PM", which that repeat can't produce.
  - Step 6 says the evening dose "falls in her 10 PM quiet hours some nights". It doesn't: a
    Relentless occurrence at 8 PM runs out its 20 nudges by about 8:50 PM (plus 3 snoozes of
    5 min), well before 10 PM. So the reason given for Ignore Quiet Hours is wrong.

  (EXPERIENCE.md L305–339.) *Fix:* make the evening dose its own reminder at a time that
  overlaps quiet hours (for example 9:45 PM), or give a different reason for Ignore Quiet Hours.
  Then make Flow 2's "next one due" match whichever schedule you choose.
- **[medium]** Several brief §6 features have no flow and aren't on the journey-less list:
  Pause/Resume and Delete (Reminder details), deleting a tag (Tags › Edit), Quiet Hours, Siri &
  Shortcuts, and Open iOS Settings (EXPERIENCE.md L389–391). *Fix:* add them to the journey-less
  list, with a pointer to the State Patterns rows that cover them. Pause/Resume could instead be a
  failure branch of Flow 4.
- **[medium]** Every Urgent step assumes iOS 26 or later (AlarmKit). iOS 18 is a supported tier
  where the climax works differently: a notification chain every minute up to 10, and silent mode
  can mute it (brief §4). No flow covers it (Flows 2 and 3). *Fix:* add an iOS 18 variant line to
  Flow 3: "On iOS 18, nudge 4 starts a notification chain…".
- **[low]** Flow 4 step 6 says that switching to Firm "applies from the next time it's due". The
  mockup's form footer (index.html L2125) and brief §3 say a new strength applies from the next
  nudge, and a new schedule from the next time it's due. *Fix:* quote the real footer, or say
  "applies to tomorrow's walk".
- **[low]** Flow 3 step 5 puts the alarm "in the Dynamic Island" over the app. Brief §10 lists
  that presentation as unconfirmed (EXPERIENCE.md L347). *Fix:* add "[to confirm on device]", as
  Nudge Surfaces does at L233.
- **[low]** Flow 5 has no failure path, although one exists in State Patterns (EXPERIENCE.md
  L371–379). *Fix:* add "Failure: All Tags matches nothing → 'No reminder has all of these
  tags…'".

## 2. Token completeness — adequate

All 37 `{path}` references across both files resolve. Every status color and the accent has all
four values (light, dark, IC, dark IC). The system semantic colors are declared as "for reference,
used by name". I recomputed the contrast for the status colors against each surface.

### Findings
- **[medium]** The mockup's Settings › Alarms row uses `--tile-orange` (index.html L1994), but
  DESIGN.md defines no `tile-orange` token. DESIGN.md also never says which tile goes with which
  Settings row. The mockup uses red for Notifications, orange for Alarms, gray for Open iOS
  Settings and Version, blue for Test Nudge and Export, purple for Siri, and red for Delete All
  Data (index.html L1993–2021) (DESIGN.md L58–64, L208–210). *Fix:* add `tile-orange: '#C55300'`
  and a one-line mapping from tile to row. Also confirm that red and orange tiles on permission
  rows don't break "one color, one meaning" (tiles are exempt only implicitly).
- **[medium]** The status-color contrast pairs are left to "Per the mockup's audit" (DESIGN.md
  L231), so no target is set. Computed values:
  - `quiet-dark` #7D7AFF on `cell-dark-elevated` #2C2C2E is **4.05:1**, and `quiet-dark-ic` on it
    is 6.16:1 (target 7:1). Either fails wherever quiet text appears inside a sheet, such as a
    quiet-hours note in the form's How It Nudges preview.
  - `positive`, `warning` and `neutral` on `tertiary-fill` are 4.40–4.49:1. That passes only as
    large text, and the spine never states the 3:1 large-text rule. These pairs occur in the
    chosen count cell.

  *Fix:* add a row for each status color on cell, grouped background, tertiary fill and the
  elevated cell. State the large-text exemption, and either check the quiet pairs inside sheets
  or forbid quiet text there.
- **[medium]** Nothing says how frontmatter components pick up dark and IC values. Every
  `components` entry references light tokens only (`{colors.accent}`, `{colors.cell}`), and
  `alarm-tint` deliberately pins `-dark`. Nothing tells a resolver that `X` maps to `X-dark`,
  `X-ic` or `X-dark-ic` for each appearance (DESIGN.md L105–158). *Fix:* add one sentence under
  Colors stating the suffix convention, and that `alarm-tint` is the only pinned exception.
- **[medium]** Some values the components need are missing:
  - `tertiary-fill` elevated dark (#3A3A3C, mockup L58) and IC (#E9E9EE, L90). `button-bordered`
    and `count-chosen` use these inside sheets.
  - "Tertiary label" (the chevron, DESIGN.md L307) is used in prose but has no token. Neither
    does the nudge-meter track.
  - `badge` has no dark value. The mockup uses the same value in dark mode, so say so.
  - The on-accent IC values aren't stated.

  *Fix:* add the tokens, or note "same as light" or "system `tertiaryLabel` by name".
- **[low]** The frontmatter is in `px` and the prose is in pt. `typography.fontFamily` is used as
  a role name, which collides with the spec's property name. `rounded.segment` and
  `rounded.stepper` are never referenced (DESIGN.md L84–93). *Fix:* add a "1px = 1pt" note, rename
  the role to `family`, and drop or reference the unused radii.

## 3. Component coverage — thin

I compared the 19 components in DESIGN.md › Components with the 19 rows in EXPERIENCE.md ›
Component Patterns:
- **In both files:** 7 components. Nudge card, Reminder row, Via label, Strength badge, Status
  label, Counts, Quiet-hours chip and Swipe actions match by name; one of these is only a near
  match.
- **Named differently in each file:** 4 components.
- **Visual spec only:** 7 components.
- **Behavior only:** 7 components.

### Findings
- **[high]** The two files use different names for the same component, so a grep for a component
  name finds only one side:

  | DESIGN.md | EXPERIENCE.md |
  |---|---|
  | **Banner** | **Permission banner** |
  | **HUD** | **Status message (HUD)** |
  | **Search token** | **Tag token field** |
  | **Filter token** | **Filter tokens** |

  The frontmatter keys (`banner`, `search-token`, `filter-token`) add a third form (DESIGN.md
  L323–331; EXPERIENCE.md L121–130). *Fix:* choose one canonical name for each and use it in both
  files and the frontmatter key.
- **[high]** **How It Nudges** has no visual spec. It's the app's main custom component, a live
  preview built from the scheduler's rules. Story-dev doesn't know its row anatomy, whether rows
  carry the urgency color, how the via glyphs appear, or how "Next one due" is styled.
  **History** (event rows that "wrap under their time", L197, used in Flows 2 and 4) has neither
  a visual spec nor a behavioral row (DESIGN.md Components; EXPERIENCE.md L126, L197). *Fix:* add
  DESIGN.md entries for both, and a Component Patterns row for History (90-day window, grouping,
  event text from the fixed phrases).
- **[medium]** The other components appear in only one file:
  - **Visual spec only:** Buttons, Sheet bar buttons, Markers, Tag tile, Alarm, Live Activity,
    Assistive Access. Markers need behavior: does "Now" move live, and does the list scroll to it?
    Sheet bar buttons need their enable and disable rules and what Return does. Alarm, Live
    Activity and Assistive Access are covered by their own sections, so link to them.
  - **Behavior only:** Match control, Strength picker, Give-up limit, Title field, Confirmation,
    Alert.

  *Fix:* for system controls, add a one-line DESIGN.md row "system `Picker(.segmented)` as-is";
  add behavior rows for Markers and Sheet bar buttons.
- **[medium]** Several things on screen aren't named as components in either file: Settings rows
  (icon tile, trailing status "On · Time Sensitive off"), Welcome feature rows, Recent Searches
  (with Clear), and the nudge meter. The meter has a visual spec inside Nudge card, but no token
  and no behavior (mockup index.html L1993–2021, L2322–2331). *Fix:* add rows for them, or fold
  each into a named parent component.

## 4. State coverage — adequate

I walked every surface in the IA table against the State Patterns table (EXPERIENCE.md L137–167).
Now, My Day, Tags, Search, Reminder details and Rename Tag are well covered: empty, filtered-empty,
permission, error and race states. Loading is explicitly "none".

### Findings
- **[high]** Two surfaces and states that brief §4 requires are missing:
  - **The "Open Nudge-inator to keep nudging" notification.** This is the reserved 64th slot,
    sent when the scheduled nudges run out. It's in neither Nudge Surfaces nor State Patterns, so
    its copy, actions and tap target aren't specified.
  - **The alarm-limit fallback** (`maximumLimitReached`). Brief §4 says the card and How It Nudges
    "say why" a nudge arrives a weaker way. The Via label lists only permission reasons
    (EXPERIENCE.md L117, L227–233).

  *Fix:* add a row to Nudge Surfaces for the top-up notification, and a Via label string such as
  "Notification: too many alarms scheduled".
- **[medium]** The form is missing states:
  - Brief §6 says "Rules the form can't express are kept as they are", but no state covers a
    reminder whose repeat rule the form can't show.
  - The notes 2,000-character limit (brief §3) has no stated behavior.
  - There's no state for a duplicate name typed into **New Tag** on the form's Tags page.

  *Fix:* add 3 State Patterns rows.
- **[medium]** Settings states aren't committed:
  - Quiet hours are on by default, 10 PM to 7 AM (mockup index.html L1249, L3233). Flow 1 depends
    on this, but the spine never states it, nor that quiet hours can be turned off.
  - **Send a Test Nudge** is disabled while notifications are off (L1996).
  - The Export Data result (share sheet, JSON per brief §11 Q12) isn't specified.
  - The consequence copy for the Delete All Data alert isn't given.

  *Fix:* add the rows, and state the quiet-hours default in Foundation or State Patterns.
- **[medium]** The Siri section covers only the case where something is nudging. It doesn't say
  what "Mark … done" or "Snooze" do when nothing is nudging. "Most urgent" isn't defined (highest
  urgency? earliest due? most nudges sent?), and the App Intent needs a deterministic rule. The
  disambiguation [ASSUMPTION] hides this gap (EXPERIENCE.md L253–255). *Fix:* define the order,
  and add the response for when nothing is nudging.
- **[low]** Brief §10 calls for a device check with 10 or more tags on one reminder. "Nothing
  truncates" (L197) implies the tag lines in rows and cards wrap, but neither file says so.
  *Fix:* state wrap behavior for tag lines in rows, cards and details.
- **[low]** Welcome is listed as "Full-screen", but the mockup presents it as a sheet
  (index.html L2322, L3261). Its four promises (and their iOS 18 variant) appear only in the
  mockup (EXPERIENCE.md L59). *Fix:* confirm the presentation, and either list the 4 promise
  titles or point to them explicitly.

## 5. Visual reference coverage — adequate

**What exists:**
- `.working/color-themes-1.html`, linked inline at DESIGN.md L196 with what it illustrates (the
  accent choice).
- `imports/`, which is empty.
- The mockup and its README, linked from both spines.

### Findings
- **[low]** "Spines win on conflict" is stated three times: DESIGN.md L181–182, EXPERIENCE.md
  L21–24 and L78–80. *Fix:* keep one statement in EXPERIENCE.md Foundation, and reduce the others
  to a link.
- **[low]** The contrast table cites "the mockup's audit" without a link (DESIGN.md L231). *Fix:*
  link to `README.md#color` and `#how-it-was-checked`.
- **[low]** DESIGN.md L174 says the mockup's icon is a "red-orange gradient placeholder". Since
  2026-10-03 it's a Lagoon gradient (index.html L669, L716; memlog L24). *Fix:* update the
  sentence.
- **[low]** Flows and states never point to the mockup's controls or seeded data, although the
  README names them (for example "Try it on 'Walk the dog'" and the "Mockup controls" section).
  *Fix:* add a "→ mockup:" pointer to Flows 2, 3 and 4.

## 6. Bloat & overspecification — strong

Little bloat. The tokens carry most of the visual spec. The pixel values in prose (5 pt stripe,
6 pt meter, 64 pt Assistive Access buttons) aren't covered by tokens, so they earn their place.

### Findings
- **[low]** The Tag token field row restates keyboard behavior that `searchable` tokens provide
  (Delete selects then removes, the Clear button). Brief §10 lists some of it as "can't know until
  on device" (EXPERIENCE.md L121). *Fix:* mark which rules are system behavior and which the app
  specifies.
- **[low]** The same material appears in several places:
  - The Siri phrases are in the IA table (L64) and in Siri & Shortcuts (L251–255).
  - The iOS 18 row (L282) restates the brief §5 table.
  - The Nutrition Labels (L218) restate brief §7.

  *Fix:* keep each in one place and link to it from the others.

## 7. Inheritance discipline — adequate

**What resolves:**
- The anchors to the brief and addendum (`#3-product-concepts`, `#4-how-nudges-reach-you`,
  `#c-…`, `#d-…`).
- The links between the two files (`#component-patterns`, `#brand--style`, `#colors`).
- Every token reference.

**What matches the sources:** the glossary (nudge, strength, give-up limit, carry-over, Not Done),
the copy strings (all 40 or so checked against the mockup) and Lagoon's values (memlog L20).

### Findings
- **[high]** iPhone-only v1 is tagged [ASSUMPTION] (EXPERIENCE.md L31), but it's an owner
  decision (memlog L11). Neither spine lists the memlog in `sources`. Meanwhile the brief still
  says iPad in v1 in several places, and architecture will read those too: the success measures
  (§8, "on iPhone and iPad"), §11 Q1 and Q10 (size classes for iPad), and §5. *Fix:* restate it
  as a decision citing `.memlog.md`, and add the memlog to both files' `sources`. List the brief
  sections it overrides (§5, §6, §8, §11 Q1/Q10), so architecture doesn't plan
  `NavigationSplitView` for v1.
- **[medium]** Some keyboard shortcuts have no source and no tag:
  - ⌘1–⌘4 and "Return saves a sheet" (EXPERIENCE.md L185). The sources give only ⌘N and ⌘F
    (brief §5, iPad), and Return to choose a tag (README L766).
  - "Return saves a sheet" conflicts with Return taking the first matching tag on the form's Tags
    page and in the token field.
  - With 5 tabs on iOS 18, ⌘1–⌘4 leaves Search out.

  *Fix:* tag them as [ASSUMPTION], or remove them. Scope Return-to-save to sheets whose focus is
  not in a text or token field.
- **[low]** The filters-reset [ASSUMPTION] (L75) decides how filter state is stored (in memory
  versus persisted), which is an architecture decision. *Fix:* list it under brief §11 questions,
  or as an explicit open item for architecture.

## 8. Shape fit — strong

**DESIGN.md:**
- **Section order:** matches the required order exactly. Brand & Style → Colors → Typography →
  Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts.
- **Frontmatter:** uses the spec's keys.

**EXPERIENCE.md:**
- **Required sections:** all eight are present and in order. Foundation, IA, Voice and Tone,
  Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, Key Flows.
- **Added sections:** Nudge Surfaces, Assistive Access, Siri & Shortcuts, Localization, Responsive
  & Platform, and Inspiration & Anti-patterns. Each earns its place, and Nudge Surfaces matters
  most.

### Findings
- **[low]** DESIGN.md's frontmatter adds `status`, `created`, `updated` and `inherits`, which the
  DESIGN.md spec doesn't define. *Fix:* check that the token resolver ignores unknown keys, or
  move them under a `meta` key.
- **[low]** The SF Symbols inventory sits in Shapes (DESIGN.md L290–294). *Fix:* it's acceptable
  as it is. Optionally, label it "Iconography" as a sub-paragraph so consumers find it.

## Mechanical notes

- **Findings by severity:** critical 0, high 6, medium 11, low 15.
  - **High:** Flow 2's timings; Rosa's schedule; component name drift; How It Nudges and History
    specs; the top-up notification and alarm-limit fallback; iPad provenance.
- **Token references:** 37 unique `{…}` references across both files, all resolved, 0 unresolved.
- **Color variants:** every status color and the accent has `-dark`, `-ic` and `-dark-ic`. The
  system colors and tiles are intentionally partial. Tiles keep one value in every mode, as stated.
- **Contrast:**
  - Accent pairs match the color-themes page: 6.74 on cell, 6.04 on grouped background and 5.67
    on tertiary fill, all in light mode.
  - Tile colors with white glyphs are 4.54–5.23:1. All pass.
  - Badge is 4.56:1, and `badge-ic` is 7.36:1.
- **Copy checked against the mockup and matching:**
  - "All clear. Nothing needs you right now."
  - "Done: … Nudging stopped." and "Its alarms are cancelled."
  - "Snoozed until …"
  - "No snoozes left. Only Done stops it."
  - "Marked not done (nudging again)"
  - "Notification cleared (still nudging)"
  - The 3 permission banners
  - "Quiet hours can't start and end at the same time."
  - "No Results for "…""
  - "Search Your Reminders"
  - "No occurrences yet…"
  - "Missed: …" and "Skipped: …"
  - "Done after N nudges"
  - "Filter (N)"
- **Copy that differs from the mockup:**
  - Flow 1 quotes How It Nudges without the mockup's trailing "(17)" count (index.html L1236).
    This is fine as a paraphrase.
- **Not in the mockup:** "Open Nudge-inator to keep nudging" (brief only).
- **Flow 3 timings are consistent** with Firm, assuming that after a snooze the next nudge comes
  when the snooze ends: 7:30 N1, 8:00 N2, 8:15 N3 (High), snooze 15 min, 8:30 N4 (Urgent), N5 →
  "Done after 5 nudges".
- **Sources:** `docs/product/.memlog.md` exists, and the design memlog names it as a source (L7),
  but neither spine lists it.
