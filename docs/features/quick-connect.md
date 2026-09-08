# Quick Connect sign-in

SOUP-91 adds Jellyfin Quick Connect to the existing third setup step. After a server is verified, Soup generates a code automatically alongside username and password. Wide layouts use equal columns; small windows and enlarged text stack the panels. Approval goes straight through the same saved-session and appearance/library flow as password authentication.

On another client already signed into the same Jellyfin server, open **Settings → Quick Connect** and enter the displayed code. Soup initiates sign-in requests; it does not authorize other devices.

## Interaction rules

- TV focus starts on Username without opening the keyboard. Moving between fields leaves polling active. Selecting a credential field pauses Quick Connect before opening the native editor.
- Phone keyboards stay closed on arrival. Entering a credential field pauses Quick Connect. Approval cannot interrupt a draft or close its native editor.
- Back from the native editor retains its draft and leaves Quick Connect paused. Resume checks the existing code immediately, replacing it if Jellyfin reports it expired. Get a new code explicitly replaces a waiting request.
- Code refresh keeps its remote action focused while showing progress; repeated presses during that request are ignored.
- Back from sign-in cancels the current attempt, including token exchange or a pending session save, and returns to the server step.
- Disabled Quick Connect remains visible with an explanation and Check again. Network errors stop polling and offer Retry. Password sign-in stays available.
- Backgrounding suspends an active request. Returning resumes that request, but never resumes one paused for credential editing. A server or Tailscale proxy change invalidates the old request.

## Protocol and persistence

The pinned Jellyfin 10.11.1 OpenAPI subset defines four operations: `GET /QuickConnect/Enabled`, `POST /QuickConnect/Initiate`, `GET /QuickConnect/Connect?secret=…`, and `POST /Users/AuthenticateWithQuickConnect` with a `Secret` body. Run `task api:generate` to regenerate the Dart package. Generator metadata and documentation normalization are in the generation script/configuration.

Soup uses its existing HTTP client, server base path, device identity and MediaBrowser headers for both direct and embedded Tailscale connections. Polls are serialized, five seconds after the preceding response, with a 15-second timeout per operation. HTTP 401 identifies disabled Quick Connect and 404 identifies an expired request. Raw server/transport errors never appear in the Quick Connect UI because they can contain a polling secret or token. Availability validates the boolean response rather than accepting the generator's permissive coercion.

Codes and secrets live only in the view model. Every async result is checked against the active generation and server. Password and Quick Connect share serialized session writes; invalidation during a save clears that stale save before a newer session can commit. No session schema or storage migration is required. Jellyfin has no request-cancellation endpoint: canceled requests are ignored locally and expire on the server.

## Verification

- `quick_connect_api_test.dart`: endpoint methods, request bodies, base paths, headers, malformed responses, HTTP status preservation, timeouts and secret-safe errors.
- `quick_connect_view_model_test.dart`: approval on either transport, serial polling, editing/background/Back/transport/disposal cancellation, expiry/resume, late responses, partial and interrupted storage writes.
- `quick_connect_screen_test.dart`: responsive panels, enlarged text, initial keyboard/focus behavior, native draft retention, late approval while editing and disabled-server recovery.
- `widget_test.dart`: both authentication methods reach appearance and then the library on either transport.
- `socks_jellyfin_client_test.dart`: generated Quick Connect availability through a real authenticated SOCKS5 proxy.

Native acceptance is recorded separately under `docs/development/`.

Protocol references: [Jellyfin Quick Connect guide](https://jellyfin.org/docs/general/server/quick-connect/), [10.11.1 Quick Connect controller](https://github.com/jellyfin/jellyfin/blob/v10.11.1/Jellyfin.Api/Controllers/QuickConnectController.cs), [10.11.1 request manager](https://github.com/jellyfin/jellyfin/blob/v10.11.1/Emby.Server.Implementations/QuickConnect/QuickConnectManager.cs).
