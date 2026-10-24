# 18: Screenshot runs take minutes, not an hour

**What to build:** A ticket's simulator screenshots shoot only the screens its change reaches, on both simulators at once, and the code review doesn't wait for them.

**Blocked by:** none.

**Status:** needs-triage

Found during ticket 15, 2026-10-24. A one-line change to `StatusLabel` (`App/Design/`) set off the full walk, about an hour, before review could start. Brian asked for this ticket and for it to come before 16 and 17.

## The problem

`scripts/screenshots.sh` runs everything one step at a time. For each simulator, each variant is its own `xcodebuild test-without-building` pass over every `ShotsUITests` method. A full run is 2 simulators × 4 variants, back to back.

Three things make a ticket wait for it:

- `docs/agents/device-testing.md` (Simulator screenshots, step 1) asks for the whole walk whenever `App/Design/` changes. `StatusLabel` is used on only three screens (My Day, Now, Reminder Details), but the rule shot all 13 tests.
- The two simulators are shot one after the other, though the harness is built once before the loop and they share nothing else.
- In ticket 15 the review waited for the shots, though it needs no simulator.

## What it should do

- [ ] `device-testing.md` says to trace a changed `App/Design/` component to its call sites, as for any other view, and shoot only the tests that reach them. The full walk is kept for a change to the design tokens, a shared view modifier with no call sites to trace, or the harness's seed, and runs once before the PR, not before review.
- [ ] `scripts/screenshots.sh` shoots the simulators in the matrix at the same time once the harness is built. Each simulator's text size and appearance are still put back, the harness is still uninstalled, and a simulator the script booted is still shut down, even after a failure.
- [ ] A failure on one simulator still fails the run, and the output says which simulator and variant failed. Each simulator's lines can be told apart.
- [ ] `review.md` (Finish order) and `ticket-workflow.md` (steps 6 and 7) let the code review start once `scripts/test.sh` passes, while the screenshots run. Fixes from either one are made after both finish.
- [ ] A run of `SHOTS_TESTS="testMyDay" SHOTS_VARIANTS="largest-text largest-text-landscape"` on both simulators takes about half as long as it did before. Both timings are recorded in Comments.

## Before you start

- Builds on: ticket 15 (Comments): which shots it needed, and how long the full walk took.
- Watch for: the iOS 26.5 simulator can stop turning to landscape (tickets 12, 14). Check whether shooting both simulators at once makes it happen more often, and keep the reshoot advice in `device-testing.md` true.
- Not in scope: splitting the tests across simulator clones with Xcode's parallel testing. Whether clones keep the original simulator's text size is unchecked.
- Developer stops: none expected beyond review. No `tdd` seams: a shell script and docs.

## Comments
