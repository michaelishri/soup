import 'package:soup_identity/src/models.dart';
import 'package:soup_identity/src/soup_identity_client.dart';
import 'package:soup_identity/src/soup_identity_exception.dart';

/// In-memory client for UI/tests when Soup Identity MS is not running.
///
/// Starts a device-link, stays `pending` for [pollsUntilApproved] polls, then
/// returns tokens. [approve] can complete early (simulates phone Google flow).
class MockSoupIdentityClient implements SoupIdentityClient {
  MockSoupIdentityClient({
    this.pollsUntilApproved = 3,
    this.baseVerificationUri = 'http://localhost:8787/auth/google/start',
    SoupSessionTokens? tokens,
    List<RosterServer>? servers,
  }) : _tokens =
           tokens ??
           const SoupSessionTokens(
             accessToken: 'mock-access',
             refreshToken: 'mock-refresh',
             expiresIn: 900,
             tokenType: 'Bearer',
             googleSub: 'mock-google-sub',
             email: 'dev@example.com',
           ),
       _servers =
           servers ??
           const [
             RosterServer(
               id: 'home-jf',
               name: 'Home',
               audience: 'jellyfin:home-jf',
               magicDns: 'jellyfin.tailnet.ts.net',
             ),
           ];

  final int pollsUntilApproved;
  final String baseVerificationUri;
  SoupSessionTokens _tokens;
  final List<RosterServer> _servers;

  final Map<String, _LinkState> _links = {};
  int _seq = 0;
  bool closed = false;

  void approve(String userCode) {
    for (final link in _links.values) {
      if (link.userCode == userCode) {
        link.approved = true;
        return;
      }
    }
    throw SoupIdentityException('Unknown user code: $userCode');
  }

  @override
  Future<DeviceLinkStart> startDeviceLink() async {
    _ensureOpen();
    _seq++;
    final deviceCode = 'device-$_seq';
    final userCode = 'MOCK-${_seq.toString().padLeft(4, '0')}';
    _links[deviceCode] = _LinkState(userCode: userCode);
    final verification = Uri.parse(
      '$baseVerificationUri?user_code=${Uri.encodeQueryComponent(userCode)}',
    );
    return DeviceLinkStart(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: Uri.parse(baseVerificationUri),
      verificationUriComplete: verification,
      expiresIn: 600,
      interval: 1,
    );
  }

  @override
  Future<DeviceLinkPoll> pollDeviceLink(String deviceCode) async {
    _ensureOpen();
    final link = _links[deviceCode];
    if (link == null) {
      throw const SoupIdentityException(
        'Unknown or consumed device code',
        statusCode: 404,
      );
    }
    if (link.consumed) {
      throw const SoupIdentityException(
        'Unknown or consumed device code',
        statusCode: 404,
      );
    }
    link.polls++;
    if (link.approved || link.polls >= pollsUntilApproved) {
      link.consumed = true;
      return DeviceLinkPoll(status: DeviceLinkStatus.approved, tokens: _tokens);
    }
    return const DeviceLinkPoll(status: DeviceLinkStatus.pending);
  }

  @override
  Future<SoupSessionTokens> refreshSession(String refreshToken) async {
    _ensureOpen();
    if (refreshToken != _tokens.refreshToken &&
        refreshToken != 'mock-refresh') {
      throw const SoupIdentityException(
        'Invalid refresh token',
        statusCode: 401,
      );
    }
    _tokens = SoupSessionTokens(
      accessToken: 'mock-access-${_seq + 1}',
      refreshToken: 'mock-refresh-${_seq + 1}',
      expiresIn: 900,
      tokenType: 'Bearer',
      googleSub: _tokens.googleSub,
      email: _tokens.email,
    );
    return _tokens;
  }

  @override
  Future<ServerRoster> listServers(String accessToken) async {
    _ensureOpen();
    if (accessToken.isEmpty) {
      throw const SoupIdentityException('Unauthorized', statusCode: 401);
    }
    return ServerRoster(servers: List.unmodifiable(_servers));
  }

  @override
  Future<AssertionResponse> mintAssertion({
    required String accessToken,
    required String serverId,
  }) async {
    _ensureOpen();
    if (accessToken.isEmpty) {
      throw const SoupIdentityException('Unauthorized', statusCode: 401);
    }
    RosterServer? server;
    for (final candidate in _servers) {
      if (candidate.id == serverId) {
        server = candidate;
        break;
      }
    }
    if (server == null) {
      throw const SoupIdentityException('Unknown server', statusCode: 404);
    }
    return AssertionResponse(
      assertion: 'mock-assertion-$serverId',
      expiresIn: 180,
      serverId: server.id,
      audience: server.audience,
    );
  }

  @override
  void close() {
    closed = true;
    _links.clear();
  }

  void _ensureOpen() {
    if (closed) {
      throw const SoupIdentityException('Client is closed');
    }
  }
}

class _LinkState {
  _LinkState({required this.userCode});

  final String userCode;
  int polls = 0;
  bool approved = false;
  bool consumed = false;
}
