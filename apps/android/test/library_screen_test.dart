import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/library/library_screen.dart';

void main() {
  final session = JellyfinSession(
    serverUrl: Uri.parse('http://jellyfin/'),
    serverId: 'server',
    userId: 'user',
    userName: 'Alex',
    accessToken: 'secret',
  );

  testWidgets('renders TV library rows and opens a focused item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    JellyfinItem? opened;
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [
          JellyfinItem(id: 'movies', name: 'Movies', type: 'CollectionFolder'),
        ],
        resume: [
          JellyfinItem(
            id: 'resume',
            name: 'Continue Me',
            type: 'Movie',
            playedPercentage: 42,
          ),
        ],
        latest: [JellyfinItem(id: 'latest', name: 'Newest', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
          onOpenItem: (item) => opened = item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Media'), findsOneWidget);
    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('Latest Media'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(opened?.id, 'movies');
  });

  testWidgets('renders an empty state and refreshes', (tester) async {
    final source = FakeLibrarySource(
      const JellyfinHome(libraries: [], resume: [], latest: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your library is empty'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(source.loads, 2);
  });

  testWidgets('renders an actionable error state', (tester) async {
    final source = FakeLibrarySource.error();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your library'), findsOneWidget);
    expect(find.text('Library unavailable for test.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('fits library navigation on a phone', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [],
        resume: [],
        latest: [JellyfinItem(id: 'movie', name: 'Phone Movie', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-home')), findsOneWidget);
    expect(find.text('Phone Movie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeLibrarySource implements JellyfinLibrarySource {
  FakeLibrarySource(this.home) : failure = null;

  FakeLibrarySource.error()
    : home = const JellyfinHome(libraries: [], resume: [], latest: []),
      failure = const JellyfinApiException('Library unavailable for test.');

  final JellyfinHome home;
  final JellyfinApiException? failure;
  int loads = 0;

  @override
  Future<JellyfinHome> getHome(JellyfinSession session) async {
    loads += 1;
    if (failure case final error?) throw error;
    return home;
  }

  @override
  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) async => null;
}
