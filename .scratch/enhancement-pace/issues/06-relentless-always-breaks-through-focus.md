# 06: Relentless always breaks through Focus

**What to build:** A Relentless reminder always breaks through Focus. The engine treats it as breaking through whatever its stored switch says. In the form, choosing Relentless shows Break through Focus on and disabled, with a footnote saying Relentless always rings; switching to Firm or Gentle makes the switch editable again with the value the person last set. Spec stories 8, 30 and 31, and story 45 for VoiceOver; ADR 0004.

**Blocked by:** 05.

**Status:** ready-for-agent

- [ ] Engine: a Relentless reminder whose stored switch is off plans and delivers its nudges as alarms, the same as with the switch on.
- [ ] Form: choosing Relentless shows the switch on and disabled, with the footnote, as in the proposed mockup.
- [ ] Form: leaving Relentless for Firm or Gentle restores the switch to the person's last value, editable.
- [ ] Onboarding's third point, also at the top of Settings' How It Nudges page, reads "Each Gentle or Firm reminder has a Break Through Focus switch. Turn it off and a Focus can hold its nudges, and nothing rings. Relentless always breaks through."
- [ ] Simulators (26.5 and 27.x): the switch and footnote in portrait, landscape and large text.
- [ ] VoiceOver reads the switch as on and dimmed, and the footnote's reason can be reached.
- [ ] Offered to Brian, after the simulator pass: on an iPhone under a Focus, a Relentless reminder saved with the switch off before choosing Relentless rings through (phone and iOS version recorded).

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: onboarding's Break Through Focus point. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 17.
