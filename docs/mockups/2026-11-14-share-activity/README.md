# Nudge-inator iOS mockup: Share Activity

The change mockup for the Share Activity page (#397, spec #127, version 1.4.0). Copied from the
[Turn Off Sharing mockup](../2026-11-14-turn-off-sharing/README.md), the latest of the feature's
change mockups, so everything that mockup shows is here too. It's deleted when the 1.4.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. The controls panel's **Share Activity (#397)** section
opens the page with entries and with none. Portrait and landscape come from the iPhone section's
Orientation, and the largest text size from iPhone settings' Text Size.

## What changed since the Turn Off Sharing mockup

- **Settings › Sharing** has a third row, **Share Activity**, below Connections: a gray tile with
  the list-in-a-rectangle symbol (`list.bullet.rectangle`, chosen from four on 2026-11-14), no
  status, and a chevron. Like Connections, it is there only while
  Sharing is on. Settings' other rows, sections and their order are as they were.
- **The Share Activity page** lists the record (`GLOSSARY.md`, Share Activity), newest first, in
  one inset list. Each entry is three lines of plain text, with nothing to tap:
  - **Who it concerns**, in full, as the person knew them: one name for most entries, and every
    connection removed for a change of Apple Account, joined as a list ("Chris Nolan, Pat Rivera,
    and Dana Kim"). Every entry has a name: a change waiting to sync keeps its connection's name,
    so one iCloud refuses after that connection ended still says who it was for (decided on
    2026-11-14, #397).
  - **What happened**, in the sentence #396 wrote for the event, unchanged.
  - **When**: "Today at 7:58 AM", "Yesterday at 4:12 PM", then the date, "Mon, Sep 21 at 6:02 PM".
  - The list's footer reads "Kept on this iPhone only. Turning off Sharing clears it."
- **With no entries** the page shows **No Share Activity** under a checkmark: "Nothing has gone
  wrong with sharing. If iCloud refuses a change or a connection ends, it shows here."
- **The made-up record** has one entry of each kind: changes iCloud refused (a send, a status
  update, a change to sharing choices, and a delete for Alex Morgan, refused after that connection ended), a connection iCloud
  lost, the other person leaving, and a change of Apple Account naming three people.
- **The controls that change the record:** "The other person disconnects" adds an entry for them;
  "A different Apple Account signs in" clears the record and leaves its own entry; turning Sharing
  off, and Delete All Data, clear it.
