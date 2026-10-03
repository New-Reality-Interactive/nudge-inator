# Adversarial review: ARCHITECTURE-SPINE.md (incompatible-but-compliant unit pairs)

Reviewed: `docs/architecture/ARCHITECTURE-SPINE.md` (as of commit 78238ee), against `.memlog.md`, brief §3/§4/§10 and EXPERIENCE.md.
Method: for each hole, two units one level down that both follow every AD to the letter yet build incompatibly. Only pairs I could build from the text are listed.

**Verdict:** the paradigm is sound, but the reconciler's diff contract, the delivery-ID path through alarms, and the command and event model each leave a gap that two compliant teams would fill in different ways. Two of these break today's new rules: AD-6's delivery-ID dedupe and AD-15's undeliverable settlement.

| Tier | Count |
|---|---|
| Critical | 2 |
| High | 8 |
| Medium | 5 |
| Low | 2 |

---

## Critical

### C1. Delivered notifications sit inside the diff, but the plan doesn't say whether it holds deliveries that already fired

- **Units:** NudgeCore plan builder (AD-1, AD-14) and NudgeShell reconciler diff (AD-6).
- **Text:** AD-6 says the diff runs against "pending requests, delivered notifications, `AlarmManager.alarms`" and "adds what's missing, removes what's extra". AD-1 and AD-14 call the plan "the desired delivery plan", with a horizon running forward and no lower bound. AD-6 Cleanup removes delivered notifications only when their occurrence is closed, plus expired follow-ups and keep notices.
- **Build A:** the plan holds only future deliveries, since a plan is for scheduling. The diff then sees nudges 1–3 of an open occurrence in the delivered list, finds them in no plan entry, and removes them as extra. Notification Center gets wiped on every reconcile while the occurrence is still nudging, which contradicts Cleanup.
- **Build B:** the plan keeps the open occurrence's past deliveries so they aren't treated as extra. The person then **Clears** nudge 3 (AD-17 records the Clear), the delivered list no longer has it, and the next reconcile re-adds it because it's missing. The same loop re-posts `followup/<key>` after the person clears it ("sent at once" has a past fire instant), and it would re-add a rung-out alarm with a past `.fixed` schedule.
- **Why both comply:** "never against the ledger" removes the only record that says "already handed over", so neither build can tell "fired" from "never sent".
- **Close (tighten AD-6 and AD-14):**
  - The plan holds only deliveries whose fire instant is after `now`. The Done follow-up is the one exception, planned once.
  - The diff compares the plan with **pending requests and alarms only**.
  - Delivered notifications are never added or replaced. They are removed only by the Cleanup rules.
  - A planned item whose ID already has a ledger row past its fire instant is never re-added. This is the single permitted ledger read, and the follow-up depends on it.

### C2. An alarm's intent can't recover the delivery ID it answers, so AD-6's new dedupe never matches

- **Units:** NudgeLiveActivity snooze, stop and Done intents (AD-3, AD-12) and the reconciler's uncounted-snooze adoption (AD-6).
- **Text:**
  - AD-3: events record "the delivery ID it answered".
  - AD-7: the AlarmKit ID is a one-way hash, `UUIDv5(deliveryID)`, and the alarm's metadata carries the occurrence key, the nudge index and the title, but not the delivery ID.
  - AD-6: adoption is skipped only if "no `snooze` with that alarm's delivery ID is committed or still waiting".
- **Build A (intent):** builds the delivery ID from metadata as `nudge/<key>/<n>`, since that's all the metadata carries. For the second snooze of nudge n, the countdown alarm is really `snooze/<key>/<n>/1`, so the recorded ID is wrong.
- **Build B (reconciler):** maps the countdown alarm's UUID back to `snooze/<key>/<n>/1` by hashing the plan's IDs. It finds no `snooze` with that ID, adopts the alarm, and counts it again. The third snooze is spent early, and the post-snooze alarm loses its Snooze button.
- **Close (tighten AD-7):** every notification's `userInfo` and every alarm's `NudgeAlarmMetadata` carry the **full delivery ID string**, alongside the key and nudge index. Intents and the delegate take the ID from there and never rebuild it. Add a round-trip test from metadata to command to adoption check.

---

## High

### H1. Commands from the app, Siri and Assistive Access answer no delivery, so "a command about it" is undefined

