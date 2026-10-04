---
name: Nudge-inator
status: final
sources:
  - ../product/brief.md
  - ../product/addendum.md
  - ../mockups/2026-10-02-ux-review-changes/index.html
  - ../mockups/2026-10-02-ux-review-changes/README.md
  - .memlog.md
design: DESIGN.md
created: 2026-10-02
updated: 2026-10-03
---

# Nudge-inator: Experience Spine

How Nudge-inator works: its screens, behavior, states, interactions, accessibility and key journeys.
[DESIGN.md](DESIGN.md) owns how it looks. The nudging rules (strengths, urgency, give-up limits,
quiet hours, carry-over, Pause, Not Done) are defined in
[brief §3–§4](../product/brief.md#3-product-concepts) and aren't restated here. This spine says how
the person meets them.

## Foundation

- **References and precedence.** The [mockup](../mockups/2026-10-02-ux-review-changes/index.html)
  is the visual and behavioral reference for every iPhone screen, and its
  [README](../mockups/2026-10-02-ux-review-changes/README.md) gives the reasons. Precedence is set once, in the [brief's introduction](../product/brief.md).
  Reasons for decisions are in the [decision log](.memlog.md).
- **Form factor: iPhone only in v1** (owner's decision, 2026-10-02, [decision log](.memlog.md)).
  - Portrait and landscape, on iOS 18, 26 and 27.
  - One column at every width: large iPhones in landscape, iOS 27 resizable windows, and the iPhone
    Duo folded or unfolded.
  - On iPad, v1 runs as an iPhone app. iPad gets its own layout in v2.
  - The brief (§5, §6, §8, §10, §11) was updated to match on 2026-10-03. Architecture should plan
    `NavigationStack` only, with no `NavigationSplitView` in v1.
- **UI system:** Apple's native components through SwiftUI:
  - navigation and lists: `TabView`, `NavigationStack`, `List` (inset grouped)
  - presentation: sheets, `alert`, `confirmationDialog`
  - input: `searchable` with tokens, `Picker`, `Toggle`, `Stepper`, `swipeActions`
  - empty states: `ContentUnavailableView`

  The system draws the chrome, so iOS 26 and 27 get Liquid Glass and iOS 18 gets its classic look,
  with no separate design. This spine specifies only how the app behaves beyond those components.
- **Visual identity:** [DESIGN.md](DESIGN.md). Tokens are referenced here as `{colors.…}`.
- **Data:** everything stays on the device. There are no network, sign-in or sync states.
- **Defaults:**
  - Quiet hours are on, from 10:00 PM to 7:00 AM, and can be turned off in Settings.
  - Times follow the iPhone's time zone; there's no time zone setting
    ([brief §3](../product/brief.md#3-product-concepts), Reminder).
  - Appearance follows the system's Light, Dark or Automatic setting. There's no in-app theme
    setting.
- **Accessibility target:** WCAG 2.2 AA and the App Store Accessibility Nutrition Labels listed in
  the [Accessibility Floor](#accessibility-floor).

## Information Architecture

There are four tabs plus Search, and each tab has its own navigation stack. Reminder details are
pushed onto the stack of the tab you came from. Sheets are one level deep, with sub-pages pushed
inside the sheet.

| Surface | Kind | Reached from | Purpose |
|---|---|---|---|
| **Now** | Tab (`bell`), default on launch | Tab bar; tapping a notification | What's nudging you, with Done and Snooze; Coming Up (7 days); Last 24 Hours. The badge shows how many reminders are nudging. |
| **My Day** | Tab (`calendar`) | Tab bar | Today in time order, with Now and quiet-hours markers. Done, Nudging, Missed and Left counts filter the list. **Filter by Tags** narrows it by tag. |
| **Tags** | Tab (`tag`) | Tab bar; a tag button in Reminder details | Browse tags; filter by one or more tag tokens, **All Tags** or **Any Tag**; **Edit** to rename or delete tags. |
| **Search** | Search-role tab (`magnifyingglass`) | Tab bar: a circle on iOS 26+, a fifth tab on iOS 18 | Every reminder, by title, notes or tag; Recent Searches. |
| **Settings** | Tab (`gearshape`) | Tab bar | Nudges (permission status, Open iOS Settings, Send a Test Nudge, How Nudges Work), Quiet Hours, Siri & Shortcuts, Your Data (Export Data, Delete All Data), About and Accessibility. |
| **Reminder details** | Pushed | Any reminder row or nudge card | Nudge card, tags, schedule, How It Nudges, History (90 days), Not Done, Pause/Resume, Delete. **Edit** in the bar. |
| **New Reminder / Edit Reminder** | Sheet | **+** on Now, My Day or Tags; **Edit** in details | The form, with pushed pages **Tags**, **Repeat** and **Custom** (frequency, interval, weekdays, and one or more times of day), and a live How It Nudges preview. |
| **Filter My Day** | Sheet | **Filter by Tags** on My Day | Tag checklist, **All Tags** or **Any Tag**, No Tags. Changes apply as they're made. |
| **Rename Tag** | Sheet | Edit mode on the Tags tab | One field, with an error for a name already in use. |
| **Welcome** | Sheet that can't be swiped away, first launch only | First launch | The four promises from the mockup's onboarding (iOS 18 has its own wording for the Urgent one), then **Continue**, the notification prompt and, on iOS 26+, the alarm prompt. |
| **Notification** | System surface | Scheduled Normal and High nudges; Urgent nudges on iOS 18 and as a fallback; follow-ups | See [Nudge Surfaces](#nudge-surfaces). |
| **Alarm** | System surface (AlarmKit), iOS 26+ | Scheduled Urgent nudges | See [Nudge Surfaces](#nudge-surfaces). |
| **Live Activity** | System surface the app designs | Snooze on an alarm | See [Nudge Surfaces](#nudge-surfaces). |
| **Assistive Access** | Separate scene | Assistive Access turned on | See [Assistive Access](#assistive-access). |
| **Siri & Shortcuts** | System | Siri, the Action button, a Home Screen shortcut | See [Siri & Shortcuts](#siri--shortcuts). |

**Rules:**
- **Navigation.**
  - A reminder row shows a chevron and pushes details.
  - A nudge card has no chevron: tapping its summary opens details.
  - Tapping the current tab pops back to its root.
- **New reminders inherit context.** A new reminder started from the Tags tab begins with the tags
  the tab is filtering by.
- **Tags are created where they're needed,** on the form's **Tags** page. The Tags tab has no Add
  Tag button.
- **Filters persist within a tab.** The Tags tab's tokens and My Day's filter survive opening a
  reminder and coming back. The two filters are separate. They're also restored when iOS has ended
  the app in the background, and reset when the person closes the app from the app switcher
  (decided 2026-10-03, [architecture](../architecture/ARCHITECTURE-SPINE.md)).

## Voice and Tone

These rules cover microcopy. The brand's posture is in
[DESIGN.md › Brand & Style](DESIGN.md#brand--style). The voice is **calm and plain**: the name and
the icon carry the fun, and the words never do. The person reading is often busy, stressed,
distractible or older, so every line has to be understood at a glance.

| Do | Don't |
|---|---|
| Second person, short declaratives: "Nothing is nudging you." | Cheerleading: "You've got this!", "Great job!" |
| Lead with the consequence in everyday words, then the mechanism: "Alarms are off. Urgent nudges come as a chain of Time Sensitive notifications instead, which silent mode can mute." | Bare states: "Permission denied", "Error" |
| Name the consequence before a destructive action: "This deletes its history too, and cancels any nudges and alarms." | "Are you sure?" |
| Status words that stand alone: **Nudging**, **Done**, **Missed**, **Skipped**, **Paused**, **Coming up** for occurrences; **Active**, **Paused**, **Completed** for a reminder (Reminder details, and the Tags and Search sections) | An icon or color as the only status signal |
| The product's own words, used the same way everywhere: *nudge*, *nudging*, *strength*, *give-up limit*, *quiet hours*, *starts higher* | Synonyms: "nag", "ping", "alert level", "level", "dismiss" |
| Title Case for buttons and headers on iOS 26+ (iOS 18 draws section headers in capitals) | Exclamation marks, emoji, jokes, ALL CAPS for emphasis |
| Numerals, through the system formatters: "in 3 min", "2 h 18 min" | Hand-built plurals: "1 reminder(s)" |
| Plain language outside the form, at about a grade 6–8 reading level. Each concept gets a one-line explanation in the form's footers and in Settings › How Nudges Work. | Unexplained jargon on Now or in banners |

Fixed phrases (verbatim copy):

| Where | Phrase |
|---|---|
| Card footer, no snoozes left | "No snoozes left. Only Done stops it." |
| Carry-over | "Starts higher: the last one was missed." |
| Closing notes | "Missed: gave up after the limit", "Missed: the next one took over", "Skipped: the reminder was changed", "Skipped: the reminder was paused" |
| Done by an alarm's Stop | "Done (alarm stopped)" |
| Follow-up after Stop | "Marked done: Blood-pressure pill. Not done yet?" |
| Privacy hint | "Notes and tags stay in the app. Notifications and alarms show the title, not these." |
| Onboarding, and How It Nudges for any reminder with alarms | "Stopping the alarm counts as Done." [To confirm on a device: Stop before the first unlock is recorded.] |
| History events | "Due", "Held for quiet hours until 7:00 AM", "Nudge 2 · Normal · notification", "Nudge 5 · Urgent · alarm", "Nudge 4 · Urgent · notification chain", "Snoozed 15 min (2 snoozes left)", "Notification cleared (still nudging)", "Marked not done (nudging again)", "Paused", "Resumed", "Nudge 3 · Normal · couldn't be sent (notifications off)", "Nudge 9 · High · couldn't be sent (the app wasn't opened)". The engine's internal step index ("level") never appears. |
| History events, Done by source (AD-3 `source`) | `app`: "Done"; `notification`: "Done from the notification"; `alarm`: "Done (alarm stopped)"; `liveActivity`: "Done from the Lock Screen"; `siri`: "Done with Siri"; `assistiveAccess`: "Done in Assistive Access" |
| Welcome, Urgent (iOS 26+) | "Urgent nudges ring as alarms" / "When it really matters, your iPhone rings and vibrates like an alarm, even on silent. Stopping the alarm counts as Done." |
| Welcome, Urgent (iOS 18) | "Urgent nudges keep coming" / "When it really matters, a nudge comes every minute, up to 10 times, then keeps nudging until you tap Done or it reaches its give-up limit." |
| Repeat summary, a day some months don't have | "Every month on the 31st (the last day in months without one) at 9:00 AM", "Every year on 29 February (28 February in years without one) at 9:00 AM" |
| Welcome, privacy | "Stays on your iPhone" / "No account and no server. Your reminders stay on this iPhone and in your own backups." |

Every string quoted in double quotes anywhere in this spine is verbatim copy for the string catalog.

All strings live in string catalogs, with plural variants and a format string per plural form. See
[Localization](#localization).

## Component Patterns

This section covers behavior. The components have the same names and order as
[DESIGN.md › Components](DESIGN.md#components), which owns the visual specs. Alarm, Live Activity
and Assistive Access behavior lives in [Nudge Surfaces](#nudge-surfaces) and
[Assistive Access](#assistive-access).

### Nudge card

- **Use:** Now (Nudging section); Reminder details (Nudging Now).
- **Content:**
  - Strength, the **urgency word** ("High" or "Urgent", none for Normal) and "Nudge 3 of 20".
  - Title, tags and due time.
  - The next nudge, with its [Via label](#via-label).
  - The [Nudge meter](#nudge-meter), the snoozes left, and "Starts higher" with carry-over.
- **Actions:** **Done** closes the occurrence. **Snooze N min** shows only while snoozes are left.
  Tapping the summary opens details. [Swipe actions](#swipe-actions) are shortcuts.
- **Layout:** at a card width of 540 pt or more, the buttons sit beside the text. At accessibility
  sizes, Done and Snooze come right after the title, before the detail lines, so they stay above
  the fold.
- **Accessibility:** the card is three elements.
  - A summary, title first ("Pay rent. High. Nudge 3 of 20. Due 7:30 AM. Next nudge by alarm at
    8:30 AM. 2 snoozes left."), with the button trait, the hint "Opens details", and the custom
    actions Done and Snooze.
  - **Done**.
  - **Snooze**.

### Nudge meter

- **Use:** Nudge card.
- **Content:** how many nudges have been sent out of the nudge limit. A time limit isn't shown on
  the meter.
- **Layout:** it fills from the leading edge and mirrors in right-to-left layouts.
- **Accessibility:** it's part of the card summary, not a separate element.

### Reminder row

- **Use:** Now (Coming Up, Last 24 Hours), My Day, Tags results, Search results.
- **Content:** chosen filter tags are bold. Tag lines wrap and never truncate, even with 10 or more
  tags. A notes-only search match shows the words around the match.
- **Actions:**
  - The whole row is the target; it pushes details (chevron).
  - On My Day, a nudging row has its own bordered **Done** beside the chevron.
  - On My Day, a row closed by an alarm's Stop reads "Done (alarm stopped)" with a **Not Done**
    button, available while Not Done applies ([brief §3](../product/brief.md#3-product-concepts)). Rows in Now › Last 24 Hours show the
    same alarm-stopped treatment.
  - Rows show **Not Done** only when the occurrence was closed by an alarm's Stop. Any other done
    occurrence can be reopened from Reminder details, Undo right after Done, or Assistive Access's
    "Done today" list.

### History

- **Use:** Reminder details.
- **Content:** occurrences from the last 90 days, newest first. Each is a disclosure: when it was
  due, its closing status, and how many nudges it took. Inside, a time-ordered event list uses the
  History events phrases in [Voice and Tone](#voice-and-tone). Footer: "History is kept for 90
  days."
- **Layout:** at accessibility sizes, events wrap under their time.

### Via label

- **Use:** Nudge card, How It Nudges.
- **Content:** how the next nudge arrives: Notification, Alarm, or Notification chain. A weaker
  fallback is said in words:
  - "Notification chain: alarms are off"
  - "Notification chain: alarms and Time Sensitive are off"
  - "Notification chain: Time Sensitive is off" (iOS 18)
  - "Notification: alarms are off"
  - "Notification: alarms and Time Sensitive are off"
  - "Notification: Time Sensitive is off"
  - "Notification: too many alarms scheduled" [ASSUMPTION: wording], when AlarmKit's limit is
    reached
  - "Notifications off" (`bell.slash`)

### Strength badge

- **Use:** cards, rows, details.
- **Content:** read-only. The name and a 1-, 2- or 3-bar glyph.
- **Rules:** never colored.

### Status label

- **Use:** rows, history.
- **Content:** one status word from the fixed set in [Voice and Tone](#voice-and-tone), led by a
  glyph (Done: `checkmark.circle.fill`), so it never reads like a Done button.

### Counts

- **Use:** My Day.
- **Actions:** four toggle buttons: Done, Nudging, Missed, Left. Only one can be chosen at a time,
  and tapping it again clears it.
- **Rules:**
  - **What each counts:** Done, Nudging (including a snoozed occurrence) and Missed count today's
    occurrences with that status. Left counts what's still coming up today, including one that's
    due but whose first nudge is held for quiet hours (its row reads "Coming up" with "Quiet hours:
    first nudge at 7:00 AM"). Skipped and Paused items stay in the list but aren't counted, so the
    counts can add up to less than the items shown.
  - **Zero:** a count of 0 can't be chosen, unless it's already chosen and drops to 0 (for example,
    after Done).
  - **Filtering:** the counts follow the tag filter. "Showing only Missed" and **Show All** appear
    while one is chosen.
- **Accessibility:** the chosen count has the selected trait.

### Tag token field

- **Use:** Tags tab.
- **Layout:** `searchable` with tokens, always visible under the title.
- **Actions:** typing suggests tags; tap one, or press Return to take the first match. **Add a
  Tag** lists the unchosen tags below the results.
- **Rules:**
  - The tokens persist within the tab.
  - **System behavior** [To confirm on a device: tap a token to select it, then Delete removes it.
    In an empty field, Delete selects the last token, and a second Delete removes it. Clear
    (`xmark.circle.fill`) removes the text and every token. **Cancel** clears the text, ends
    editing and keeps the tokens.]

### Match control

- **Use:** Tags tab, Filter My Day.
- **Content:** appears once 2 or more tags are chosen: **All Tags** (default) or **Any Tag**.
- **Layout:** segmented; a menu at accessibility sizes.

### Filter token

- **Use:** My Day.
- **Content:** the chosen tags, as removable capsules, with **Clear** when there are 2 or more.
  **Filter by Tags** reads **Filter (2)** while a filter is on.

### Strength picker

- **Use:** Form.
- **Content:** Gentle, Firm or Relentless.
- **Layout:** segmented; a menu at accessibility sizes.
- **Rules:** choosing a gentler strength raises the give-up limit to the new strength's minimum, if
  it's below it, and says so in the footer.

### Snooze length

- **Use:** Form.
- **Content:** a menu with the strength's default (Gentle 30, Firm 15, Relentless 5 min) and any of
  5, 10, 15 and 30 min that are longer. It starts at the strength's default.
- **Rules:**
  - A change applies from the next snooze. The cap stays at 3 snoozes per occurrence. How It
    Nudges shows the length.
  - Choosing a gentler strength raises a snooze length that's shorter than the new strength's
    default to that default, and the footer says so.

### Give-up limit

- **Use:** Form.
- **Content:** a stepper for nudges and a menu for time, neither going below the strength's minimum
  ([brief §3](../product/brief.md#3-product-concepts)). The footer gives the minimum and the reason
  for it.

### How It Nudges

- **Use:** Form (live), Reminder details.
- **Content:**
  - **Rows:** one per run of nudges, giving when, the urgency and how it arrives (Via label). For a
    repeat, a **Next one due** row says the next occurrence takes over.
  - **Summary line:** total nudges, how many are alarms, the snooze length, and the Focus note for
    Gentle and Firm. For any reminder with alarms it adds "Stopping the alarm counts as Done."
- **Rules:** it's generated from the same rules as the scheduler.

### Title field

- **Use:** Form.
- **Content:** wraps onto more lines. Return doesn't add a line, and pasted newlines become spaces.
  Up to 200 characters.
- **Actions:** **Add** is disabled until there's a title ("Add a title to save.").

### Buttons

Visual only; see [DESIGN.md › Components › Buttons](DESIGN.md#buttons). Every action is a button of
at least 44 pt.

### Sheet bar buttons

- **Use:** every sheet.
- **Actions:**
  - **Cancel:** always enabled. With unsaved changes, it asks to discard them.
  - **Confirm (Add, Save, Done):** disabled until the sheet is valid.
  - **Keyboard:** Return confirms when focus isn't in a field that has its own Return action. Escape
    cancels.
  - **Exception, Filter My Day:** the filter applies as you change it, so there's nothing to
    discard. The sheet has **Clear** (disabled while no filter is on) and **Done**, and no
    **Cancel**. Escape closes it, like **Done**.

### Permission banner

- **Use:** Now, Settings.
- **Content:** one per missing permission (notifications, alarms or Time Sensitive). It says what
  that means. When alarms and Time Sensitive are both off, both banners show. When notifications
  are off, only that banner shows, because it already says what can still reach you.
- **Actions:** **Open Settings** and **Got It**. **Got It** collapses the banner on Now to a
  one-line row at the bottom of the screen. When two banners are showing, each has its own **Got
  It** and collapses to its own row, and the rows stack. Got It is remembered for each permission
  until that permission changes; any change clears it, so a banner that comes back shows in full. A
  collapsed row shows only while its banner would. Settings keeps the full banner until the
  permission changes.
- **Layout:** a banner never sits above the first nudge card's Done.

### Quiet-hours chip

- **Use:** Now.
- **Content:** "Quiet 10:00 PM to 7:00 AM", with "· on now" during quiet hours.
- **Accessibility:** a button with the hint "Opens Quiet Hours settings". [ASSUMPTION: the mockup's
  chip is static.]

### Status message

- **Use:** after Done, Snooze, Pause, Resume, Not Done, Save.
- **Content:** a short sentence ("Snoozed until 8:35 AM. 2 snoozes left.").
- **Actions:** after Done it has an **Undo** button, which runs Not Done.
- **Layout:** it pushes the content down rather than covering it.
- **Accessibility:** VoiceOver announces it.
- **Rules:** it stays until the next tap or key press, never on a timer.

### Markers

- **Use:** My Day.
- **Content:** "Now" sits at the current time and moves as time passes; quiet hours are shown as a
  range.
- **Rules:** My Day opens scrolled to "Now". The markers stay while a filter is on, so the list
  still reads as a timeline.

### Settings row

- **Use:** Settings.
- **Content:** icon tile, label, and a trailing status or a chevron. Notifications reads "On",
  "Off" or "On · Time Sensitive off"; Alarms (iOS 26+) reads "On" or "Off".
- **Rules:** **Send a Test Nudge** is disabled while notifications are off, with a footer explaining
  why.

### Tag tile

Visual only; decorative, hidden from VoiceOver.

### Confirmation

- **Use:** Delete Reminder, Discard Changes.
- **Layout:**
  - **iOS 26+:** a `confirmationDialog` attached to its button, with no Cancel; tapping outside
    cancels.
  - **iOS 18:** an action sheet with Cancel.

### Alert

- **Use:** Delete tag, Delete All Data, permission prompts.
- **Content:** a centered alert. The destructive button is labeled with its verb.

### Swipe actions

- **Use:** nudging rows and cards (Now, My Day).
- **Actions:**
  - **Placement:** Snooze on the leading edge (only while snoozes are left), Done on the trailing
    edge.
  - **No full swipe:** a swipe reveals the tile, and a tap performs it.
- **Accessibility:** they appear in VoiceOver's Actions rotor.
- **Rules:** they're shortcuts only, never the only way to act.

## State Patterns

### Now

| State | Treatment |
|---|---|
| Nothing nudging | Subtitle "Nothing is nudging you". The Nudging section is replaced by "All clear. Nothing needs you right now." |
| Nothing this week, or nothing closed | "Nothing scheduled this week." / "Nothing closed yet today." under their headers |
| Quiet hours on | The chip reads "· on now". Coming Up rows due in quiet hours say "Quiet hours: first nudge at 7:00 AM". |
| Quiet hours turned off | No chip |
| A nudge starts while the app is open | The card appears, and VoiceOver makes one queued announcement ("Pay rent is nudging"). Focus doesn't move. A nudge count going up isn't announced. |
| A card closes while the app is open (Done from a notification, the give-up limit, the next occurrence taking over) | The card leaves. If it had VoiceOver focus, focus follows the rule in [Interaction Primitives › Done is the climax](#interaction-primitives), with an announcement of why ("Pay rent was marked done"). |
| Opened from a notification | Scrolled to that occurrence's card, with VoiceOver focus on its summary |
| Notifications off, alarms on, iOS 26+ (also Settings) | Red banner: "Notifications are off. Only Urgent nudges can reach you, as alarms. Gentle reminders can't reach you at all." Cards mark the nudges that can't arrive. |
| Notifications off, with alarms off or on iOS 18 (also Settings) | Red banner: "Notifications are off. Nudges can't reach you." Cards mark the nudges that can't arrive. |
| Alarms off, iOS 26+ (also Settings) | Orange banner: "Alarms are off. Urgent nudges come as a chain of Time Sensitive notifications instead, which silent mode can mute." |
| Alarms off and Time Sensitive off, iOS 26+ (also Settings) | Orange banner: "Alarms are off. Urgent nudges come as a chain of ordinary notifications instead, which silent mode can mute and a Focus can hold." The Time Sensitive banner shows too. |
| Time Sensitive off, iOS 26+ (also Settings) | Orange banner: "Time Sensitive is off. High nudges come as ordinary notifications, so a Focus can hold them." |
| Time Sensitive off, iOS 18 (also Settings) | Orange banner: "Time Sensitive is off. High and Urgent nudges come as ordinary notifications, so a Focus can hold them." |
| Alarm limit reached (also Reminder details) | The Via label of the affected nudges reads "Notification: too many alarms scheduled". |
| Snoozed (also Reminder details) | The card says "Snoozed until 8:35 AM, then …", and the snoozes left update. |
| No snoozes left, or the one extra nudge after Not Done at the limit (also Reminder details) | Snooze is removed from the card, notification and alarm. Footer: "No snoozes left. Only Done stops it." |
| Carry-over (also Reminder details) | "↑ Starts higher" on the card and the Coming Up row |
| Closed by an alarm's Stop (also My Day) | The row reads "Done (alarm stopped)" with **Not Done** while Not Done applies ([brief §3](../product/brief.md#3-product-concepts)). |

### My Day

| State | Treatment |
|---|---|
| Nothing due today | `ContentUnavailableView`: "Nothing is due today" |
| Chosen count is empty | The count stays chosen, and the list says, for example, "Nothing is nudging you". |
| **No Tags** chosen in the filter | Shows only reminders without tags; the counts follow. |

### Tags

| State | Treatment |
|---|---|
| No tags yet | "No Tags", explaining that tags are added on a reminder |
| No match (All Tags) | "No reminder has all of these tags. Try Any Tag, or remove one." |
| Edit mode | Rows show **Rename** and Delete. Tapping a row doesn't filter. |
| Deleting a tag | Alert: "Delete #home?" / "It's removed from 3 reminders. They aren't deleted." With no reminders: "No reminders have this tag." The tag is also removed from the Tags filter and the My Day filter; a filter left with no tags turns off. |

### Search

| State | Treatment |
|---|---|
| Before typing | "Search Your Reminders", saying what can be searched. Recent Searches (up to 5, with **Clear**) appear once a result has been opened. |
| No results | "No Results for "…"", with "Check the spelling or try a new search." |

### Reminder details

| State | Treatment |
|---|---|
| No history | "No occurrences yet. The first one is created when it falls due." |
| Latest occurrence done | **Not Done** shows while Not Done applies ([brief §3](../product/brief.md#3-product-concepts)). |
| Paused | **Resume**, with the note "Pausing stops the nudging and clears any carry-over. Anything due while it's paused is skipped, not missed." |
| Delete | Confirmation: "Delete "Pay rent"?" / "This deletes its history too, and cancels any nudges and alarms." |
| Deleted while open (a notification action got there first) | "This reminder was deleted.", with Back |

### Form

| State | Treatment |
|---|---|
| Editing while nudging | The footer says when each change applies. It warns when saving would close the occurrence as skipped. |
| Notes at 2,000 characters | No more input is accepted. A footer counter appears from 1,800 characters ("1,950 of 2,000"). |
| New tag name already used, ignoring case (Tags page) | The form checks the existing tag instead of creating a new one, and the footer says "Using #home". |
| Typing a tag name (Tags page, Rename Tag) | The name follows [brief §3](../product/brief.md#3-product-concepts), Tag name: as you type, "dog walks" becomes #dog-walks. |
| Unsaved changes, then Cancel | Confirmation: **Discard Changes** / **Keep Editing** |
| Resuming a one-off whose time passed | Asks for a new time ("Choose a New Time"). |
| Repeat Never with a start time that has passed | Inline error under Starts: "This time has passed. Choose a later time." **Add**/**Save** is disabled. An edit to a reminder that was already a one-off, keeping its time, can still be saved; resuming one, or changing a repeat to Never, can't. |

### Settings

| State | Treatment |
|---|---|
| Quiet hours start equals end | Inline error: "Quiet hours can't start and end at the same time." Not saved. |
| Export Data | Writes a readable JSON record and opens the share sheet. The footer says it isn't a backup and can't be imported. |
| Delete All Data | Alert: "Delete All Data?" / "This deletes every reminder, tag and all history from this iPhone, and cancels every nudge and alarm. It can't be undone." On iOS 18: "…and cancels every nudge. It can't be undone." It deletes reminders, tags, history and Recent Searches, and clears the tag filters. Settings (quiet hours) and iOS permissions are kept. |

### Rename Tag

| State | Treatment |
|---|---|
| Name already in use | Inline error: "You already have a tag with this name." **Save** is disabled. |
| Typing | The same name rules as a new tag ([brief §3](../product/brief.md#3-product-concepts), Tag name). |

### Any

| State | Treatment |
|---|---|
| First launch | Welcome, then the permission prompts. Denying either lands on Now with its banner. |
| Launch after updating from iOS 18 to iOS 26 or later (alarm permission never asked) | The system's alarm prompt, once, before Now. No Welcome. Denying it lands on Now with the alarms-off banner. |
| Loading | None. Data is local and loads with the view, so there are no spinners or skeletons. |
| The reminders can't be opened (a failed update or damaged data; architecture AD-16) | One message in place of the tabs: "Nudge-inator can't open your reminders, so it has stopped nudging. Check for an update, then open the app again." |

## Nudge Surfaces

The nudges are the product, and most of them appear outside the app, on surfaces the system draws.
How and when each one arrives is in [brief §4](../product/brief.md#4-how-nudges-reach-you). This
section covers what the person sees and can do on each.

| Surface | Content | Actions | Notes |
|---|---|---|---|
| **Notification** (Normal: ordinary; High: Time Sensitive) | App icon, title (bold), "Nudge 3 of 20 · High". The header says "Time Sensitive" for High and Urgent only. | **Done**, **Snooze 15 min** (while snoozes are left), on a long press; the system's **Clear** | Tapping it opens Now at the card. Clear is recorded in the history ("Notification cleared (still nudging)"); a banner flicked away isn't. With previews hidden, iOS shows only the app's name. |
| **Notification chain** (Urgent on iOS 18, and Urgent with alarms off) | As above, but Time Sensitive (see [brief §4](../product/brief.md#4-how-nudges-reach-you) for Time Sensitive off), sent each time the occurrence enters Urgent: at once and then every minute, 10 in all. Each shows the current nudge number. | **Done**, **Snooze** | The card marks it "Notification chain". Silent mode can mute it. The rules are in [brief §4](../product/brief.md#4-how-nudges-reach-you). |
| **Alarm** (Urgent on iOS 26+) | The app's name and the title, tinted `{colors.accent-dark}` | **Snooze N min** (`clock`, filled with the tint) while snoozes are left; the system's **Stop** | Stop counts as Done, as onboarding and How It Nudges say. After each snooze the app's own alarm rings at the snooze's end, without Snooze once none are left (architecture spine, AD-12). The alarm also shows in StandBy and on a paired Apple Watch. |
| **Done follow-up** (after Stop on an alarm, or on the Watch) | An ordinary notification: "Marked done: Blood-pressure pill. Not done yet?" | **Not Done**; tapping it opens the reminder | Sent at once. **Not Done** works while Not Done applies ([brief §3](../product/brief.md#3-product-concepts)); the app removes the notification the next time it runs after that, or at once when Not Done is used. |
| **Live Activity** (after Snooze on an alarm) | Title (up to 2 lines), countdown, "Snoozed. Rings again at 8:35 AM." | **Done** | Designed by the app, in a widget extension. Before the first unlock, iOS shows its own countdown instead. |
| **Keep-nudging notice** (the reserved slot) | An ordinary notification: "Open Nudge-inator to keep nudging." [ASSUMPTION: wording; brief §4 gives only the phrase] | Tapping it opens the app, which tops up the schedule | Sent when brief §4 says (the first nudge that couldn't be scheduled), unless the app has run again first. |
| **Over the app** (the iPhone is in use) | Notifications as banners. The alarm in the Dynamic Island, or as a banner at the top in landscape [To confirm on a device: the alarm as a banner in landscape]. | Same as on each surface | |

- **Privacy:** notes and tags never appear outside the app.
- **Closing clears:** however an occurrence closes, nothing more arrives for it, and its pending and
  delivered notifications, alarms and Live Activity are removed as soon as the app runs. No app code
  runs when a nudge arrives, so after a close at the give-up limit or a takeover, delivered
  notifications stay until the app next runs, and their actions do nothing. The Done follow-up is
  the only exception.

### States

| State | Treatment |
|---|---|
| Alarm rang out with no Stop or Snooze | Still nudging; the next nudge follows the interval. [To confirm on a device: AlarmKit doesn't report this as a stop.] |
| An action on an occurrence that has already closed (notification, alarm, Live Activity) | Does nothing. The app clears it on its next run. |

## Interaction Primitives

- **Tap to act.** Every action is a visible button. No action in the app needs a gesture, a long
  press or a timer. Notification actions need a long press, which the system requires. Tapping the
  notification opens the card.
- **Swipe actions** appear on nudging rows and cards only, as shortcuts that reveal and then need a
  tap (see [Swipe actions](#swipe-actions)).
- **Done is the climax.** On Done from anywhere in the app:
  1. A `.success` haptic plays.
  2. The card leaves the Nudging section with the system's list transition, and the row becomes
     "Done 8:22 AM".
  3. The status message says "Done: Pay rent. Nudging stopped." (or, for a reminder with alarms,
     "Done: Pay rent. Its alarms are cancelled."), with **Undo**.
  4. VoiceOver focus moves to the title of the item now at the same position in that list (a
     nudge card's summary, a My Day row, or an Assistive Access card), or to the one before it if it
     was last, or to that section's header if none is left. Only reminder items count; My Day's Now and quiet-hours markers aren't items. It never lands on a Done button. This is
     the one focus rule for an item that leaves or changes after Done.

  VoiceOver makes one announcement, the status message, posted with the layout change. There's no
  custom animation.
- **Haptics:**
  - `.success` on Done.
  - `.selection` when choosing a count, token or strength. [ASSUMPTION: the owner specified only
    Done.]
- **Sounds:** system sounds only. Notifications use the default sound, and alarms use AlarmKit's
  default alarm sound. Nudges also vibrate when the person's system settings allow it.
- **Motion:** only the system's transitions (push, sheet, list insert and remove, tab-bar
  minimize), plus 0.2 s fades for the status message and the inline title. System transitions
  follow Reduce Motion and Prefer Cross-Fade Transitions. The app's own fades become instant.
- **Keyboard** (this is the one list; brief §5 names the shortcuts):

  | Key | Action |
  |---|---|
  | ⌘N | New Reminder |
  | ⌘F | Search |
  | ⌘1–⌘4 | Now, My Day, Tags, Settings |
  | Return | Confirm a sheet (see [Sheet bar buttons](#sheet-bar-buttons)) |
  | Escape | Cancel a sheet, alert or dialog |

  Tab reaches every control.
- **Banned:**
  - full-swipe actions
  - badges, other than the Now tab's nudging count
  - carousels and auto-dismissing messages
  - pull-to-refresh (there's nothing to refresh)

  Rationale for the rest: [Inspiration & Anti-patterns](#inspiration--anti-patterns).

## Accessibility Floor

This section covers behavior. Contrast and color rules are in
[DESIGN.md › Colors](DESIGN.md#colors).

- **Dynamic Type,** from xSmall to AX5. At AX1–AX5:
  - rows and form rows stack
  - segmented controls become menus
  - My Day's counts go to 2 columns, or 1 when the screen is narrow
  - history events wrap under their time
  - nudge cards stack, with their buttons right after the title

  Nothing truncates with "…" inside the app. Bars and tab labels stay fixed and use the Large
  Content Viewer. On system surfaces (Live Activity, alarm) titles take up to 2 lines, and the full
  title is in the accessibility label.
- **VoiceOver:**
  - Every control is named. Repeated buttons include the reminder: "Done, stop nudging: Pay rent",
    "Snooze 15 minutes: Pay rent".
  - Each screen has one top-level heading, which gets focus on navigation. Every section header
    (Nudging, Coming Up, Last 24 Hours, Later today) has the header trait.
  - Focus returns to the opening control when a sheet or alert closes. Focus after Done follows
    [Interaction Primitives › Done is the climax](#interaction-primitives). Focus when a card
    closes and on opening from a notification follows [State Patterns › Now](#now).
  - Counts form a group ("Today's counts. Choose one to show only those."), and the chosen count
    has the selected trait. The Now badge reads "2 nudging".
  - Filter, search and action results are announced ("7 reminders with #home or #morning").
  - **Spoken forms:**
    - "#home" reads as "tag home", and "↑ Starts higher" as "Starts higher".
    - Durations are spelled out.
    - Separators such as "·" aren't spoken.
    - Composed labels use format strings with positional arguments.
- **Voice Control:**
  - Every control's name contains its visible label ("Remove #home from the filter", "Rename
    #home").
  - Glyph-only buttons get input labels:

    | Button | Input labels |
    |---|---|
    | Confirm | "Add", "Save", "Done", "Checkmark" |
    | Cancel | "Cancel", "Close" |
    | **+** | "New Reminder", "Add", "Plus" |
    | Filter | "Filter" |
- **Full Keyboard Access and Switch Control** reach every control, and nothing the app draws covers
  the focused control. The status message pushes content down, and scrolling to the focused control
  keeps it clear of the glass bars.
- **Targets:** at least 44 pt. The system's own small controls (switch, stepper, segments, tokens,
  the search clear button) sit in 44 pt rows. Shaped controls are 12 pt apart.
- **Not color alone:**
  - Every status has a word.
  - Urgency has a word and a glyph.
  - Strength has a name and bars.
  - The chosen count has a ring, a selected trait and the "Showing only…" line.
  - Tertiary text buttons honor **Button Shapes**.
- **Time:** nothing in the app is on a timer. Nudges are the product's timed interruptions. For
  people who need more time, snooze length is adjustable per reminder, and Done can be undone (Undo,
  Not Done).
- **Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion, Dark Mode:** all honored. The
  visual treatment is in DESIGN.md.
- **Hearing:** every nudge is visual. Settings › Accessibility suggests LED Flash for Alerts and a
  paired Apple Watch for people who rely on vibration and light.
- **Consistent help:** Settings › How Nudges Work explains strengths, urgency, Focus, quiet hours
  and alarms. Every permission banner links to it.
- **Assistive Access:** see [Assistive Access](#assistive-access).
- **App Store Accessibility Nutrition Labels:** VoiceOver, Voice Control, Larger Text, Dark
  Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion.
- **Release gate for the labels:** before the App Store listing declares them, run the following on
  a device:
  - an Accessibility Inspector audit
  - VoiceOver, Voice Control and Switch Control on the common tasks: add a reminder, respond to
    each nudge surface, Not Done, filter My Day
  - each at Large and AX5, in light, dark and Increase Contrast
  - the selected tab's contrast on the system's glass pill, measured

## Assistive Access

- **One screen, with no tab bar.**
  - **Heading:** "Nudge-inator".
  - **"Needs you now"** (or "Nothing needs you now"): a large card for each nudging reminder, with
    the title, the due time and large **Done** and **Snooze** buttons.
  - **"Done today":** each reminder done today, with a large **Not done yet** button while Not Done applies ([brief §3](../product/brief.md#3-product-concepts)).
  - **"Later today":** up to 4 rows, or "Nothing else today".
- **Left out:** editing, tags, search, settings and history. Reminders are set up in the full app,
  by the person or a caregiver. Settings › Accessibility tells caregivers what Assistive Access
  shows.
- **By iOS version:** on iOS 26+ it's an `AssistiveAccess` scene, in the system's style. On iOS 18
  the same view is shown full screen when `isAssistiveAccessEnabled` is on.
- [To confirm on a device: how alarms, Time Sensitive notifications and the Live Activity behave
  while Assistive Access is on.]

## Siri & Shortcuts

**Order.** When several reminders are nudging, "the first" one is decided by:
1. the highest urgency
2. then the earliest due time
3. then the most nudges sent

| Phrase | Something nudging | Nothing nudging |
|---|---|---|
| "Mark my Nudge-inator nudge done" | With one nudging, marks it done and says its title. With several, Siri lists them in that order and asks which. | "Nothing is nudging you." |
| "Snooze Nudge-inator" | Snoozes the first one by its snooze length, if snoozes are left. Otherwise says "No snoozes left. Only Done stops it." | "Nothing is nudging you." |
| "What's nudging me in Nudge-inator?" | Reads the titles and nudge counts, in that order. | "Nothing is nudging you." |

The phrases work from Siri, the Action button and Home Screen shortcuts. Settings › Siri &
Shortcuts lists them.

## Localization

English only at launch, built for translation. The full checklist is in
[addendum §D](../product/addendum.md#d-localization-checklist). The experience rules are:
- **Direction:** layouts use leading and trailing, and mirror for right-to-left; so do directional
  symbols and the nudge meter.
- **Length:** layouts allow text 30–40% longer than English, and the stacked accessibility layouts
  cover most of it.
- **Formats:** dates, times, durations and relative times use the system formatters and follow the
  12- or 24-hour setting.
- **Strings:** every accessibility label and plural uses a format string with positional
  arguments.
- **The person's own text** (titles, notes, tag names) is never translated, and the `#` stays.

## Responsive & Platform

Layout depends on the available **width**, never on the iPhone model. The full iOS version matrix
is in [addendum §B](../product/addendum.md#b-ios-version-matrix).

| Context | Behavior |
|---|---|
| **Portrait, any iPhone** | Large titles; a full tab bar that doesn't shrink. |
| **Landscape (compact height)** | **Chrome:** no status bar; inline titles.<br>**Content:** the readable width (about 672 pt) inside the safe areas, with backgrounds running to the edges.<br>**Tab bar:** a compact capsule, each symbol beside its title. On iOS 26+ it shrinks to the current tab while you scroll down, except on Search.<br>**My Day (iOS 26+):** the date becomes the nav subtitle, Filter becomes a bar button, and the counts become a row of capsules.<br>**Sheets** fill the screen, and **nudges** arrive as banners over the app. |
| **Nudge card 540 pt or wider** | Done and Snooze sit beside the text, except at accessibility sizes. |
| **iOS 27 resizable window** (320–1,024 pt) | One column, at the readable width. Sheets become a centered card at 700 pt or wider. |
| **iPhone Duo (iOS 27)** | Treated like any iPhone: one column, folded and unfolded. Navigation, scroll position, open sheets and form input survive folding and unfolding. [To confirm on a device: folding and unfolding, at both sizes.] |
| **iOS 18** | Search is a fifth tab, with its field under the title. Sheet buttons are words. Deletes are confirmed in a bottom action sheet. The tab bar doesn't shrink. Urgent nudges use the notification chain, and there's no alarm permission. |
| **iOS 26 and 27** | Liquid Glass bars and a Search circle. Sheet buttons are `xmark` and `checkmark`, with their words as labels. Dialogs grow from their button. Urgent nudges are AlarmKit alarms, or the notification chain if alarms aren't allowed. |
| **iPad (v2, deferred)** | v1 runs on iPad as an iPhone app. v2 adds the layout in [addendum §C](../product/addendum.md#c-layout-notes-for-landscape-and-ipad). |

## Inspiration & Anti-patterns

- **Lifted from Mail and Reminders:** **All Tags** is the default, so adding a tag narrows the list.
- **Lifted from Apple Music's library search:** a search scoped to one tab sits under its title,
  alongside a global Search tab, with visible filter options beside the tokens.
- **Lifted from the Clock app's alarms:** the strongest nudge is a real alarm, and its system
  controls are trusted as they are.
- **Rejected: a Dismiss action.** It duplicates the system's Clear and invites people to make a
  nudge go away without acting on it.
- **Rejected: colored tags.** They'd compete with the status colors (one color, one meaning).
  Revisit if testers ask for them.
- **Rejected: endless snoozing.** Snoozes can be longer, but there are only three per occurrence,
  and then only Done stops the nudging.
- **Rejected: streaks and celebration.** Done is quiet relief, not a reward loop.

## Key Flows

The protagonists are [ASSUMPTION]s drawn from the brief's audience, for the owner to replace with
real testers. Times follow the strength tables in brief §3. To follow along in the mockup, use its
seeded data and the **Next early nudge** and **Next Urgent nudge** controls.

### Flow 1: Setting up a medication reminder (Rosa, 71, blood-pressure pills morning and night)

Rosa's daughter installed the app. Rosa sets it up herself at the kitchen table one evening.

1. **First launch.** On the Welcome sheet she reads "Stopping the alarm counts as Done." and taps
   **Continue**.
2. She allows notifications, then alarms.
3. Now is empty: "All clear. Nothing needs you right now." She taps **+**.
4. **New Reminder.** Title "Morning pill", Repeat **Every Day** at 8:00 AM, **Relentless**. How It
   Nudges updates: nudges 1–3 are notifications, and nudges 4–20 ring as alarms.
5. Relentless snoozes are 5 minutes. Getting to the pill box takes her longer, so she sets **Snooze
   Length** to 15 min. How It Nudges shows it.
6. She taps **Add**. She adds a second reminder, "Evening pill", for 9:45 PM. A Relentless nudge
   could run past 10:00 PM, when her quiet hours start, so she turns on **Ignore Quiet Hours**
   ("Turn this on for medication or caregiving that can't wait.").
7. **Climax:** Coming Up shows both pills with the Relentless badge, and How It Nudges says exactly
   when each will ring. She knows they won't let her forget.

**Failure:** she denies alarms. Now shows the orange alarms-off banner with **Open Settings**, and
How It Nudges marks nudges 4–20 "Notification chain: alarms are off".

### Flow 2: The alarm she stopped too soon (Rosa, next morning)

Rosa's Morning pill from Flow 1 is due at 8:00 AM.

1. 8:00 AM: a Time Sensitive notification, "Morning pill · Nudge 1 of 20 · High". She's in the
   garden. Nudges 2 and 3 follow at 8:10 and 8:15.
2. 8:17 AM, nudge 4 (Urgent): the first alarm rings through silent mode on the Lock Screen:
   "Nudge-inator · Morning pill", **Snooze 15 min**, **Stop**.
3. She taps **Stop** to quiet it, meaning to take the pill once she's inside.
4. At once, an ordinary notification arrives: "Marked done: Morning pill. Not done yet?"
5. She hasn't taken it, so she long-presses the notification and taps **Not Done**.
6. The history records "Marked not done (nudging again)", and the next nudge comes one interval
   later.
7. **Climax:** the nudging card is back on Now. The app caught her reflex Stop at the moment she
   made it, and it will keep at her until she really takes the pill.

**Failure:** she ignores the follow-up. At lunch she opens Now, and Last 24 Hours shows "Done
(alarm stopped)" with **Not Done**. It stays available until tomorrow's 8:00 AM Morning pill falls
due. The Evening pill is a separate reminder, so it doesn't end that window.

**Mockup:** Not Done can be tried on "Walk the dog".

### Flow 3: Rent during a Focus (Marcus, 29, ADHD, working from a café)

Rent is due on the 1st at 7:30 AM, set to **Firm** and tagged `#money #home`. His Work Focus is on.

1. 7:30 AM, nudge 1 (Normal): the Focus holds it. 8:00 AM, nudge 2 (Normal): also held.
2. 8:15 AM, nudge 3 (High): a Time Sensitive notification gets through.
3. He long-presses it and taps **Snooze 15 min**. Later the card reads "2 snoozes left".
4. 8:30 AM, nudge 4 (Urgent): the alarm rings over the app, in the Dynamic Island [To confirm on a
   device: the alarm in the Dynamic Island over another app]. The card's top row reads "Urgent",
   with `alarm`.
5. He opens the banking app and pays, then taps **Stop** on the 8:35 alarm. The follow-up asks "Not
   done yet?", and he ignores it.
6. **Climax:** the nudging stops, with no alarms and no more notifications. In Nudge-inator the card
   has left the Nudging section, Last 24 Hours shows "Done (alarm stopped)", and the Now badge is
   gone.

**Failure:** he snoozes three times. Snooze disappears from the notification and the alarm, and the
card says "No snoozes left. Only Done stops it."

**Variant (iOS 18):** nudge 4 starts a notification chain instead: a Time Sensitive notification
every minute, up to 10, which silent mode can mute. He taps **Done** on one.

**Mockup:** the **Next Urgent nudge** control.

### Flow 4: Finding what slipped (Priya, 44, caregiver for her father, end of the day)

Priya tags her father's reminders `#dad`.

1. At 9 PM she opens **My Day**.
2. She taps **Filter by Tags** and checks `#dad`. The sheet says "5 due today with #dad". She taps
   **Done**.
3. My Day reads **Filter (1)**. The counts show Done 3, Missed 1, Left 1.
4. She taps **Missed**, and "Showing only Missed" appears. There's one row: "Evening walk · Missed:
   gave up after the limit".
5. She opens it. History shows when each nudge went out, and that none was answered.
6. In **Edit** she switches it to **Firm**. The form says a new strength applies from the next nudge,
   so tomorrow's walk nudges as Firm.
7. **Climax:** back on My Day, the timeline still reads in order with the filter on. In under a
   minute she knows what her dad missed today, and tomorrow's walk will push harder, starting
   higher.

**Failure:** nothing was missed. **Missed** shows 0 in gray and can't be chosen.

**Variant (branch):** her dad is in the hospital for a few days. She taps **Pause Reminder** on each
of his reminders. Anything due is skipped, not missed, and **Resume** picks up at the next due time.

**Mockup:** the seeded "Stretch break" reminder, whose missed occurrence shows on My Day and carries
over to "Starts higher".

### Flow 5: Browsing by tag (Marcus, Sunday planning)

Marcus plans his week by tag.

1. Marcus opens **Tags**. "Your Tags" lists each tag with counts; `#home` shows "6 reminders · 2
   today".
2. He taps `#home`. It becomes a token, and results appear under Today, Later, Paused and Completed.
3. He types "mor" and presses Return, which adds `#morning`: "1 reminder with #home and #morning".
4. He chooses **Any Tag**: "7 reminders with #home or #morning".
5. He taps **+**. The new reminder starts with `#home` and `#morning` already chosen.
6. **Climax:** he adds "Water the plants" (Gentle), already tagged, and it appears in the filtered
   results he's still looking at.

**Failure:** with **All Tags**, his tags match nothing. "No reminder has all of these tags. Try Any
Tag, or remove one."

### Flow 6: Searching (Priya)

Priya is looking for a reminder whose title she doesn't remember.

1. Priya taps the **Search** circle (a tab on iOS 18) and types "pharmacy".
2. One row matches in its notes: "…pick up from the pharmacy on Elm…".
3. **Climax:** she opens it and sees when it's next due. "pharmacy" is saved in Recent Searches.

**Failure:** "No Results for "pharmcy"", with "Check the spelling or try a new search."

**Surfaces without a journey.** Their behavior is specified in State Patterns and Component
Patterns, and in the mockup:
- **Settings:** Quiet Hours, Send a Test Nudge, Open iOS Settings, Export Data, Delete
  All Data, How Nudges Work
- **Tags:** Rename Tag and deleting a tag
- **Reminder details:** Delete Reminder
- **Elsewhere:** Siri & Shortcuts, Assistive Access

Add a flow for any of these if TestFlight shows it's needed.

## Open Items

**Assumptions:**
- The wording of the alarm-limit fallback ([Via label](#via-label)).
- The quiet-hours chip is a button; the mockup's chip is static ([Quiet-hours chip](#quiet-hours-chip)).
- `.selection` haptics; the owner specified only Done ([Interaction Primitives](#interaction-primitives)).
- The keep-nudging notice's wording ([Nudge Surfaces](#nudge-surfaces)).
- The flows' protagonists ([Key Flows](#key-flows)).

**Device checks:** the one list is in
[brief §10 › Device checklist](../product/brief.md#10-risks-and-decisions). The ones that can
change this spine are the Tags tab's token field ([Tag token field](#tag-token-field)), an alarm
that rings out ([Nudge Surfaces › States](#states)), the alarm over the app and in the Dynamic
Island ([Nudge Surfaces](#nudge-surfaces), Flow 3), Stop before the first unlock, which "Stopping the alarm counts as Done" depends on ([Voice and Tone](#voice-and-tone)), Assistive Access with alarms
([Assistive Access](#assistive-access)), the iPhone Duo
([Responsive & Platform](#responsive--platform)) and the
accessibility [release gate](#accessibility-floor).

**Architecture questions:** none. Filters across a relaunch were settled on 2026-10-03
([Information Architecture](#information-architecture)).
