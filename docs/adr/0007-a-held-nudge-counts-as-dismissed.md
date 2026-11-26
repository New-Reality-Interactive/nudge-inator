# A held nudge counts as dismissed, so quiet hours can end in Missed

A nudge due at a quiet time is held (a time covered by a schedule that is on, or any time from when Quiet Now was turned on, #497): it is left out of the plan and counts as if the person had swiped the notification away or tapped Stop. The ladder moves on without it, the nudges after it keep their numbers, and nothing is sent late. So an occurrence that reaches its give-up limit while a window is in effect closes as Missed, even if nothing ever sounded, and the engine reports how many of its nudges were held so the screens can say why.

Pause looks similar but stays different: it closes the open occurrence as Skipped, which isn't counted against the person. Pause is a direct action the person takes about one reminder, at that moment. A held nudge comes from a rule the person set in advance for every reminder, and the reminder still came due and went unanswered, so it is Missed (the developer's decision, 2026-11-10, spec #338).

## Considered Options

- **Held nudges close the occurrence as Skipped, as Pause does.** Rejected: a window would silently erase every reminder that came due in it from My Day's Missed count, and the person couldn't tell a reminder they chose to stop from one they never answered.
- **Send the held nudges, or one catch-up nudge, when the window ends.** Rejected: a burst of old alerts at 7 AM is what quiet hours is meant to avoid, and it would need a nudge outside the ladder.
- **Pause the ladder during a window and resume it after.** Rejected: the occurrence would nudge for longer than its give-up limit allows, and the nudge numbers would no longer match the ladder's times.

## Consequences

- No new state is added to a nudge, and an occurrence's state is worked out as before: the ladder, urgency, take-over and give-up limit don't change; only the plan does.
- Quiet hours are read as they were when each nudge was due, as permissions are, so editing a schedule, or turning Quiet Now on or off, changes only nudges due after the change. The engine keeps the quiet hours each edit replaced, Quiet Now's moment included, and the app saves them and hands them back at launch, so a Missed occurrence's held count stays true after a relaunch.
- An occurrence's held count is fixed with its closing whenever the engine fixes one (Done, or an Edit that moves the nudge times), so an Edit to the reminder's strength, pace or due time can't change a past count. The reminder store saves it in one optional field (schema version 5, a lightweight stage, the developer's decision on #367); a closing saved before it has none and reads as none held, since quiet hours didn't exist yet. Only a closing the clock works out, whose ladder no Edit has moved, has its count read from the ladder.
- A held nudge takes no part in the alarm limit, since it never reaches the plan.
- A reminder the person can't afford to miss can close as Missed during a window with nothing sounding. That risk is accepted; a per-reminder override is out of scope.
