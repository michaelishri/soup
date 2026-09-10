import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:soup_identity/src/models.dart';
import 'package:soup_identity/src/soup_identity_client.dart';
import 'package:soup_identity/src/soup_identity_exception.dart';

class HttpSoupIdentityClient implements SoupIdentityClient {
  HttpSoupIdentityClient({required Uri baseUrl, http.Client? httpClient})
    : _base = _normalizeBase(baseUrl),
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final String _base;
  final http.Client _client;
  final bool _ownsClient;

  static String _normalizeBase(Uri baseUrl) {
    if (!{'http', 'https'}.contains(baseUrl.scheme) || baseUrl.host.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'must be an absolute URL');
    }
    return baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
  }

  Uri _uri(String path) => Uri.parse('$_base$path');

  Map<String, Object?> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SoupIdentityException(
        'Soup Identity request failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SoupIdentityException('Expected a JSON object response');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SoupIdentityException {
      rethrow;
    } on Object catch (error) {
      throw SoupIdentityException(error.toString());
    }
  }

  @override
  Future<DeviceLinkStart> startDeviceLink() => _guard(() async {
    final response = await _client.post(
      _uri('/auth/device/link'),
      headers: const {'accept': 'application/json'},
    );
    return DeviceLinkStart.fromJson(_decodeObject(response));
  });

  @override
  Future<DeviceLinkPoll> pollDeviceLink(String deviceCode) => _guard(() async {
    final response = await _client.get(
      _uri('/auth/device/link/${Uri.encodeComponent(deviceCode)}'),
      headers: const {'accept': 'application/json'},
    );
    if (response.statusCode == 404) {
      throw const SoupIdentityException(
        'Unknown or consumed device code',
        statusCode: 404,
      );
    }
    return DeviceLinkPoll.fromJson(_decodeObject(response));
  });

  @override
  Future<SoupSessionTokens> refreshSession(String refreshToken) =>
      _guard(() async {
    final response = await _client.post(
      _uri('/v1/sessions/refresh'),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return SoupSessionTokens.fromJson(_decodeObject(response));
  });

  @override
  Future<ServerRoster> listServers(String accessToken) => _guard(() async {
    final response = await _client.get(
      _uri('/v1/me/servers'),
      headers: {
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    return ServerRoster.fromJson(_decodeObject(response));
  });

  @override
  Future<AssertionResponse> mintAssertion({
    required String accessToken,
    required String serverId,
  }) => _guard(() async {
    final response = await _client.post(
      _uri('/v1/assertions'),
      headers: {
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({'server_id': serverId}),
    );
    return AssertionResponse.fromJson(_decodeObject(response));
  });

  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}
