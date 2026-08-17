import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/shared/artwork_placeholder.dart';

void main() {
  testWidgets('uses standard BlurHash decoding for a valid placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: ArtworkPlaceholder(blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
        ),
      ),
    );

    final placeholder = tester.widget<BlurHash>(find.byType(BlurHash));
    expect(placeholder.optimizationMode, BlurHashOptimizationMode.standard);
    expect(
      find.byKey(const ValueKey('artwork-placeholder-blurhash')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to the surface placeholder for an invalid hash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: ArtworkPlaceholder(
            blurHash: 'not-a-valid-hash',
            fallback: Icon(Icons.movie),
          ),
        ),
      ),
    );

    expect(find.byType(BlurHash), findsNothing);
    expect(
      find.byKey(const ValueKey('artwork-placeholder-fallback')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.movie), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
