import 'dart:typed_data';

import 'package:flutter/material.dart';

class FadingArtwork extends StatefulWidget {
  const FadingArtwork({
    required this.artworkKey,
    required this.image,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.opacity = 1,
    this.duration = const Duration(milliseconds: 320),
    super.key,
  });

  final Object artworkKey;
  final Future<Uint8List?> image;
  final Widget placeholder;
  final BoxFit fit;
  final double opacity;
  final Duration duration;

  @override
  State<FadingArtwork> createState() => _FadingArtworkState();
}

class _FadingArtworkState extends State<FadingArtwork> {
  Uint8List? _displayedBytes;
  Object? _displayedKey;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FadingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkKey != widget.artworkKey ||
        oldWidget.image != widget.image) {
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    final artworkKey = widget.artworkKey;
    final bytes = await widget.image;
    if (!mounted || revision != _loadRevision) return;
    setState(() {
      _displayedBytes = bytes == null || bytes.isEmpty ? null : bytes;
      _displayedKey = artworkKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bytes = _displayedBytes;
    final child = bytes == null
        ? KeyedSubtree(
            key: ValueKey('artwork-placeholder-$_displayedKey'),
            child: widget.placeholder,
          )
        : SizedBox.expand(
            key: ValueKey('artwork-image-$_displayedKey'),
            child: Opacity(
              opacity: widget.opacity,
              child: Image.memory(bytes, fit: widget.fit),
            ),
          );
    return AnimatedSwitcher(
      key: const ValueKey('fading-artwork-transition'),
      duration: reduceMotion ? Duration.zero : widget.duration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
