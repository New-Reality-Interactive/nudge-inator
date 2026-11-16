# Nudge-inator iOS mockup: swipe through How Sharing Works, buttons in the top bar

The change mockup for swiping between the four pages of the How Sharing Works tutorial, with its
buttons in the top bar (spec #127, version 1.4.0). Copied from the
[Sharing tutorial mockup](../2026-11-15-sharing-tutorial/README.md). It's deleted when the 1.4.0
version mockup takes the change in.

Open [`index.html`](index.html) in a browser. The controls panel's **How Sharing Works (tutorial)**
section opens it each way. Swipe on the phone, or drag with the mouse.

## What changed since the Sharing tutorial mockup

- **The pages swipe.** Swipe left for the next page and right for the one before. The pages sit side by side and snap into place, as a paged `TabView` does. Swiping right on page 1 and left on page 4 does nothing.
- **The page dots are pinned** at the bottom, centred, and stay put while a page slides.
- **No Continue or Done button under the pages.** Only the page dots stay there, so a page gets more
  room in landscape and at the largest text sizes.
- **Close is top left**, where a sheet's dismiss goes, not top right.
- **Back and Next share one capsule, top right.** Back is dimmed on page 1.
- **On the last page** Next becomes the system's confirm button, as every sheet's confirm is: the accent-colored checkmark circle on iOS 26 and later, and the word Done on iOS 18. It is named Done for VoiceOver.
- Nothing else changes: the pages' words, pictures and order, when the tutorial opens, and the
  Settings row.
