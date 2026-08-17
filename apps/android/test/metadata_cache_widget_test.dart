import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';
import 'package:soup/src/features/library/library_screen.dart';

void main() {
  const cachedItem = JellyfinItem(
    id: 'cached',
    name: 'Cached Movie',
    type: 'Movie',
  );
  const home = JellyfinHome(
    libraries: [],
    resume: [],
    latest: [cachedItem],
    recentlyAddedMovies: [cachedItem],
    recentlyAddedTv: [],
  );

  testWidgets('renders a cached home while revalidation is still running', (
    tester,
  ) async {
    final refresh = Completer<void>();
    final repository = FakeWidgetMetadataRepository(
      const MetadataSnapshot(data: home, hasSnapshot: true, stale: false),
      onRefresh: () => refresh.future,
    );

    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('Cached Movie'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    refresh.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('keeps stale content visible and clears banner after retry', (
    tester,
  ) async {
    late FakeWidgetMetadataRepository repository;
    repository = FakeWidgetMetadataRepository(
      const MetadataSnapshot(
        data: home,
        hasSnapshot: true,
        stale: true,
        errorMessage: 'Refresh failed.',
      ),
      onRefresh: () async {
        if (repository.refreshCount > 1) {
          repository.emit(
            const MetadataSnapshot(data: home, hasSnapshot: true, stale: false),
          );
        }
      },
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Cached Movie'), findsWidgets);
    expect(find.byKey(const ValueKey('stale-data-banner')), findsOneWidget);
    expect(find.text('Refresh failed.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stale-data-retry')));
    await tester.pumpAndSettle();

    expect(repository.refreshCount, 2);
    expect(find.byKey(const ValueKey('stale-data-banner')), findsNothing);
    expect(find.text('Cached Movie'), findsWidgets);
  });
}

Widget _app(JellyfinMetadataRepository repository) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: LibraryScreen(
      source: const FakeArtworkSource(),
      metadataRepository: repository,
      session: JellyfinSession(
        serverUrl: Uri.parse('http://jellyfin/'),
        serverId: 'server',
        userId: 'user',
        userName: 'Alex',
        accessToken: 'token',
      ),
      onSignOut: () async {},
    ),
  );
}

class FakeWidgetMetadataRepository implements JellyfinMetadataRepository {
  FakeWidgetMetadataRepository(this._snapshot, {required this.onRefresh});

  MetadataSnapshot<JellyfinHome> _snapshot;
  final Future<void> Function() onRefresh;
  final StreamController<MetadataSnapshot<JellyfinHome>> _controller =
      StreamController.broadcast();
  int refreshCount = 0;

  void emit(MetadataSnapshot<JellyfinHome> snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  @override
  Stream<MetadataSnapshot<JellyfinHome>> watchHome() {
    return Stream.multi((listener) {
      listener.add(_snapshot);
      final subscription = _controller.stream.listen(listener.add);
      listener.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> refreshHome() {
    refreshCount++;
    return onRefresh();
  }

  @override
  Stream<MetadataSnapshot<JellyfinItem>> watchItem(String itemId) =>
      const Stream.empty();

  @override
  Future<void> refreshItem(String itemId) async {}

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchLibraryItems(
    String libraryId,
  ) => const Stream.empty();

  @override
  Future<void> refreshLibraryItems(String libraryId) async {}

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchSeasons(String seriesId) =>
      const Stream.empty();

  @override
  Future<void> refreshSeasons(String seriesId) async {}

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchEpisodes(
    String seriesId, {
    required String seasonId,
  }) => const Stream.empty();

  @override
  Future<void> refreshEpisodes(
    String seriesId, {
    required String seasonId,
  }) async {}

  @override
  Future<void> close() => _controller.close();
}

class FakeArtworkSource implements JellyfinLibrarySource {
  const FakeArtworkSource();

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
