# Android TV navigation and server entry — SOUP-95

The Festival onboarding now has an HTTPS/HTTP selector immediately left of the
server address. HTTPS is the initial selection. The field contains only the
address; entering a complete HTTP or HTTPS URL updates the selector and removes
the prefix while preserving the cursor position. Hostnames, ports, IPv6 addresses
and Jellyfin base paths are retained. The dedicated clipboard button is removed;
normal keyboard paste remains available. TV Down reaches Next and Up returns to
the address. Left from the TV field reaches the selector; Right returns to the
field. The native TV keyboard still owns directional input while editing.

Festival's top navigation has one focus stop per action, including Account
(which opens Settings). Left and Right stay within the navigation bar. Down on
Home enters the hero; Up from the hero returns to the selected navigation tab.
Returning to the hero restores the full section to the top of the viewport.

Home rows have explicit horizontal boundaries and retain their last focused
card when traversing vertically. Navigation can materialize an offscreen card
before focusing it. Returning to the first card restores the original inset in
both Festival and Blockbuster. Reduced-motion scrolling uses an immediate jump.

Detail grids now follow the visible arrow direction. Edge handling uses the same
column calculation as Flutter's grid delegate, including width breakpoints.
Up from the first row reaches Back. Series pages initially focus the first
season and scroll it into view on short displays. Episodes retain vertical navigation.

## Automated verification

`test/tv_navigation_test.dart` adds coverage for:

- Home → both recently added rows → full hero at 960×540 and 1280×720, with
  animations both enabled and disabled.
- Traversing long movie/TV rows to both ends and restoring their original inset.
- Held-arrow repeat events and lazy card construction.
- Continue Watching, remembered positions per row, and focus after a detail
  route closes.
- Each top-nav stop, both boundaries, Account, and Down to Home content.
- TV and Movies library destinations, empty Home, and Settings down to the
  final action and back to navigation.
- Detail grids at 960×540 and the 1030×540 column breakpoint, including vertical
  movement to the last row and back.
- Season selection and traversal down and back through episodes.
- Mobile and TV protocol selection, bare addresses, manually entered schemes,
  whitespace, ports, IPv6, base paths, draft preservation and TV field/Next focus.

The complete `task qa` run passes formatting, all three analyzers, and 258
tests (226 app, 8 Tailscale, 24 generated API).

Eight regression cases were also run against the previous commit: all eight
failed there and passed with the fixes. The existing native-editor, Quick Connect,
restoration, alternate-theme and phone-layout tests remain part of `task qa`.

## Physical-device verification

Device: Guest Room TV (Chromecast/sabrina), Android 14, 1920×1080 at density 320.
Installation uses `adb install -r` and preserves the existing signed-in account.
Onboarding is tested with automated phone/TV fixtures so the real session does
not need to be cleared. Device screenshots and UI dumps stay in the local
`/tmp/soup95-navigation` directory because they contain personal library data.

Verified on the device:

- Updating the release APK reopens the saved account with the hero focused.
- Home → TV → Movies → Settings → Account, with focus held at both nav edges.
- Down from Account reaches the hero at its full original vertical position.
- Movie row traverses eight cards right until its first card leaves the viewport,
  then restores that card to x=80 physical pixels (40 logical pixels).
- The current TV row contains five cards that fit in the viewport. Right holds
  at its last card; Left restores its first card at x=80. Longer TV rows are
  covered by the automated fixtures.
- Up from TV → movies → hero restores the complete hero, confirmed by matching
  the View details bounds and inspecting the full screenshot.

- Account opens Settings. Down reaches its final account action and Up returns
  to the Settings navigation tab, without activating or changing preferences.
- Both TV and Movies library grids move horizontally and vertically to the
  expected column. The first Movies load exceeded the harness’s initial fixed
  wait; navigation assertions ran after the content finished loading.
- A real series opens with its first season visible. Down/Up traverses episodes
  and returns to the season; no episode playback is activated.

- Movie details focus Play/Resume; Up reaches Back and Down returns to the play
  action. Hardware Back returns through the library to Home without playback.

- The process remained alive throughout the final-build navigation checks, with
  no fatal or unhandled exception entries in its captured log. A deliberate
  force-stop and reopen then restored the saved account and focused the hero.
- The installed APK checksum matches the final local release artifact.

Final release APK SHA-256:
`94fad512bdf9f3df386b6f8933c5ce47437d02a529a63c54b007b30fe226756c`.
