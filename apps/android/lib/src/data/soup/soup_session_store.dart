import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:soup_identity/soup_identity.dart';

/// Persisted Soup Identity session (separate from Jellyfin [SecureSessionStore]).
class SoupSession {
  const SoupSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.email,
    this.lastServerId,
    this.accessExpiresAt,
  });

  factory SoupSession.fromTokens(
    SoupSessionTokens tokens, {
    String? lastServerId,
    DateTime? issuedAt,
  }) {
    final now = issuedAt ?? DateTime.now().toUtc();
    return SoupSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      tokenType: tokens.tokenType,
      email: tokens.email,
      lastServerId: lastServerId,
      accessExpiresAt: now.add(Duration(seconds: tokens.expiresIn)),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final String email;
  final String? lastServerId;
  final DateTime? accessExpiresAt;

  SoupSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
    String? tokenType,
    String? email,
    String? lastServerId,
    DateTime? accessExpiresAt,
    bool clearLastServerId = false,
  }) {
    return SoupSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
      tokenType: tokenType ?? this.tokenType,
      email: email ?? this.email,
      lastServerId: clearLastServerId
          ? null
          : (lastServerId ?? this.lastServerId),
      accessExpiresAt: accessExpiresAt ?? this.accessExpiresAt,
    );
  }

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'tokenType': tokenType,
    'email': email,
    'lastServerId': lastServerId,
    'accessExpiresAt': accessExpiresAt?.toIso8601String(),
  };

  static SoupSession fromJson(Map<String, Object?> json) {
    final accessToken = json['accessToken'] as String?;
    final refreshToken = json['refreshToken'] as String?;
    final email = (json['email'] as String?)?.trim().toLowerCase();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        email == null ||
        email.isEmpty ||
        !email.contains('@')) {
      throw const FormatException();
    }
    return SoupSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: json['expiresIn'] as int? ?? 0,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      email: email,
      lastServerId: json['lastServerId'] as String?,
      accessExpiresAt: DateTime.tryParse(
        json['accessExpiresAt'] as String? ?? '',
      )?.toUtc(),
    );
  }
}

abstract interface class SoupSessionStore {
  Future<SoupSession?> read();

  Future<void> write(SoupSession session);

  Future<void> clear();
}

class SecureSoupSessionStore implements SoupSessionStore {
  const SecureSoupSessionStore([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  ]);

  static const _sessionKey = 'soup.session';

  final FlutterSecureStorage _storage;

  @override
  Future<SoupSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded);
      if (json is! Map) throw const FormatException();
      return SoupSession.fromJson(Map<String, Object?>.from(json));
    } on Object {
      throw const FormatException('Your Soup sign-in could not be read.');
    }
  }

  @override
  Future<void> write(SoupSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
