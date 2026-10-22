# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading
- A new ticket, including a bug found while working another, goes in the open feature's folder (AGENTS.md, Issue tracker), numbered after its last ticket, in the format of that folder's other tickets. A released feature's folder gets no new tickets.
- A ticket split from an open one keeps its number, and the new part takes the number plus a letter (`07` and `07b`), so it stays in dependency order. Its branch, title and PR use that number (`pace-07b-<slug>`, `# 07b:`, `Ticket 07b (…)`). The tickets it blocked list it in `Blocked by`, and both tickets' Comments record the split.

## Features and versions

Each feature is one release, versioned in its spec on a `Version:` line under `Status:`, chosen when the spec is written:

- **Major:** something existing stops working for people who update: a capability removed, or data that can't carry over.
- **Minor:** a new capability, or an existing one extended, that carries existing reminders and settings forward.
- **Patch:** fixes only.

From 1.2.0 on, a feature updates in place: when it changes a capability, its spec plans how existing data and settings migrate. 1.1.0 (pace) is the exception: its two beta testers delete all data and reinstall.

Bugs found while no feature is open go in a patch feature, such as `.scratch/fixes-1-1-1/`, whose `spec.md` is the `Status:` and `Version:` lines and one line on what it fixes.

When a feature's last ticket is resolved and merged, it's released: its spec's `Status:` becomes `released`, the developer tags `v<version>` on `main` and sets `MARKETING_VERSION` in `project.yml`, and AGENTS.md's open feature moves to the next one.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
