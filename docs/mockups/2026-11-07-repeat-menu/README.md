# Nudge-inator iOS mockup: Repeat menu

The change mockup for #283: the [1.2.0 mockup](../1.2.0/README.md) with the reminder form's Repeat as a
pop-up menu, as in Apple's Reminders on iOS 27 (spec #104). Once Brian signs it off on #283, the
ticket is checked against it. The release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The
New Reminder form (the + button) reaches every state below.

## What changed since the 1.2.0 mockup

- **Repeat is a menu, not a page.** Tapping the Repeat row lists Never, Every Day, Every Weekday,
  Every Week, Every 2 Weeks, Every Month and Every Year, a divider, then Custom, with a checkmark on
  the current choice. A choice is the form's repeat at once. The Repeat page and its checkmark are gone.
- **The Custom row.** Choosing Custom adds a Custom row below Repeat. It shows the rule's summary
  with a chevron and opens the Custom repeat page. Choosing a preset again removes the row.
- **The Custom page** still edits a copy: its checkmark makes the choices the repeat and goes back to
  the form; Back drops them. (#284 turns it into a sheet.)
- **Cancel** asks "Are you sure you want to discard these changes?" when only the repeat changed.
- **While nudging** the Repeat row and the Custom row are locked, each with the `lock`, beside the
  lock note.