- **Units:** in-app nudge card, Siri "Snooze Nudge-inator", and the Assistive Access card (command producers), against the reconciler (AD-6's "Alarms in progress" and "Uncounted snoozes").
- **Text:** AD-3 says the delivery ID is recorded "when there is one". AD-6 never removes an alerting alarm "until a command about it has been committed".
- **Build A:** the card's Snooze carries no delivery ID. The reconciler reads "about it" as "carries this alarm's ID", so it leaves the alarm ringing in the Dynamic Island after the person snoozed in the app.
- **Build B:** the reconciler reads "about it" as "about its occurrence" and removes the alarm. Now take the case where the person tapped Snooze on the alarm before the first unlock (so the countdown is running) and then taps Snooze on the card after unlocking. The card's snooze has no ID, so the adoption check doesn't find it, the countdown is adopted as well, and the occurrence records 2 snoozes for 1 intent.
- **Close (AD-4 and AD-6):**
  - Before `accepts` runs, the coordinator stamps any command that has no delivery ID with the occurrence's current delivery from the engine: the alerting or counting-down alarm, or else the latest delivered nudge.
  - "A command about it" means a committed event on the same occurrence with `issuedAt` at or after the alarm's fire instant.

### H2. Event order and `accepts`' view of the facts are undefined, and backdated events now exist

- **Units:** the Coordinator and NudgeStore projections (write order) against the NudgeCore fold, History and Export (read order).
- **Text:**
  - AD-4: `accepts(command, facts, at: issuedAt)`.
  - AD-6: an adopted snooze gets `issuedAt` = the alarm's past fire time.
  - AD-16: journal replay commits commands issued hours earlier.
  - AD-3: says nothing about ordering.
- **Build A:** the store returns events in commit (rowid) order, and `accepts` sees every committed fact. A Siri Snooze issued at 8:30:00 that commits after a notification Done issued at 8:30:01 is rejected.
- **Build B:** the engine folds events by `issuedAt`, and `accepts` slices the facts as of `issuedAt`. The same Snooze applies, and its event sorts before the Done. After a later Not Done, the engine treats the occurrence as still snoozed until 8:45, while Build A schedules the next nudge one interval after reopening. History also lists the two builds' events in different orders.
- **Close (AD-3):** define the canonical order as `(issuedAt, commit sequence)`, used by every projection, by the fold and by Export. Also state what `accepts` sees: either "all committed facts; a command issued before a committed closing event is rejected", or "facts with `issuedAt` ≤ the command's". Pick one.

### H3. AD-8 freezes the due instant from a ledger fire instant, which isn't the due instant, and the command payload is undefined

- **Units:** the Coordinator's materialization (AD-8) against the NudgeCore engine and My Day, which derive "due" from the key's wall time (AD-7, AD-9).
- **Text:** AD-8: "the due instant is frozen from that delivery's ledger row, or from the command's payload". AD-15's ledger row has a **fire instant**, not a due instant. Under brief §3, an occurrence due at 3:00 inside quiet hours sends nudge 1 at 7:00.
- **Build A:** freezes due = 7:00, the fire instant of nudge 1. The give-up time, Not Done's "next step", My Day ("Due 7:00") and History all shift.
- **Build B:** the engine resolves the key `…@…T0300` in the zone in effect and gets 3:00.
- **The payload:** the notification delegate's command carries (key, nudge index, issuedAt, source) per AD-3 and AD-7, with no instant. A Siri command built from `NudgeQuerying` may carry one. Neither shape is specified.
- **Close (AD-8, plus a `Command` type in AD-4):**
  - Ledger rows carry `dueInstant` separately from `fireInstant`.
  - Define `Command` in NudgeCore with fixed fields (kind, key, deliveryID?, issuedAt, source, dueInstant?).
  - When neither a ledger row nor a payload gives the due instant, the coordinator resolves the key with the zone fact in effect at that wall time (AD-7's DST rule).

### H4. NudgeModel and the Coordinator can call `evaluate` with different zone and capability inputs

- **Units:** `NudgeModel` in the app target (AD-20, which re-evaluates at `nextChangeAt` and on foreground with no store change) against the Coordinator's reconcile (AD-4, AD-6).
- **Text:**
  - AD-1: "`now` and the device zone are parameters".
  - AD-3 and AD-9: the zone is also a versioned fact, written by the coordinator "when it detects a change".
  - AD-11 and AD-18: `Capabilities` is built in the shell, and the reconcile persists capability state.
- **Build A (NudgeModel):** passes `TimeZone.current` and builds `Capabilities` live, for example from a fresh `getNotificationSettings`.
- **Build B (Coordinator):** passes the latest zone fact and the persisted capabilities.
- **Result:** between `NSSystemTimeZoneDidChange` and the reconcile, or after the person turns off Time Sensitive and before the next reconcile, the card's time and Via label differ from what's actually scheduled. AD-20's "screens refreshing statuses at different moments" problem comes back.
- **Close (AD-1 and AD-20):** one shell function provides `EvaluationInputs` (facts, settings, the **latest committed zone fact**, the **persisted** capabilities). NudgeModel evaluates only from the snapshot the coordinator last published, changing nothing but `now`. Zone and capability changes reach the UI only through a reconcile.

### H5. The journal drops `source`, so replay can't tell an alarm's Stop from a notification's Done

- **Units:** the journal writer (CommandSubmitting before the first unlock, AD-16) against journal replay and the engine's follow-up planning (AD-12, AD-3).
- **Text:** AD-16 says the journal holds "**only** the command kind, occurrence key, nudge index, delivery ID and `issuedAt`". A Stop and a notification's Done both answer `nudge/<key>/<n>`, since AD-7 uses that one form for both channels.
- **Build A (writer):** writes kind `done`, because a Stop is a `done(source: .alarmStop)` command (AD-12).
- **Build B (replay):** must choose a source. If it chooses `.notification`, there's no "Done (alarm stopped)" row, no Not Done on Now or My Day, and the intent's `followup/<key>` is orphaned. If it chooses `.alarmStop`, a notification Done gets an unexpected follow-up.
- **Close (AD-16):** the journal also holds `source`, which isn't personal text, so AD-19 is unaffected. Alternatively, define `stop` as its own command kind.

### H6. `alarmCapacity` has no starting value, and `maximumLimitReached` doesn't replan within the job

- **Units:** shell `Capabilities` and the reconciler (AD-14) against the NudgeCore slot policy (AD-11, AD-14).
- **Text:** AD-14: "persists the number that succeeded … Each later reconcile tries one more." Nothing gives the value before the limit is first hit, or says what happens to the alarms that failed in this job.
- **Build A (shell):** starts at 0 to be safe, then grows by one alarm per reconcile. A Firm occurrence then gets 1 alarm and 16 Time Sensitive fallbacks for days.
- **Build B (engine):** treats an absent value as unlimited. On a throw, the reconciler persists the count and ends the job. The failed Urgent nudges are in no OS request until the next reconcile, possibly 12 h later per AD-14. Under C1, they also get no ledger row, so they vanish from History.
- **Close (AD-14):**
  - The initial value is "unknown", which means unbounded.
  - On `maximumLimitReached`, the job persists the capacity, re-evaluates and re-diffs **in the same job**, so the overflow nudges become `.timeSensitive` notifications.
  - "Tries one more" applies only when the plan wants more alarms than the capacity.

### H7. No NudgeCore entry point for the status and nudge count of past occurrences

- **Units:** the History screen (AD-15, "History screens read past facts separately") against the NudgeCore export encoding (Conventions › Export) and the nudge card's "Nudge 12 of 20" (AD-1).
- **Text:** AD-2 says status is never stored and is computed by the engine. AD-14 says `evaluate` reads only "each reminder's open or latest occurrence". So nothing defines how an occurrence from 30 days ago gets "Missed: the next one took over" or "how many nudges it took" (EXPERIENCE › History).
- **Build A (History):** counts the ledger rows per occurrence, or the distinct nudge indexes. Chain rows (one row per notification, AD-15), `snooze/…` rows that reuse index n, and nudges cut by the 63-request budget (no row at all) each make its count differ from the engine's on-schedule count.
- **Build B (Export):** derives status through some other path inside NudgeCore.
- **Close (AD-1 and AD-14):** NudgeCore exposes `summarize(occurrence, facts, settings) -> OccurrenceSummary` (status, closing reason, nudges counted), the same fold as `evaluate`. History, Export and Siri use only that. Ledger rows supply the per-nudge lines, never the counts.

### H8. Chain IDs can collide when a chain restarts, and a chain row's nudge index is ambiguous

- **Units:** the NudgeCore plan builder (AD-13) against the reconciler diff (AD-6) and History (AD-15).
- **Text:** AD-7 gives `chain/<key>/<startNudge>/<k>` and `snooze/<key>/<n>/<s>`. Keying post-snooze deliveries to n implies that a post-snooze delivery keeps nudge index n. AD-13 restarts a chain at the end of a snooze.
- **The collision:** the first chain starts at nudge 4. The person snoozes at minute 2, and the chain re-enters at the end of the snooze with `startNudge` = 4 again. Its `chain/<key>/4/1` and `chain/<key>/4/2` match IDs still in the delivered list, so under AD-6 they count as present and are never sent.
- **Second divergence:** a chain row's "nudge index" (AD-15 groups by it) can be `startNudge` (parsed from the ID) or "the current nudge number" shown at that minute (AD-13).
- **Close (AD-7, AD-13 and AD-15):**
  - Every delivery ID is unique for the life of its occurrence and never reused. For example, use `chain/<key>/<chainOrdinal>/<k>`, or the chain's UTC start minute. Add a uniqueness test over a full simulated occurrence.
  - A chain row's nudge index is the number displayed at that minute.
  - The index always comes from the plan item, never from parsing the ID.

---

## Medium

### M1. The diff key ("replaces what changed") is undefined

- **Units:** the Form editing title and tags (AD-3's mutable fields) and the snooze-limit display (brief §4), against the reconciler (AD-6).
- **Build A:** the reconciler compares the delivery ID, fire instant and channel. A rename, a `nudge` to `nudge-final` category change after the third snooze (AD-17), and `NSCurrentLocaleDidChange` all change nothing. Pending notifications keep the old title and still offer Snooze.
- **Build B:** the reconciler compares the full content and replaces every request.
- **Close (AD-6):** a plan item's identity is its delivery ID. "Changed" means any change in fire instant, channel, interruption level, category, or a hash of the localized content: title, nudge line, and the `previewsHidden` effects.

### M2. The intent-posted `followup/<key>` (AD-16) shares an ID with the engine's follow-up but carries the opposite removal rule

- **Units:** the Cleanup implementer against the Exceptions implementer, both in AD-6.
- **The conflict:** AD-6 Exceptions says the follow-up posted before the first unlock is "outside the reconciler's namespace and never removed by it". Cleanup removes "expired Done follow-ups". Both use `followup/<key>` (AD-7). One build never removes it, so a stale Not Done stays forever. The other removes it.
- **Close:** after replay commits the `done`, the reconciler adopts the intent-posted follow-up as its own, writing a ledger row with the same ID. The "never removed" exception holds only until replay.

### M3. Ledger row identity across replacements, and "handed over"

- **Units:** reconciler bookkeeping (AD-15) against AD-8 materialization and History.
- **Build A:** updates a row in place when a delivery moves (after a snooze or a zone change before it's due).
- **Build B:** marks the old row `cancelled` and appends a new one. AD-8's "that delivery's ledger row" is then ambiguous.
- **Missing fields and rules:**
  - Undeliverable settlement needs "no OS request was ever handed over", but no `handedOver` field exists.
  - The rule for a row whose OS `add` threw is undefined.
- **Close (AD-15):**
  - Rows are append-only per (delivery ID, fire instant, channel), and a replacement cancels the old row.
  - Each row has `handedOverAt?`, set only after the OS accepts the request.
  - A failed `add` leaves the row `scheduled` with no hand-over, so it settles as `undeliverable` unless it's replanned first.

### M4. Writes other than the event list have no defined command semantics

- **Units:** the Form (new and edited reminders, inline tag creation), the Tags tab (rename and delete), Settings (quiet hours, Delete All) and Search (Recent Searches), all through the Coordinator (AD-4).
- **The gap:** AD-4's command job writes "the resulting events" from `accepts`. AD-3's event list is done, not done, snooze, clear, pause, resume and skip-by-edit. Config versions, tag rows, mutable fields and Recent Searches belong to neither job kind.
- **Build A (Form):** relies on the store's unique-key error for case-folded tag names.
- **Build B (Rename Tag):** relies on `accepts`.
- **Also undefined:** whether a version's "saved" instant is `issuedAt` or the commit clock, which decides which nudge an edit made during nudging applies from.
- **Close (AD-4):**
  - Enumerate the command set in NudgeCore, including the CRUD commands.
  - `accepts` returns the complete set of row writes: events, versions, tags, Recent Searches.
  - Uniqueness and validation are checked there. The DB constraint is only a backstop.
  - A version's saved instant is the command's `issuedAt`.

### M5. The No Tags filter has no defined form under "dropped whenever read"

- **Units:** My Day's filter (No Tags mode, EXPERIENCE › My Day) against the shared read-time cleaner (Conventions › UI state).
- **Build A:** stores No Tags as an empty ID set plus a mode. The cleaner sees no tags left and turns the filter off, so No Tags can never be chosen.
- **Build B:** keeps No Tags as a mode, so Delete All Data leaves it on, against brief §3's "clears the tag filters".
- **Close (Conventions):** define `TagFilter = off | tags(Set<UUID>, match) | noTags`. State that the read-time drop applies only to `tags`, and whether `noTags` survives Delete All. If it shouldn't, amend brief §3 and EXPERIENCE, or accept it explicitly.

---

## Low

### L1. Delivered notifications of a deleted reminder are covered by no Cleanup rule

AD-6 Cleanup is keyed to a closed occurrence. Delete and Delete All (AD-16) remove the occurrence row, so one implementer treats "not found" as closed and another leaves the notifications in place, with actions that do nothing. **Close:** Cleanup also removes delivered notifications whose occurrence or reminder no longer exists, keeping `test/…` exempt.

### L2. "Sent ledger rows" in Export isn't History's definition

Conventions › Export includes "sent ledger rows". AD-15's History shows rows past their fire instant that are still `scheduled`, plus `undeliverable` rows, so Export can include or exclude `undeliverable` rows. **Close:** Export uses the same row filter as History, with the state included.
