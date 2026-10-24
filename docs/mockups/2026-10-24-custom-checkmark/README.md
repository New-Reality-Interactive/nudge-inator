# Nudge-inator iOS mockup: Custom checkmark

The Custom repeat page with a checkmark that saves its choices, as decided in enhancement-pace
[ticket 17](../../../.scratch/enhancement-pace/issues/17-custom-repeat-saved-with-a-checkmark.md).
It's a copy of the [filter-badge mockup](../2026-10-24-filter-badge/README.md), changed only for the
Custom page, so the two can be compared screen by screen. Everything this README doesn't list is as
that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **The checkmark:** the Custom page's navigation bar has a checkmark on the right, drawn as the
  form's own Save and Add checkmark (an accent glass circle; the word on iOS 18). Tapping it makes
  the page's choices the repeat and goes back to the Repeat page, where Custom is checked with its
  summary under it. It works with no choice changed, so from Never the weekly repeat the page shows
  can be chosen as it is.
- **Back changes nothing:** the page edits a copy of the repeat. Back drops the copy, so choices
  changed on the page are lost and the repeat stays as it was. Opening Custom again starts from the
  repeat: a custom repeat's own choices, or the preset's.
- **Opening Custom no longer marks it:** the earlier mockups checked Custom as soon as its row was
  tapped. The app hasn't done that since first-version ticket 27, and now neither does this one.
- **Disabled:** the checkmark is disabled while the choices can't be saved (an end date before the
  start, or no times left), as Save is, and while the reminder is nudging. The mockup draws no other
  lock on the Custom page; the app locks its controls too (ticket 16).
- **Accessibility:** VoiceOver reads the checkmark as "Done, button", as it reads Save.
