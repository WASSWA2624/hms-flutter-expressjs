import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showRadiologyCatalogProcedureDetailsDialog(
  BuildContext context, {
  required RadiologyCatalogProcedure procedure,
}) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final List<(String, String)> facts = <(String, String)>[
        (
          l10n.radiologyCatalogProcedureIdLabel,
          _displayValue(procedure.effectiveId),
        ),
        (l10n.radiologyProcedureNameLabel, _displayValue(procedure.name)),
        (l10n.radiologyProcedureCodeLabel, _displayValue(procedure.code)),
        (l10n.radiologyModalityLabel, _displayValue(procedure.modality)),
        (l10n.radiologyBodyRegionLabel, _displayValue(procedure.bodyRegion)),
        (l10n.radiologyLateralityLabel, _displayValue(procedure.laterality)),
        (l10n.radiologyEquipmentLabel, _displayValue(procedure.equipment)),
      ];

      return AppDialog(
        title: Text(l10n.radiologyCatalogProcedureDetailsDialogTitle),
        icon: const Icon(Icons.medical_information_outlined),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCollapsibleSection(
              title: procedure.name,
              titleIcon: Icons.info_outline,
              child: Wrap(
                spacing: theme.spacing.md,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final (String label, String value) in facts)
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: theme.spacing.xs / 2),
                          Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            leadingIcon: Icons.check,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

String _displayValue(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '—' : trimmed;
}
