# Code review and session size

How a ticket is reviewed, and how to keep a session's context small. Review runs the `mattpocock-skills:code-review` skill.

## Review procedure

- One full review per ticket, after `scripts/test.sh` passes. After fixing findings, re-review only the files the fixes changed. Ask before any second full round.
- Give the skill its inputs up front so it skips the issue-ref search: the fixed point (`main` unless told otherwise) and the ticket's issue number, for example `#83`.
- Tell it the repo's rules (`CODING_STANDARDS.md`, `AGENTS.md`) win over the skill's smell baseline. Where a rule endorses something a smell would flag, drop the smell.
- The Standards agent reads `CODING_STANDARDS.md`, and `AGENTS.md`'s AlarmKit and Testing sections.
- Nothing gates localization, accessibility labels or Swift 6 isolation except the catalog check in `scripts/test.sh`, so the Standards agent is the only check on them.
- Tell the Spec agent: a change on screen that differs from the mockup (the latest `docs/mockups/<version>/`, or the change's mockup) or from `docs/design/DESIGN.md` either updates them in the same diff, or the ticket's Comments say why. The first-version mockup drifted 32 ways from the app this way (enhancement-pace ticket 02).
- Skip the Spec agent when every acceptance criterion in the ticket is already ticked and the change is mechanical. Say so in the report.
- Finish order: tests pass → review, while any screenshots run → fix findings from both → re-test (skipped when every fix changes only comments; the report says so) → ticket update and commit. Then `docs/agents/ticket-workflow.md`, from step 8: the developer's check comes before the PR.

## Session size

Most usage comes from long sessions that re-send a large history on every request.

- Read a ticket's Comments only for the tickets it builds on. Never read a whole finished ticket.
- Never `cat` test logs (`.build/test-logs`) or `Localizable.xcstrings`. Grep them, or Read with `offset` and `limit`.
- Run `/compact` after tests pass and before review.
- Run device-check walkthroughs in a fresh session holding only the ticket and the check list.
