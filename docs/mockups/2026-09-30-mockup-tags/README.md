# Mockup 3, with tags instead of groups

This is [mockup 3](../2026-09-30-mockup/README.md) with one change. **Groups are gone.** A
reminder can have **any number of tags** (or none), and you find reminders by **filtering on one or
more tags**.

Everything else is the same as mockup 3: nudges, alarms, strengths, quiet hours, pausing, the
Search tab, accessibility, typography, color and the mockup controls.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What a tag is

- **A name, nothing else.** It's one word, shown as `#home`. Typing spaces turns them into hyphens
  ("dog walks" becomes `#dog-walks`), and a leading `#` is dropped.
- **No color.** Groups had a six-color palette. Tags are all the same neutral gray. That way they
  never compete with the status colors (see mockup 3's [Color](../2026-09-30-mockup/README.md#color)).
- **Names are unique**, ignoring case. Adding `Home` when `#home` exists reuses `#home`.
- **Stays in the app.** Like notes, tags are never shown in notifications or alarms.

The made-up data has seven tags: `#appointments`, `#health`, `#home`, `#money`, `#morning`,
`#travel` and `#work`. Most reminders have two. "Call Grandma" has none.

## Tags tab (replaces Groups)

| Tab | SF Symbol | What it shows |
|---|---|---|
| **Tags** | `tag` | Your tags with counts. Choose one or more to filter, then see the matching reminders in Today, Later, Paused and Completed sections. |

**Filtering:**
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
- **Delete** asks first: "It's removed from 3 reminders. They aren't deleted." That replaces
  mockup 3's "Its reminders move to No Group."

There's no "Add Tag" button. You create tags while editing a reminder, where you need them.

## Other screens

- **New and Edit Reminder.** The **Group** menu is replaced by a **Tags** row under Notes, showing
  the reminder's tags or "None". It opens a **Tags** page:
  - a **New Tag** field with **Add**, which also works with Return
  - a checklist of your tags
  - Tags created here are kept only if you save the reminder with them checked.
  - A new reminder started from the Tags tab begins with the tags you're filtering by, as mockup 3
    filled in the group you were looking at.
- **Reminder details.** The group chip is replaced by a row of tag buttons. Tapping one opens the
  Tags tab, filtered by that tag.
- **Now, My Day and lists.** Where a row or nudge card showed the group name, it shows the tags
  (`#home #money · due 8:10 AM`).
- **My Day's filter** picks one or more tags, like the Tags tab. The **Filter by Tags** button opens
  a **Filter My Day** sheet:
  - a checklist of your tags, with **Match All Tags or Any Tag** once two or more are checked
  - **No Tags**, which shows only reminders without tags. Checking it clears the tags, and checking
    a tag clears it. My Day is the only place to see reminders with no tags.
  - The sheet applies changes as you make them and says how many match ("7 due today with #work or
    #morning"). **Clear** resets the filter, and **Done** closes the sheet.

  Back on My Day, the button reads **Filter (2)**, and the chosen tags show as tokens you can
  remove, with **Clear**. The rows and the Done, Nudging, Missed and Left counts all follow the
  filter. In each row the chosen tags are in bold. My Day's filter is separate from the Tags tab's.
- **My Day's counts filter the list.** Tap **Done**, **Nudging**, **Missed** or **Left** to show only
  those reminders, and tap it again to show everything.
  - The chosen count sits in a filled box with an accent ring, so it doesn't rely on color alone.
    VoiceOver reads it as selected.
  - "Showing only Missed" appears under the counts, with **Show All**.
  - Only one count can be chosen at a time. It works together with the tag filter: the counts are
    for the tagged reminders, and the list shows the chosen count within them.
  - A count of 0 can't be chosen. If the chosen count drops to 0 (after **Done**, say), it stays
    chosen, and the list says, for example, "Nothing is nudging you".
  - The Now and quiet-hours markers stay in the list, so it still reads as a timeline.
- **Search** also matches tag names, and ignores a leading `#`, so "#health" works. The placeholder
  reads "Title, notes or tag".
- **Delete All Data** deletes tags along with reminders and history.
- **Assistive Access** still leaves out tags, as it left out groups.

## Icons

The icons follow mockup 3's [Icons](../2026-09-30-mockup/README.md#icons) rules. These are the
symbols this mockup adds or uses in new places. The standard actions use the symbols from the
standard-icons table in Apple's Icons page:

| Where | Action | Symbol |
|---|---|---|
| My Day's **Filter by Tags** button | Filter | `line.3.horizontal.decrease` (standard) |
| Tag rows (+ beside each tag) | Add | `plus` (standard) |
| Tokens (remove a tag from the filter) | Deselect | `xmark` (standard) |
| Edit mode on the Tags tab | Delete | `trash` (standard) |
| Tags tab, tag tiles, Rename Tag sheet, empty state | Tag | `tag` (nearest symbol) |

- **Rename** in Edit mode is a text button, so it doesn't need `pencil`.
- **One stroke weight.** Token ✕ marks use the semibold stroke, like the token text, and get
  heavier with Bold Text, like every other icon.
- **Text labels.** The + on a tag row is decorative to sight, but VoiceOver reads "add to filter"
  after the tag. The Delete icon is labeled "Delete #home". Tag tiles are decorative and hidden.
- **Checked against the other symbols.** `tag` was drawn at the same size and weight as `bell` and
  `calendar` and is optically centered. `line.3.horizontal.decrease` looks lighter, as Apple's
  symbol does.

## Typography

Text follows mockup 3's [Typography](../2026-09-30-mockup/README.md#typography) rules: SF Pro
only, the built-in text styles, all 12 Dynamic Type sizes, Apple's tracking table, and stacked
layouts at AX1 to AX5. Everything new uses them too:
- Tokens use Subhead.
- The count buttons keep Title 2 numbers and Caption 1 labels.
- The Match control is a segmented control (Footnote).
- The Filter My Day and Rename Tag sheets use the same rows and footers as the other sheets.

This review changed four things. The first two were already in mockup 3:

- **Segmented controls stack at accessibility sizes.** At AX3 to AX5, the Strength control cut off
  "Relentless". At AX1 to AX5, every segmented control now lists its options vertically. That
  covers Strength, Frequency, and Match All Tags or Any Tag.
- **History events wrap.** At AX5, an open history row cut off lines like "Nudge 2 · level 1 ·
  High · notification". Events now wrap under their time.
- **Navigation bars keep their size.** At AX3, a sheet's title ran into **Cancel** and **Save**.
  Inline navigation titles and bar buttons are now fixed-size system elements, like the tab bar:
  they stay at Headline and Body (17 pt) at every Dynamic Type size, and people use the Large
  Content Viewer. Their symbols (Back, +) stay fixed too. Large titles are content and still scale.
- **No truncated text.**
  - The reminder **Title** field wraps onto more lines, as in Reminders, instead of scrolling out
    of view. It's still one paragraph: Return doesn't add a line.
  - The Tags tab's placeholders were shortened to "Find a tag" and "Add a tag". "Add another tag"
    was cut off at AX3.

**How it was checked:** in headless Chrome, all 12 Dynamic Type sizes with Bold Text off and on
(24 combinations). Each covered these screens:
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

Color follows mockup 3's [Color](../2026-09-30-mockup/README.md#color) rules: one color, one
meaning, and the accent only on things you can tap. The new parts follow them too:
- **Accent (tappable):** tokens, the + on tag rows, tag buttons in details, Filter by Tags, Show
  All, Rename, and the ring on the chosen count.
- **Status colors:** "2 nudging" on a tag row is red, the same red as Nudging everywhere else.
- **Neutral:** tags themselves, tag tiles in gray, and the highlighted tags in a row, which are bold,
  not colored.
- **Semantic colors as named:** tokens and the chosen count use `tertiarySystemFill`.
- **Not color alone:** the chosen count has a fill, a ring and `aria-pressed`, and "Showing only
  Left" says it in words.

This review changed three things:

- **Zero counts aren't status-colored.** My Day showed "0 Missed" and "0 Nudging" in red and "0
  Done" in green. Red means danger or needs you now, and nothing does. A count of 0 is now in the
  secondary label color, which also signals that it can't be chosen.
- **The chosen count's label uses the label color.** The secondary label color on the count's fill
  was 4.40:1 in light mode.
- **The selected tab's title has its own shade of the accent** (`--tab-selected`). The accent on the
  tab's translucent pill was 3.4 to 3.9:1 in dark mode and 6.5:1 (light) and 4.8:1 (dark) with
  Increase Contrast. This was already in mockup 3. It's the same blue hue, so it means the same
  thing:

  | Appearance | `--tab-selected` | On the pill |
  |---|---|---|
  | Light | the accent (`#0064D2`) | 4.5:1 or more |
  | Light, Increase Contrast | `#0032B3` | 7.1:1 |
  | Dark | `#74B7FF` | 4.6:1 or more |
  | Dark, Increase Contrast | `#D8ECFF` | 7.1:1 |

**How it was checked:** in headless Chrome, on the same 17 screens as the typography check, in all
8 combinations of light and dark, Increase Contrast and Reduce Transparency:
- **A contrast audit** measured every visible piece of text against the background actually
  behind it, with translucent layers combined. All text reaches 4.5:1, or 7:1 with Increase
  Contrast.
  - The only exceptions are disabled controls (**Add** with no tag typed, and a stepper at its
    limit) at 4.40:1. WCAG exempts inactive controls.
- **A color-role check** listed every element drawn in the accent color, and every one is
  tappable.

## Dark Mode

Dark mode follows mockup 3's [Dark Mode](../2026-09-30-mockup/README.md#dark-mode) rules. The new
parts follow them too:
- **No app-specific appearance setting.** The app follows the iPhone.
- **Colors that adapt.** The only new color values are the `--tab-selected` tokens (see
  [Color](#color)). Each has light, dark and Increase Contrast variants. Everything else uses the
  existing semantic tokens.
- **Base and elevated backgrounds.** The new Filter My Day and Rename Tag sheets, and the reminder
  sheet's Tags page, use the elevated backgrounds in dark mode: `#1C1C1E` behind and `#2C2C2E`
  for cells. That makes them lighter than the black screen behind them, with Increase Contrast and
  Reduce Transparency on or off.
- **Contrast in every appearance.** See [Color](#color): the contrast audit covered dark mode with
  Increase Contrast and Reduce Transparency, separately and together.

This review changed one thing:

- **Tokens get an outline with Increase Contrast,** as mockup 3's tinted buttons, segmented
  controls, steppers and date fields do. Without it, a token's fill on the black screen (about
  1.4:1) was the only thing showing its shape.

**How it was checked:** in headless Chrome, a script confirmed that each new sheet and its cells
are lighter than the screen and the cells behind them, in all 4 dark combinations. Screenshots of
My Day and Filter My Day in dark mode, with and without Increase Contrast, were checked by eye.

## Accessibility

Accessibility follows mockup 3's [Accessibility](../2026-09-30-mockup/README.md#accessibility)
rules and WCAG 2.1 AA. The new parts follow them too:
- **Vision:** larger text, contrast and more than color are covered in [Typography](#typography),
  [Color](#color) and [Dark Mode](#dark-mode).
  - Every new control has a name that includes its visible label, for Voice Control. For example,
    "Remove #home from the filter", "Rename #home" and "Delete #home".
  - The + on a tag row reads "add to filter".
  - Each view still has one heading, and the new sheets are modal.
- **Mobility:** every new control is at least 44 pt tall, and there are no gestures. Deleting a tag
  asks first.
- **Speech:** Return chooses the first matching tag or adds a new one, and Escape closes the new
  sheets.
- **Cognitive:** nothing new runs on a timer. Assistive Access still leaves out tags along with
  editing and settings.

This review changed two things:

- **Filter and search results are announced.** The screens re-render whole, and text that's
  replaced isn't reliably read, so VoiceOver users didn't hear what a filter change did. Mockup 3's
  Search result count had the same problem. A single live region that stays in place now speaks:
  - the result of each Tags tab change ("7 reminders with #home or #morning")
  - each My Day change ("Showing only Nudging: 2 due today with #home")
  - matching tags as you type, and the Search result count
- **More space between controls.** Tokens are 12 pt apart, up from 8, and so are Rename and Delete
  in Edit mode, up from 6. That's the spacing the page suggests for controls with a visible shape.

**How it was checked:** in headless Chrome, on the same 17 screens, at Large and AX3, with the
phone's on-screen scale taken out:
- every enabled control is at least 44 pt tall, or 28 pt for the iOS switch, stepper, segmented
  control and menus, which sit in 44 pt rows
- every control's name contains its visible label
- every control can be reached by keyboard
- each filter change and search is announced with its result
- **axe-core** (WCAG 2.0 and 2.1, A and AA) found no violations, in light and dark

**Accessibility Nutrition Labels:** unchanged from mockup 3.

## Materials

Materials follow Apple's Human Interface Guidelines page on
[Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (a copy is in
`docs/design/`).

**Already in line with the page:**
- **Liquid Glass only in the functional layer.** Glass is used for the tab bar, the Search circle and
  field, and navigation bar buttons, and nowhere else. Everything new in the content layer uses
  ordinary fills, not glass: tokens, the chosen count, tag buttons and the Match control.
- **The regular variant, not clear.** The glass blurs and tints what's behind it. The app has no
  photo or video backgrounds that would call for clear glass.
- **Glass used sparingly.** Only the confirming action in a sheet (**Add**, **Save**, **Done**) is
  tinted.
- **Legible colors on materials.** Text on glass and on the alert and notification materials uses
  the label and secondary label colors, never a quaternary level.
- **Accessibility settings.** Reduce Transparency makes every material and glass surface solid, and
  Increase Contrast gives glass a visible edge.
- **System materials stay system.** Alerts, action sheets, and the Lock Screen notification keep
  their standard blurred materials. The full-height sheets are opaque, as iOS's large sheets are.

This review changed one thing, which was already in mockup 3:

- **The navigation bar no longer has a solid background.** The glass buttons sat on an opaque
  strip, so nothing could show through them, and the large title stayed pinned at the top. Now,
  as in iOS 26:
  - Content scrolls under the bar. A **scroll edge effect**, a blur that fades the content out,
    keeps the buttons and title legible.
  - The large title scrolls away with the content, and the **inline title** fades in once it's
    gone. The large title stays the screen's heading for VoiceOver.
  - A gentler edge effect fades content under the floating tab bar.
  - With Reduce Transparency, the edge effects are solid, and the fade has no motion with Reduce
    Motion.

  Sheets keep their solid bars, because their content scrolls inside the sheet body, not under the
  bar.

**How it was checked:** in headless Chrome, My Day was scrolled in light, dark and Reduce
Transparency. A script confirmed that the inline title is hidden at the top and shown once the
large title is under the bar. Screenshots were checked by eye. The typography, contrast,
accessibility and axe-core audits, and the flow tests, were all re-run and still pass.

## Removed from mockup 3

- groups, All Reminders and No Group, and the group pages with their own search fields
- the New Group and Edit Group sheets, with their color swatches
- the group color tokens (`--g-*`) and the `square.stack`, `list.bullet` and `tray` symbols

## Open questions

- **Should My Day and the Tags tab share one filter?** They're separate now, so filtering My Day
  to `#work` doesn't change what the Tags tab shows.
- **Is All Tags the right default?** Choosing a second tag narrows the list, as it does in Mail and
  Reminders' smart lists. If people expect it to widen the list, Any Tag should be the default.
- **Tag colors.** Leaving them out keeps the color rules simple. If people need to tell tags apart
  at a glance, a fixed palette like the groups had could come back.

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

The mockup 3 audits for contrast, Dynamic Type sizes and axe-core haven't been re-run on the new
Tags tab controls.
