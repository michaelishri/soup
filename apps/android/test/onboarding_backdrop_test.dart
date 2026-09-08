import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/connectivity/onboarding_backdrop.dart';

void main() {
  OnboardingBackgroundPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('onboarding-background-art')),
              )
              .painter!
          as OnboardingBackgroundPainter;

  Widget canvas({
    bool reducedMotion = false,
    bool accessibleNavigation = false,
    bool enabled = true,
    Widget child = const SizedBox.shrink(),
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        accessibleNavigation: accessibleNavigation,
      ),
      child: TickerMode(
        enabled: enabled,
        child: OnboardingBackdrop(child: child),
      ),
    ),
  );

  testWidgets(
    'ambient motion leaves foreground layout, focus and builds alone',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var builds = 0;
      var taps = 0;
      await tester.pumpWidget(
        canvas(
          child: Center(
            child: Builder(
              builder: (context) {
                builds++;
                return FilledButton(
                  autofocus: true,
                  focusNode: focus,
                  onPressed: () => taps++,
                  child: const Text('Next'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = painter(tester).motion.value;
      final rect = tester.getRect(find.text('Next'));
      final initialBuilds = builds;
      await tester.pump(const Duration(seconds: 3));
      expect(painter(tester).motion.value, isNot(initial));
      expect(builds, initialBuilds);
      expect(tester.getRect(find.text('Next')), rect);
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.text('Next'));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('accessibility and inactive routes stop ambient motion', (
    tester,
  ) async {
    for (final widget in [
      canvas(reducedMotion: true),
      canvas(accessibleNavigation: true),
      canvas(enabled: false),
    ]) {
      await tester.pumpWidget(widget);
      final phase = painter(tester).motion.value;
      await tester.pump(const Duration(seconds: 2));
      expect(painter(tester).motion.value, phase);
    }
    await tester.pumpWidget(canvas());
    final phase = painter(tester).motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).motion.value, isNot(phase));
    await tester.pumpWidget(canvas(reducedMotion: true));
    final stopped = painter(tester).motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).motion.value, stopped);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('backgrounding pauses motion and foregrounding resumes it', (
    tester,
  ) async {
    await tester.pumpWidget(canvas());
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final phase = painter(tester).motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).motion.value, phase);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).motion.value, isNot(phase));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
