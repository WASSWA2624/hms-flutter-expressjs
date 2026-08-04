import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Selectable tile used for payment methods, plan options, and similar choices.
class AppChoiceTile extends StatelessWidget {
  const AppChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.subtitle,
    this.accentColor,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final String? subtitle;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = accentColor ?? colorScheme.primary;
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);
    final Color background = selected
        ? accent.withValues(alpha: 0.12)
        : colorScheme.surface;
    final Color border = selected ? accent : theme.borders.faint;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? theme.borders.side(color: border, weight: AppBorderWeight.medium)
              : theme.borders.side(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? theme.spacing.sm : theme.spacing.md,
              vertical: compact ? theme.spacing.sm : theme.spacing.md,
            ),
            child: Row(
              children: <Widget>[
                if (iconWidget != null || icon != null) ...<Widget>[
                  iconWidget ??
                      Icon(
                        icon,
                        size: compact ? 20 : 22,
                        color: selected ? accent : colorScheme.onSurfaceVariant,
                      ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                          color: selected ? accent : colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null &&
                          subtitle!.trim().isNotEmpty) ...<Widget>[
                        SizedBox(height: theme.spacing.xs),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
