import 'dart:convert';

enum UiPreset { fruity, blockbuster }

enum PaletteFamily { soup, ocean, grove, mono }

enum AppearanceBrightness { light, dark }

class AppearanceSettings {
  const AppearanceSettings({
    this.preset = UiPreset.fruity,
    this.palette = PaletteFamily.soup,
    this.brightness = AppearanceBrightness.dark,
  });

  static const schemaVersion = 1;
  static const defaults = AppearanceSettings();

  final UiPreset preset;
  final PaletteFamily palette;
  final AppearanceBrightness brightness;

  AppearanceSettings copyWith({
    UiPreset? preset,
    PaletteFamily? palette,
    AppearanceBrightness? brightness,
  }) {
    return AppearanceSettings(
      preset: preset ?? this.preset,
      palette: palette ?? this.palette,
      brightness: brightness ?? this.brightness,
    );
  }

  String encode() => jsonEncode({
    'version': schemaVersion,
    'preset': preset.name,
    'palette': palette.name,
    'brightness': brightness.name,
  });

  static AppearanceSettings? tryDecode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, Object?> || value['version'] != schemaVersion) {
        return null;
      }
      final preset = UiPreset.values.byName(value['preset'] as String);
      final palette = PaletteFamily.values.byName(value['palette'] as String);
      final brightness = AppearanceBrightness.values.byName(
        value['brightness'] as String,
      );
      return AppearanceSettings(
        preset: preset,
        palette: palette,
        brightness: brightness,
      );
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.preset == preset &&
      other.palette == palette &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(preset, palette, brightness);
}
