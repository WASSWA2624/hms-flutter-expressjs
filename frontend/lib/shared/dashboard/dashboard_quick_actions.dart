import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    required this.actions,
    required this.title,
    super.key,
  });

  final List<DashboardQuickActionData> actions;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: dashboardSurfaceCardDecoration(theme, colorScheme),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.bolt_rounded, size: 20, color: colorScheme.primary),
                SizedBox(width: theme.spacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            DashboardActionButtonRow(actions: actions),
          ],
        ),
      ),
    );
  }
}

class DashboardActionButtonRow extends StatelessWidget {
  const DashboardActionButtonRow({
    required this.actions,
    this.maxActions = 5,
    super.key,
  });

  final List<DashboardQuickActionData> actions;
  final int maxActions;

  @override
  Widget build(BuildContext context) {
    final List<DashboardQuickActionData> visibleActions = actions
        .take(maxActions)
        .toList(growable: false);

    if (visibleActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ThemeData theme = Theme.of(context);
        final double gap = theme.spacing.sm;
        final double minTileWidth = dashboardQuickActionMinTileWidth(
          constraints.maxWidth,
        );
        final int columns = math
            .max(1, (constraints.maxWidth / (minTileWidth + gap)).floor())
            .clamp(1, visibleActions.length);

        if (columns >= visibleActions.length) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (
                int index = 0;
                index < visibleActions.length;
                index += 1
              ) ...<Widget>[
                if (index > 0) SizedBox(width: gap),
                Expanded(
                  child: _DashboardQuickActionTile(
                    action: visibleActions[index],
                  ),
                ),
              ],
            ],
          );
        }

        final double tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final DashboardQuickActionData action in visibleActions)
              SizedBox(
                width: tileWidth,
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

    return Semantics(
      button: true,
      label: action.semanticsLabel,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(theme.radius.lg),
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: BorderRadius.circular(theme.radius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radius.lg),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: dashboardAccentIconDecoration(
                      theme,
                      colorScheme.primary,
                    ),
                    child: Icon(
                      action.icon,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
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
