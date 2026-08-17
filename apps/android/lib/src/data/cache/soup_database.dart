import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'soup_database.g.dart';

class MediaItems extends Table {
  TextColumn get serverId => text()();

  TextColumn get itemId => text()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get collectionType => text().nullable()();

  TextColumn get overview => text().nullable()();

  IntColumn get productionYear => integer().nullable()();

  TextColumn get officialRating => text().nullable()();

  RealColumn get communityRating => real().nullable()();

  IntColumn get runTimeTicks => integer().nullable()();

  TextColumn get seriesName => text().nullable()();

  TextColumn get seasonName => text().nullable()();

  IntColumn get indexNumber => integer().nullable()();

  IntColumn get parentIndexNumber => integer().nullable()();

  TextColumn get primaryImageTag => text().nullable()();

  TextColumn get backdropImageTag => text().nullable()();

  TextColumn get primaryBlurHash => text().nullable()();

  TextColumn get backdropBlurHash => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, itemId};
}

class UserItemStates extends Table {
  TextColumn get serverId => text()();

  TextColumn get userId => text()();

  TextColumn get itemId => text()();

  IntColumn get playbackPositionTicks =>
      integer().withDefault(const Constant(0))();

  RealColumn get playedPercentage => real().nullable()();

  BoolColumn get played => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, userId, itemId};
}

class ScopeEntries extends Table {
  TextColumn get serverId => text()();

  TextColumn get userId => text()();

  TextColumn get scopeType => text()();

  TextColumn get scopeId => text()();

  TextColumn get itemId => text()();

  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    serverId,
    userId,
    scopeType,
    scopeId,
    itemId,
  };
}

class ScopeSyncs extends Table {
  TextColumn get serverId => text()();

  TextColumn get userId => text()();

  TextColumn get scopeType => text()();

  TextColumn get scopeId => text()();

  DateTimeColumn get lastSuccessfulRefresh => dateTime().nullable()();

  BoolColumn get stale => boolean().withDefault(const Constant(false))();

  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, userId, scopeType, scopeId};
}

class ArtworkEntries extends Table {
  TextColumn get variantKey => text()();

  TextColumn get serverId => text()();

  TextColumn get itemId => text()();

  TextColumn get imageType => text()();

  IntColumn get imageIndex => integer().withDefault(const Constant(0))();

  TextColumn get imageTag => text()();

  IntColumn get width => integer()();

  IntColumn get quality => integer()();

  IntColumn get formatPolicyVersion => integer()();

  TextColumn get mimeType => text()();

  TextColumn get fileName => text()();

  IntColumn get byteSize => integer()();

  DateTimeColumn get lastAccess => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {variantKey};
}

abstract final class CacheScopeType {
  static const homeLibraries = 'home-libraries';
  static const homeResume = 'home-resume';
  static const homeLatest = 'home-latest';
  static const homeRecentMovies = 'home-recent-movies';
  static const homeRecentTv = 'home-recent-tv';
  static const itemDetails = 'item-details';
  static const libraryContents = 'library-contents';
  static const seriesSeasons = 'series-seasons';
  static const seasonEpisodes = 'season-episodes';
}

const homeScopeId = 'home';

class ScopeKey {
  const ScopeKey({
    required this.serverId,
    required this.userId,
    required this.type,
    required this.id,
  });

  final String serverId;
  final String userId;
  final String type;
  final String id;
}

class ScopeSnapshotWrite {
  const ScopeSnapshotWrite({required this.key, required this.orderedItemIds});

  final ScopeKey key;
  final List<String> orderedItemIds;
}

class CachedScopedItem {
  const CachedScopedItem({required this.item, this.userState});

  final MediaItem item;
  final UserItemState? userState;
}

@DriftDatabase(
  tables: [
    MediaItems,
    UserItemStates,
    ScopeEntries,
    ScopeSyncs,
    ArtworkEntries,
  ],
)
class SoupDatabase extends _$SoupDatabase {
  SoupDatabase() : super(driftDatabase(name: 'soup'));

  SoupDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> replaceScopes({
    required Iterable<MediaItemsCompanion> items,
    required Iterable<UserItemStatesCompanion> userStates,
    required Iterable<ScopeSnapshotWrite> scopes,
    DateTime? refreshedAt,
  }) {
    final completedAt = refreshedAt ?? DateTime.now();
    return transaction(() async {
      for (final item in items) {
        await into(mediaItems).insertOnConflictUpdate(item);
      }
      for (final state in userStates) {
        await into(userItemStates).insertOnConflictUpdate(state);
      }
      for (final scope in scopes) {
        await _replaceScope(scope, completedAt);
      }
    });
  }

