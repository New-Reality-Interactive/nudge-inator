# Ticket workflow

Every ticket is one `/implement` run, from a fresh session, plus this project's additions around
it. The skill states the ticket's title, builds with `tdd` at the seams it records, runs the
tests, reviews with `code-review` and commits. This file adds what comes before, during and after.

Only the developer can start `/implement` (and `/retro`): it runs only when typed as a command,
not inside pasted text. Each skill named here as `mattpocock-skills:<name>` runs through the Skill
tool at its step.

## Start

The developer runs `/clear` and types `/implement #<n>`, `<n>` being the ticket's issue number.
Everything else the ticket needs is in the ticket: its sections, and **Before you start** (both below).

1. Check every issue blocking it is closed (`issue-tracker.md`, Blocked by). If one isn't, stop and say which.
   If the ticket can't be built backwards compatible (`release.md`, Features and versions), stop and say what breaks.
2. Branch from an up-to-date `main`: `<feature>-<n>-<slug>`, such as `tags-83-filter-sheet`, `<feature>`
   being the slug in the milestone's description.
3. Read the ticket, all its sections (Context, Must keep, Developer stops) and its Before you start, the Comments of the tickets it builds on, and the spec
   sections it names (`review.md`, Session size).

## During `/implement`

4. Choose the `tdd` seams, starting from the spec's Testing Decisions, and record them in the
   ticket's Comments before the first test, then go on (global rule: the developer raises a
   wrong seam in review). A ticket with no behaviour (docs, a mockup) skips `tdd`; say so.
5. Run `mattpocock-skills:domain-modeling` when a name isn't in `GLOSSARY.md`, and
   `mattpocock-skills:diagnosing-bugs` when something fails and a first look doesn't explain it.
6. Test with `scripts/test.sh`.
7. Review as `review.md` says, starting once step 6 passes. A change on screen also gets the
   **phone check**, started at the same time, unless the developer has opted out for this ticket
   (by saying so in the ticket or when starting it). The phone is the only place the screens are
   checked (the developer retired the simulator screenshot runs on 2026-11-09), so this one pass
   also covers what those runs did.
   - Install the build on the phone and load the ticket's seed (`device-testing.md`, Manual device
     checks), then give the developer **one checklist** covering the ticket's acceptance criteria
     and the screens next to the change, plus landscape and the largest text size on the changed
     screens, and, for a ticket with a mockup, a comparison with the mockup's screen. Each line holds its action and what to report from it, as
     a device-check walkthrough's items do. The developer works through the whole list and reports
     everything in one go: no waiting for an answer between lines, which differs from a
     walkthrough. VoiceOver checks and automated device runs are not on this list; they stay one
     step at a time, each with the developer's go (`device-testing.md`, Device-check walkthrough).
   - Make the fixes from the review and from the phone check after both finish, rerun
     `scripts/test.sh` (not when every fix changes only comments, `review.md`), then commit. A fix
     that changes something on screen sends the developer back to only the checklist lines it
     changed, not the whole list.
   - Record each finding and the phone time as "Recording findings" (below) says.
   - A change that alters nothing on screen (logic alone) has no phone check; it goes from the
     review's fixes to step 8.

## The developer's check

8. Before any PR:
   - Device checks, from the criteria: walk them through one at a time (`device-testing.md`).
   - A criterion the developer judges, such as approving a mockup: show it and ask.
   - The phone check of step 7 is the check of a change on screen; there are no simulator runs.
   - None of these: go straight to step 9, with the evidence in the PR body. The developer's go in
     step 9 is the check.

   A failed check goes back to step 4. A ticket is `resolved` only when every acceptance
   criterion is ticked; while one is open, the issue stays open. Say which criterion is open and
   why, and resolve it with the developer: meet it, or agree a change to it (reworded, or moved
   to a named ticket) and record that agreement in Comments.

## Recording findings

