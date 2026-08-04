import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_print_options_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Mutable selection state for dispense-history print preview rebuilds.
final class PharmacyPrintHistoryOptionsController extends ChangeNotifier {
  PharmacyPrintHistoryOptionsController(List<PharmacyTimelineItem> historyItems)
    : _historyItems = List<PharmacyTimelineItem>.unmodifiable(historyItems) {
    _selectedHistoryIds =
        _historyItems.map((PharmacyTimelineItem item) => item.id).toSet();
  }

  final List<PharmacyTimelineItem> _historyItems;
  late final Set<String> _selectedHistoryIds;

  List<PharmacyTimelineItem> get historyItems => _historyItems;

  Set<String> get selectedHistoryIds =>
      Set<String>.unmodifiable(_selectedHistoryIds);

  bool get canPrint => _selectedHistoryIds.isNotEmpty;

  List<PharmacyTimelineItem> get selectedHistoryItems {
    return _historyItems
        .where(
          (PharmacyTimelineItem item) => _selectedHistoryIds.contains(item.id),
        )
        .toList(growable: false);
  }

  void setHistorySelected(String historyId, bool selected) {
    if (selected) {
      _selectedHistoryIds.add(historyId);
    } else {
      _selectedHistoryIds.remove(historyId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedHistoryIds
      ..clear()
      ..addAll(_historyItems.map((PharmacyTimelineItem item) => item.id));
    notifyListeners();
  }

  void clearAll() {
    _selectedHistoryIds.clear();
    notifyListeners();
  }
}

/// Collapsible print-history selection section for the preview dialog.
class PharmacyPrintHistoryOptionsSection extends StatelessWidget {
  const PharmacyPrintHistoryOptionsSection({
    required this.controller,
    required this.workflow,
    super.key,
  });

  final PharmacyPrintHistoryOptionsController controller;
  final PharmacyOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final int selectedCount = controller.selectedHistoryIds.length;
        final int totalCount = controller.historyItems.length;

        return AppFormSection(
          title: l10n.pharmacyPrintHistoryOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.pharmacyPrintSelectHistoryLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$selectedCount / $totalCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (totalCount > 0) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  tristate: true,
                  value: selectedCount == 0
                      ? false
                      : selectedCount == totalCount
                      ? true
                      : null,
                  title: Text(l10n.pharmacyPrintSelectAllHistoryLabel),
                  onChanged: (bool? checked) {
                    if (checked == true) {
                      controller.selectAll();
                    } else {
                      controller.clearAll();
                    }
                  },
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            if (totalCount == 0)
              Text(
                l10n.pharmacyDispenseHistoryEmptyBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (
                var index = 0;
                index < controller.historyItems.length;
                index++
              ) ...<Widget>[
                if (index > 0) SizedBox(height: theme.spacing.xs),
                Builder(
                  builder: (BuildContext context) {
                    final PharmacyTimelineItem item =
                        controller.historyItems[index];
                    final String? batch = item.labelParams['batch']
                        ?.toString()
                        .trim();
                    final List<PharmacyDispenseBatchLine> lines =
                        resolvePharmacyDispenseBatchLines(
                          workflow: workflow,
                          dispenseBatchRef: batch,
                          dispenseLogId: item.labelParams['log_id']?.toString(),
                        );
                    final String medications = lines
                        .map(
                          (PharmacyDispenseBatchLine line) =>
                              line.item.medicationLabel,
                        )
                        .where((String label) => label.trim().isNotEmpty)
                        .join(', ');
                    final String? direct = item.labelParams['medication']
                        ?.toString()
                        .trim();
                    final String medicationLabel = medications.isNotEmpty
                        ? medications
                        : (direct == null || direct.isEmpty ? '' : direct);

                    return PharmacyPrintSelectableTile(
                      selected: controller.selectedHistoryIds.contains(item.id),
                      emphasizeTitle: false,
                      icon: Icons.history_outlined,
                      title: pharmacyTimelineEventLabel(context, item),
                      subtitle: medicationLabel.isEmpty ? null : medicationLabel,
                      meta: <String>[
                        if (item.at != null)
                          AppFormatters.dateTime(
                            item.at!,
                            Localizations.localeOf(context),
                          ),
                        if (batch != null && batch.isNotEmpty) batch,
                      ].join(' · '),
                      onChanged: (bool selected) {
                        controller.setHistorySelected(item.id, selected);
                      },
                    );
                  },
                ),
              ],
          ],
        );
      },
    );
  }
}
