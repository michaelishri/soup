import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/shared/adaptive_backdrop_contrast.dart';

void main() {
  test('uses a light foreground over a dark backdrop', () {
    final contrast = contrastForBackdropLuminances(List.filled(20, 0.03));

    expect(contrast.foreground, Colors.white);
    expect(contrast.scrim, Colors.black);
    expect(contrast.scrimOpacity, 0);
  });

  test('keeps light copy and adds a dark fade over a light backdrop', () {
    final contrast = contrastForBackdropLuminances(List.filled(20, 0.9));

    expect(contrast.foreground, Colors.white);
    expect(contrast.scrim, Colors.black);
    expect(contrast.scrimOpacity, greaterThan(0));
  });

  test(
    'adds a supporting scrim when a backdrop mixes light and dark areas',
    () {
      final contrast = contrastForBackdropLuminances([
        ...List.filled(8, 0.03),
        ...List.filled(12, 0.92),
      ]);

      expect(contrast.foreground, Colors.white);
      expect(contrast.scrim, Colors.black);
      expect(contrast.scrimOpacity, greaterThan(0));
    },
  );
}
