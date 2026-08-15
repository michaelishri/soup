import 'dart:convert';
import 'dart:typed_data';

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

class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.collectionType,
    this.overview,
    this.productionYear,
    this.officialRating,
    this.communityRating,
    this.runTimeTicks,
    this.playbackPositionTicks = 0,
    this.playedPercentage,
    this.played = false,
    this.seriesName,
    this.seasonName,
    this.indexNumber,
    this.parentIndexNumber,
    this.primaryImageTag,
    this.backdropImageTag,
  });

  factory JellyfinItem.fromJson(Map<String, Object?> json) {
    final userData = json['UserData'] is Map<String, Object?>
        ? json['UserData']! as Map<String, Object?>
        : const <String, Object?>{};
    final imageTags = json['ImageTags'] is Map<String, Object?>
        ? json['ImageTags']! as Map<String, Object?>
        : const <String, Object?>{};
    final backdropTags = json['BackdropImageTags'];
    return JellyfinItem(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? 'Untitled',
      type: json['Type'] as String? ?? '',
      collectionType: json['CollectionType'] as String?,
      overview: json['Overview'] as String?,
      productionYear: (json['ProductionYear'] as num?)?.toInt(),
      officialRating: json['OfficialRating'] as String?,
      communityRating: (json['CommunityRating'] as num?)?.toDouble(),
      runTimeTicks: (json['RunTimeTicks'] as num?)?.toInt(),
      playbackPositionTicks:
          (userData['PlaybackPositionTicks'] as num?)?.toInt() ?? 0,
      playedPercentage: (userData['PlayedPercentage'] as num?)?.toDouble(),
      played: userData['Played'] as bool? ?? false,
      seriesName: json['SeriesName'] as String?,
      seasonName: json['SeasonName'] as String?,
      indexNumber: (json['IndexNumber'] as num?)?.toInt(),
      parentIndexNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
      primaryImageTag: imageTags['Primary'] as String?,
      backdropImageTag: backdropTags is List && backdropTags.isNotEmpty
          ? backdropTags.first as String?
          : null,
    );
  }

  final String id;
  final String name;
  final String type;
  final String? collectionType;
  final String? overview;
  final int? productionYear;
  final String? officialRating;
  final double? communityRating;
  final int? runTimeTicks;
  final int playbackPositionTicks;
  final double? playedPercentage;
  final bool played;
  final String? seriesName;
  final String? seasonName;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? primaryImageTag;
  final String? backdropImageTag;

  bool get isPlayable =>
      type == 'Movie' || type == 'Episode' || type == 'Video';
}

class JellyfinHome {
  const JellyfinHome({
    required this.libraries,
    required this.resume,
    required this.latest,
  });

  final List<JellyfinItem> libraries;
  final List<JellyfinItem> resume;
  final List<JellyfinItem> latest;
}

abstract interface class JellyfinLibrarySource {
  Future<JellyfinHome> getHome(JellyfinSession session);

  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type,
    int maxWidth,
  });
}

abstract interface class JellyfinDetailsSource {
  Future<JellyfinItem> getItem(JellyfinSession session, String itemId);

  Future<List<JellyfinItem>> getLibraryItems(
    JellyfinSession session,
    String libraryId,
  );

  Future<List<JellyfinItem>> getSeasons(
    JellyfinSession session,
    String seriesId,
  );

  Future<List<JellyfinItem>> getEpisodes(
    JellyfinSession session,
    String seriesId, {
    required String seasonId,
  });
}

