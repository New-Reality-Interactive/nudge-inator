# Nudge-inator iOS mockup: My Day's day buttons (#375)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[My Day on another day mockup](../2026-11-23-my-day-other-days/README.md) with the changes the
developer made on the phone during #375's phone check, and nothing else changed. It is deleted when
the 1.6.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. My Day is the
second tab; the controls' "My Day on another day" group jumps to each state.

## What changed since the My Day on another day mockup

- **No sideways swipe between days.** On the phone, iOS's paging took a Nudging row's Done swipe,
  and nothing short of dropping the day swipe kept both. Previous Day, Next Day and Today move the
  day, and the new day slides in from the side it lies on. A Nudging row's Done swipe works as before.
- **Previous Day and Next Day sit either side of the date**, each on the side it moves toward, as
  44 pt glass circles (they were smaller, at the date's trailing end). The date is centered and wraps
  between them. They stay that size at every text size, as the bar's buttons do. In landscape they
  are in the bar, as before.
- **The day label is the secondary grey on every day**, as Now's date line and today's date before
  this feature are. The other day's label color read as if today's were dimmed.
- **The date row stays still** while the day below it changes, as before.

Everything else, from the range and the day label's words to the counts, the filter, the empty
states and VoiceOver, is as in the My Day on another day mockup.
