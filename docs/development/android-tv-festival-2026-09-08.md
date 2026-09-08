# Festival theme validation — 2026-09-08

SOUP-93, following the approved SOUP-92 onboarding direction.

## Behaviour

New/unconfigured devices use Fruity / Festival / Light. The persisted schema and
storage key remain version 1. Every existing layout, palette and brightness
value is decoded unchanged; the prior Soup/orange palette remains available.
Festival also has an explicit dark version and works with Blockbuster.

Settings → Use default edits the appearance draft. Apply appearance saves it,
keeps the current Settings destination, restores remote focus to Apply and
scrolls that action into view. Bottom padding keeps it above the save message.

The default layout pairs a cobalt programme panel with the featured artwork.
Its height follows the copy, with a stacked phone arrangement. Details use a
matching title panel. Navigation, media-card focus, chips, dialogs and Settings
controls share the crisp edges and colour treatment. Playback receives a dark
local theme even when the surrounding app is light.

## Automated validation

- Full `task qa`: formatting, all three analyzers and 222 tests pass (191 app,
  7 Tailscale, 24 generated API).
- The Festival interaction suite checks light/dark at 960×540, 412×915 and
  320×640 with 130% text. It opens details, returns to Settings, applies a theme
  without losing the destination, and checks default restoration stays a draft
  until Apply. Remote focus and visible Apply are checked after saving.
- Both layouts fit the Chromecast's 960×540 logical viewport with enlarged text.
- Contrast covers body text, surfaces, primary/selected controls and both button
  focus states. The real player widget is checked under a light parent theme.
- Existing version-1 appearance combinations round-trip without migration.

[Review gallery](../screenshots/festival/README.md) uses production widgets,
bundled fonts and original geometric fixture artwork. Onboarding captures were
also regenerated for the new default choice. Ordinary QA does not rewrite them.

Debug APK SHA-256: `1bd84b3ef3960f8292dd6b977b547d56230eb343776e53a3587b4fe9748f8d34`.

## Guest Room TV

Chromecast/sabrina, Android 14/API 34, 1920×1080 physical / 960×540 logical.
Replacement install preserved the existing signed-in Jellyfin session,
Tailscale identity and stored appearance. The old theme was visible after
upgrade, confirming that saved choices were not overwritten.

The signed-in library became available during this session, so native checks
used existing artwork and metadata. A prepared disposable HTTP fixture was
stopped without using it. Native screenshots remain local; no real library or
account content is added to the review gallery.

Native checks passed:

- D-pad navigation reached Use default and Apply, and Festival/light applied
  without leaving Settings or signing out.
- The home featured panel rendered real artwork beside readable cobalt copy.
  Remote navigation scrolled to a media card and opened its details page; Back
  returned to the library. No playback or progress changes were made.
- The final APK retained Festival after replacement install and restarted into
  the signed-in library, with View details focused.
- Selected Dark and Apply using only D-pad/Select. The final build kept Apply
  focused at physical bounds `[80,780][440,888]`, fully above the save message.
  The dark canvas, selected chips and focused action were inspected on device.
- Returned to Light and applied it with the remote. Apply retained focus and
  remained visible in that direction too. The final process log contained no
  Flutter error or Android crash entries during the native checks.

Physical-phone and real-media playback acceptance remain separate under SOUP-18.
This work checks appearance and player controls; it does not establish decoder
or release-performance acceptance.
