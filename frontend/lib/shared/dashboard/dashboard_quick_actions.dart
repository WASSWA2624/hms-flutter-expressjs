import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.actions, super.key});

  final List<DashboardQuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = theme.spacing.sm;
        final int columns = dashboardQuickActionColumnCount(
          constraints.maxWidth,
          actions.length,
        );
        final double tileWidth = columns <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final DashboardQuickActionData action in actions)
              SizedBox(
                width: math.max(0, tileWidth),
                child: _DashboardQuickActionTile(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardQuickActionTile extends StatelessWidget {
  const _DashboardQuickActionTile({required this.action});

  final DashboardQuickActionData action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = colorScheme.primary;

    return Semantics(
      button: true,
      label: action.semanticsLabel,
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radius.lg),
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: BorderRadius.circular(theme.radius.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(theme.radius.lg),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(theme.radius.md),
                    ),
                    child: Icon(action.icon, color: accent, size: 18),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
