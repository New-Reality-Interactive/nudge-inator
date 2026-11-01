# Nudge-inator iOS mockup: Sort menu

The change mockup for #115's Sort menu: the [Reminders tab mockup](../2026-10-30-reminders-tab/README.md)
(signed off on #107) with the Sort menu redrawn. It is copied from that change mockup, not from
1.2.0, because 1.2.0 has no Reminders tab. Once Brian signs it off on #115, the Sort menu is
checked against it. The release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since the Reminders tab mockup

- **The Sort menu is one picker of four choices,** not a picker of the field and one of its
  order. A section headed **Created** holds Oldest First and Newest First, and one headed **Due
  Date** holds Earliest First and Latest First, each choice under its header with the chosen one
  checked. One tap applies a choice, which is remembered, and the menu closes as iOS's does, so
  any change is one open and one tap. Brian's call during #115's device check (2026-11-01): with
  two pickers, changing both the field and the order took two opens.
- Switching the field no longer keeps the direction, since each choice names its own.
- **VoiceOver** reads each choice whole ("Created, Oldest First"), so a choice is clear without
  its header. The Sort button still reads "Sort" and the choice as its value.

Nothing else changed. The Reminders tab mockup's choices, known differences and screens stand.
