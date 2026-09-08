# Soup identity — soup can / play

The red-and-cream can selected in SOUP-89 remains the production mark. SOUP-92
removes its slate backdrop and surrounding tile. The can now sits directly on
its host surface in connectivity, appearance and library headers.

## Assets and integration

- [Transparent production master](concepts/soup-can-play-transparent.png): 1024 × 1024 RGBA.
- [Flutter asset](../../apps/android/assets/branding/soup-icon.png).
- Android copy: `apps/android/android/app/src/main/res/drawable-nodpi/soup_launcher_art.png`.
- Shared widget: `SoupMark`, with no tint, enclosing tile or corner clipping.
- Android adaptive launcher: `@mipmap/soup_launcher`, with a 22dp inset and paper background. Android still supplies the platform's required launcher mask.
- Native launch backgrounds match the paper onboarding canvas in light and dark system mode.

The transparent master and both production copies are byte-identical. Regression
checks cover their alpha border, visible can, preserved dark play symbol, and
launcher background. The tightly framed can remains readable at small sizes.

## Onboarding visual language

The onboarding takes its cues from film-festival posters: cobalt introduction
panels, acid-yellow highlights, ink-black controls and an off-white paper canvas.
Condensed Barlow headings, crisp corners and offset print shadows give it a
distinct graphic character. Fine diagonal frames and a narrow filmstrip edge
provide subtle motion. Body copy and native editors retain platform typography
for reading and editing.

The font is an unmodified ExtraBold TTF from the
[Google Fonts Barlow Condensed distribution](https://github.com/google/fonts/tree/main/ofl/barlowcondensed).
Its [SIL Open Font License](../../apps/android/assets/fonts/OFL.txt) ships with the
app and is registered in Flutter's license registry. No runtime font download is
needed. The app's user-selected library palettes remain available. SOUP-93 extends this
identity into the default Festival library theme, with light and dark versions;
see the [Festival gallery](../screenshots/festival/README.md).

## Artwork provenance

The [original generated master](concepts/soup-can-play-v2-campbells.png) and its
[SOUP-89 generation record](concepts/soup-can-play-v2-campbells.md) are retained.
The SOUP-92 transparent derivative uses that original, without redrawing the can.

Background removal used Pillow: flood-fill only the connected dark exterior
(maximum RGB channel below 90), preserve the enclosed play symbol, recover colour
and coverage at the antialiased perimeter, then centre an 820px square crop and
resample to 1024px. The connected foreground bounds in the original were
`(356, 265, 898, 994)`. The result was inspected against both cream and slate.

The previous fin source is unused. Superseded S-badge and cinema-ticket production
assets remain in git history.
