# Accessibility review: DESIGN.md + EXPERIENCE.md

> **Historical.** This review ran on 2026-10-03, before its findings were applied. The findings
> were applied to DESIGN.md and EXPERIENCE.md the same day (see [.memlog.md](.memlog.md), "Review
> findings applied"), and the mockup was brought in line afterwards. Read the spines for current
> behavior; this file records why they changed. The critical and high findings are
> tracked in [validation-report.md › Resolution status](validation-report.md#resolution-status).

Reviewed 2026-10-03 against Apple HIG (iOS 18/26/27), WCAG 2.2 AA and the App Store Accessibility
Nutrition Label criteria. Scope: `DESIGN.md` and `EXPERIENCE.md`, with the brief, the mockup README
(Accessibility, Color, Typography) and `.memlog.md` as context. Contrast numbers below were computed
with the WCAG relative-luminance formula. Color distances are CIEDE2000, with color-blindness
simulated by Machado 2009 at full severity.

## Verdict

The spines' floor is solid. Every status has a word, text scales to AX5 with stacking layouts,
nothing runs on a timer, swipes are only shortcuts, and Lagoon meets its contrast targets. If an
engineer builds what the spines say, though, three things go wrong for this audience. The alarm's
Stop marks a reminder Done without a word, and getting it back takes several steps and the person
remembering. VoiceOver focus lands on the next destructive Done. And some light-mode status text,
plus the High vs Urgent color pair, isn't actually distinguishable. VoiceOver, Larger Text, Dark
Interface and Reduced Motion are close to declarable. Differentiate Without Color Alone, Sufficient
Contrast and Voice Control each need specific fixes first.

## Findings

### Cognitive load and recovery

- **[critical]** The alarm's system **Stop** silently counts as Done. The only recovery is
  **Not Done** in Reminder details, which the person has to remember to look for. Flow 2 shows the
  failure itself: Rosa stops the alarm out of reflex and finds out only at lunch, by chance. One
  onboarding sentence won't hold for people with memory impairment or ADHD. VoiceOver users hear
  only "Stop", and a stop on the paired Apple Watch is just as silent. For medication this is a
  missed dose that the app records as taken. (EXPERIENCE.md › Nudge Surfaces; Key Flows › Flow 2;
  brief §3 Done) *Fix:* Keep Stop = Done (brief §10), but make it visible and reversible where the
  person already is. After a Stop, post a quiet notification right away: "Marked done: Blood-pressure
  pill. Not done yet?" Give it a **Not Done** action, and have it expire when the next occurrence
  falls due. Record the Done as "Done (alarm stopped)" in Last 24 Hours and in My Day, and offer
  **Not Done** on that row as a button and a swipe/rotor action. Add a Settings explainer, and
  repeat "Stopping the alarm counts as Done" in How It Nudges for every reminder that has alarms.
  Test this with older users, as brief §10 already asks.
- **[high]** Done has no in-place undo. A full swipe performs Done, so a tremor or a stray swipe
  closes the occurrence and cancels its alarms. The HUD confirms but offers nothing to reverse it.
  (EXPERIENCE.md › Component Patterns › Swipe actions, Status message (HUD); Interaction Primitives)
  *Fix:* Give the Done HUD an **Undo** button that runs Not Done and stays until the next
  interaction, consistent with "never on a timer". Consider turning off full-swipe-to-Done
  (`allowsFullSwipe: false`) so a swipe only reveals the tile.
- **[high]** Assistive Access has no Not Done. The people it serves are the most likely to stop an
  alarm by reflex, and a caregiver can't see or fix that from the AA screen. (EXPERIENCE.md ›
  Assistive Access) *Fix:* Add a "Done today" section to the AA screen with a large **Not done yet**
  button on each item, available until its next occurrence. Specify how alarms, Time Sensitive
  notifications and Live Activities behave while Assistive Access is on (verify on a device), and
  tell caregivers in Settings › Accessibility.
- **[medium]** The spines use a lot of concepts and jargon for a stressed or older reader:
  strength, give-up limit, carry-over, "Starts higher", Time Sensitive, Focus, notification chain,
  "via". The permission banners assume the reader knows all of them ("High nudges come as ordinary
  notifications, so a Focus can hold them"). (EXPERIENCE.md › Voice and Tone; State Patterns)
  *Fix:* Set a plain-language target, about grade 6–8, for every string shown outside the form.
  Lead each banner with the consequence in everyday words ("Some reminders may not reach you during
  Do Not Disturb"). Give each concept a one-line "What's this?" disclosure in the form footer, and
  run a microcopy check with a tester over 65.
- **[medium]** The label **Not Done** reads like a status word, not an action, and it sits among
  status words (Done, Missed, Skipped). (EXPERIENCE.md › State Patterns › Latest occurrence done)
  *Fix:* Label it **Mark as Not Done** (or **Undo Done**), with a footer saying what will happen:
  "Nudging starts again in 5 min."
- **[medium]** Permission banners stay until the permission changes, can't be acknowledged and
  stack above the Nudging section. If someone deliberately denied alarms (because of anxiety or
  hearing aids, say), a red or orange banner sits there forever and pushes Done further down at
  large text sizes. (EXPERIENCE.md › Component Patterns › Permission banner) *Fix:* After the
  person acknowledges a banner, collapse it to a one-line row at the bottom of Now and keep the full
  explanation in Settings. Never put a banner above the Nudging section's first Done.
- **[low]** Some tap targets aren't shown as tappable. The nudge card opens details with no
  chevron, and the quiet-hours chip is a button drawn in indigo, not the accent, which goes against
  "accent means tappable". (DESIGN.md › Components; EXPERIENCE.md › Quiet-hours chip) *Fix:* Give
  the chip a chevron or accent text and the button trait with a hint ("Opens Quiet Hours settings").
  Make sure the card's accessibility hint says "Opens details".

### Timing and interruptions

- **[high]** Snoozes are fixed at 3 per occurrence, with lengths set by the strength (Relentless:
  5 min). Someone who needs more time to act gets at most 15 minutes before alarms every 2 min, and
  only Done stops them. That could be someone with limited mobility getting to the pills, or a
  caregiver mid-task. The give-up limit can be adjusted, but nothing that buys more time can be.
  This goes against the intent of WCAG 2.2.1 Timing Adjustable for the app's core timed interaction.
  (EXPERIENCE.md › Inspiration & Anti-patterns "Rejected: easy endless snoozing"; brief §3 Snooze)
  *Fix:* Keep the 3-snooze cap, but let the person choose a per-reminder snooze length (for
  example 5/10/15/30 min, never shorter than the strength's default). Or add a Settings ›
  Accessibility option, "Longer snoozes", that doubles them. Say so in How It Nudges.
- **[medium]** The spines don't say what happens when an alarm rings out with no one touching it
  (for example, the phone is in another room), or whether the app can tell that apart from Stop. If
  it can't, a timed-out alarm could be recorded as Done. (EXPERIENCE.md › Nudge Surfaces; State
  Patterns) *Fix:* Add a state: "Alarm ended without Stop or Snooze → still nudging; next nudge per
  interval." Confirm the AlarmKit behavior on a device before declaring it.
- **[low]** Relentless sends alarms every 2 minutes with the default alarm sound, which can be
  distressing for anxious users, and sounds are system-only. (EXPERIENCE.md › Interaction
  Primitives › Sounds) *Fix:* For Firm and Relentless, add a How It Nudges note that suggests Firm
  for people who find alarms stressful, and a one-tap way to step a reminder down a strength.

### Color and contrast

- **[high]** High (warning #C93400) and Urgent (negative #D70015) are almost indistinguishable in
  light mode: ΔE2000 7.2 for typical vision, 0.5 with deuteranopia and 3.9 with protanopia, and a
  luminance ratio of 1.03. They color the nudge card's stripe and meter, which DESIGN.md calls "the
  only color on a nudge card". DESIGN.md's card anatomy doesn't place the urgency word anywhere.
  Only EXPERIENCE.md says the card "shows urgency". (DESIGN.md › Colors, Components › Nudge card)
  *Fix:* In DESIGN.md's card anatomy, require the urgency word ("High", "Urgent") in the top row
  next to "Nudge 3 of 20", with a glyph (for example `exclamationmark` for Urgent). Consider
  `arrow.up` / `alarm` glyphs on the stripe when Differentiate Without Color is on.
- **[high]** Two kinds of "Done" are told apart mainly by hue: the **Done** button (Lagoon, filled
  on cards and tinted borderless text on My Day rows) and the **Done 8:22 AM** status label (green).
  On My Day a nudging row's tinted "Done" button and a closed row's "Done 8:22 AM" are both bare
  text. Lagoon vs green has a luminance ratio of 1.26 and ΔE2000 of 6.1 with tritanopia, and the
  same word appears in both. "Words always accompany both" doesn't help when the word is the same.
  (DESIGN.md › Colors "Lagoon sits near green and gray"; Components › Reminder row, Status label)
  *Fix:* Give the My Day row's Done a visible shape (bordered capsule, `checkmark` glyph) or name
  it **Mark Done**. Lead the status label with a glyph (`checkmark.circle.fill`) so the two never
  read alike. Honor Button Shapes.
- **[medium]** Lagoon vs neutral gray collapses for protanopes (ΔE2000 5.6) and deuteranopes
  (10.8), with a luminance ratio of 1.29. Plain accent-text buttons such as **Open Settings**,
  **Show All**, **Clear** and **Add a Tag** then look the same as gray detail text, so tappability
  depends on hue alone. (DESIGN.md › Colors; Components › Buttons "plain accent text for tertiary")
  *Fix:* Require that tertiary text buttons honor the system **Button Shapes** setting
  (`accessibilityShowButtonShapes`), and that standalone tertiary actions sit in their own row or
  carry a glyph. State this in the Do's and Don'ts.
- **[medium]** Light-mode status and secondary text on `tertiary-fill` (#EBEBF0) fails 4.5:1:
  secondary-label 4.40, warning 4.45, positive 4.49 (negative is 4.53, barely). This is where the
  chosen count lives: its caption label, and a chosen count that has dropped to 0 in secondary
  label. In dark mode, quiet-dark #7D7AFF on the elevated cell #2C2C2E is 4.05, which affects
  quiet-hours text in sheets. The contrast table lists accent pairs only, and "per the mockup's
  audit" points to an audit that, per `.memlog.md`, wasn't re-run after the Lagoon change.
  (DESIGN.md › Colors › Contrast targets; Components › Counts) *Fix:* Add a full matrix to
  DESIGN.md: each text color × {grouped background, cell, tertiary fill, elevated cell} × light /
  dark / IC. Darken the light status-text values slightly (or keep chosen-count captions in
  `label`). Use #8A87FF or lighter for quiet-dark on elevated surfaces. Re-run the mockup audit with
  Lagoon.
- **[medium]** Selected-tab contrast on the Liquid Glass pill is called "passes in all four
  appearances", but that was measured on the mockup's approximation. The system pill and whatever
  content scrolls under it (a red banner, say) decide the real ratio. (DESIGN.md › Colors ›
  Contrast targets) *Fix:* Mark it [to measure on device], and make passing it a release gate
  before the Sufficient Contrast label is declared.
- **[low]** The teal Snooze tile (#008198) and the green Done tile (#008932) have a luminance ratio
  of 1.01 and ΔE2000 of 6.0 with tritanopia. They sit on opposite edges and carry glyphs and labels,
  so the risk is low. (DESIGN.md › Components › Swipe actions) *Fix:* Require both the glyph and the
  word on each tile, even when the row is short. No color change needed.
- **[low]** The chosen count's fill (`tertiary-fill` on `cell`) is 1.19:1 in light mode and 1.22:1
  in dark, so the 2 pt accent ring (5.67+) carries the state by itself. "Fill, ring and selected
  trait" overstates it. (DESIGN.md › Components › Counts) *Fix:* Add a `checkmark` or a bold label
  on the chosen count, and keep the "Showing only …" line.

### VoiceOver

- **[high]** After Done, "focus moves to the next Done button." The next VoiceOver double-tap then
  marks a *different* reminder done, which is easy to do while flicking through quickly, and it is
  a destructive, alarm-cancelling action. (EXPERIENCE.md › Interaction Primitives › Done is the
  climax) *Fix:* Move focus to the next nudge card's summary element (its title), or to the Nudging
  heading if none is left. Never land on an action button.
- **[medium]** The spines don't say what happens when a nudge starts while the app is open, or when
  a card changes or disappears in the background (Done from a notification, the next nudge, the
  give-up limit). VoiceOver focus on a removed card falls back unpredictably, and nothing says what
  gets announced. (EXPERIENCE.md › Nudge Surfaces "Over the app"; State Patterns) *Fix:* Add
  states. A new nudging card: post one queued announcement ("Pay rent is nudging"), with no focus
  move. A count tick ("Nudge 4 of 20"): no announcement. A focused card removed: focus moves to the
  next card or the section heading, and an announcement says why ("Pay rent was marked done").
- **[medium]** The nudge card's accessibility structure isn't specified. The whole card is a
  button that contains the Done and Snooze buttons, and the visual order puts the strength badge
  and "Nudge 3 of 20" before the title. A naive build reads "Relentless, Nudge 3 of 20, Pay rent…"
  or nests controls, which breaks VoiceOver and Switch Control. (EXPERIENCE.md › Component
  Patterns › Nudge card; DESIGN.md › Components › Nudge card) *Fix:* Define three elements: (1) the
  card summary, title first ("Pay rent. Urgent. Nudge 3 of 20. Due 8:00 AM. Next nudge by alarm at
  8:30. 2 snoozes left."), with the button trait and the "Opens details" hint; (2) Done; (3) Snooze.
  Also give the summary the custom actions Done and Snooze.
- **[medium]** "Each screen has one heading" would leave out section headers (Nudging, Coming Up,
  Last 24 Hours, Later today), so the headings rotor can't navigate Now or My Day. (EXPERIENCE.md ›
  Accessibility Floor › VoiceOver) *Fix:* Change it to "one top-level heading that gets focus;
  every section header carries the header trait."
- **[medium]** Tapping a notification "opens Now", but the spines don't say where focus lands. A
  VoiceOver user then has to hunt for the card that nudged them. (EXPERIENCE.md › Nudge Surfaces)
  *Fix:* Open Now scrolled to that occurrence's card, with VoiceOver focus on its summary.
- **[low]** Done triggers a HUD announcement, a list change and a focus move at once, and the
  spines don't order them, so one may cut off another. (EXPERIENCE.md › Interaction Primitives)
  *Fix:* Specify one announcement (the HUD text) posted after the layout change, with the focus
  move inside that same layout-change notification.
- **[low]** Spoken forms aren't specified. "#home" may be read as "number home", "↑ Starts higher"
  as "up arrow", "2 h 18 min" letter by letter, and the "·" separator aloud. (EXPERIENCE.md › Voice
  and Tone) *Fix:* Add accessibility labels: "tag home", "Starts higher", spelled-out durations
  (`DateComponentsFormatter` `.spellOut`), and no separators.

### Voice Control, Switch Control, Full Keyboard Access

- **[medium]** On iOS 26+ the sheet's confirm and cancel are glyph-only (`checkmark`, `xmark`), and
  so are **+** and Filter. Voice Control users say what they see ("Tap checkmark", "Tap plus"), and
  the label alone ("Add") may not match. (EXPERIENCE.md › Responsive & Platform › iOS 26 and 27;
  Accessibility Floor › Voice Control) *Fix:* Specify `accessibilityInputLabels` for each
  glyph-only button: ["Add", "Save", "Done", "Checkmark"], ["Cancel", "Close"], ["New Reminder",
  "Add", "Plus"], ["Filter"].
- **[medium]** HUD and glass bars can cover the focused control. The HUD "stays until the next
  interaction" as a capsule at the top, and in landscape a compact tab bar floats over content.
  Either can hide the focused control under Full Keyboard Access or Switch Control (WCAG 2.2
  2.4.11 Focus Not Obscured). (DESIGN.md › Components › HUD; EXPERIENCE.md › Responsive) *Fix:*
  Make the HUD inset content (safe-area inset) instead of overlaying it, and make sure scroll-to-
  focus accounts for the glass bars.
- **[low]** Notification **Done** and **Snooze** need a long press (or "View"), which contradicts
  "No action needs a long press". The fallback (tap → Now) asks for an unlock. (EXPERIENCE.md ›
  Interaction Primitives; Nudge Surfaces) *Fix:* Accept it as a system constraint, but say so, and
  make the tap-to-open path land on the card (see VoiceOver above).
- **[low]** There's no keyboard shortcut for the top nudge, and Snooze vanishing when snoozes run
  out shifts positions for Switch Control users. (EXPERIENCE.md › Interaction Primitives ›
  Keyboard) *Fix:* Add ⌘↩ Done and ⌘S Snooze for the first nudging card. When snoozes run out, keep
  a disabled "No snoozes left" in Snooze's place instead of removing it.

### Dynamic Type and layout

- **[medium]** At AX3–AX5 a stacked nudge card (badge, count, title, up to 5 detail lines, footer,
  then Done and Snooze) can be taller than the screen, especially in landscape, so Done ends up
  below the fold. (DESIGN.md › Layout › Accessibility sizes stack; EXPERIENCE.md › Accessibility
  Floor) *Fix:* At accessibility sizes, put Done and Snooze right after the title, before the detail
  lines, and fold secondary details (via, footer) into details.
- **[low]** The Live Activity and the alarm can't follow "nothing truncates". Live Activities have a
  fixed height, and a 200-character title won't fit. (DESIGN.md › Components › Live Activity)
  *Fix:* Add a rule for system and widget surfaces: title up to 2 lines then truncate, with the full
  title in the accessibility label. Test the Lock Screen at AX5.
- **[low]** "All of it is off with Reduce Motion" isn't accurate for system pushes and sheets, which
  turn into cross-fades rather than switching off. (EXPERIENCE.md › Interaction Primitives ›
  Motion) *Fix:* Say "system transitions follow Reduce Motion; the HUD and title fades become
  instant; honor Prefer Cross-Fade Transitions."

### Hearing and haptics

- **[medium]** "Every nudge vibrates too" isn't something the app can guarantee. Notification
  vibration follows the person's Sounds & Haptics settings, and system-wide Vibration can be off
  (Accessibility › Touch). For Deaf and hard-of-hearing users, visual and haptic delivery is the
  whole product. (EXPERIENCE.md › Interaction Primitives › Sounds; README › Hearing) *Fix:* Change
  it to "Nudges vibrate when the system allows it." Have Send a Test Nudge and Settings ›
  Accessibility suggest LED Flash for Alerts and Apple Watch haptics, and detect and explain when
  vibration is off where possible.

### Localization and RTL

- **[low]** Composed labels ("Done, stop nudging: Pay rent") and plural strings will be built by
  concatenation unless the spines say otherwise, which breaks word order and VoiceOver in other
  languages. In RTL the card's urgency stripe and meter must mirror, and mixed-direction titles
  need their own language. (EXPERIENCE.md › Localization) *Fix:* Require format strings with
  positional arguments for every accessibility label. Make the meter fill from the leading edge.
  Leave titles unmarked by language unless detected (`accessibilityLanguage`).

### Gaps between what's declared and what's specified

- **[medium]** The README cites WCAG 2.1, but the target is 2.2 AA, and the spines don't cover
  2.2's additions: 2.4.11 Focus Not Obscured (above) and 3.2.6 Consistent Help, since there's no
  help or "how nudges work" entry in a consistent place. (EXPERIENCE.md › Accessibility Floor;
  README › Accessibility) *Fix:* State WCAG 2.2 AA in the floor, and add a fixed "How Nudges Work"
  row in Settings, linked from each banner.
- **[medium]** Nothing in the spines verifies that the labels are earned. The floor lists them but
  sets no evidence gate, and the README itself says device testing is still to do. (EXPERIENCE.md ›
  Accessibility Floor) *Fix:* Add a release gate: an Accessibility Inspector audit plus manual
  VoiceOver, Voice Control and Switch Control runs of the "common tasks" (add a reminder, respond to
  each nudge surface, Not Done, filter My Day) at Large and AX5, in light, dark and IC, before the
  App Store listing declares the labels.

## Nutrition Label readiness

| Label | Supported by spec? | Why |
|---|---|---|
| VoiceOver | Partial | Labels, rotor actions and announcements are specified, but focus lands on the next Done, nothing covers a nudge arriving or a card being removed while the app is open, the card structure is undefined and section headings are missing |
| Voice Control | Partial | The label-in-name rule is good; glyph-only iOS 26 buttons need input labels |
| Larger Text | Yes (minor gaps) | AX5 with stacked layouts; Done can fall below the fold on tall AX cards, and widget truncation isn't covered |
| Dark Interface | Yes | Full dark and dark IC token set; elevated surfaces specified |
| Differentiate Without Color Alone | Partial | Statuses have words, but High vs Urgent is near-identical to color-blind users and has no placed word in DESIGN.md; tinted Done vs green Done; plain accent text vs gray needs Button Shapes |
| Sufficient Contrast | Partial | Lagoon passes everywhere computed; light status/secondary text on tertiary fill (4.40–4.49) and quiet-dark on elevated (4.05) fail; the glass tab pill isn't measured on a device; the audit wasn't re-run after Lagoon |
| Reduced Motion | Yes | System transitions only, plus short fades; wording needs correcting |
