import 'package:soup_identity/src/models.dart';

/// Wave 0 Soup Identity surface used by the Android auth shell.
abstract interface class SoupIdentityClient {
  Future<DeviceLinkStart> startDeviceLink();

  Future<DeviceLinkPoll> pollDeviceLink(String deviceCode);

  Future<SoupSessionTokens> refreshSession(String refreshToken);

  Future<ServerRoster> listServers(String accessToken);

  /// Mint a short-lived Pattern A assertion JWT for [serverId].
  Future<AssertionResponse> mintAssertion({
    required String accessToken,
    required String serverId,
  });

  void close();
}
