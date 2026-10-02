# Nudge-inator iOS mockup

Nudge-inator as an **iPhone app**. Reminders, nudging and history all live on the device: there's
no account, no server and no website. A reminder can have **any number of tags** (or none), and you
find reminders by **filtering on one or more tags**.

- **Early nudges** (Normal and High urgency) are **local Time Sensitive notifications**. They get
  through Focus, and their actions are **Done**, **Snooze** and **Dismiss**.
- **Urgent nudges** ring as **AlarmKit alarms** (iOS 26 and later): a prominent system alert on the
  Lock Screen, sounding through silent mode and Focus, with **Snooze** and the system's **Stop**,
  which counts as Done.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. On a desktop
it shows a phone with **Mockup controls** beside it. On a phone the app fills the screen and the
controls are below it.

**Words.** A *nudge* is one alert sent while an occurrence is open: a notification or an alarm. A
reminder is *nudging* until you mark it done.

The [product brief](../../product/brief.md) is built on this mockup. It also covers what the mockup
doesn't show: landscape, iPad, and iOS 18.

## Product rules

- **Strengths:** Gentle, Firm and Relentless, each with its own intervals and urgency ladder.
- **Give-up limit:** 20 nudges or 24 hours by default, whichever comes first.
- **Quiet hours**, and **carry-over** after a missed occurrence ("↑ Starts higher").
- **Editing:** a repeat rule the form can't express is kept as it is ("Keep: …").
- **Privacy:** only the title (and, as iOS adds it, the app's name) is shown in notifications and
  alarms. Notes and tags stay in the app.

## Screens

The app uses standard iOS layouts: a tab bar, large titles, inset grouped lists, modal sheets,
alerts and action sheets. As on iOS, screens and sheets scroll without showing a scrollbar.

The bars follow iOS 26's Liquid Glass (see [Materials](#materials)):

- The **tab bar** is a glass capsule that floats above the content. The selected tab sits in a
  lighter pill, in the accent color. **Search** is a separate glass circle at the trailing end, as
  iOS 26 does for a search tab.
- **Bar buttons** are glass capsules (**Edit**, **Cancel**) or glass circles when they hold only a
  symbol (**+**, and Back, which shows just the chevron). They use the label color. The confirming
  action in a sheet (**Add**, **Save**, **Done**) is tinted with the accent color.

| Tab | SF Symbol | What it shows |
|---|---|---|
| **Now** | `bell` | Nudging cards with **Done** and **Snooze**, Coming Up (7 days), Last 24 Hours |
| **My Day** | `calendar` | Today in time order, with Now and quiet-hours markers. Done, Nudging, Missed and Left counts that filter the list, and a tag filter. |
| **Tags** | `tag` | Your tags with counts. Choose one or more to filter, then see the matching reminders in Today, Later, Paused and Completed sections. |
| **Settings** | `gearshape` | Nudges (permission status, Send a Test Nudge), Quiet Hours, Time Zone, Siri & Shortcuts, Your Data, About |
| **Search** | `magnifyingglass` | Every reminder, found by title, notes or tag, in Today, Later, Paused and Completed sections |

- **Search:** choosing the Search circle turns the tab bar into a search field, with the tab you
  came from shrunk to a circle in front of it. Tap that circle to go back.
  - Before you type, it shows an empty state that says what you can search. Once you've opened a
    result, it shows **Recent Searches** (up to five) with **Clear**.
  - When a reminder matches only in its notes, the row shows the words around the match. A leading
    `#` is ignored, so "#health" finds that tag.
  - With no matches it says **No Results for "…"**, as iOS apps do.
- **New reminder:** the **+** button in the navigation bar opens a sheet with **Cancel** and
  **Add**.
  - The **Title** wraps onto more lines as you type. Return doesn't add a line.
  - **Tags** opens a page with a **New Tag** field and a checklist of your tags.
  - **Repeat** opens a picker page: Never, Every Day, Every Weekday, Every Week, Every 2 Weeks,
    Every Month, Every Year, or Custom (frequency, interval and weekdays).
  - **Strength** is a segmented control.
  - **Give Up** uses a stepper for the number of nudges and a menu for the time.
  - **How It Nudges** previews every nudge: when it comes, its urgency, and whether it's a
    notification or an alarm.
- **Reminder details** are pushed onto the tab's navigation stack. They show the nudging card, the
  reminder's tags, the schedule, How It Nudges, the history (kept 90 days), **Pause** or
  **Resume**, and **Delete**, which asks for confirmation in an action sheet. **Edit** is in the
  navigation bar.
- **First launch:** a welcome screen, then the notification permission prompt, then the alarm
  permission prompt.

## Tags

**What a tag is:**
- **A name, nothing else.** It's one word, shown as `#home`. Typing spaces turns them into hyphens
  ("dog walks" becomes `#dog-walks`), and a leading `#` is dropped. Names are up to 30 characters.
- **No color.** Tags are all the same neutral gray, so they never compete with the status colors
  (see [Color](#color)).
- **Names are unique**, ignoring case. Adding `Home` when `#home` exists reuses `#home`.
- **Stays in the app.** Like notes, tags are never shown in notifications or alarms.

The made-up data has seven tags: `#appointments`, `#health`, `#home`, `#money`, `#morning`,
`#travel` and `#work`. Most reminders have two. "Call Grandma" has none.

**Filtering on the Tags tab:**
- **Choose tags.** The field at the top finds tags as you type. Tap a tag in the list, or press
  Return to take the first match, and it becomes a **token** under the field. Tap a token to remove
  it. **Clear** removes them all.
- **Match All Tags or Any Tag.** Once two or more tags are chosen, a segmented control appears.
  **All Tags** is the default and shows reminders that have every chosen tag. **Any Tag** shows
  reminders with at least one.
- **The result** says what it's showing, for example "1 reminder with #home and #morning" or
  "7 reminders with #home or #morning". In each row the chosen tags are in bold.
- **No matches** says why. With All Tags, it suggests Any Tag or removing a tag.
- **The filter stays.** It's still there after you open a reminder and come back.

**Before you choose any tags,** the tab lists every tag. Each row shows how many reminders have
that tag, how many are due today, and how many are nudging (in red). The footer says how many
reminders have no tags.

**Edit** (in the navigation bar) switches the list to **Rename** and **Delete** for each tag.
- **Rename** opens a sheet. A name that's already used shows an error.
- **Delete** asks first: "It's removed from 3 reminders. They aren't deleted."

There's no "Add Tag" button. You create tags while editing a reminder, where you need them.

**Tags elsewhere:**
- **New and Edit Reminder.** A **Tags** row under Notes shows the reminder's tags or "None". Tags
  created on its page are kept only if you save the reminder with them checked. A new reminder
  started from the Tags tab begins with the tags you're filtering by.
- **Reminder details.** A row of tag buttons. Tapping one opens the Tags tab, filtered by that tag.
- **Now, My Day and lists.** Rows and nudge cards show the tags (`#home #money · due 8:10 AM`).
- **Delete All Data** deletes tags along with reminders and history.
- **Assistive Access** leaves out tags.

## My Day's filters

- **Filter by Tags** opens a **Filter My Day** sheet:
  - a checklist of your tags, with **Match All Tags or Any Tag** once two or more are checked
  - **No Tags**, which shows only reminders without tags. Checking it clears the tags, and checking
    a tag clears it. My Day is the only place to see reminders with no tags.
  - The sheet applies changes as you make them and says how many match ("7 due today with #work or
    #morning"). **Clear** resets the filter, and **Done** closes the sheet.

  Back on My Day, the button reads **Filter (2)**, and the chosen tags show as tokens you can
  remove, with **Clear**. The rows and the counts all follow the filter. In each row the chosen
  tags are in bold. My Day's filter is separate from the Tags tab's.
- **The counts filter the list.** Tap **Done**, **Nudging**, **Missed** or **Left** to show only
  those reminders, and tap it again to show everything.
  - The chosen count sits in a filled box with an accent ring, so it doesn't rely on color alone.
    VoiceOver reads it as selected.
  - "Showing only Missed" appears under the counts, with **Show All**.
  - Only one count can be chosen at a time. It works together with the tag filter: the counts are
    for the tagged reminders, and the list shows the chosen count within them.
  - A count of 0 can't be chosen. If the chosen count drops to 0 (after **Done**, say), it stays
    chosen, and the list says, for example, "Nothing is nudging you".
  - The Now and quiet-hours markers stay in the list, so it still reads as a timeline.

## How nudges reach you

| Nudge | Arrives as | Actions |
|---|---|---|
| Normal or High urgency | Time Sensitive notification | **Done**, **Snooze** (while snoozes are left), **Dismiss** |
| Urgent (Firm and Relentless, from nudge 4) | AlarmKit alarm | **Stop** (counts as Done), **Snooze** (while snoozes are left) |
| Urgent, with alarms not allowed | Time Sensitive notification | as above |

- **Gentle** reminders never reach Urgent, so they never ring an alarm.
- **Done** stops the nudging and cancels the reminder's remaining notifications and alarms.
- **Snooze** waits a fixed time set by the strength: Gentle 30 minutes, Firm 15, Relentless 5.
  - It doesn't raise the level, and the snoozed time doesn't count toward the time limit.
  - Each occurrence can be snoozed 3 times. Then Snooze disappears from the card, the notification
    and the alarm, and the card says "No snoozes left. Only Done stops it."
- **Dismiss** clears only the notification. The next nudge still comes on time, and the history
  records "Notification cleared (still nudging)".
- If **alarms** are turned off in iOS Settings, Now and Settings show a banner, and Urgent nudges come
  as notifications, which silent mode can mute. If **notifications** are off, a red banner says
  that only Urgent nudges can reach you, as alarms (or that nothing can, if alarms are off too).
  Nudging cards and How It Nudges mark each nudge that can't arrive as **Notifications off**, with
  `bell.slash`, in red.
  The two permissions are separate, so the alarm prompt comes after the notification prompt
  whatever the person chose. That alarms still ring with notifications off is to be confirmed on a
  device.
- **The alarm is AlarmKit's system alert.** iOS draws it over the Lock Screen, under the Lock
  Screen clock, with the app's name above the title. The app supplies only:
  - the title: the reminder's title
  - the secondary button: **Snooze 15 min** (the strength's length) with `clock`, filled with the
    tint color. It's left off once the occurrence has no snoozes left (see below).
  - the tint color: the app's accent

  The stop control is the system's own from iOS 26.1: `AlarmPresentation.Alert`'s `stopButton` is
  deprecated and ignored, so the app can't label it **Done**. The mockup shows it as **Stop**.
  Stopping runs the app's stop intent, which marks the occurrence done, and onboarding says
  "Stopping the alarm counts as Done". The nudge count and snoozes left can't appear on the alarm,
  so the nudging card in the app shows them. The mockup's layout, wording and colors for the system
  parts are an approximation.
- **After Snooze on the alarm,** AlarmKit counts down and rings again when the time is up. The
  countdown shows on the Lock Screen as the app's **Live Activity**: the title, the time left,
  "Snoozed. Rings again at 8:35 AM." and **Done** to stop it early. The app designs this view, in a
  widget extension. Before the first unlock after a restart, iOS shows its own countdown instead,
  from the alarm's countdown presentation.
- **The alarm that rings again keeps its buttons,** so the third Snooze can't simply remove Snooze
  from it. On the third snooze, the app's snooze intent cancels that alarm and schedules a new one
  for the end of the snooze, without Snooze. Each snooze also moves the occurrence's later alarms,
  so none ring during the snooze.

**Pausing:**
- **Pause Reminder** stops the nudging. An occurrence that's nudging closes as **Skipped**, not
  missed.
- Anything due while the reminder is paused is skipped too, so there's no carry-over from a pause.
- **Resume** picks up at the next time in the future. A one-off reminder whose time passed while it
  was paused asks for a new time.

## Mockup controls

These are not part of the app:

- **Next early nudge** shows the Lock Screen with a Time Sensitive notification for the next nudging
  reminder whose next nudge isn't Urgent. Tap it to see its actions, which on an iPhone come from a
  long press. It sends a real nudge in the mockup, so the card and history update.
- **Next Urgent nudge** shows the alarm for the next reminder whose next nudge is Urgent. **Snooze**
  shows the Live Activity, and **Unlock** returns to the app. Press it several times to use up the
  snoozes and see the alarm with only **Stop**.
- **First launch** shows onboarding and the permission prompts.
- **Screen size** switches the phone between the screen sizes, in points, of the iPhones that run
  iOS 18 or later, from iPhone SE (375 × 667) to iPhone 17 Pro Max (440 × 956). The iPhone XS, XS
  Max and XR are included: they stop at iOS 18, and share their sizes with later models. The top of
  the screen matches each one: the Dynamic Island, a notch, or a Home button. The phone is scaled
  down, never up, to fit the window.
- **Permissions**, **24-Hour Time**, **Appearance**, **Text Size** (all 12 Dynamic Type sizes),
  **Bold Text**, **Increase Contrast**, **Reduce Transparency** and **Assistive Access** stand in
  for iOS Settings.
- **Reset the mockup** restores the data.

The clock is fixed at Monday 28 Sep 2026, 8:20 AM. A snooze pushes the next nudge later, but the
clock doesn't move.

## Icons

Icons follow Apple's Human Interface Guidelines page on
[Icons](https://developer.apple.com/design/human-interface-guidelines/icons) (a local copy is in
`docs/apple/design/`). A web page can't use SF Symbols, so each icon is drawn to match the SF Symbol
it names. The real app uses the symbols themselves.

- **Standard actions use the standard symbols** from the page's table:

  | Action | Symbol |
  |---|---|
  | Done | `checkmark` |
  | Dismiss, remove a tag from the filter | `xmark` |
  | Delete | `trash` |
  | New reminder, add a tag to the filter | `plus` |
  | Filter | `line.3.horizontal.decrease` |
  | Search | `magnifyingglass` |
  | Export Data | `square.and.arrow.up` |
  | Alarms | `alarm` |
  | My Day | `calendar` |

- **Other icons use the nearest SF Symbol:** `bell`, `tag` and `gearshape` for tabs;
  `chevron.backward` and `chevron.right`; `moon.fill` for quiet hours and `arrow.up` for "starts
  higher"; `pause`, `play` and `clock`; `bell.slash` for a nudge that can't arrive because
  notifications are off; `exclamationmark.triangle`, `lock`, `info.circle`, `mic` and
  `accessibility`.
- **Rename** in the Tags tab's Edit mode is a text button, so it doesn't need `pencil`.
- **One stroke weight, matched to the text beside it.** Icons next to regular text use a regular
  stroke. Icons in bold buttons, tokens, chevrons, status labels and tiles use a semibold stroke.
  Bold Text makes every stroke heavier.
- **Evened-out sizes.** Some icons are scaled slightly so they look the same size as the others,
  and asymmetric ones (`bell`, `alarm`, `square.and.arrow.up`, `exclamationmark.triangle`) are
  nudged up to look centered.
- **Scales with the text.** Icons are sized in `rem`, as SF Symbols follow Dynamic Type. Tab bar and
  navigation bar symbols are fixed, like their titles.
- **No separate selected versions.** The selected tab only changes color, which is what the system
  does.
- **Text labels.** Every icon-only button has one ("New Reminder", "Delete #home"). The + on a tag
  row reads "add to filter". Decorative icons, such as tag tiles, are hidden from screen readers.

## Typography

Text follows Apple's Human Interface Guidelines page on
[Typography](https://developer.apple.com/design/human-interface-guidelines/typography) (a local copy
is in `docs/apple/design/`).

- **The system font only.** All text is SF Pro, through `-apple-system`.
- **Built-in text styles.** Every piece of app text uses one of the iOS text styles, never an
  ad-hoc size:

  | Style | Size at Large (default) | Used for |
  |---|---|---|
  | Large Title, bold | 34 pt | Screen titles, the welcome screen |
  | Title 1, bold | 28 pt | The alarm's reminder title |
  | Title 2, bold | 22 pt | Reminder title in details, My Day counts |
  | Title 3 | 20 pt | Section title "Nudging" (semibold), action sheet buttons, steppers, Lock Screen date |
  | Headline | 17 pt semibold | Navigation titles, nudge card titles, alert titles |
  | Body | 17 pt | Row titles, buttons, notification actions |
  | Subhead | 15 pt | Row details, statuses, notifications, tokens, small buttons |
  | Footnote | 13 pt | Section headers and footers, timestamps, chips, segmented controls |
  | Caption 1 | 12 pt | Strength badges, count labels |

  Emphasized weights follow the page's specification table: Bold for the titles and Semibold for
  Title 3 and the smaller styles.
- **Dynamic Type at all 12 sizes,** xSmall to xxxLarge and AX1 to AX5, using the iOS Dynamic Type
  tables. Sizes grow by style: at AX5, Body goes from 17 to 53 pt and Large Title from 34 to 60 pt.
- **Tracking from Apple's table.** Letter spacing follows the SF Pro tracking table for each point
  size.
- **Legible sizes and weights.** Nothing is smaller than 11 pt. Weights are Regular, Medium,
  Semibold and Bold only. **Bold Text** steps every weight up one level.
- **Layouts that adapt at large sizes (AX1 to AX5):**
  - Rows stack: the time, the title and the trailing detail each get their own line.
  - Segmented controls (Strength, Frequency, Match) list their options vertically.
  - History events wrap under their time.
  - The day's four counts become two columns.
  - Text wraps; nothing is cut off with "…". The reminder **Title** field wraps onto more lines.
- **Fixed-size system elements.** The tab bar, inline navigation titles and bar buttons keep their
  default size (17 pt) at every text size, so they never crowd each other. People use the Large
  Content Viewer instead. Large titles are content and scale. The status bar, Lock Screen clock and
  alarm clock are fixed too.
- **Short placeholders.** The Tags tab's field says "Find a tag" or "Add a tag", which fit at AX3.

**How it was checked:** in headless Chrome, all 12 Dynamic Type sizes with Bold Text off and on
(24 combinations), on 17 screens:
- the Tags tab: browsing, filtered, typing, no results and Edit
- Rename Tag
- New and Edit Reminder, with the Tags, Repeat and Custom pages
- My Day with a tag filter and a status filter, the No Tags filter, and the Filter My Day sheet
- reminder details, with history open
- Search and Now

The checks confirmed that:
- every visible piece of text uses one of that size's text styles, with Apple's tracking, apart
  from the fixed-size bars
- nothing is under 11 pt or lighter than Regular
- nothing is clipped, cut off with "…" or scrolls sideways, and no placeholder overflows its field
- navigation bar items never overlap and stay at 17 pt

## Color

Colors follow Apple's Human Interface Guidelines page on
[Color](https://developer.apple.com/design/human-interface-guidelines/color) (a local copy is in
`docs/apple/design/`).

**One color, one meaning.** Status colors are named by their job, and nothing else uses them:

| Token | Hue | Means | Used for |
|---|---|---|---|
| `--accent` | blue | You can tap this | Buttons, links, the selected tab, menus, checkmarks, tokens, the chosen count's ring |
| `--negative` | red | Danger or needs you now | Nudging, Urgent, Missed, errors, Off, destructive actions |
| `--warning` | orange | Escalating | High urgency, "starts higher" |
| `--positive` | green | Done or on | Done, switches that are on |
| `--quiet` | indigo | Quiet hours | The quiet-hours chip, notes and markers |

- **Strength has no color.** It's a neutral capsule with its name and a bars glyph (one, two or
  three bars).
- **Nudge cards take their color from urgency:** gray for Normal, orange for High, red for Urgent.
- **Tags have no color.** Tags, tag tiles (gray) and the highlighted tags in a row (bold, not
  colored) are all neutral.
- **Zero counts aren't status-colored.** "0 Missed" isn't red, because nothing needs you. A count of
  0 uses the secondary label color, which also signals that it can't be chosen.
- **The "Now" marker on My Day** is plain label text, not the accent, which would mean tappable.

**Color sparingly on controls.** Only primary actions get a colored background: the confirm button
in each sheet (**Add**, **Save**, **Done**) and **Done** on each nudge card. My Day's per-row
**Done** buttons are tinted instead of filled, so a long list isn't a column of blue.

**Semantic colors used as named.** Token names match the UIKit and SwiftUI colors they stand for,
and each is used only for its purpose:

| Token | UIKit / SwiftUI |
|---|---|
| `--system-grouped-background` | `systemGroupedBackground` |
| `--secondary-system-grouped-background` | `secondarySystemGroupedBackground` |
| `--label` | `label` |
| `--secondary-label` | `secondaryLabel` |
| `--tertiary-label` | `tertiaryLabel` (chevrons) |
| `--placeholder-text` | `placeholderText` |
| `--separator` | `separator` |
| `--tertiary-system-fill` | `tertiarySystemFill` (tokens, the chosen count) |
| `--system-gray` | `systemGray` (control outlines) |
| `--accent` | `AccentColor`, the app's own color set |

**System color values.** The real app uses the system colors through their APIs. This mockup has to
use values:
- **Graphics** (tiles, the badge) use Apple's published values, with all four variants.
- **Text** in a status color uses slightly darker (light mode) or lighter (dark mode) versions of
  the same hues, because several default system colors are below 4.5:1 as text.
- The accent is the app's own color set, with light, dark and Increased Contrast values.
- **The selected tab's title** has its own shade of the accent (`--tab-selected`), so it reaches
  4.5:1 (7:1 with Increase Contrast) on the tab's translucent pill:

  | Appearance | `--tab-selected` | On the pill |
  |---|---|---|
  | Light | the accent (`#0064D2`) | 4.5:1 or more |
  | Light, Increase Contrast | `#0032B3` | 7.1:1 |
  | Dark | `#74B7FF` | 4.6:1 or more |
  | Dark, Increase Contrast | `#D8ECFF` | 7.1:1 |

**Not color alone.** Every status has words as well as a color, such as "Nudging", "Urgent",
"Missed" and "Done". Strength shows its name and bars. The chosen count has a fill, a ring and
`aria-pressed`, and "Showing only Left" says it in words.

**How it was checked:** in headless Chrome, on the same 17 screens, in all 8 combinations of light
and dark, Increase Contrast and Reduce Transparency:
- **A contrast audit** measured every visible piece of text against the background actually
  behind it, with translucent layers combined. All text reaches 4.5:1, or 7:1 with Increase
  Contrast. The only exceptions are disabled controls (**Add** with no tag typed, and a stepper at
  its limit) at 4.40:1, which WCAG exempts.
- **A color-role check** listed every element drawn in the accent color, and every one is
  tappable.

## Dark Mode

Dark mode follows Apple's Human Interface Guidelines page on
[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) (a local copy
is in `docs/apple/design/`):

- **No app-specific appearance setting.** The app follows the iPhone's Light, Dark or Automatic
  setting. The **Appearance** mockup control stands in for it.
- **Colors that adapt.** Every color is a token with light, dark and Increased Contrast values.
- **Base and elevated backgrounds.** In dark mode, sheets, alerts, action sheets and status
  messages use the brighter elevated backgrounds (`#1C1C1E` behind, `#2C2C2E` for cells), so they
  stand out from the black screen. Light mode uses the same colors for both.
- **Increase Contrast** switches text to stronger variants that reach 7:1, makes separators and
  control edges stronger, and outlines tinted buttons, tokens, segmented controls, steppers and
  date fields.
- **Icons on colored tiles** use Apple's Increased Contrast (light) system colors in every mode, so
  each white glyph keeps at least 4.5:1.
- **Dark-only screens.** The Lock Screen and the alarm are dark in both modes, like the system
  screens they imitate. The Live Activity uses the Lock Screen material, which follows the
  appearance.

**How it was checked:** in headless Chrome, a script confirmed that each sheet and its cells are
lighter than the screen and the cells behind them, in all 4 dark combinations. The contrast audit
under [Color](#color) covered dark mode too.

## Accessibility

Accessibility follows Apple's Human Interface Guidelines page on
[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) (a
local copy is in `docs/apple/design/`), and WCAG 2.1 AA:

**Vision**
- **Larger text** up to AX5, about 3 times the default (see [Typography](#typography)).
- **Contrast** of at least 4.5:1, or 7:1 with Increase Contrast (see [Color](#color)).
- **More than color.** Every status has words, and strength has its name and a bars glyph.
- **VoiceOver.**
  - Every control has a name, and buttons repeated for several reminders include the reminder's
    title ("Done: Take the bins out").
  - Every view has one heading that gets focus when you navigate.
  - Sheets, alerts, the Lock Screen and the alarm are modal.
  - Status changes are announced, including the result of every filter and search ("7 reminders
    with #home or #morning", "Showing only Nudging: 2 due today with #home"). They use one live
    region that stays in place, because the screens re-render whole.

**Hearing**
- Every nudge vibrates as well as sounding, and the alarm and notifications are visual, so nothing
  relies on hearing it.

**Mobility**
- **Target size.** Buttons are at least 44 pt tall, apart from the iOS switch, stepper, segmented
  control and menus, which are at least 28 pt and sit in 44 pt rows. A reminder's row or card is its
  tap target, and its Done button keeps its own action.
- **Spacing.** Controls with a visible shape are 12 pt apart, such as Done and Snooze on nudge
  cards, tokens, and Rename and Delete in Edit mode.
- **No gestures needed.** Every action is a button. There are no swipe actions.
- **Voice Control.** Every control's name includes its visible label ("Remove #home from the
  filter", "Rename #home").
- **Siri and Shortcuts.** "Mark my nudge done", "Snooze my nudge" and "What's nudging me?", from
  Siri, the Action button or a Home Screen shortcut.

**Speech**
- **Keyboard alone.** Every control can be reached with Tab and used with Enter or Space. Return
  chooses the first matching tag or adds a new one, and Escape closes a sheet or alert.

**Cognitive**
- **Nothing on a timer.** Status messages stay until your next tap or key press.
- **Reduce Motion.** Transitions run only when Reduce Motion is off.
- **Assistive Access** (mockup control). The app shrinks to one screen: what needs you now, with
  large Done and Snooze buttons, and what's later today. No tab bar, editing, tags or settings.

**Accessibility Nutrition Labels.** The App Store listing can declare:

| Feature | Supported |
|---|---|
| VoiceOver | Yes |
| Voice Control | Yes |
| Larger Text | Yes |
| Dark Interface | Yes |
| Differentiate Without Color Alone | Yes |
| Sufficient Contrast | Yes |
| Reduced Motion | Yes |
| Captions, Audio Descriptions | Not applicable: the app has no video or audio content |

**How it was checked:** in headless Chrome, on the same 17 screens, at Large and AX3, with the
phone's on-screen scale taken out:
- every enabled control meets the target sizes above
- every control's name contains its visible label
- every control can be reached by keyboard
- each filter change and search is announced with its result
- **axe-core** (WCAG 2.0 and 2.1, A and AA) found no violations, in light and dark

**Known gaps:** iOS form fields are borderless, as in the Settings app, so they have no 3:1
borders. The app will need testing with Accessibility Inspector, VoiceOver, Voice Control and
Switch Control on a real iPhone, which a web mockup can't stand in for.

## Materials

Materials follow Apple's Human Interface Guidelines page on
[Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (a local copy
is in `docs/apple/design/`):

- **Liquid Glass only in the functional layer.** Glass is used for the tab bar, the Search circle and
  field, and navigation bar buttons, and nowhere else. The content layer uses ordinary fills:
  tokens, the chosen count, tag buttons and the Match control.
- **The regular variant, not clear.** The glass blurs and tints what's behind it. The app has no
  photo or video backgrounds that would call for clear glass.
- **Glass used sparingly.** Only the confirming action in a sheet is tinted.
- **Legible colors on materials.** Text on glass and on the alert and notification materials uses
  the label and secondary label colors, never a quaternary level.
- **The navigation bar has no background of its own.** Content scrolls under its glass buttons, as
  in iOS 26:
  - A **scroll edge effect**, a blur that fades the content out, keeps the buttons and title
    legible.
  - The large title scrolls away with the content, and the **inline title** fades in once it's
    gone. The large title stays the screen's heading for VoiceOver.
  - A gentler edge effect fades content under the floating tab bar.
  - Sheets keep solid bars, because their content scrolls inside the sheet, not under the bar.
- **System materials stay system.** Alerts, action sheets and the Lock Screen notification keep
  their standard blurred materials. Full-height sheets are opaque, as iOS's large sheets are.
- **Accessibility settings.** Reduce Transparency makes every material, glass surface and edge
  effect solid. Increase Contrast gives glass a visible edge.

**How it was checked:** in headless Chrome, My Day was scrolled in light, dark and Reduce
Transparency. A script confirmed that the inline title is hidden at the top and shown once the
large title is under the bar, and screenshots were checked by eye.

## Open questions

- **Should My Day and the Tags tab share one filter?** They're separate now, so filtering My Day
  to `#work` doesn't change what the Tags tab shows.
- **Should My Day's counts allow more than one at a time,** such as Nudging and Missed together?
- **Is All Tags the right default?** Choosing a second tag narrows the list, as it does in Mail and
  Reminders' smart lists. If people expect it to widen the list, Any Tag should be the default.
- **Tag colors.** Leaving them out keeps the color rules simple. If people need to tell tags apart
  at a glance, a fixed palette could be added.
- **Fixed-size bars at large text sizes,** or bars that grow with the text?
- **The pale selected-tab color** in dark mode with Increase Contrast (`#D8ECFF`): acceptable, or a
  darker pill instead?

## How it was checked

In headless Chrome, a script went through these steps, and the console had no errors:
1. browse tags
2. choose `#home`, then type "#mor" and press Return to add `#morning`
3. switch to Any Tag
4. open a result, then tap its tag to filter by it again
5. create a reminder with a new tag
6. rename `#home` and delete `#travel`
7. filter My Day by `#work` and `#morning`, switch to Any Tag, remove a token, then filter by No
   Tags and clear it
8. on My Day, tap each count, mark a nudging reminder done while showing Nudging, combine Left
   with a `#work` filter, tap a count again to turn it off, and use Show All
9. search "#health"

The alarm and its Live Activity were checked separately, in light and dark, with Increase Contrast
off and on, at Large and AX3. They were checked again after the AlarmKit corrections (the system's
Stop control, Snooze filled with the tint color, and the app's name), together with the screens
those corrections changed: Now, Settings and a Firm reminder's details (How It Nudges) with
notifications off, alarms off and both off, and onboarding.
- axe-core found no violations
- the buttons are at least 44 pt tall
- the app's text on the alarm and the Live Activity reaches 7.4:1 or more against the background
  behind it, so it passes 4.5:1 and 7:1 with Increase Contrast. The banners, Settings rows,
  **Notifications off** labels and onboarding text reach 4.5:1, or 7:1 with Increase Contrast.
- **Notifications off** appears only while notifications are off
- after the third snooze, the alarm shows only **Stop**
- no app status message appears over the Lock Screen
- the alarm permission prompt follows the notification prompt, whichever choice is made
- the console has no errors

At AX5 the alarm scrolls instead of clipping.

The typography, contrast, accessibility and materials checks above were run on the final version,
apart from the AlarmKit corrections, which were checked as described in the previous paragraph.
