# Free and Pro

What the app charges for and what stays free. Writing a spec, a ticket or a milestone, or building a feature that someone might pay for: read this.

The developer decided this on 2026-11-20. On 2026-11-27 they moved the App Store launch to 1.7.0: the Pro unlock (spec #474) ships in it, in English, and the milestones after it ship as App Store updates. On 2026-11-28 they moved the Accessibility Nutrition Labels (spec #257) to 1.7.1, so the launch claims no labels.

## The model

- One app, with a free tier and one **Pro** unlock: a one-time, non-consumable in-app purchase at $4.99. There is no second app and no subscription.
- The aim is modest income, reach first. The free tier does the app's whole core job on its own.
- Purchases are verified on the device with StoreKit 2. The app uses no server, no account and no analytics for them, so the App Store privacy label stays "Data Not Collected" (`privacy-compliance.md`).
- Family Sharing is on for Pro, there is a Restore Purchases button, and the developer enrolls in Apple's Small Business Program.
- Apple handles refunds. The app needs no refund policy of its own.

## Free

- Reminders, repeats, strengths and paces, Break through Focus, tags, My Day and Sent.
- The bundled alarm tones and the Default Alarm Sound.
- Quiet hours and the other 1.6.0 items, localization and accessibility.
- **Receiving** reminders, from any number of Connections, and accepting Invites: always free, and they never use the free connection.
- **One free connection**: the one Connection a person without Pro sends reminders to.

## Pro

- Sending to more than one Connection: the sender pays. Receiving stays free so every Pro sender brings in free recipients who install the app.
- Siri and Shortcuts (1.8.0), Apple Watch (1.9.0) and accent color (1.10.0).

Sending beyond the free connection is gated from 1.7.0; before it, sharing shipped ungated in TestFlight builds only. Every later Pro feature ships gated from its first version: its spec says `Tier: Pro`, and its gate ticket sits in its own milestone.

## Connections

The developer decided these on 2026-11-28 (spec #474). The terms are in `GLOSSARY.md` (Pro, Free connection, Pro screen).

- A person without Pro can be connected with any number of people, and receives from all of them. They send reminders to one Connection only, their **free connection**; every other Connection is receive-only for them. Accepting an Invite and receiving never use it.
- The free connection is the Connection they started with their own Invite, held from the moment the Invite is sent (cancelling it frees it). With none, it is the first Connection they send a reminder to.
- Ending the free connection frees it, and nothing is picked automatically: the next Invite or the next first send picks it.
- On Send To, a receive-only Connection shows a Pro badge, and tapping it opens the Pro screen.
- Losing Pro (Apple refunds it, or the person leaves the family that bought it) puts the person back to one free connection, which they pick: on the next open, a sheet asks which Connection to keep sending to (none when they have only one). Until they pick, every Connection has the Pro badge, and the sheet returns on each open. Reminders already sent stay on the recipients' phones; changing one counts as sending; cancelling and Disconnect always work.
- TestFlight testers get Pro free with a one-time offer code the developer sends at launch. The app has no tester rule: in TestFlight, the first-installed version always reads "1.0".

## Each new feature

Every new milestone's spec states **Pro or free** in its own line, and the developer decides. Don't assume a feature is free, and don't gate one without asking. Gating a feature that was free in a released version needs the developer's explicit go: people already have it.
