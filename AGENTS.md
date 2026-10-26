## Agent skills

### Issue tracker

Issues and specs are GitHub issues: one milestone per feature, a `spec` issue with its tickets as sub-issues. See `docs/agents/issue-tracker.md`. No feature is open. `testflight-readiness` (the 1.1.0 TestFlight build), `enhancement-pace` (1.1.0) and `first-version` (1.0.0) are released; their tickets are at the `tickets-archive` tag. Versions and releases: `docs/agents/issue-tracker.md`.

A ticket is `resolved` only when every acceptance criterion is ticked. While one is open, the issue stays open. Say which criterion is open and why, and resolve it with the user: meet it, or agree a change to it (reworded, or moved to a named ticket) and record that agreement in Comments.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Design system

Colors, type, spacing, shapes and components are in `docs/design/DESIGN.md`. UI stories meet it; screen layout is the mockup under `docs/mockups/`.

### Code review and session size

How a ticket is reviewed and how to keep a session small: `docs/agents/review.md`.

### Ticket workflow

Starting a ticket, opening its PR, or told its PR merged: `docs/agents/ticket-workflow.md`.

## Apple platform questions

For any iOS design, implementation or testing question, or any Xcode question, look it up with the `apple-rag-mcp` tools before answering or deciding: `search` first, then `fetch` for a full page. Don't answer from memory.

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

### AlarmKit

Apple's AlarmKit docs confirm that scheduling fails silently without a non-empty `NSAlarmKitUsageDescription`, and that the app must handle the `denied` authorization state in its UI. On the iPhone, alert-only alarms ring through silent mode and Do Not Disturb, with or without the widget extension (first-version ticket 02).

AlarmKit's authorization state comes from `AlarmAdapter` (`permissions(updating:)`), never from `AlarmManager` directly: on the iPhone that synchronous read froze the app for 69 s, and once for good (ticket 22). `scripts/test.sh` fails on a direct read outside `App/Alarms/AlarmManaging.swift`. When the adapter reads it, and why the update stream alone isn't enough: its doc comments.

### Testing

- Automated tests always run against **both** the `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` simulators; `scripts/test.sh` does this. The iOS 26.1 simulator is dropped from the matrix for now, though 26.1 stays the minimum. Don't narrow it to one simulator to get a pass.
- A story that changes something on screen has its visual criteria checked on both simulators first, in portrait, landscape and a large text size. Once they pass there, offer the person a run on the physical iPhone; they decide whether to take it.
- Simulators don't cover AlarmKit behavior, so device checks stay on a physical iPhone and record which phone and iOS version they ran on. There is one test iPhone for now, on iOS 27.x, so the iOS 26 path of anything behind `if #available` is checked on the iOS 26.5 simulator. Detail: `docs/agents/device-testing.md`.
- Run everything with `scripts/test.sh` before committing. UI, VoiceOver and AlarmKit behavior can't be checked in unit tests, so mark those as device checks.
- Any test run on the physical iPhone is safe and leaves the phone exactly as it found it. Each test undoes everything it changed: pending and delivered notifications, scheduled alarms, stored data, and the app's own state. The cleanup runs even when the test fails, so put it in a `defer` or in a class or actor suite's `deinit`, which Swift Testing runs after each test. A test acts only on what it created, found by its own identifiers, and leaves the person's reminders, notifications from other apps, and system settings (permissions, Focus, Time Sensitive) as they were. If a test can't undo something, make it a manual device check instead. Before a device run, note whether the app is installed (`xcrun devicectl device info apps`). If it wasn't, uninstall it afterwards, which also resets its permissions. If it was, keep it and its data.
- Uninstalling does **not** remove the app's AlarmKit alarms on a device, so a device test cancels every alarm it schedules and doesn't assume a fresh install holds none. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`). History and detail: `docs/agents/device-testing.md`.
- When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time and wait for their go before each run. If a run does not do what you said it would, stop and explain before running anything else. Procedure: `docs/agents/device-testing.md`.
