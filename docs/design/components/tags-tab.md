# Tags tab

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

The Reminders tab's tools, in its layout, so they're learned once.
- **Search:** the system's search field, always shown under the large title while a tag exists, with the
  prompt "Search tags". It finds the tag's name only and ignores a leading `#`. The Reminders tab's
  known difference on iOS 27.0 applies.
- **Header row:** as on Reminders, in place of a "Your Tags" header: "9 tags out of 9", "1 tag out of 9".
- **Bar:** Filter and Sort share one glass group and New Tag stands apart, as on Reminders. There's no
  Edit button and there are no quick filter chips. With no tags, only New Tag. The bar stays during
  a search.
- **Sort button:** as on Reminders. Its menu has a section headed Name (A to Z, Z to A) and one headed
  Reminders (Most First, Fewest First). Ties on the count sort by name, A to Z, either way round.
- **Filter button:** as on Reminders, with a badge of 1 or none. Its menu is Filter and Clear All Filters.
- **Filter sheet ("Filter Tags"):** as on Reminders: Cancel, the confirm `checkmark` (VoiceOver name
  Apply), Reset at the bottom and the Discard Changes prompt. One row, Has no reminders, with the
  footer "Shows only tags that no reminder uses." and what Apply would show.
- **Rows:** the tag tile, name and counts, with content at least 48 pt tall for the swipe (Swipe
  actions). A tap opens the tag's details page ([Tag details page](tag-details-page.md)). A row that leaves, after a
  delete or when the filter excludes it, fades as its height closes up, and the count follows.
- **Help text:** static, not a dismissible tip, for a person new to tags. The list's footer, in
  `{typography.footnote}` and wrapping at large text and in landscape: "Tags are labels you add to
  reminders. Choose one to see every reminder that has it." The no-tags description: "Tags are labels, like #home or #errands, that you add
  to reminders so you can find them together. Tap + to make one, or add one when you create or edit
  a reminder."
- **Empty states:** `ContentUnavailableView`. With no tags: `tag`, "No Tags", the help text and no
  button, since + is in the bar. When search or the filter match nothing: `magnifyingglass` or
  `line.3.horizontal.decrease`, a title, a line naming what's narrowing the list and a bordered
  Clear button (Clear Search, Clear Filter, Clear Search and Filter), with no help text. The header
  row stays above it.
