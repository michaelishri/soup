import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';

/// Slow, painted film-frame linework. Only this isolated layer repaints, at 20 fps;
/// forms, QR codes and text stay still. No blur filters or offscreen layers.
class OnboardingBackdrop extends StatefulWidget {
  const OnboardingBackdrop({required this.child, super.key});
  final Widget child;

  @override
  State<OnboardingBackdrop> createState() => _OnboardingBackdropState();
}

class _OnboardingBackdropState extends State<OnboardingBackdrop>
    with WidgetsBindingObserver {
  final _motion = ValueNotifier<double>(0);
  Timer? _timer;
  bool _foreground = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _allowed =
        !media.disableAnimations &&
        !media.accessibleNavigation &&
        TickerMode.valuesOf(context).enabled;
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion() {
    if (_allowed && _foreground) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        _motion.value = (_motion.value + 1 / 720) % 1;
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('onboarding-background-art'),
                painter: OnboardingBackgroundPainter(_motion),
                isComplex: true,
                willChange: _allowed && _foreground,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class OnboardingBackgroundPainter extends CustomPainter {
  OnboardingBackgroundPainter(this.motion) : super(repaint: motion);
  final ValueListenable<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final unit = math.min(width, height);
    final drift = math.sin(motion.value * math.pi * 2) * 10;
    canvas.drawColor(SoupTheme.onboardingBackground, BlendMode.src);
    final paint = Paint()
      ..color = SoupTheme.onboardingAccent.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    // Fine diagonal rules and offset frames recall a printed film programme.
    // They sit behind the content, with no moving text or interactive targets.
    for (double x = -height; x < width; x += 80) {
      canvas.drawLine(Offset(x, height), Offset(x + height * 0.7, 0), paint);
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = SoupTheme.onboardingAccent.withValues(alpha: 0.12);
    for (var i = 0; i < 3; i++) {
      final x = width * 0.87 + i * 24 + drift;
      final y = height * 0.08 + i * 24;
      final frame = Path()
        ..moveTo(x, y)
        ..lineTo(x + unit * 0.62, y)
        ..lineTo(x + unit * 0.30, y + unit * 0.92)
        ..lineTo(x - unit * 0.32, y + unit * 0.92)
        ..close();
      canvas.drawPath(frame, paint);
    }

    // A narrow film edge moves by one perforation per cycle. It remains outside
    // the page's safe padding, including on compact screens.
    paint
      ..style = PaintingStyle.fill
      ..color = SoupTheme.onboardingInk;
    canvas.drawRect(Rect.fromLTWH(0, height - 10, width, 10), paint);
    paint.color = SoupTheme.onboardingSignal;
    for (double x = -36 + motion.value * 36; x < width; x += 36) {
      canvas.drawRect(Rect.fromLTWH(x, height - 7, 18, 4), paint);
    }
    paint.color = SoupTheme.onboardingAccent;
    canvas.drawRect(
      Rect.fromLTWH(0, height * 0.7, 5, height * 0.3 - 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(OnboardingBackgroundPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
