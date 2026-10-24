# Nudge-inator iOS mockup: Repeat checkmark

The Repeat page with a checkmark that saves its choice, as decided in enhancement-pace
[ticket 22](../../../.scratch/enhancement-pace/issues/22-repeat-saved-with-a-checkmark.md).
It's a copy of the [Custom checkmark mockup](../2026-10-24-custom-checkmark/README.md), changed only
for the Repeat and Custom pages, so the two can be compared screen by screen. Everything this README
doesn't list is as that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **The checkmark:** the Repeat page's navigation bar has a checkmark on the right, drawn as the
  form's Save checkmark and the Custom page's (an accent glass circle; the word on iOS 18). Tapping
  it makes the page's choice the repeat and goes back to the form. Tapped with nothing changed, it
  leaves the repeat as it was.
- **Back changes nothing:** the page edits a copy of the repeat, made when it opens from the form.
  Tapping a row checks it on the page only. Back drops the copy, so the repeat stays as it was.
- **Custom saves into the Repeat page:** the Custom page's checkmark now writes its choices to the
  Repeat page's copy, not the form. It goes back to the Repeat page with Custom checked and its
  summary under it, and nothing reaches the form until the Repeat page's checkmark is tapped. Back
  on the Repeat page drops that custom repeat too. Opening Custom again starts from the copy.
- **Cancel asks first:** a choice on the Repeat page that isn't saved yet, or a Custom page edit,
  counts as a change, so Cancel asks before discarding it.
- **Disabled while nudging:** the checkmark is disabled while the reminder is nudging, as the
  Custom page's is. The mockup draws no other lock on the Repeat page; the app locks its rows too
  (ticket 13).
- **Accessibility:** VoiceOver reads the checkmark as "Done, button", as on the Custom page.
