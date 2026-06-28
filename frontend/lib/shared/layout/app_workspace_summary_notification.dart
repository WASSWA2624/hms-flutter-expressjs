import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Worklist filter shortcut surfaced in the workspace More actions menu.
@immutable
final class AppWorkspaceSummaryNotification {
  const AppWorkspaceSummaryNotification({
    required this.label,
    required this.count,
    required this.icon,
    required this.onSelected,
    this.tone = AppWorkspaceStatusTone.neutral,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onSelected;
  final AppWorkspaceStatusTone tone;

  bool get isVisible => count > 0;
}

/// Accent color for notification icons matching former summary card tones.
Color workspaceStatusToneAccentColor(
  ThemeData theme,
  AppWorkspaceStatusTone tone,
) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    AppWorkspaceStatusTone.neutral => colorScheme.primary,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

/// Compact numeric badge for menu notification rows.
class AppMenuCountBadge extends StatelessWidget {
  const AppMenuCountBadge({
    required this.count,
    required this.tone,
    super.key,
  });

  final int count;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final Color accentColor = workspaceStatusToneAccentColor(theme, tone);

    return Text(
      AppFormatters.compactNumber(count, locale),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: theme.textTheme.titleSmall?.copyWith(
        color: accentColor,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

List<AppWorkspaceSummaryNotification> visibleWorkspaceSummaryNotifications(
  List<AppWorkspaceSummaryNotification> notifications,
) {
  return notifications.where((AppWorkspaceSummaryNotification n) => n.isVisible).toList(growable: false);
}
