# Nudge-inator iOS mockup: Turn Off Sharing

The change mockup for turning Sharing off (#388, spec #127, version 1.4.0). Copied from the
[Sharing switch mockup](../2026-11-14-sharing-switch/README.md), so everything that mockup shows is
here too; this one changes two things, decided in #388's review (2026-11-14). It's deleted when the
1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. The controls panel's **Sharing switch (#386, #388)**
section has three starting points, each keeping the tab you're on. Portrait and landscape come from
the iPhone section's Orientation.

## What changed since the Sharing switch mockup

- **No success messages.** The app shows none, so the mockup doesn't either: the message that used to
  appear at the top of the screen after an action (such as "Sharing turned off", "Disconnected from
  Riley Park", "Changes saved") is gone everywhere. An action that worked shows its result on the
  screen; only a failure says anything. `docs/design/DESIGN.md` states the rule. What a mockup
  control did, or why it did nothing (such as "Reset the mockup"), is shown in the controls panel,
  off the iPhone. The [mockup template](../2026-10-26-mockup-template/README.md) dropped the message
  too, so later mockups don't start with it.
- **Turning Sharing off asks whenever it deletes anything**, as every destructive action does: a
  connection, an invite, or a reminder sent or received. Before, it asked only while anyone was
  connected or invited, so with only reminders received (the other people ended their connections)
  or only a Sent history, it deleted them at once. With nothing to delete it still turns off at once.
  - The **Turn Off Sharing** sheet's first line says what goes: "This disconnects you from 2 people
    and cancels 2 invites." with either part left out at 0, then "You won't be able to send or
    receive reminders, and your Sent list and its history are deleted." With no one connected or
    invited, only the second sentence shows.
  - The new starting point **Sharing on, reminders received, no one connected** reaches that case:
    tap the switch off in Settings to see the sheet with Remove or Keep and no note footer.
