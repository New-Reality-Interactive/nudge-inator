# Due time, repeat, strength and Break through Focus are locked while a reminder is nudging

While an occurrence is Nudging, the reminder's due time, repeat, strength and Break through Focus switch can't be edited. Title, notes and tags can. The lock lifts when the occurrence closes. Pace, and a Consistent pace's wait, were added to the lock when pace was introduced, for the same reason as strength: changing them would reshape a schedule already running. To change a locked field, mark the reminder Done, or Pause, edit and Resume.

The product promise is that nudging continues until Done. An edit that moved the due time into the future would close the occurrence as Skipped without Done, the same loophole ADR 0001 closed for Stop. Locking also removes three engine rules the earlier plan needed: a preview of what an edit would do, skip-by-edit, and the nudge count rule when strength changes mid-ladder.

## Considered Options

- **Free edits with a skip warning (the earlier plan, in the old wording of spec story 50).** Rejected: it needs the preview call, skip-by-edit and the strength re-plan rule, and the warning is a speed bump on a loophole.
- **Lock every field, title included.** Rejected: a typo should not need a Pause, and a title change only re-derives later plan items.

## Consequences

- A nudging reminder can't be postponed. Snooze is already out of the first version (ADR 0001), so Pause then Resume is the only way to push one back, and Resume on a Never reminder whose due time has passed needs a new due time.
- The engine rejects the edit; the form only reflects it.
- If testing shows people need to push a nudge back, that is a Snooze decision, not a looser lock.
