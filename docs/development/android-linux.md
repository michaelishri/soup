# Android builds on headless Linux

An Android emulator is not required to compile Soup. Install a JDK, the Android
SDK command-line tools, and the SDK/NDK versions selected by Flutter. This
checkout uses Flutter 3.44.7, compile SDK 36 and NDK 28.2.13676358.

## Tools installed on the development host

- OpenJDK 21, installed with Ubuntu's package manager.
- Android SDK at `/home/mishri/Android/Sdk`.
- Google's command-line tools, platform tools, API 35 and 36 platforms, build tools
  36.0.0, NDK 28.2.13676358, CMake 3.22.1, emulator, and API 36 Android TV
  x86_64 image.
- Existing Go toolchain and the pinned libtailscale submodule.

Flutter's SDK and JDK locations are configured using `flutter config`. The
user's login profiles export `ANDROID_HOME`, `JAVA_HOME`, and the SDK tool paths.
Open a new login shell to use `adb`, `sdkmanager`, `avdmanager`, and `emulator`.

The Linux command-line tools archive was downloaded from
[Google's Android tools page](https://developer.android.com/studio#command-tools)
and verified against its published SHA-256 checksum before extraction. SDK
components are managed by `sdkmanager`.

## Building with limited memory

This VM has approximately 3.3 GiB of RAM. Its user-level
`/home/mishri/.gradle/gradle.properties` limits Gradle to a 1536 MiB heap,
512 MiB metaspace, two workers, and in-process Kotlin compilation. This local
configuration overrides the repository's larger default without imposing VM
limits on other developers.

From `apps/android`, reduce Go compilation parallelism and put build scratch
files on disk rather than the host's small RAM-backed `/tmp`:

```sh
mkdir -p /home/mishri/.cache/soup-build-tmp
TMPDIR=/home/mishri/.cache/soup-build-tmp GOMAXPROCS=2 GOMEMLIMIT=512MiB GOFLAGS=-p=1 flutter build apk --debug
```

Verified on 2026-09-07: the first debug build completed successfully in roughly
17 minutes, producing `build/app/outputs/flutter-apk/app-debug.apk` (240 MiB).
The APK includes Flutter and native Tailscale libraries for `arm64-v8a`,
`armeabi-v7a`, and `x86_64`. Flutter's Android toolchain check passes, including
accepted SDK licenses.

## Headless emulator limitations

Headless mode removes the emulator window; it does not provide CPU
virtualization. This host currently exposes neither `/dev/kvm` nor the CPU
`vmx`/`svm` flags. Its hypervisor must expose nested virtualization before an
accelerated Android emulator can run.

See Google's [emulator command-line options](https://developer.android.com/studio/run/emulator-commandline)
for `-no-window` and software-emulation options. Run `emulator -accel-check`
after any hypervisor change. An Android device connected through ADB is another
way to validate native Tailscale, QR scanning, and playback.

The installed `Soup_Android_TV_API_36_Headless` AVD uses the Android TV x86_64
image, a 720p display, 1536 MiB RAM, and keyboard input. Once hardware
acceleration is available, start it from a login shell with:

```sh
emulator -avd Soup_Android_TV_API_36_Headless -no-window -no-audio -gpu swiftshader -no-snapshot
```

A bounded software-only test on 2026-09-07 added `-no-accel`, `-no-boot-anim`,
`-cores 2`, and `-memory 1536`. The emulator process started, but ADB remained
offline throughout the four-minute window. The test was stopped without
installing or launching Soup. This does not establish that software boot is
impossible, but native runtime behavior and emulator screenshots remain
unverified on this host.

The [onboarding screenshots](../screenshots/onboarding/README.md) can be regenerated
using the headless Flutter test renderer without an emulator.

## Emulator Tailscale and ABI

Embedded Tailscale needs an AVD ABI that matches the APK (`x86_64` or `arm64-v8a`).
On a Linux/x86_64 host use:

```sh
task emulator:tv:start
# defaults to Soup_Android_TV_x86_64 / system-images;android-36;android-tv;x86_64
```

A 32-bit `android-tv;x86` AVD is reported as Flutter `unsupported` and has been
observed to hard-close Soup on first Tailscale enable while loading
`libtailscale.so`. With the x86_64 TV image, enabling Tailscale reaches the
authorization QR without a process crash.

Physical Chromecast/ARM devices remain the reference for Tailscale enrollment.
See [emulator discovery notes](android-tv-discovery-2026-09-09.md#emulator-networking-testing-only)
for LAN Jellyfin testing without Tailscale.

The remaining phone/TV runtime checks are consolidated in
[Android acceptance — SOUP-18](android-acceptance.md).
