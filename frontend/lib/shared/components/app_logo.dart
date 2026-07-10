import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 40,
    this.assetPath = _defaultLogoAssetPath,
    this.icon = Icons.local_hospital_outlined,
    this.backgroundColor,
    super.key,
  });

  final double size;
  final String assetPath;
  final IconData icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color resolvedBackground =
        backgroundColor ?? colorScheme.surface;

    return SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: resolvedBackground,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
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
        ),
      ),
    );
  }
}

const String _defaultLogoAssetPath = 'assets/logos/logo.png';
