# One release branch per feature, merged to main once

Each feature (milestone) has a branch, `release/<version>`. Ticket PRs merge into it, and it merges into `main` once, as the release PR; the version tag goes on that merge commit. `main` holds only released code, so several features can be built at the same time without mixing.

A ticket PR into a release branch doesn't close its ticket: GitHub honours `Closes #<n>` only for a PR into the default branch. The agent closes the ticket by hand after the merge, and the release PR's `Closes` lines are a backstop.

## Considered Options

- **Everything to `main`, one feature at a time.** Rejected: a second feature has to wait, or lands half-built beside the first.
- **Long-lived feature flags on `main`.** Rejected: the store and alarm changes can't hide behind a flag, and each flag would need its own tests and cleanup.

## Consequences

- When `main` gains a release, it is merged (not rebased) into every open release branch; a branch with open PRs is shared.
- A feature that builds on unreleased code is cut from that feature's branch (the spec's `Base:` line) and merges to `main` after it.
- CI runs on pushes to `main` and `release/**`, and on every PR.
