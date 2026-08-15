import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/library/library_view_model.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.source,
    required this.session,
    required this.onSignOut,
    this.onOpenItem,
    super.key,
  });

  final JellyfinLibrarySource source;
  final JellyfinSession session;
  final Future<void> Function() onSignOut;
  final ValueChanged<JellyfinItem>? onOpenItem;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LibraryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = LibraryViewModel(
      source: widget.source,
      session: widget.session,
    )..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _open(JellyfinItem item) {
    final callback = widget.onOpenItem;
    if (callback != null) {
      callback(item);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} details are coming next.')),
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
              builder: (context, _) {
                return CustomScrollView(
                  key: const ValueKey('library-home'),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _LibraryHeader(
                        userName: widget.session.userName,
                        loading: _viewModel.loading,
                        onRefresh: _viewModel.load,
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                    if (_viewModel.loading && _viewModel.home == null)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_viewModel.error case final error?)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _LibraryMessage(
                          icon: Icons.cloud_off,
                          title: 'Could not load your library',
                          message: error,
                          actionLabel: 'Try again',
                          onAction: _viewModel.load,
                        ),
                      )
                    else if (_viewModel.home case final home?)
                      if (home.libraries.isEmpty &&
                          home.resume.isEmpty &&
                          home.latest.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _LibraryMessage(
                            icon: Icons.video_library_outlined,
                            title: 'Your library is empty',
                            message:
                                'Add media in Jellyfin, then refresh this screen.',
                            actionLabel: 'Refresh',
                            onAction: _viewModel.load,
                          ),
                        )
                      else ...[
                        if (home.libraries.isNotEmpty)
                          _LibrarySection(
                            title: 'My Media',
                            items: home.libraries,
                            landscape: true,
                            image: _viewModel.image,
                            onOpen: _open,
                            autofocusFirst: true,
                            sectionOrder: 1,
                          ),
                        if (home.resume.isNotEmpty)
                          _LibrarySection(
                            title: 'Continue Watching',
                            items: home.resume,
                            image: _viewModel.image,
                            onOpen: _open,
                            autofocusFirst: home.libraries.isEmpty,
                            sectionOrder: 2,
                          ),
                        if (home.latest.isNotEmpty)
                          _LibrarySection(
                            title: 'Latest Media',
                            items: home.latest,
                            image: _viewModel.image,
                            onOpen: _open,
                            autofocusFirst:
                                home.libraries.isEmpty && home.resume.isEmpty,
                            sectionOrder: 3,
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.userName,
    required this.loading,
    required this.onRefresh,
    required this.onSignOut,
  });

  final String userName;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 28, 32, 18),
      child: Row(
        children: [
          Icon(
            Icons.soup_kitchen,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Soup', style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  'Welcome back, $userName',
                  key: const ValueKey('library-welcome'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(900),
            child: IconButton.filledTonal(
              key: const ValueKey('refresh-library-button'),
              tooltip: 'Refresh library',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(width: 12),
          FocusTraversalOrder(
            order: const NumericFocusOrder(901),
            child: IconButton.filledTonal(
              key: const ValueKey('library-sign-out-button'),
              tooltip: 'Change server or account',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.title,
    required this.items,
    required this.image,
    required this.onOpen,
    required this.autofocusFirst,
    required this.sectionOrder,
    this.landscape = false,
  });

  final String title;
  final List<JellyfinItem> items;
  final Future<Uint8List?> Function(
    JellyfinItem item, {
    String type,
    int maxWidth,
  })
  image;
  final ValueChanged<JellyfinItem> onOpen;
  final bool autofocusFirst;
  final int sectionOrder;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final width = landscape ? 240.0 : 148.0;
    final artHeight = landscape ? 132.0 : 206.0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: artHeight + 62,
              child: ListView.separated(
                key: ValueKey('library-row-${title.toLowerCase()}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FocusTraversalOrder(
                    order: NumericFocusOrder(
                      sectionOrder * 100 + index.toDouble(),
                    ),
                    child: _MediaCard(
                      key: ValueKey('media-card-${item.id}'),
                      item: item,
                      width: width,
                      artHeight: artHeight,
                      image: image(item, maxWidth: landscape ? 600 : 400),
                      autofocus: autofocusFirst && index == 0,
                      onPressed: () => onOpen(item),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.item,
    required this.width,
    required this.artHeight,
    required this.image,
    required this.autofocus,
    required this.onPressed,
    super.key,
  });

  final JellyfinItem item;
  final double width;
  final double artHeight;
  final Future<Uint8List?> image;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _focused ? 1.045 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: widget.artHeight,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _focused ? colors.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.28),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FutureBuilder<Uint8List?>(
                    future: widget.image,
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes != null && bytes.isNotEmpty) {
                        return Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      }
                      return Center(
                        child: Icon(
                          widget.item.type == 'CollectionFolder'
                              ? Icons.video_library_outlined
                              : Icons.movie_outlined,
                          size: 42,
                          color: colors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (widget.item.playedPercentage case final progress?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0, 1),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
