# 18: Screenshot runs take minutes, not an hour

**What to build:** A ticket's simulator screenshots shoot only the screens its change reaches, on both simulators at once, and the code review doesn't wait for them.

**Blocked by:** none.

**Status:** resolved

Found during ticket 15, 2026-10-24. A one-line change to `StatusLabel` (`App/Design/`) set off the full walk, about an hour, before review could start. Brian asked for this ticket and for it to come before 16 and 17.

## The problem

`scripts/screenshots.sh` runs everything one step at a time. For each simulator, each variant is its own `xcodebuild test-without-building` pass over every `ShotsUITests` method. A full run is 2 simulators × 4 variants, back to back.

Three things make a ticket wait for it:

- `docs/agents/device-testing.md` (Simulator screenshots, step 1) asks for the whole walk whenever `App/Design/` changes. `StatusLabel` is used on only three screens (My Day, Now, Reminder Details), but the rule shot all 13 tests.
- The two simulators are shot one after the other, though the harness is built once before the loop and they share nothing else.
- In ticket 15 the review waited for the shots, though it needs no simulator.

## What it should do

- [x] `device-testing.md` says to trace a changed `App/Design/` component to its call sites, as for any other view, and shoot only the tests that reach them. The full walk is kept for a change to the design tokens, a shared view modifier with no call sites to trace, or the harness's seed, and runs once before the PR, not before review.
- [x] `scripts/screenshots.sh` shoots the simulators in the matrix at the same time once the harness is built. Each simulator's text size and appearance are still put back, the harness is still uninstalled, and a simulator the script booted is still shut down, even after a failure.
- [x] A failure on one simulator still fails the run, and the output says which simulator and variant failed. Each simulator's lines can be told apart.
- [x] `review.md` (Finish order) and `ticket-workflow.md` (steps 6 and 7) let the code review start once `scripts/test.sh` passes, while the screenshots run. Fixes from either one are made after both finish.
- [x] A run of `SHOTS_TESTS="testMyDay" SHOTS_VARIANTS="largest-text largest-text-landscape"` on both simulators takes no more than 60% of the time it did before. Both timings are recorded in Comments.

## Before you start

- Builds on: ticket 15 (Comments, "The fix, the drifts, and the shots"): the full walk took 61 min on one simulator; a targeted run of `testMyDay` (iOS 26.5) and `testMyDay testNow` (iOS 27.0), four variants each, took 18 min one simulator after the other. Neither is the run in the last criterion, so time that run on `main` before changing the script.
- Watch for:
  - Every invocation builds the harness into the same `.build/screenshots`, so two copies of the script can't run side by side. Build once, then shoot the simulators in parallel inside one run.
  - Stopping a run part-way (ticket 15) left the harness and its UI-test runner installed on `iPhone 15 - iOS 27.0`, and both simulators booted. The `EXIT` trap didn't finish. With background jobs per simulator, make sure an interrupted run still cleans up every simulator.
  - The iOS 26.5 simulator can stop turning to landscape (tickets 12, 14). Check whether shooting both simulators at once makes it happen more often, and keep the reshoot advice in `device-testing.md` true.
- Not in scope: splitting the tests across simulator clones with Xcode's parallel testing. Whether clones keep the original simulator's text size is unchecked.
- Developer stops: none expected beyond review. No `tdd` seams: a shell script and docs.

## Comments

### Timings, and the open criterion (2026-10-24)

`SHOTS_TESTS="testMyDay" SHOTS_VARIANTS="largest-text largest-text-landscape"`, both simulators, run with `time`:

| Script | Total |
|---|---|
| `main` (one simulator after the other) | 6 min 56 s |
| Simulators at the same time | 4 min 2 s (58%) |
| Same, plus booting the simulators while the harness builds | 4 min 32 s (65%) |

The third was a variant I dropped: it showed no gain over the second, and the runs differ more than the change would (the same test on the iOS 26.5 simulator wrote 12, 14 and 20 screenshots in `largest-text`).

**Criterion 5 was open: 58% is not "about half".** Parallel by simulator can't get below the slower simulator's own run plus the setup (xcodegen, boot, build, about 50 s). Getting nearer half takes something this ticket puts out of scope (splitting tests across simulator clones), or a looser reading of the criterion. Needs a decision: accept 4 min 2 s as met, or reword it (for example "no more than 60% of the time").

Checked by hand:

- A failure on one simulator (a stand-in `xcodebuild` that fails for the iOS 26.5 simulator only): the other kept shooting, the run exited 1, each simulator's lines were prefixed `[<simulator>]`, and the summary listed `iPhone 15 Pro - iOS 26.5, portrait` and `..., landscape`.
- `SIGTERM` to the script 40 s into a run: it stopped both `xcodebuild` runs, exited 143, shut down both simulators it had booted and uninstalled the harness from both. (`SIGINT` can't be sent to a background job, but it takes the same trap.)
- Landscape on the iOS 26.5 simulator turned in every parallel run (19 screenshots, as on `main`). Three runs is too few to say it never fails, so the reshoot advice stands as it was.
- A `SHOTS_TESTS` name that doesn't exist passes with 0 screenshots, as before this ticket. Not changed here.

Review (Standards, Spec, code smells; no Apple files, so no iOS reviewer): no hard violations. Fixed: the temp directory leaked if `xcodegen` failed; a simulator's run that died without writing a failure was not counted (now it fails the run); an interrupt during the harness build waited out the build (the build now runs in the background, and `SIGTERM` 4 s into it exited at once and shut the simulator down); the header and docs claimed every line is prefixed (now "each simulator's lines"); `ticket-workflow.md` didn't say the full walk runs before the PR (step 7 excepts it, step 9 runs it); the timing history left `device-testing.md` for these Comments. Not changed: the simulators share one `-derivedDataPath`, which worked in every parallel run that reached the tests (two timed, one failure test, one plain run) but is unproven beyond that.

Decision (Brian, 2026-10-24): criterion 5 reworded from "about half as long" to "no more than 60% of the time it did before". 4 min 2 s against 6 min 56 s is 58%, 42% faster, and that is good enough; going further needs simulator clones, out of scope. Criterion ticked, ticket resolved. Brian also accepted, as they stand: the iOS 26.5 landscape advice unchanged, the shared `-derivedDataPath`, and a nonexistent `SHOTS_TESTS` name passing with 0 screenshots. Ticket 19's file is left out of this branch.
