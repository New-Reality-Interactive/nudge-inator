Status: ready-for-agent
Type: bug

# My Day rows break words at accessibility text sizes

Found while making the as-built mockup (enhancement-pace ticket 02), in simulator screenshots on `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` at the largest text size (AX5), 2026-10-21. Brian agreed the mockup draws the row as intended, and asked for this ticket.

## The bug

At the accessibility text sizes, a My Day row that shows a status label (✓ Done, Missed, Skipped, Paused) squeezes its text into a narrow column, so words break in the middle: the time reads "12:33 / PM", the title "Morn- / ing meds", the tags "#morn- / ing", and the label itself "Do / ne".

`MyDayRowView.opener` in `App/MyDay/MyDayRows.swift` puts `text`, a `Spacer` and the `outcome` (the status label) in an `HStack` at every size. `text` itself stacks the time over the title at accessibility sizes, but the label stays beside it and takes its share of the width.

## What it should do

The as-built mockup's My Day (`docs/mockups/2026-10-21-as-built/`, Text Size AX1 to AX5): at accessibility sizes the row stacks the time, then the title and its detail, then the status label under them, with the chevron. At the other sizes nothing changes.

- [ ] At accessibility sizes a My Day row's status label sits under its text, and no word in the row breaks mid-word at AX5 (simulator screenshots on both simulators, portrait and landscape: `scripts/screenshots.sh`, the `myday` screens).
- [ ] At the default size the row is unchanged (screenshots compared with the as-built mockup).
- [ ] VoiceOver still reads the row as one element, with the status (device check on the iPhone, after the simulator pass).

## Comments