class JellyfinApiException implements Exception {
  const JellyfinApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JellyfinApi implements JellyfinLibrarySource, JellyfinDetailsSource {
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

  @override
  Future<JellyfinHome> getHome(JellyfinSession session) async {
    final fields = [
      'Overview',
      'PrimaryImageAspectRatio',
      'ProductionYear',
      'RunTimeTicks',
      'OfficialRating',
      'CommunityRating',
    ].join(',');
    final responses = await Future.wait([
      _getJson(
        session,
        'Users/${session.userId}/Views',
        query: const {'IncludeExternalContent': 'false'},
      ),
      _getJson(
        session,
        'Users/${session.userId}/Items/Resume',
        query: {
          'Limit': '12',
          'MediaTypes': 'Video',
          'Fields': fields,
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
        },
      ),
      _getJson(
        session,
        'Users/${session.userId}/Items/Latest',
        query: {
          'Limit': '18',
          'Fields': fields,
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'ImageTypeLimit': '1',
        },
      ),
    ]);
    return JellyfinHome(
      libraries: _itemsFromResponse(responses[0]),
      resume: _itemsFromResponse(responses[1]),
      latest: _itemsFromResponse(responses[2]),
    );
  }

  @override
  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) async {
    final tag = type == 'Backdrop'
        ? item.backdropImageTag
        : item.primaryImageTag;
    if (tag == null || tag.isEmpty || item.id.isEmpty) return null;
    final response = await _client
        .get(
          _sessionUri(
            session,
            'Items/${item.id}/Images/$type',
            query: {'tag': tag, 'maxWidth': '$maxWidth', 'quality': '85'},
          ),
          headers: _sessionHeaders(session),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JellyfinApiException(
        'Could not load artwork. Jellyfin returned HTTP ${response.statusCode}.',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<JellyfinItem> getItem(JellyfinSession session, String itemId) async {
    final value = await _getJson(
      session,
      'Users/${session.userId}/Items/$itemId',
      query: {'Fields': _detailFields},
    );
    if (value is! Map<String, Object?>) {
      throw const JellyfinApiException(
        'Jellyfin returned an unreadable item response.',
      );
    }
    return JellyfinItem.fromJson(value);
  }

  @override
  Future<List<JellyfinItem>> getLibraryItems(
    JellyfinSession session,
    String libraryId,
  ) async {
    final value = await _getJson(
      session,
      'Users/${session.userId}/Items',
      query: {
        'ParentId': libraryId,
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Series',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': _detailFields,
        'EnableImages': 'true',
        'EnableImageTypes': 'Primary,Backdrop,Thumb',
        'ImageTypeLimit': '1',
      },
    );
    return _itemsFromResponse(value);
  }

  @override
  Future<List<JellyfinItem>> getSeasons(
    JellyfinSession session,
    String seriesId,
  ) async {
    final value = await _getJson(
      session,
      'Shows/$seriesId/Seasons',
      query: {
        'UserId': session.userId,
        'Fields': _detailFields,
        'EnableImages': 'true',
      },
    );
    return _itemsFromResponse(value);
  }

  @override
  Future<List<JellyfinItem>> getEpisodes(
    JellyfinSession session,
    String seriesId, {
    required String seasonId,
  }) async {
    final value = await _getJson(
      session,
      'Shows/$seriesId/Episodes',
      query: {
        'UserId': session.userId,
        'SeasonId': seasonId,
        'Fields': _detailFields,
        'EnableImages': 'true',
      },
    );
    return _itemsFromResponse(value);
  }

  Future<Object?> _getJson(
    JellyfinSession session,
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client
        .get(
          _sessionUri(session, path, query: query),
          headers: _sessionHeaders(session),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const JellyfinApiException(
        'Your Jellyfin session has expired. Sign in again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JellyfinApiException(
        'Could not load your library. Jellyfin returned HTTP ${response.statusCode}.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const JellyfinApiException(
        'Jellyfin returned an unreadable library response.',
      );
    }
  }

  Uri _sessionUri(
    JellyfinSession session,
    String path, {
    Map<String, String>? query,
  }) {
    return session.serverUrl.resolve(path).replace(queryParameters: query);
  }

  Map<String, String> _sessionHeaders(JellyfinSession session) => {
    'Accept': 'application/json',
    'X-Emby-Token': session.accessToken,
    'Authorization':
        'MediaBrowser Client="$clientName", Device="Soup Android", DeviceId="$deviceId", Version="$clientVersion", Token="${session.accessToken}"',
  };

  static List<JellyfinItem> _itemsFromResponse(Object? value) {
    final rawItems = value is Map<String, Object?> ? value['Items'] : value;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map<String, Object?>>()
        .map(JellyfinItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static const _detailFields =
      'Overview,PrimaryImageAspectRatio,ProductionYear,RunTimeTicks,'
      'OfficialRating,CommunityRating,MediaSources,MediaStreams';

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
