import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

const artworkGlobalByteLimit = 402653184;
const artworkBackdropByteLimit = 100663296;
const artworkQuality = 75;
const artworkBackdropWidth = 1280;
const artworkFormatPolicyVersion = 1;

enum ArtworkRequestPriority { visible, prefetch }

class CachedArtwork {
  const CachedArtwork({
    required this.file,
    required this.variantKey,
    required this.mimeType,
    required this.variantWidth,
  });

  final File file;
  final String variantKey;
  final String mimeType;
  final int variantWidth;
}

abstract interface class ArtworkRepository {
  Future<CachedArtwork?> getArtwork(
    JellyfinItem item, {
    String type,
    int imageIndex,
    int maxWidth,
    ArtworkRequestPriority priority,
  });

  void prefetch(JellyfinItem item, {String type, int imageIndex, int maxWidth});

  Stream<int> watchUsageBytes();

  Future<int> usageBytes();

  Future<void> clear();
}

class ArtworkCache implements ArtworkRepository {
  ArtworkCache({
    required this.database,
    required this.networkSource,
    required this.session,
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? now,
    int maxConcurrentDownloads = 4,
    this.globalByteLimit = artworkGlobalByteLimit,
    this.backdropByteLimit = artworkBackdropByteLimit,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory,
       _now = now ?? DateTime.now,
       _scheduler = ArtworkDownloadScheduler(maxConcurrentDownloads);

  final SoupDatabase database;
  final JellyfinArtworkNetworkSource networkSource;
  final JellyfinSession session;
  final int globalByteLimit;
  final int backdropByteLimit;
  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _now;
  final ArtworkDownloadScheduler _scheduler;
  final Map<String, Future<CachedArtwork?>> _inFlight = {};
  Future<Directory>? _directory;
  Future<void>? _mutationTail;
  int _generation = 0;
  int _temporaryFileSequence = 0;

  String get _serverId => session.serverId.isEmpty
      ? session.serverUrl.toString()
      : session.serverId;

  @override
  Future<CachedArtwork?> getArtwork(
    JellyfinItem item, {
    String type = 'Primary',
    int imageIndex = 0,
    int maxWidth = 480,
    ArtworkRequestPriority priority = ArtworkRequestPriority.visible,
  }) {
    final tag = type == 'Backdrop'
        ? item.backdropImageTag
        : item.primaryImageTag;
    if (item.id.isEmpty || tag == null || tag.isEmpty) {
      return Future.value();
    }
    final variant = ArtworkVariant(
      serverId: _serverId,
      itemId: item.id,
      imageType: type,
      imageIndex: imageIndex,
      imageTag: tag,
      width: maxWidth,
      quality: artworkQuality,
      formatPolicyVersion: artworkFormatPolicyVersion,
    );
    final key = variant.key;
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final generation = _generation;
    final completer = Completer<CachedArtwork?>();
    final future = completer.future;
    _inFlight[key] = future;
    unawaited(
      _completeRequest(
        key: key,
        future: future,
        completer: completer,
        variant: variant,
        item: item,
        priority: priority,
        generation: generation,
      ),
    );
    return future;
  }

  Future<void> _completeRequest({
    required String key,
    required Future<CachedArtwork?> future,
    required Completer<CachedArtwork?> completer,
    required ArtworkVariant variant,
    required JellyfinItem item,
    required ArtworkRequestPriority priority,
    required int generation,
  }) async {
    try {
      completer.complete(await _resolve(variant, item, priority, generation));
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  Future<CachedArtwork?> _resolve(
    ArtworkVariant variant,
    JellyfinItem item,
    ArtworkRequestPriority priority,
    int generation,
  ) async {
    final cached = await _lookup(variant);
    if (cached != null || generation != _generation) return cached;
    return _scheduler.schedule(
      priority,
      () => _download(variant, item, generation),
    );
  }

  Future<CachedArtwork?> _lookup(ArtworkVariant variant) async {
    final entry = await database.findArtwork(variant.key);
    if (entry == null) return null;
    final file = File('${(await _cacheDirectory()).path}/${entry.fileName}');
    if (!entry.mimeType.startsWith('image/') ||
        !await _isValidImageFile(file)) {
      await _removeEntry(entry);
      return null;
    }
    await database.touchArtwork(variant.key, _now().toUtc());
    return CachedArtwork(
      file: file,
      variantKey: entry.variantKey,
      mimeType: entry.mimeType,
      variantWidth: entry.width,
    );
  }

  Future<CachedArtwork?> _download(
    ArtworkVariant variant,
    JellyfinItem item,
    int generation,
  ) async {
    if (generation != _generation) return null;
    final response = await networkSource.downloadImage(
      session,
      item,
      type: variant.imageType,
      imageIndex: variant.imageIndex,
      maxWidth: variant.width,
      quality: variant.quality,
    );
    if (response == null || generation != _generation) return null;
    final mimeType = response.mimeType.toLowerCase().split(';').first.trim();
    if (!mimeType.startsWith('image/') ||
        !_hasSupportedImageSignature(response.bytes)) {
      throw const JellyfinApiException(
        'Jellyfin returned invalid artwork bytes.',
      );
    }

    return _mutate(() async {
      if (generation != _generation) return null;
      final directory = await _cacheDirectory();
      final fileName = '${variant.key}${_extensionFor(mimeType)}';
      final file = File('${directory.path}/$fileName');
      final temporary = File('${file.path}.${_temporaryFileSequence++}.tmp');
      try {
        await temporary.writeAsBytes(response.bytes, flush: true);
        if (generation != _generation) {
          await _deleteIfPresent(temporary);
          return null;
        }
        await _deleteIfPresent(file);
        await temporary.rename(file.path);
        final accessedAt = _now().toUtc();
        await database.upsertArtwork(
          ArtworkEntriesCompanion.insert(
            variantKey: variant.key,
            serverId: variant.serverId,
            itemId: variant.itemId,
            imageType: variant.imageType,
            imageIndex: Value(variant.imageIndex),
            imageTag: variant.imageTag,
            width: variant.width,
            quality: variant.quality,
            formatPolicyVersion: variant.formatPolicyVersion,
            mimeType: mimeType,
            fileName: fileName,
            byteSize: response.bytes.length,
            lastAccess: accessedAt,
          ),
        );
        await _enforceLimits();
        final retained = await database.findArtwork(variant.key);
        if (retained == null || !await file.exists()) return null;
        return CachedArtwork(
          file: file,
          variantKey: variant.key,
          mimeType: mimeType,
          variantWidth: variant.width,
        );
      } on Object {
        await _deleteIfPresent(temporary);
        rethrow;
      }
    });
  }

  Future<void> _enforceLimits() async {
    var backdropBytes = await database.artworkBytes(backdropsOnly: true);
    if (backdropBytes > backdropByteLimit) {
      for (final entry in await database.oldestArtwork(backdropsOnly: true)) {
        if (backdropBytes <= backdropByteLimit) break;
        await _removeEntry(entry);
        backdropBytes -= entry.byteSize;
      }
    }

    var totalBytes = await database.artworkBytes();
    if (totalBytes > globalByteLimit) {
      for (final entry in await database.oldestArtwork()) {
        if (totalBytes <= globalByteLimit) break;
        await _removeEntry(entry);
        totalBytes -= entry.byteSize;
      }
    }
  }

  Future<void> _removeEntry(ArtworkEntry entry) async {
    final file = File('${(await _cacheDirectory()).path}/${entry.fileName}');
    await _deleteIfPresent(file);
    await database.removeArtwork(entry.variantKey);
  }

  @override
  void prefetch(
    JellyfinItem item, {
    String type = 'Primary',
    int imageIndex = 0,
    int maxWidth = 480,
  }) {
    unawaited(
      getArtwork(
        item,
        type: type,
        imageIndex: imageIndex,
        maxWidth: maxWidth,
        priority: ArtworkRequestPriority.prefetch,
      ).catchError((Object _) => null),
    );
  }

  @override
  Stream<int> watchUsageBytes() => database.watchArtworkBytes();

  @override
  Future<int> usageBytes() => database.artworkBytes();

  @override
  Future<void> clear() async {
    _generation++;
    _inFlight.clear();
    await _mutate(() async {
      final directory = await _cacheDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
      await database.clearArtworkManifest();
    });
  }

  Future<Directory> _cacheDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final future = _directoryProvider().then((directory) async {
      await directory.create(recursive: true);
      return directory;
    });
    _directory = future;
    return future;
  }

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final previous = _mutationTail;
    final release = Completer<void>();
    _mutationTail = release.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  static Future<Directory> _defaultDirectory() async {
    final cache = await getTemporaryDirectory();
    return Directory('${cache.path}/artwork');
  }
}

class ArtworkVariant {
  const ArtworkVariant({
    required this.serverId,
    required this.itemId,
    required this.imageType,
    required this.imageIndex,
    required this.imageTag,
    required this.width,
    required this.quality,
    required this.formatPolicyVersion,
  });

  final String serverId;
  final String itemId;
  final String imageType;
  final int imageIndex;
  final String imageTag;
  final int width;
  final int quality;
  final int formatPolicyVersion;

  String get key => base64Url
      .encode(
        utf8.encode(
          jsonEncode([
            serverId,
            itemId,
            imageType,
            imageIndex,
            imageTag,
            width,
            quality,
            formatPolicyVersion,
          ]),
        ),
      )
      .replaceAll('=', '');
}

class ArtworkDownloadScheduler {
  ArtworkDownloadScheduler(this.maximumConcurrent);

  final int maximumConcurrent;
  final Queue<_DownloadJob> _visible = Queue();
  final Queue<_DownloadJob> _prefetch = Queue();
  int _active = 0;

  Future<T> schedule<T>(
    ArtworkRequestPriority priority,
    Future<T> Function() work,
  ) {
    final completer = Completer<T>();
    final job = _DownloadJob(() async {
      try {
        completer.complete(await work());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    (priority == ArtworkRequestPriority.visible ? _visible : _prefetch).add(
      job,
    );
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_active < maximumConcurrent &&
        (_visible.isNotEmpty || _prefetch.isNotEmpty)) {
      final job = _visible.isNotEmpty
          ? _visible.removeFirst()
          : _prefetch.removeFirst();
      _active++;
      unawaited(
        job.run().whenComplete(() {
          _active--;
          _drain();
        }),
      );
    }
  }
}

class _DownloadJob {
  const _DownloadJob(this.run);

  final Future<void> Function() run;
}

Future<void> _deleteIfPresent(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // A cache file can disappear between the existence check and deletion.
  }
}

Future<bool> _isValidImageFile(File file) async {
  if (!await file.exists() || await file.length() == 0) return false;
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    return _hasSupportedImageSignature(await handle.read(16));
  } on FileSystemException {
    return false;
  } finally {
    await handle?.close();
  }
}

bool _hasSupportedImageSignature(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return true;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return true;
  }
  return bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
}

String _extensionFor(String mimeType) => switch (mimeType) {
  'image/jpeg' || 'image/jpg' => '.jpg',
  'image/png' => '.png',
  'image/webp' => '.webp',
  _ => '.image',
};
