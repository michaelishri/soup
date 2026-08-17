import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

void main() {
  late SoupDatabase database;
  late Directory directory;

  setUp(() async {
    database = SoupDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    directory = await Directory.systemTemp.createTemp('soup-artwork-cache-');
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('uses the exact production cache limits', () {
    expect(artworkGlobalByteLimit, 402653184);
    expect(artworkBackdropByteLimit, 100663296);
    expect(artworkQuality, 75);
    expect(artworkBackdropWidth, 1280);
  });

  test('disk hits survive cache recreation', () async {
    final network = FakeArtworkNetwork();
    final firstCache = _cache(database, directory, network);
    final first = await firstCache.getArtwork(_item('one'));

    final recreated = _cache(database, directory, network);
    final second = await recreated.getArtwork(_item('one'));

    expect(network.calls, 1);
    expect(second?.variantKey, first?.variantKey);
    expect(await second?.file.exists(), isTrue);
  });

  test('image tag changes create a new cached variant', () async {
    final network = FakeArtworkNetwork();
    final cache = _cache(database, directory, network);

    final first = await cache.getArtwork(_item('one', tag: 'old'));
    final second = await cache.getArtwork(_item('one', tag: 'new'));

    expect(network.calls, 2);
    expect(second?.variantKey, isNot(first?.variantKey));
    expect(await database.allArtwork(), hasLength(2));
  });

  test('usage stream updates after downloads and clearing', () async {
    final cache = _cache(database, directory, FakeArtworkNetwork(bytes: 12));
    expect(await cache.watchUsageBytes().first, 0);
    final downloadedUsage = cache.watchUsageBytes().firstWhere(
      (bytes) => bytes == 12,
    );

    await cache.getArtwork(_item('one'));
    expect(await downloadedUsage, 12);

    final clearedUsage = cache.watchUsageBytes().firstWhere(
      (bytes) => bytes == 0,
    );
    await cache.clear();
    expect(await clearedUsage, 0);
  });

  test('concurrent identical requests share one download', () async {
    final network = FakeArtworkNetwork();
    final cache = _cache(database, directory, network);

    final requests = <Future<CachedArtwork?>>[];
    for (var index = 0; index < 8; index++) {
      requests.add(cache.getArtwork(_item('one')));
    }
    final results = await Future.wait(requests);

    expect(network.calls, 1);
    expect(results.map((result) => result?.variantKey).toSet(), hasLength(1));
  });

  test('missing and corrupt files are redownloaded as cache misses', () async {
    final network = FakeArtworkNetwork();
    final cache = _cache(database, directory, network);
    final item = _item('one');

    final missing = await cache.getArtwork(item);
    await missing!.file.delete();
    await cache.getArtwork(item);
    expect(network.calls, 2);

    final corrupt = await cache.getArtwork(item);
    await corrupt!.file.writeAsBytes([1, 2, 3], flush: true);
    await cache.getArtwork(item);
    expect(network.calls, 3);
  });

  test(
    'backdrop and global limits evict true least-recently-used rows',
    () async {
      var now = DateTime.utc(2026, 8, 17);
      final network = FakeArtworkNetwork(bytes: 12);
      final cache = _cache(
        database,
        directory,
        network,
        now: () => now,
        globalLimit: 24,
        backdropLimit: 24,
      );

      await cache.getArtwork(_item('a'));
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(_item('b'));
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(_item('a'));
      now = now.add(const Duration(seconds: 1));
      final c = await cache.getArtwork(_item('c'));

      final primaryRows = await database.allArtwork();
      expect(primaryRows.map((entry) => entry.itemId).toSet(), {'a', 'c'});
      expect(await c?.file.exists(), isTrue);

      await cache.clear();
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(
        _item('backdrop-a'),
        type: 'Backdrop',
        maxWidth: artworkBackdropWidth,
      );
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(
        _item('backdrop-b'),
        type: 'Backdrop',
        maxWidth: artworkBackdropWidth,
      );
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(
        _item('backdrop-a'),
        type: 'Backdrop',
        maxWidth: artworkBackdropWidth,
      );
      now = now.add(const Duration(seconds: 1));
      await cache.getArtwork(
        _item('backdrop-c'),
        type: 'Backdrop',
        maxWidth: artworkBackdropWidth,
      );

      final backdropRows = await database.allArtwork();
      expect(backdropRows.map((entry) => entry.itemId).toSet(), {
        'backdrop-a',
        'backdrop-c',
      });
      expect(await cache.usageBytes(), 24);
    },
  );

  test('runs at most four downloads and promotes visible work', () async {
    final scheduler = ArtworkDownloadScheduler(4);
    final gates = <String, Completer<void>>{};
    final started = <String>[];
    final visibleStarted = Completer<void>();
    var active = 0;
    var maximumActive = 0;
    Future<void> run(String id) async {
      active++;
      if (active > maximumActive) maximumActive = active;
      started.add(id);
      if (id == 'visible') visibleStarted.complete();
      try {
        await gates.putIfAbsent(id, Completer.new).future;
      } finally {
        active--;
      }
    }

    final prefetches = <Future<void>>[];
    for (var index = 0; index < 6; index++) {
      prefetches.add(
        scheduler.schedule(
          ArtworkRequestPriority.prefetch,
          () => run('prefetch-$index'),
        ),
      );
    }
    expect(started, ['prefetch-0', 'prefetch-1', 'prefetch-2', 'prefetch-3']);
    expect(maximumActive, 4);

    final visible = scheduler.schedule(
      ArtworkRequestPriority.visible,
      () => run('visible'),
    );
    gates['prefetch-0']!.complete();
    await visibleStarted.future;

    expect(started.take(5).last, 'visible');
    expect(started.take(5), isNot(contains('prefetch-4')));

    for (final id in ['prefetch-1', 'prefetch-2', 'prefetch-3', 'visible']) {
      gates[id]!.complete();
    }
    await Future.wait([...prefetches.take(4), visible]);
    expect(started, hasLength(7));
    gates['prefetch-4']!.complete();
    gates['prefetch-5']!.complete();
    await Future.wait([...prefetches, visible]);
    expect(maximumActive, 4);
  });

  test('promotes a matching queued prefetch when it becomes visible', () async {
    final scheduler = ArtworkDownloadScheduler(1);
    final runningGate = Completer<void>();
    final targetGate = Completer<void>();
    final otherGate = Completer<void>();
    final targetStarted = Completer<void>();
    final started = <String>[];
    Future<void> run(
      String id,
      Completer<void> gate, {
      Completer<void>? signal,
    }) async {
      started.add(id);
      signal?.complete();
      await gate.future;
    }

    final running = scheduler.schedule(
      ArtworkRequestPriority.prefetch,
      () => run('running', runningGate),
      key: 'running',
    );
    final target = scheduler.schedule(
      ArtworkRequestPriority.prefetch,
      () => run('target', targetGate, signal: targetStarted),
      key: 'target',
    );
    final other = scheduler.schedule(
      ArtworkRequestPriority.prefetch,
      () => run('other', otherGate),
      key: 'other',
    );

    scheduler.promote('target');
    runningGate.complete();
    await targetStarted.future;
    expect(started, ['running', 'target']);

    targetGate.complete();
    await target;
    otherGate.complete();
    await Future.wait([running, other]);
  });

  test('failed responses are not cached and leave the dedupe map', () async {
    final network = FakeArtworkNetwork(mimeType: 'text/plain');
    final cache = _cache(database, directory, network);

    await expectLater(cache.getArtwork(_item('one')), throwsA(isA<Object>()));
    await Future<void>.value();
    await expectLater(cache.getArtwork(_item('one')), throwsA(isA<Object>()));

    expect(network.calls, 2);
    expect(await database.allArtwork(), isEmpty);
  });

  test('clear cannot be undone by an older in-flight request', () async {
    late ArtworkCache cache;
    final network = FakeArtworkNetwork(
      handler: (_, _, _, _, _) async {
        await cache.clear();
        return _response();
      },
    );
    cache = _cache(database, directory, network);
    await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            serverId: 'server',
            itemId: 'metadata',
            name: 'Metadata survives',
            type: 'Movie',
            updatedAt: DateTime.utc(2026, 8, 17),
          ),
        );

    expect(await cache.getArtwork(_item('one')), isNull);
    expect(network.calls, 1);
    expect(await cache.usageBytes(), 0);
    expect(await database.allArtwork(), isEmpty);
    expect(await database.findMediaItem('server', 'metadata'), isNotNull);
    expect(await directory.list().toList(), isEmpty);
  });
}

