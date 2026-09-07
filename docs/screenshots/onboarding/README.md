# Onboarding review screenshots

Current direction: a full-screen cool slate canvas, soft white typography and
mist-blue controls, with a generated cinema-ticket/play app badge. TV uses a
side-by-side heading and form; phone uses a stacked
layout. There is no floating modal/card shell. These replace the earlier
charcoal-and-orange, apricot-accent and teal/S-badge captures (SOUP-84/85/86).

These images render the production Flutter onboarding widgets using SDK Roboto
fonts and fake connection/server responses. They are headless UI renders, not
Android emulator captures. The QR codes contain demonstration URLs and do not
authorize a real device. No account credentials are included.

| Step | Android TV (960×540 logical) | Phone (412×915 logical) |
| --- | --- | --- |
| Welcome | [TV](welcome-tv.png) | [Phone](welcome-phone.png) |
| Tailscale QR | [TV](tailscale-qr-tv.png) | [Phone](tailscale-qr-phone.png) |
| Jellyfin server | [TV](jellyfin-server-tv.png) | [Phone](jellyfin-server-phone.png) |
| Jellyfin sign-in | [TV](jellyfin-sign-in-tv.png) | [Phone](jellyfin-sign-in-phone.png) |

Regenerate from `apps/android`:

```sh
flutter test --dart-define=UPDATE_ONBOARDING_SCREENSHOTS=true test/onboarding_screenshots_test.dart
```

Regular tests do not update these files. Native Tailscale registration, actual
QR scanning, media playback, and Android keyboard behavior still require an
Android device or emulator for end-to-end validation.
