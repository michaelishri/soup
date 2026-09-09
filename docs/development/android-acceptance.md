# Android phone and TV acceptance — SOUP-18

SOUP-18 is the single open acceptance record for the 2026-09-08 In Review
cleanup. It retains the original cross-preset requirements and the native
checks transferred from the completed implementation tickets. Closing those
tickets does not establish that native acceptance passed.

## Application and evidence baseline

- Application commit: `6a472e7432c4fbaeaecf526bc76f09a175ebfc6c`, verified on
  GitHub `main` on 2026-09-08. All 27 original review-ticket implementation
  commits are ancestors of this commit.
- Current design: full-screen slate/mist-blue onboarding, SOUP-87 interaction
  polish, and the red-and-cream can/play logo selected in SOUP-89.
- Historical verification at this baseline: SOUP-89 records 143 passing tests
  (124 app, 7 Tailscale, 12 API), clean formatting/analysis, two opt-in screenshot
  render tests and a successful debug APK build. Housekeeping did not rerun
  these suites because the application code was unchanged.
- The [onboarding gallery](../screenshots/onboarding/README.md) contains
  production-widget renders with fake network data and demonstration QR URLs.
  Native QR scanning, playback and Android input remain unverified by those
  images.
- Initial host check found no ADB devices, `/dev/kvm`, or exposed `vmx`/`svm`
  CPU flags. The user subsequently provided Guest Room TV; wireless pairing,
  installation and native onboarding checks succeeded. SOUP-90 then fixed
  success focus and TV IME navigation, with 151 passing automated tests and
  a new APK installed over the existing enrollment. See the
  [Chromecast session report](android-tv-2026-09-08.md). Phone access and the
  remaining account-dependent checks are still outstanding.

SOUP-91 subsequently adds Quick Connect alongside password sign-in. Its
[Guest Room TV acceptance report](android-tv-quick-connect-2026-09-08.md) records
real Jellyfin 10.11.1 approval over embedded Tailscale, native editor pause/resume,
and the feature's current APK and 210 passing tests. This is additional
onboarding evidence; it does not replace the remaining media and phone checks.

The local debug artifact checked during housekeeping is
`apps/android/build/app/outputs/flutter-apk/app-debug.apk` (275,923,962 bytes),
with SHA-256:

```text
6e37150e82aab55acb908e523967ff4a44e72324518ea43f54029f7fa6ba91ea
```

This identifies the existing artifact; it is not evidence of a fresh build or
a device run. If rebuilding, record the new source commit and APK checksum.
The source currently uses application ID `dev.michaelishri.soup` and minimum
Android API 31. SOUP-75 separately owns the proposed `cc.mishri.soup` package,
release signing, Google Play publication and Play-installed acceptance.

## Runtime access needed

Use an Android phone and Android TV/Google TV, or suitable accelerated emulators.
Record coverage separately: a phone pass does not prove remote/TV behavior.
Provide a test Jellyfin account/server with playable media and a user-controlled
Tailscale test account/tailnet. The user completes real browser sign-in on mobile
or QR sign-in on TV, and any administrator approval. Record unavailable multi-tailnet or approval scenarios
as blocked rather than passed. Keep credentials and live authorization URLs out
of screenshots and ticket evidence.

Use a dedicated test device/profile for fresh onboarding so an existing session
can be retained for the restoration checks. From the repository root, after ADB
access is available, replace `DEVICE_SERIAL` with the selected device:

```sh
adb devices -l
adb -s DEVICE_SERIAL install -r apps/android/build/app/outputs/flutter-apk/app-debug.apk
adb -s DEVICE_SERIAL shell am start -n dev.michaelishri.soup/.MainActivity
```

If a new build is needed, use the documented Linux build command above. Do not
substitute a differently signed APK by uninstalling an existing app with test
data; resolve package/signing compatibility first.

## Acceptance cases

For each row record phone and TV results independently as pass, fail, blocked or
user-approved deferral. Include the actual device/OS, source commit, artifact
checksum, screen dimensions/density, observations and any defect ticket. Leave
unexecuted cases blocked. Preserve the final visual/interaction decision in
SOUP-18.

