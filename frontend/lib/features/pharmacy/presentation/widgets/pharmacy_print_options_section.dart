import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Snapshot of pharmacy medication-instructions print filters.
@immutable
final class PharmacyPrintInstructionsOptions {
  const PharmacyPrintInstructionsOptions({
    required this.selectedItemIds,
    required this.hideZeroQuantity,
    required this.hidePartiallyDispensed,
    required this.includeHistory,
    required this.selectedHistoryIds,
  });

  final Set<String> selectedItemIds;
  final bool hideZeroQuantity;
  final bool hidePartiallyDispensed;
  final bool includeHistory;
  final Set<String> selectedHistoryIds;
}

/// Mutable print-option state for live medication-instructions preview rebuilds.
final class PharmacyPrintOptionsController extends ChangeNotifier {
  PharmacyPrintOptionsController(this.workflow) {
    _selectedItemIds = items.map((PharmacyOrderItem item) => item.id).toSet();
    _selectedHistoryIds =
        history.map((PharmacyTimelineItem item) => item.id).toSet();
  }

  final PharmacyOrderWorkflow workflow;

  late final Set<String> _selectedItemIds;
  late final Set<String> _selectedHistoryIds;
  bool _hideZeroQuantity = true;
  bool _hidePartiallyDispensed = false;
  bool _includeHistory = false;
  bool _selectAllHistory = true;

  List<PharmacyOrderItem> get items {
    return workflow.items.isEmpty ? workflow.order.items : workflow.items;
  }

  List<PharmacyTimelineItem> get history => workflow.timeline;

  Set<String> get selectedItemIds => Set<String>.unmodifiable(_selectedItemIds);

  bool get hideZeroQuantity => _hideZeroQuantity;

  bool get hidePartiallyDispensed => _hidePartiallyDispensed;

  bool get includeHistory => _includeHistory;

  bool get selectAllHistory => _selectAllHistory;

  Set<String> get selectedHistoryIds =>
      Set<String>.unmodifiable(_selectedHistoryIds);

  bool get canPrint => _selectedItemIds.isNotEmpty;

  List<PharmacyTimelineItem> get selectedHistoryItems {
    if (!_includeHistory) {
      return const <PharmacyTimelineItem>[];
    }
    return history
        .where(
          (PharmacyTimelineItem item) => _selectedHistoryIds.contains(item.id),
        )
        .toList(growable: false);
  }

  PharmacyPrintInstructionsOptions get snapshot {
    return PharmacyPrintInstructionsOptions(
      selectedItemIds: selectedItemIds,
      hideZeroQuantity: _hideZeroQuantity,
      hidePartiallyDispensed: _hidePartiallyDispensed,
      includeHistory: _includeHistory,
      selectedHistoryIds:
          _includeHistory ? selectedHistoryIds : const <String>{},
    );
  }

  void setItemSelected(String itemId, bool selected) {
    if (selected) {
      _selectedItemIds.add(itemId);
    } else {
      _selectedItemIds.remove(itemId);
    }
    notifyListeners();
  }

  void setHideZeroQuantity(bool value) {
    if (_hideZeroQuantity == value) {
      return;
    }
    _hideZeroQuantity = value;
    notifyListeners();
  }

  void setHidePartiallyDispensed(bool value) {
    if (_hidePartiallyDispensed == value) {
      return;
    }
    _hidePartiallyDispensed = value;
    notifyListeners();
  }

  void setIncludeHistory(bool value) {
    if (_includeHistory == value) {
      return;
    }
    _includeHistory = value;
    notifyListeners();
  }

  void setSelectAllHistory(bool value) {
    _selectAllHistory = value;
    if (value) {
      _selectedHistoryIds
        ..clear()
        ..addAll(history.map((PharmacyTimelineItem item) => item.id));
    } else {
      _selectedHistoryIds.clear();
    }
    notifyListeners();
  }

  void setHistorySelected(String historyId, bool selected) {
    _selectAllHistory = false;
    if (selected) {
      _selectedHistoryIds.add(historyId);
    } else {
      _selectedHistoryIds.remove(historyId);
    }
    notifyListeners();
  }
}

/// Collapsible print-options section for the medication-instructions preview.
class PharmacyPrintOptionsSection extends StatelessWidget {
  const PharmacyPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final PharmacyPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return AppFormSection(
          title: l10n.pharmacyPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.pharmacyPrintSelectMedicationsLabel,
                    style: theme.textTheme.titleSmall,
                  ),
                  SizedBox(height: theme.spacing.sm),
                  for (final PharmacyOrderItem item in controller.items)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: controller.selectedItemIds.contains(item.id),
                      title: Text(item.medicationLabel),
                      subtitle: Text(item.simplifiedDoseLine),
                      onChanged: (bool? checked) {
                        controller.setItemSelected(item.id, checked == true);
                      },
                    ),
                  SizedBox(height: theme.spacing.md),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.pharmacyPrintHideZeroQuantityLabel),
                    value: controller.hideZeroQuantity,
                    onChanged: (bool? checked) {
                      controller.setHideZeroQuantity(checked == true);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.pharmacyPrintHidePartialLabel),
                    value: controller.hidePartiallyDispensed,
                    onChanged: (bool? checked) {
                      controller.setHidePartiallyDispensed(checked == true);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.pharmacyPrintIncludeHistoryLabel),
                    value: controller.includeHistory,
                    onChanged: (bool? checked) {
                      controller.setIncludeHistory(checked == true);
                    },
                  ),
                  if (controller.includeHistory) ...<Widget>[
                    SizedBox(height: theme.spacing.sm),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.pharmacyPrintSelectAllHistoryLabel),
                      value: controller.selectAllHistory,
                      onChanged: (bool? checked) {
                        controller.setSelectAllHistory(checked == true);
                      },
                    ),
                    Text(
                      l10n.pharmacyPrintSelectHistoryLabel,
                      style: theme.textTheme.titleSmall,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    for (final PharmacyTimelineItem item in controller.history)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: controller.selectedHistoryIds.contains(item.id),
                        title: Text(pharmacyTimelineEventLabel(context, item)),
                        onChanged: (bool? checked) {
                          controller.setHistorySelected(
                            item.id,
                            checked == true,
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
