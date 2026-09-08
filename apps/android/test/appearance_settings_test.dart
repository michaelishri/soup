import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/features/appearance/appearance_controller.dart';

void main() {
  test('new devices default to the light Festival theme', () {
    expect(AppearanceSettings.defaults.palette, PaletteFamily.festival);
    expect(AppearanceSettings.defaults.brightness, AppearanceBrightness.light);
  });

  test('existing serialized choices keep their palette and brightness', () {
    for (final preset in UiPreset.values) {
      for (final palette in PaletteFamily.values) {
        for (final brightness in AppearanceBrightness.values) {
          final encoded =
              '{"version":1,"preset":"${preset.name}","palette":"${palette.name}","brightness":"${brightness.name}"}';
          final settings = AppearanceSettings.tryDecode(encoded)!;
          expect(settings.preset, preset);
          expect(settings.palette, palette);
          expect(settings.brightness, brightness);
          expect(AppearanceSettings.tryDecode(settings.encode()), settings);
        }
      }
    }
  });

  test('round-trips every appearance value', () {
    const settings = AppearanceSettings(
      preset: UiPreset.blockbuster,
      palette: PaletteFamily.grove,
      brightness: AppearanceBrightness.light,
    );

    expect(AppearanceSettings.tryDecode(settings.encode()), settings);
  });

  test('rejects corrupt, unknown, and unsupported settings', () {
    expect(AppearanceSettings.tryDecode('not-json'), isNull);
    expect(
      AppearanceSettings.tryDecode(
        '{"version":1,"preset":"unknown","palette":"soup","brightness":"dark"}',
      ),
      isNull,
    );
    expect(
      AppearanceSettings.tryDecode(
        '{"version":2,"preset":"fruity","palette":"soup","brightness":"dark"}',
      ),
      isNull,
    );
  });

  test('controller loads and saves device settings', () async {
    final store = MemoryAppearanceStore();
    final controller = AppearanceController(store);
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.initialized, isTrue);
    expect(controller.settings, isNull);
    expect(controller.effectiveSettings, AppearanceSettings.defaults);

    const selected = AppearanceSettings(
      palette: PaletteFamily.ocean,
      brightness: AppearanceBrightness.light,
    );
    await controller.save(selected);

    expect(controller.settings, selected);
    expect(store.settings, selected);
  });
}
