/// Compile-time flags for the Soup Identity auth shell.
///
/// Enable with:
/// `--dart-define=SOUP_IDENTITY_AUTH=true`
/// Optional mock when MS is down:
/// `--dart-define=SOUP_IDENTITY_MOCK=true`
/// Optional base URL (emulator default uses 10.0.2.2):
/// `--dart-define=SOUP_IDENTITY_BASE_URL=http://10.0.2.2:8787`
/// Opt out of roster auth-key Tailscale join (Wave 2C):
/// `--dart-define=SOUP_TRANSPORT_AUTH_KEY=false`
class SoupIdentityFlags {
  const SoupIdentityFlags({
    this.enabled = false,
    this.useMock = false,
    this.connectTransportGrants = true,
    this.baseUrl = 'http://10.0.2.2:8787',
  });

  static const fromEnvironment = SoupIdentityFlags(
    enabled: bool.fromEnvironment('SOUP_IDENTITY_AUTH'),
    useMock: bool.fromEnvironment('SOUP_IDENTITY_MOCK'),
    connectTransportGrants: bool.fromEnvironment(
      'SOUP_TRANSPORT_AUTH_KEY',
      defaultValue: true,
    ),
    baseUrl: String.fromEnvironment(
      'SOUP_IDENTITY_BASE_URL',
      defaultValue: 'http://10.0.2.2:8787',
    ),
  );

  final bool enabled;
  final bool useMock;

  /// When true (default), claimable roster grants call [connectWithAuthKey].
  final bool connectTransportGrants;
  final String baseUrl;

  Uri get baseUri => Uri.parse(baseUrl);
}
