import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Icon + label row used in popup menus (user menu, toolbar overflow, etc.).
class AppMenuItemLabel extends StatelessWidget {
  const AppMenuItemLabel({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
