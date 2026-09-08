# Reopening and saved setup — 2026-09-08

SOUP-94. Guest Room TV: Chromecast/sabrina, Android 14/API 34,
1920×1080 physical / 960×540 logical.

## Findings

Reopening the previous build reproduced the server-address step. The Tailscale
identity and Festival/light appearance still existed, but the encrypted
preferences contained a device ID and no Jellyfin session. That absence was
observed before installing or signing into a fixture in this task. The retained
logs do not establish exactly when or why that session was removed.

The collected Android exit history contained package updates and intentional
force stops, with no recorded Soup crash or ANR. No fatal Android, native signal,
or unhandled Flutter error appeared in the initial process logs. This does not
rule out the user's intermittent crash report.

Code and native lifecycle investigation identified several concrete problems:

- Startup could show the connection form before stored setup finished loading.
  Its controls became available while an existing Tailscale session was still
  restoring. A storage error was also treated as incomplete onboarding.
- The installed secure-storage dependency defaults to `resetOnError: true`.
  Its Android read error path can delete the affected entry and retry, yielding
  an absent session. Soup now explicitly disables that behavior. This is a
  confirmed risk in the previous configuration, not a proven explanation for
  the already-missing session.
- An activity exit destroyed the Flutter engine, but native libtailscale nodes
  belong to the Android process and are held in its global server map. Dart
  widget disposal is not guaranteed on engine destruction. A Back/reopen cycle
  created another engine in the same PID; observed socket counts increased from
  27 to 34 and threads from 62 to 66. These are diagnostic samples, not a memory
  benchmark or proof of the reported crash.
- Tailscale reconnection left an existing account on the setup screen. Routes
  could also outlive the API transport they used.
- Back from Settings/TV/Movies could exit the app directly, and failed library
  initialization had no retry action.

## Changes

The Android activity now reuses one application-context Flutter engine per
process, retaining the isolate that owns Tailscale. Activity-bound editor and
network channels detach and reattach with the activity. Privacy-safe lifecycle
logs distinguish engine creation, reuse and activity detachment. OS process
death still causes normal restoration from disk on the next launch.

Soup waits for both saved sign-in and appearance reads before showing setup.
Read failures and malformed saved account or appearance values produce a retry screen without clearing
the account or choosing first-use defaults. In-flight initialization cannot
change transport or clear the session; appearance loading also tolerates widget
disposal safely.

Existing accounts receive a dedicated Tailscale recovery screen. Reconnection
reuses the saved node after network failures, requests authorization only when
the node requires it, and automatically opens the library when connected. Old
detail/player routes are removed when their account or transport is replaced.
LocalAPI requests have a five-second deadline, including the response body;
restoration polling has a 30-second limit checked between bounded requests.

Library initialization can retry. Library and details controllers stop notifying
closed screens, and refuse new work after disposal. Back from a secondary library destination
returns Home, while Back at Home retains normal Android exit behavior.

References: [Flutter engine lifetime](https://docs.flutter.dev/add-to-app/android/add-flutter-screen),
[secure-storage Android options](https://pub.dev/documentation/flutter_secure_storage/latest/flutter_secure_storage/AndroidOptions-class.html).
Implementation was checked against the locally installed Flutter and
flutter_secure_storage 10.3.1 sources.

## Confirmed asynchronous lifecycle error

Six regression cases were run against the previous commit's library and details
controllers: leaving during successful or failed library, item, and episode
loads. All six failed with `used after being disposed`. They pass with the
lifecycle guards. This confirms a Flutter error path during navigation; it does
not prove that it caused the user's separate reported Android exits.

## Automated validation

`task qa` passes: formatting, all three analyzers, and **245 tests** (213 app,
8 Tailscale, 24 generated API).

Regression coverage includes password and Quick Connect completion followed by
a new app instance in both connection modes; slow storage/native restoration;
session, appearance and connection preference read failures with retry; corrupt
session preservation; recovery without repeating setup; removal of obsolete
routes; library initialization retry; Back from Settings; disposal during
startup; recovery QR layout at TV and small-screen sizes; a stalled LocalAPI
body followed by a successful request; and successful/failed requests completing
after library, details and season screens have closed.


## Native validation

A disposable local Jellyfin fixture was used for account persistence and
navigation tests. It used the existing embedded Tailscale identity; the app was
never uninstalled and its data was never cleared.

The debug build completed native username/password sign-in, returned to Home
on a Back/reopen cycle, and restored the encrypted session and Festival
appearance after an intentional force stop. In the new process, two further
activity recreations used one renderer startup. No fatal/error markers appeared
in the captured process log. These checks verify session restoration separately
from restoring an activity that still has in-memory state.

The release APK replaced the debug build without clearing data and restored the
fixture account immediately. Two Back/launch cycles retained the library and
PID; `SoupLifecycle` recorded one engine creation and two reuses. D-pad Select
opened details both before and after activity recreation, and Back returned to
the library. A missed Select was observed in a debug run that also used injected touch input; it did not reproduce
in these release checks. No claim is made that an unrelated intermittent crash
has been reproduced or eliminated.

An additional release cold start with the fixture server stopped retained the
account and cached library, showing a retry banner instead of onboarding.
Restarting the fixture and selecting Try again refreshed the library and removed
the error. The test exposed raw proxy diagnostics in that banner; metadata
refresh now preserves the cached content with a readable failure message, with
a regression test covering recovery. Back from Settings was checked separately
on device and returned to the signed-in Home screen without exiting.

The native persistence/recovery checks above used the release build
`299192379938c92fce20d03107b6eeef8edba542978892d52a877d749c0405ef`,
before adding the library/details late-notification guards.
The build uses the repository's existing local debug signing configuration for
release testing; no signing keys or release configuration were changed.

That release was installed and the offline cold-start check repeated:
the account and cached library remained visible, the banner used the readable
message, and no onboarding step or raw exception appeared. Captured final
process logs contained no fatal Android/native or unhandled Flutter errors.
Physical-phone and real-media playback/decoder acceptance remain under SOUP-18;
this investigation does not establish long-duration playback stability.

Final reviewed release APK (including the late-notification guards):
`8b5bb403fc18991a01cb10822ff632469e8e7c681429a88e7943e68270b7cd63`.
The disposable account was signed out through Settings and the local fixture
server stopped. Tailscale identity and Festival/light preferences were retained.
The previous real Jellyfin token was already absent before testing; one new
Jellyfin sign-in is needed to resume that account.
