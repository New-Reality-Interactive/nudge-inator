# Free and Pro

What the app charges for and what stays free. Writing a spec, a ticket or a milestone, or building a feature that someone might pay for: read this.

The developer decided this on 2026-11-20. The App Store launch happens after every milestone defined at that date has shipped. The Pro unlock itself is the 1.12.0 milestone, after 1.11.0.

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
- **Receiving** shared reminders: always free, and it never uses the free connection.
- **One sharing connection.**

## Pro

- Sharing beyond one connection: the sender pays. Receiving stays free so every Pro sender brings in free recipients who install the app.
- Apple Watch (1.8.0), Siri and Shortcuts (1.7.0) and accent color (1.9.0).

Until 1.12.0 adds the gate, the Pro features above ship ungated in TestFlight builds. Their tickets still say they are Pro, so 1.12.0 knows what to gate.

## Connections

- The free connection counts only people you send to, never people who send to you. Ending a connection frees it.
- If Pro is revoked (a refund, or a family member removed), existing connections keep working. Only adding a connection beyond the free one is blocked. The gate is checked once, at the moment a connection is added.
- TestFlight testers get Pro free. How is decided in the 1.12.0 spec.

## Each new feature

Every new milestone's spec states **Pro or free** in its own line, and the developer decides. Don't assume a feature is free, and don't gate one without asking. Gating a feature that was free in a released version needs the developer's explicit go: people already have it.
