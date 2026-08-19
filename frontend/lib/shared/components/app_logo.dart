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
  /// Printed as `APP_LOGO_ASPECT` by `tool/generate_hosspi_logo.py`.
  static const double defaultAspectRatio = 0.9798;

  /// Cap-height fraction of the brand typeface, from Roboto's `OS/2.sCapHeight`
  /// (1456 ÷ 2048 unitsPerEm). Keep in sync with `AppFontFamily.primary`.
  static const double capHeightRatio = 0.7109;

  /// Alphabetic baseline position as a fraction of font size, for text set with
  /// `height: 1.0` in the brand typeface. Flutter lays a height-scaled line box
  /// out from the hhea metrics (Roboto: ascent 1900, descent -500).
  static const double baselineRatio = 1900 / (1900 + 500);

  /// Mark height that optically matches capitals set at [fontSize].
  ///
  /// A glyph's em box is taller than the letters drawn inside it, so a mark
  /// sized to the font size towers over the word beside it. Sizing to the cap
  /// height is what makes a logo lockup read as one line.
  static double markHeightForFontSize(double fontSize) =>
      fontSize * capHeightRatio;

  /// Top inset that drops a [markHeightForFontSize] mark onto the text
  /// baseline when both sit in a row aligned to [CrossAxisAlignment.start].
  ///
  /// Row baseline alignment cannot do this: an image reports no real baseline,
  /// so `RenderFlex` silently falls back to top-aligning it.
  static double markBaselineInsetForFontSize(double fontSize) =>
      fontSize * (baselineRatio - capHeightRatio);

  /// Cyan-blue from the book cover under the medical cross.
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
      filterQuality: FilterQuality.high,
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
