# Nudge-inator iOS mockup

Nudge-inator as an **iPhone app**. Reminders, nudging and history all live on the device: there's
no account, no server and no website. A reminder can have **any number of tags** (or none), and you
find reminders by **filtering on one or more tags**.

- **Early nudges** are **local notifications** with **Done** and **Snooze**. High urgency ones are
  **Time Sensitive**, so they get through Focus unless the person turns Time Sensitive off for the
  app. Normal ones are ordinary notifications, which a Focus holds until the reminder reaches High.
- **Urgent nudges** ring as **AlarmKit alarms** on iOS 26 and later: a prominent system alert on the
  Lock Screen, sounding through silent mode and Focus, with **Snooze** and the system's **Stop**,
  which counts as Done. iOS 18 has no AlarmKit, so there they repeat as a **chain of Time Sensitive
  notifications**, and so do they on iOS 26 and later when alarms aren't allowed. (With Time
  Sensitive off, these come as ordinary notifications; the rule is in
  [brief §4](../../product/brief.md#4-how-nudges-reach-you).)

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. On a desktop
it shows a phone with **Mockup controls** beside it, in portrait or landscape. On a phone the app
fills the screen and the controls are below it.

**iOS versions.** The app supports iOS 18, 26 and 27 on iPhone, and the **iOS version** mockup
control shows each one (see [iOS versions](#ios-versions)). The mockup draws only what the app can
build with the system's own components and APIs on that version. Where it can't know how iOS draws
something, it says so and lists it to check on a device. iPad is for v2.

**Words.** A *nudge* is one alert sent while an occurrence is open: a notification or an alarm. A
reminder is *nudging* until you mark it done.

The [product brief](../../product/brief.md) is built on this mockup. It also covers what the mockup
doesn't show: iPad. The mockup illustrates the brief and the
[UX spines](../../design/EXPERIENCE.md). Precedence is set once, in the [brief's introduction](../../product/brief.md).

This version follows the UX review of 2026-10-02. The version before it is archived in
[`../archive/2026-09-30-mockup-tags-v1/`](../archive/2026-09-30-mockup-tags-v1/README.md).

**In the spines, not drawn here.** These are specified in
[EXPERIENCE.md](../../design/EXPERIENCE.md) and [DESIGN.md](../../design/DESIGN.md) but aren't in this
mockup yet. Build them from the spines:

- **Undo** in the Done status message (it runs Not Done)
- the **Done follow-up** notification after an alarm's Stop ("Marked done: … Not done yet?")
- **Not Done** on rows closed by an alarm's Stop, in Now and My Day
- the **urgency word** and glyph in the nudge card's top row
- **Got It** on permission banners
- **Settings › How Nudges Work**
- Assistive Access's **Done today** list with **Not done yet**
- the "Done with Siri" history line (the mockup doesn't simulate Siri)
- the one extra nudge after Not Done on an occurrence that had used its give-up limit (Done only,
  no Snooze); no sample occurrence reaches its limit before Not Done
- the alarm permission prompt on the first launch after an update from iOS 18 (the mockup doesn't
  simulate an OS update)
- the **keep-nudging** notice
- the alarm-limit Via label, "Notification: too many alarms scheduled"

## Product rules

These follow the nudging rules in the [product brief](../../product/brief.md#3-product-concepts),
including the ones decided on 2026-10-02.

- **Strengths:** Gentle, Firm and Relentless, each with its own intervals and urgency ladder.
- **Give-up limit:** 20 nudges or 24 hours by default, whichever comes first. Quiet hours and
  snoozed time don't count toward the time.
  - Each strength has a smallest limit, so the limit can't end an occurrence before its first High
    nudge: Gentle 5 nudges or 3 hours, Firm 3 nudges or 1 hour, Relentless 1 nudge or 15 minutes.
  - The stepper and the time menu stop at the minimum. Choosing a gentler strength raises a lower
    limit to its minimum.
- **One open occurrence per reminder.** When the next one falls due while the last is still
  nudging, the last closes as missed ("Missed: the next one took over") and the new one starts at
  nudge 1. How It Nudges shows where that happens for a repeat ("Next one due at +4 h").
- **Quiet hours stop the clock** for every open occurrence, as Snooze does: nothing is sent,
  nothing escalates, no alarms ring, and the time doesn't count toward the give-up limit. When they
  end, the next nudge comes at once (1 nudge, not a backlog). Start and end can't be the same time.
  A reminder with **Ignore Quiet Hours** on nudges through them.
- **Carry-over** ("↑ Starts higher"): after a missed occurrence, the next one that nudges sends its
  Normal nudges at High, so they get through a Focus. Its intervals, and when it reaches Urgent,
  don't change, so Relentless, which starts at High, has none. It doesn't stack. Skipped
  occurrences neither use it nor clear it, and pausing clears it.
- **Editing:** every repeat rule can be shown and edited in the form. While a reminder
  is nudging, the form says when each change applies (see [Screens](#screens)).
- **Privacy:** notifications show the title and the nudge count and urgency ("Nudge 3 of 20 ·
  High"), and alarms only the title. The alarm shows the app's name; a notification shows the app's
  icon, and its name only when previews are hidden. Notes and tags stay in the app.

The made-up data shows carry-over on "Stretch break" (Firm, 1 hour limit), whose 4 PM occurrence
yesterday was missed.

**Not shown,** because the mockup's clock doesn't move: an occurrence being taken over, a nudge
sent when quiet hours end, which nudges get the system's notification and alarm slots, the "Open
Nudge-inator to keep nudging" notification.

## Screens

The app uses standard iOS layouts: a tab bar, large titles, inset grouped lists, modal sheets,
alerts and confirmation dialogs. As on iOS, screens and sheets scroll without showing a scrollbar.

On iOS 26 and 27 the bars follow Liquid Glass (see [Materials](#materials)):

- The **tab bar** is a glass capsule that floats above the content. The selected tab sits in a
  lighter pill, in the TabView's tint, which is the accent. **Search** is a separate glass circle at
  the trailing end, as iOS 26 does for a tab with the search role.
- **Bar buttons** are glass capsules when they hold words (**Edit**, **Clear**) or glass circles
  when they hold only a symbol (**+**, and Back, which shows just the chevron). They use the label
  color.
  - Sheets use symbols, as iOS 26 does for SwiftUI's `.cancel` and `.confirm` button roles: an
    `xmark` circle to cancel, and a `checkmark` circle tinted with the accent color to confirm
    (**Add**, **Save**, **Done**). Each symbol keeps its word as its accessibility label.
  - **Edit** stays a word, because Apple's toolbar guidance names it as an action that symbols
    don't represent well.

On iOS 18 the same components look as iOS 18 draws them (see [iOS versions](#ios-versions)): a
full-width tab bar with Search as a fifth tab, bar buttons as words or symbols in the accent color,
and **Cancel**, **Add**, **Save** and **Done** as words.

| Tab | SF Symbol | What it shows |
|---|---|---|
| **Now** | `bell` | Nudging cards with **Done** and **Snooze**, Coming Up (7 days), Last 24 Hours |
| **My Day** | `calendar` | Today in time order, with Now and quiet-hours markers. Done, Nudging, Missed and Left counts that filter the list, and a tag filter. |
| **Tags** | `tag` | Your tags with counts. Choose one or more to filter, then see the matching reminders in Today, Later, Paused and Completed sections. |
| **Settings** | `gearshape` | Nudges (permission status, Send a Test Nudge), Quiet Hours, Siri & Shortcuts, Your Data (Export Data, a readable record rather than a backup, and Delete All Data), About |
| **Search** | `magnifyingglass` | Every reminder, found by title, notes or tag, in Today, Later, Paused and Completed sections |

- **Search:** on iOS 26, choosing the Search circle turns the tab bar into a search field, with the
  tab you came from shrunk to a circle in front of it. Tap that circle to go back. On iOS 18, Search
  is an ordinary tab, with its field under the title and **Cancel** beside it while it's focused.
  - Before you type, it shows an empty state that says what you can search. Once you've opened a
    result, it shows **Recent Searches** (up to five) with **Clear**.
  - When a reminder matches only in its notes, the row shows the words around the match. A leading
    `#` is ignored, so "#health" finds that tag.
  - With no matches it says **No Results for "…"**, as iOS apps do.
- **New reminder:** the **+** button in the navigation bar opens a sheet with **Cancel** (`xmark`)
  and **Add** (`checkmark`).
  - The **Title** wraps onto more lines as you type. Return doesn't add a line.
  - **Tags** opens a page with a **New Tag** field and a checklist of your tags.
  - **Repeat** opens a picker page: Never, Every Day, Every Weekday, Every Week, Every 2 Weeks,
    Every Month, Every Year, or Custom (frequency, interval, weekdays, and one or more times of
    day, so a reminder can repeat several times a day).
  - **Snooze Length** is a menu under Strength: the strength's default, or a longer 5, 10, 15 or
    30 minutes. Choosing a gentler strength raises a shorter length to its default.
  - **Strength** is a segmented control. At the accessibility sizes it's a menu instead (see
    [Typography](#typography)), as are Custom's **Frequency** and the tag filters' **Match**.
  - **Give Up** uses a stepper for the number of nudges and a menu for the time, neither going
    below the strength's minimum. The footer says what the minimum is and why.
  - **Ignore Quiet Hours** is a switch, for medication or caregiving reminders that must nudge at
    night.
  - **How It Nudges** previews every nudge: when it comes, its urgency, and whether it's a
    notification or an alarm. For a repeat whose next occurrence falls due first, the last row says
    **Next one due** and that it takes over. After a miss, the footer says the Normal nudges come at
    High.
  - **Edit** on a reminder that's nudging says when each change applies: a new schedule from the
    next time it's due, a new strength, give-up limit or Ignore Quiet Hours from the next nudge, with
    the nudge count carrying on. In the two cases where saving closes the occurrence as **skipped**
    ([brief §3](../../product/brief.md#3-product-concepts), Edit), it warns ("Skipped: the
    reminder was changed"). The time counted toward the limit leaves out quiet hours, snoozes and
    any time it was closed before Not Done.
- **Rows that open a reminder show a chevron** (`chevron.right`), on Now, My Day, Tags, Search and
  the details' history, as a `NavigationLink` in a `List` does. My Day's rows keep their **Done**
  button beside the chevron (`.buttonStyle(.borderless)`, so it does its own action). Nudge cards
  have no chevron: tapping one opens the reminder through a button, because a chevron looks out of
  place on a card.
- **Reminder details** are pushed onto the tab's navigation stack. They show the nudging card, the
  reminder's tags, the schedule (with whether it waits for quiet hours), How It Nudges, the history
  (kept 90 days), **Not Done**, **Pause** or **Resume**, and **Delete**, which asks for
  confirmation in a confirmation dialog. **Edit** is in the navigation bar.
  - On iOS 26 the dialog grows out of the button that opened it, and has no **Cancel** button:
    tapping outside it cancels. Apple's WWDC25 session "Build a UIKit app with the new design"
    confirms this: "Action sheets presented inline don't have a cancel button because the cancel
    action is implicit by tapping anywhere else." It holds only when the dialog is attached to its
    button; without a source, iOS 26 centers it and adds **Cancel**. On iOS 18 it's an action sheet
    at the bottom of the screen, with **Cancel**. Discarding a changed form asks the same way.
  - **Not Done** appears while it applies
    ([brief §3](../../product/brief.md#3-product-concepts), Not Done). It reopens that occurrence: the next nudge comes one interval later, at the next step, and
    the history records "Marked not done (nudging again)". The alarm's Stop counts as Done and
    can't be labelled, so this is how to take it back. Try it on "Walk the dog".
- **First launch:** a welcome screen, then the notification permission prompt, then, on iOS 26
  and later, the alarm permission prompt.
- **Swipe actions** on nudging rows and cards (Now and My Day): swipe left for **Done**, right for
  **Snooze** while snoozes are left. A swipe only shows the button, and a tap does the action:
  there's no full swipe, so a stray swipe can't mark a reminder done. They're shortcuts for the
  buttons the row already has (see [Accessibility](#accessibility)).

## Tags

**What a tag is:**
- **A name, nothing else.** It's one word, shown as `#home`; typing "dog walks" gives `#dog-walks`.
  The naming rules are in [brief §3](../../product/brief.md#3-product-concepts) (Tag name).
- **No color.** Tags are all the same neutral gray, so they never compete with the status colors
  (see [Color](#color)).
- **Names are unique**, ignoring case. Adding `Home` when `#home` exists reuses `#home`.
- **Stays in the app.** Like notes, tags are never shown in notifications or alarms.

The made-up data has seven tags: `#appointments`, `#health`, `#home`, `#money`, `#morning`,
`#travel` and `#work`. Most reminders have two. "Call Grandma" has none.

**Filtering on the Tags tab:**
- **The search field holds the chosen tags.** It's SwiftUI's `searchable(text:tokens:suggestedTokens:)`,
  placed under the title with `.navigationBarDrawer(displayMode: .always)`, so it sits in the same
  place on iOS 18 and 26. Apple recommends this placement for a search scoped to one tab, alongside
  a Search tab (WWDC26, "Design intuitive search experiences", with Apple Music's library as the
  example).
- **Cancel** shows beside the field while it's focused, as on every iOS search field. It clears the
  typed text and ends the search, and keeps the tokens. Whether `searchable` keeps the tokens on
  Cancel is to be confirmed on a device; if it doesn't, the app keeps the chosen tags itself.
- **Choose tags.** Typing suggests matching tags. Tap one, or press Return to take the first match,
  and it becomes a **token** inside the field.
- **Remove tags** the way a search field's tokens are removed: tap a token to select it, then press
  Delete. In an empty field, Delete selects the last token, and a second Delete removes it. The
  field's clear button (`xmark.circle.fill`) removes the text and every token. That the clear button
  also removes tokens is to be confirmed on a device.
- **Tokens are the system's**, so their size and look are too. The mockup's are an approximation.
- **The tags stay visible.** Under the results, **Add a Tag** lists the tags not chosen yet, so
  adding one doesn't depend on typing. Apple warns that tokens "can also be less discoverable. So
  don't use them to replace more visible filtering UI" (the same WWDC26 session).
- **Match All Tags or Any Tag.** Once two or more tags are chosen, a segmented control appears.
  **All Tags** is the default and shows reminders that have every chosen tag. **Any Tag** shows
  reminders with at least one.
- **The result** says what it's showing, for example "1 reminder with #home and #morning" or
  "7 reminders with #home or #morning". In each row the chosen tags are in bold.
- **No matches** says why. With All Tags, it suggests Any Tag or removing a tag.
- **The filter stays.** It's still there after you open a reminder and come back.

**Before you choose any tags,** the tab lists every tag. Each row shows how many reminders have
that tag, how many are due today, and how many are nudging (in red). The footer says how many
reminders have no tags. Tapping a row adds that tag as a token.

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
    #morning"). **Clear** resets the filter, and **Done** (`checkmark`) closes the sheet.

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
| Normal urgency | Notification (a Focus holds it) | **Done**, **Snooze** (while snoozes are left) |
| High urgency | Time Sensitive notification (gets through Focus). | as above |
| Urgent (Firm and Relentless, from nudge 4), iOS 26 and later | AlarmKit alarm | **Stop** (counts as Done), **Snooze** (while snoozes are left) |
| Urgent, with alarms not allowed | Notification chain, as on iOS 18, marked "Notification chain: alarms are off" | **Done**, **Snooze** |
| Urgent, past the system's alarm limit | Time Sensitive notification, marked "Notification: too many alarms scheduled" (the spine's wording; not drawn in this mockup) | **Done**, **Snooze** |
| Urgent, iOS 18 | Notification chain: each time the occurrence enters Urgent, a Time Sensitive notification at once and then every minute, 10 in all, marked "Notification chain" | **Done**, **Snooze** |

- **There's no Dismiss action.** The system's own **Clear** (swipe left on a notification) already
  does that. The app hears about it through its notification category's `customDismissAction`
  option, and the history records "Notification cleared (still nudging)". Flicking a banner away
  doesn't tell the app, so that isn't recorded. The mockup's Lock Screen has **Clear**, and its
  banners have **Flick it away** to show the difference.
- **The notification looks as iOS 15 and later draw it:** the app's icon, the title in bold beside
  the time, and the body under them. "Time Sensitive" heads High and Urgent nudges. There's no row
  with the app's name in capitals: with a title, the icon says which app it is. The layout is an
  approximation, to compare with a screenshot from a device.
- **On iOS 18, Urgent nudges come as a chain.** Each time an occurrence enters Urgent ([brief §4](../../product/brief.md#4-how-nudges-reach-you)
  lists when), a Time Sensitive
  notification comes at once and then every minute, 10 in all, until **Done** or **Snooze**. The strength's
  Urgent nudges inside a chain still count, but aren't sent separately (brief §4). Silent mode can mute
  them. There's no alarm permission, no Alarms row in Settings, and onboarding says "Urgent nudges
  keep coming" instead of "ring as alarms".

- **Gentle** reminders never reach Urgent, so they never ring an alarm.
- **Normal nudges aren't Time Sensitive,** so the app doesn't wear out the person's trust in its
  Time Sensitive notifications: turning those off would let a Focus hold High nudges too. During a
  Focus, a Gentle or Firm reminder's first nudges wait until it reaches High. People who want every
  nudge can allow Nudge-inator in that Focus. How It Nudges and Settings say so.
- **The notification's header** says "Time Sensitive" only for High and Urgent nudges. Normal
  nudges and the test nudge are ordinary notifications.
- **If Time Sensitive is turned off** for the app (the **Time Sensitive allowed** mockup control),
  Now and Settings show a banner, the Notifications row in Settings says "On · Time Sensitive off",
  and High nudges are marked "Notification: Time Sensitive is off". How It Nudges says that during a
  Focus every notification waits.
- **Done** is the only way to close an occurrence as done. The give-up limit, the next
  occurrence, Pause, Delete and some edits also stop the nudging, and quiet hours hold it. However
  an occurrence closes, nothing more is sent for it, and its pending notifications and alarms are
  cancelled the next time the app runs (no app code runs when a nudge arrives).
- **Weaker fallbacks show.** With alarms off, nudging cards and How It Nudges mark each Urgent
  nudge as "Notification chain: alarms are off" ("alarms and Time Sensitive are off" if both are), and
  the New Reminder summary says how Urgent nudges come instead.
- **Snooze** waits the reminder's snooze length. It starts at the strength's default (Gentle 30
  minutes, Firm 15, Relentless 5), and the form's **Snooze Length** menu can make it longer (5, 10,
  15 or 30 minutes, where that's longer than the default). Pay rent in the made-up data snoozes for
  15 minutes, though it's Relentless.
  - It doesn't raise the level, and the snoozed time doesn't count toward the time limit.
  - Each occurrence can be snoozed 3 times. Then Snooze disappears from the card, the notification
    and the alarm, and the card says "No snoozes left. Only Done stops it."
- **Clear** clears only the notification. The next nudge still comes on time.
- If **alarms** are turned off in iOS Settings, Now and Settings show a banner, and Urgent nudges come
  as a notification chain, which silent mode can mute. If **notifications** are off, a red banner says
  that only Urgent nudges can reach you, as alarms (or that nothing can, if alarms are off too).
  Nudging cards and How It Nudges mark each nudge that can't arrive as **Notifications off**, with
  `bell.slash`, in red.
  The two permissions are separate, so the alarm prompt comes after the notification prompt
  whatever the person chose. That alarms still ring with notifications off is to be confirmed on a
  device.
- **The alarm is AlarmKit's system alert.** On a locked iPhone, iOS draws it over the Lock Screen,
  under the Lock Screen clock, with the app's name above the title. On an iPhone that's in use, it
  appears over the app, in the Dynamic Island (see [Landscape](#landscape)). It also appears in
  StandBy and on a paired Apple Watch. The app supplies only:
  - the title: the reminder's title
  - the secondary button: **Snooze 15 min** (the reminder's snooze length) with `clock`, filled with the
    tint color. It's left off once the occurrence has no snoozes left (see below).
  - the tint color: the app's accent, in its dark variant (`#07DDE6`, with black text), since the
    alarm is always on a dark screen

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
  from it. On the third snooze, once its snooze intent has run, the app cancels that alarm and schedules a new one
  for the end of the snooze, without Snooze. Each snooze also moves the occurrence's later alarms,
  so none ring during the snooze.

**Pausing:**
- **Pause Reminder** stops the nudging. An occurrence that's nudging closes as **Skipped**, not
  missed.
- Anything due while the reminder is paused is skipped too, so there's no carry-over from a pause,
  and pausing clears any carry-over there was.
- **Resume** picks up at the next time in the future. A one-off reminder whose time passed while it
  was paused asks for a new time.

## Mockup controls

These are not part of the app:

- **Next early nudge** shows the Lock Screen with a notification for the next nudging
  reminder whose next nudge isn't Urgent. In landscape the iPhone is in use, so it arrives as a banner
  over the app instead (see [Landscape](#landscape)). Tap it to see its actions, which on an iPhone come from a
  long press. It sends a real nudge in the mockup, so the card and history update.
- **Next Urgent nudge** shows the alarm for the next reminder whose next nudge is Urgent. In landscape
  it rings over the app, as it does on an iPhone that's in use. **Snooze**
  shows the Live Activity, and **Unlock** returns to the app. Press it several times to use up the
  snoozes and see the alarm with only **Stop**. On iOS 18 it shows the first notification of the
  chain instead.
- **First launch** shows onboarding and the permission prompts.
- **iOS version** switches between iOS 18, 26 and 27 (see [iOS versions](#ios-versions)).
- **Screen size** switches the phone between the screen sizes, in points, of the iPhones that run
  the chosen iOS version, from iPhone SE (375 × 667) to the Pro Max models (440 × 956). Each size
  names only the iPhones that run that version, from Apple's lists of iPhones compatible with
  [iOS 26](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/26/ios/26)
  and [iOS 27](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-27-iphe3fa5df43/ios):
  - iOS 18 adds the iPhone XS, XS Max and XR, which stop at iOS 18, and leaves out the iPhones that
    shipped with iOS 26 or later. So the iPhone Air (420 × 912) isn't there.
  - iOS 26 adds the iPhone 17, 17 Pro, 17 Pro Max, Air and 17e.
  - iOS 27 adds the iPhone 18 Pro and 18 Pro Max. It runs on every iPhone that iOS 26 does.
  - Switching to a version that no iPhone of the current size runs moves to the nearest size, and
    the note under the control says so.
  - The 17e and 18 Pro Max sizes come from Apple's pixel resolutions at 3×; the 18 Pro is assumed to
    match the 17 Pro (402 × 874). The **iPhone Duo**, a foldable, is left out because its sizes in
    points aren't published. It's treated like any iPhone (see the
    [brief, §5 and §10](../../product/brief.md#10-risks-and-decisions), and
    [EXPERIENCE.md › Responsive & Platform](../../design/EXPERIENCE.md)).

  The top of the screen matches each one: the Dynamic Island, a notch, or a Home button. The phone
  is scaled down, never up, to fit the window.
- **Window (iOS 27)** shows the app in a resizable window, as in iPhone Mirroring or as an iPhone
  app on iPad, at any width from 320 to 1,024 pt (see [iOS versions](#ios-versions)). The window is
  drawn at one scale at every width, with room kept for the widest, so dragging the width moves only
  its right edge. Ticks mark 375 and 440 pt (the smallest and largest iPhones), 540 pt (wide nudge
  cards) and 700 pt (sheets as a centered card). The label under it gives the exact size.
- **The controls scroll on their own** beside the phone, so the phone stays in view while they're
  used.
- **Orientation** turns the phone between **Portrait** and **Landscape** (see
  [Landscape](#landscape)). The screen you're on stays open. On a phone it's turned off, because
  the app fills the real screen.
- **Permissions** (notifications, alarms and Time Sensitive), **24-Hour Time**, **Appearance**, **Text Size** (all 12 Dynamic Type sizes),
  **Bold Text**, **Increase Contrast**, **Reduce Transparency** and **Assistive Access** stand in
  for iOS Settings. **Alarms allowed** is off on iOS 18, which has no AlarmKit.
- **Reset the mockup** restores the data.

The clock is fixed at Monday 28 Sep 2026, 8:20 AM. A snooze pushes the next nudge later, but the
clock doesn't move.

## iOS versions

The app supports iOS 18 and later. It uses the system's own components (`TabView`, `NavigationStack`, `List`, sheets, `confirmationDialog`, `searchable`), so
each version draws them its own way. The **iOS version** mockup control shows the differences.

| | iOS 18 | iOS 26 | iOS 27 |
|---|---|---|---|
| Bars, tab bar and sheets | iOS 18's own: a full-width tab bar with Search as a fifth tab, a navigation bar that takes the bar material once content is under it, solid sheet bars | Liquid Glass: a floating tab bar with a Search circle, glass bar buttons, scroll edge effects, sheet bars with no background | As iOS 26 |
| Sheet buttons | **Cancel**, **Add**, **Save**, **Done** as words | `xmark` and `checkmark` circles (the `.cancel` and `.confirm` roles) | As iOS 26 |
| Back | Chevron and the previous title | Chevron only, in a glass circle | As iOS 26 |
| Section headers | Capitals | Title case | Title case |
| Confirming a delete | Action sheet at the bottom, with **Cancel** | Dialog that grows out of its button, no **Cancel** | As iOS 26 |
| Urgent nudges | Notification chain | AlarmKit alarm (the chain if alarms aren't allowed) | As iOS 26 |
| Alarm permission, Alarms row in Settings | None | Yes | Yes |
| Landscape | Full tab bar; My Day's date in the content | Shrinking tab bar; My Day's date as a subtitle | As iOS 26 |
| Resizable window | No | No | Yes (mockup control) |

- **Unselected tabs on iOS 18** use the secondary label color, set with `UITabBarAppearance` on
  iOS 18 only. iOS 18's default gray is about 3:1. On iOS 26 the app leaves the tab bar's
  appearance alone, because custom bar appearances interfere with Liquid Glass.
- **iOS 27's resizable window.** On iOS 27 an iPhone app can be resized, in iPhone Mirroring or as
  an iPhone app on iPad. The layout follows the window's width, never the iPhone model: content
  keeps a readable width (about 672 pt at Large), a nudge card 540 pt or wider puts **Done** and
  **Snooze** beside its text, and the app stays one column. In a window 700 pt or wider, sheets are
  a centered card. How iOS 27 places the tab bar and sheets in a window is an approximation.
- **Also new in iOS 27, and not used:** a navigation bar that hides while you scroll
  (`toolbarMinimizeBehavior`), swipe actions outside `List` (the app's swipe actions are on `List`
  rows, which work from iOS 15), and the Liquid Glass tint setting, which the system applies to the
  app's glass without any code.
- **Confirmed in Apple's documentation:** iOS 26's confirmation dialog has no **Cancel** when it's
  attached to its button (WWDC25, "Build a UIKit app with the new design"); the Tags field's place
  under the title, and **Cancel** beside a focused search field (WWDC26, "Design intuitive search
  experiences"); and that iOS 18's unselected tab color can be set (`UITabBarItemAppearance.normal`).
- **To check on a device,** because the documentation doesn't say: each version's bars and sheets
  against the mockup; that the search field's clear button removes tokens, and that Cancel keeps
  them; what iOS 26's Search tab shows to end a search; the notification's layout; the selected
  tab's contrast; and iOS 26's alerts, which the mockup draws in the iOS 18 style on every version.

## Landscape

Landscape follows Apple's Human Interface Guidelines page on
[Layout](https://developer.apple.com/design/human-interface-guidelines/layout) and what iOS 26 does
on an iPhone in compact height. The phone turns to the left, so the Dynamic Island or notch is on
the left, and the iPhone SE's Home button is on the right.

- **No status bar.** iOS hides it in landscape.
- **Safe areas.** Backgrounds and scrolling content run to the screen's edges, but text and
  controls stay inside the safe areas. The insets are about 44 to 62 pt on each side, depending on
  the model (0 on the iPhone SE). They clear the Dynamic Island or notch, and are the same on the
  other side.
- **A readable width.** Content is centered at UIKit's readable width (about 672 pt at the default
  text size). It grows with Dynamic Type, so at the accessibility sizes content fills the space
  between the safe areas.
- **Inline titles.** Large titles collapse into the navigation bar, which keeps its glass buttons
  at the edges of the safe area. The inline title is the screen's heading for VoiceOver.
- **A compact tab bar.** It's still a floating glass capsule at the bottom, sized to its tabs and
  centered, with each symbol beside its title (`compactInline`). Search is a glass circle beside
  it, and on the Search tab the field takes the free width, up to 480 pt.
- **The tab bar shrinks while you scroll down** on iOS 26 and later
  (`tabBarMinimizeBehavior(.onScrollDown)`), to give back about 50 pt of height. iOS 18 keeps its
  full tab bar, with each symbol beside its title. Only the current tab stays, as a glass circle at the leading
  edge, with Search at the trailing edge. Scrolling up, or tapping the current tab, brings it back,
  and keyboard focus does too. Search doesn't shrink, because it holds the search field. Portrait
  is unchanged.
- **My Day's header is shorter** on iOS 26 and later. The date becomes a subtitle under the inline
  title (`navigationSubtitle`), and **Filter** becomes a glass button in the navigation bar. On
  iOS 18, which has no `navigationSubtitle`, the date and Filter stay in the content. While the
  filter is on, the button shows how many tags are chosen, in the accent color. The four counts
  become a row of capsules, still with the chosen count's fill and ring, and two columns at the
  accessibility sizes. Together these show about two more reminders.
- **Wide nudge cards put Done and Snooze beside the text.** This depends on the card's width
  (540 pt or more), not on the orientation, so a card in a narrow column stays stacked. At the
  accessibility sizes it always stacks. A card is about 60 pt shorter this way.
- **One column on every iPhone.** There's no split view in v1, even on the larger iPhones that are
  regular width in landscape: the app uses `NavigationStack`, not `NavigationSplitView`, so it
  stays one column in landscape and in a wide iOS 27 window too. A split view comes with iPad, in
  v2 (see the [addendum](../../product/addendum.md)). The previous mockup's split view is in the
  [archive](../archive/2026-09-30-mockup-tags-v1/README.md#landscape).
- **Sheets fill the screen,** as page sheets do in compact height, and their content keeps the
  readable width. Alerts stay centered and scroll if they're taller than the screen. On iOS 26,
  confirmation dialogs grow out of their button, as in portrait. On iOS 18, action sheets keep
  their portrait width, centered at the bottom.
- **Nudges arrive over the app.** Someone using the app in landscape has the iPhone unlocked, so
  nudges don't appear on the Lock Screen:
  - **The alarm** is AlarmKit's alert as iOS shows it while the iPhone is in use. In portrait that's
    the Dynamic Island. In landscape the island is at the side, so the mockup shows the same alert
    as a black banner at the top center. It has the same parts as on the Lock Screen: the app's
    name, the title, **Snooze** (while snoozes are left, filled with the tint color) and the
    system's **Stop**. Snooze returns to the app, and the nudge card says when it rings again.
    Where and how iOS draws this alert in landscape is an approximation, still to confirm on a
    device.
  - **The notification** is a banner at the top center. Tap it to see **Done** and
    **Snooze**, which on an iPhone come from a long press. **Flick it away** hides the banner
    without telling the app.
  - The banners are about as wide as the screen in portrait. At the accessibility sizes the alarm
    scrolls rather than clip.
  - The Lock Screen itself doesn't rotate on an iPhone, so it's shown only in portrait.
- **Everything else is unchanged:** the colors, text styles, materials, 44 pt targets and the
  layouts for accessibility sizes.

**How it was checked** (before the 2026-10-02 UX review; see [How it was checked](#how-it-was-checked)
for what was checked after it): in headless Chrome, in landscape on the iPhone SE, a notched iPhone
and two Dynamic Island sizes:
- Now, My Day, Tags (browsing and filtered), Search with results, New Reminder, reminder details,
  the Delete action sheet, and My Day at AX3
- every button, heading and list on those screens is inside the safe areas, and nothing scrolls
  sideways
- the alarm and the notification arrive as banners over the app, and stay in landscape
- Portrait looks the same as before
- the console has no errors

Then against the six local HIG pages in `docs/apple/design`, on Now, My Day, Tags (browsing and
filtered), Settings, reminder details, New Reminder and Filter My Day:
- at Large and AX5, each with Bold Text off and on: no text is clipped or cut off with "…", navigation
  bar items don't overlap, and every enabled button is at least 44 pt tall (a reminder's title is
  covered by its row, which is the target)
- in all 8 combinations of light and dark, Increase Contrast and Reduce Transparency, screenshots
  were checked by eye: the glass, scroll edge effects and full-screen sheets follow each setting as
  in portrait
- the tab bar's glass shapes are 10 pt apart, as in portrait

The shrinking tab bar, My Day's header and the wide nudge cards were then checked on a 393 pt and
a 440 pt iPhone:
- the tab bar shrinks on scrolling down and comes back on scrolling up or tapping its tab
- the alarm banner's Snooze and Stop, with Snooze gone after the third snooze, and the test nudge's
  Close; portrait still shows the Lock Screen
- the size audit above, repeated on both iPhones: no clipped text, no overlapping bar items, and
  buttons at least 44 pt
- the console has no errors

## Icons

Icons follow Apple's Human Interface Guidelines page on
[Icons](https://developer.apple.com/design/human-interface-guidelines/icons) (a local copy is in
`docs/apple/design/`). A web page can't use SF Symbols, so each icon is drawn to match the SF Symbol
it names. The real app uses the symbols themselves.

- **Standard actions use the standard symbols** from the page's table:

  | Action | Symbol |
  |---|---|
  | Done | `checkmark` |
  | Cancel (iOS 26 sheets), remove a tag from My Day's filter | `xmark` |
  | Delete | `trash` |
  | New reminder, add a tag to the filter | `plus` |
  | Filter | `line.3.horizontal.decrease` |
  | Search | `magnifyingglass` |
  | Export Data | `square.and.arrow.up` |
  | Alarms | `alarm` |
  | My Day | `calendar` |

- **Other icons use the nearest SF Symbol:** `xmark.circle.fill` for the search field's clear
  button; `bell`, `tag` and `gearshape` for tabs;
  `chevron.backward` and `chevron.right`; `moon.fill` for quiet hours and `arrow.up` for "starts
  higher"; `arrow.uturn.backward` for Not Done; `pause`, `play` and `clock`; `bell.slash` for a nudge that can't arrive because
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
- **Text labels.** Every icon-only button has one ("New Reminder", "Delete #home", "Clear"). The +
  on a tag row reads "add to filter". Decorative icons, such as tag tiles, are hidden from screen readers.

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
  | Title 3 | 20 pt | Section title "Nudging" (semibold), iOS 18's action sheet buttons, steppers, Lock Screen date |
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
  - Segmented controls (Strength, Frequency, Match) become menus: a row with the label and the
    chosen option, as SwiftUI's `Picker` with the `.menu` style. A segmented control stays on one
    line and would cut off "Relentless", and iOS has no segmented control that stacks its options.
    The app switches when `dynamicTypeSize.isAccessibilitySize` is true.
  - History events wrap under their time.
  - The day's four counts become two columns.
  - Text wraps; nothing is cut off with "…". The reminder **Title** field wraps onto more lines.
- **Fixed-size system elements.** The tab bar, inline navigation titles (and their subtitles) and bar buttons keep their
  default size (17 pt) at every text size, so they never crowd each other. People use the Large
  Content Viewer instead. Large titles are content and scale. The status bar, Lock Screen clock and
  alarm clock are fixed too.
- **Short placeholders.** The Tags tab's field says "Find a tag", which fits at AX3. Once it holds
  tokens it has no placeholder.

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
| `--accent` | teal (Lagoon) | You can tap this | Buttons, links, the selected tab, menus, checkmarks, tokens, the chosen count's ring |
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
**Done** buttons are tinted instead of filled, so a long list isn't a column of teal.

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
- The accent is the app's own color set, **Lagoon** teal, with light, dark and Increased Contrast
  values. It replaced a system-like blue on 2026-10-03 (see the
  [design spine](../../design/DESIGN.md#colors) and its
  [color study](../../design/.working/color-themes-1.html)): the blue fell short on the selected
  tab's pill, and white text on its dark fill reached only 2.8:1.
- **The selected tab's title is the accent.** On iOS 26 the system draws the selected tab from the
  TabView's tint, and the app can't color its label on its own: a different tint on the TabView
  would carry into every screen. So the mockup uses the accent, as the app will. Measured on the
  mockup's pill, which approximates the system's:

  | Appearance | Accent | On the pill | Target |
  |---|---|---|---|
  | Light | `#04666B` | 5.4:1 | 4.5:1 |
  | Light, Increase Contrast | `#04474A` | 7.4:1 | 7:1 |
  | Dark | `#07DDE6` | 6.5:1 | 4.5:1 |
  | Dark, Increase Contrast | `#A5FAFE` | 7.2:1 | 7:1 |

  All four pass on the mockup's pill, as measured in the color study. The system's pill may
  differ, so this is still to measure on a device. Text on a filled accent button is white in light
  mode and black in dark mode.
- **Search tokens** sit on their own fill (`--token-fill`: white, or near-black in dark mode), which
  keeps their accent text at 4.5:1 or more. A selected token is filled with the accent.
- **Swipe actions** use tile colors, which keep white text at 4.5:1: green (`--tile-green`) for
  **Done**, the color of done, and teal (`--tile-teal`) for **Snooze**, the tile nearest the
  Lagoon accent, the color of something tappable.

**Not color alone.** Every status has words as well as a color, such as "Nudging", "Urgent",
"Missed" and "Done". Strength shows its name and bars. The chosen count has a fill, a ring and
`aria-pressed`, and "Showing only Left" says it in words.

**How it was checked** (before the 2026-10-02 UX review; see [How it was checked](#how-it-was-checked)
for after it): in headless Chrome, on the same 17 screens, in all 8 combinations of light and dark,
Increase Contrast and Reduce Transparency:
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
local copy is in `docs/apple/design/`), and WCAG 2.2 AA (the target set in
[EXPERIENCE.md](../../design/EXPERIENCE.md)):

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
- Nudges vibrate when the iPhone's settings allow it, and the alarm and notifications are visual,
  so nothing relies on hearing it.

**Mobility**
- **Target size.** Buttons are at least 44 pt tall, apart from the iOS switch, stepper, segmented
  control and menus, which are at least 28 pt and sit in 44 pt rows. A reminder's row or card is its
  tap target, and its Done button keeps its own action. The system's own small controls keep their
  sizes: search tokens, the search field's clear button, and iOS 18's tab bar in landscape (32 pt).
- **Spacing.** Controls with a visible shape are 12 pt apart, such as Done and Snooze on nudge
  cards, tokens, and Rename and Delete in Edit mode.
- **No gestures needed.** Every action is a button. Swipe actions on nudging rows and cards
  (**Done** and **Snooze**) are shortcuts for buttons the row already shows, so VoiceOver, Voice
  Control and the keyboard use those buttons. In the app, SwiftUI's `swipeActions` also appear in
  VoiceOver's Actions rotor.
- **Voice Control.** Every control's name includes its visible label ("Remove #home from the
  filter" on My Day, "Rename #home"). On the Tags tab, a token is removed by selecting it ("Tap
  #home") and then saying "Delete", or with the field's **Clear** button.
- **Siri and Shortcuts.** From the Action button, a Home Screen shortcut, or Siri. Apple requires
  every App Shortcut phrase to include the app's name, so the phrases are "Mark my Nudge-inator nudge
  done", "Snooze Nudge-inator" and "What's nudging me in Nudge-inator?"

**Speech**
- **Keyboard alone.** Every control can be reached with Tab and used with Enter or Space. Return
  chooses the first matching tag or adds a new one, Delete removes a selected token, Tab reaches a
  focused search field's **Cancel**, and Escape closes a sheet, alert or confirmation dialog.

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
- **axe-core** (WCAG 2.0, 2.1 and 2.2, A and AA) found no violations, in light and dark. Of the
  WCAG 2.2 additions, axe checks only 2.5.8 Target Size (Minimum); the rest (such as 2.4.11 Focus
  Not Obscured and 3.2.6 Consistent Help) can't be checked automatically and are covered by
  EXPERIENCE.md's device release gate.

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
    legible. The mockup draws it as a fade into the background, without the blur: a browser can't
    fade a blur in gradually, so it would start at a hard line. The app gets the system's effect. It shows only once content is under the bar: at rest, the first line below the bar
    (such as Now's date in landscape) stays sharp.
  - The large title scrolls away with the content, and the **inline title** fades in once it's
    gone. The large title stays the screen's heading for VoiceOver.
  - A gentler edge effect fades content under the floating tab bar, drawn the same way.
  - Sheets work the same way: their bar has no background, and the sheet's content scrolls under
    its glass buttons behind an edge effect. iOS 26 makes a full-height sheet opaque, so the edge
    effect fades into the sheet's own background.
  - On iOS 18 there's no glass: the navigation bar takes the bar material, with a hairline, once
    content is under it, and sheets have solid bars.
- **System materials stay system.** Alerts, action sheets and the Lock Screen notification keep
  their standard blurred materials. Full-height sheets are opaque, as iOS's large sheets are.
- **Accessibility settings.** Reduce Transparency makes every material, glass surface and edge
  effect solid. Increase Contrast gives glass a visible edge.

**How it was checked:** in headless Chrome, My Day was scrolled in light, dark and Reduce
Transparency. A script confirmed that the inline title is hidden at the top and shown once the
large title is under the bar, and screenshots were checked by eye.

## Decisions

The questions this mockup raised are settled in the
[product brief, §10](../../product/brief.md#10-risks-and-decisions):
- **Decided:** My Day and the Tags tab keep separate filters, My Day's counts filter one at a time,
  Match All Tags is the default, tags have no colors, and the tab bar shrinks only in landscape.
- **Decided on 2026-10-02, and shown here since:** carry-over sends Normal nudges at High, the next
  occurrence takes over, quiet hours stop the clock and a reminder can ignore them, give-up limits
  have a minimum per strength, changes while nudging apply from the next nudge, Not Done reopens a
  done occurrence, and Export Data is a readable record, not a backup.
- **Decided in the UX review of 2026-10-02, so the mockup shows only what the app can build on
  iOS 18, 26 and 27:**
  1. The mockup shows iOS 18, 26 and 27, with only the iPhones that run the chosen version.
  2. Each version's own look: title-case headers and dialogs from their button on iOS 26; capitals
     and bottom action sheets on iOS 18; sheet bars with no background on iOS 26.
  3. Menus instead of segmented controls at the accessibility sizes.
  4. The Tags tab's chosen tags are tokens in its search field.
  5. No Dismiss action on notifications: the system's Clear does that.
  6. Siri phrases include the app's name.
  7. Notifications drawn as iOS 15 and later draw them.
  8. Layout follows the width, not the iPhone model, ready for iOS 27's resizable windows.
  9. One column on every iPhone: the split view waits for iPad (v2).
  10. Swipe actions for Done and Snooze, as shortcuts.
  11. The selected tab uses the accent, as the system draws it.
- **Left to check on a device:** the navigation bars at large text sizes (the system's own
  behavior, as shown here), the selected tab's contrast on its pill (see [Color](#color)), reminders
  with many tags, and the items listed under [iOS versions](#ios-versions).

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

After Normal nudges became ordinary notifications, the longer text was checked in headless Chrome:
New Reminder's How It Nudges summary for each strength, and the Settings footer, on the iPhone SE
and the 440 pt iPhone, in portrait and landscape, at Large, AX3 and AX5, with Bold Text off and on
(96 checks). The text wraps with nothing clipped, cut off with "…" or scrolling sideways, and the
Focus sentence appears for Gentle and Firm but not Relentless. The console has no errors.

After the 2026-10-02 nudging rules, a script in headless Chrome checked them, and the console had
no errors:
- carry-over: "Starts higher" on Now, and Stretch break's How It Nudges starting at High; pausing
  clears it
- Not Done on "Walk the dog" reopens it, with the next nudge an hour later, and then disappears
- the Gentle form's time menu starts at 3 hours, and switching from Relentless to Gentle raises the
  limit to 5 nudges or 3 hours
- Ignore Quiet Hours saves, and removes the quiet-hours note from Coming Up
- lowering a nudging reminder's limit below its nudges warns, then closes it as skipped
- How It Nudges shows **Next one due** when a repeat's next occurrence comes first
- Settings refuses quiet hours that start and end at the same time, and says why
- with alarms off, Urgent nudges are marked "Notification: alarms are off" (since 2026-10-03,
  "Notification chain: alarms are off"; see below)
- the notification's header says "Time Sensitive" for a High nudge but not for a Normal one
- with Time Sensitive off: the banner on Now, the Settings row, High nudges marked "Notification:
  Time Sensitive is off", and the Focus sentence in How It Nudges
- a snooze is left out of the time counted toward the limit

The new text was then checked on the iPhone SE and the 440 pt iPhone, in portrait and landscape,
at Large, AX3 and AX5, with Bold Text off and on, on 8 screens (192 checks): details with carry-over,
Not Done and alarms off, Now, the form for a Gentle reminder, for a nudging reminder about to close
and for a takeover, and Settings with the quiet-hours error. Nothing is clipped, cut off with "…"
or scrolls sideways.

The typography, contrast, accessibility and materials checks above were run on the version before
the 2026-10-02 UX review, apart from the AlarmKit corrections, the Normal-nudge wording and the
2026-10-02 nudging rules, which were checked as described in the previous paragraphs.

**After the 2026-10-02 UX review,** these checks were run in headless Chrome on this version:
- **The nine steps above,** on iOS 18 and iOS 26, with the Tags tab's tokens in its field. All
  passed, and the console had no errors.
- **The new behavior,** with 31 assertions, all passing:
  - tokens: added by tap and by Return, selected by tap, removed with Delete, cleared with the
    clear button
  - iOS 18: the chain notification with Done and Snooze, recorded in the history; no Alarms row
    and no alarm prompt
  - Clear is recorded and a flicked banner isn't
  - the iOS 26 dialog shows only Delete and cancels on a tap outside it
  - swiping right snoozes, swiping left marks done, and taps still work after a swipe
  - Strength and Frequency are menus at AX2 and segmented at Large
  - the window works only on iOS 27
  - the Siri phrase includes the app's name
- **A layout audit,** 540 checks: iOS 18, 26 and 27; the iPhone SE and the 440 pt iPhone; portrait
  and landscape; Large and AX5; Bold Text off and on; ten screens (Now, My Day filtered, Tags with
  three tokens, Search, Settings, details, the form, Custom repeat, Filter My Day and the Delete
  dialog). Plus iOS 27 windows 320, 600 and 1,024 pt wide, at Large and AX5. Nothing sticks out past
  the screen, nothing is cut off with "…", navigation bar items don't overlap, and enabled buttons
  are at least 44 pt, apart from the system's small controls listed under
  [Accessibility](#accessibility).
- **axe-core 4.13** (WCAG 2.0, 2.1 and 2.2, A and AA) on nine screens (Now, My Day, Tags, Search,
  Settings, Reminder details, New Reminder, Welcome, Filter My Day), on iOS 18, 26 and 27, in light
  and dark, with Increase Contrast off and on, at Large and AX3: 216 runs, no violations. Re-run on
  2026-10-03 after the cross-doc review changes; a planted unlabeled button and image were flagged,
  so the runs do detect violations. The only automated WCAG 2.2 rule is 2.5.8 Target Size; the
  other 2.2 additions are covered by the device release gate (see [Accessibility](#accessibility)).
- **A contrast audit** of the same screens: all text reaches 4.5:1, or 7:1 with Increase Contrast,
  apart from the selected tab's title on iOS 26 and 27 with the earlier blue accent (see [Color](#color)). The Lagoon accent passes there in the color study; the full audit hasn't been re-run with it. The Lock Screen
  wasn't measured, because the audit skips text over gradients.
- **Cancel and the visible tag list,** 11 assertions, all passing: Cancel shows only while a field
  is focused, on the Tags tab and iOS 18's Search tab; it clears the text, keeps the tokens and ends
  focus; Tab reaches it and Enter presses it; **Add a Tag** lists the tags not chosen and adds them.
  At AX5 on the iPhone SE, Cancel wraps under the field and stays on screen. The nine steps, the 31
  assertions, the layout audit, axe-core and the contrast audit above were run again after this
  change, with the same results.
- **The Screen size list,** 11 assertions, all passing: each version lists only its iPhones (the
  XS, XS Max and XR on iOS 18 only; the 17 series, Air and 17e from iOS 26; the 18 Pro and 18 Pro
  Max on iOS 27; no Duo); the Air on iOS 18 moves to 414 × 896 and says why; a size that every
  version has stays put; and the choice survives a reload.
- **The edge effect at rest and the shrunk tab bar:** on iOS 18 and 26, on the iPhone SE, a 393 pt
  and a 440 pt iPhone, in portrait and landscape, the edge effect is off with the content at the
  top and on once it's scrolled; sheets in landscape leave 20 pt between the bar and the first row.
  The shrunk tab bar shows the current tab and the Search circle. The edge effects are a fade
  with no blur, so none of them starts at a hard line: checked by eye above the tab bar on the
  iPhone SE in landscape, where a card crosses it.
- **Screenshots checked by eye:** iOS 18's bars, tab bar (portrait and landscape), sheet and
  action sheet; iOS 26's dialogs growing from their buttons and its sheet bar; the notification and
  the iOS 18 chain; tokens; menus at AX3; a swipe; and windows 420 and 900 pt wide.

**After the architecture decisions of 2026-10-03,** these changes were checked in headless Chrome,
with no console errors:
- **Repeat** has no "Keep: …" option; on **Custom**, **Add a Time** adds a time, typing one updates
  the summary ("Every day at 9:00 AM, 12:00 PM and 3:30 PM"), and **Remove** takes it away
- Stretch break opens as Custom, every day at 10:00 AM, 2:00 PM and 4:00 PM, and My Day lists all
  three
- with alarms off on iOS 26, the banner says Urgent nudges come as a chain, and Urgent nudges are
  marked "Notification chain: alarms are off"
- **Snooze Length:** a new Firm reminder offers 15 and 30 min, starting at 15; a Relentless one
  offers 5, 10, 15 and 30 min; switching to Gentle raises the length to 30 min and says why; Pay
  rent (Relentless) snoozes for 15 min; and each nudge card's Snooze button shows its own
  reminder's length. The notification, alarm, Live Activity and history read the same length.
