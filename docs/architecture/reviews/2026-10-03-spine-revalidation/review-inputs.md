# Input reconciliation review: spine re-validation

- **Run:** bmad-architecture VALIDATE (report only)
- **Repository state:** `architecture/spine-update` at `acb3a01`
- **Inputs checked:** `docs/product/brief.md` (introduction, §3, §4, §10, §11), `docs/product/addendum.md`,
  `docs/design/EXPERIENCE.md`, `docs/design/DESIGN.md`, the mockup's `README.md` and `index.html`. Each was
  checked against `docs/architecture/ARCHITECTURE-SPINE.md`.
- **Precedence:** the brief's introduction (brief.md:23-33). The spine (SPINE:25), EXPERIENCE (:27),
  DESIGN (:225), the addendum (:10) and the README (:31) point to it and don't restate it.

## Verdict

**Pass, with medium findings.** None of the inputs gives a builder instructions that contradict the
spine. The brief's §3/§4 rules, the §10 device checklist and the §11 answers all agree with the spine's
ADs. The spine's device table (SPINE:436-447) matches brief §10's checklist (brief.md:417-440) item for
item.

The branch's own "one rule, one home" pass is mostly complete. These were checked clean: `alarmStop` →
`alarm`, the `undeliverable` state's removal, the "couldn't be sent (the app wasn't opened)" history
line, `followup/<key>/<n>`, the Keychain → marker-file change, the end of `swift test`, the Siri order's
move to EXPERIENCE, the month-end rule's move to brief §3, the entitlement list, `alarmCapacity`,
`appEntityIdentifier` and the keyboard list. The pass missed one place: EXPERIENCE's alarm row still
gives the old third-snooze rule. A few lower-precedence restatements of that rule are also stale.

| Tier | Count |
|---|---|
| High | 0 |
| Medium | 3 |
| Low | 11 |

## Rules changed on this branch (from `git diff main...HEAD`)

Each rule was searched for in the brief, the addendum, EXPERIENCE, DESIGN, the spine, the README and
index.html. "Clean" means every statement agrees with the spine, or points to the rule's home.

| # | Rule (home) | Result |
|---|---|---|
| 1 | Every snooze: the reconciler cancels the system countdown, and the engine's post-snooze alarm rings at the snooze's end (AD-12) | **Stale in EXPERIENCE:500** (M1). Also brief §4:188-190 and §11 Q5:559-561 (L4, L5), README:342 and index.html comments (L1, L2) |
| 2 | Snooze's end sends the next nudge, and the intervals carry on (brief §3:93; AD-7:149) | Clean (EXPERIENCE:415 "Snoozed until 8:35 AM, then …"; brief §4:169 chain start) |
| 3 | Later alarms lose Snooze once none are left (brief §4:198; formerly addendum §E) | Branch removed the addendum's mechanism; AD-12 states it only for the post-snooze alarm (M3) |
| 4 | `source` `alarmStop` → `alarm` (AD-3:87) | Clean (EXPERIENCE:123, index.html:1933) |
| 5 | Follow-up ID `followup/<key>/<n>`; posted by the stop intent before the first unlock (AD-6:138, AD-12:209, AD-16:259) | Clean (brief §4:163-165, §11 Q13:581-583, EXPERIENCE:501) |
| 6 | Stop not recorded if the stop intent can't run before the first unlock (AD-16:259); copy depends on the device check (brief §10:426-428) | **EXPERIENCE copy not tied to the check** (M2) |
| 7 | History's nudge lines and "couldn't be sent (the app wasn't opened)"; no `undeliverable` (AD-15:248) | Clean (EXPERIENCE:122, README:54-55, brief §4:202-204) |
| 8 | `alarmCapacity` counting and "try one more" (AD-14:233) | Clean; restated without detail in brief §4:223 and addendum:187-189, which points (L9) |
| 9 | An open failure stops nudging and shows a message (AD-16:260; EXPERIENCE:488) | Clean; copy issue (L10) |
| 10 | Restore detection by a backup-excluded marker file plus a second signal (AD-15:249) | Clean (brief §10:389-391, 437-438); no Keychain mention left |
| 11 | Siri order (EXPERIENCE:659-662; SPINE:331 points) | Clean |
| 12 | Month ends (brief §3:83; AD-10:185 points) | Clean in the spine and EXPERIENCE:126; index.html cites the old home (L2) |
| 13 | Keyboard list (EXPERIENCE:549-557, "the one list") | Addendum:97-98 points; brief §5:266-267 still names the keys (L6) |
| 14 | Entitlements, keys, privacy manifest and label (SPINE:414-424) | Addendum:218-225 points; `ITSAppUsesNonExemptEncryption` restated alongside the pointer (L7) |
| 15 | `appEntityIdentifier` deferral (SPINE:479) | Clean; addendum:193-195 points |
| 16 | Crash reports (SPINE:427) | Consistent restatement at addendum:237-238 (L8) |
| 17 | Device checks added: notifications-off alarms, the snooze intent with `.countdown`, the iOS 26 intent process, restore to a new iPhone, engine speed (SPINE:436-447; brief §10:417-440) | Clean; EXPERIENCE's Open Items omits the copy-dependent check (M2) |
| 18 | Tag filter forms and Delete All Data turning `noTags` off (SPINE:329) | Consistent with EXPERIENCE:435; a minor gap with brief §3:100 (L11) |
| 19 | Alarm prompt on launch only after onboarding (AD-11:197) | Clean (EXPERIENCE:485-486) |
| 20 | Chain semantics now point to brief §4 (AD-13:219-220) | Clean |
| 21 | Not Done extra nudge points to brief §3; its interval counts from the planned fire instant (AD-4:101) | Clean (brief §3:96) |
| 22 | Keep-nudging request at the first delivery left out, whether the budget or the horizon cut it (AD-14:232) | Clean (brief §4:221; EXPERIENCE:503 "Sent when the scheduled nudges run out") |
| 23 | Export carries History's nudge lines (SPINE:333) | Clean |
| 24 | Durations in integer seconds; the search matcher; Testing and CI; signing | Spine only; no other statements |

## High

None. No two documents give contradictory instructions that a builder would follow differently.

## Medium

### M1. EXPERIENCE still gives the old third-snooze rule

- **Evidence:** EXPERIENCE.md:500 (Nudge Surfaces, Alarm row) says "On the third snooze the app
  replaces the alarm with one that has no Snooze."
- **The changed rule:** ARCHITECTURE-SPINE.md:207 and :211 (AD-12). After every snooze, the
  reconciler cancels the system countdown, and the engine's `snooze/<key>/<n>/<s>` alarm rings at the
  snooze's end. That alarm loses its secondary button only when no snoozes remain. The branch updated
  addendum.md:152-161 and README.md:347-350 to say "every snooze" and to point to AD-12, which "holds
  the rule".
- **Why it matters:** EXPERIENCE is the only UX-spine statement of the rule. It restates the rule
  instead of pointing to it, and it describes the replacement as a third-snooze-only step. The spine
  wins under precedence, so the statement isn't strictly false. But a builder reading EXPERIENCE alone
  would implement replace-on-third, which leaves the system countdown in place for snoozes 1 and 2.
  That is the path AD-12 was changed to avoid, because the countdown can ring after a takeover or in
  quiet hours.
- **Fix:** replace the sentence with a pointer, for example: "After each snooze the app's own alarm
  rings at the snooze's end, without Snooze once none are left (architecture spine, AD-12)."

### M2. "Stopping the alarm counts as Done" isn't tied to its device check in EXPERIENCE

- **Evidence:** brief.md:426-428 says that if Stop isn't recorded before the first unlock,
  "onboarding's 'Stopping the alarm counts as Done' needs a caveat". ARCHITECTURE-SPINE.md:259 (AD-16)
  now spells out that case: "If the stop intent itself doesn't run before the first unlock … the Stop
  isn't recorded … and the occurrence keeps nudging". The copy appears unqualified at EXPERIENCE.md:121
  (fixed phrase), :124 (Welcome, Urgent iOS 26+), :295 (How It Nudges) and :728 (Flow 1).
- **Gap:** EXPERIENCE's Open Items › Device checks (EXPERIENCE.md:861-868) lists "the ones that can
  change this spine", and this check isn't among them. None of the four copy sites carries a
  "[To confirm on a device]" marker, although EXPERIENCE uses that marker elsewhere (:517, :654).
  Commit 43a090d ("tie copy to the checks it depends on") made the tie in the brief only.
- **Why it matters:** the copy is the UX spine's to own. Its owning document doesn't record that a
  pending check can falsify it, so the caveat could be missed at release.
- **Fix:** add the before-first-unlock check to EXPERIENCE.md:861-868, and add a "[To confirm on a
  device]" note at EXPERIENCE.md:121.

### M3. The branch dropped the stated mechanism for removing Snooze from an occurrence's later alarms

- **Evidence:** the branch deleted the addendum's sentence that, on the third snooze, "the remaining
  alarms are scheduled without it" (the `git diff` of addendum.md, old line ~160). The rule's
  product statement remains at brief.md:198: "Snooze disappears from the card, the notification and
  the alarm once the occurrence has no snoozes left". ARCHITECTURE-SPINE.md:207 (AD-12) says only the
  post-snooze alarm "has no secondary button when no snoozes remain". Its "Every alarm's
  configuration" bullet (:210) lists the presentations and `postAlert`, but not the secondary button.
  The behavior follows only by inference: AD-1 (the engine plans brief §4's rules) plus AD-6:124 (the
  diff treats a changed secondary button as a change). The memlog's gate H7 entry confirms that this
  is the intent.
- **Why it matters:** brief §4 has precedence and is explicit, so a builder who follows precedence
  gets it right. AD-12 now reads as the complete list of alarm-configuration rules, though. A builder
  working from AD-12 could leave Snooze on alarms that were scheduled before the last snooze.
- **Fix:** in AD-12's "Every alarm's configuration" bullet, add that every alarm of an occurrence with
  no snoozes left has no secondary button (brief §4). The AD-6 diff then replaces the ones already
  scheduled.

## Low

- **L1. README restates the old countdown behavior next to the new rule.** README.md:342-346 says
  "After Snooze on the alarm, AlarmKit counts down and rings again when the time is up." Under AD-12
  (SPINE:211), the reconciler cancels that countdown and the app's own alarm rings, which the next
  bullet (README.md:347-350) says. The two bullets contradict each other. Reword 342 as "the
  countdown shows …" without "AlarmKit … rings again".
- **L2. Stale code comments and pointers in index.html.** index.html:2433-2434 says Snooze is left
  out "because the app cancels the alarm and schedules a new one without it" (the third-snooze
  framing). index.html:2450 says "AlarmKit counts down and rings again". index.html:1383 and :1426
  cite AD-10 for the month-end rule, whose home is now brief §3's Reminder row (brief.md:83;
  SPINE:185). The mockup adds no rules, so this is hygiene only.
