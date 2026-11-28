# Swipe actions

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- **Token:** `swipe-done`, `swipe-delete`, `swipe-edit`, `swipe-reminders`. Trailing swipe shows Done: green tile, white
  `checkmark` and the word "Done". On the Reminders tab's Mine, Edit sits beside it: blue tile, white
  `pencil` and the word "Edit", which opens the Edit Reminder form; then Delete: red tile, white
  `trash` and the word "Delete". Done is offered only while Nudging, at the edge; a row that isn't
  Nudging shows Edit at the edge with Delete beside it. Edit is on the person's own rows only: a
  received copy's row shows Remove (and Done while Nudging), since its sender owns what it says
  (#429). On Sent, Edit is at the edge with Delete beside it; a sent reminder's Edit opens its Edit Reminder
  form. On the Tags tab the tiles are Delete, Edit and Reminders, left to right with Reminders at
  the edge: a teal (`{colors.tile-teal}`) tile, white `list.bullet.clipboard` and the word
  "List" (a longer word widens every tile into an oval, #378; VoiceOver's action is still
  "Reminders"), which opens the tag's reminders page (Back returns to the Tags list); a tag's Edit opens
  the rename sheet. Teal is for a tile that goes somewhere, blue for one that edits in place. Delete asks first. Nothing is on
  the leading edge, there's no full swipe (ADR 0001), and each tile always shows its glyph and its
  word. There is no Snooze.
- **Shape:** a tile is the same 50 pt circle on every screen, holding the white glyph, with the word
  under it in `{colors.secondary-label}` and the swiped row gray with rounded ends, all as the system
  draws them. The system draws the tile from the row's
  height: a circle on a row of at least 78 pt, a wider oval on a shorter one. Apple doesn't document
  this; it was measured on iOS 26.5 and 27.0 (#126). So a list row with a swipe has content at
  least 48 pt tall (`Design.Size.swipeRowContentHeight`), which makes 78 pt with the list's padding.
  This is why Reminders rows are taller than the 44 pt `{spacing.row-min}`.
- **Where each swipe appears:** a Nudging row offers Done as a trailing swipe on every screen it
  appears on (Now, My Day and Reminders), and Done means the same on each. Delete's and Edit's
  swipes are on the Reminders and Tags tabs, where reminders and tags are managed. Now and
  My Day are for acting on the day, so a destructive swipe never sits beside Done there. On those
  two screens a row that isn't Nudging (Coming up, Last 24 Hours, closed) has no swipe.
- **A swipe is a shortcut,** never the only way: Done is also the Done button on Now and My Day and
  on the details page, Edit and Delete are also on the details page, and VoiceOver gets each as the
  row's own actions. A new screen that adds swipes follows this section, and on the Reminders and
  Tags tabs gets its tiles and VoiceOver actions from one list (`rowActions`, #429). **The exception
  is a tag:** its Edit and Delete are reachable by the swipe and by VoiceOver actions only, since
  the Tags tab has no Edit mode (spec #104, Decision 50).
- **VoiceOver after a delete:** iOS decides where it lands, and the app doesn't move it. After a tag's
  Delete it landed on a nearby row, the heading, New Tag or a row further away, and after the last tag
  on the bar's title, an empty-looking box one swipe from the visible title. Moving focus from code
  was tried on the iPhone: iOS moves it first as the question closes, so VoiceOver starts reading
  something else and then jumps, which Brian found worse (#139's Comments).