A ticket that changes something on screen records every finding in its Comments (#305), as it comes, so the readout below has the data. One comment per check (the phone check, the review, a TestFlight report), one line per finding:

- **Found by:** the phone, the review, or TestFlight.
- **Kind:** an app bug, a harness fault, a mockup mismatch, or a flake.
- **Where:** the orientation and text size it showed on (the phone's).
- A run that found nothing says so in one line, so a ticket with no findings still shows its checks.

**Phone time** comes from timestamps, with no stopwatch: post a comment as soon as the build is installed and the seed loaded ("Phone check: installed, checklist sent"), and post the developer's report as a comment as soon as it arrives, one line per finding as above. The phone time is the gap between the two comments' timestamps (`gh issue view <n> --comments --json comments`). A report that comes in pieces is recorded when its last piece arrives.

**The readout.** After the fifth ticket that changes something on screen and merges under the phone-only order (2026-11-09, counting from the ticket after it), give the developer a one-page readout in chat: per ticket, the phone time and the findings by finder and kind; then a recommendation on what to **keep, change or drop**. Collection continues after the readout.

**An earlier readout.** An app bug that reaches TestFlight on iOS 26 prompts the readout sooner: it is the gap the developer accepted on 2026-11-09, no look at iOS 26 on screen, showing up. Give the readout at once, before the next ticket, with the ticket that missed it and which check would have caught it.

## PR

9. Rerun `scripts/test.sh` if anything changed since its last run. Then
   give the developer a summary of the PR and ask whether to create it. `/implement` is not that go; any
   answer that affirms continuing is, and it covers the merge too. After it: push, run
   `mattpocock-skills:pr` and open the PR to `main` with `gh pr create`, titled
   `#<n> (<feature>): <short summary>`, with `Closes #<n>` as the body's last line before the
   attribution, so the merge closes the ticket. A hook refuses a body without the `pr` skill's sections. Wait for its CI
   checks on the pushed commit; if one fails, find out why, fix it, push and wait again. On green,
   merge it without asking, then go on to step 10.

## When the PR is merged

10. `git switch main && git pull`, check the merge commit is there, and delete the local branch
    with `git branch -d`. Shut down every simulator (`xcrun simctl shutdown all`), then check
    `xcrun simctl list devices booted` lists none: no simulator stays running once a ticket's PR
    has merged. If the ticket went sideways, suggest `/retro` before `/clear`.
11. Find the next ticket: the lowest-numbered open sub-issue of the feature's spec with no open
    blocker. If none is left, the feature is ready to release: follow
    `release.md`, and tell the developer which steps are theirs.
12. Add its **Before you start** to the issue body, and any of the ticket sections (below) it lacks (an older ticket does), and give the developer one line, then stop:

    > Run `/clear`, `/model` → <model>, effort <level> (<why>), then `/implement #<n>`.

### Ticket sections

Every ticket body has the same sections, in this order. `to-tickets` writes them from the block the agent drafts; the `implement` skill doesn't parse them, it reads the body, so this file is what gives them meaning. A ticket that predates them gets the three new ones when it becomes the next ticket (step 12), not before.

- `## Parent`, `## What to build`, `## Acceptance criteria`: the `to-tickets` template, with blockers as native edges.
- `## Context`: where this belongs, in prose: the spec sections it implements, the ADRs and `GLOSSARY.md` terms that apply, the mockup it follows. No file paths or code snippets.
- `## Must keep`: what the change must not break, such as data it carries forward (`release.md`, Backwards compatible) or behaviour other screens rely on.
- `## Developer stops`: where the developer takes part: `phone check`, `device check`, `approval of X`, or `none`. A ticket that is the developer's own steps is `ready-for-human`.

The `tdd` seams are not in the ticket: they depend on what earlier tickets leave behind, so step 4 records them in its Comments.

### Before you start

A section at the end of the issue body, written when the ticket before it merges:

```markdown
## Before you start

- Builds on: #<n>: <what it left that this one needs, and which of its comments says so>.
- Watch for: <anything earlier tickets found that this one could trip on>.
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
