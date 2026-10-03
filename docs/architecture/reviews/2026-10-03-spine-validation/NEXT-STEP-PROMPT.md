# Prompt for the next session: update the architecture spine

Paste everything below the line into a new Claude Code session once PR
`docs/align-precedence-and-mockup` is merged.

---

# Task: update the Nudge-inator architecture spine (bmad-architecture, Update mode)

## Before you start
1. Confirm that the PR `docs/align-precedence-and-mockup` is merged into `main`. If it isn't, stop and tell me.
2. Update `main` and run `git fetch --prune`. Then run `git branch -d` on each local branch that is
   merged and has a `[gone]` upstream; never use `-D`. Tell me which branches you deleted.
3. Create a branch from `main`: `architecture/spine-update`.

## Goal
Run the `bmad-method:bmad-architecture` skill in **Update** mode on
`docs/architecture/ARCHITECTURE-SPINE.md` to close the findings from the 2026-10-03 validation.
Work from the spine's decision log (`docs/architecture/.memlog.md`). Keep AD IDs stable: amend a
Rule in place, add new ADs as the next number, never renumber. Run the skill's Reviewer Gate before
closing. Then re-run validate mode and tell me what's left.

## Read first
- `docs/architecture/reviews/2026-10-03-spine-validation/README.md` gives the index, what was reviewed
  and what was verified.
- `report.md` in that folder has the merged critical and high findings (2 critical, 13 high),
  overlaps, which predate the last branch, and three AD-4/AD-6/AD-15 items routed from a later pass.
- `review-rubric.md`, `review-currency.md` and `review-adversarial.md` in that folder have the full
  evidence and suggested fixes for every finding, including medium and low. They also list what was
  confirmed current and what was checked and holds, so don't redo those without a reason.
- The spine, its `.memlog.md`, `docs/product/brief.md` (§3, §4, §10), `docs/design/EXPERIENCE.md`,
  and the product and design `.memlog.md` files for the reasons behind decisions.
- Precedence is set once, in the brief's introduction. Decision logs record reasons only.

The reviews describe the spine as of commit `78238ee`. Check each finding against the current text
before acting on it.

## How I want you to work
- **Decisions.** For each finding or group that needs a decision, give me the two most relevant
  options with your recommendation first. Use the question tool, up to four per batch. Recommend the
  option that leaves the rule stated in one place and removes or narrows rather than adds, so a
  later review won't find something new in my choice. When I question an option, explain where the
  rule came from (git history, memlogs) before re-asking.
- **What to defer.** Defer only what can truly be learned only in the simulator or on a device;
  those go to the spine's Deferred list or brief §10's device checklist. Before calling anything
  device-only, check Apple's documentation with the `apple-rag-mcp` tools (search and fetch) and the
  web.
- **One rule, one home.** Before changing any rule, search `docs/product`, `docs/design`,
  `docs/architecture` and the mockup README for every statement of it. Update all of them, or point
  them to one home, in the same commit. If an AD change alters a rule the brief or EXPERIENCE
  states, update that source too, and ask me first if it's a product rule.
- **Commits.** Make one commit per item or decision on `architecture/spine-update`, with a message
  that says what was wrong and what changed. Don't push or open a PR until I ask.
- **Decision logs.** Record each decision, with the option I didn't choose, in
  `docs/architecture/.memlog.md`, and in the product or design memlog when those docs change. Use
  each log's existing format; there's no memlog.py helper in this repo.
- **Verification.** Verify claims before stating them, and say plainly what you checked and what
  you didn't. When subagents review, merge overlapping findings and check a sample against the files
  yourself. Mark the validation folder's README status as closed when you're done.
- **Mockup.** If you touch the mockup, run `docs/mockups/2026-10-02-ux-review-changes/checks/run-checks.sh`
  (behavior and axe) and follow the conventions in that folder's README. In particular, a new check
  must fail on the commit before its fix.

## Done when
- Every critical and high finding is resolved in the spine. A finding that's truly device-only can
  instead be recorded in Deferred and on the device checklist, with what would settle it.
- Every medium and low finding is resolved, deferred with a reason, or dropped with my agreement.
- A fresh validate-mode run shows no critical or high findings.
- Every changed rule is stated in one place across the four directories.
- The decision logs are updated, and you've given me a short summary of each decision and what's
  left.
