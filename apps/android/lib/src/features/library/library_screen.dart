import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/library/library_view_model.dart';

enum _FruityDestination { home, tv, movies, settings }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.source,
    required this.session,
    required this.onSignOut,
    this.appearance = AppearanceSettings.defaults,
    this.onSaveAppearance,
    this.onOpenItem,
    super.key,
  });

  final JellyfinLibrarySource source;
  final JellyfinSession session;
  final Future<void> Function() onSignOut;
  final AppearanceSettings appearance;
  final Future<void> Function(AppearanceSettings)? onSaveAppearance;
  final ValueChanged<JellyfinItem>? onOpenItem;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LibraryViewModel _viewModel;
  late AppearanceSettings _appearanceDraft;
  _FruityDestination _destination = _FruityDestination.home;
  bool _savingAppearance = false;

  @override
  void initState() {
    super.initState();
    _appearanceDraft = widget.appearance;
    _viewModel = LibraryViewModel(
      source: widget.source,
      session: widget.session,
    )..load();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance) {
      _appearanceDraft = widget.appearance;
    }
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

  Future<void> _saveAppearance() async {
    final save = widget.onSaveAppearance;
    if (save == null || _savingAppearance) return;
    setState(() => _savingAppearance = true);
    await save(_appearanceDraft);
    if (!mounted) return;
    setState(() => _savingAppearance = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Appearance updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
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
            child: Column(
              children: [
                if (wide)
                  _FruityTopNavigation(
                    destination: _destination,
                    userName: widget.session.userName,
                    onSelected: (value) => setState(() => _destination = value),
                  ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _viewModel,
                    builder: (context, _) => _content(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _destination.index,
              onDestinationSelected: (index) => setState(
                () => _destination = _FruityDestination.values[index],
              ),
              destinations: const [
                NavigationDestination(
                  key: ValueKey('fruity-mobile-home'),
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tv_outlined),
                  selectedIcon: Icon(Icons.tv),
                  label: 'TV',
                ),
                NavigationDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: 'Movies',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _content() {
    if (_viewModel.loading && _viewModel.home == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.error case final error?) {
      return _LibraryMessage(
        icon: Icons.cloud_off,
        title: 'Could not load your library',
        message: error,
        actionLabel: 'Try again',
        onAction: _viewModel.load,
      );
    }
    final home = _viewModel.home;
    if (home == null) return const SizedBox.shrink();

    return switch (_destination) {
      _FruityDestination.home => _home(home),
      _FruityDestination.tv => _libraryDestination(home, television: true),
      _FruityDestination.movies => _libraryDestination(home, television: false),
      _FruityDestination.settings => _settings(),
    };
  }

  Widget _home(JellyfinHome home) {
    if (home.libraries.isEmpty && home.resume.isEmpty && home.latest.isEmpty) {
      return _LibraryMessage(
        icon: Icons.video_library_outlined,
        title: 'Your library is empty',
        message: 'Add media in Jellyfin, then refresh this screen.',
        actionLabel: 'Refresh',
        onAction: _viewModel.load,
      );
    }
    final hero = home.resume.firstOrNull ?? home.latest.firstOrNull;
    return CustomScrollView(
      key: const ValueKey('library-home'),
      slivers: [
        if (hero != null)
          SliverToBoxAdapter(
            child: _FruityHero(
              item: hero,
              userName: widget.session.userName,
              image: _viewModel.image(hero, type: 'Backdrop', maxWidth: 1600),
              onOpen: () => _open(hero),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
              child: Text(
                'Welcome back, ${widget.session.userName}',
                key: const ValueKey('library-welcome'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        if (home.resume.isNotEmpty)
          _LibrarySection(
            title: 'Continue Watching',
            items: home.resume,
            landscape: true,
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
            autofocusFirst: home.resume.isEmpty && home.libraries.isEmpty,
            sectionOrder: 3,
          ),
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
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }

  Widget _libraryDestination(JellyfinHome home, {required bool television}) {
    final items = home.libraries.where((item) {
      final type = item.collectionType?.toLowerCase();
      final name = item.name.toLowerCase();
      return television
          ? type == 'tvshows' || name.contains('tv') || name.contains('show')
          : type == 'movies' || name.contains('movie') || name.contains('film');
    }).toList();
    final title = television ? 'TV' : 'Movies';
    if (items.isEmpty) {
      return _LibraryMessage(
        icon: television ? Icons.tv_off_outlined : Icons.movie_filter_outlined,
        title: 'No $title library found',
        message: 'Add a $title library in Jellyfin, then refresh Soup.',
        actionLabel: 'Refresh',
        onAction: _viewModel.load,
      );
    }
    return CustomScrollView(
      key: ValueKey('fruity-${title.toLowerCase()}'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
          sliver: SliverToBoxAdapter(
            child: Text(title, style: Theme.of(context).textTheme.displaySmall),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 230,
              crossAxisSpacing: 22,
              mainAxisSpacing: 22,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => FocusTraversalOrder(
              order: NumericFocusOrder(100 + index.toDouble()),
              child: _LibraryTile(
                item: items[index],
                image: _viewModel.image(items[index], maxWidth: 720),
                autofocus: index == 0,
                onPressed: () => _open(items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    return ListView(
      key: const ValueKey('fruity-settings'),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 56),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Signed in as ${widget.session.userName}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 36),
        Text('Appearance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        Text('Layout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        const _FruitySettingTile(),
        const SizedBox(height: 28),
        Text('Colour palette', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final palette in PaletteFamily.values)
              ChoiceChip(
                key: ValueKey('settings-palette-${palette.name}'),
                label: Text(_paletteLabel(palette)),
                avatar: CircleAvatar(backgroundColor: _paletteColor(palette)),
                selected: _appearanceDraft.palette == palette,
                onSelected: (_) => setState(
                  () => _appearanceDraft = _appearanceDraft.copyWith(
                    palette: palette,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Brightness', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<AppearanceBrightness>(
            segments: const [
              ButtonSegment(
                value: AppearanceBrightness.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: AppearanceBrightness.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {_appearanceDraft.brightness},
            onSelectionChanged: (selection) => setState(
              () => _appearanceDraft = _appearanceDraft.copyWith(
                brightness: selection.single,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            FilledButton.icon(
              key: const ValueKey('apply-appearance'),
              onPressed: widget.onSaveAppearance == null || _savingAppearance
                  ? null
                  : _saveAppearance,
              icon: _savingAppearance
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Apply appearance'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('refresh-library-button'),
              onPressed: _viewModel.loading ? null : _viewModel.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh library'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('library-sign-out-button'),
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Change server or account'),
            ),
          ],
        ),
      ],
    );
  }

  static String _paletteLabel(PaletteFamily palette) => switch (palette) {
    PaletteFamily.soup => 'Soup',
    PaletteFamily.ocean => 'Ocean',
    PaletteFamily.grove => 'Grove',
    PaletteFamily.mono => 'Mono',
  };

  static Color _paletteColor(PaletteFamily palette) => switch (palette) {
    PaletteFamily.soup => const Color(0xFFFC7814),
    PaletteFamily.ocean => const Color(0xFF1E88E5),
    PaletteFamily.grove => const Color(0xFF2E7D32),
    PaletteFamily.mono => const Color(0xFF6B7280),
  };
}

class _FruityTopNavigation extends StatelessWidget {
  const _FruityTopNavigation({
    required this.destination,
    required this.userName,
    required this.onSelected,
  });

  final _FruityDestination destination;
  final String userName;
  final ValueChanged<_FruityDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.78),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.soup_kitchen, color: colors.primary, size: 30),
            const SizedBox(width: 10),
            Text('Soup', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            _TopNavItem(
              key: const ValueKey('fruity-nav-home'),
              order: 1,
              selected: destination == _FruityDestination.home,
              tooltip: 'Home',
              onPressed: () => onSelected(_FruityDestination.home),
              child: const Icon(Icons.home_rounded),
            ),
            const SizedBox(width: 8),
            _TopNavItem(
              key: const ValueKey('fruity-nav-tv'),
              order: 2,
              selected: destination == _FruityDestination.tv,
              tooltip: 'TV',
              onPressed: () => onSelected(_FruityDestination.tv),
              child: const Text('TV'),
            ),
            const SizedBox(width: 8),
            _TopNavItem(
              key: const ValueKey('fruity-nav-movies'),
              order: 3,
              selected: destination == _FruityDestination.movies,
              tooltip: 'Movies',
              onPressed: () => onSelected(_FruityDestination.movies),
              child: const Text('Movies'),
            ),
            const SizedBox(width: 8),
            _TopNavItem(
              key: const ValueKey('fruity-nav-settings'),
              order: 4,
              selected: destination == _FruityDestination.settings,
              tooltip: 'Settings',
              onPressed: () => onSelected(_FruityDestination.settings),
              child: const Text('Settings'),
            ),
            const Spacer(),
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Text(
                userName.isEmpty
                    ? '?'
                    : userName.characters.first.toUpperCase(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopNavItem extends StatelessWidget {
  const _TopNavItem({
    required this.order,
    required this.selected,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final double order;
  final bool selected;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: Tooltip(
        message: tooltip,
        child: selected
            ? FilledButton.tonal(onPressed: onPressed, child: child)
            : TextButton(onPressed: onPressed, child: child),
      ),
    );
  }
}

class _FruityHero extends StatelessWidget {
  const _FruityHero({
    required this.item,
    required this.userName,
    required this.image,
    required this.onOpen,
  });

  final JellyfinItem item;
  final String userName;
  final Future<Uint8List?> image;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final theme = Theme.of(context);
    final tokens = theme.extension<AuthenticatedThemeTokens>();
    return SizedBox(
      height: wide ? 390 : 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: image,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) {
                return ColoredBox(color: theme.colorScheme.surfaceContainer);
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens?.heroScrimStart ?? Colors.transparent,
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.35),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 52 : 24, 24, 24, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.playbackPositionTicks > 0
                          ? 'UP NEXT FOR ${userName.toUpperCase()}'
                          : 'FEATURED FOR ${userName.toUpperCase()}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      key: const ValueKey('fruity-hero-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: wide
                          ? theme.textTheme.displayMedium
                          : theme.textTheme.headlineLarge,
                    ),
                    if (item.overview case final overview?) ...[
                      const SizedBox(height: 10),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const ValueKey('fruity-hero-open'),
                      autofocus: true,
                      onPressed: onOpen,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View details'),
                    ),
                  ],
                ),
              ),
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
    final phone = MediaQuery.sizeOf(context).width < 600;
    final width = landscape ? (phone ? 210.0 : 270.0) : (phone ? 140.0 : 166.0);
    final artHeight = landscape
        ? (phone ? 118.0 : 152.0)
        : (phone ? 196.0 : 232.0);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: phone ? 20 : 40),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: artHeight + 64,
              child: ListView.separated(
                key: ValueKey('library-row-${title.toLowerCase()}'),
                padding: EdgeInsets.symmetric(
                  horizontal: phone ? 20 : 40,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
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
                      image: image(item, maxWidth: landscape ? 720 : 480),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = theme.extension<AuthenticatedThemeTokens>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            scale: _focused && !reduceMotion ? 1.055 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  height: widget.artHeight,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _focused ? colors.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color:
                                  tokens?.focusGlow ??
                                  colors.primary.withValues(alpha: 0.3),
                              blurRadius: 22,
                              spreadRadius: 2,
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
                const SizedBox(height: 9),
                Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
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

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.image,
    required this.autofocus,
    required this.onPressed,
  });

  final JellyfinItem item;
  final Future<Uint8List?> image;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _MediaCard(
      item: item,
      width: double.infinity,
      artHeight: 166,
      image: image,
      autofocus: autofocus,
      onPressed: onPressed,
    );
  }
}

class _FruitySettingTile extends StatelessWidget {
  const _FruitySettingTile();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary, width: 2),
      ),
      child: const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.auto_awesome),
        title: Text('Fruity'),
        subtitle: Text('Spacious and cinematic'),
        trailing: Icon(Icons.check_circle),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
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
      ),
    );
  }
}
