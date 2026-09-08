import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/shared/soup_mark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native launcher background matches the onboarding slate', () async {
    final xml = await File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsString();
    final value = RegExp(
      r'<color name="soup_icon_background">#([A-Fa-f0-9]{6})</color>',
    ).firstMatch(xml)?.group(1);
    expect(value, isNotNull);
    expect(
      Color(int.parse('FF$value', radix: 16)),
      SoupTheme.onboardingBackground,
    );
  });

  test('Flutter and Android use the same square generated artwork', () async {
    final data = await rootBundle.load(SoupMark.assetName);
    final bytes = data.buffer.asUint8List();
    final native = await File(
      'android/app/src/main/res/drawable-nodpi/soup_launcher_art.png',
    ).readAsBytes();
    final selected = await File(
      '../../docs/branding/concepts/soup-can-play-v2-campbells.png',
    ).readAsBytes();
    expect(listEquals(bytes, native), isTrue);
    expect(
      listEquals(bytes, selected),
      isTrue,
      reason: 'Production artwork must match the SOUP-89 selection',
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, frame.image.height);
      expect(frame.image.width, greaterThanOrEqualTo(1024));
      final pixels = await frame.image.toByteData();
      expect(
        pixels!.getUint8(3),
        255,
        reason: 'The badge is intentionally opaque',
      );
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  for (final size in [24.0, 40.0, 64.0]) {
    testWidgets('brand badge has correct bounds and no tint at $size', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SoupTheme.onboarding,
          home: Center(child: SoupMark(size: size)),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, const AssetImage(SoupMark.assetName));
      expect(image.color, isNull);
      expect(image.excludeFromSemantics, isTrue);
      expect(tester.getSize(find.byType(SoupMark)), Size.square(size));
      expect(tester.takeException(), isNull);
    });
  }
}
