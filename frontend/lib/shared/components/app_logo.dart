import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 40,
    this.assetPath = _defaultLogoAssetPath,
    this.icon = Icons.local_hospital_outlined,
    this.backgroundColor,
    /// Width ÷ height for the mark asset. Keep in sync with logo art.
    this.aspectRatio = defaultAspectRatio,
    super.key,
  });

  /// Default mark height.
  final double size;

  /// Matches cropped `logo.png` content aspect (width ÷ height).
  static const double defaultAspectRatio = 1.0;

  /// Cyan-blue from the window/grid features under the medical cross.
  /// Keep in sync with [AppLightThemePalette.brandPrimary] / light `colorScheme.primary`.
  static const Color brandBlue = Color(0xFF0079FD);

  final String assetPath;
  final IconData icon;
  final Color? backgroundColor;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double width = size * aspectRatio;
    // Decode at device pixels so Flutter web/high-DPI does not soft-scale the
    // full bitmap down in the compositor (common cause of blurry app-bar marks).
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheWidth = (width * dpr).round().clamp(1, 4096);
    final int cacheHeight = (size * dpr).round().clamp(1, 4096);

    final Widget image = Image.asset(
      assetPath,
      width: width,
      height: size,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      errorBuilder: (_, _, _) {
        return ColoredBox(
          color: colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
            size: size * 0.55,
          ),
        );
      },
    );

    return SizedBox(
      width: width,
      height: size,
      child: backgroundColor == null
          ? image
          : ColoredBox(color: backgroundColor!, child: image),
    );
  }
}

const String _defaultLogoAssetPath = 'assets/logos/logo.png';
