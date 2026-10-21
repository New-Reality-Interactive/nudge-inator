# 05: Relentless rings from nudge 1

**What to build:** Every Relentless nudge, from the first at the due time, is an alarm. Its waits don't change (10, 5, 2.5, then 2 min). When alarms are denied or past the alarm limit it falls back as Urgent nudges do today. How It Nudges, the line under Strength and the permission banners say so, since they are read from the engine. Spec stories 7 and 9–11; ADR 0004.

**Blocked by:** 04.

**Status:** ready-for-agent

- [ ] Engine: every nudge of a Relentless reminder is Urgent, and its fire times are unchanged.
- [ ] Engine: with alarms denied, Relentless nudges arrive as Time Sensitive notifications, or ordinary ones when Time Sensitive is off; past the alarm limit they fall back the same way, marked "too many alarms scheduled".
- [ ] How It Nudges and the strength line show Relentless as alarms from nudge 1, matching the proposed mockup, and the reach the banners describe stays true.
- [ ] Simulators (26.5 and 27.x): How It Nudges and the form show the change in portrait, landscape and large text.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a Relentless reminder's first nudge rings as an alarm at its due time (phone and iOS version recorded).

## Comments
