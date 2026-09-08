# Guest Room TV native acceptance — 2026-09-08

Tracked by SOUP-18 and the [acceptance matrix](android-acceptance.md).
This is a partial runtime pass; phone coverage and account-dependent TV cases
remain open.

## Device and artifact

- User-authorized Chromecast named Guest Room TV, connected using paired ADB
  wireless debugging.
- Android 14 / API 34; native ABI `armeabi-v7a`.
- Physical display 1920×1080, density 320 dpi: Flutter viewport 960×540 logical.
- Default font scale 1.0; device-wide animation settings were not changed.
- No Soup package was installed before this test. The prepared debug APK
  installed successfully without replacing or clearing an existing Soup session.
- Application `dev.michaelishri.soup`, version 1.0.0 (1); application source
  baseline `6a472e7432c4fbaeaecf526bc76f09a175ebfc6c`.
- APK SHA-256:
  `6e37150e82aab55acb908e523967ff4a44e72324518ea43f54029f7fa6ba91ea`.

## Observed results

1. Native installation and launch succeeded. The first cold debug launch
   exceeded `am start -W`'s approximately ten-second wait, but the app rendered
   and became ready afterward. Startup logs showed successful secure-storage
   initialization with zero existing items and skipped frames during startup;
   this is not release-performance evidence.
2. The selected red-and-cream can/play logo and slate/mist-blue welcome layout
   rendered on the physical TV. Android resolved Soup's `LEANBACK_LAUNCHER`
   intent to its main activity. Launcher tile/mask inspection remains pending.
3. D-pad Down focused the Tailscale switch with a visible blue outline; Down
   moved to Next and Select advanced to the direct server form. The native TV
   keyboard appeared. A Back path returned to the connection step. Full form
   validation, draft preservation and keyboard behavior remain open.
4. D-pad Up/Select enabled Tailscale. The embedded native library produced a
   real sign-in QR and a waiting-for-sign-in state. Next was disabled until
   connection. The QR bounds and New code action remained within the viewport.
   User authorization and Jellyfin server/test-account details were requested.
5. The pending QR was left in place for user authorization. Registration
   cancellation/retry, completed login/approval, restart/restoration, real
   browsing/playback and the preset matrix have not yet been completed.

## Native screenshot

This is an unmodified ADB capture from the Chromecast, with the Tailscale switch
focused. It contains no account information or live authorization QR.

![Guest Room TV welcome screen with D-pad focus](../screenshots/android-tv/guest-room-welcome.png)

Live QR captures, pairing credentials, device network identifiers and raw
runtime logs are excluded from repository evidence. Final visual acceptance is
still pending in SOUP-18.
