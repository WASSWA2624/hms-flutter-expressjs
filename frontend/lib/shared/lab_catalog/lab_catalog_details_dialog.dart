import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Result from [showLabCatalogItemDetailsDialog] when the viewer chooses a
/// mutate action. `null` means Close / dismiss.
enum LabCatalogItemDetailsAction { edit, delete }

Future<LabCatalogItemDetailsAction?> showLabCatalogItemDetailsDialog(
  BuildContext context, {
  required LabCatalogItem item,
  bool showMutateActions = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool isPanel = item.isPanel;
  final String title = isPanel
      ? l10n.labCatalogPanelDetailsDialogTitle
      : l10n.labCatalogTestDetailsDialogTitle;

  return showAppDialog<LabCatalogItemDetailsAction>(
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
        if (isPanel)
          (
            l10n.labPanelSelectedTestsTitle,
            l10n.labPanelSelectedTestsCountLabel(
              item.panelItems.isNotEmpty
                  ? item.panelItems.length
                  : item.testCount,
            ),
          ),
        (
          isPanel
              ? l10n.labPanelDescriptionLabel
              : l10n.labTestDescriptionLabel,
          _displayValue(item.description),
        ),
        if ((item.source ?? '').trim().isNotEmpty)
          (l10n.radiologySourceColumnLabel, item.source!.trim()),
        if (item.isStandard)
          (l10n.labStandardCatalogBadge, l10n.labStandardCatalogBadge),
      ];

      return AppDialog(
        title: Text(title),
        icon: Icon(
          isPanel ? Icons.view_module_outlined : Icons.biotech_outlined,
        ),
        scrollable: true,
        maxWidth: isPanel ? 720 : 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCollapsibleSection(
              title: item.displayTitle,
              titleIcon: Icons.info_outline,
              headerActions: showMutateActions
                  ? <Widget>[
                      AppButton(
                        iconOnly: true,
                        leadingIcon: Icons.delete_outline,
                        label: l10n.commonDeleteActionLabel,
                        semanticLabel: l10n.commonDeleteActionLabel,
                        tooltip: l10n.commonDeleteActionLabel,
                        color: theme.colorScheme.error,
                        onPressed: () => Navigator.of(
                          dialogContext,
                        ).pop(LabCatalogItemDetailsAction.delete),
                      ),
                    ]
                  : const <Widget>[],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  fontWeight: AppFontWeight.emphasis,
                                ),
                              ),
                              SizedBox(height: theme.spacing.xs / 2),
                              Text(
                                value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: AppFontWeight.medium,
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
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    for (final LabReferenceRange range
                        in item.referenceRanges) ...<Widget>[
                      Text(
                        range.displayLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: AppFontWeight.medium,
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs),
                    ],
                  ],
                  if (isPanel) ...<Widget>[
                    SizedBox(height: theme.spacing.md),
                    Text(
                      l10n.labPanelTestsLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    if (item.panelItems.isEmpty)
                      AppMutedText(l10n.labPanelNoSelectedTests)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: theme.borders.all(),
                          borderRadius: BorderRadius.circular(theme.radius.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (
                              int index = 0;
                              index < item.panelItems.length;
                              index += 1
                            ) ...<Widget>[
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  color: theme.borders.faint,
                                ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacing.md,
                                  vertical: theme.spacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${index + 1}.',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: AppFontWeight.emphasis,
                                          ),
                                    ),
                                    SizedBox(width: theme.spacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.panelItems[index].displayTitle,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: AppFontWeight.medium,
                                                ),
                                          ),
                                          if (_panelItemSubtitle(
                                            item.panelItems[index],
                                          ).isNotEmpty)
                                            Text(
                                              _panelItemSubtitle(
                                                item.panelItems[index],
                                              ),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (showMutateActions)
            AppButton.secondary(
              label: l10n.clinicalLabRequestEditSelectionAction,
              leadingIcon: Icons.edit_outlined,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(LabCatalogItemDetailsAction.edit),
            ),
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

String _panelItemSubtitle(LabPanelItem item) {
  return <String?>[
    item.testCode,
    item.unit,
  ].whereType<String>().where((String value) => value.trim().isNotEmpty).join(
    ' · ',
  );
}

String _displayValue(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '—' : trimmed;
}
