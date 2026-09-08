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

  test('native launcher background matches the onboarding canvas', () async {
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

  test('native editor text retains contrast on its light canvas', () async {
    final xml = await File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsString();
    final style = RegExp(
      r'<style name="TvTextInputTheme"[\s\S]*?</style>',
    ).firstMatch(xml)!.group(0)!;
    final background = SoupTheme.onboardingBackground.computeLuminance();
    for (final attribute in [
      'textColorPrimary',
      'textColorSecondary',
      'textColorHint',
    ]) {
      final hex = RegExp(
        '<item name="android:$attribute">#([A-Fa-f0-9]{6})</item>',
      ).firstMatch(style)?.group(1);
      expect(
        hex,
        isNotNull,
        reason: 'TV theme defaults can supply white text on a light canvas',
      );
      final foreground = Color(
        int.parse('FF$hex', radix: 16),
      ).computeLuminance();
      expect(
        (background + 0.05) / (foreground + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: attribute,
      );
    }
  });

  test('Flutter and Android use the same transparent can artwork', () async {
    final data = await rootBundle.load(SoupMark.assetName);
    final bytes = data.buffer.asUint8List();
    final native = await File(
      'android/app/src/main/res/drawable-nodpi/soup_launcher_art.png',
    ).readAsBytes();
    final selected = await File(
      '../../docs/branding/concepts/soup-can-play-transparent.png',
    ).readAsBytes();
    expect(listEquals(bytes, native), isTrue);
    expect(
      listEquals(bytes, selected),
      isTrue,
      reason: 'Production artwork must match the SOUP-92 transparent master',
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, frame.image.height);
      expect(frame.image.width, greaterThanOrEqualTo(1024));
      final pixels = await frame.image.toByteData();
      final width = frame.image.width;
      final height = frame.image.height;
      int alpha(int x, int y) => pixels!.getUint8((y * width + x) * 4 + 3);
      for (var i = 0; i < width; i++) {
        expect(alpha(i, 0), 0);
        expect(alpha(i, height - 1), 0);
        expect(alpha(0, i), 0);
        expect(alpha(width - 1, i), 0);
      }
      expect(
        alpha(width ~/ 2, height ~/ 2),
        255,
        reason: 'Background removal must preserve the dark play symbol',
      );
      var visible = 0;
      for (var offset = 3; offset < pixels!.lengthInBytes; offset += 4) {
        if (pixels.getUint8(offset) > 0) visible++;
      }
      expect(visible / (width * height), inInclusiveRange(0.45, 0.65));
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  for (final size in [24.0, 40.0, 64.0]) {
    testWidgets('brand mark has correct bounds and no tint at $size', (
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
