Status: ready-for-agent

# Edit while nudging applies from the next nudge or occurrence

## What to build

An Edit event changes title, notes, tags, repeat, strength, Break through Focus, or due time.

- Changes to a Nudging occurrence apply **from the next nudge or the next occurrence**, not to nudges already delivered.
- An edit that would skip the current occurrence (for example moving the due time to the future) closes it as **Skipped** and the engine reports that so the screen can warn first (spec story 49). Provide a way to ask "what would this edit do?" without applying it.
- Changing strength re-plans remaining nudges on the new ladder; the nudge count continues rather than resetting (state your rule in a test).

## Acceptance criteria

- [ ] Editing the title changes the title in all later plan items and none of the already-passed ones.
- [ ] Flipping Break through Focus re-kinds the remaining items only.
- [ ] Moving the due time into the future closes the open occurrence as Skipped and the preview reports "skips this occurrence" before it is applied.
- [ ] Changing the repeat preset affects the next occurrence only.
- [ ] Notes and tag edits never reach any plan item text.

Blocked by: 08, 10
