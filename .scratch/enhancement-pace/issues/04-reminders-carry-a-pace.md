# 04: Prefactor: reminders carry a pace

**What to build:** Make the change easy before making it. A reminder gets a pace, saved and reloaded with it, and the engine works out a reminder's nudge times, waits and give-up time from its pace and strength together instead of from the strength alone. Only Escalating exists for now, so every reminder nudges exactly as before and nothing changes on screen. Spec stories 5 and 6, and the Implementation Decisions on the engine, storage and How It Nudges read-out.

**Blocked by:** 03 (no implementation starts before the proposed mockup is approved).

**Status:** ready-for-agent

- [ ] A reminder has a pace, Escalating, using the GLOSSARY's terms; the engine stays free of Apple frameworks.
- [ ] The stored reminder record holds the pace, and a saved reminder reloads with it. No migration (the spec's beta install note).
- [ ] The engine's nudge times, waits and give-up time come from pace and strength together; urgency still comes from the strength.
- [ ] The How It Nudges read-out takes the pace.
- [ ] Every existing engine and app test passes unchanged on both simulators, showing Gentle, Firm and Relentless nudge as before.
- [ ] New tests: a reminder's pace survives a save and reload; an Escalating reminder of each strength plans the same nudges as before.

## Comments
