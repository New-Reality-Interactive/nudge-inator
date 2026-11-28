# Reminders tab

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- **Search:** the system's search field (`searchable`), always shown under the navigation bar while
  there are reminders (the no-reminders empty state has none), with the prompt "Search titles and
  notes". The system draws its `magnifyingglass`, its clear button, and Cancel while it's focused
  or has text. Known difference, accepted (Brian, #113): on iOS 27.0
  the tab's first visit after a launch draws the title in its small inline form, with the list a
  little higher; a later visit draws the large title. The system does it to any field always under
  the title (an 11-line app too), and `toolbarTitleDisplayMode(.large)`, `defaultScrollAnchor(.top)`
  and a scroll to the header on appear didn't change it. A Search button in the bar was tried and
  dropped: its X took three presses on iOS 27.0 (the simulator and the iPhone) and one on iOS 26.5.
  A field that shows only on a pull down was dropped for being hidden.
- **Header row:** the first row of the list, above the rows' group, not in a cell. On its own line,
  in every size and orientation: the count in `{typography.subhead}` `{colors.secondary-label}`: the
  reminders shown out of every reminder, in every case, so a filtered list never reads as all of
  them ("3 reminders out of 14", "14 reminders out of 14"). One string with both numbers, one
  VoiceOver element.
- **Bar:** Filter, Sort, New, in that order; Filter and Sort share one glass group and New stands
  apart, split by a fixed `ToolbarSpacer`. With no reminders, only New. The bar stays during a
  search (`searchPresentationToolbarBehavior(.avoidHidingContent)`), so the Filter button's badge
  still says the sheet's filters are on.
- **Sort button:** `arrow.up.arrow.down` in the bar, monochrome like New. It opens the Sort menu: a
  section headed Created (Oldest First, Newest First) and one headed Due Date (Earliest First, Latest
  First), one choice checked across both, each choice a `Toggle` in a `Section` of a SwiftUI `Menu`,
  since the system drops the header of a section with a `Picker`. One tap applies a choice and closes
  the menu. Its label is "Sort" and its value the choice ("Created, Oldest First"), and VoiceOver
  reads each header, then its choices. Sorted by Due Date, a row keeps its place while search,
  filters and sort stay as they are, so Done doesn't move it; changing any of them, or leaving the
  tab, sorts again.
- **Filter button:** `line.3.horizontal.decrease` in the bar. Its badge counts how many of the filter
  sheet's sections are in use (Tags, Status, Strength, Due Date). Search doesn't count. While the
  count is above 0 the button takes the accent color and a tap shows a menu: Filter
  (`line.3.horizontal.decrease`) opens the sheet, Clear All Filters (`xmark`) removes every sheet
  filter and leaves the search. With none on, a tap opens the sheet. No long press, as on My Day.
- **Filter sheet ("Filter Reminders"):** Cancel (`xmark`, the form's cancel button) leading,
  Apply (the filled confirm button, `checkmark`) trailing, and Reset, a bordered button, at the bottom under the footer.
  With the draft unchanged, Cancel or swiping down closes it. Once it differs from what's applied,
  a swipe springs back and Cancel asks first, as the reminder form does: the system's
  confirmation dialog, "Are you sure you want to discard these changes?", as Calendar asks (#278). From the ✕ iOS draws it as a
  popover with Discard Changes alone; a tap outside it keeps the changes. A tap above the sheet does nothing either way: iOS draws a sheet's dimming
  view as noninteractive (spec #104, Decision 57).
  Match and Tags with No Tags as on My Day, then Status, Strength, From (From others, as on My Day,
  shown on the same terms) and Due Date. Status and
  Strength are checkmark lists. Due Date has From and To, each a switch with a date pill beside it
  while on. The footer counts what Apply would show.
- **Empty states:** `ContentUnavailableView`. With no reminders: `list.bullet.clipboard`, "No
  Reminders" and the line "Tap + to make one. Every reminder you make shows here, whatever its
  state." There is no button: New is in the bar (spec #104, Decision 62). When search or filters match nothing:
  `magnifyingglass` or `line.3.horizontal.decrease`, a title, a line naming what's narrowing the
  list, and a bordered Clear button. The header row stays above it.
