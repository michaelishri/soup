# Soup identity — geometric S

Selected for visual review in SOUP-85 on 2026-09-08.

The new mark uses two opposing rounded bands to suggest an S. Mist-blue
controls replace the apricot accent on the approved teal onboarding canvas.
Existing user-selectable library palettes are unchanged.

## Assets and integration

- [Generated master / Flutter asset](../../apps/android/assets/branding/soup-icon.png)
- Android copy: `apps/android/android/app/src/main/res/drawable-nodpi/soup_launcher_art.png`
- Shared widget: `SoupMark`, used in connectivity, appearance and library headers.
- Android adaptive launcher: `@mipmap/soup_launcher` (Soup supports API 31+).

The final PNG is a 1254 × 1254 opaque app badge, not a transparent silhouette
or a vector master. Keep its own background and do not tint the entire image.
Flutter rounds its corners at display time; Android applies its launcher mask.
The generated S has generous padding for the adaptive-icon safe zone.
Both app consumers use byte-identical copies, checked by a regression test.

The previous fin PNG remains in the repository as an unused legacy source;
it is no longer declared in Flutter's assets or referenced by the UI.

## Generation provenance

Generated with the built-in image generation tool (imagegen skill), not the
CLI/API fallback. The selected output was copied unchanged into the repository.
Earlier transparent ribbon studies were discarded because their alpha exports
contained visible artifacts. The final deliberate opaque treatment avoids that
problem. This is an original generated concept, not a trademark-clearance claim.

## Final generation prompt

```text
Use case: logo-brand
Asset type: finished square app icon for Soup, a contemporary Jellyfin film and television app.
Primary request: A beautifully simple, original geometric S symbol, constructed from TWO thick opposing rounded geometric bands, balanced negative space, blunt softly rounded ends. Abstract and compact, with the clarity of a premium modern app identity. It should communicate fluidity without any literal illustration. Strong silhouette readable at 24 pixels. No sharp tips, no hooks, no fin-like curves.
Style: absolutely FLAT two-colour vector-like graphic, perfectly uniform fills, impeccably clean smooth edges. No thin lines, no overlapping ribbon seams, no texture, no 3D or shading.
Colours: solid mist-blue #AFD9EA symbol on a completely solid opaque deep-teal #203C40 square background. Every background pixel exactly the same deep teal. Do NOT make the background transparent; do NOT use any checkerboard. No gradients anywhere.
Composition: one centered symbol, occupying 58 percent of the square canvas width and height, with generous even deep-teal padding on all sides. The canvas itself is a full square, not a rounded tile drawn on another background. No border.
Text: none. No wordmark, labels, slogan or presentation sheet.
Avoid: shark, fin, fish, cooking bowl, literal play triangle, ornamental curls, ribbons with folds, shadows, highlights, mockup, photograph, grain, speckles, checkerboard, watermarks. Deliver only the finished square app icon.
```
