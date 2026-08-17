import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/cache/soup_database.dart';

void main() {
  late SoupDatabase database;

  setUp(() {
    database = SoupDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => database.close());

  test('shares media rows while isolating user state and visibility', () async {
    final now = DateTime.utc(2026, 8, 17);
    final shared = _item('server', 'shared', 'Shared title', now);
    final privateItem = _item('server', 'private', 'Private title', now);

    await database.replaceScopes(
      items: [shared],
      userStates: [_state('server', 'alice', 'shared', now, position: 10)],
      scopes: [
        _scope('server', 'alice', ['shared']),
      ],
      refreshedAt: now,
    );
    await database.replaceScopes(
      items: [shared, privateItem],
      userStates: [_state('server', 'bob', 'shared', now, played: true)],
      scopes: [
        _scope('server', 'bob', ['private', 'shared']),
      ],
      refreshedAt: now,
    );

    expect(await database.select(database.mediaItems).get(), hasLength(2));
    final alice = await database.watchScope(_scopeKey('server', 'alice')).first;
    final bob = await database.watchScope(_scopeKey('server', 'bob')).first;
    expect(alice.map((entry) => entry.item.itemId), ['shared']);
    expect(alice.single.userState?.playbackPositionTicks, 10);
    expect(bob.map((entry) => entry.item.itemId), ['private', 'shared']);
    expect(bob.last.userState?.played, isTrue);
  });

  test(
    'atomically replaces scope order and removes revoked membership',
    () async {
      final now = DateTime.utc(2026, 8, 17);
      final key = _scopeKey('server', 'alice');
      await database.replaceScopes(
        items: [
          _item('server', 'one', 'One', now),
          _item('server', 'two', 'Two', now),
        ],
        userStates: const [],
        scopes: [
          _scope('server', 'alice', ['one', 'two']),
        ],
        refreshedAt: now,
      );

      final updates = database.watchScope(key);
      expect((await updates.first).map((entry) => entry.item.itemId), [
        'one',
        'two',
      ]);

      await database.replaceScopes(
        items: [_item('server', 'two', 'Two updated', now)],
        userStates: const [],
        scopes: [
          _scope('server', 'alice', ['two']),
        ],
        refreshedAt: now.add(const Duration(minutes: 1)),
      );

      final replacement = await updates.firstWhere(
        (items) => items.length == 1 && items.single.item.name == 'Two updated',
      );
      expect(replacement.single.item.itemId, 'two');
      expect(await database.findMediaItem('server', 'one'), isNotNull);
    },
  );

  test(
    'watched sync status becomes stale without discarding a snapshot',
    () async {
      final now = DateTime.utc(2026, 8, 17);
      final key = _scopeKey('server', 'alice');
      await database.replaceScopes(
        items: [_item('server', 'one', 'One', now)],
        userStates: const [],
        scopes: [
          _scope('server', 'alice', ['one']),
        ],
        refreshedAt: now,
      );

      await database.markScopeStale(key, StateError('refresh failed'));

      final sync = await database.watchScopeSync(key).first;
      expect(sync?.stale, isTrue);
      expect(sync?.lastSuccessfulRefresh?.toUtc(), now);
      expect(sync?.errorMessage, contains('refresh failed'));
      expect(await database.watchScope(key).first, hasLength(1));
    },
  );

  test('a failed transaction rolls scope deletion back', () async {
    final now = DateTime.utc(2026, 8, 17);
    final key = _scopeKey('server', 'alice');
    await database.replaceScopes(
      items: [_item('server', 'one', 'One', now)],
      userStates: const [],
      scopes: [
        _scope('server', 'alice', ['one']),
      ],
      refreshedAt: now,
    );

    await expectLater(
      database.transaction(() async {
        await database.delete(database.scopeEntries).go();
        throw StateError('incomplete response');
      }),
      throwsStateError,
    );

    expect(await database.watchScope(key).first, hasLength(1));
  });
}

MediaItemsCompanion _item(
  String serverId,
  String itemId,
  String name,
  DateTime updatedAt,
) {
  return MediaItemsCompanion.insert(
    serverId: serverId,
    itemId: itemId,
    name: name,
    type: 'Movie',
    updatedAt: updatedAt,
  );
}

UserItemStatesCompanion _state(
  String serverId,
  String userId,
  String itemId,
  DateTime updatedAt, {
  int position = 0,
  bool played = false,
}) {
  return UserItemStatesCompanion.insert(
    serverId: serverId,
    userId: userId,
    itemId: itemId,
    playbackPositionTicks: Value(position),
    played: Value(played),
    updatedAt: updatedAt,
  );
}

ScopeKey _scopeKey(String serverId, String userId) {
  return ScopeKey(
    serverId: serverId,
    userId: userId,
    type: CacheScopeType.libraryContents,
    id: 'library',
  );
}

ScopeSnapshotWrite _scope(String serverId, String userId, List<String> ids) {
  return ScopeSnapshotWrite(
    key: _scopeKey(serverId, userId),
    orderedItemIds: ids,
  );
}
