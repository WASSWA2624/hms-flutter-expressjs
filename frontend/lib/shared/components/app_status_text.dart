import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class AppStatusText extends StatelessWidget {
  const AppStatusText({
    required this.label,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.icon,
    this.includeDefaultToneIcon = true,
    this.fontWeight = AppFontWeight.emphasis,
    this.maxLines = 1,
    this.softWrap = false,
    super.key,
  });

  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData? icon;

  /// When true and [icon] is null, shows a tone-default icon so status is not
  /// color-only.
  final bool includeDefaultToneIcon;
  final FontWeight fontWeight;
  final int maxLines;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _textColor(theme);
    final IconData? resolvedIcon =
        icon ?? (includeDefaultToneIcon ? _defaultToneIcon(tone) : null);
    final Text text = Text(
      label,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: fontWeight,
      ),
    );

    if (resolvedIcon == null) {
      return text;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(resolvedIcon, size: theme.appTokens.listIconSize, color: color),
        SizedBox(width: theme.spacing.xs),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: text,
          ),
        ),
      ],
    );
  }

  static IconData? _defaultToneIcon(AppWorkspaceStatusTone tone) {
    return switch (tone) {
      AppWorkspaceStatusTone.success => Icons.check_circle_outline,
      AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
      AppWorkspaceStatusTone.error => Icons.error_outline,
      AppWorkspaceStatusTone.info => Icons.info_outline,
      AppWorkspaceStatusTone.neutral => Icons.circle_outlined,
    };
  }

  Color _textColor(ThemeData theme) {
    return switch (tone) {
      AppWorkspaceStatusTone.success => theme.statusColors.success,
      AppWorkspaceStatusTone.warning => theme.statusColors.warning,
      AppWorkspaceStatusTone.error => theme.statusColors.error,
      AppWorkspaceStatusTone.info => theme.statusColors.info,
      AppWorkspaceStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
  }
}
