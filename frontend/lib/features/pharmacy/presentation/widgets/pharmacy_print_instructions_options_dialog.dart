import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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

Future<PharmacyPrintInstructionsOptions?> showPharmacyPrintInstructionsOptionsDialog(
  BuildContext context, {
  required PharmacyOrderWorkflow workflow,
}) {
  return showDialog<PharmacyPrintInstructionsOptions>(
    context: context,
    builder: (_) => _PharmacyPrintInstructionsOptionsDialog(workflow: workflow),
  );
}

class _PharmacyPrintInstructionsOptionsDialog extends StatefulWidget {
  const _PharmacyPrintInstructionsOptionsDialog({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  State<_PharmacyPrintInstructionsOptionsDialog> createState() =>
      _PharmacyPrintInstructionsOptionsDialogState();
}

class _PharmacyPrintInstructionsOptionsDialogState
    extends State<_PharmacyPrintInstructionsOptionsDialog> {
  late final Set<String> _selectedItemIds;
  late final Set<String> _selectedHistoryIds;
  bool _hideZeroQuantity = true;
  bool _hidePartiallyDispensed = false;
  bool _includeHistory = false;
  bool _selectAllHistory = true;

  List<PharmacyOrderItem> get _items {
    final PharmacyOrderWorkflow workflow = widget.workflow;
    return workflow.items.isEmpty ? workflow.order.items : workflow.items;
  }

  List<PharmacyTimelineItem> get _history => widget.workflow.timeline;

  @override
  void initState() {
    super.initState();
    _selectedItemIds = _items.map((PharmacyOrderItem item) => item.id).toSet();
    _selectedHistoryIds = _history
        .map((PharmacyTimelineItem item) => item.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.pharmacyPrintInstructionsOptionsTitle),
      icon: const Icon(Icons.print_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.pharmacyPrintSelectMedicationsLabel,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          for (final PharmacyOrderItem item in _items)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _selectedItemIds.contains(item.id),
              title: Text(item.medicationLabel),
              subtitle: Text(item.simplifiedDoseLine),
              onChanged: (bool? checked) {
                setState(() {
                  if (checked == true) {
                    _selectedItemIds.add(item.id);
                  } else {
                    _selectedItemIds.remove(item.id);
                  }
                });
              },
            ),
          SizedBox(height: theme.spacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pharmacyPrintHideZeroQuantityLabel),
            value: _hideZeroQuantity,
            onChanged: (bool value) =>
                setState(() => _hideZeroQuantity = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pharmacyPrintHidePartialLabel),
            value: _hidePartiallyDispensed,
            onChanged: (bool value) =>
                setState(() => _hidePartiallyDispensed = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pharmacyPrintIncludeHistoryLabel),
            value: _includeHistory,
            onChanged: (bool value) => setState(() => _includeHistory = value),
          ),
          if (_includeHistory) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pharmacyPrintSelectAllHistoryLabel),
              value: _selectAllHistory,
              onChanged: (bool value) {
                setState(() {
                  _selectAllHistory = value;
                  if (value) {
                    _selectedHistoryIds
                      ..clear()
                      ..addAll(
                        _history.map((PharmacyTimelineItem item) => item.id),
                      );
                  } else {
                    _selectedHistoryIds.clear();
                  }
                });
              },
            ),
            Text(
              l10n.pharmacyPrintSelectHistoryLabel,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.sm),
            for (final PharmacyTimelineItem item in _history)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selectedHistoryIds.contains(item.id),
                title: Text(pharmacyTimelineEventLabel(context, item)),
                onChanged: (bool? checked) {
                  setState(() {
                    _selectAllHistory = false;
                    if (checked == true) {
                      _selectedHistoryIds.add(item.id);
                    } else {
                      _selectedHistoryIds.remove(item.id);
                    }
                  });
                },
              ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.pharmacyPrintInstructionsAction,
          leadingIcon: Icons.print_outlined,
          onPressed: _selectedItemIds.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    PharmacyPrintInstructionsOptions(
                      selectedItemIds: Set<String>.from(_selectedItemIds),
                      hideZeroQuantity: _hideZeroQuantity,
                      hidePartiallyDispensed: _hidePartiallyDispensed,
                      includeHistory: _includeHistory,
                      selectedHistoryIds: _includeHistory
                          ? Set<String>.from(_selectedHistoryIds)
                          : <String>{},
                    ),
                  );
                },
        ),
      ],
    );
  }
}
