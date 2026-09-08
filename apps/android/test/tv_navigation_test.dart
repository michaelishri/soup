import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';

import 'package:soup/src/features/details/details_screen.dart';
import 'details_screen_test.dart' show FakeDetailsSource;

import 'library_screen_test.dart' show FakeLibrarySource;
import 'support/connectivity_fakes.dart';
import 'support/review_fonts.dart';
import 'widget_test.dart' show setup, nextToServer, FakeTvTextInput;

Finder keyed(String key) => find.byKey(ValueKey(key));

bool focused(Finder target) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var result = target.evaluate().contains(context);
  context.visitAncestorElements((element) {
    if (target.evaluate().contains(element)) result = true;
    return !result;
  });
  return result;
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  int count = 1,
]) async {
  for (var i = 0; i < count; i++) {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

Future<void> mountLibrary(
  WidgetTester tester, {
  required Size size,
  bool resume = false,
  bool empty = false,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  List<JellyfinItem> items(String prefix, String type, int count) =>
      List.generate(
        count,
        (i) => JellyfinItem(
          id: '$prefix-$i',
          name: '$prefix $i',
          type: type,
          overview:
              'A fixture story with a full hero and a long row to navigate.',
        ),
      );
  final movies = items('movie', 'Movie', 16);
  await tester.pumpWidget(
    MaterialApp(
      theme: SoupTheme.authenticated(AppearanceSettings.defaults),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => LibraryScreen(
          source: FakeLibrarySource(
            JellyfinHome(
              libraries: const [
                JellyfinItem(
                  id: 'movies',
                  name: 'Movies',
                  type: 'CollectionFolder',
                  collectionType: 'movies',
                ),
                JellyfinItem(
                  id: 'tv',
                  name: 'TV Shows',
                  type: 'CollectionFolder',
                  collectionType: 'tvshows',
                ),
              ],
              resume: resume ? items('resume', 'Movie', 12) : [],
              latest: empty ? [] : movies,
              recentlyAddedMovies: empty ? [] : movies,
              recentlyAddedTv: empty ? [] : items('tv', 'Series', 12),
            ),
          ),
          session: testSession,
          onSignOut: () async {},
          onSaveAppearance: (_) async {},
          onOpenItem: (item) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: FilledButton(
                  autofocus: true,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close ${item.id}'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFonts);
  for (final size in [const Size(960, 540), const Size(1280, 720)]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'Festival arrows restore hero, row insets and nav at $size reduced=$reduced',
        (tester) async {
          await mountLibrary(tester, size: size, reducedMotion: reduced);
          final hero = keyed('fruity-hero-open');
          final panel = keyed('festival-hero-panel');
          final originalHero = tester.getRect(panel);
          expect(focused(hero), isTrue);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(focused(keyed('media-card-movie-0')), isTrue);
          final originalLeft = tester
              .getTopLeft(keyed('media-card-movie-0'))
              .dx;
          await press(tester, LogicalKeyboardKey.arrowRight, 15);
          expect(focused(keyed('media-card-movie-15')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowRight, 2);
          expect(focused(keyed('media-card-movie-15')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowLeft, 15);
          expect(focused(keyed('media-card-movie-0')), isTrue);
          expect(
            tester.getTopLeft(keyed('media-card-movie-0')).dx,
            originalLeft,
          );
          await press(tester, LogicalKeyboardKey.arrowLeft);
          expect(focused(keyed('media-card-movie-0')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(focused(keyed('media-card-tv-0')), isTrue);
          final tvLeft = tester.getTopLeft(keyed('media-card-tv-0')).dx;
          await press(tester, LogicalKeyboardKey.arrowRight, 11);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(focused(keyed('media-card-tv-11')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowLeft, 11);
          expect(tester.getTopLeft(keyed('media-card-tv-0')).dx, tvLeft);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(focused(keyed('media-card-movie-0')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(focused(hero), isTrue);
          expect(tester.getRect(panel), originalHero);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(focused(keyed('fruity-nav-home')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowLeft);
          expect(focused(keyed('fruity-nav-home')), isTrue);
          for (final destination in ['tv', 'movies', 'settings', 'account']) {
            await press(tester, LogicalKeyboardKey.arrowRight);
            expect(focused(keyed('fruity-nav-$destination')), isTrue);
            await press(tester, LogicalKeyboardKey.arrowDown);
            expect(focused(hero), isTrue);
            expect(tester.getRect(panel), originalHero);
            await press(tester, LogicalKeyboardKey.arrowUp);
            // Up returns to the selected Home tab. Walk back to this stop.
            final steps = [
              'home',
              'tv',
              'movies',
              'settings',
              'account',
            ].indexOf(destination);
            await press(tester, LogicalKeyboardKey.arrowRight, steps);
          }
          await press(tester, LogicalKeyboardKey.arrowRight);
          expect(focused(keyed('fruity-nav-account')), isTrue);
          await press(tester, LogicalKeyboardKey.select);
          expect(keyed('fruity-settings'), findsOneWidget);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(focused(keyed('reset-appearance')), isTrue);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(focused(keyed('fruity-nav-settings')), isTrue);
        },
      );
    }
  }

  testWidgets('holding a remote direction keeps focus in its row', (
    tester,
  ) async {
    await mountLibrary(tester, size: const Size(960, 540));
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 11; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(keyed('media-card-movie-12')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowLeft, 12);
    expect(tester.getTopLeft(keyed('media-card-movie-0')).dx, 40);
  });

  testWidgets(
    'Continue Watching remembers each row and focus after closing details',
    (tester) async {
      await mountLibrary(tester, size: const Size(960, 540), resume: true);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(keyed('media-card-resume-0')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowRight, 7);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(keyed('media-card-movie-0')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowRight, 3);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(keyed('media-card-resume-7')), isTrue);
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('Close resume-7'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.select);
      expect(focused(keyed('media-card-resume-7')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(keyed('fruity-hero-open')), isTrue);
    },
  );

  testWidgets(
    'TV and Movies Down enters first library; Up returns to selected tab',
    (tester) async {
      await mountLibrary(tester, size: const Size(960, 540));
      await press(tester, LogicalKeyboardKey.arrowUp);
      for (final destination in ['tv', 'movies']) {
        await press(tester, LogicalKeyboardKey.arrowRight);
        await press(tester, LogicalKeyboardKey.select);
        expect(keyed('fruity-$destination'), findsOneWidget);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(focused(keyed('media-card-$destination')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(focused(keyed('fruity-nav-$destination')), isTrue);
      }
    },
  );

  testWidgets('empty Home remains reachable from every nav stop', (
    tester,
  ) async {
    await mountLibrary(tester, size: const Size(960, 540), empty: true);
    // No hero is available: enter the refresh action instead.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(
      focused(
        find.ancestor(
          of: find.text('Refresh'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      ),
      isTrue,
    );
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(keyed('fruity-nav-home')), isTrue);
  });

  for (final size in [const Size(960, 540), const Size(1030, 540)]) {
    testWidgets(
      'library details grid follows columns and holds its edges at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const library = JellyfinItem(
          id: 'library',
          name: 'Movies',
          type: 'CollectionFolder',
        );
        final items = List.generate(
          25,
          (index) => JellyfinItem(
            id: 'grid-$index',
            name: 'Movie $index',
            type: 'Movie',
          ),
        );
        final source = FakeDetailsSource(
          items: const {'library': library},
          libraryItems: items,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: SoupTheme.authenticated(AppearanceSettings.defaults),
            home: DetailsScreen(
              source: source,
              artworkSource: source,
              session: testSession,
              item: library,
              onPlay: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(focused(keyed('detail-card-grid-0')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(focused(keyed('detail-card-grid-1')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(focused(keyed('detail-card-grid-5')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(focused(keyed('detail-card-grid-1')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        expect(focused(keyed('detail-card-grid-0')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(focused(keyed('details-back-button')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(focused(keyed('detail-card-grid-0')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowRight, 3);
        expect(focused(keyed('detail-card-grid-3')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(focused(keyed('detail-card-grid-3')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowLeft, 3);
        await press(tester, LogicalKeyboardKey.arrowDown, 6);
        expect(focused(keyed('detail-card-grid-24')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(focused(keyed('detail-card-grid-24')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp, 6);
        expect(focused(keyed('detail-card-grid-0')), isTrue);
      },
    );
  }

  testWidgets('series seasons and episodes follow visible arrow directions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const series = JellyfinItem(
      id: 'series',
      name: 'Fixture Series',
      type: 'Series',
      overview: 'A series for remote navigation.',
    );
    final seasons = List.generate(
      3,
      (i) => JellyfinItem(id: 's$i', name: 'Season ${i + 1}', type: 'Season'),
    );
    final episodes = List.generate(
      5,
      (i) => JellyfinItem(id: 'e$i', name: 'Episode ${i + 1}', type: 'Episode'),
    );
    final source = FakeDetailsSource(
      items: const {'series': series},
      seasons: seasons,
      episodes: {for (final season in seasons) season.id: episodes},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoupTheme.authenticated(AppearanceSettings.defaults),
        home: DetailsScreen(
          source: source,
          artworkSource: source,
          session: testSession,
          item: series,
          onPlay: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(focused(keyed('season-s0')), isTrue);
    expect(tester.getRect(keyed('season-s0')).bottom, lessThanOrEqualTo(540));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(keyed('season-s1')), isTrue);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(keyed('episode-e0')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown, 4);
    expect(focused(keyed('episode-e4')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(keyed('episode-e4')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp, 4);
    expect(focused(keyed('episode-e0')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(
      ['s0', 's1', 's2'].any((id) => focused(keyed('season-$id'))),
      isTrue,
    );
  });

  testWidgets('Settings can be traversed to its final action and back to nav', (
    tester,
  ) async {
    await mountLibrary(tester, size: const Size(960, 540));
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowRight, 3);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 20 && !focused(keyed('library-sign-out-button')); i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focused(keyed('library-sign-out-button')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(keyed('library-sign-out-button')), isTrue);
    for (var i = 0; i < 20 && !focused(keyed('fruity-nav-settings')); i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focused(keyed('fruity-nav-settings')), isTrue);
  });

  for (final tv in [false, true]) {
    testWidgets('server protocol accepts bare and full addresses tv=$tv', (
      tester,
    ) async {
      final input = FakeTvTextInput();
      final factory = FakeJellyfinClientFactory();
      final (model, _) = await setup(
        tester,
        size: tv ? const Size(960, 540) : const Size(320, 640),
        factory: factory,
        tvTextInput: tv ? input : const TvTextInput(),
      );
      await nextToServer(tester);
      final field = keyed('server-url-field');
      final protocol = keyed('server-protocol-button');
      expect(keyed('paste-server-url-button'), findsNothing);
      expect(find.text('https://'), findsOneWidget);
      TextEditingController controller() => tv
          ? tester.widget<TvTextField>(field).controller
          : tester.widget<TextField>(field).controller!;
      Future<void> enter(String text) async {
        if (tv) {
          tester.widget<TvTextField>(field).focusNode.requestFocus();
          await tester.pump();
          await press(tester, LogicalKeyboardKey.select);
          input.complete(text, submitted: false);
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(field, text);
          await tester.pumpAndSettle();
        }
      }

      await enter('jellyfin.example.com/base');
      await tester.tap(keyed('check-server-button'));
      await tester.pumpAndSettle();
      expect(model.serverUrl.toString(), 'https://jellyfin.example.com/base/');
      await tester.tap(keyed('onboarding-back-button'));
      await tester.pumpAndSettle();
      await tester.tap(protocol);
      await enter('192.168.1.10:8096/jellyfin');
      await tester.tap(keyed('check-server-button'));
      await tester.pumpAndSettle();
      expect(model.serverUrl.toString(), 'http://192.168.1.10:8096/jellyfin/');
      await tester.tap(keyed('onboarding-back-button'));
      await tester.pumpAndSettle();
      await enter('  HTTPS://example.com:8920/base/');
      expect(controller().text, 'example.com:8920/base/');
      expect(find.text('https://'), findsOneWidget);
      expect(controller().selection.extentOffset, controller().text.length);
      await enter('http://[fd00::1]:8096/jellyfin');
      expect(find.text('http://'), findsOneWidget);
      expect(controller().text, '[fd00::1]:8096/jellyfin');
      if (tv) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
        expect(focused(protocol), isTrue);
        await press(tester, LogicalKeyboardKey.select);
        expect(find.text('https://'), findsOneWidget);
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(focused(field), isTrue);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(focused(keyed('check-server-button')), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(focused(field), isTrue);
      }
      await tester.tap(keyed('check-server-button'));
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.credentials);
      expect(model.serverUrl!.host, 'fd00::1');
      expect(tester.takeException(), isNull);
    });
  }
}
