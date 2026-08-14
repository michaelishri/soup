# soup_tailscale

Android Dart FFI adapter for the pinned upstream `tailscale/libtailscale`
source. It owns the embedded node lifecycle and exposes the authenticated
loopback SOCKS5 endpoint used by Soup.

## Native build

Flutter's native-assets build hook invokes Go with the NDK compiler selected by
Flutter, produces `libtailscale.so`, strips it, and bundles it into the APK.
The upstream submodule is pinned by the parent repository.

Android does not permit sandboxed Go code to enumerate interfaces through
netlink. `native/android_interfaces.go` registers the supported Tailscale
interface getter, populated through the app's Java `NetworkInterface` bridge.
It also places native log state inside the app-owned support directory.

This template uses the following structure:

`tailscale_up` runs in a worker isolate. A non-ephemeral node stores state in
the directory provided by the host app. Auth keys are passed directly to the
native call and are not retained by this package.

```sh
flutter analyze
flutter test
```
