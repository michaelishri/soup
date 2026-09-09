# Onboarding review screenshots

SOUP-92: film-festival poster typography, cobalt, acid yellow and ink on a paper
canvas. The transparent original Soup can remains unboxed. Bold Barlow Condensed
headings sit in crisp introduction panels with an offset print shadow; controls
use small corners and a strong colour change for remote focus. Quick Connect and
password sign-in share equal columns on TV and stack on phones.

The gallery includes the SOUP-95 server entry update: an HTTPS/HTTP selector
beside the address, with no dedicated paste button. SOUP-96 refreshes these
captures for the root README.

SOUP-98 adds server discovery cards, with manual entry available throughout the
search. The example server and its Tailscale address are fictional.

SOUP-99 replaces the phone Tailscale QR with **Authorise device on Tailscale**.
SOUP-100 opens that link in a Custom Tab and returns to Soup on connection or administrator
approval. An external-browser fallback retains manual return. TV retains its QR.
Browser launch and return require native phone validation; these fixture renders
verify the interface only.

Fine diagonal frames and the bottom filmstrip edge are painted in a separate,
noninteractive layer. A 36-second cycle updates at 20 fps without rebuilding
forms or moving focus. Reduced motion, accessible navigation, inactive routes
and app backgrounding stop the motion. Existing step/focus transitions also
respect reduced motion.

These are production Flutter widget renders with bundled headings, SDK Roboto and
icon fonts, and fixture network responses. They are not native device captures.
The QR URLs and Quick Connect code are demonstrations, with no real authorization
or credentials. TV captures use the production remote field widget; Android's
native editor is tested separately on Guest Room TV.

| Step | Android TV (960×540 logical) | Phone (412×915 logical) |
| --- | --- | --- |
| Welcome | [TV](welcome-tv.png) | [Phone](welcome-phone.png) |
| Tailscale authorisation | [TV QR](tailscale-qr-tv.png) | [Phone button](tailscale-authorisation-phone.png) |
| Tailscale connected | [TV](tailscale-connected-tv.png) | [Phone](tailscale-connected-phone.png) |
| Discovered Jellyfin server | [TV](jellyfin-discovery-tv.png) | [Phone](jellyfin-discovery-phone.png) |
| Jellyfin server | [TV](jellyfin-server-tv.png) | [Phone](jellyfin-server-phone.png) |
| Quick Connect / password | [TV](jellyfin-sign-in-tv.png) | [Phone](jellyfin-sign-in-phone.png) |
| Appearance (initial scroll position) | [TV](appearance-tv.png) | [Phone](appearance-phone.png) |

Regenerate from `apps/android`:

```sh
flutter test --dart-define=UPDATE_ONBOARDING_SCREENSHOTS=true test/onboarding_screenshots_test.dart
```

Regular tests do not update these files. Native device evidence is recorded in
[Guest Room TV validation](../../development/android-tv-design-2026-09-08.md).
