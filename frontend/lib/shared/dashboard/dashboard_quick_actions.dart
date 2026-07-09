import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.play_arrow_rounded,
      density: AppContentPanelDensity.spacious,
      backgroundColor: dashboardSectionBackgroundColor(colorScheme),
      borderColor: dashboardSectionBorderColor(colorScheme),
      children: <Widget>[DashboardActionButtonRow(actions: actions)],
    );
  }
}

class DashboardActionButtonRow extends StatelessWidget {
  const DashboardActionButtonRow({
    required this.actions,
    this.maxActions = 4,
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
        final int columns = dashboardQuickActionColumnCount(
          constraints.maxWidth,
          visibleActions.length,
        );
        final double tileWidth = columns <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (gap * (columns - 1))) / columns;
        final bool singleRow = columns == visibleActions.length;
        final List<Widget> actionTiles = <Widget>[
          for (final DashboardQuickActionData action in visibleActions)
            SizedBox(
              width: singleRow ? null : math.max(0, tileWidth),
              child: _DashboardQuickActionTile(action: action),
            ),
        ];

        if (singleRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (
                int index = 0;
                index < actionTiles.length;
                index += 1
              ) ...<Widget>[
                if (index > 0) SizedBox(width: gap),
                Expanded(child: actionTiles[index]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (
              int index = 0;
              index < actionTiles.length;
              index += 1
            ) ...<Widget>[
              if (index > 0) SizedBox(height: gap),
              actionTiles[index],
            ],
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radius.lg),
          border: Border.all(color: dashboardSectionBorderColor(colorScheme)),
        ),
        child: AppButton.primary(
          label: action.label,
          leadingIcon: action.icon,
          onPressed: action.onPressed,
          fullWidth: true,
          semanticLabel: action.semanticsLabel,
        ),
      ),
    );
  }
}
