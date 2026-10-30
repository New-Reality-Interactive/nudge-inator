# Ticket workflow

Every ticket is one `/implement` run, from a fresh session, plus this project's additions around
it. The skill states the ticket's title, builds with `tdd` at the seams it records, runs the
tests, reviews with `code-review` and commits. This file adds what comes before, during and after.

Only the developer can start `/implement` (and `/retro`): it runs only when typed as a command,
not inside pasted text. Each skill named here as `mattpocock-skills:<name>` runs through the Skill
tool at its step.

## Start

The developer runs `/clear` and types `/implement #<n>`, `<n>` being the ticket's issue number.
Everything else the ticket needs is in the ticket, under **Before you start** (below).

1. Check every issue blocking it is closed (`issue-tracker.md`, Blocked by). If one isn't, stop and say which.
   If the ticket can't be built backwards compatible (`release.md`, Features and versions), stop and say what breaks.
2. Branch from an up-to-date `main`: `<feature>-<n>-<slug>`, such as `tags-83-filter-sheet`, `<feature>`
   being the slug in the milestone's description.
3. Read the ticket, its Before you start, the Comments of the tickets it builds on, and the spec
   sections it names (`review.md`, Session size).

## During `/implement`

4. Choose the `tdd` seams, starting from the spec's Testing Decisions, and record them in the
   ticket's Comments before the first test, then go on (global rule: the developer raises a
   wrong seam in review). A ticket with no behaviour (docs, a mockup) skips `tdd`; say so.
5. Run `mattpocock-skills:domain-modeling` when a name isn't in `GLOSSARY.md`, and
   `mattpocock-skills:diagnosing-bugs` when something fails and a first look doesn't explain it.
6. Test with `scripts/test.sh`.
7. Review as `review.md` says, starting once step 6 passes. A change on screen: start
   `scripts/screenshots.sh` for its visual criteria, on both simulators, in the background at
   the same time (`device-testing.md`, Simulator screenshots), except the full walk, which that
   section puts once before the PR. Make the fixes from the review
   and from the screenshots after both finish, rerun `scripts/test.sh` (not when every fix changes
   only comments, `review.md`), then commit.

## The developer's check

8. Before any PR:
   - Device checks, from the criteria or AGENTS.md's offer of an iPhone run: walk them through
     one at a time (`device-testing.md`).
   - A criterion the developer judges, such as approving a mockup: show it and ask.
   - Neither: go straight to step 9, with the evidence in the PR body. The developer's approval
     of the PR is the check.

   A failed check goes back to step 4. A ticket is `resolved` only when every acceptance
   criterion is ticked; while one is open, the issue stays open. Say which criterion is open and
   why, and resolve it with the developer: meet it, or agree a change to it (reworded, or moved
   to a named ticket) and record that agreement in Comments.

## PR

9. A change that calls for the full screenshot walk (`device-testing.md`, Simulator
   screenshots) runs it now. Rerun `scripts/test.sh` if anything changed since its last run, push, then run
   `mattpocock-skills:pr` and open the PR to `main` with `gh pr create`, titled
   `#<n> (<feature>): <short summary>`, with `Closes #<n>` as the body's last line before the
   attribution, so the merge closes the ticket. A hook refuses a body without the `pr` skill's sections. Give the developer the
   link and stop.

## When the PR is merged

10. `git switch main && git pull`, check the merge commit is there, and delete the local branch
    with `git branch -d`. If the ticket went sideways, suggest `/retro` before `/clear`.
11. Find the next ticket: the lowest-numbered open sub-issue of the feature's spec with no open
    blocker. If none is left, the feature is ready to release: follow
    `release.md`, and tell the developer which steps are theirs.
12. Add its **Before you start** to the issue body, and give the developer one line, then stop:

    > Run `/clear`, `/model` → <model>, effort <level> (<why>), then `/implement #<n>`.

### Before you start

A section at the end of the issue body, written when the ticket before it merges:

```markdown
## Before you start

- Builds on: #<n>: <what it left that this one needs, and which of its comments says so>.
- Watch for: <anything earlier tickets found that this one could trip on>.
- Developer stops: <simulator check | device check | approval of X | none>.
```

## Choosing a model and effort

Count the cost per finished ticket, not per request. A cheaper model that needs a second attempt
isn't cheaper. A stronger model at lower effort often beats a weaker one at maximum effort.
API prices per million tokens, input/output (2026-10-06): Sonnet 5.5 $2/$10, Opus 5.5 $4/$20,
Fable 5.1 $10/$50.

| The ticket | Model · effort |
|---|---|
| Mechanical: config, a docs follow-up, criteria that leave no judgement | Sonnet 5.5 · medium |
| Well-specified engine or store logic, where the tests define done | Sonnet 5.5 · high |
| Crosses engine and UI, or needs a visual or design call (mockups, layout, accessibility) | Opus 5.5 · medium |
| AlarmKit, concurrency, isolation, a hard bug, or a ticket that failed once | Opus 5.5 · high |
| Failed again at that, or the way forward is unclear | Fable 5.1 · high, or step back to `/grill-with-docs` |

Haiku 5.5 isn't recommended for ticket work.
