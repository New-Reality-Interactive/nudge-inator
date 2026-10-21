# 01: Toolchain: Xcode 27.x and the 26.5 + 27.x simulators

**What to build:** The project moves to the new development Mac, which runs Xcode 27.x. The automated tests run on the iOS 26.5 simulator and the newest iOS 27.x simulator that Mac's Xcode offers, and no longer on 26.1. The project's written rules (AGENTS.md's Toolchain and Testing sections, `docs/agents/device-testing.md`) describe the new setup, so every later ticket works to it. The app's minimum stays iOS 26.1. Spec: `.scratch/enhancement-pace/spec.md`, Testing Decisions.

**Blocked by:** None (can start immediately, on the new Mac).

**Status:** ready-for-agent

- [ ] The project builds with the new Mac's Xcode 27.x; the Xcode and SDK versions found there are recorded in this ticket's Comments.
- [ ] The test script's default simulators are iOS 26.5 and the newest installed iOS 27.x, and the full suite passes on both (counts recorded).
- [ ] The deployment target is still iOS 26.1.
- [ ] AGENTS.md's Toolchain rule names Xcode 27.x and the iOS 27 SDK, and says an iOS 27-only API is allowed only behind `if #available` with an iOS 26 path.
- [ ] AGENTS.md's Testing rule names the 26.5 and 27.x simulators (26.1 dropped for now), and says a story that changes something on screen is checked on both simulators first, after which the person is offered a run on a physical iPhone and decides.
- [ ] The device-testing doc records the two test iPhones, one on iOS 26.x and one on 27.x: a device check names which phone it ran on, and anything behind `if #available` is checked on the 26.x phone. Its rationale for the old Intel Mac toolchain is kept as history.
- [ ] Any new compiler warnings or test failures under Xcode 27.x are fixed or listed in Comments with a reason.

## Comments
