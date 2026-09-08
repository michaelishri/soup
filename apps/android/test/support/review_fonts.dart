import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'onboarding_fonts.dart';

Future<void> loadReviewFonts() async {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(await config.readAsString())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final flutter = packages.cast<Map<String, dynamic>>().singleWhere(
    (entry) => entry['name'] == 'flutter',
  );
  final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
  final directory = root.resolve('../../bin/cache/artifacts/material_fonts/');
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    loader.addFont(
      File.fromUri(
        directory.resolve(name),
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
  await loadOnboardingFonts();
  final icons = FontLoader('packages/phosphoricons_flutter/PhosphorRegular');
  icons.addFont(
    rootBundle.load('packages/phosphoricons_flutter/lib/fonts/Phosphor.ttf'),
  );
  await icons.load();
  final filledIcons = FontLoader('packages/phosphoricons_flutter/PhosphorFill');
  filledIcons.addFont(
    rootBundle.load(
      'packages/phosphoricons_flutter/lib/fonts/Phosphor-Fill.ttf',
    ),
  );
  await filledIcons.load();
  final materialIcons = FontLoader('MaterialIcons');
  materialIcons.addFont(
    File.fromUri(
      directory.resolve('MaterialIcons-Regular.otf'),
    ).readAsBytes().then(ByteData.sublistView),
  );
  await materialIcons.load();
}
