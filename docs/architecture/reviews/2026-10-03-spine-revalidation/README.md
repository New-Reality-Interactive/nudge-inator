# Spine revalidation, 2026-10-03

A validate-mode run of the `bmad-architecture` skill on
[`ARCHITECTURE-SPINE.md`](../../ARCHITECTURE-SPINE.md) at commit `acb3a01`, after the Update run on
branch `architecture/spine-update` closed the findings of the
[first validation](../2026-10-03-spine-validation/README.md). Report only; fixes follow on the same
branch.

## What was reviewed

- The deterministic lint (`lint_spine.py`) found nothing.
- Four reviewers ran in parallel, each in a fresh context, without reading the earlier reviews:

| File | Reviewer | Critical | High | Medium | Low |
|---|---|---|---|---|---|
| [review-rubric.md](review-rubric.md) | Rubric walker (good-spine checklist) | 0 | 2 | 5 | 9 |
| [review-currency.md](review-currency.md) | Technology currency | 0 | 1 | 3 | 3 |
| [review-adversarial.md](review-adversarial.md) | Adversarial unit pairs | 0 | 6 | 6 | 9 |
| [review-inputs.md](review-inputs.md) | Input reconciliation and one rule, one home | 0 | 0 | 3 | 11 |

## Outcome

- None of the first validation's 2 critical and 13 high findings came back. The adversarial reviewer
  couldn't build a compliant pair that breaks the single writer and queue, event order, delivery
  IDs, the frozen due instant, the at-once rule, journal replay or snooze adoption.
- 8 new high findings once overlaps are merged (rubric H2 and adversarial H1 are the same):
  command submission timing, the window's membership, an Assistive Access API that doesn't exist,
  the alarm diff, the slot policy, telling a locked store from a failed one, the carry-over input,
  and the post-snooze pre-alert length.

## Verified by the main session

- `UIAccessibility.isAssistiveAccessEnabled` doesn't exist in Apple's docs;
  `AccessibilitySettings.isAssistiveAccessEnabled` and SwiftUI's
  `accessibilityAssistiveAccessEnabled` do (both iOS 18.0+).
- The `AlarmConfiguration` initializers with `appEntityIdentifier` carry no beta flag in Apple's
  live documentation JSON.
- `Alarm` exposes only `id`, `schedule`, `countdownDuration` and `state`, so the diff can't read an
  alarm's presentation or metadata back from AlarmKit.

**Status: open.** Fixes are on `architecture/spine-update`; see the decision log entries after this
run.