ArtworkCache _cache(
  SoupDatabase database,
  Directory directory,
  FakeArtworkNetwork network, {
  DateTime Function()? now,
  int globalLimit = artworkGlobalByteLimit,
  int backdropLimit = artworkBackdropByteLimit,
}) {
  return ArtworkCache(
    database: database,
    networkSource: network,
    session: _session,
    directoryProvider: () async => directory,
    now: now,
    globalByteLimit: globalLimit,
    backdropByteLimit: backdropLimit,
  );
}

final _session = JellyfinSession(
  serverUrl: Uri.parse('http://jellyfin/'),
  serverId: 'server',
  userId: 'user',
  userName: 'Alex',
  accessToken: 'token',
);

JellyfinItem _item(String id, {String? tag}) => JellyfinItem(
  id: id,
  name: id,
  type: 'Movie',
  primaryImageTag: tag ?? 'primary-$id',
  backdropImageTag: tag ?? 'backdrop-$id',
);

JellyfinImageResponse _response({int bytes = 12}) =>
    JellyfinImageResponse(bytes: _imageBytes(bytes), mimeType: 'image/png');

Uint8List _imageBytes(int length) {
  final bytes = Uint8List(length < 8 ? 8 : length);
  bytes.setAll(0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  return bytes;
}

class FakeArtworkNetwork implements JellyfinArtworkNetworkSource {
  FakeArtworkNetwork({
    this.bytes = 12,
    this.mimeType = 'image/png',
    this.handler,
  });

  final int bytes;
  final String mimeType;
  final Future<JellyfinImageResponse?> Function(
    JellyfinItem item,
    String type,
    int imageIndex,
    int maxWidth,
    int quality,
  )?
  handler;
  int calls = 0;
  int active = 0;
  int maximumActive = 0;
  final List<String> started = [];

  @override
  Future<JellyfinImageResponse?> downloadImage(
    JellyfinSession session,
    JellyfinItem item, {
    required String type,
    required int imageIndex,
    required int maxWidth,
    required int quality,
  }) async {
    calls++;
    active++;
    if (active > maximumActive) maximumActive = active;
    started.add(item.id);
    try {
      final custom = handler;
      if (custom != null) {
        return await custom(item, type, imageIndex, maxWidth, quality);
      }
      return JellyfinImageResponse(
        bytes: _imageBytes(bytes),
        mimeType: mimeType,
      );
    } finally {
      active--;
    }
  }
}
