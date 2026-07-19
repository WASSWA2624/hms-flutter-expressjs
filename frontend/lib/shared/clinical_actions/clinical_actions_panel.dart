import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_items.dart';

class ClinicalActionsPanel extends StatelessWidget {
  const ClinicalActionsPanel({
    required this.title,
    required this.actions,
    this.description,
    this.minItemWidth = 156,
    this.maxColumns = 5,
    super.key,
  });

  final String title;
  final String? description;
  final List<ClinicalActionItem> actions;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return AppQuickActions(
      title: title,
      description: description,
      presentation: AppQuickActionsPresentation.detailPanel,
      minItemWidth: minItemWidth,
      maxColumns: maxColumns,
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
