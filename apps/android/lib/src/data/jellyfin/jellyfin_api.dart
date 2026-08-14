import 'package:http/http.dart' as http;
import 'package:jellyfin_api/api.dart' as generated;

class JellyfinServerInfo {
  const JellyfinServerInfo({
    required this.name,
    required this.version,
    required this.id,
  });

  factory JellyfinServerInfo.fromJson(Map<String, Object?> json) {
    return JellyfinServerInfo(
      name: json['ServerName'] as String? ?? 'Jellyfin',
      version: json['Version'] as String? ?? '',
      id: json['Id'] as String? ?? '',
    );
  }

  final String name;
  final String version;
  final String id;

  bool get supportsSoup {
    final parts = version.split('.');
    if (parts.length < 2) return false;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    return major != null &&
        minor != null &&
        (major > 10 || major == 10 && minor >= 11);
  }
}

class JellyfinSession {
  const JellyfinSession({
    required this.serverUrl,
    required this.serverId,
    required this.userId,
    required this.userName,
    required this.accessToken,
  });

  final Uri serverUrl;
  final String serverId;
  final String userId;
  final String userName;
  final String accessToken;
}

class JellyfinApiException implements Exception {
  const JellyfinApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JellyfinApi {
  JellyfinApi(
    this._client, {
    required this.deviceId,
    this.clientName = 'Soup',
    this.clientVersion = '0.1.0',
  });

  final http.Client _client;
  final String deviceId;
  final String clientName;
  final String clientVersion;

  static Uri parseServerUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const JellyfinApiException('Enter your Jellyfin server address.');
    }
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const JellyfinApiException(
        'Use an HTTP or HTTPS Jellyfin server address.',
      );
    }
    return uri.replace(
      path: _normaliseBasePath(uri.path),
      query: null,
      fragment: null,
    );
  }

  Future<JellyfinServerInfo> getPublicSystemInfo(Uri serverUrl) async {
    try {
      final result = await generated.SystemApi(
        _generatedClient(serverUrl),
      ).getPublicSystemInfo().timeout(const Duration(seconds: 15));
      if (result == null) {
        throw const JellyfinApiException(
          'Could not reach Jellyfin. The server returned no information.',
        );
      }
      final info = JellyfinServerInfo(
        name: result.serverName ?? 'Jellyfin',
        version: result.version ?? '',
        id: result.id ?? '',
      );
      if (!info.supportsSoup) {
        throw JellyfinApiException(
          'Soup requires Jellyfin 10.11 or newer; this server reports ${info.version.isEmpty ? 'an unknown version' : info.version}.',
        );
      }
      return info;
    } on generated.ApiException catch (error) {
      throw _mapGeneratedError(error, operation: 'reach Jellyfin');
    }
  }

  Future<JellyfinSession> authenticate({
    required Uri serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      final result =
          await generated.AuthenticationApi(_generatedClient(serverUrl))
              .authenticateUserByName(
                generated.AuthenticateUserByName(
                  username: username,
                  pw: password,
                ),
              )
              .timeout(const Duration(seconds: 15));
      final token = result?.accessToken;
      final user = result?.user;
      if (result == null || token == null || token.isEmpty || user == null) {
        throw const JellyfinApiException(
          'Jellyfin returned an incomplete sign-in response.',
        );
      }
      return JellyfinSession(
        serverUrl: serverUrl,
        serverId: result.serverId ?? '',
        userId: user.id ?? '',
        userName: user.name ?? username,
        accessToken: token,
      );
    } on generated.ApiException catch (error) {
      throw _mapGeneratedError(error, operation: 'sign in');
    }
  }

  generated.ApiClient _generatedClient(Uri serverUrl) {
    final basePath = serverUrl.toString().replaceFirst(RegExp(r'/$'), '');
    final client = generated.ApiClient(basePath: basePath)
      ..client = _client
      ..addDefaultHeader(
        'Authorization',
        'MediaBrowser Client="$clientName", Device="Soup Android", DeviceId="$deviceId", Version="$clientVersion"',
      )
      ..addDefaultHeader('Accept', 'application/json');
    return client;
  }

  static String _normaliseBasePath(String path) {
    final withoutTrailing = path.replaceFirst(RegExp(r'/+$'), '');
    return withoutTrailing.isEmpty ? '/' : '$withoutTrailing/';
  }

  static JellyfinApiException _mapGeneratedError(
    generated.ApiException error, {
    required String operation,
  }) {
    final reason = error.code == 401
        ? 'Check your username and password.'
        : 'Jellyfin returned HTTP ${error.code}.';
    return JellyfinApiException('Could not $operation. $reason');
  }
}
