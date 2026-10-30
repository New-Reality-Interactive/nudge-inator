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

When a feature's last ticket is resolved and merged, it's released, in this order:

1. **Release PR.** The agent opens one that:
   - adds the version mockup, `docs/mockups/<version>/` (such as `1.2.0`): copied from the latest version mockup, as the template's README says, drawing the app as built at that version with working mockup controls. It's checked against the app with the screenshot walk (`docs/agents/device-testing.md`, Simulator screenshots) for the screens the release changed (`SHOTS_TESTS`), on both simulators, in portrait, landscape and the largest text size; the whole walk is only for a mockup first lined up with the app;
   - deletes the change mockups the version mockup takes in;
   - sets `MARKETING_VERSION` in `project.yml`, and the version `BuiltBundleTests` pins;
   - adds the TestFlight build's What to Test note to `docs/release-notes/` and passes a trial archive (`docs/agents/device-testing.md`, Archive and upload).
2. **Release.** Once it merges, the agent tags `v<version>` (annotated) on the merge commit on `main` and pushes the tag, then runs the whole walk in portrait on the `iPhone 15 - iOS 27.0` simulator (`SHOTS_VARIANTS=portrait SIMULATORS="iPhone 15 - iOS 27.0"`), zips it as `screenshots-<version>.zip`, and attaches it to the GitHub Release (`gh release create v<version>`, then `gh release upload v<version>`). The screenshots never go in the repo. It closes the spec issue and the milestone.
3. **TestFlight build**, for every release, from the pushed tag: `docs/agents/device-testing.md`, Archive and upload. The developer's steps are the go before the upload and the App Store Connect steps after it.
