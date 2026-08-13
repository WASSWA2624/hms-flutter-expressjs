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

  /// Square mark; sizing by [size] keeps height and width equal.
  static const double defaultAspectRatio = 1.0;

  final String assetPath;
  final IconData icon;
  final Color? backgroundColor;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double width = size * aspectRatio;

    final Widget image = Image.asset(
      assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
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
