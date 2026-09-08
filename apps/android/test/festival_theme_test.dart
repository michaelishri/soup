import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/details/details_screen.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/shared/soup_mark.dart';

import 'details_screen_test.dart' show FakeDetailsSource;
import 'library_screen_test.dart' show FakeLibrarySource, FakeArtworkRepository;
import 'support/review_fonts.dart';

const _capture = bool.fromEnvironment('UPDATE_FESTIVAL_SCREENSHOTS');
const _movie = JellyfinItem(
  id: 'night-train',
  name: 'The Night Train',
  type: 'Movie',
  overview:
      'One last train. A city full of stories. An unexpected journey home.',
  productionYear: 2026,
  officialRating: 'PG',
  runTimeTicks: 57600000000,
  playbackPositionTicks: 18000000000,
  playedPercentage: 31,
);
const _latest = [
  JellyfinItem(id: 'after-hours', name: 'After Hours', type: 'Movie'),
  JellyfinItem(id: 'blue-hour', name: 'Blue Hour', type: 'Movie'),
  JellyfinItem(id: 'the-crossing', name: 'The Crossing', type: 'Movie'),
  JellyfinItem(id: 'summer-radio', name: 'Summer Radio', type: 'Movie'),
];

void main() {
  setUpAll(loadReviewFonts);
  final session = JellyfinSession(
    serverUrl: Uri.parse('http://fixture.invalid/'),
    serverId: 'fixture',
    userId: 'fixture-user',
    userName: 'Alex',
    accessToken: 'fixture-only',
  );
  for (final brightness in AppearanceBrightness.values) {
    for (final (label, size, scale) in [
      ('tv', const Size(960, 540), 1.0),
      ('phone', const Size(412, 915), 1.0),
      ('small-large-text', const Size(320, 640), 1.3),
    ]) {
      testWidgets(
        'Festival ${brightness.name} $label browses and saves appearance',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final artwork = _ReviewArtwork();
          addTearDown(artwork.close);
          if (_capture) {
            await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
            final context = tester.element(find.byType(SizedBox).first);
            await tester.runAsync(() async {
              await artwork.prepare();
              for (final file in artwork.files.values) {
                for (final width in [
                  140,
                  166,
                  190,
                  210,
                  250,
                  270,
                  280,
                  320,
                  372,
                  412,
                  414,
                  960,
                  1280,
                ]) {
                  await precacheImage(
                    ResizeImage(FileImage(file), width: width),
                    context,
                  );
                }
              }
            });
          }
          var settings = AppearanceSettings(brightness: brightness);
          final source = FakeLibrarySource(
            const JellyfinHome(
              libraries: [],
              resume: [_movie],
              latest: _latest,
            ),
          );
          final details = FakeDetailsSource(
            items: const {'night-train': _movie},
          );
          Future<void> mount() => tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('festival-capture'),
              child: StatefulBuilder(
                builder: (context, rebuild) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: SoupTheme.authenticated(settings),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => LibraryScreen(
                      source: source,
                      artworkRepository: artwork,
                      session: session,
                      appearance: settings,
                      onSignOut: () async {},
                      onSaveAppearance: (value) async =>
                          rebuild(() => settings = value),
                      onOpenItem: (item) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetailsScreen(
                            source: details,
                            artworkSource: details,
                            artworkRepository: artwork,
                            session: session,
                            item: item,
                            onPlay: (_, _) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (_capture) {
            await tester.runAsync(mount);
          } else {
            await mount();
          }
          await tester.pumpAndSettle();
          if (_capture) {
            await tester.runAsync(() async {
              final context = tester.element(find.byType(LibraryScreen));
              await precacheImage(
                const AssetImage(SoupMark.assetName),
                context,
              );
              for (final file in artwork.files.values) {
                await precacheImage(FileImage(file), context);
              }
            });
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('festival-hero-panel')),
            findsOneWidget,
          );
          Future<void> capture(String page) async {
            if (!_capture || scale != 1) return;
            // File decoding crosses real I/O and the test's fake frame clock.
            // Drain both before capturing the production Image.file widgets.
            for (var frame = 0; frame < 3; frame++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pumpAndSettle();
            }
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('festival-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../../docs/screenshots/festival/$page-${brightness.name}-$label.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('home');
          final action = find.byKey(const ValueKey('fruity-hero-open'));
          await tester.ensureVisible(action);
          if (label == 'tv') {
            expect(Focus.of(tester.element(action)).hasFocus, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.select);
          } else {
            await tester.tap(action);
          }
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('festival-details-title')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await capture('details');
          Navigator.of(tester.element(find.byType(DetailsScreen))).pop();
          await tester.pumpAndSettle();
          final settingsNav = label == 'tv'
              ? find.byKey(const ValueKey('fruity-nav-settings'))
              : find.text('Settings');
          await tester.tap(settingsNav);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture('settings');
          Future<void> reveal(Finder target) => tester.scrollUntilVisible(
            target,
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('fruity-settings')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final palette = find.byKey(
            const ValueKey('settings-palette-festival'),
          );
          await reveal(palette);
          expect(tester.widget<ChoiceChip>(palette).selected, isTrue);
          final darkChoice = find.text('Dark');
          await reveal(darkChoice);
          await tester.tap(darkChoice);
          final apply = find.byKey(const ValueKey('apply-appearance'));
          await reveal(apply);
          await tester.pumpAndSettle();
          if (label == 'tv') {
            tester.widget<FilledButton>(apply).focusNode!.requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.select);
          } else {
            await tester.tap(apply);
          }
          await tester.pumpAndSettle();
          if (label == 'tv') {
            expect(
              tester.widget<FilledButton>(apply).focusNode!.hasFocus,
              isTrue,
            );
            expect(apply.hitTestable(), findsOneWidget);
          }
          expect(settings.brightness, AppearanceBrightness.dark);
          expect(settings.palette, PaletteFamily.festival);
          expect(find.byKey(const ValueKey('fruity-settings')), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Let the previous save confirmation leave before editing again.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          final reset = find.byKey(const ValueKey('reset-appearance'));
          await tester.scrollUntilVisible(
            reset,
            -160,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('fruity-settings')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(reset);
          await tester.pumpAndSettle();
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(
            settings.brightness,
            AppearanceBrightness.dark,
            reason: 'Use default edits the draft until Apply is selected.',
          );
          await reveal(apply);
          await tester.pumpAndSettle();
          if (label == 'tv') {
            tester.widget<FilledButton>(apply).focusNode!.requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.select);
          } else {
            await tester.tap(apply);
          }
          await tester.pumpAndSettle();
          expect(settings, AppearanceSettings.defaults);
          expect(find.byKey(const ValueKey('fruity-settings')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

/// Original geometric artwork for reproducible review captures; no film images
/// or user library data are downloaded. The same PNGs can feed native TV tests.
class _ReviewArtwork extends FakeArtworkRepository {
  final files = <String, File>{};

  Future<void> prepare() async {
    final folder = Directory('/tmp/soup-festival-artwork');
    await folder.create(recursive: true);
    const colors = [
      Color(0xFF16333E),
      Color(0xFF652B46),
      Color(0xFF173F7A),
      Color(0xFF3B5141),
      Color(0xFFAE593D),
    ];
    final items = [_movie, ..._latest];
    for (var index = 0; index < items.length; index++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = colors[index];
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1280, 720), paint);
      paint.color = const Color(0xFFEDD9A8);
      canvas.drawCircle(Offset(820 - index * 60, 210), 100, paint);
      paint.color = const Color(0xFF0D202C);
      for (var i = 0; i < 10; i++) {
        canvas.drawRect(
          Rect.fromLTWH(i * 150, 330 + (i % 3) * 55, 120, 390),
          paint,
        );
      }
      paint.color = const Color(0xFF88B2B8);
      for (var i = 0; i < 24; i++) {
        canvas.drawRect(Rect.fromLTWH(i * 60, 540, 24, 6), paint);
      }
      final text = TextPainter(
        text: TextSpan(
          text: items[index].name.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            color: Color(0xFFF5F3EB),
            fontSize: 64,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1050);
      text.paint(canvas, const Offset(64, 610));
      text.dispose();
      final picture = recorder.endRecording();
      final image = await picture.toImage(1280, 720);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${folder.path}/${items[index].id}.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      files[items[index].id] = file;
      image.dispose();
      picture.dispose();
    }
  }

  @override
  Future<CachedArtwork?> getArtwork(
    JellyfinItem item, {
    String type = 'Primary',
    int imageIndex = 0,
    int maxWidth = 480,
    ArtworkRequestPriority priority = ArtworkRequestPriority.visible,
  }) async {
    final file = files[item.id];
    return file == null
        ? null
        : CachedArtwork(
            file: file,
            variantKey: item.id,
            mimeType: 'image/png',
            variantWidth: 1280,
          );
  }
}
