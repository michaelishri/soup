import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';

const _minimumTextContrast = 4.5;
const _sampleWidth = 96;
const _sampleHeight = 54;

@immutable
class BackdropContrast {
  const BackdropContrast({
    required this.foreground,
    required this.scrim,
    required this.scrimOpacity,
  });

  static const fallback = BackdropContrast(
    foreground: Colors.white,
    scrim: Colors.black,
    scrimOpacity: 0.28,
  );

  final Color foreground;
  final Color scrim;
  final double scrimOpacity;

  List<Shadow> get shadows => [
    Shadow(
      color: scrim.withValues(alpha: 0.78),
      blurRadius: 7,
      offset: const Offset(0, 1),
    ),
  ];
}

BackdropContrast contrastForBackdropLuminances(Iterable<double> values) {
  final luminances =
      values
          .map((value) => value.clamp(0.0, 1.0).toDouble())
          .toList(growable: false)
        ..sort();
  if (luminances.isEmpty) return BackdropContrast.fallback;

  final difficultLuminance = _percentile(luminances, 0.9);
  final requiredOpacity = _darkScrimOpacity(difficultLuminance);

  return BackdropContrast(
    foreground: Colors.white,
    scrim: Colors.black,
    scrimOpacity: requiredOpacity.clamp(0.0, 0.58).toDouble(),
  );
}

Future<BackdropContrast> analyzeBackdropContrast(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return BackdropContrast.fallback;
  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _sampleWidth,
      targetHeight: _sampleHeight,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) return BackdropContrast.fallback;
    return contrastForBackdropLuminances(
      _sampleHeroRegion(pixels, image.width, image.height),
    );
  } catch (_) {
    return BackdropContrast.fallback;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

class AdaptiveBackdropContrastBuilder extends StatefulWidget {
  const AdaptiveBackdropContrastBuilder({
    required this.artworkKey,
    required this.image,
    required this.builder,
    super.key,
  });

  final Object artworkKey;
  final Future<CachedArtwork?> image;
  final Widget Function(BuildContext context, BackdropContrast contrast)
  builder;

  @override
  State<AdaptiveBackdropContrastBuilder> createState() =>
      _AdaptiveBackdropContrastBuilderState();
}

class _AdaptiveBackdropContrastBuilderState
    extends State<AdaptiveBackdropContrastBuilder> {
  static final _cache = <Object, BackdropContrast>{};
  BackdropContrast _contrast = BackdropContrast.fallback;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AdaptiveBackdropContrastBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkKey != widget.artworkKey) _resolve();
  }

  Future<void> _resolve() async {
    final revision = ++_revision;
    final cached = _cache[widget.artworkKey];
    if (cached != null) {
      if (mounted) setState(() => _contrast = cached);
      return;
    }
    BackdropContrast contrast;
    try {
      final artwork = await widget.image;
      contrast = await analyzeBackdropContrast(
        artwork == null ? null : await artwork.file.readAsBytes(),
      );
    } catch (_) {
      contrast = BackdropContrast.fallback;
    }
    if (!mounted || revision != _revision) return;
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    _cache[widget.artworkKey] = contrast;
    setState(() => _contrast = contrast);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _contrast);
}

Iterable<double> _sampleHeroRegion(
  ByteData pixels,
  int width,
  int height,
) sync* {
  final left = (width * 0.06).floor();
  final right = math.max(left + 1, (width * 0.8).ceil());
  final top = (height * 0.08).floor();
  final bottom = math.max(top + 1, (height * 0.7).ceil());
  for (var y = top; y < math.min(bottom, height); y++) {
    for (var x = left; x < math.min(right, width); x++) {
      final offset = (y * width + x) * 4;
      final alpha = pixels.getUint8(offset + 3) / 255;
      final red = pixels.getUint8(offset) / 255;
      final green = pixels.getUint8(offset + 1) / 255;
      final blue = pixels.getUint8(offset + 2) / 255;
      yield _relativeLuminance(red, green, blue) * alpha;
    }
  }
}

double _relativeLuminance(double red, double green, double blue) {
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue);
}

double _percentile(List<double> sorted, double percentile) {
  return sorted[((sorted.length - 1) * percentile).round()];
}

double _darkScrimOpacity(double luminance) {
  final target = 1.05 / _minimumTextContrast - 0.05;
  if (luminance <= target || luminance == 0) return 0;
  return 1 - target / luminance;
}
