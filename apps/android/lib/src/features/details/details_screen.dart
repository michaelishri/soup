import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';
import 'package:soup/src/features/details/details_view_model.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/shared/artwork_placeholder.dart';
import 'package:soup/src/features/shared/fading_artwork.dart';
import 'package:soup/src/features/shared/stale_data_banner.dart';

typedef PlayItem = void Function(JellyfinItem item, Duration startAt);

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({
    required this.source,
    required this.artworkSource,
    required this.session,
    required this.item,
    required this.onPlay,
    this.metadataRepository,
    this.artworkRepository,
    super.key,
  });

  final JellyfinDetailsSource source;
  final JellyfinLibrarySource artworkSource;
  final JellyfinMetadataRepository? metadataRepository;
  final ArtworkRepository? artworkRepository;
  final JellyfinSession session;
  final JellyfinItem item;
  final PlayItem onPlay;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final DetailsViewModel _viewModel;
  late final JellyfinMetadataRepository _metadataRepository;
  late final bool _ownsMetadataRepository;
  final Map<String, Future<CachedArtwork?>> _images = {};
  final Set<String> _prefetchedImages = {};

  @override
  void initState() {
    super.initState();
    _ownsMetadataRepository = widget.metadataRepository == null;
    _metadataRepository =
        widget.metadataRepository ??
        TransientJellyfinMetadataRepository(
          session: widget.session,
          librarySource: widget.artworkSource,
          detailsSource: widget.source,
        );
    _viewModel = DetailsViewModel(
      repository: _metadataRepository,
      initialItem: widget.item,
    )..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    if (_ownsMetadataRepository) {
      unawaited(_metadataRepository.close());
    }
    super.dispose();
  }

  Future<CachedArtwork?> _image(
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 900,
  }) {
    final detailTag = type == 'Backdrop'
        ? item.backdropImageTag
        : item.primaryImageTag;
    final initialTag = type == 'Backdrop'
        ? widget.item.backdropImageTag
        : widget.item.primaryImageTag;
    final artworkItem =
        item.id == widget.item.id &&
            (detailTag == null || detailTag.isEmpty) &&
            initialTag != null &&
            initialTag.isNotEmpty
        ? widget.item
        : item;
    final key = '${artworkItem.id}:$type:$maxWidth:$detailTag:$initialTag';
    return _images.putIfAbsent(
      key,
      () =>
          widget.artworkRepository
              ?.getArtwork(artworkItem, type: type, maxWidth: maxWidth)
              .catchError((Object _) => null) ??
          Future.value(),
    );
  }

  void _prefetch(JellyfinItem item, {int maxWidth = 720}) {
    final repository = widget.artworkRepository;
    final tag = item.primaryImageTag;
    if (repository == null || tag == null || tag.isEmpty) return;
    final key = '${item.id}:Primary:$maxWidth:$tag';
    if (!_prefetchedImages.add(key)) return;
    repository.prefetch(item, maxWidth: maxWidth);
  }

  void _play(JellyfinItem item) {
    widget.onPlay(item, _viewModel.resumePosition(item));
  }

  void _openItem(JellyfinItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailsScreen(
          source: widget.source,
          artworkSource: widget.artworkSource,
          metadataRepository: _metadataRepository,
          artworkRepository: widget.artworkRepository,
          session: widget.session,
          item: item,
          onPlay: widget.onPlay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  _Backdrop(
                    artworkKey: _viewModel.item.id,
                    blurHash: _viewModel.item.backdropBlurHash,
                    image: _image(
                      _viewModel.item,
                      type: 'Backdrop',
                      maxWidth: artworkBackdropWidth,
                    ),
                  ),
                  if (_viewModel.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_viewModel.blockingError case final error?)
                    _DetailsError(error: error, onRetry: _viewModel.load)
                  else if (_viewModel.item.type == 'CollectionFolder')
                    _LibraryContents(
                      library: _viewModel.item,
                      items: _viewModel.libraryItems,
                      image: _image,
                      prefetch: _prefetch,
                      onOpen: _openItem,
                    )
                  else
                    _ItemDetails(
                      item: _viewModel.item,
                      seasons: _viewModel.seasons,
                      selectedSeason: _viewModel.selectedSeason,
                      episodes: _viewModel.episodes,
                      loadingEpisodes: _viewModel.loadingEpisodes,
                      image: _image,
                      onSelectSeason: _viewModel.selectSeason,
                      onPlay: _play,
                    ),
                  Positioned(
                    left: 24,
                    top: 18,
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(900),
                      child: IconButton.filledTonal(
                        key: const ValueKey('details-back-button'),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(PhosphorIconsRegular.arrowLeft),
                      ),
                    ),
                  ),
                  if (_viewModel.stale && _viewModel.blockingError == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: StaleDataBanner(
                        message:
                            _viewModel.error ??
                            'Showing saved data. Refresh failed.',
                        retrying:
                            _viewModel.refreshing ||
                            _viewModel.refreshingEpisodes,
                        onRetry: _viewModel.retry,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.artworkKey,
    required this.blurHash,
    required this.image,
  });

  final String artworkKey;
  final String? blurHash;
  final Future<CachedArtwork?> image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AuthenticatedThemeTokens>();
    final start = tokens?.heroScrimStart ?? Colors.transparent;
    final end = tokens?.heroScrimEnd ?? theme.scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        FadingArtwork(
          key: const ValueKey('details-background-crossfade'),
          artworkKey: artworkKey,
          image: image,
          opacity: 0.28,
          placeholder: Opacity(
            opacity: 0.28,
            child: ArtworkPlaceholder(blurHash: blurHash),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [start, end.withValues(alpha: 0.85), end],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({
    required this.item,
    required this.seasons,
    required this.selectedSeason,
    required this.episodes,
    required this.loadingEpisodes,
    required this.image,
    required this.onSelectSeason,
    required this.onPlay,
  });

  final JellyfinItem item;
  final List<JellyfinItem> seasons;
  final JellyfinItem? selectedSeason;
  final List<JellyfinItem> episodes;
  final bool loadingEpisodes;
  final Future<CachedArtwork?> Function(
    JellyfinItem item, {
    String type,
    int maxWidth,
  })
  image;
  final ValueChanged<JellyfinItem> onSelectSeason;
  final ValueChanged<JellyfinItem> onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final blockbuster =
            Theme.of(context).extension<AuthenticatedThemeTokens>()?.preset ==
            UiPreset.blockbuster;
        return SingleChildScrollView(
          key: const ValueKey('item-details'),
          padding: EdgeInsets.fromLTRB(
            wide ? (blockbuster ? 72 : 96) : 28,
            wide && blockbuster ? 150 : 96,
            wide ? 72 : 28,
            48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide && blockbuster)
                _Metadata(item: item, onPlay: onPlay)
              else if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Poster(
                      image: image(item),
                      blurHash: item.primaryBlurHash,
                      width: 250,
                      height: 360,
                    ),
                    const SizedBox(width: 44),
                    Expanded(
                      child: _Metadata(item: item, onPlay: onPlay),
                    ),
                  ],
                )
              else ...[
                Center(
                  child: _Poster(
                    image: image(item),
                    blurHash: item.primaryBlurHash,
                    width: 190,
                    height: 270,
                  ),
                ),
                const SizedBox(height: 24),
                _Metadata(item: item, onPlay: onPlay),
              ],
              if (item.type == 'Series') ...[
                const SizedBox(height: 36),
                Text('Seasons', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (var index = 0; index < seasons.length; index++)
                      FocusTraversalOrder(
                        order: NumericFocusOrder(100 + index.toDouble()),
                        child: ChoiceChip(
                          key: ValueKey('season-${seasons[index].id}'),
                          label: Text(seasons[index].name),
                          selected: selectedSeason?.id == seasons[index].id,
                          onSelected: (_) => onSelectSeason(seasons[index]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (loadingEpisodes)
                  const Center(child: CircularProgressIndicator())
                else if (episodes.isEmpty)
                  const Text('No episodes are available for this season.')
                else
                  _EpisodeList(
                    episodes: episodes,
                    image: image,
                    onPlay: onPlay,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.item, required this.onPlay});

  final JellyfinItem item;
  final ValueChanged<JellyfinItem> onPlay;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (item.productionYear case final year?) '$year',
      ?item.officialRating,
      if (item.runTimeTicks case final ticks?) _runtime(ticks),
      if (item.communityRating case final rating?)
        '★ ${rating.toStringAsFixed(1)}',
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.seriesName case final series?)
            Text(series, style: Theme.of(context).textTheme.titleMedium),
          if (SoupTheme.isFestival(context))
            Container(
              key: const ValueKey('festival-details-title'),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: SoupTheme.onboardingAccent,
                boxShadow: [
                  BoxShadow(
                    color: SoupTheme.onboardingInk,
                    offset: Offset(5, 5),
                  ),
                ],
              ),
              child: Text(
                item.name,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: SoupTheme.onboardingSurface,
                ),
              ),
            )
          else
            Text(item.name, style: Theme.of(context).textTheme.displaySmall),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(metadata.join('  •  ')),
          ],
          if (item.isPlayable) ...[
            const SizedBox(height: 22),
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: FilledButton.icon(
                key: const ValueKey('play-item-button'),
                autofocus: true,
                onPressed: () => onPlay(item),
                icon: Icon(
                  item.playbackPositionTicks > 0
                      ? PhosphorIconsRegular.arrowCounterClockwise
                      : PhosphorIconsFill.play,
                ),
                label: Text(item.playbackPositionTicks > 0 ? 'Resume' : 'Play'),
              ),
            ),
          ],
          if (item.overview case final overview?) ...[
            const SizedBox(height: 24),
            Text(
              overview,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  static String _runtime(int ticks) {
    final minutes = Duration(microseconds: ticks ~/ 10).inMinutes;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return hours == 0 ? '${minutes}m' : '${hours}h ${remainder}m';
  }
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({
    required this.episodes,
    required this.image,
    required this.onPlay,
  });

  final List<JellyfinItem> episodes;
  final Future<CachedArtwork?> Function(
    JellyfinItem item, {
    String type,
    int maxWidth,
  })
  image;
  final ValueChanged<JellyfinItem> onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < episodes.length; index++) ...[
          FocusTraversalOrder(
            order: NumericFocusOrder(200 + index.toDouble()),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('episode-${episodes[index].id}'),
                onTap: () => onPlay(episodes[index]),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _Poster(
                        image: image(episodes[index], maxWidth: 720),
                        blurHash: episodes[index].primaryBlurHash,
                        width: 180,
                        height: 102,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _episodeTitle(episodes[index]),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (episodes[index].overview case final overview?)
                              Text(
                                overview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        episodes[index].playbackPositionTicks > 0
                            ? PhosphorIconsRegular.arrowCounterClockwise
                            : PhosphorIconsFill.play,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  static String _episodeTitle(JellyfinItem item) {
    final number = item.indexNumber;
    return number == null ? item.name : '$number. ${item.name}';
  }
}

class _LibraryContents extends StatelessWidget {
  const _LibraryContents({
    required this.library,
    required this.items,
    required this.image,
    required this.prefetch,
    required this.onOpen,
  });

  final JellyfinItem library;
  final List<JellyfinItem> items;
  final Future<CachedArtwork?> Function(
    JellyfinItem item, {
    String type,
    int maxWidth,
  })
  image;
  final void Function(JellyfinItem item, {int maxWidth}) prefetch;
  final ValueChanged<JellyfinItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final gridWidth = MediaQuery.sizeOf(context).width - 120;
    final calculatedColumns = ((gridWidth + 18) / (210 + 18)).ceil();
    final columnCount = calculatedColumns < 1 ? 1 : calculatedColumns;
    return CustomScrollView(
      key: const ValueKey('library-contents'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(96, 96, 48, 20),
          sliver: SliverToBoxAdapter(
            child: Text(
              library.name,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No movies or series are in this library.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(72, 10, 48, 48),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                childAspectRatio: 0.66,
                crossAxisSpacing: 18,
                mainAxisSpacing: 22,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final prefetchIndex = index + columnCount;
                if (prefetchIndex < items.length) {
                  prefetch(items[prefetchIndex], maxWidth: 720);
                }
                return FocusTraversalOrder(
                  order: NumericFocusOrder(index + 1.0),
                  child: _DetailCard(
                    item: items[index],
                    image: image(items[index], maxWidth: 720),
                    autofocus: index == 0,
                    onPressed: () => onOpen(items[index]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.item,
    required this.image,
    required this.autofocus,
    required this.onPressed,
  });

  final JellyfinItem item;
  final Future<CachedArtwork?> image;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: item.name,
        button: true,
        child: InkWell(
          key: ValueKey('detail-card-${item.id}'),
          autofocus: autofocus,
          onTap: onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Poster(
                  image: image,
                  blurHash: item.primaryBlurHash,
                  width: double.infinity,
                  height: 300,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.image,
    required this.blurHash,
    required this.width,
    required this.height,
  });

  final Future<CachedArtwork?> image;
  final String? blurHash;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(
            SoupTheme.isFestival(context) ? 4 : 12,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            SoupTheme.isFestival(context) ? 4 : 12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => FutureBuilder<CachedArtwork?>(
              future: image,
              builder: (context, snapshot) {
                final artwork = snapshot.data;
                final placeholder = ArtworkPlaceholder(
                  blurHash: blurHash,
                  fallback: const Center(
                    child: Icon(PhosphorIconsRegular.filmSlate, size: 44),
                  ),
                );
                if (artwork == null) return placeholder;
                final logicalWidth = width.isFinite
                    ? width
                    : constraints.maxWidth;
                final physicalWidth = logicalWidth.isFinite
                    ? (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                    : artwork.variantWidth;
                return Image.file(
                  artwork.file,
                  fit: BoxFit.cover,
                  cacheWidth: physicalWidth.clamp(1, artwork.variantWidth),
                  errorBuilder: (_, _, _) => placeholder,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsRegular.warningCircle, size: 52),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
