# Mockup checks

Scripted checks for the mockup in [`../index.html`](../index.html), run in headless Chrome. They were
written during the cross-document review (branch `docs/align-precedence-and-mockup`) to confirm each
behavior change against the specs.

| File | What it checks |
|---|---|
| [behavior-checks.js](behavior-checks.js) | 34 behavior checks: swipe, focus after Done (Now, My Day, Assistive Access), permission banners and the Settings footer, the Not Done window, month ends, past-start one-offs, Resume and paused edits, close-on-edit, tag names, history copy and Done sources, Delete All, no time zone setting. |
| [axe-checks.js](axe-checks.js) | axe-core with WCAG 2.0, 2.1 and 2.2 A and AA rules on 9 screens × iOS 18/26/27 × light/dark × Increase Contrast × Large/AX3 (216 runs). |
| [run-checks.sh](run-checks.sh) | Injects a check script into a copy of the mockup and prints the results. |

## Running

```sh
./run-checks.sh behavior                  # expect "34/34 pass"
./run-checks.sh axe                        # expect "axe runs 216, errors 0, violations 0" (downloads axe-core 4.13.0 with npm)
./run-checks.sh behavior /path/to/old.html # run against another copy, e.g. from `git show <commit>:…/index.html`
```

Needs Google Chrome at the default macOS path (or set `CHROME`), Python 3, and npm for the axe run.

## Conventions

- **Each check starts from a clean mockup.** The harness clicks the **Reset the mockup** control
  before every check, so checks can't change data later checks rely on. A check that needs special
  data sets it up itself (see `2a`, `2c`).
- **Edit checks by name, never by position.** Earlier edits that sliced the file by position
  silently deleted checks; the count dropping is the tell.
- **A new check must fail on the commit before its fix.** Run it against that commit's `index.html`
  to show it catches the bug. A check that passes on both doesn't test the fix.
- **Headless Chrome:** don't add `--user-data-dir` (Chrome hangs on GoogleUpdater). macOS has no
  `timeout`, so the runner caps Chrome with a perl alarm; exit 142 means the cap was hit.
- The checks call the mockup's own functions (`ack`, `nextFocusAfterAck`, `cleanTag`, …), so a
  renamed function shows up as an `ERROR` line rather than a `FAIL`.
