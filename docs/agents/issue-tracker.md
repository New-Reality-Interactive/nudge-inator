# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `New-Reality-Interactive/nudge-inator`. Use the `gh` CLI for all operations; it infers the repo from `git remote -v`.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..." --milestone "<version>"`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --json number,title,body,labels,milestone,comments`.
- **List issues**: `gh issue list --state open --json number,title,labels,milestone --jq '[.[] | {number, title, labels: [.labels[].name], milestone: .milestone.title}]'` with `--milestone`, `--label` and `--state` filters.
- **Make an issue a sub-issue of a parent**: `gh issue create --parent <parent> ...`, or `gh issue edit <parent> --add-sub-issue <child>` afterwards.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Tick a criterion**: acceptance criteria are a task list (`- [ ]`) in the issue body. Edit the body with `gh issue edit <number> --body-file <file>` after reading it fresh, never from a stale copy.
- **Close**: `gh issue close <number> --comment "..."`

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## Features, specs and tickets

- **Feature**: one milestone per feature, titled with its version (`1.2.0`). The milestone description names the feature's slug (`enhancement-tags`), used in branch names.
- **Spec**: one issue labelled `spec`, in the feature's milestone. Its body starts with a `Version:` line.
- **Ticket**: one issue per ticket, a sub-issue of the spec and in the same milestone, numbered by GitHub (`#83`). A ticket starts `ready-for-agent`, or `ready-for-human` when its steps are the developer's.
- **Blocked by**: GitHub's native issue dependencies: `gh api --method POST repos/New-Reality-Interactive/nudge-inator/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is `gh api repos/New-Reality-Interactive/nudge-inator/issues/<n> --jq .id` (the database id, not the `#number`). A ticket is unblocked when every blocker is closed.
- **Resolved**: the ticket is closed as completed, by its PR's `Closes #<n>` or by hand. AGENTS.md says when a ticket may be resolved.
- **Comments**: issue comments, including each agreed change to a criterion.
- **A new ticket**, including a bug found while working another, goes in the open feature's milestone as a sub-issue of its spec. A released feature's milestone gets no new tickets.
- **A split ticket**: the new part is its own issue. The tickets the original blocked are also blocked by the new one, and both issues' comments record the split.

## Features and versions

Each feature is one release, versioned on the spec's `Version:` line and in its milestone title, chosen when the spec is written:

- **Major:** something existing stops working for people who update: a capability removed, or data that can't carry over.
- **Minor:** a new capability, or an existing one extended, that carries existing reminders and settings forward.
- **Patch:** fixes only.

From 1.2.0 on, a feature updates in place: when it changes a capability, its spec plans how existing data and settings migrate.

Bugs found while no feature is open go in a patch milestone (`1.1.1`), whose spec issue is the `Version:` line and one line on what it fixes.

When a feature's last ticket is resolved and merged, it's released: the spec issue and the milestone are closed, the developer tags `v<version>` on `main` and sets `MARKETING_VERSION` in `project.yml`, and AGENTS.md's open feature moves to the next one.

## Tickets before GitHub Issues

Features up to 1.1.0 (`first-version`, `enhancement-pace`, `testflight-readiness`) were tracked as markdown files under `.scratch/`, removed from the tree after the tag `tickets-archive`. In comments and docs, "ticket NN" (or "<feature> ticket NN", or a `.scratch/...` path) means `.scratch/<feature>/issues/NN-*.md` at that tag: `git show tickets-archive:.scratch/<feature>/issues/<file>`, or `git ls-tree -r --name-only tickets-archive .scratch` to find it. New references use `#<n>`.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in the open feature's milestone. A spec gets the `spec` label; a ticket becomes a sub-issue of its spec.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a sub-issue. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: native issue dependencies, as in **Blocked by** above.
- **Frontier query**: list the map's open sub-issues, drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