- **L3. Historical verification lines.** README.md:536 and :936 ("after the third snooze, the alarm
  shows only Stop") record past checks. They're still true under AD-12, so no change is needed.
- **L4. Brief §11 Q5 keeps the old framing.** brief.md:559-561 says "the third snooze has to replace
  that alarm with one without Snooze, and every snooze has to move the occurrence's later alarms".
  AD-12 answers differently: every snooze replaces the countdown. Q7, Q13 and Q14 carry
  "(Answered: …)" notes, and Q5 could add "(Answered: AD-12, every snooze)".
- **L5. Brief §4 states the countdown replacement conditionally.** brief.md:188-190 ("A snooze never
  outlasts its occurrence") says that if the snooze would end after a takeover or in quiet hours,
  "the app replaces the system's countdown". That's true under AD-12, where the countdown is always
  replaced, but it reads as if replacement happens only in those cases. The nudging rule is the
  brief's to own; a pointer to AD-12 for the mechanism would remove the ambiguity.
- **L6. Keyboard shortcuts named in two places.** EXPERIENCE.md:549 calls its table "the one list"
  and says "brief §5 names the shortcuts". brief.md:266-267 lists ⌘N, ⌘F and ⌘1 to ⌘4. The content
  matches and the overlap is acknowledged, but it is still a second statement that could drift.
- **L7. Encryption key restated beside its pointer.** addendum.md:224 says
  "`ITSAppUsesNonExemptEncryption` is `NO` (it's in the one list)". That matches SPINE:422, but the
  value is stated twice.
- **L8. Crash reports in two places.** addendum.md:237-238 ("crash reports arrive in App Store
  Connect") and SPINE:427 (only from testers and people who share them) agree. The spine's wording
  changed on this branch, and the addendum's didn't. The addendum could point to Environments ›
  Crash reports.
- **L9. Alarm limit summarized in three places.** brief.md:223, addendum.md:187-189 and AD-14
  (SPINE:233) agree. The addendum points to AD-14 and the brief doesn't. Acceptable, since the brief
  states the product rule and AD-14 the mechanism.
- **L10. The open-failure message mentions the App Store, but v1 testers get updates from
  TestFlight.** EXPERIENCE.md:488 says "Check the App Store for an update". The first release reaches
  testers through TestFlight (brief.md:76-77, :465-467; SPINE:412), where updates come from the
  TestFlight app. The copy is the UX spine's call, but it won't be accurate during the beta.
- **L11. Delete All Data and `noTags` in other scenes.** SPINE:329 turns a `noTags` filter off only
  "in the scene it runs in". Brief §3 (brief.md:100) says Delete All Data clears "the tag filters".
  v1 is a single-scene iPhone app (iPad runs the iPhone app), so the case can't happen yet.

## Also checked, with no finding

- **Brief §3 against AD-2, AD-3, AD-4, AD-8 and AD-9:** Completed and Paused status, the give-up time
  excluding quiet, snoozed and closed intervals, Not Done's extra nudge and its chain exception (AD-11
  at :197), Edit timing (AD-3 at :90), Delete and Delete All Data keeping settings (AD-16 at :261), and
  the one time-zone rule (AD-9 at :174 points to brief §3).
- **Brief §4 against AD-6, AD-11 to AD-14, AD-17 and AD-19:** the channel table, Time Sensitive off
  (stated once, brief §4:205-211, with AD-11 at :194 the spine's one statement), closing clears its
  nudges (AD-6 Cleanup and its alarms-in-progress protection), a stale action does nothing (the
  accepts rejection in AD-4, which ends with a reconcile), the slot order and keep-nudging slot
  (AD-14), the chain (AD-13 points), and the follow-up before the first unlock (AD-16).
- **AD-6's "a nudge that fell due while the app was closed isn't sent late":** compatible with brief
  §3's quiet-hours "sent at once", because nudges are planned ahead. The at-once writes cover edits,
  and AD-8 covers an eastward zone change.
- **Snooze before the first unlock (AD-6:127):** counted at most once per alarm, and the re-ring can
  be up to one snooze length late. Brief §10:368-371 hands this decision to AD-6, so it doesn't
  contradict brief §3's snooze length or 3-snooze cap. The device table row at SPINE:445 tracks it.
- **Brief §10's checklist and SPINE:436-447:** all ten decision-changing checks appear in both, with
  matching AD references.
- **Brief §11 Q1-Q14:** each maps to a row in the Capability → Architecture Map (SPINE:451-474).
  Q6, Q7, Q13 and Q14's answers match the spine.
- **EXPERIENCE's Nudge Surfaces, State Patterns and Siri sections against AD-11, AD-17 and AD-20:**
  the taps, the categories, the alarm prompt after an update, banners over the app, and the Live
  Activity before the first unlock all agree.
- **DESIGN.md:** the Alarm and Live Activity components (:558-572) point to EXPERIENCE for behavior
  and restate no changed rule.
- **Out of branch scope:** README.md:57-84 ("Product rules") restates brief §3 rules this branch didn't
  change (give-up minimums, quiet hours, carry-over). It agrees with the brief today.