| Case | Exercise and expected result | Phone | TV |
| --- | --- | --- | --- |
| A1: Install and branding | Launch the native app; inspect the selected can/play mark in the app and launcher, including available circular/squircle masks. No clipped artwork, wrong legacy logo or startup failure. | Blocked: device | Partial: install, launch, in-app branding and TV launch intent verified; launcher masks pending |
| A2: Direct connection | Start with Tailscale off; enter the test server; exercise invalid and valid credentials, Back, draft preservation and keyboard insets. Browse real artwork/details and play real media with pause/seek/resume and progress reporting. Restart and verify session restoration. | Blocked: device/account | Partial: direct server form and native keyboard reached; server/account needed |
| A3: Fresh Tailscale registration | Enable Tailscale. On mobile, tap Authorise device on Tailscale, complete sign-in in the Custom Tab and verify it closes automatically; on TV, scan the real QR on another device. Choose the intended tailnet where available and complete administrator approval. Waiting and success states are correct; connection requires explicit Next. | Blocked: device/account | Partial: user authorization completed; connected/Next handoff verified; separate approval and multi-tailnet scenarios pending |
| A4: Registration recovery | Cancel during preparation/waiting; obtain a new link on mobile or code on TV; retry a failed attempt; toggle Tailscale off/on. On mobile, verify Back/close preserves the pending attempt and the same link can reopen. Verify automatic return for connection and pending administrator approval, plus external-browser fallback and retryable launch failure. An old attempt cannot complete the new one or advance the UI. Background/reopen and restart; verify restored-node, saved-session reauthorisation and legacy-session behavior with suitable fixtures. | Blocked: device/account | Partial: toggle off/on and saved-node restoration verified; failure/approval and legacy-session paths pending |
| A5: Tailscale media path | Through the embedded node, sign into Jellyfin, load artwork/details and play real media. Verify controls, progress, error recovery and restored access after app restart. | Blocked: device/account | Partial: fixture discovery/authentication exercised through the embedded node; real server/media account needed |
| A6: Onboarding interaction | Verify phone touch/keyboard and TV remote/keyboard traversal, readable TV QR quiet zone, accessible mobile authorisation button, visible actions at short heights, stable header/footer, success transition, rapid Back/Next and reduced-motion behavior. | Blocked: device | Partial: SOUP-90 verifies success/Back focus, native keyboard navigation, drafts, validation and retry; native reduced-motion/enlarged-text checks pending |
| A7: Appearance and persistence | Exercise Fruity/Blockbuster × Festival/Soup/Ocean/Grove/Mono × light/dark (20 combinations). Check first-use selection, explicit Apply, switching without losing the destination, settings persistence after restart/sign-out, and fixed-style setup/login. | Blocked: device/account | Partial: first-use focus/Continue verified with fixture; full combinations and persistence checks pending |
| A8: Browsing and accessibility | Exercise current Home, TV/Movies, details/episodes, playback and Settings with empty/loading/error/retry and missing-artwork states. Verify directional focus, return from details, active-vs-focused navigation, transparent rail focus, expansion/collapse, full hero visibility on return, enlarged text, contrast, reduced motion and usable touch targets. | Blocked: device/account | Partial: fixture empty library and D-pad Settings navigation verified; real browsing/media and accessibility pending |
| A9: Visual acceptance | Review the current palette/layout/branding and animations on both form factors. Compare with the current gallery and record the user's acceptance or concrete changes requested. | Pending | Pending |

Cover the original 412×915 phone and 1280×720/1920×1080 TV layout targets;
record actual physical and logical dimensions rather than relabelling a capture.
Any unavailable size remains an explicit gap. Automated contrast, corrupt-setting
fallback and fake-network widget evidence can support this matrix but cannot
replace the native runtime cases.

SOUP-100 adds Custom Tabs and automatic return for mobile onboarding and saved-session
reauthorisation, using native Tailscale status. TV retains QR sign-in. SOUP-99’s
external-browser flow was tested by the user on their phone; automatic Custom Tab
return still needs real phone verification. Only a Chromecast is connected and
the installed emulator is Android TV. Controller/widget tests cover automatic
dismissal, approval, races, manual return, fallback and saved-session recovery;
they do not substitute for the native browser checks in A3–A4.
Auth-key entry remains absent from Soup onboarding. The package-level auth-key
API remains supported; its real provisioning check from SOUP-78 also needs a
disposable test credential and a suitable native harness.
Keep that package-only check open in SOUP-18 until exercised or explicitly
deferred; never store the credential in the evidence.

## Ticket reconciliation

| Original tickets | Disposition during housekeeping |
| --- | --- |
| SOUP-15–17 | Implementation and historical checks complete; missing push blocker resolved. Current-device acceptance is A7–A9. |
| SOUP-18 | Retained and expanded as this single open acceptance ticket. Original cross-preset scope remains in its description. |
| SOUP-20, 22–24, 26, 28, 30, 32–33 | Implemented with historical automated/emulator evidence. Current browsing, navigation and visual acceptance are A8–A9; later hero/sidebar changes govern the current UI. |
| SOUP-31, 35–36, 80, 85, 88 | Earlier assets/explorations completed and superseded by the explicit SOUP-89 production selection. No earlier logo selection remains outstanding. |
| SOUP-76–79 | Implemented; remaining native registration/media evidence is A3–A6 plus the package-only auth-key check above. Earlier app browser/auth-key controls and card layout were superseded. |
| SOUP-82, 84, 86–87 | Implemented and pushed; native runtime and final visual/interaction acceptance are A1–A9. SDK/build failure is resolved by SOUP-83; earlier colors/logos are superseded by SOUP-89. |

SOUP-75 remains the separate release workstream. Record any acceptance failures
as concrete bug tickets and link them to SOUP-18. Close SOUP-18 only when the
matrix and package-only check have evidence or explicit user-approved deferrals,
and final visual acceptance is recorded.
