# Input reconciliation review: second spine re-validation

- **Run:** bmad-architecture VALIDATE (report only)
- **Repository state:** `architecture/spine-update` at `8c2ce98`
- **Inputs checked:** `docs/product/brief.md` (introduction, §3, §4, §10, §11, plus §5/§6 where the
  spine cites them), `docs/product/addendum.md`, `docs/design/EXPERIENCE.md`, `docs/design/DESIGN.md`,
  and the mockup's `README.md` and `index.html`. Each was checked against
  `docs/architecture/ARCHITECTURE-SPINE.md` ("SPINE" below).
- **Precedence:** set once, in brief.md:23-31. SPINE:25, EXPERIENCE.md:27, DESIGN.md:225 and
  README.md:31 point to it. The addendum (:10) points to it too. Nothing restates it.

## Verdict

**Pass, with medium findings.** None of the inputs gives a builder instructions that contradict the
spine. The first re-validation's three mediums are closed:

- EXPERIENCE.md:500 now points to AD-12's every-snooze rule.
- The "Stopping the alarm counts as Done" copy carries a device-check marker (EXPERIENCE.md:121). It
  is also listed in Open Items (EXPERIENCE.md:864).
- AD-12's "Every alarm's configuration" bullet (SPINE:210) now drops the secondary button once no
  snoozes are left.

Of the earlier lows, L1, L2, L4, L5, L7 and L8 are fixed by pointers. Two new mediums remain. Both are
cases where a higher-precedence statement and the spine say different things, and precedence settles
which one a builder should follow.

| Tier | Count |
|---|---|
| High | 0 |
| Medium | 2 |
| Low | 12 |

## Rules changed on this branch (from `git diff main...HEAD`)

Each rule was searched for in the brief, the addendum, EXPERIENCE, DESIGN, the spine, the README and
index.html. "Clean" means every statement agrees with the spine or points to the rule's home.

