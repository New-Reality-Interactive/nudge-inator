# Ticket workflow

The steps every ticket follows, from its first prompt to the prompt for the next one. They follow
the mattpocock-skills main flow. Where a step has its own doc, this file points to it.

Run each skill named here with the Skill tool (`mattpocock-skills:<name>`), at the step that names
it. Don't write its output from memory of what the skill does: its steps are the procedure, and a
step done by hand gets skipped. The ones in `/slash` form only the developer can run; ask for them.

## Start

The developer starts a ticket in a fresh session (`/clear`) by pasting the prompt drafted when the
last PR was merged (below), with the model and effort it recommends. The prompt begins
`/implement <ticket path>`, because only the developer can run that skill.

1. Check every ticket in `Blocked by` is `resolved` on `main`. If one isn't, stop and say which.
2. Branch from an up-to-date `main`: `<feature>-<NN>-<slug>`, for example `pace-02-as-built-mockup`.
3. Read the ticket, the Comments of the tickets it builds on, and the spec sections it names
   (`review.md`, Session size).

## Build

4. Build every change in behaviour with `mattpocock-skills:tdd`. Propose the seams and wait for
   the developer to agree them before the first test. A ticket with no behaviour (docs, a mockup)
   skips `tdd`; say so.
5. Use `mattpocock-skills:domain-modeling` when a name isn't in `GLOSSARY.md`, and
   `mattpocock-skills:diagnosing-bugs` when something fails and a first look doesn't explain it.
6. For a change on screen, check its visual criteria on both simulators (AGENTS.md, Testing)
   before review.

## Review and commit

7. Follow `review.md`'s finish order up to the commit: `scripts/test.sh` passes, `/compact`
   (ask the developer), `mattpocock-skills:code-review`, fix, re-test, tick the criteria, write
   Comments, commit.

## The developer's check

8. A ticket ends with the developer's check, before any PR:
   - Device checks, from the criteria or AGENTS.md's offer of an iPhone run: walk them through
     one at a time (`device-testing.md`).
   - A criterion the developer judges, such as approving a mockup: show it and ask.
   - Neither: show the evidence and ask whether it's ready.

   A failed check goes back to Build. The ticket is `resolved` only when every criterion is ticked
   (AGENTS.md, Issue tracker).

## PR

9. When the developer says it passed: rerun `scripts/test.sh` if anything changed since the
   last run, push the branch, and open a PR to `main` with `gh pr create`. Title it
   `Ticket NN: <ticket title>` and write the body with `mattpocock-skills:pr`. Give the developer
   the link and stop.

## When the PR is merged

10. When the developer says the PR is merged:
    - `git switch main && git pull`, check the merge commit is there, and delete the local branch
      with `git branch -d`.
    - If the ticket went sideways, suggest the developer run `/retro` before `/clear`.
    - Find the next ticket: the lowest-numbered open ticket in the feature whose `Blocked by`
      tickets are all resolved. If none is left, say the feature is done.
    - Draft its starting prompt (below) and stop. Don't start it.

## The next ticket's prompt

One line for the developer, then the prompt as a block to copy:

> Run `/clear`, then `/model` → <model>, effort <level>: <why, in one line>.

```text
/implement .scratch/<feature>/issues/<NN>-<slug>.md

Follow docs/agents/ticket-workflow.md.

- Branch: `<feature>-<NN>-<slug>` from main (<short sha>, after PR #<n>).
- Builds on: ticket <NN>: <what it left that this one needs, and where in its Comments>.
- Spec: <the sections the ticket names>.
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
