# Nudge-inator iOS mockup: Last synced

The change mockup for Last synced (#434, spec #127, version 1.4.0). Copied from the
[account change mockup](../2026-11-16-account-change-not-told/README.md), the latest of the
feature's change mockups. It's deleted when the 1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser, then the controls' Shared reminders › "Maya Torres
goes quiet" (and "Maya Torres syncs again" to go back).

## What changed since the account change mockup

- **A quiet connection's note.** Once the other person hasn't synced for 14 days,
  and their status sharing for the connection is on, the connection's page shows "Last synced on
  Sep 10" (the date in the person's locale) under Connected since. Nowhere else shows it, the
  Connections row included. Sam Okafor's status sharing is off, so Sam Okafor's page never shows it.
- **The status sharing footer**, with Status Sharing on, names the person once and adds a
  sentence: "Maya Torres sees how the reminders they send you are going: Done, Paused, Missed or
  Removed, and the last 7 days of a repeating one. They also see when you last opened the app."
  The off wording is unchanged, since nothing is shared then.
- **What Maya Torres Chose's footer** names the person once: "They set these, for the reminders
  you send them."
- Nothing else changes: the rows, the page's other sections and Disconnect stay as they were.
