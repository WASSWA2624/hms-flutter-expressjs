import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
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

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final DashboardQuickActionData action in actions)
          Semantics(
            button: true,
            label: action.semanticsLabel,
            child: AppButton.secondary(
              label: action.label,
              leadingIcon: action.icon,
              onPressed: action.onPressed,
            ),
          ),
      ],
    );
  }
}
