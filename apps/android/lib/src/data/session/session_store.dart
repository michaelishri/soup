import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

abstract interface class SessionStore {
  Future<String> deviceId();

  Future<JellyfinSession?> read();

  Future<void> write(JellyfinSession session);

  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  ]);

  static const _deviceIdKey = 'jellyfin.device-id';
  static const _sessionKey = 'jellyfin.session';

  final FlutterSecureStorage _storage;

  @override
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final generated = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  @override
  Future<JellyfinSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded);
      if (json is! Map<String, Object?>) throw const FormatException();
      final serverUrl = Uri.tryParse(json['serverUrl'] as String? ?? '');
      final token = json['accessToken'] as String?;
      final serverId = json['serverId'] as String?;
      final userId = json['userId'] as String?;
      if (serverUrl == null ||
          !{'http', 'https'}.contains(serverUrl.scheme) ||
          serverUrl.host.isEmpty ||
          token == null ||
          token.isEmpty ||
          serverId == null ||
          serverId.isEmpty ||
          userId == null ||
          userId.isEmpty) {
        throw const FormatException();
      }
      return JellyfinSession(
        serverUrl: serverUrl,
        serverId: serverId,
        userId: userId,
        userName: json['userName'] as String? ?? '',
        accessToken: token,
      );
    } on Object {
      throw const FormatException('Your saved sign-in could not be read.');
    }
  }

  @override
  Future<void> write(JellyfinSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'serverUrl': session.serverUrl.toString(),
        'serverId': session.serverId,
        'userId': session.userId,
        'userName': session.userName,
        'accessToken': session.accessToken,
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
