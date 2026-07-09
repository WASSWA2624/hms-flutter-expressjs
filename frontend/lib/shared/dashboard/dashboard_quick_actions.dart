import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_section_header.dart';

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
    final ThemeData theme = Theme.of(context);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DashboardSectionHeader(
          title: title,
          leadingIcon: Icons.play_arrow_rounded,
        ),
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double gap = theme.spacing.sm;
            final int columns = dashboardQuickActionColumnCount(
              constraints.maxWidth,
              actions.length,
            );
            final double tileWidth = columns <= 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (gap * (columns - 1))) / columns;
            final bool singleRow = columns == actions.length;
            final List<Widget> actionTiles = <Widget>[
              for (final DashboardQuickActionData action in actions)
                SizedBox(
                  width: singleRow ? null : math.max(0, tileWidth),
                  child: _DashboardQuickActionTile(action: action),
                ),
            ];

            if (singleRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int index = 0; index < actionTiles.length; index += 1)
                    ...<Widget>[
                      if (index > 0) SizedBox(width: gap),
                      Expanded(child: actionTiles[index]),
                    ],
                ],
              );
            }

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: actionTiles,
            );
          },
        ),
      ],
    );
  }
}

class _DashboardQuickActionTile extends StatelessWidget {
  const _DashboardQuickActionTile({required this.action});

  final DashboardQuickActionData action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.semanticsLabel,
      child: AppButton.primary(
        label: action.label,
        leadingIcon: action.icon,
        onPressed: action.onPressed,
        fullWidth: true,
        semanticLabel: action.semanticsLabel,
      ),
    );
  }
}
