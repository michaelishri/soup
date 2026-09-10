import 'package:soup_identity/src/secret_redact.dart';

class SoupIdentityException implements Exception {
  const SoupIdentityException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;

  /// Raw response body for diagnostics; never include in UI or logs without [redactSecrets].
  final String? body;

  @override
  String toString() =>
      'SoupIdentityException(${redactSecrets(message)}'
      '${statusCode == null ? '' : ', status=$statusCode'})';
}
