import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Lightweight section title used below the metric strip.
class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    required this.title,
    this.leadingIcon,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          Icon(
            leadingIcon,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
        ],
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: theme.spacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
