# Ticket workflow

Every ticket is one `/implement` run, from a fresh session, plus this project's additions around
it. The skill states the ticket's title, builds with `tdd` at seams agreed beforehand, runs the
tests, reviews with `code-review` and commits. This file adds what comes before, during and after.

Only the developer can start `/implement` (and `/retro`): it runs only when typed as a command,
not inside pasted text. Each skill named here as `mattpocock-skills:<name>` runs through the Skill
tool at its step.

## Start

The developer runs `/clear` and types `/implement .scratch/<feature>/issues/<NN>-<slug>.md`.
Everything else the ticket needs is in the ticket, under **Before you start** (below).

1. Check every ticket in `Blocked by` is `resolved` on `main`. If one isn't, stop and say which.
2. Branch from an up-to-date `main`: `<feature>-<NN>-<slug>`, such as `pace-02-as-built-mockup`.
3. Read the ticket, its Before you start, the Comments of the tickets it builds on, and the spec
   sections it names (`review.md`, Session size).

## During `/implement`

4. Propose the `tdd` seams and wait for the developer to agree them before the first test. A
   ticket with no behaviour (docs, a mockup) skips `tdd`; say so.
5. Run `mattpocock-skills:domain-modeling` when a name isn't in `GLOSSARY.md`, and
   `mattpocock-skills:diagnosing-bugs` when something fails and a first look doesn't explain it.
6. A change on screen: check its visual criteria with `scripts/screenshots.sh` on both
   simulators before review (`device-testing.md`, Simulator screenshots).
7. Test with `scripts/test.sh` and review as `review.md` says, then commit.

## The developer's check

8. Before any PR:
   - Device checks, from the criteria or AGENTS.md's offer of an iPhone run: walk them through
     one at a time (`device-testing.md`).
   - A criterion the developer judges, such as approving a mockup: show it and ask.
   - Neither: show the evidence and ask whether it's ready.

   A failed check goes back to step 4. The ticket is `resolved` only when every criterion is
   ticked (AGENTS.md, Issue tracker).

## PR

9. Rerun `scripts/test.sh` if anything changed since its last run, push, then run
   `mattpocock-skills:pr` and open the PR to `main` with `gh pr create`, titled
   `Ticket <NN> (<folder>): <short summary>`, `<folder>` being the ticket's folder under
   `.scratch/`. A hook refuses a body without the `pr` skill's sections. Give the developer the
   link and stop.

## When the PR is merged

10. `git switch main && git pull`, check the merge commit is there, and delete the local branch
    with `git branch -d`. If the ticket went sideways, suggest `/retro` before `/clear`.
11. Find the next ticket: the lowest-numbered open ticket in the feature whose `Blocked by`
    tickets are all resolved. If none is left, say the feature is done.
12. Write its **Before you start** into the ticket, uncommitted (the ticket's own branch commits
    it), and give the developer one line, then stop:

    > Run `/clear`, `/model` → <model>, effort <level> (<why>), then `/implement <ticket path>`.

### Before you start

A section in the ticket, above `## Comments`, written when the ticket before it merges:

```markdown
## Before you start

- Builds on: ticket <NN>: <what it left that this one needs, and where in its Comments>.
- Watch for: <anything earlier tickets found that this one could trip on>.
- Developer stops: <seams to agree | simulator check | device check | approval of X>.
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