  Future<void> _replaceScope(
    ScopeSnapshotWrite scope,
    DateTime completedAt,
  ) async {
    final key = scope.key;
    await (delete(scopeEntries)..where(
          (entry) =>
              entry.serverId.equals(key.serverId) &
              entry.userId.equals(key.userId) &
              entry.scopeType.equals(key.type) &
              entry.scopeId.equals(key.id),
        ))
        .go();

    final seen = <String>{};
    var position = 0;
    for (final itemId in scope.orderedItemIds) {
      if (!seen.add(itemId)) {
        continue;
      }
      await into(scopeEntries).insert(
        ScopeEntriesCompanion.insert(
          serverId: key.serverId,
          userId: key.userId,
          scopeType: key.type,
          scopeId: key.id,
          itemId: itemId,
          position: position++,
        ),
      );
    }

    await into(scopeSyncs).insertOnConflictUpdate(
      ScopeSyncsCompanion.insert(
        serverId: key.serverId,
        userId: key.userId,
        scopeType: key.type,
        scopeId: key.id,
        lastSuccessfulRefresh: Value(completedAt),
        stale: const Value(false),
        errorMessage: const Value(null),
      ),
    );
  }

  Future<void> markScopeStale(ScopeKey key, Object error) {
    return markScopesStale([key], error);
  }

  Future<void> markScopesStale(Iterable<ScopeKey> keys, Object error) {
    return transaction(() async {
      for (final key in keys) {
        await _markScopeStale(key, error);
      }
    });
  }

  Future<void> _markScopeStale(ScopeKey key, Object error) async {
    final previous =
        await (select(scopeSyncs)..where(
              (sync) =>
                  sync.serverId.equals(key.serverId) &
                  sync.userId.equals(key.userId) &
                  sync.scopeType.equals(key.type) &
                  sync.scopeId.equals(key.id),
            ))
            .getSingleOrNull();
    await into(scopeSyncs).insertOnConflictUpdate(
      ScopeSyncsCompanion.insert(
        serverId: key.serverId,
        userId: key.userId,
        scopeType: key.type,
        scopeId: key.id,
        lastSuccessfulRefresh: Value(previous?.lastSuccessfulRefresh),
        stale: const Value(true),
        errorMessage: Value(error.toString()),
      ),
    );
  }

  Stream<List<CachedScopedItem>> watchScope(ScopeKey key) {
    final query =
        select(scopeEntries).join([
            innerJoin(
              mediaItems,
              mediaItems.serverId.equalsExp(scopeEntries.serverId) &
                  mediaItems.itemId.equalsExp(scopeEntries.itemId),
            ),
            leftOuterJoin(
              userItemStates,
              userItemStates.serverId.equalsExp(scopeEntries.serverId) &
                  userItemStates.userId.equalsExp(scopeEntries.userId) &
                  userItemStates.itemId.equalsExp(scopeEntries.itemId),
            ),
          ])
          ..where(
            scopeEntries.serverId.equals(key.serverId) &
                scopeEntries.userId.equals(key.userId) &
                scopeEntries.scopeType.equals(key.type) &
                scopeEntries.scopeId.equals(key.id),
          )
          ..orderBy([OrderingTerm.asc(scopeEntries.position)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CachedScopedItem(
            item: row.readTable(mediaItems),
            userState: row.readTableOrNull(userItemStates),
          ),
      ],
    );
  }

  Stream<ScopeSync?> watchScopeSync(ScopeKey key) {
    return (select(scopeSyncs)..where(
          (sync) =>
              sync.serverId.equals(key.serverId) &
              sync.userId.equals(key.userId) &
              sync.scopeType.equals(key.type) &
              sync.scopeId.equals(key.id),
        ))
        .watchSingleOrNull();
  }

  Future<MediaItem?> findMediaItem(String serverId, String itemId) {
    return (select(mediaItems)..where(
          (item) => item.serverId.equals(serverId) & item.itemId.equals(itemId),
        ))
        .getSingleOrNull();
  }

  Stream<MediaItem?> watchMediaItem(String serverId, String itemId) {
    return (select(mediaItems)..where(
          (item) => item.serverId.equals(serverId) & item.itemId.equals(itemId),
        ))
        .watchSingleOrNull();
  }
}
