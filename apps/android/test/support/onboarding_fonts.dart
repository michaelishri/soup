import 'package:flutter/services.dart';

/// Use the real condensed heading metrics for responsive and remote-focus tests.
Future<void> loadOnboardingFonts() async {
  final font = FontLoader('BarlowCondensed');
  font.addFont(rootBundle.load('assets/fonts/BarlowCondensed-ExtraBold.ttf'));
  await font.load();
}
