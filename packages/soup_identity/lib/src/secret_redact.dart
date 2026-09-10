/// Redacts auth keys, bearer tokens, and JWT-shaped strings from operator-facing text.
String redactSecrets(String input) {
  var out = input;
  out = out.replaceAllMapped(
    RegExp(r'tskey-(?:auth|api|client)-[A-Za-z0-9_-]+', caseSensitive: false),
    (_) => '[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    (_) => '[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    (_) => '[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'"(?:access_token|refresh_token|material|client_secret|plugin_secret)"\s*:\s*"[^"]*"',
      caseSensitive: false,
    ),
    (_) => '"[redacted]":"[redacted]"',
  );
  return out;
}
