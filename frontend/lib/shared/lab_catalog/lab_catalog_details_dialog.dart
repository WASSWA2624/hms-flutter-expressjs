import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showLabCatalogItemDetailsDialog(
  BuildContext context, {
  required LabCatalogItem item,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool isPanel = item.isPanel;
  final String title = isPanel
      ? l10n.labCatalogPanelDetailsDialogTitle
      : l10n.labCatalogTestDetailsDialogTitle;

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final List<(String, String)> facts = <(String, String)>[
        (l10n.labCatalogItemIdLabel, _displayValue(item.apiId)),
        (
          isPanel ? l10n.labPanelNameLabel : l10n.labTestNameLabel,
          _displayValue(item.name),
        ),
        (
          isPanel ? l10n.labPanelCodeLabel : l10n.labTestCodeLabel,
          _displayValue(item.code),
        ),
        (l10n.labCategoryLabel, _displayValue(item.category)),
        if (!isPanel) ...<(String, String)>[
          (l10n.labSpecimenTypeLabel, _displayValue(item.specimenType)),
          (l10n.labResultKindLabel, _displayValue(item.resultKind)),
          (l10n.labDefaultUnitLabel, _displayValue(item.unit)),
        ],
        if ((item.description ?? '').trim().isNotEmpty)
          (
            isPanel
                ? l10n.labPanelDescriptionLabel
                : l10n.labTestDescriptionLabel,
            item.description!.trim(),
          ),
        if (item.isStandard)
          (l10n.labStandardCatalogBadge, l10n.labStandardCatalogBadge),
      ];

      return AppDialog(
        title: Text(title),
        icon: Icon(
          isPanel ? Icons.view_module_outlined : Icons.biotech_outlined,
        ),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSectionPanel(
              tone: AppWorkspaceStatusTone.info,
              density: AppContentPanelDensity.compact,
              leadingIcon: Icons.info_outline,
              title: item.displayTitle,
              children: <Widget>[
                Wrap(
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: theme.spacing.xs / 2),
                            Text(
                              value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (!isPanel && item.referenceRanges.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.md),
                  Text(
                    l10n.labTestRangesSectionTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  for (final LabReferenceRange range
                      in item.referenceRanges) ...<Widget>[
                    Text(
                      range.displayLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                  ],
                ],
              ],
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
