import 'package:flutter/material.dart';

/// Displays the official VARANTi wordmark, automatically switching between the
/// Light (ink black + crimson) and Dark (crisp white + crimson) transparent PNGs.
class VarantiWordmark extends StatelessWidget {
  final double height;

  const VarantiWordmark({super.key, this.height = 24});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/brand/varanti_wordmark_dark.png'
          : 'assets/brand/varanti_wordmark_light.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Varanti',
    );
  }
}

/// Displays the official Varanti V symbol mark with theme-aware contrast.
class VarantiMark extends StatelessWidget {
  final double size;

  const VarantiMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/brand/varanti_icon_dark.png'
          : 'assets/brand/varanti_icon_light.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Varanti logo',
    );
  }
}
