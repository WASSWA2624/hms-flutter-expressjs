import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 40,
    this.assetPath = _defaultLogoAssetPath,
    this.icon = Icons.local_hospital_outlined,
    super.key,
  });

  final double size;
  final String assetPath;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: colorScheme.surface,
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
