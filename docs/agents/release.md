# Releases

How a feature is versioned, what every version must carry forward, and the steps that release it. Starting a spec, checking a version, planning a migration, or releasing: read this.

## Features and versions

Each feature is one release, versioned on the spec's `Version:` line and in its milestone title, chosen when the spec is written:

- **Major:** something existing stops working for people who update: a capability removed, or data that can't carry over.
- **Minor:** a new capability, or an existing one extended, that carries existing reminders and settings forward.
- **Patch:** fixes only.

**Backwards compatible.** Every version carries forward everything the version before it left on the phone:

- the store, with its reminders, tags and histories;
- the Done queue;
- the settings and onboarding records;
- pending notifications and AlarmKit alarms, which survive even an uninstall;
- the identifiers that name all of these.

When a feature changes a capability, its spec plans how that data migrates. The spec's `Compatibility:` line says what carries forward, or names the break the developer accepted. A change that can't stay backwards compatible stops all work: before the spec is agreed or a ticket starts, tell the developer what breaks, for whom, and the options. Only the developer can accept a break, and accepting one makes the version major.

**Reconcile the version.** When the developer proposes a version for a milestone, check it against the change, by the rules above. If they don't match, say so before the spec is agreed, with the version the rules give and why. The developer decides; the spec's `Version:` line and the milestone title follow. Check again whenever the scope changes.

When a feature's last ticket is resolved and merged, it's released, in this order (the developer trimmed the screenshot walks out of it on 2026-11-08: no full gate pass, no screenshots on the GitHub Release; the mockup's check against the app came back on 2026-11-17 as the drift check below, and the website screenshots are a new step):

1. **Release PR.** The agent opens one that:
   - adds the version mockup, `docs/mockups/<version>/` (such as `1.2.0`): copied from the latest version mockup, as the template's README says, drawing the app as built at that version with working mockup controls. Then the **drift check** (the developer's decision, 2026-11-17: the hand-drawn mockup had drifted from the app):
     1. Run `scripts/screenshots.sh` once for the release, portrait, on the iOS 27.2 simulator (`device-testing.md`, Simulator screenshots).
     2. Make a side-by-side contact sheet of each app screen and the mockup's matching screen (`scripts/contact-sheet.sh`, `scripts/mockup-shots.py`).
     3. List every divergence. Fix the HTML where the mockup is wrong. Where the app is wrong, write the developer a ticket; don't copy the bug into the mockup.
     4. Commit a small set of compressed as-built screenshots in the version mockup's folder, as reference; the HTML stays the design source for the next feature's change mockups.
     Landscape and the largest text size stay on the phone check.
   - deletes the change mockups the version mockup takes in;
   - sets `MARKETING_VERSION` in `project.yml`, and the version `BuiltBundleTests` pins;
   - adds the TestFlight build's What to Test note to `docs/release-notes/` and passes a trial archive (`docs/agents/device-testing.md`, Archive and upload). The note opens with a **highlights** section: the changes people will see between the previous release and this one, in plain words, one line each, drawn from the version's tickets and the spec. It ends its tester text with a **COMING SOON** section, drawn fresh from GitHub for every release, never from a saved list: every open milestone above the one being released whose description links a spec, in version order, one line each (`- <version>: <one plain sentence from the spec's Solution>`, no dates), with a one-line invitation to send feedback. List them with `gh api 'repos/New-Reality-Interactive/nudge-inator/milestones?state=open' --jq '.[] | "\(.title)\t\(.description)"'`. A milestone without a spec stays off it, because the note is a public promise to testers. For now the `accessibility-labels` milestone (1.11.0) stays off it too, the developer's call of 2026-11-08; the developer says when it may return. Check that the note's other claims still hold for what the later milestones will change (such as "makes no network connections" once shared reminders ship).
2. **Release.** Once it merges, the agent tags `v<version>` (annotated) on the merge commit on `main` and pushes the tag, creates the GitHub Release (`gh release create v<version>`), closes the spec issue and closes the milestone. No screenshots are attached.
   **Website screenshots** (the developer's decision, 2026-11-17), right after the tag, for every release, from the tagged build: the screenshots of the app page's carousel on newrealityinteractive.com. They are real simulator screenshots of the app, not the mockup, taken as one person's day, with the same made-up people, reminders and times on every screen (a Debug-only `site-shots` seed set), portrait, light, 100% text size, 600 × 1302 px, on the iPhone 15 Pro simulator with iOS 27, with the status bar overridden (`xcrun simctl status_bar`, 9:41, full bars) and no Debug UI showing (the stand-in's menu is on Connections and Settings). They are written to `shots/<version>/` in `/Users/bpm/Work/repositories/new-reality-interactive/nudge-inator`, uncommitted, and nothing else in that repository changes: the developer updates the site later. A `README.md` in that folder gives each slide a recommended title, summary and alt text. The slides are the app's tabs (the carousel at 1.3.0: welcome, Now, My Day, Reminders, New Reminder, Tags) with a slide for each new feature the release ships; for 1.4.0 the Reminders slide is replaced by the Sent view and a Send To page slide is added.
3. **TestFlight build**, for every release, from the pushed tag: `docs/agents/device-testing.md`, Archive and upload. The developer's steps are the go before the upload and the App Store Connect steps after it.
   - **Shared reminders (from 1.4.0):** before the build goes to an external group, a two-device check on the TestFlight build itself, the iPhone and the iPad on the second Apple Account: invite, accept, and send one reminder that arrives. It covers what only the shipped build has, distribution signing and production push, which the Debug two-account checks don't. Walked one step at a time, cleaning up what it made.
     Once the reminder arrives, compare How Sharing Works' pages 3 and 4 (Send a Reminder, Who Sees What)
     with what the send showed on both phones; copy the app contradicts is fixed before the external group
     gets the build (#423's criterion, moved here 2026-11-15, since sending had no device test yet).
     Then, with the iPhone on a fresh TestFlight install (Sharing off, How Sharing Works unseen), two
     checks of the tutorial opening by itself (#424's, moved here 2026-11-15, as the Debug stand-in
     can't drive them): the iPad invites the iPhone and cancels it; the iPhone opens the invite and
     taps Turn On Sharing, and after Invite Unavailable's OK the tutorial opens. Then, with Sharing
     off again and the tutorial unseen (reinstall), open How Sharing Works from its Settings row, open
     a new invite from the iPad and tap Turn On Sharing: report whether the tutorial opens once the
     open sheet and Connected have closed, or never; a bug either finds is fixed before the external
     group gets the build.
   - **Review notes:** while the app isn't on the App Store, the Beta App Review notes and the What to Test note say that sharing needs two Apple Accounts, and how to try it; the What to Test note also tells testers to install the build from TestFlight before opening an invite, since an invite can't lead to an App Store page yet (Brian, 2026-11-15).
