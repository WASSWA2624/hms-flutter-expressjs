import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 40, this.icon = Icons.apps_outlined, super.key});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: colorScheme.primaryContainer,
        child: Icon(
          icon,
          color: colorScheme.onPrimaryContainer,
          size: size * 0.55,
        ),
      ),
    );
  }
}
