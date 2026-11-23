# Nudge-inator iOS mockup: My Day on another day (#374, #375)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Settings rows mockup](../2026-11-23-settings-rows/README.md) with My Day able to show other days, and
nothing else changed. It is deleted when the 1.6.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. My Day is the
second tab; the controls' first group jumps to each state.

## What changed since the Settings rows mockup

- **The swipe:** a sideways drag on My Day moves a day: left to the next, right to the previous. The
  new day slides in from the side the drag came from. A drag that starts on a Nudging row is that
  row's Done swipe, as before, so the two never both move.
- **The range:** back to the day the oldest reminder was created, forward 7 days, as Coming Up looks.
  Past either end the page gives a little and springs back. With no reminders it is just today.
- **The day label** under the title names the day: today's date as before; Yesterday or Tomorrow
  before the date ("Tomorrow, Tuesday, September 29"); any other day its date alone, with the year
  when it isn't this year's. On another day it is in the label color, not the secondary one. In
  landscape it is the title's subtitle, as today's date is.
- **Previous Day and Next Day** are glass chevron buttons, as the tutorials' Back and Next are, on
  every day, today included, so it's plain that My Day goes back and forward. Each is dimmed at its
  end of the range. They sit beside the day label, the pair at its trailing end (the developer's
  call, 2026-11-23, over around the label or in the bar). In landscape the label is the bar's
  subtitle, so they sit in the bar there.
- **Today** is a bar button at the top left, shown only while another day is showing. It goes back
  to today.
- **A past day** lists each occurrence as its history recorded it: Done, Missed (with the quiet hours
  note when it has one) or Skipped. A reminder created after that day isn't there. There is no Now
  marker.
- **A future day** lists what falls due on it as Left, or Paused if its reminder is; Nudging is 0.
  Each row says how it repeats, as Coming Up's rows do, in place of "in 22 hr.".
- **Counts and filters** work on every day. The words that said "today" say the day: the empty
  states ("Nothing was due yesterday.", "Nothing is done yet for tomorrow."), the tag filter's
  "Due tomorrow with #home and #morning", and the filter sheet's "Apply shows 2 reminders due
  tomorrow."
- **VoiceOver:** Previous Day and Next Day are buttons it reads by name, dimmed at the range's
  ends, and a change of day is announced: "Tomorrow, Tuesday, September 29. 6 reminders due." Focus stays where iOS puts it.
- **Today is unchanged:** My Day opens on today and looks as it did.

The mockup's made-up history covers only a few days, so it makes up the rest (mostly Done, now and
then Missed). The app reads the store's history.
