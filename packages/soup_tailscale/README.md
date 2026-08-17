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

## Registration lifecycle

The adapter starts a non-ephemeral node with `tailscale_start`, obtains the
authenticated loopback LocalAPI endpoint, and supports two registration paths:

- Interactive registration requests a Tailscale HTTPS authorization URL,
  reports it to the app for QR/browser presentation, and monitors `NeedsLogin`,
  `NeedsMachineAuth`, and `Running` states until the node is usable.
- Auth-key registration passes a trimmed one-time key directly to the native
  node. The package does not retain or persist the key.

Both paths can be cancelled safely and produce the same authenticated SOCKS5
proxy after connection. Persistent node state lives in the host-provided private
directory, allowing `restore()` to reconnect without another registration when
the state remains valid.

```sh
flutter analyze
flutter test
```
