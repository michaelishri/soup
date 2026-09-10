# Wave 2C — Android connectWithAuthKey from roster transport grant

Date: 2026-09-10  
Scope: `apps/android` + `packages/soup_tailscale` (+ typed grant in `packages/soup_identity`)  
Task: `task_e6c4f6f88b73`

## Done

When Soup Identity auth is enabled and `GET /v1/me/servers` returns a claimable
`tailscale_auth_key` grant (material present after MS single-claim), the Android
shell calls `TailscaleClient.connectWithAuthKey`, then `waitUntilConnected`
before marking Soup auth ready (hook for Wave 3 assertion exchange).

Legacy interactive Tailscale QR onboarding is unchanged when Soup auth is off
or no grant is present. `ConnectivityViewModel.adoptSoupAuthKeyTransport()`
adopts the already-connected node without calling `connectInteractively`.

## Feature flags

```sh
flutter run --dart-define=SOUP_IDENTITY_AUTH=true \
  --dart-define=SOUP_IDENTITY_MOCK=true
# Opt out of auth-key join while keeping device-link:
# --dart-define=SOUP_TRANSPORT_AUTH_KEY=false
```

| Define | Effect |
| --- | --- |
| `SOUP_IDENTITY_AUTH` | Soup device-link gate |
| `SOUP_TRANSPORT_AUTH_KEY` | Default `true`; when false, roster grants are ignored for Tailscale join |

## Key surfaces

- `packages/soup_identity`: typed `TransportGrant`, `RosterServer.firstClaimableAuthKey`
- `packages/soup_tailscale`: `TailscaleClientWait.waitUntilConnected`
- `SoupDeviceLinkViewModel`: phase `connectingTransport`, `transportConnected`
- `ConnectivityViewModel.adoptSoupAuthKeyTransport`

## Explicitly not done (Wave 3+)

- Jellyfin `/SoupAuth/Exchange` / assertion mint
- Replacing legacy Jellyfin onboarding UI entirely
- Live Tailscale mint (plugin Wave)

## Tests

- `packages/soup_identity/test/soup_identity_client_test.dart` (grant parse)
- `packages/soup_tailscale/test/soup_tailscale_test.dart` (`waitUntilConnected`)
- `apps/android/test/soup_device_link_view_model_test.dart` (auth-key join + flag off)
- `apps/android/test/connectivity_view_model_test.dart` (adopt skips interactive)
