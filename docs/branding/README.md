# Soup identity — classic soup can / play

Selected for production in SOUP-89 on 2026-09-08.

The mark is an upright soup can with a large play cutout across a classic red and
cream split label. Pale mist-blue rims connect it to the existing UI accent and
the opaque cool-slate canvas coordinates with the onboarding background. It
replaces the cinema-ticket mark selected during SOUP-86. Existing user-selectable
library palettes and the onboarding flow are unchanged.

## Assets and integration

- [Production Flutter asset](../../apps/android/assets/branding/soup-icon.png)
- [Generated master / selected concept](concepts/soup-can-play-v2-campbells.png)
- Android copy: `apps/android/android/app/src/main/res/drawable-nodpi/soup_launcher_art.png`
- Shared widget: `SoupMark`, used in connectivity, appearance and library headers.
- Android adaptive launcher: `@mipmap/soup_launcher` (Soup supports API 31+).

The final PNG is a 1254 × 1254 opaque RGB app badge, not a transparent silhouette
or a vector master. Keep its own background and do not tint the entire image.
Flutter rounds its corners at display time; Android applies its launcher mask.
The Android foreground retains a 10dp inset so the upright can remains comfortably
inside circular and squircle masks. The selected master, Flutter asset and Android
copy are byte-identical, checked by a regression test. The launcher background
resource is checked against the onboarding slate token.

The previous fin PNG remains in the repository as an unused legacy source; it is
no longer declared in Flutter's assets or referenced by the UI. The rejected S
badge is preserved in commit `1d8c354`; the superseded cinema-ticket production
asset is preserved in commit `a1cc40e`.

## Generation provenance

Generated with the built-in image generation tool via the imagegen skill during
SOUP-89, using the first soup-can study as its edit reference. The selected master
was copied unchanged to both production assets. It deliberately evokes familiar
red-and-cream soup packaging without lettering or a third-party wordmark. This is
generated artwork, not a trademark-clearance claim.

## Final generation prompt

The exact edit prompt is preserved in the
[SOUP-89 generation record](concepts/soup-can-play-v2-campbells.md).
