import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'support/onboarding_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/library/library_screen.dart';

void main() {
  setUpAll(loadOnboardingFonts);
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
    expect(find.text('Recently Added Movies'), findsOneWidget);
    expect(find.text('Recently Added TV'), findsNothing);
    expect(find.text('Latest Media'), findsNothing);
    expect(find.text('My Media'), findsNothing);
    expect(find.byKey(const ValueKey('media-card-movies')), findsNothing);
    expect(find.byKey(const ValueKey('media-card-shows')), findsNothing);
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

    expect(find.text('No playlists yet'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(source.loads, 2);
  });

  testWidgets(
    'builds separate movie and TV playlists without library folders',
    (tester) async {
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
            JellyfinItem(
              id: 'shows',
              name: 'TV Shows',
              type: 'CollectionFolder',
              collectionType: 'tvshows',
            ),
          ],
          resume: [
            JellyfinItem(
              id: 'resume-library',
              name: 'Resume Library',
              type: 'CollectionFolder',
            ),
            JellyfinItem(
              id: 'resume-movie',
              name: 'Resume Movie',
              type: 'Movie',
            ),
          ],
          latest: [
            JellyfinItem(
              id: 'latest-library',
              name: 'Latest Library',
              type: 'CollectionFolder',
            ),
            JellyfinItem(
              id: 'latest-series',
              name: 'Latest Series',
              type: 'Series',
            ),
          ],
          recentlyAddedMovies: [
            JellyfinItem(
              id: 'latest-library',
              name: 'Latest Library',
              type: 'CollectionFolder',
            ),
            JellyfinItem(
              id: 'latest-movie',
              name: 'Latest Movie',
              type: 'Movie',
            ),
          ],
          recentlyAddedTv: [
            JellyfinItem(
              id: 'latest-series',
              name: 'Latest Series',
              type: 'Series',
            ),
            JellyfinItem(
              id: 'latest-episode',
              name: 'Latest Episode',
              type: 'Episode',
            ),
          ],
        ),
      );

      for (final preset in UiPreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: LibraryScreen(
              key: ValueKey('hidden-libraries-${preset.name}'),
              source: source,
              session: session,
              appearance: AppearanceSettings(preset: preset),
              onSignOut: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Media'), findsNothing);
        expect(find.text('Latest Media'), findsNothing);
        expect(find.text('Recently Added Movies'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('media-card-resume-library')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('media-card-latest-library')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('media-card-movies')), findsNothing);
        expect(find.byKey(const ValueKey('media-card-shows')), findsNothing);
        expect(
          find.byKey(const ValueKey('media-card-resume-movie')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('media-card-latest-movie')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('library-row-recently added movies')),
            matching: find.byKey(const ValueKey('media-card-latest-movie')),
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Recently Added TV'),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('library-home')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Recently Added TV'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('library-row-recently added tv')),
            matching: find.byKey(const ValueKey('media-card-latest-series')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('library-row-recently added tv')),
            matching: find.byKey(const ValueKey('media-card-latest-episode')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('library-row-recently added tv')),
            matching: find.byKey(const ValueKey('media-card-latest-movie')),
          ),
          findsNothing,
        );
      }
    },
  );

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

  testWidgets('renders Blockbuster with a latest-first billboard and rails', (
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
    expect(find.text('Favourites'), findsNothing);
    expect(find.text('Latest'), findsWidgets);
    expect(find.byKey(const ValueKey('fruity-nav-home')), findsNothing);
    expect(
      find.byKey(const ValueKey('blockbuster-playlist-rails')),
      findsOneWidget,
    );

    expect(find.text('More info'), findsNothing);
    expect(
      find.byKey(const ValueKey('blockbuster-hero-more-info-surface')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
      findsOneWidget,
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-rail'))).width,
      64,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('blockbuster-hero'))).dx,
      0,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('blockbuster-hero'))).height,
      720,
    );
    expect(
      tester.getTopLeft(find.text('Continue Watching')).dy,
      closeTo(620, 0.1),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('blockbuster-hero-focus-anchor')))
          .bottom,
      lessThan(tester.getTopLeft(find.text('Continue Watching')).dy),
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
    expect(find.text('Favourites'), findsOneWidget);
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
      tester.widget<Text>(find.text('Favourites')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('blockbuster-nav-favourites-icon')),
          )
          .icon,
      PhosphorIconsBold.heart,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Search')).style?.fontWeight,
      FontWeight.w800,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Favourites')).style?.fontWeight,
      FontWeight.w800,
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

  testWidgets(
    'restores the Blockbuster recently-added rail inset at its first card',
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

      final homeScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('library-home')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      homeScroll.position.jumpTo(homeScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final firstCard = find.byKey(const ValueKey('media-card-latest-0'));
      expect(tester.getTopLeft(firstCard).dx, 104);
      final latestRow = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey('library-row-recently added movies'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

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

  testWidgets(
    'cycles the latest five Blockbuster heroes and returns focus above playlists',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final latest = List.generate(
        6,
        (index) => JellyfinItem(
          id: 'hero-$index',
          name: 'Hero $index',
          type: index.isEven ? 'Movie' : 'Episode',
        ),
      );
      JellyfinItem? opened;

      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(
            source: FakeLibrarySource(
              JellyfinHome(
                libraries: const [],
                resume: const [
                  JellyfinItem(
                    id: 'resume',
                    name: 'Resume item',
                    type: 'Movie',
                  ),
                ],
                latest: latest,
              ),
            ),
            session: session,
            appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
            onSignOut: () async {},
            onOpenItem: (item) => opened = item,
          ),
        ),
      );
      await tester.pumpAndSettle();

      String heroTitle() => tester
          .widget<Text>(find.byKey(const ValueKey('fruity-hero-title')))
          .data!;

      expect(heroTitle(), 'Hero 0');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'blockbuster-hero-carousel',
      );
      expect(
        find.byKey(const ValueKey('blockbuster-hero-dots')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(opened?.id, 'hero-0');

      for (var index = 0; index < 5; index++) {
        expect(
          find.byKey(ValueKey('blockbuster-hero-dot-$index')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('blockbuster-hero-dot-5')),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(heroTitle(), 'Hero 1');
      expect(
        find.byKey(const ValueKey('blockbuster-background-hero-1')),
        findsOneWidget,
      );
      final selectedDot = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('blockbuster-hero-dot-1')),
      );
      expect(
        (selectedDot.decoration! as BoxDecoration).color,
        Colors.white.withValues(alpha: 0.82),
      );

      for (var index = 0; index < 4; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(heroTitle(), 'Hero 0');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(heroTitle(), 'Resume item');
      expect(find.byKey(const ValueKey('blockbuster-hero-dots')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(heroTitle(), 'Hero 0');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'blockbuster-hero-carousel',
      );
      expect(
        find.byKey(const ValueKey('blockbuster-hero-dots')),
        findsOneWidget,
      );
      final homeScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('library-home')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(homeScroll.position.pixels, 0);
    },
  );

  testWidgets('updates the fixed Blockbuster backdrop as card focus moves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: LibraryScreen(
          source: FakeLibrarySource(
            const JellyfinHome(
              libraries: [
                JellyfinItem(
                  id: 'movies',
                  name: 'Movies',
                  type: 'CollectionFolder',
                  collectionType: 'movies',
                ),
              ],
              resume: [
                JellyfinItem(
                  id: 'resume-0',
                  name: 'Resume 0',
                  type: 'Movie',
                  overview:
                      'The Eternals are a team of ancient aliens who have been living on Earth in secret for thousands of years. When an unexpected tragedy forces them out of the shadows, they reunite against mankind’s most ancient enemy.',
                ),
                JellyfinItem(
                  id: 'resume-1',
                  name: 'Resume 1',
                  type: 'Movie',
                  overview: 'Second resume overview',
                ),
              ],
              latest: [
                JellyfinItem(id: 'featured', name: 'Featured', type: 'Movie'),
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

    void expectFocusedRailClippedBelowHero() {
      final clipFinder = find.byKey(
        const ValueKey('blockbuster-focused-rail-clip'),
      );
      final fadeFinder = find.byKey(
        const ValueKey('blockbuster-focused-rail-fade'),
      );
      final clip = tester.widget<ClipRect>(clipFinder);
      final fade = tester.widget<ShaderMask>(fadeFinder);
      final clipBounds = clip.clipper!.getClip(tester.getSize(clipFinder));
      expect(fade.blendMode, BlendMode.dstIn);
      expect(
        clipBounds.top,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
              )
              .dy,
        ),
      );
    }

    void expectFocusedCardFits(String itemId) {
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getBottomLeft(find.byKey(ValueKey('media-card-$itemId'))).dy,
        lessThanOrEqualTo(viewportHeight - 8),
      );
    }

    expect(
      find.byKey(const ValueKey('blockbuster-background-featured')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('blockbuster-background-crossfade')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fruity-hero-title'))).data,
      'Featured',
    );
    expect(
      tester.getTopLeft(find.text('Recently Added Movies')).dy,
      greaterThan(
        tester
                .getBottomLeft(
                  find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
                )
                .dy +
            24,
      ),
    );
    final featuredTitleTop = tester
        .getTopLeft(find.byKey(const ValueKey('fruity-hero-title')))
        .dy;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blockbuster-background-resume-0')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fruity-hero-title'))).data,
      'Resume 0',
    );
    expect(
      find.textContaining('The Eternals are a team of ancient aliens'),
      findsOneWidget,
    );
    final heroTitleTop = tester
        .getTopLeft(find.byKey(const ValueKey('fruity-hero-title')))
        .dy;
    expect(heroTitleTop, lessThan(featuredTitleTop));
    expect(
      tester.getTopLeft(find.text('Continue Watching')).dy,
      greaterThan(
        tester
                .getBottomLeft(
                  find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
                )
                .dy +
            24,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('media-card-resume-0'))).dy,
      greaterThan(
        tester
                .getBottomLeft(
                  find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
                )
                .dy +
            24,
      ),
    );
    expectFocusedRailClippedBelowHero();
    expectFocusedCardFits('resume-0');
    final measuredClipTop = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('blockbuster-focused-rail-clip')),
        )
        .clipper!
        .getClip(
          tester.getSize(
            find.byKey(const ValueKey('blockbuster-focused-rail-clip')),
          ),
        )
        .top;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final transitioningClipTop = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('blockbuster-focused-rail-clip')),
        )
        .clipper!
        .getClip(
          tester.getSize(
            find.byKey(const ValueKey('blockbuster-focused-rail-clip')),
          ),
        )
        .top;
    expect(
      transitioningClipTop,
      measuredClipTop,
      reason: 'Card changes must retain the measured hero-safe boundary.',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blockbuster-background-resume-1')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fruity-hero-title'))).data,
      'Resume 1',
    );
    expect(find.text('Second resume overview'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('fruity-hero-title'))).dy,
      closeTo(heroTitleTop, 0.1),
    );
    final trailingCardFocus = FocusManager.instance.primaryFocus;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus,
      same(trailingCardFocus),
      reason: 'Right focus must stop at the final card in a playlist.',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fruity-hero-title'))).data,
      'Resume 1',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey('blockbuster-playlist-continue-watching'),
            ),
          )
          .opacity,
      0,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('fruity-hero-title'))).dy,
      closeTo(heroTitleTop, 0.1),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fruity-hero-title'))).data,
      'Featured',
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('media-card-featured'))).dy,
      greaterThan(
        tester
                .getBottomLeft(
                  find.byKey(const ValueKey('blockbuster-hero-focus-anchor')),
                )
                .dy +
            24,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('media-card-featured'))).dy,
      lessThan(460),
    );
    expectFocusedRailClippedBelowHero();
    expectFocusedCardFits('featured');

    expect(find.text('My Media'), findsNothing);
    expect(find.byKey(const ValueKey('media-card-movies')), findsNothing);
  });

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

  testWidgets('prefetches beyond horizontal and grid viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final artwork = FakeArtworkRepository();
    addTearDown(artwork.close);
    final latest = [
      for (var index = 0; index < 100; index++)
        JellyfinItem(
          id: 'latest-$index',
          name: 'Latest $index',
          type: 'Movie',
          primaryImageTag: 'primary-latest-$index',
        ),
    ];
    final libraries = [
      for (var index = 0; index < 100; index++)
        JellyfinItem(
          id: 'library-$index',
          name: 'Library $index',
          type: 'CollectionFolder',
          collectionType: 'movies',
          primaryImageTag: 'primary-library-$index',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: FakeLibrarySource(
            JellyfinHome(
              libraries: libraries,
              resume: const [],
              latest: latest,
            ),
          ),
          artworkRepository: artwork,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final builtHorizontal = [
      for (var index = 0; index < latest.length; index++)
        if (find
            .byKey(ValueKey('media-card-latest-$index'))
            .evaluate()
            .isNotEmpty)
          index,
    ];
    final lastHorizontal = builtHorizontal.last;
    expect(
      artwork.prefetches,
      contains('latest-${lastHorizontal + 1}:Primary:480'),
    );
    expect(
      artwork.prefetches,
      contains('latest-${lastHorizontal + 2}:Primary:480'),
    );

    artwork.prefetches.clear();
    await tester.tap(find.byKey(const ValueKey('fruity-nav-movies')));
    await tester.pumpAndSettle();
    final builtGrid = [
      for (var index = 0; index < libraries.length; index++)
        if (find
            .byKey(ValueKey('media-card-library-$index'))
            .evaluate()
            .isNotEmpty)
          index,
    ];
    final lastGrid = builtGrid.last;
    const gridColumns = 4;
    expect(
      artwork.prefetches,
      contains('library-${lastGrid + gridColumns}:Primary:720'),
    );
  });

  testWidgets('waits for stable rail focus before loading a backdrop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final artwork = FakeArtworkRepository();
    addTearDown(artwork.close);

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          source: FakeLibrarySource(
            const JellyfinHome(
              libraries: [],
              resume: [
                JellyfinItem(
                  id: 'resume-0',
                  name: 'Resume 0',
                  type: 'Movie',
                  backdropImageTag: 'backdrop-0',
                ),
                JellyfinItem(
                  id: 'resume-1',
                  name: 'Resume 1',
                  type: 'Movie',
                  backdropImageTag: 'backdrop-1',
                ),
              ],
              latest: [
                JellyfinItem(
                  id: 'featured',
                  name: 'Featured',
                  type: 'Movie',
                  backdropImageTag: 'backdrop-featured',
                ),
              ],
            ),
          ),
          artworkRepository: artwork,
          session: session,
          appearance: const AppearanceSettings(preset: UiPreset.blockbuster),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    artwork.visibleRequests.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 179));

    expect(
      artwork.visibleRequests.where(
        (request) => request.contains(':Backdrop:'),
      ),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      artwork.visibleRequests,
      contains('resume-1:Backdrop:$artworkBackdropWidth'),
    );
    expect(
      artwork.visibleRequests,
      isNot(contains('resume-0:Backdrop:$artworkBackdropWidth')),
    );
  });

  testWidgets('shows cache usage and confirms artwork-only clearing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final artwork = FakeArtworkRepository(usage: 64 * 1024 * 1024);
    addTearDown(artwork.close);

    await tester.pumpWidget(
      MaterialApp(
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
          artworkRepository: artwork,
          session: session,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fruity-nav-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('clear-artwork-cache')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('fruity-settings')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('64 MiB of 384 MiB used'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-artwork-cache')));
    await tester.pumpAndSettle();
    expect(find.text('Clear artwork cache?'), findsOneWidget);
    expect(
      find.textContaining('Library details and playback progress'),
      findsOneWidget,
    );
    expect(artwork.clearCalls, 0);

    await tester.tap(find.byKey(const ValueKey('confirm-clear-artwork-cache')));
    await tester.pumpAndSettle();
    expect(artwork.clearCalls, 1);
    expect(find.text('0.0 MiB of 384 MiB used'), findsOneWidget);
  });

  testWidgets('fits both presets at 1080p with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
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
          theme: SoupTheme.authenticated(AppearanceSettings(preset: preset)),
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

class FakeArtworkRepository implements ArtworkRepository {
  FakeArtworkRepository({this.usage = 0});

  final StreamController<int> _usageChanges = StreamController.broadcast();
  final List<String> visibleRequests = [];
  final List<String> prefetches = [];
  int usage;
  int clearCalls = 0;

  @override
  Future<CachedArtwork?> getArtwork(
    JellyfinItem item, {
    String type = 'Primary',
    int imageIndex = 0,
    int maxWidth = 480,
    ArtworkRequestPriority priority = ArtworkRequestPriority.visible,
  }) async {
    visibleRequests.add('${item.id}:$type:$maxWidth');
    return null;
  }

  @override
  void prefetch(
    JellyfinItem item, {
    String type = 'Primary',
    int imageIndex = 0,
    int maxWidth = 480,
  }) {
    prefetches.add('${item.id}:$type:$maxWidth');
  }

  @override
  Stream<int> watchUsageBytes() async* {
    yield usage;
    yield* _usageChanges.stream;
  }

  @override
  Future<int> usageBytes() async => usage;

  @override
  Future<void> clear() async {
    clearCalls++;
    usage = 0;
    _usageChanges.add(0);
  }

  Future<void> close() => _usageChanges.close();
}
