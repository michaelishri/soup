import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

const _blurHashAlphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';

class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder({
    required this.blurHash,
    this.fit = BoxFit.cover,
    this.fallback,
    super.key,
  });

  final String? blurHash;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final hash = blurHash;
    if (!_isValidBlurHash(hash)) {
      return ColoredBox(
        key: const ValueKey('artwork-placeholder-fallback'),
        color: color,
        child: fallback,
      );
    }
    return BlurHash(
      key: const ValueKey('artwork-placeholder-blurhash'),
      hash: hash!,
      color: color,
      imageFit: fit,
      decodingWidth: 32,
      decodingHeight: 32,
      optimizationMode: BlurHashOptimizationMode.standard,
    );
  }
}

bool _isValidBlurHash(String? hash) {
  if (hash == null || hash.length < 6) return false;
  final sizeFlag = _blurHashAlphabet.indexOf(hash[0]);
  if (sizeFlag < 0) return false;
  for (var index = 1; index < hash.length; index++) {
    if (!_blurHashAlphabet.contains(hash[index])) return false;
  }
  final componentCount = (sizeFlag % 9 + 1) * (sizeFlag ~/ 9 + 1);
  return hash.length == 4 + 2 * componentCount;
}
