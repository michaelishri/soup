import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/features/shared/fading_artwork.dart';

void main() {
  testWidgets('keeps the previous artwork while the next image cross-fades', (
    tester,
  ) async {
    final firstImage = Completer<CachedArtwork?>();
    final secondImage = Completer<CachedArtwork?>();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final directory = Directory.systemTemp.createTempSync(
      'soup-fading-artwork-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final firstFile = File('${directory.path}/first.png')
      ..writeAsBytesSync(png);
    final secondFile = File('${directory.path}/second.png')
      ..writeAsBytesSync(png);

    Widget build({
      required Object artworkKey,
      required Future<CachedArtwork?> image,
    }) {
      return MaterialApp(
        home: SizedBox.expand(
          child: FadingArtwork(
            artworkKey: artworkKey,
            image: image,
            placeholder: const ColoredBox(color: Colors.black),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      build(artworkKey: 'first', image: firstImage.future),
    );
    firstImage.complete(
      CachedArtwork(
        file: firstFile,
        variantKey: 'first',
        mimeType: 'image/png',
        variantWidth: 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);

    await tester.pumpWidget(
      build(artworkKey: 'second', image: secondImage.future),
    );

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsNothing);

    secondImage.complete(
      CachedArtwork(
        file: secondFile,
        variantKey: 'second',
        mimeType: 'image/png',
        variantWidth: 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('artwork-image-first')), findsNothing);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsOneWidget);
  });
}
