import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';
import 'package:soup/src/features/details/details_view_model.dart';
import 'package:soup/src/features/library/library_view_model.dart';

import 'jellyfin_metadata_repository_test.dart' show FakeMetadataSource;
import 'support/connectivity_fakes.dart' show testSession;

const _item = JellyfinItem(id: 'movie', name: 'Movie', type: 'Movie');
const _home = JellyfinHome(libraries: [], resume: [], latest: [_item]);

void main() {
  for (final fail in [false, true]) {
    test(
      'leaving library before refresh completes (failure=$fail) is safe',
      () async {
        final source = _PendingSource();
        final repository = TransientJellyfinMetadataRepository(
          session: testSession,
          librarySource: source,
        );
        final model = LibraryViewModel(
          repository: repository,
          session: testSession,
        );
        final pending = model.load();
        model.dispose();
        await repository.close();
        if (fail) {
          source.homeResult.completeError(StateError('disconnected'));
        } else {
          source.homeResult.complete(_home);
        }
        await expectLater(pending, completes);
      },
    );

    test(
      'leaving details before refresh completes (failure=$fail) is safe',
      () async {
        final source = _PendingSource();
        final repository = TransientJellyfinMetadataRepository(
          session: testSession,
          detailsSource: source,
        );
        final model = DetailsViewModel(
          repository: repository,
          initialItem: _item,
        );
        final pending = model.load();
        model.dispose();
        await repository.close();
        if (fail) {
          source.itemResult.completeError(StateError('disconnected'));
        } else {
          source.itemResult.complete(_item);
        }
        await expectLater(pending, completes);
      },
    );

    test(
      'leaving a season before episodes complete (failure=$fail) is safe',
      () async {
        final source = _PendingSource();
        final repository = TransientJellyfinMetadataRepository(
          session: testSession,
          detailsSource: source,
        );
        final model = DetailsViewModel(
          repository: repository,
          initialItem: _item,
        );
        final pending = model.selectSeason(
          const JellyfinItem(id: 'season', name: 'Season 1', type: 'Season'),
        );
        model.dispose();
        await repository.close();
        if (fail) {
          source.episodesResult.completeError(StateError('disconnected'));
        } else {
          source.episodesResult.complete([]);
        }
        await expectLater(pending, completes);
      },
    );
  }
}

class _PendingSource extends FakeMetadataSource {
  _PendingSource() : super(home: _home);
  final homeResult = Completer<JellyfinHome>();
  final itemResult = Completer<JellyfinItem>();
  final episodesResult = Completer<List<JellyfinItem>>();
  @override
  Future<JellyfinHome> getHome(JellyfinSession session) => homeResult.future;
  @override
  Future<JellyfinItem> getItem(JellyfinSession session, String itemId) =>
      itemResult.future;
  @override
  Future<List<JellyfinItem>> getEpisodes(
    JellyfinSession session,
    String seriesId, {
    required String seasonId,
  }) => episodesResult.future;
}