| # | Rule (home) | Result |
|---|---|---|
| 1 | First-nudge slot priority limited to occurrences due in the next 24 hours (brief §4:222; AD-14:227 points) | Agrees everywhere. Also restated in brief §10:492-494 (L4). Affects the keep-nudging timing (M2) |
| 2 | Every snooze: the reconciler cancels the system countdown, and the app's own alarm rings at the snooze's end (AD-12:207, :211) | Clean. Brief §4:188-191, §11 Q5:563-564, addendum:157-161, EXPERIENCE:500, README:342-350 and index.html:2433-2434, :2450 point to AD-12 |
| 3 | No secondary button once the occurrence has no snoozes left (AD-12:210; brief §4:199-200) | Matches brief §4. But it leaves out the extra nudge after Not Done (M1) |
| 4 | One notification category per snooze length, plus `nudge-final` (AD-17:265-266) | The spine never says when `nudge-final` is chosen (M1) |
| 5 | `source` renamed `alarmStop` → `alarm`, and `alarmCountdown` added (AD-3:87) | Clean (EXPERIENCE:123, index.html:1933). `alarmCountdown` is used only for snoozes, so it has no Done string (correct) |
| 6 | Before the first unlock, the shell's `submit` posts `followup/<key>/<n>` (AD-16:255; AD-6:138 and AD-9:176 point) | Clean (brief §4:163-165, §11 Q13:585-586, addendum:147) |
| 7 | Stop isn't recorded if the stop intent can't run before the first unlock (AD-16:255) | Clean. Tied to brief §10:427-429 and EXPERIENCE:121, :864. Brief §4:150-151 is still unconditional (L12) |
| 8 | History's nudge lines, including "couldn't be sent (the app wasn't opened)" (AD-15:243) | Clean (EXPERIENCE:122, README:54-55). Copy accuracy noted in L6 |
| 9 | How `alarmCapacity` is counted and grows; `protectedAlarms` (AD-11:193, AD-14:228) | Clean. Brief §4:224 states the product rule, and addendum:187-189 points to AD-14 |
| 10 | Store open failure stops nudging and shows a message; locked and failed told apart by protected data (AD-16:254-256) | Clean (EXPERIENCE:488 points to AD-16). Copy noted in L5 |
| 11 | Restore detection by marker file plus second signal (AD-15:244) | Clean (brief §10:390-392, :438-439) |
| 12 | Siri order: EXPERIENCE's order, with ties broken by reminder UUID (SPINE:327; EXPERIENCE:659-662) | Clean. The tie-break exists only in the spine, and EXPERIENCE owns the order |
| 13 | Month ends (brief §3:83; AD-10:185 points) | Clean. index.html:1383 and :1426 now cite brief §3 |
| 14 | Keyboard list (EXPERIENCE:549-557, "the one list") | Addendum:97-98 points. Brief §5:267 still names the keys (L1) |
| 15 | Entitlements, keys, privacy manifest and label (SPINE:410-420) | Clean. Addendum:218-225 points, and the encryption key's value is no longer restated |
| 16 | Crash reports (SPINE:423) | Clean. Addendum:237-238 points |
| 17 | `appEntityIdentifier` deferral (SPINE:475) | Clean. Addendum:193-195 points |
| 18 | Assistive Access detection API: `AccessibilitySettings.isAssistiveAccessEnabled` (AD-18:282) | Brief:291, addendum:44 and EXPERIENCE:653 give it unqualified (L2) |
| 19 | Device checks that change a decision (SPINE:432-443; brief §10:418-441) | All 10 match, with the same AD references. The intent-process check is scoped differently (L7) |
| 20 | Alarm prompt on launch only after onboarding (AD-11:197) | Clean (EXPERIENCE:486, addendum:38, brief §6:289) |
| 21 | Chain semantics point to brief §4 (AD-13:219-220) | Clean |
| 22 | Not Done's extra nudge: its interval counts from its planned instant (AD-4:101; brief §3:96) | Clean on timing. Its no-Snooze rule isn't carried into AD-12/AD-17 (M1) |
| 23 | Keep-nudging request at the fire time of the earliest delivery left out (AD-14:227) | **Differs from brief §4:222 and EXPERIENCE:503** (M2) |
| 24 | Export: last 90 days up to now, the offsets of the zone facts in effect, History's nudge lines (SPINE:329) | Clean. EXPERIENCE:471 and index.html:3149 agree on JSON and the file name |
| 25 | Tag filter forms; deleting a tag or all data empties filters (SPINE:325) | Agrees with EXPERIENCE:88-91 and :435. Gap with brief §3:100 for other scenes (L8) |
| 26 | Filters restored after iOS ends the app, reset on close from the switcher (SPINE:325) | Clean (EXPERIENCE:88-91, brief §11 Q14:587-588) |
| 27 | Command set, `accepts`' write set, Recent Searches trimmed to 5 (AD-4:102) | Agrees with EXPERIENCE:441 and README:128. Restated count (L11) |
| 28 | Time Sensitive off sent as `.active` (AD-11:194; brief §4:206-212) | Agrees. The spine restates a rule the brief calls "the one statement" (L3) |
| 29 | Strings per target, App Shortcut phrases in `AppShortcuts.xcstrings` (SPINE:323) | Agrees with addendum §D:107-109 and EXPERIENCE:131, :683 |
| 30 | Testing via `xcodebuild` on the 18/26/27 simulators, iPad UI tests, CI runner (SPINE:328, :421) | Clean. Brief §5:233-234 and §11 Q10 agree. No other statements |
| 31 | Time convention: zone per instant from zone facts; display formatters use the current zone (SPINE:318) | No other statements. EXPERIENCE:48 and addendum:173 point to brief §3 |
| 32 | issuedAt's clock, the answered nudge derived from issuedAt, event order (AD-3:87-88, AD-4:101) | Spine only |
| 33 | Window membership, per-reminder status and `notDoneUntil` in Evaluation (AD-1:74); the previous occurrence projected for carry-over (AD-14:230) | Spine only. Consistent with brief §3's Not Done and Carry-over rows, and with brief §6's "Later" and "Coming Up (7 days)" |

## High

None. No two documents give contradictory instructions that a builder would follow differently once
the brief's precedence is applied.

## Medium

### M1. The spine's no-Snooze rules leave out the extra nudge after Not Done, and never say when `nudge-final` applies

- **Higher-precedence rule:** brief.md:96 (§3, Not Done) says that if the occurrence had already used
  its give-up limit, reopening allows "one more nudge, with Done but no Snooze". EXPERIENCE.md:416
  says the same: "No snoozes left, or the one extra nudge after Not Done at the limit … Snooze is
  removed from the card, notification and alarm". README.md:48-49 agrees.
- **Spine:** ARCHITECTURE-SPINE.md:210 (AD-12) gives an alarm "no secondary button once its
  occurrence has no snoozes left (brief §4)". An extra nudge on an occurrence with snoozes still
  unused would therefore get an alarm with Snooze. ARCHITECTURE-SPINE.md:265 (AD-17) says "the engine
  picks the category for the reminder's snooze length". :266 defines `nudge-final` ("Done only") but
  no rule selects it, either for no snoozes left or for the extra nudge.
- **Related:** the 3-snooze cap appears nowhere in `accepts`' rejection rules
  (ARCHITECTURE-SPINE.md:101). Delivered notifications are never replaced (:124), so an earlier
  notification still shows Snooze after the third snooze. Only AD-1's general "is this command
  allowed" (:74) plus brief §3:128 makes `accepts` reject a fourth snooze. Brief §10:366-367 says
  "the app's reconciler … enforces the 3-snooze limit", but in the spine the reconciler only removes
  the button.
- **Why medium, not high:** brief §3 outranks the spine, and AD-4 says "Not Done applies as brief §3
  says". A builder who follows precedence gets it right. But AD-12:210 and AD-17:265 read as complete
  rules for the alarm configuration and the category choice. A builder working from them would put
  Snooze on the extra nudge, and wouldn't know when to use `nudge-final`.
- **Fix:** in AD-12:210, add "or it is the extra nudge after Not Done at the limit (brief §3)". In
  AD-17, say the engine picks `nudge-final` for those same two cases. In AD-4, name the snooze cap
  (brief §3) among `accepts`' rejections. Optionally reword brief §10:366-367 so the reconciler moves
  alarms and removes Snooze, and the engine enforces the cap.

### M2. The keep-nudging notice's time differs between the brief, EXPERIENCE and AD-14

- **Higher-precedence rule:** brief.md:222 (§4 System limits): "1 slot is kept for an 'Open
  Nudge-inator to keep nudging' notification, at the time its scheduled nudges run out."
  EXPERIENCE.md:503: "Sent when the scheduled nudges run out before the app has run again."
- **Spine:** ARCHITECTURE-SPINE.md:227 (AD-14): "1 keep-nudging request at the fire time of the
  earliest delivery left out (by the budget or the horizon)".
- **Why they differ:** slots go first to nudge 1 of every occurrence due in the next 24 hours, then
  to every other nudge, soonest first (brief.md:222, changed on this branch). So a kept nudge 1 can
  fire after the earliest nudge that was cut. "When the scheduled nudges run out" reads as the last
  scheduled fire time. "The earliest delivery left out" can come hours before that. A builder
  following the brief's wording would leave a gap: nudges cut before the last scheduled one go missing
  with no notice. AD-14's time is the one that keeps the promise.
- **Why medium:** the brief's phrase is loose rather than plainly opposite, and EXPERIENCE copies the
  brief. The brief has precedence, though, and restates the timing instead of pointing to AD-14.
- **Fix:** in brief.md:222, say "at the time of the first nudge that couldn't be scheduled
  (architecture spine, AD-14)", or just point to AD-14. In EXPERIENCE.md:503, say "Sent when the
  first nudge that couldn't be scheduled would have come".

## Low

- **L1. Keyboard shortcuts named in two places.** EXPERIENCE.md:549 calls its table "the one list"
  and notes that "brief §5 names the shortcuts". brief.md:267 lists ⌘N, ⌘F and ⌘1 to ⌘4. The content
  matches today. (Carried over.)
- **L2. The Assistive Access API is unqualified outside the spine.** brief.md:291, addendum.md:44 and
  EXPERIENCE.md:653 say "`isAssistiveAccessEnabled`". AD-18 (ARCHITECTURE-SPINE.md:282) was changed
  on this branch to name `AccessibilitySettings.isAssistiveAccessEnabled`. The bare name could also
  be read as SwiftUI's `accessibilityAssistiveAccessEnabled` environment value, or as the
  non-existent `UIAccessibility` property the branch removed. Point to AD-18 or qualify the name.
- **L3. Time Sensitive off is stated twice.** brief.md:209-211 says "This is the one statement of
  that rule". AD-11 (ARCHITECTURE-SPINE.md:194) restates it as "the only place the spine states it",
  and adds the mechanism. The two agree. A "(brief §4)" pointer on AD-11 would make the home explicit.
- **L4. The slot-priority rule is stated twice in the brief.** brief.md:222 (the System limits table)
  and :492-494 (Decided 2026-10-02) both carry the 24-hour wording. They were updated together on this
  branch. The decision entry could point to the table instead.
- **L5. The open-failure copy fits neither the beta nor the downgrade case.** EXPERIENCE.md:488 says
  "Check the App Store for an update". The beta ships through TestFlight (brief.md:466-468;
  SPINE:408). AD-16 (SPINE:253) names "a newer TestFlight build ran first" as an open failure. There
  the fix is the newer build, not an App Store update. (Carried over, now with the downgrade case.)
- **L6. "Couldn't be sent (the app wasn't opened)" also covers lost rows.** AD-15
  (ARCHITECTURE-SPINE.md:243) gives that reason when a nudge was cut by the budget, never handed
  over, or `lost`. Restore detection (:244) marks rows `lost` even when the app has been opened. The
  copy at EXPERIENCE.md:122 and README.md:54-55 may then be untrue. The wording is the UX spine's
  call.
- **L7. The intent-process check is scoped differently.** brief.md:425-426 asks only about iOS 26
  with the app not running. The First spike (SPINE:426) checks iOS 26 and 27, with the app running
  and not running, on a TestFlight build. The device table (SPINE:438) says iOS 26. The checks don't
  conflict, but the brief's checklist item is narrower than what the spike records.
- **L8. Delete All Data and `noTags` in other scenes.** SPINE:325 turns a `noTags` filter off only
  "in the scene it runs in". brief.md:100 says Delete All Data clears "the tag filters". v1 is
  single-scene, so the case can't happen yet. (Carried over.)
- **L9. Brief §11 Q5 keeps the old question.** brief.md:561-563 still asks how "the third snooze has
  to replace that alarm". The "(Answered: …; AD-12)" note that follows resolves it, so this is
  history, not a live rule. README.md:536 and :936 record past checks, and they are still true.
- **L10. Mockup Done-source map is incomplete.** The comment at index.html:1932 says "One string per
  Done source", but the map at :1933 has no `siri` ("Done with Siri", EXPERIENCE.md:123); `app`
  falls back to "Done". The mockup doesn't simulate Siri, so this is hygiene only.
- **L11. Recent Searches' cap is stated three times.** EXPERIENCE.md:441 ("up to 5"), AD-4
  (ARCHITECTURE-SPINE.md:102, "trimmed to 5") and README.md:128 ("up to five") agree. AD-4 could cite
  EXPERIENCE for the number.
- **L12. Brief §4 still says Stop always marks the occurrence done.** brief.md:150-151: "Stopping the
  alarm runs the app's code, which marks the occurrence done, and onboarding says so." AD-16
  (ARCHITECTURE-SPINE.md:255) says the Stop isn't recorded if the stop intent doesn't run before the
  first unlock. The caveat is tied to its device check at brief.md:427-429 and EXPERIENCE.md:121, so
  this is a wording gap only.

## Also checked, with no finding

- **Brief §3 against AD-1 to AD-4, AD-8 to AD-10 and AD-16:**
  - status derivation and the Completed row (AD-2:80)
  - Edit timing, and gentler-strength versions (AD-3:90)
  - the give-up time excluding quiet, snoozed and closed time (AD-3:93; brief :88, :96)
  - snooze lengths and the category set (AD-17:265; brief :127)
  - Tag uniqueness ignoring case (Conventions › Tags)
  - Delete All Data keeping settings (AD-16:257)
  - the one time-zone rule (AD-9:174 points to brief §3:83)
- **Brief §4 against AD-6, AD-11 to AD-15, AD-17 and AD-19:**
  - the channel table and the alarms-unavailable chain (AD-11:197)
  - the extra nudge's chain exception (AD-11:197; brief :170-171)
  - closing clears nudges, with alarms in progress protected only for open occurrences (AD-6:126,
    :128)
  - a stale action does nothing (AD-4:101)
  - the alarm limit (AD-14:228)
  - notifications off still counting nudges (AD-11:193, AD-15:238)
  - privacy on system surfaces (AD-19:293)
  - the follow-up's sending and removal (AD-12:209, AD-6:128, AD-16:255)
- **Brief §10:** the risks agree with the spine. Snooze before the first unlock is handed to AD-6
  (brief :369-372; AD-6:127). Restore follows AD-15. The background top-up follows AD-14:229. Every
  checklist item that names an AD appears in SPINE:432-443 with the same consequence.
- **Brief §11 Q1-Q14:** each maps to a row of the Capability → Architecture Map (SPINE:447-470).
  The answered notes on Q5, Q7, Q13 and Q14 match AD-12, AD-9, AD-12/AD-16/AD-6 and Conventions › UI
  state.
- **Addendum §E (:143-189):** points to AD-12, AD-14 and AD-16 for the rules and keeps only Apple's
  API facts. The note at :179-181 that "an alarm missing from `alarmUpdates` is no longer scheduled"
  is an API fact. It doesn't conflict with AD-6:127, which never treats absence as a command.
- **EXPERIENCE's Nudge Surfaces, State Patterns, Siri & Shortcuts and Assistive Access:** these agree
  with:
  - the taps (AD-17:270)
  - banners over the app (AD-20:310)
  - the Live Activity before the first unlock (AD-12:210)
  - the alarm prompt after an update (AD-11:197)
  - a rung-out alarm still nudging (AD-6:127)
- **DESIGN.md:558-571:** the Alarm and Live Activity components point to EXPERIENCE for behavior and
  restate no changed rule.
