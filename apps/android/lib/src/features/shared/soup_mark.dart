import 'package:flutter/material.dart';

/// The generated Soup app badge. It has its own opaque background, so it must
/// not be tinted like the previous monochrome fin asset.
class SoupMark extends StatelessWidget {
  const SoupMark({this.size = 40, super.key});

  static const assetName = 'assets/branding/soup-icon.png';
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.25),
    child: Image.asset(
      assetName,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
