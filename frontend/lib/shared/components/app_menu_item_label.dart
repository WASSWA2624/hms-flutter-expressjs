import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart';

/// Icon + label row used in popup menus (user menu, toolbar overflow, etc.).
class AppMenuItemLabel extends StatelessWidget {
  const AppMenuItemLabel({
    required this.icon,
    required this.label,
    this.iconTone,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final AppWorkspaceStatusTone? iconTone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color iconColor = iconTone == null
        ? colorScheme.onSurfaceVariant
        : workspaceStatusToneAccentColor(theme, iconTone!);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: iconColor,
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
        if (trailing != null) ...<Widget>[
          SizedBox(width: theme.spacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
