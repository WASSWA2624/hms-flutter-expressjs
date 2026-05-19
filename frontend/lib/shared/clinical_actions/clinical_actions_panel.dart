import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_items.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class ClinicalActionsPanel extends StatelessWidget {
  const ClinicalActionsPanel({
    required this.title,
    required this.actions,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<ClinicalActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppWorkspaceDetailPanel(
      title: title,
      description: description,
      child: Wrap(
        spacing: theme.spacing.xs,
        runSpacing: theme.spacing.xs,
        children: <Widget>[
          for (final ClinicalActionItem action in actions)
            AppButton.secondary(
              label: action.label,
              leadingIcon: action.icon,
              enabled: action.enabled,
              isLoading: action.isLoading,
              tooltip: action.tooltip,
              semanticLabel: action.semanticLabel,
              onPressed: action.onPressed,
            ),
        ],
      ),
    );
  }
}
