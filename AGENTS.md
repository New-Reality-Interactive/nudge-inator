## Agent skills

`CLAUDE.md` only imports this file, so `setup-matt-pocock-skills` updates this block here.

### Issue tracker

Issues and specs are GitHub issues: one milestone per feature, a `spec` issue with its tickets as sub-issues. See `docs/agents/issue-tracker.md`. The open feature is the lowest-numbered open milestone: `gh api 'repos/New-Reality-Interactive/nudge-inator/milestones?state=open' --jq '[.[].title] | sort_by(split(".") | map(tonumber)) | first'`; its description names the slug and the spec. A higher open milestone is a later feature, already specced: its spec and tickets go there, and nothing else does. With none open, a bug found now goes in a patch milestone.

### Releases

Versions, backwards compatibility, migrations and the release steps: `docs/agents/release.md`. A change that can't stay backwards compatible, or a proposed version that doesn't fit its change: tell the developer before any work begins.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Design system

Colors, type, spacing, shapes and components are in `docs/design/DESIGN.md`. UI stories meet it; screen layout is the latest version mockup, `docs/mockups/<version>/`, or a change's mockup for what it changes. New mockups start from `docs/mockups/*-mockup-template/`.

### Code review and session size

How a ticket is reviewed and how to keep a session small: `docs/agents/review.md`.

### Ticket workflow

Starting a ticket, opening its PR, or told its PR merged: `docs/agents/ticket-workflow.md`.

## Apple platform questions

For any iOS design, implementation or testing question, or any Xcode question, look it up with the `apple-rag-mcp` tools before answering or deciding: `search` first, then `fetch` for a full page, or for a page you have the URL of, since `fetch` reads pages `search` doesn't surface. Don't answer from memory.

- Say what the docs confirm and what they don't. If they're silent, mark it as a device check instead of guessing.
- If `apple-rag-mcp` has nothing on a page (for example a support.apple.com guide), say so before falling back to another source.

## Project

Nudge-inator is a Swift 6, SwiftUI, iPhone-only app (iOS 26.1 minimum) with a widget extension and two local packages. `project.yml` is the source of truth for the Xcode project: edit it, then run `xcodegen generate`. Never hand-edit the generated `.xcodeproj`.

### Coding standards

Writing or reviewing Swift, a SwiftUI view, a string a person sees, accessibility, or a test: `CODING_STANDARDS.md`.

### Toolchain

The project builds with **Xcode 27.x and the iOS 27 SDK** on an Apple silicon Mac. The minimum stays iOS 26.1, so an iOS 27-only API is allowed only behind `if #available(iOS 27, *)` with an iOS 26 path beside it. Setting up a Mac (selecting Xcode, creating the simulators): `README.md`. The Mac's versions, rationale and history: `docs/agents/device-testing.md`.

### Structure

- `Packages/NudgeEngine` is pure Swift: no Apple framework imports, `Foundation` at most. `scripts/test.sh` enforces this. Anything that touches Apple frameworks (AlarmKit, store, adapters) lives in the app target, behind a type the engine can use without importing the framework.
- `Packages/NudgeShared` holds only code that both the app and the widget extension compile (AlarmKit `AlarmMetadata`, the Open intent).
- `Packages/NudgeEngine`'s `NudgeDeviceSeed` target is pure Swift too (`Foundation` and `NudgeEngine`). It is no product: the app compiles its folder in Debug builds only (every file is wrapped in `#if DEBUG`): sets of test data a launch loads for manual device checks (`docs/agents/device-testing.md`). Release builds contain none of it; `scripts/check-release-has-no-seed.sh` checks.

### AlarmKit

Apple's AlarmKit docs confirm that scheduling fails silently without a non-empty `NSAlarmKitUsageDescription`, and that the app must handle the `denied` authorization state in its UI. On the iPhone, alert-only alarms ring through silent mode and Do Not Disturb, with or without the widget extension (first-version ticket 02).

AlarmKit's authorization state comes from `AlarmAdapter` (`permissions(updating:)`), never from `AlarmManager` directly: on the iPhone that synchronous read froze the app for 69 s, and once for good (ticket 22). `scripts/test.sh` fails on a direct read outside `App/Alarms/AlarmManaging.swift`. When the adapter reads it, and why the update stream alone isn't enough: its doc comments.

### Testing

- Automated tests always run against **both** the `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.2` simulators; `scripts/test.sh` does this. The iOS 26.1 simulator is dropped from the matrix for now, though 26.1 stays the minimum. Don't narrow it to one simulator to get a pass.
- A story that changes something on screen is checked in this order: `scripts/test.sh`; the review and its fixes; then the phone check (the default; the developer can opt out on a ticket), one step at a time, and its fixes. The phone is the only place the screens are checked: the developer's one phone pass per ticket covers the acceptance criteria, landscape, the largest text size and the mockup comparison. There are no simulator screenshot runs, per ticket or per release. The order in full: `docs/agents/ticket-workflow.md`, steps 7 and 8.
- Simulators don't cover AlarmKit behavior, so device checks stay on a physical iPhone and record which phone and iOS version they ran on. There is one test iPhone for now, on iOS 27.x, so the iOS 26 path of anything behind `if #available` is covered only by the tests `scripts/test.sh` runs on the iOS 26.5 simulator; nothing looks at it on screen (a gap the developer accepted on 2026-11-09). Detail: `docs/agents/device-testing.md`.
- Run everything with `scripts/test.sh` before committing a change to code or tests (Swift, `project.yml`, the scripts, the packages). A change to docs or Markdown alone skips it: CI skips those too. UI, VoiceOver and AlarmKit behavior can't be checked in unit tests, so mark those as device checks.
- Any test run on the physical iPhone is safe. The phone is the primary test device while a milestone is built, and it holds no data the developer needs kept. A test or check seeds the data its steps need (a seed set, `docs/agents/device-testing.md`, Seeding test data) so the steps are easy to follow, and when it finishes, everything it seeded or changed is removed automatically, with no step left to the developer. The cleanup runs even when the test fails, so put it in a `defer` or in a class or actor suite's `deinit`, which Swift Testing runs after each test, and run `NUDGE_SEED=clean` after a manual check. A test acts only on what it created or seeded, found by its own identifiers: it removes that and nothing more. It never uninstalls the app, and it leaves system settings (permissions, Focus, Time Sensitive) as they were. If a test can't undo something, make it a manual device check instead.
- Uninstalling does **not** remove the app's AlarmKit alarms on a device, so a device test cancels every alarm it schedules and doesn't assume a fresh install holds none. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`). History and detail: `docs/agents/device-testing.md`.
- When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time and wait for their go before each run. If a run does not do what you said it would, stop and explain before running anything else. Procedure: `docs/agents/device-testing.md`.
