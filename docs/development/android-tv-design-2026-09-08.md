# Guest Room TV: onboarding design, 2026-09-08

SOUP-92, supporting SOUP-18. Device: Guest Room TV, Chromecast/sabrina,
Android 14/API 34, armeabi-v7a; 1920×1080 physical / 960×540 logical.
Package: `dev.michaelishri.soup`.

## Change

Film-festival poster styling: cobalt panels, acid-yellow highlights, ink controls,
Barlow Condensed headings, crisp corners and offset print shadows. Fine frame
outlines and a narrow filmstrip edge move behind the content. The original can
has a transparent canvas across connectivity, appearance and library headers.
Native splash, launcher and TV editor use the same paper/cobalt palette.

## Validation

The interaction suites load the actual condensed font so short screens, large
text and remote focus are checked against production heading metrics. Contrast
checks cover the paper, blue poster, yellow sign-in panel, body text and controls.
A native resource check guards against the TV supplying pale text on a light
editor canvas. Both the editor context and AlertDialog explicitly use Soup's
light theme and text colours, preserving the working Gboard input path.

Motion checks confirm that only the background moves: foreground layout, builds,
focus and pointer actions stay stable. Reduced motion, accessible navigation,
disabled TickerMode, backgrounding and resuming are covered.

[Production-widget captures](../screenshots/onboarding/README.md) cover connection,
QR, connected, server, both sign-in methods and appearance on TV and phone.
These use fixture data with no live codes or user credentials.

This design task does not establish physical-phone, media playback or complete
Settings D-pad acceptance; those remain tracked under SOUP-18.

## Guest Room TV results

The new debug APK was installed with replacement install, preserving the saved
Tailscale identity. The existing transport reconnected and reached the server
step. The poster, fields and footer fit the physical TV without clipping.

- Selecting Server address opens the native editor and Gboard. The editor has
  dark title/hint text and cobalt labels on acid-yellow buttons.
- D-pad Right then Down moves Gboard focus from Q to S. Arrow keys navigate the
  keyboard correctly.
- Back retains the typed address and returns focus to the server field. D-pad
  navigation reaches Next without opening the keyboard again.
- The live server loads both sign-in panels and a Quick Connect code. Username
  receives initial focus without opening the editor. Down reaches Password and
  Left reaches the Quick Connect action.
- Back returns to the server step with the address intact. No sign-in was completed
  for this design check.
- Returned to Welcome with Tailscale connected, Next focused and the server
  address retained for the next step.

[Native welcome capture](../screenshots/android-tv/guest-room-poster-welcome.png)
shows the final TV state. The [native keyboard capture](../screenshots/android-tv/guest-room-poster-keyboard.png)
shows the final editor colours and the selected S key. Live server details and
Quick Connect codes are excluded from the committed screenshots.

The app process log contained Android renderer swap-behaviour and IME callback
messages; no Flutter exception or app crash was observed during these checks.

## Automated results

- `task qa`: formatting and all three analyzers passed; 182 app, 7 Tailscale and
  24 generated API tests passed (213 total).
- Production-widget screenshots rendered successfully on TV and phone.
- Debug APK built successfully. SHA-256: `bd4fc1a31bffbdf87743ad39fe5653fa430549022a86aceb20cf49f63081f570`.
