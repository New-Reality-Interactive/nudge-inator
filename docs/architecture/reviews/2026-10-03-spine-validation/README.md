# Spine validation, 2026-10-03

A validate-mode run of the `bmad-architecture` skill on
[`ARCHITECTURE-SPINE.md`](../../ARCHITECTURE-SPINE.md), made at the end of the cross-document
review branch `docs/align-precedence-and-mockup`. It reported findings only; the spine wasn't edited
from it.

**Status: closed (2026-10-04).** Every finding here, critical to low, was resolved in the spine or
the documents it points to on branch `architecture/spine-update`; the decision log
(`../../.memlog.md`, entries "update run") records each decision and the option not chosen. Later
validate runs found new issues in the text the fixes added, not these: see
[2026-10-03-spine-revalidation](../2026-10-03-spine-revalidation/README.md),
[-2](../2026-10-03-spine-revalidation-2/README.md) and
[-3](../2026-10-03-spine-revalidation-3/review-adversarial.md). The prompt for the Update session
is in [NEXT-STEP-PROMPT.md](NEXT-STEP-PROMPT.md).

## What was reviewed

- The spine as of commit `78238ee`. Later commits on the same branch changed the brief, EXPERIENCE
  and the mockup, not the spine.
- The deterministic lint (`lint_spine.py`) found nothing.
- Three reviewers ran in parallel, each in its own context:

| File | Reviewer | Critical | High | Medium | Low |
|---|---|---|---|---|---|
| [review-rubric.md](review-rubric.md) | Rubric walker (good-spine checklist, internal consistency, coverage) | 0 | 6 | 11 | 10 |
| [review-currency.md](review-currency.md) | Technology currency (verified vs assumed, with sources) | 0 | 2 | 4 | 6 |
| [review-adversarial.md](review-adversarial.md) | Adversarial unit pairs (two compliant units that still diverge) | 2 | 8 | 5 | 2 |

[report.md](report.md) (and [report.html](report.html)) merges the critical and high findings, notes
overlaps between reviewers, marks which came from that branch's edits and which predate it, and
adds three AD-4, AD-6 and AD-15 items routed here from a later edge-case pass.

## Verified by the main session

These claims were checked against the files or Apple's sources, not only taken from the reviewers:

- Conventions › Durations says integer minutes; brief §3 has 7.5- and 2.5-minute intervals.
- The layer table puts AlarmKit in `NudgeShell` and `NudgeLiveActivity`, against AD-18.
- Apple's WidgetKit article says a `LiveActivityIntent` runs in the app's process, and WWDC26
  session 345 says intents in a package shared by app and extension are routed by heuristic (the
  extension is launched if the app isn't running). Both confirmed with the apple-rag-mcp tools.
- `AlarmManager.alarms`: an alarm is deleted from the store once it fires and stops; `SceneStorage`
  is per scene. (These drove AD-6 and Conventions › UI state on the same branch.)

## Using these files

- The review files hold each finding's evidence, the reviewer's reasoning and a suggested fix.
  Treat the fix as a starting point; each one is still the owner's decision.
- [review-currency.md](review-currency.md) ends with a list of what was confirmed current, and
  [review-rubric.md](review-rubric.md) ends with what was checked and holds. Don't re-verify those
  without a reason.
- Some reviewer counts differ slightly from the table above (the rubric walker lists M11 as
  medium–low); the table follows the files.
