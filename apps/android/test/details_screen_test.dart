import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/details/details_screen.dart';

void main() {
  final session = JellyfinSession(
    serverUrl: Uri.parse('http://jellyfin/'),
    serverId: 'server',
    userId: 'user',
    userName: 'Alex',
    accessToken: 'token',
  );

  testWidgets('shows movie metadata and resolves its resume position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const movie = JellyfinItem(
      id: 'movie',
      name: 'Example Movie',
      type: 'Movie',
      overview: 'A useful movie overview.',
      productionYear: 2025,
      officialRating: '12',
      communityRating: 8.25,
      runTimeTicks: 54000000000,
      playbackPositionTicks: 900000000,
    );
    final source = FakeDetailsSource(items: const {'movie': movie});
    JellyfinItem? played;
    Duration? startAt;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: DetailsScreen(
          source: source,
          artworkSource: source,
          session: session,
          item: movie,
          onPlay: (item, position) {
            played = item;
            startAt = position;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Example Movie'), findsOneWidget);
    expect(find.text('2025  •  12  •  1h 30m  •  ★ 8.3'), findsOneWidget);
    expect(find.text('A useful movie overview.'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-item-button')));
    expect(played?.id, 'movie');
    expect(startAt, const Duration(seconds: 90));
  });

  testWidgets('loads seasons and resolves an episode for playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const series = JellyfinItem(
      id: 'series',
      name: 'Example Show',
      type: 'Series',
    );
    const season1 = JellyfinItem(id: 's1', name: 'Season 1', type: 'Season');
    const season2 = JellyfinItem(id: 's2', name: 'Season 2', type: 'Season');
    const episode1 = JellyfinItem(
      id: 'e1',
      name: 'Pilot',
      type: 'Episode',
      indexNumber: 1,
    );
    const episode2 = JellyfinItem(
      id: 'e2',
      name: 'Return',
      type: 'Episode',
      indexNumber: 1,
      playbackPositionTicks: 300000000,
    );
    final source = FakeDetailsSource(
      items: const {'series': series},
      seasons: const [season1, season2],
      episodes: const {
        's1': [episode1],
        's2': [episode2],
      },
    );
    JellyfinItem? played;
    Duration? startAt;

    await tester.pumpWidget(
      MaterialApp(
        home: DetailsScreen(
          source: source,
          artworkSource: source,
          session: session,
          item: series,
          onPlay: (item, position) {
            played = item;
            startAt = position;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seasons'), findsOneWidget);
    expect(find.text('1. Pilot'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('season-s2')));
    await tester.pumpAndSettle();
    expect(find.text('1. Return'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('episode-e2')));
    expect(played?.id, 'e2');
    expect(startAt, const Duration(seconds: 30));
  });

  testWidgets('browses a library folder into item details', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const library = JellyfinItem(
      id: 'library',
      name: 'Movies',
      type: 'CollectionFolder',
    );
    const movie = JellyfinItem(
      id: 'movie',
      name: 'Nested Movie',
      type: 'Movie',
    );
    final source = FakeDetailsSource(
      items: const {'movie': movie},
      libraryItems: const [movie],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailsScreen(
          source: source,
          artworkSource: source,
          session: session,
          item: library,
          onPlay: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-contents')), findsOneWidget);
    expect(find.text('Nested Movie'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail-card-movie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-details')), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('shows a retry action when details fail', (tester) async {
    final source = FakeDetailsSource(
      items: const {},
      error: const JellyfinApiException('Details unavailable for test.'),
    );
    const movie = JellyfinItem(id: 'movie', name: 'Movie', type: 'Movie');

    await tester.pumpWidget(
      MaterialApp(
        home: DetailsScreen(
          source: source,
          artworkSource: source,
          session: session,
          item: movie,
          onPlay: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Details unavailable for test.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class FakeDetailsSource
    implements JellyfinDetailsSource, JellyfinLibrarySource {
  FakeDetailsSource({
    required this.items,
    this.libraryItems = const [],
    this.seasons = const [],
    this.episodes = const {},
    this.error,
  });

  final Map<String, JellyfinItem> items;
  final List<JellyfinItem> libraryItems;
  final List<JellyfinItem> seasons;
  final Map<String, List<JellyfinItem>> episodes;
  final JellyfinApiException? error;

  @override
  Future<JellyfinItem> getItem(JellyfinSession session, String itemId) async {
    if (error case final failure?) throw failure;
    return items[itemId]!;
  }

  @override
  Future<List<JellyfinItem>> getLibraryItems(
    JellyfinSession session,
    String libraryId,
  ) async => libraryItems;

  @override
  Future<List<JellyfinItem>> getSeasons(
    JellyfinSession session,
    String seriesId,
  ) async => seasons;

  @override
  Future<List<JellyfinItem>> getEpisodes(
    JellyfinSession session,
    String seriesId, {
    required String seasonId,
  }) async => episodes[seasonId] ?? const [];

  @override
  Future<JellyfinHome> getHome(JellyfinSession session) async =>
      const JellyfinHome(libraries: [], resume: [], latest: []);

  @override
  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) async => null;
}
