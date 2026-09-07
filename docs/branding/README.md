# Soup identity — cinema ticket / play

Selected for visual review in SOUP-86 on 2026-09-08.

The new mark is a single cinema-ticket silhouette with a play cutout. It replaces
the linked S concept, which the user felt suggested a security product. The
approved mist-blue UI accent remains exactly `#AFD9EA`; the green/teal canvas
and supporting surfaces are replaced by coordinated cool slate shades.
Existing user-selectable library palettes and the onboarding flow are unchanged.

## Assets and integration

- [Generated master / Flutter asset](../../apps/android/assets/branding/soup-icon.png)
- Android copy: `apps/android/android/app/src/main/res/drawable-nodpi/soup_launcher_art.png`
- Shared widget: `SoupMark`, used in connectivity, appearance and library headers.
- Android adaptive launcher: `@mipmap/soup_launcher` (Soup supports API 31+).

The final PNG is a 1254 × 1254 opaque app badge, not a transparent silhouette
or a vector master. Keep its own background and do not tint the entire image.
Flutter rounds its corners at display time; Android applies its launcher mask.
The ticket is centered; the Android foreground adds a 10dp inset to give its
wide silhouette extra clearance from circular and squircle launcher masks.
Both app consumers use byte-identical copies, checked by a regression test.
The launcher background resource is checked against the onboarding slate token.

The previous fin PNG remains in the repository as an unused legacy source;
it is no longer declared in Flutter's assets or referenced by the UI. The
rejected S badge and its original prompt are preserved in commit `1d8c354`.

## Generation provenance

Generated with the built-in image generation tool (imagegen skill), not the
CLI/API fallback. The selected output was copied unchanged into the repository.
This pass deliberately uses an opaque slate badge; earlier transparent studies
had export artifacts. This is a generated concept, not a trademark-clearance claim.

## Final generation prompt

```text
Use case: logo-brand
Asset type: finished square app icon for Soup, a modern Jellyfin movie and television client.
Primary request: Create a polished minimalist CINEMA TICKET / PLAY logo that clearly belongs to an entertainment app. A single solid horizontal ticket silhouette, softly rounded corners, a small semicircular notch halfway along each short side, and a generously sized right-pointing play triangle cut out of its centre. The triangle uses the background colour. One cohesive silhouette, not two interlocking elements. No letters or monogram. Confident, friendly proportions with a little character, exceptionally readable when reduced to a 24-pixel app badge. Avoid fiddly details: no perforation line, no outline, no additional shapes.
Style: precise flat two-colour vector-like graphic, clean smooth edges, uniform solid fills, no gradients, grain, depth, shadows, reflections, lighting or texture.
Colour palette: mist-blue #AFD9EA ticket on a completely solid opaque cool slate #202936 square canvas. No teal or green. The background extends edge to edge, no second background or surrounding mockup. This deliberately opaque asset must not have a checkerboard or simulated transparency.
Composition: one centred horizontal ticket, straight with no tilt, symbol width 58 percent of the square canvas and height about 40 percent, generous even margins for Android adaptive icon cropping.
Constraints: NO chain links, NO overlapping or interlocking shapes, NO loops, NO letter S, NO lock, NO shield, NO security symbolism, NO fin or shark, NO text, NO watermark. Only the actual square icon, no presentation board.
```
