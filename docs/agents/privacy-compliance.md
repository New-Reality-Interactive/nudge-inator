# Privacy and compliance answers

What the app sends to iCloud, and the App Store answers that follow from it. Recorded in
shared-reminders #213 for #327's App Store Connect work. Checked 2026-11-13.

## What goes to iCloud

Only sharing does (spec #127; the records are `SharingRecordMapping`): a sender's reminder content
(title, notes, due time, repeat, strength, pace), the person's name as iCloud gives it, a
recipient's receipt and status, and each person's connection settings. The values are CloudKit
encrypted fields, in the person's own private or shared database. Personal reminders never go.
The app makes no CloudKit request until Connections is opened or an invite is accepted.

## Export compliance: `ITSAppUsesNonExemptEncryption` stays `false`

- CloudKit traffic is encrypted by the system; the app adds no cryptography of its own beyond
  `Insecure.SHA1` for alarm IDs.
- Apple, "Complying with Encryption Export Regulations" (Security framework documentation): set the
  key to `NO` if the app "only uses forms of encryption that are exempt"; "typically, the use of
  encryption that's built into the operating system ... is exempt from export documentation upload
  requirements, whereas the use of proprietary encryption is not."
- Source named by the ticket: App Store Connect Help, "Overview of export compliance". Reached, but
  it doesn't say whether OS-provided encryption is exempt, and it never mentions the key; it defers
  to the article above. The exemption criteria sit on "Export compliance documentation for
  encryption", which wasn't reachable here. Before #327's submission, answer App Store Connect's
  own encryption questions once in the web UI and check they agree (a device-free check for Brian).
- Not covered by either page: the year-end self-classification report. Apple's article says an app
  with exempt encryption "might alternatively be required" to file one with the U.S. government.
  Whether that applies to New Reality Interactive is a legal question, left open for Brian.

## App Store privacy label: is data in the person's own iCloud "collected"?

- Apple, "App privacy details on the App Store": "Collect" refers to transmitting data off the
  device in a way that allows you and/or your third-party partners to access it for a period longer
  than what is necessary to service the request in real time. Apple's frameworks and services:
  "You are not responsible for disclosing data collected by Apple." CloudKit is named there.
- New Reality Interactive has no server and can't read the person's iCloud, and the fields are
  encrypted. So none of it is collected: the label answers **Data Not Collected**, and the manifest's
  collected data types stay empty. If sharing ever gains a server of ours, this is revisited.
- The Apple pages never state the iCloud case outright; this is the definition applied, not a quote.
  Apple's "Manage app privacy" page (App Store Connect Help) was also reached and has no definition.
- The privacy policy (`docs/privacy-policy.md`) still says the app makes no network connections and
  that nothing leaves the iPhone; #327 updates it, with the label.
