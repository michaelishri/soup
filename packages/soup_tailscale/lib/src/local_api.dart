import 'dart:convert';
import 'dart:io';

class TailscaleBackendStatus {
  const TailscaleBackendStatus({
    required this.backendState,
    this.authorizationUrl,
  });

  factory TailscaleBackendStatus.fromJson(Map<String, Object?> json) {
    final rawUrl = json['AuthURL'];
    final parsedUrl = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    return TailscaleBackendStatus(
      backendState: json['BackendState'] as String? ?? 'NoState',
      authorizationUrl: parsedUrl != null && parsedUrl.scheme == 'https'
          ? parsedUrl
          : null,
    );
  }

  final String backendState;
  final Uri? authorizationUrl;
}

class TailscaleLocalApiException implements Exception {
  const TailscaleLocalApiException(this.operation, this.message);

  final String operation;
  final String message;

  @override
  String toString() => '$operation failed: $message';
}

class TailscaleLocalApiClient {
  TailscaleLocalApiClient({required String address, required this.credential})
    : _baseUri = Uri.parse('http://$address/localapi/v0/');

  final Uri _baseUri;
  final String credential;

  Future<void> startInteractiveLogin() async {
    await _request('POST', 'login-interactive');
  }

  Future<TailscaleBackendStatus> status() async {
    final body = await _request('GET', 'status');
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Tailscale status was not a JSON object.');
    }
    return TailscaleBackendStatus.fromJson(json);
  }

  Future<String> _request(String method, String path) async {
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.openUrl(method, _baseUri.resolve(path));
      request.headers
        ..set(
          HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode(':$credential'))}',
        )
        ..set('Sec-Tailscale', 'localapi');
      request.contentLength = 0;
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TailscaleLocalApiException(
          'LocalAPI $method $path',
          'HTTP ${response.statusCode}${body.isEmpty ? '' : ': $body'}',
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}
