import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/library/library_screen.dart';

void main() {
  final session = JellyfinSession(
    serverUrl: Uri.parse('http://jellyfin/'),
    serverId: 'server',
    userId: 'user',
    userName: 'Alex',
    accessToken: 'secret',
  );

  testWidgets('renders TV library rows and opens a focused item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    JellyfinItem? opened;
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [
          JellyfinItem(
            id: 'movies',
            name: 'Movies',
            type: 'CollectionFolder',
            collectionType: 'movies',
          ),
          JellyfinItem(
            id: 'shows',
            name: 'TV Shows',
            type: 'CollectionFolder',
            collectionType: 'tvshows',
          ),
        ],
        resume: [
          JellyfinItem(
            id: 'resume',
            name: 'Continue Me',
            type: 'Movie',
            playedPercentage: 42,
          ),
        ],
        latest: [JellyfinItem(id: 'latest', name: 'Newest', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
          onOpenItem: (item) => opened = item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.byKey(const ValueKey('fruity-nav-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('fruity-nav-tv')), findsOneWidget);
    expect(find.byKey(const ValueKey('fruity-nav-movies')), findsOneWidget);
    expect(find.byKey(const ValueKey('fruity-nav-settings')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(opened?.id, 'resume');

    await tester.tap(find.byKey(const ValueKey('fruity-nav-tv')));
    await tester.pump();
    expect(find.byKey(const ValueKey('fruity-tv')), findsOneWidget);
    expect(find.text('TV Shows'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fruity-nav-movies')));
    await tester.pump();
    expect(find.byKey(const ValueKey('fruity-movies')), findsOneWidget);
    expect(find.text('Movies'), findsWidgets);
  });

  testWidgets('renders an empty state and refreshes', (tester) async {
    final source = FakeLibrarySource(
      const JellyfinHome(libraries: [], resume: [], latest: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your library is empty'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(source.loads, 2);
  });

  testWidgets('renders an actionable error state', (tester) async {
    final source = FakeLibrarySource.error();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your library'), findsOneWidget);
    expect(find.text('Library unavailable for test.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('fits library navigation on a phone', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [],
        resume: [],
        latest: [JellyfinItem(id: 'movie', name: 'Phone Movie', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-home')), findsOneWidget);
    expect(find.text('Phone Movie'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies Fruity appearance changes from Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AppearanceSettings? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: FakeLibrarySource(
            const JellyfinHome(libraries: [], resume: [], latest: []),
          ),
          session: session,
          appearance: AppearanceSettings.defaults,
          onSaveAppearance: (value) async => saved = value,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fruity-nav-settings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-palette-ocean')));
    await tester.tap(find.text('Light'));
    await tester.tap(find.byKey(const ValueKey('apply-appearance')));
    await tester.pump();

    expect(saved?.preset, UiPreset.fruity);
    expect(saved?.palette, PaletteFamily.ocean);
    expect(saved?.brightness, AppearanceBrightness.light);
  });

  testWidgets('renders Blockbuster with a latest-first billboard and TV rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [],
        resume: [JellyfinItem(id: 'resume', name: 'Resume', type: 'Movie')],
        latest: [JellyfinItem(id: 'latest', name: 'Latest', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blockbuster-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('blockbuster-nav-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('blockbuster-brand-mark')), findsNothing);
    expect(
      find.byKey(const ValueKey('blockbuster-nav-search-icon')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('blockbuster-nav-search-icon')),
          )
          .icon,
      PhosphorIconsRegular.magnifyingGlass,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('blockbuster-nav-search-icon')),
          )
          .size,
      20,
    );
    expect(find.text('Search'), findsNothing);
    expect(find.text('Latest'), findsWidgets);
    expect(find.byKey(const ValueKey('fruity-nav-home')), findsNothing);

    final moreInfoSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('blockbuster-hero-more-info-surface')),
    );
    final moreInfoDecoration = moreInfoSurface.decoration! as BoxDecoration;
    expect(moreInfoDecoration.color, const Color(0xB36D6D6E));
    expect(moreInfoDecoration.border, isNull);

    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-rail'))).width,
      64,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('blockbuster-hero'))).dx,
      0,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('blockbuster-nav-items'))).dy,
      360,
    );
    final collapsedRail = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('blockbuster-rail')),
    );
    final collapsedGradient =
        (collapsedRail.decoration! as BoxDecoration).gradient!
            as LinearGradient;
    expect(collapsedGradient.colors.last.a, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-rail'))).width,
      300,
    );
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    final homeSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('blockbuster-nav-home-surface')),
    );
    expect(
      (homeSurface.decoration! as BoxDecoration).color,
      Colors.transparent,
    );
    expect(
      tester.widget<Text>(find.text('Home')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(tester.widget<Text>(find.text('Home')).style?.fontSize, 16);
    final homeIconScale = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('blockbuster-nav-home-icon-scale')),
    );
    expect(homeIconScale.scale, 1.12);
    expect(homeIconScale.duration, const Duration(milliseconds: 180));
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('blockbuster-nav-home-icon')))
          .icon,
      PhosphorIconsBold.house,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('blockbuster-nav-home-icon')))
          .size,
      20,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Search')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('blockbuster-nav-search-icon')),
          )
          .icon,
      PhosphorIconsBold.magnifyingGlass,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Home')).style?.fontWeight,
      FontWeight.w800,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Home')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      tester.widget<Text>(find.text('TV')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(tester.widget<Text>(find.text('TV')).style?.fontSize, 16);
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('blockbuster-nav-home-icon-scale')),
          )
          .scale,
      1,
    );
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('blockbuster-nav-tv-label-scale')),
          )
          .scale,
      1.1,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('blockbuster-nav-movies-label-opacity')),
          )
          .opacity,
      closeTo(0.6, 0.001),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-rail'))).width,
      64,
    );
    expect(find.text('Home'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-rail'))).width,
      300,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('blockbuster-nav-settings')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('blockbuster-nav-settings')));
    await tester.pump();
    expect(find.byKey(const ValueKey('blockbuster-settings')), findsOneWidget);
  });

  testWidgets('switches presets in place and keeps Settings selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var appearance = AppearanceSettings.defaults;
    final source = FakeLibrarySource(
      const JellyfinHome(libraries: [], resume: [], latest: []),
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: LibraryScreen(
            source: source,
            session: session,
            appearance: appearance,
            onSaveAppearance: (value) async {
              setState(() => appearance = value);
            },
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fruity-nav-settings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-layout-blockbuster')));
    await tester.tap(find.byKey(const ValueKey('apply-appearance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blockbuster-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('blockbuster-settings')), findsOneWidget);
  });

  testWidgets('restores the full Blockbuster hero when focus returns upward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [
          JellyfinItem(
            id: 'movies',
            name: 'Movies',
            type: 'CollectionFolder',
            collectionType: 'movies',
          ),
        ],
        resume: [JellyfinItem(id: 'resume', name: 'Resume', type: 'Movie')],
        latest: [JellyfinItem(id: 'latest', name: 'Latest', type: 'Movie')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: source,
          session: session,
          appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final homeScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('library-home')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    homeScroll.position.jumpTo(homeScroll.position.maxScrollExtent);
    await tester.pump();
    expect(homeScroll.position.pixels, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(homeScroll.position.pixels, 0);
  });

  testWidgets(
    'restores the Blockbuster latest-media rail inset when focus returns to its first card',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final latest = List.generate(
        10,
        (index) => JellyfinItem(
          id: 'latest-$index',
          name: 'Latest $index',
          type: 'Movie',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(
            source: FakeLibrarySource(
              JellyfinHome(
                libraries: const [],
                resume: const [],
                latest: latest,
              ),
            ),
            session: session,
            appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.byKey(const ValueKey('media-card-latest-0'));
      expect(tester.getTopLeft(firstCard).dx, 104);
      final latestRow = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('library-row-latest media')),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      for (var index = 0; index < 8; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(latestRow.position.pixels, greaterThan(0));

      for (var index = 0; index < 8; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }

      expect(latestRow.position.pixels, 0);
      expect(tester.getTopLeft(firstCard).dx, 104);
    },
  );

  testWidgets('disables Blockbuster rail focus motion when requested', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: LibraryScreen(
          source: FakeLibrarySource(
            const JellyfinHome(
              libraries: [],
              resume: [],
              latest: [
                JellyfinItem(id: 'latest', name: 'Latest', type: 'Movie'),
              ],
            ),
          ),
          session: session,
          appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    final iconScale = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('blockbuster-nav-home-icon-scale')),
    );
    expect(iconScale.scale, 1.12);
    expect(iconScale.duration, Duration.zero);
  });

  testWidgets('fits both presets at 1080p with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeLibrarySource(
      const JellyfinHome(
        libraries: [
          JellyfinItem(
            id: 'movies',
            name: 'Movies',
            type: 'CollectionFolder',
            collectionType: 'movies',
          ),
        ],
        resume: [JellyfinItem(id: 'resume', name: 'Resume', type: 'Movie')],
        latest: [JellyfinItem(id: 'latest', name: 'Latest', type: 'Movie')],
      ),
    );

    for (final preset in UiPreset.values) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: LibraryScreen(
            key: ValueKey('1080p-${preset.name}'),
            source: source,
            session: session,
            appearance: AppearanceSettings(preset: preset),
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('library-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class FakeLibrarySource implements JellyfinLibrarySource {
  FakeLibrarySource(this.home) : failure = null;

  FakeLibrarySource.error()
    : home = const JellyfinHome(libraries: [], resume: [], latest: []),
      failure = const JellyfinApiException('Library unavailable for test.');

  final JellyfinHome home;
  final JellyfinApiException? failure;
  int loads = 0;

  @override
  Future<JellyfinHome> getHome(JellyfinSession session) async {
    loads += 1;
    if (failure case final error?) throw error;
    return home;
  }

  @override
  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) async => null;
}
