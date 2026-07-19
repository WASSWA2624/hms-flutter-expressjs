import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
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
    return AppQuickActions(
      title: title,
      leadingIcon: Icons.bolt_rounded,
      minItemWidth: 180,
      maxColumns: 5,
      actions: <AppActionItem>[
        for (final DashboardQuickActionData action in actions)
          AppActionItem(
            label: action.label,
            leadingIcon: action.icon,
            semanticLabel: action.semanticsLabel,
            onPressed: action.onPressed,
          ),
      ],
    );
  }
}

/// Backwards-compatible action row used by compact dashboard empty states.
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
    return AppActionList(
      maxColumns: maxActions,
      minItemWidth: 180,
      actions: <AppActionItem>[
        for (final DashboardQuickActionData action in actions.take(maxActions))
          AppActionItem(
            label: action.label,
            leadingIcon: action.icon,
            semanticLabel: action.semanticsLabel,
            onPressed: action.onPressed,
          ),
      ],
    );
  }
}
