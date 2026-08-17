import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/shared/fading_artwork.dart';

void main() {
  testWidgets('keeps the previous artwork while the next image cross-fades', (
    tester,
  ) async {
    final firstImage = Completer<Uint8List?>();
    final secondImage = Completer<Uint8List?>();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    Widget build({
      required Object artworkKey,
      required Future<Uint8List?> image,
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
    firstImage.complete(png);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);

    await tester.pumpWidget(
      build(artworkKey: 'second', image: secondImage.future),
    );

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsNothing);

    secondImage.complete(png);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byKey(const ValueKey('artwork-image-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('artwork-image-first')), findsNothing);
    expect(find.byKey(const ValueKey('artwork-image-second')), findsOneWidget);
  });
}
