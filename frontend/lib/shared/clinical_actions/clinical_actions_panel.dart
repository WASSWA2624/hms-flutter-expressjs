import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_items.dart';

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
    return AppActionPanel(
      title: title,
      description: description,
      actions: <AppActionItem>[
        for (final ClinicalActionItem action in actions)
          AppActionItem(
            label: action.label,
            leadingIcon: action.icon,
            enabled: action.enabled,
            isLoading: action.isLoading,
            tooltip: action.tooltip,
            semanticLabel: action.semanticLabel,
            onPressed: action.onPressed,
          ),
      ],
    );
  }
}
