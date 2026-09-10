class DeviceLinkStart {
  const DeviceLinkStart({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceLinkStart.fromJson(Map<String, Object?> json) {
    return DeviceLinkStart(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: Uri.parse(json['verification_uri'] as String),
      verificationUriComplete: Uri.parse(
        json['verification_uri_complete'] as String,
      ),
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
    );
  }

  final String deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final int expiresIn;
  final int interval;

  Map<String, Object?> toJson() => {
    'device_code': deviceCode,
    'user_code': userCode,
    'verification_uri': verificationUri.toString(),
    'verification_uri_complete': verificationUriComplete.toString(),
    'expires_in': expiresIn,
    'interval': interval,
  };
}

enum DeviceLinkStatus { pending, expired, approved }

class DeviceLinkPoll {
  const DeviceLinkPoll({required this.status, this.tokens});

  factory DeviceLinkPoll.fromJson(Map<String, Object?> json) {
    final statusName = json['status'] as String;
    final status = switch (statusName) {
      'pending' => DeviceLinkStatus.pending,
      'expired' => DeviceLinkStatus.expired,
      'approved' => DeviceLinkStatus.approved,
      _ => throw FormatException('Unknown device-link status: $statusName'),
    };
    return DeviceLinkPoll(
      status: status,
      tokens: status == DeviceLinkStatus.approved
          ? SoupSessionTokens.fromJson(json)
          : null,
    );
  }

  final DeviceLinkStatus status;
  final SoupSessionTokens? tokens;
}

class SoupSessionTokens {
  const SoupSessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.email,
  });

  factory SoupSessionTokens.fromJson(Map<String, Object?> json) {
    final email = (json['email'] as String?)?.trim().toLowerCase();
    if (email == null || email.isEmpty || !email.contains('@')) {
      throw const FormatException('Soup session tokens missing email');
    }
    return SoupSessionTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      tokenType: json['token_type'] as String? ?? 'Bearer',
      email: email,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final String email;

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': expiresIn,
    'token_type': tokenType,
    'email': email,
  };
}

/// One-time transport grant returned by roster / claim (Wave 2).
///
/// Material is present only on the first successful claim for that grant.
class TransportGrant {
  const TransportGrant({
    required this.id,
    required this.grantType,
    required this.expiresAt,
    this.claimedAt,
    this.material,
    this.tailscaleKeyId,
    this.capabilities = const {},
  });

  factory TransportGrant.fromJson(Map<String, Object?> json) {
    return TransportGrant(
      id: json['id'] as String,
      grantType: json['grant_type'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      claimedAt: json['claimed_at'] == null
          ? null
          : DateTime.parse(json['claimed_at'] as String),
      material: json['material'] as String?,
      tailscaleKeyId: json['tailscale_key_id'] as String?,
      capabilities: json['capabilities'] is Map
          ? Map<String, Object?>.from(json['capabilities'] as Map)
          : const {},
    );
  }

  static TransportGrant? tryParse(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    return TransportGrant.fromJson(Map<String, Object?>.from(raw));
  }

  final String id;
  final String grantType;
  final DateTime expiresAt;
  final DateTime? claimedAt;
  final String? material;
  final String? tailscaleKeyId;
  final Map<String, Object?> capabilities;

  /// Roster already atomically claimed; app can join with [material].
  bool get isClaimableTailscaleAuthKey {
    final key = material?.trim();
    return grantType == 'tailscale_auth_key' &&
        key != null &&
        key.isNotEmpty;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'grant_type': grantType,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'claimed_at': claimedAt?.toUtc().toIso8601String(),
    'material': material,
    'tailscale_key_id': tailscaleKeyId,
    'capabilities': capabilities,
  };
}

class RosterServer {
  const RosterServer({
    required this.id,
    required this.name,
    required this.audience,
    this.baseUrl,
    this.magicDns,
    this.entitlement = const {},
    this.transportGrant,
  });

  factory RosterServer.fromJson(Map<String, Object?> json) {
    return RosterServer(
      id: json['id'] as String,
      name: json['name'] as String,
      audience: json['audience'] as String,
      baseUrl: json['base_url'] as String?,
      magicDns: json['magic_dns'] as String?,
      entitlement: json['entitlement'] is Map
          ? Map<String, Object?>.from(json['entitlement'] as Map)
          : const {},
      transportGrant: TransportGrant.tryParse(json['transport_grant']),
    );
  }

  final String id;
  final String name;
  final String audience;
  final String? baseUrl;
  final String? magicDns;
  final Map<String, Object?> entitlement;
  final TransportGrant? transportGrant;

  /// Prefer plugin `base_url`, else `http://` MagicDNS on the Tailscale net.
  Uri? get jellyfinServerUrl {
    final raw = baseUrl?.trim();
    if (raw != null && raw.isNotEmpty) {
      final withScheme = raw.contains('://') ? raw : 'http://$raw';
      return Uri.tryParse(withScheme);
    }
    final dns = magicDns?.trim();
    if (dns != null && dns.isNotEmpty) {
      return Uri.tryParse('http://$dns/');
    }
    return null;
  }

  /// First server row with a claimable Tailscale auth-key grant, if any.
  static ({RosterServer server, TransportGrant grant})? firstClaimableAuthKey(
    Iterable<RosterServer> servers,
  ) {
    for (final server in servers) {
      final grant = server.transportGrant;
      if (grant != null && grant.isClaimableTailscaleAuthKey) {
        return (server: server, grant: grant);
      }
    }
    return null;
  }
}

class ServerRoster {
  const ServerRoster({required this.servers});

  factory ServerRoster.fromJson(Map<String, Object?> json) {
    final raw = json['servers'];
    if (raw is! List) {
      throw const FormatException('servers must be a list');
    }
    return ServerRoster(
      servers: [
        for (final item in raw)
          RosterServer.fromJson(Map<String, Object?>.from(item as Map)),
      ],
    );
  }

  final List<RosterServer> servers;

  /// v1 auto-select: sole server, else first. No multi-server picker.
  RosterServer? get autoSelected {
    if (servers.isEmpty) return null;
    return servers.first;
  }
}

/// Short-lived Pattern A JWT from `POST /v1/assertions`.
class AssertionResponse {
  const AssertionResponse({
    required this.assertion,
    required this.expiresIn,
    required this.serverId,
    required this.audience,
  });

  factory AssertionResponse.fromJson(Map<String, Object?> json) {
    return AssertionResponse(
      assertion: json['assertion'] as String,
      expiresIn: json['expires_in'] as int,
      serverId: json['server_id'] as String,
      audience: json['audience'] as String,
    );
  }

  final String assertion;
  final int expiresIn;
  final String serverId;
  final String audience;

  Map<String, Object?> toJson() => {
    'assertion': assertion,
    'expires_in': expiresIn,
    'server_id': serverId,
    'audience': audience,
  };
}
