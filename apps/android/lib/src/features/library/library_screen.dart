import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/library/library_view_model.dart';

enum _FruityDestination { home, tv, movies, settings }

const _blockbusterContentInset = 104.0;

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
  final _blockbusterRailKey = GlobalKey<_BlockbusterRailState>();
  late final FocusScopeNode _blockbusterContentScopeNode;
  late final ScrollController _homeScrollController;
  late AppearanceSettings _appearanceDraft;
  _FruityDestination _destination = _FruityDestination.home;
  bool _savingAppearance = false;

  @override
  void initState() {
    super.initState();
    _blockbusterContentScopeNode = FocusScopeNode(
      debugLabel: 'blockbuster-content',
    );
    _homeScrollController = ScrollController(debugLabel: 'library-home-scroll');
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
    _homeScrollController.dispose();
    _blockbusterContentScopeNode.dispose();
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
    final blockbuster = widget.appearance.preset == UiPreset.blockbuster;
    final content = ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _content(),
    );
    return Scaffold(
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: blockbuster && wide
              ? Stack(
                  children: [
                    FocusScope(
                      node: _blockbusterContentScopeNode,
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: _handleBlockbusterContentKeyEvent,
                        child: content,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _BlockbusterRail(
                        key: _blockbusterRailKey,
                        destination: _destination,
                        onExit: _focusBlockbusterContent,
                        onSelected: (value) =>
                            setState(() => _destination = value),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    if (wide)
                      _FruityTopNavigation(
                        destination: _destination,
                        userName: widget.session.userName,
                        onSelected: (value) =>
                            setState(() => _destination = value),
                      ),
                    Expanded(child: content),
                  ],
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
                  key: ValueKey('mobile-nav-home'),
                  icon: Icon(PhosphorIconsRegular.house),
                  selectedIcon: Icon(PhosphorIconsFill.house),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.television),
                  selectedIcon: Icon(PhosphorIconsFill.television),
                  label: 'TV',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.filmSlate),
                  selectedIcon: Icon(PhosphorIconsFill.filmSlate),
                  label: 'Movies',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.gear),
                  selectedIcon: Icon(PhosphorIconsFill.gear),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  KeyEventResult _handleBlockbusterContentKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final moved =
        FocusManager.instance.primaryFocus?.focusInDirection(
          TraversalDirection.left,
        ) ??
        false;
    if (!moved) {
      _blockbusterRailKey.currentState?.focusSelectedDestination();
    }
    return KeyEventResult.handled;
  }

  void _focusBlockbusterContent() {
    _blockbusterContentScopeNode.requestFocus();
    _blockbusterContentScopeNode.nextFocus();
  }

  Widget _content() {
    if (_viewModel.loading && _viewModel.home == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.error case final error?) {
      return _LibraryMessage(
        icon: PhosphorIconsRegular.cloudSlash,
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
        icon: PhosphorIconsRegular.monitorPlay,
        title: 'Your library is empty',
        message: 'Add media in Jellyfin, then refresh this screen.',
        actionLabel: 'Refresh',
        onAction: _viewModel.load,
      );
    }
    final blockbuster = widget.appearance.preset == UiPreset.blockbuster;
    final hero = blockbuster
        ? home.latest.firstOrNull ?? home.resume.firstOrNull
        : home.resume.firstOrNull ?? home.latest.firstOrNull;
    return CustomScrollView(
      key: const ValueKey('library-home'),
      controller: _homeScrollController,
      slivers: [
        if (hero != null)
          SliverToBoxAdapter(
            child: _FruityHero(
              blockbuster: blockbuster,
              item: hero,
              userName: widget.session.userName,
              image: _viewModel.image(hero, type: 'Backdrop', maxWidth: 1600),
              onOpen: () => _open(hero),
              onHeroFocused: blockbuster ? _restoreFullHero : null,
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
            blockbuster: blockbuster,
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
            blockbuster: blockbuster,
            title: 'Latest Media',
            items: home.latest,
            image: _viewModel.image,
            onOpen: _open,
            autofocusFirst: home.resume.isEmpty && home.libraries.isEmpty,
            sectionOrder: 3,
          ),
        if (home.libraries.isNotEmpty)
          _LibrarySection(
            blockbuster: blockbuster,
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

  void _restoreFullHero() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_homeScrollController.hasClients) return;
      _homeScrollController.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _libraryDestination(JellyfinHome home, {required bool television}) {
    final blockbuster = widget.appearance.preset == UiPreset.blockbuster;
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
        icon: television
            ? PhosphorIconsRegular.television
            : PhosphorIconsRegular.filmStrip,
        title: 'No $title library found',
        message: 'Add a $title library in Jellyfin, then refresh Soup.',
        actionLabel: 'Refresh',
        onAction: _viewModel.load,
      );
    }
    return CustomScrollView(
      key: ValueKey(
        '${blockbuster ? 'blockbuster' : 'fruity'}-${title.toLowerCase()}',
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            blockbuster ? _blockbusterContentInset : 40,
            40,
            40,
            20,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(title, style: Theme.of(context).textTheme.displaySmall),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            blockbuster ? _blockbusterContentInset : 40,
            0,
            40,
            40,
          ),
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
                blockbuster: blockbuster,
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
    final blockbuster = widget.appearance.preset == UiPreset.blockbuster;
    return ListView(
      key: ValueKey('${blockbuster ? 'blockbuster' : 'fruity'}-settings'),
      padding: EdgeInsets.fromLTRB(
        blockbuster ? _blockbusterContentInset : 40,
        16,
        40,
        24,
      ),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          'Signed in as ${widget.session.userName}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Layout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _LayoutSettingTile(
              key: const ValueKey('settings-layout-fruity'),
              title: 'Fruity',
              subtitle: 'Spacious and cinematic',
              icon: PhosphorIconsRegular.sparkle,
              selected: _appearanceDraft.preset == UiPreset.fruity,
              onSelected: () => setState(
                () => _appearanceDraft = _appearanceDraft.copyWith(
                  preset: UiPreset.fruity,
                ),
              ),
            ),
            _LayoutSettingTile(
              key: const ValueKey('settings-layout-blockbuster'),
              title: 'Blockbuster',
              subtitle: 'Bold and browse-focused',
              icon: PhosphorIconsRegular.filmStrip,
              selected: _appearanceDraft.preset == UiPreset.blockbuster,
              onSelected: () => setState(
                () => _appearanceDraft = _appearanceDraft.copyWith(
                  preset: UiPreset.blockbuster,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Colour palette', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
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
        const SizedBox(height: 10),
        Text('Brightness', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<AppearanceBrightness>(
            segments: const [
              ButtonSegment(
                value: AppearanceBrightness.light,
                icon: Icon(PhosphorIconsRegular.sun),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: AppearanceBrightness.dark,
                icon: Icon(PhosphorIconsRegular.moon),
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
        const SizedBox(height: 12),
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
                  : const Icon(PhosphorIconsBold.check),
              label: const Text('Apply appearance'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('refresh-library-button'),
              onPressed: _viewModel.loading ? null : _viewModel.load,
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
              label: const Text('Refresh library'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('library-sign-out-button'),
              onPressed: widget.onSignOut,
              icon: const Icon(PhosphorIconsRegular.signOut),
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

class _BlockbusterRail extends StatefulWidget {
  const _BlockbusterRail({
    required this.destination,
    required this.onSelected,
    required this.onExit,
    super.key,
  });

  final _FruityDestination destination;
  final ValueChanged<_FruityDestination> onSelected;
  final VoidCallback onExit;

  @override
  State<_BlockbusterRail> createState() => _BlockbusterRailState();
}

class _BlockbusterRailState extends State<_BlockbusterRail> {
  late final FocusScopeNode _focusScopeNode;
  late final FocusNode _searchNode;
  late final Map<_FruityDestination, FocusNode> _destinationNodes;
  bool _expanded = false;
  bool _exitAfterCollapse = false;

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(debugLabel: 'blockbuster-navigation')
      ..addListener(_handleFocusChange);
    _searchNode = FocusNode(debugLabel: 'blockbuster-search');
    _destinationNodes = {
      for (final destination in _FruityDestination.values)
        destination: FocusNode(debugLabel: 'blockbuster-${destination.name}'),
    };
  }

  @override
  void dispose() {
    _focusScopeNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _searchNode.dispose();
    for (final node in _destinationNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleRailKeyEvent,
      child: FocusScope(
        node: _focusScopeNode,
        child: AnimatedContainer(
          key: const ValueKey('blockbuster-rail'),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          onEnd: _finishExitToContent,
          width: _expanded ? 300 : 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _expanded
                  ? [
                      Colors.black.withValues(alpha: 0.92),
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.36),
                      Colors.transparent,
                    ]
                  : [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
              stops: const [0, 0.18, 0.48, 0.75, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showLabels = constraints.maxWidth > 180;
              return Padding(
                padding: EdgeInsets.fromLTRB(8, 14, showLabels ? 72 : 8, 14),
                child: Center(
                  child: Column(
                    key: const ValueKey('blockbuster-nav-items'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BlockbusterRailItem(
                        key: const ValueKey('blockbuster-nav-search'),
                        order: 1,
                        icon: PhosphorIconsRegular.magnifyingGlass,
                        focusedIcon: PhosphorIconsBold.magnifyingGlass,
                        label: 'Search',
                        focusNode: _searchNode,
                        expanded: showLabels,
                        selected: false,
                        onPressed: () {},
                      ),
                      _BlockbusterRailItem(
                        key: const ValueKey('blockbuster-nav-home'),
                        order: 2,
                        icon: PhosphorIconsRegular.house,
                        focusedIcon: PhosphorIconsBold.house,
                        label: 'Home',
                        focusNode: _destinationNodes[_FruityDestination.home]!,
                        expanded: showLabels,
                        selected: widget.destination == _FruityDestination.home,
                        onPressed: () =>
                            widget.onSelected(_FruityDestination.home),
                      ),
                      _BlockbusterRailItem(
                        key: const ValueKey('blockbuster-nav-tv'),
                        order: 3,
                        icon: PhosphorIconsRegular.television,
                        focusedIcon: PhosphorIconsBold.television,
                        label: 'TV',
                        focusNode: _destinationNodes[_FruityDestination.tv]!,
                        expanded: showLabels,
                        selected: widget.destination == _FruityDestination.tv,
                        onPressed: () =>
                            widget.onSelected(_FruityDestination.tv),
                      ),
                      _BlockbusterRailItem(
                        key: const ValueKey('blockbuster-nav-movies'),
                        order: 4,
                        icon: PhosphorIconsRegular.filmSlate,
                        focusedIcon: PhosphorIconsBold.filmSlate,
                        label: 'Movies',
                        focusNode:
                            _destinationNodes[_FruityDestination.movies]!,
                        expanded: showLabels,
                        selected:
                            widget.destination == _FruityDestination.movies,
                        onPressed: () =>
                            widget.onSelected(_FruityDestination.movies),
                      ),
                      _BlockbusterRailItem(
                        key: const ValueKey('blockbuster-nav-settings'),
                        order: 5,
                        icon: PhosphorIconsRegular.gear,
                        focusedIcon: PhosphorIconsBold.gear,
                        label: 'Settings',
                        focusNode:
                            _destinationNodes[_FruityDestination.settings]!,
                        expanded: showLabels,
                        selected:
                            widget.destination == _FruityDestination.settings,
                        onPressed: () =>
                            widget.onSelected(_FruityDestination.settings),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleRailKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowRight ||
        !_expanded) {
      return KeyEventResult.ignored;
    }
    _exitAfterCollapse = true;
    setState(() => _expanded = false);
    return KeyEventResult.handled;
  }

  void _finishExitToContent() {
    if (!_exitAfterCollapse || _expanded) return;
    _exitAfterCollapse = false;
    widget.onExit();
  }

  void _handleFocusChange() {
    final expanded = _focusScopeNode.hasFocus;
    if (mounted && expanded != _expanded) {
      setState(() => _expanded = expanded);
    }
  }

  void focusSelectedDestination() {
    _destinationNodes[widget.destination]?.requestFocus();
  }
}

class _BlockbusterRailItem extends StatefulWidget {
  const _BlockbusterRailItem({
    required this.order,
    required this.icon,
    required this.focusedIcon,
    required this.label,
    required this.focusNode,
    required this.expanded,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final double order;
  final IconData icon;
  final IconData focusedIcon;
  final String label;
  final FocusNode focusNode;
  final bool expanded;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_BlockbusterRailItem> createState() => _BlockbusterRailItemState();
}

class _BlockbusterRailItemState extends State<_BlockbusterRailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final focusDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final focusCurve = _focused ? Curves.easeOutBack : Curves.easeOutCubic;
    final inactiveOpacity = widget.selected ? 0.82 : 0.6;
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          onFocusChange: (focused) => setState(() => _focused = focused),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: AnimatedContainer(
                key: ValueKey(
                  'blockbuster-nav-${widget.label.toLowerCase()}-surface',
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                height: 44,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.expanded ? 12 : 2,
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Row(
                  mainAxisAlignment: widget.expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 3,
                      height: widget.selected ? 24 : 0,
                      color: colors.primary,
                    ),
                    SizedBox(width: widget.expanded ? 12 : 4),
                    AnimatedOpacity(
                      key: ValueKey(
                        'blockbuster-nav-${widget.label.toLowerCase()}-opacity',
                      ),
                      duration: focusDuration,
                      curve: Curves.easeOutCubic,
                      opacity: _focused ? 1 : inactiveOpacity,
                      child: AnimatedScale(
                        key: ValueKey(
                          'blockbuster-nav-${widget.label.toLowerCase()}-icon-scale',
                        ),
                        duration: focusDuration,
                        curve: focusCurve,
                        scale: _focused ? 1.12 : 1,
                        child: Icon(
                          _focused ? widget.focusedIcon : widget.icon,
                          key: ValueKey(
                            'blockbuster-nav-${widget.label.toLowerCase()}-icon',
                          ),
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.expanded) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedOpacity(
                          key: ValueKey(
                            'blockbuster-nav-${widget.label.toLowerCase()}-label-opacity',
                          ),
                          duration: focusDuration,
                          curve: Curves.easeOutCubic,
                          opacity: _focused ? 1 : inactiveOpacity,
                          child: AnimatedScale(
                            key: ValueKey(
                              'blockbuster-nav-${widget.label.toLowerCase()}-label-scale',
                            ),
                            alignment: Alignment.centerLeft,
                            duration: focusDuration,
                            curve: focusCurve,
                            scale: _focused ? 1.1 : 1,
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: _focused
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
            Icon(
              PhosphorIconsRegular.cookingPot,
              color: colors.primary,
              size: 30,
            ),
            const SizedBox(width: 10),
            Text('Soup', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            _TopNavItem(
              key: const ValueKey('fruity-nav-home'),
              order: 1,
              selected: destination == _FruityDestination.home,
              tooltip: 'Home',
              onPressed: () => onSelected(_FruityDestination.home),
              child: const Icon(PhosphorIconsRegular.house),
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

class _TopNavItem extends StatefulWidget {
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
  State<_TopNavItem> createState() => _TopNavItemState();
}

class _TopNavItemState extends State<_TopNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Tooltip(
        message: widget.tooltip,
        child: FocusableActionDetector(
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.tooltip,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                constraints: const BoxConstraints(minWidth: 56, minHeight: 50),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _focused
                      ? colors.primary
                      : widget.selected
                      ? colors.primaryContainer.withValues(alpha: 0.72)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _focused
                        ? colors.onPrimary
                        : widget.selected
                        ? colors.primary
                        : Colors.transparent,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: _focused ? colors.onPrimary : null,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: _focused ? colors.onPrimary : null,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FruityHero extends StatelessWidget {
  const _FruityHero({
    required this.blockbuster,
    required this.item,
    required this.userName,
    required this.image,
    required this.onOpen,
    this.onHeroFocused,
  });

  final bool blockbuster;
  final JellyfinItem item;
  final String userName;
  final Future<Uint8List?> image;
  final VoidCallback onOpen;
  final VoidCallback? onHeroFocused;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final theme = Theme.of(context);
    final tokens = theme.extension<AuthenticatedThemeTokens>();
    return SizedBox(
      key: ValueKey('${blockbuster ? 'blockbuster' : 'fruity'}-hero'),
      height: wide ? 300 : 330,
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
                begin: blockbuster
                    ? Alignment.centerRight
                    : Alignment.topCenter,
                end: blockbuster
                    ? Alignment.centerLeft
                    : Alignment.bottomCenter,
                colors: blockbuster
                    ? [
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.1),
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.58),
                      ]
                    : [
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
              padding: EdgeInsets.fromLTRB(
                blockbuster && wide
                    ? _blockbusterContentInset
                    : (wide ? 44 : 24),
                24,
                24,
                30,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.playbackPositionTicks > 0
                          ? '${blockbuster ? 'CONTINUE WATCHING' : 'UP NEXT'} FOR ${userName.toUpperCase()}'
                          : '${blockbuster ? 'NOW SHOWING' : 'FEATURED'} FOR ${userName.toUpperCase()}',
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
                          ? theme.textTheme.displaySmall
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
                    if (blockbuster)
                      _BlockbusterHeroAction(
                        key: const ValueKey('fruity-hero-open'),
                        onPressed: onOpen,
                        onFocused: onHeroFocused,
                      )
                    else
                      FilledButton.icon(
                        key: const ValueKey('fruity-hero-open'),
                        autofocus: true,
                        onPressed: onOpen,
                        icon: const Icon(PhosphorIconsRegular.info),
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

class _BlockbusterHeroAction extends StatefulWidget {
  const _BlockbusterHeroAction({
    required this.onPressed,
    this.onFocused,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback? onFocused;

  @override
  State<_BlockbusterHeroAction> createState() => _BlockbusterHeroActionState();
}

class _BlockbusterHeroActionState extends State<_BlockbusterHeroAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return FocusableActionDetector(
      autofocus: true,
      onFocusChange: (focused) {
        if (focused) widget.onFocused?.call();
      },
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: 'More info',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            key: const ValueKey('blockbuster-hero-more-info-surface'),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: _focused ? Colors.white : const Color(0xB36D6D6E),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsRegular.info,
                  size: 20,
                  color: _focused ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 9),
                Text(
                  'More info',
                  style: TextStyle(
                    color: _focused ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
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

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.blockbuster,
    required this.title,
    required this.items,
    required this.image,
    required this.onOpen,
    required this.autofocusFirst,
    required this.sectionOrder,
    this.landscape = false,
  });

  final bool blockbuster;
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
    final width = landscape
        ? (phone ? 210.0 : (blockbuster ? 240.0 : 270.0))
        : (phone ? 140.0 : (blockbuster ? 148.0 : 166.0));
    final artHeight = landscape
        ? (phone ? 118.0 : (blockbuster ? 135.0 : 152.0))
        : (phone ? 196.0 : (blockbuster ? 207.0 : 232.0));
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                blockbuster && !phone
                    ? _blockbusterContentInset
                    : (phone ? 20 : 40),
                0,
                phone ? 20 : 40,
                0,
              ),
              child: Text(
                title,
                style: blockbuster
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      )
                    : Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: artHeight + 64,
              child: _BlockbusterHorizontalCardRow(
                key: ValueKey('library-row-${title.toLowerCase()}'),
                restoreLeadingInset: blockbuster && !phone,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FocusTraversalOrder(
                    order: NumericFocusOrder(
                      sectionOrder * 100 + index.toDouble(),
                    ),
                    child: _MediaCard(
                      blockbuster: blockbuster,
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

class _BlockbusterHorizontalCardRow extends StatelessWidget {
  const _BlockbusterHorizontalCardRow({
    required this.restoreLeadingInset,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final bool restoreLeadingInset;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  void _restoreLeadingInset(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      if (position == null ||
          !position.hasPixels ||
          position.pixels <= position.minScrollExtent) {
        return;
      }
      position.animateTo(
        position.minScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        restoreLeadingInset ? _blockbusterContentInset : (phone ? 20 : 40),
        6,
        phone ? 20 : 40,
        6,
      ),
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        final child = itemBuilder(context, index);
        if (index != 0 || !restoreLeadingInset) return child;
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (focused) _restoreLeadingInset(context);
          },
          child: child,
        );
      },
    );
  }
}

class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.blockbuster,
    required this.item,
    required this.width,
    required this.artHeight,
    required this.image,
    required this.autofocus,
    required this.onPressed,
    super.key,
  });

  final bool blockbuster;
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
            scale: _focused && !reduceMotion
                ? (widget.blockbuster ? 1.035 : 1.055)
                : 1,
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
                    borderRadius: BorderRadius.circular(
                      widget.blockbuster ? 2 : 16,
                    ),
                    border: Border.all(
                      color: _focused
                          ? (widget.blockbuster ? Colors.white : colors.primary)
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: _focused && !widget.blockbuster
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
                              ? PhosphorIconsRegular.monitorPlay
                              : PhosphorIconsRegular.filmSlate,
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
    required this.blockbuster,
    required this.item,
    required this.image,
    required this.autofocus,
    required this.onPressed,
  });

  final bool blockbuster;
  final JellyfinItem item;
  final Future<Uint8List?> image;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _MediaCard(
      blockbuster: blockbuster,
      item: item,
      width: double.infinity,
      artHeight: 166,
      image: image,
      autofocus: autofocus,
      onPressed: onPressed,
    );
  }
}

class _LayoutSettingTile extends StatelessWidget {
  const _LayoutSettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          minVerticalPadding: 0,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: selected ? const Icon(PhosphorIconsFill.checkCircle) : null,
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
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
