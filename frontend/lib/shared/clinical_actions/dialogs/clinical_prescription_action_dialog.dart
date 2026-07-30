import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_resolve.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalPrescriptionActionDialog extends StatefulWidget {
  const ClinicalPrescriptionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    this.payerContext,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final ClinicalRequestPayerContext? payerContext;
  final Future<AppFailure?> Function({
    required List<Map<String, Object?>> items,
    ClinicalRequestBillingSubmit? billing,
  })
  onSubmit;

  @override
  State<ClinicalPrescriptionActionDialog> createState() =>
      _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<ClinicalPrescriptionActionDialog> {
  static const String _columnVisibilityStorageKey =
      'clinical_prescription_selected_medicines_columns';
  static const String _selectColumnKey = 'select';
  static const String _medicineColumnKey = 'medicine';
  static const String _doseColumnKey = 'dose';
  static const String _sigColumnKey = 'sig';
  static const String _quantityColumnKey = 'quantity';
  static const String _durationColumnKey = 'duration';
  static const String _instructionsColumnKey = 'instructions';
  static const String _priceColumnKey = 'price';
  static const String _actionsColumnKey = 'actions';
  static const String _routeFilterKey = 'route';
  static const String _frequencyFilterKey = 'frequency';

  final List<_PrescriptionLineFormState> _lines =
      <_PrescriptionLineFormState>[];
  final Set<String> _selectedLineKeys = <String>{};
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<_PrescriptionLineFormState>
  _columnVisibilityController;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  int _nextLineId = 0;
  bool _isSaving = false;
  AppFailure? _failure;
  ClinicalRequestBillingSubmit? _billingSubmit;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<_PrescriptionLineFormState>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    for (final _PrescriptionLineFormState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<_PrescriptionLineFormState> visibleLines = _lines
        .where(_matchesOptionFilters)
        .toList(growable: false);
    final List<AppListTableColumn<_PrescriptionLineFormState>> defaultColumns =
        _defaultColumns(context);
    final List<AppListTableColumn<_PrescriptionLineFormState>> columnChoices =
        _columnChoices(context);

    return AppDialog(
      title: Text(l10n.clinicalPrescribeAction),
      icon: const Icon(Icons.medication_outlined),
      maxWidth: 880,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Expanded(
            child: AppListTable<_PrescriptionLineFormState>(
              items: visibleLines,
              columns: defaultColumns,
              columnChoices: columnChoices,
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: _columnVisibilityStorageKey,
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle: l10n.clinicalPrescriptionColumnsTitle,
              columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
              columnVisibilityResetLabel: l10n.labResetColumnsAction,
              displayMode: AppListTableDisplayMode.table,
              tableHorizontalMargin: theme.spacing.sm,
              showRowNumbers: false,
              itemKeyBuilder: (_PrescriptionLineFormState line) =>
                  ValueKey<String>(_lineKey(line)),
              search: AppListTableSearch<_PrescriptionLineFormState>(
                controller: _searchController,
                semanticLabel: l10n.clinicalPrescriptionSearchLabel,
                hintText: l10n.clinicalPrescriptionSearchHint,
                enabled: !_isSaving,
                matcher: _matchesSearch,
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.clinicalFiltersLabel,
                advancedFilterTitle: l10n.clinicalFiltersLabel,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.labScopeAll,
                filterGroups: _filterGroups(l10n),
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
                trailingActions: _searchTrailingActions(l10n),
              ),
              emptyBuilder: (BuildContext context) {
                final bool hasQueryOrFilters =
                    _searchController.text.trim().isNotEmpty ||
                    _filterValue.isActive;
                return Padding(
                  padding: EdgeInsets.all(theme.spacing.lg),
                  child: Center(
                    child: Text(
                      hasQueryOrFilters
                          ? l10n.clinicalPrescriptionEmptySearchLabel
                          : l10n.clinicalPrescriptionNoMedicinesLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
              mobileItemBuilder:
                  (BuildContext context, _PrescriptionLineFormState line) {
                    final String key = _lineKey(line);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppListTableMobileItem(
                          title: _medicineName(line, l10n),
                          caption: _doseLabel(line),
                          meta: <AppListTableMobileMeta>[
                            AppListTableMobileMeta(label: _sigLabel(line)),
                            AppListTableMobileMeta(label: _quantityLabel(line)),
                          ],
                          showAvatar: false,
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: theme.spacing.sm,
                            right: theme.spacing.sm,
                            bottom: theme.spacing.sm,
                          ),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: _selectedLineKeys.contains(key),
                                onChanged: _isSaving
                                    ? null
                                    : (bool? value) =>
                                          _toggleKey(key, value ?? false),
                                visualDensity: VisualDensity.compact,
                              ),
                              AppButton.tertiary(
                                label: l10n.clinicalPrescriptionEditLineDialogTitle,
                                leadingIcon: Icons.edit_outlined,
                                enabled: !_isSaving,
                                onPressed: () => unawaited(
                                  _openLineDialog(editIndex: _lineIndex(line)),
                                ),
                              ),
                              AppButton.tertiary(
                                label: l10n.clinicalRequestRemoveItemAction,
                                leadingIcon: Icons.delete_outline,
                                color: theme.colorScheme.error,
                                enabled: !_isSaving,
                                onPressed: () =>
                                    unawaited(_confirmAndDeleteLine(line)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalPrescribeAction,
          leadingIcon: Icons.send_outlined,
          isLoading: _isSaving,
          enabled: !_isSaving && _lines.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<AppSearchBarAction> _searchTrailingActions(AppLocalizations l10n) {
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.delete_outline,
        label: l10n.clinicalRequestRemoveSelectedAction,
        enabled: !_isSaving && _selectedLineKeys.isNotEmpty,
        destructive: true,
        onPressed: _selectedLineKeys.isEmpty || _isSaving
            ? null
            : () => unawaited(_confirmAndDeleteSelected()),
      ),
      AppSearchBarAction(
        icon: Icons.add_circle_outline,
        label: l10n.clinicalPrescriptionAddMedicineAction,
        enabled: !_isSaving,
        onPressed: _isSaving ? null : () => unawaited(_openLineDialog()),
      ),
      AppSearchBarAction(
        icon: Icons.payments_outlined,
        label: l10n.clinicalRequestReviewBillingAction,
        enabled: !_isSaving && _lines.isNotEmpty,
        onPressed: _lines.isEmpty || _isSaving
            ? null
            : () => unawaited(_openBillingDialog()),
      ),
    ];
  }

  List<AppListTableColumn<_PrescriptionLineFormState>> _defaultColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<_PrescriptionLineFormState>>[
      _selectionColumn(context),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _medicineColumnKey,
        label: l10n.clinicalPrescriptionMedicineLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(
                  _medicineName(left, l10n),
                  _medicineName(right, l10n),
                ),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_medicineName(line, l10n));
        },
      ),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _doseColumnKey,
        label: l10n.clinicalDoseAmountLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(_doseLabel(left), _doseLabel(right)),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_doseLabel(line));
        },
      ),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _sigColumnKey,
        label: l10n.clinicalPrescriptionSigColumnLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(_sigLabel(left), _sigLabel(right)),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_sigLabel(line));
        },
      ),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _quantityColumnKey,
        label: l10n.opdDrugQuantityLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(
                  _quantityLabel(left),
                  _quantityLabel(right),
                ),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_quantityLabel(line));
        },
      ),
      _actionsColumn(context),
    ];
  }

  List<AppListTableColumn<_PrescriptionLineFormState>> _columnChoices(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<_PrescriptionLineFormState>>[
      ..._defaultColumns(context),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _durationColumnKey,
        label: l10n.clinicalDurationValueLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(
                  _durationLabel(left),
                  _durationLabel(right),
                ),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_durationLabel(line));
        },
      ),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _instructionsColumnKey,
        label: l10n.clinicalInstructionsLabel,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) =>
                appListTableCompareText(
                  left.instructionsController.text,
                  right.instructionsController.text,
                ),
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          final String instructions = line.instructionsController.text.trim();
          return Text(instructions.isEmpty ? '—' : instructions);
        },
      ),
      AppListTableColumn<_PrescriptionLineFormState>(
        id: _priceColumnKey,
        label: l10n.clinicalRequestSelectedPriceColumnLabel,
        numeric: true,
        sortComparator:
            (_PrescriptionLineFormState left, _PrescriptionLineFormState right) {
              return (_unitPrice(left) ?? 0).compareTo(_unitPrice(right) ?? 0);
            },
        cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
          return Text(_priceLabel(context, line));
        },
      ),
    ];
  }

  AppListTableColumn<_PrescriptionLineFormState> _selectionColumn(
    BuildContext context,
  ) {
    final List<_PrescriptionLineFormState> visibleLines = _lines
        .where(_matchesOptionFilters)
        .where(
          (_PrescriptionLineFormState line) =>
              _matchesSearch(line, _searchController.text),
        )
        .toList(growable: false);
    return AppListTableColumn<_PrescriptionLineFormState>(
      id: _selectColumnKey,
      label: '',
      alwaysVisible: true,
      headerBuilder: (BuildContext context) {
        final bool allSelected =
            visibleLines.isNotEmpty &&
            visibleLines.every(
              (_PrescriptionLineFormState line) =>
                  _selectedLineKeys.contains(_lineKey(line)),
            );
        final bool someSelected = visibleLines.any(
          (_PrescriptionLineFormState line) =>
              _selectedLineKeys.contains(_lineKey(line)),
        );
        return Checkbox(
          tristate: true,
          value: allSelected
              ? true
              : someSelected
              ? null
              : false,
          onChanged: _isSaving || visibleLines.isEmpty
              ? null
              : (bool? checked) => _toggleAllVisible(checked ?? false),
          visualDensity: VisualDensity.compact,
        );
      },
      cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
        final String key = _lineKey(line);
        return Checkbox(
          value: _selectedLineKeys.contains(key),
          onChanged: _isSaving
              ? null
              : (bool? value) => _toggleKey(key, value ?? false),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  AppListTableColumn<_PrescriptionLineFormState> _actionsColumn(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppListTableColumn<_PrescriptionLineFormState>(
      id: _actionsColumnKey,
      label: l10n.clinicalRequestSelectedActionsColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, _PrescriptionLineFormState line) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.edit_outlined,
              label: l10n.clinicalPrescriptionEditLineDialogTitle,
              semanticLabel: l10n.clinicalPrescriptionEditLineDialogTitle,
              tooltip: l10n.clinicalPrescriptionEditLineDialogTitle,
              enabled: !_isSaving,
              onPressed: _isSaving
                  ? null
                  : () => unawaited(
                      _openLineDialog(editIndex: _lineIndex(line)),
                    ),
            ),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.clinicalRequestRemoveItemAction,
              semanticLabel: l10n.clinicalRequestRemoveItemAction,
              tooltip: l10n.clinicalRequestRemoveItemAction,
              enabled: !_isSaving,
              color: colorScheme.error,
              onPressed: _isSaving
                  ? null
                  : () => unawaited(_confirmAndDeleteLine(line)),
            ),
          ],
        );
      },
    );
  }

  List<AppSearchBarFilterGroup> _filterGroups(AppLocalizations l10n) {
    final Set<String> routes = <String>{
      for (final _PrescriptionLineFormState line in _lines)
        if ((line.route ?? '').trim().isNotEmpty) line.route!.trim(),
    };
    final Set<String> frequencies = <String>{
      for (final _PrescriptionLineFormState line in _lines)
        if ((line.frequency ?? '').trim().isNotEmpty) line.frequency!.trim(),
    };
    return <AppSearchBarFilterGroup>[
      if (routes.isNotEmpty)
        AppSearchBarFilterGroup(
          key: _routeFilterKey,
          label: l10n.opdMedicationRouteLabel,
          allLabel: l10n.labScopeAll,
          choices: <AppSearchBarFilterChoice>[
            for (final String route in routes.toList()..sort())
              AppSearchBarFilterChoice(
                value: route,
                label: clinicalActionApiLabel(route),
              ),
          ],
        ),
      if (frequencies.isNotEmpty)
        AppSearchBarFilterGroup(
          key: _frequencyFilterKey,
          label: l10n.opdFrequencyLabel,
          allLabel: l10n.labScopeAll,
          choices: <AppSearchBarFilterChoice>[
            for (final String frequency in frequencies.toList()..sort())
              AppSearchBarFilterChoice(
                value: frequency,
                label: clinicalFrequencyReadable(frequency),
              ),
          ],
        ),
    ];
  }

  bool _matchesOptionFilters(_PrescriptionLineFormState line) {
    final String? route = _filterValue.option(_routeFilterKey);
    if (route != null && line.route != route) {
      return false;
    }
    final String? frequency = _filterValue.option(_frequencyFilterKey);
    if (frequency != null && line.frequency != frequency) {
      return false;
    }
    return true;
  }

  bool _matchesSearch(_PrescriptionLineFormState line, String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final AppLocalizations l10n = context.l10n;
    final String haystack = <String>[
      _medicineName(line, l10n),
      _doseLabel(line),
      _sigLabel(line),
      _quantityLabel(line),
      _durationLabel(line),
      line.instructionsController.text,
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  String _lineKey(_PrescriptionLineFormState line) => line.id.toString();

  int _lineIndex(_PrescriptionLineFormState line) {
    return _lines.indexWhere(
      (_PrescriptionLineFormState item) => item.id == line.id,
    );
  }

  void _toggleKey(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedLineKeys.add(key);
      } else {
        _selectedLineKeys.remove(key);
      }
    });
  }

  void _toggleAllVisible(bool selected) {
    final Iterable<String> visibleKeys = _lines
        .where(_matchesOptionFilters)
        .where(
          (_PrescriptionLineFormState line) =>
              _matchesSearch(line, _searchController.text),
        )
        .map(_lineKey);
    setState(() {
      if (!selected) {
        _selectedLineKeys.removeAll(visibleKeys);
        return;
      }
      _selectedLineKeys.addAll(visibleKeys);
    });
  }

  void _pruneSelection() {
    final Set<String> validKeys = _lines.map(_lineKey).toSet();
    _selectedLineKeys.removeWhere((String key) => !validKeys.contains(key));
  }

  String _medicineName(_PrescriptionLineFormState line, AppLocalizations l10n) {
    return clinicalActionCatalogDisplayLabelById(
          widget.referenceData.drugs,
          line.drugId,
        ) ??
        l10n.clinicalPrescriptionMedicineLabel;
  }

  String _doseLabel(_PrescriptionLineFormState line) {
    return clinicalActionJoinDisplay(<String?>[
      clinicalActionTrimmedOrNull(line.doseAmountController.text),
      clinicalActionTrimmedOrNull(line.doseUnit),
    ], separator: ' ');
  }

  String _sigLabel(_PrescriptionLineFormState line) {
    return clinicalActionJoinDisplay(<String?>[
      if ((line.route ?? '').trim().isNotEmpty)
        clinicalActionApiLabel(line.route!.trim()),
      if ((line.frequency ?? '').trim().isNotEmpty)
        clinicalFrequencyReadable(line.frequency!.trim()),
    ], separator: ' · ');
  }

  String _quantityLabel(_PrescriptionLineFormState line) {
    return clinicalActionJoinDisplay(<String?>[
      clinicalActionTrimmedOrNull(line.quantityController.text),
      clinicalActionTrimmedOrNull(line.quantityUnit),
    ], separator: ' ');
  }

  String _durationLabel(_PrescriptionLineFormState line) {
    return clinicalActionJoinDisplay(<String?>[
      clinicalActionTrimmedOrNull(line.durationController.text),
      clinicalActionTrimmedOrNull(line.durationUnit),
    ], separator: ' ');
  }

  ClinicalActionCatalogOption? _drugOption(_PrescriptionLineFormState line) {
    final String? drugId = line.drugId?.trim();
    if (drugId == null || drugId.isEmpty) {
      return null;
    }
    for (final ClinicalActionCatalogOption drug
        in widget.referenceData.drugs) {
      if (drug.apiId == drugId) {
        return drug;
      }
    }
    return ClinicalActionCatalogOption(
      id: drugId,
      name: clinicalActionCatalogDisplayLabelById(
        widget.referenceData.drugs,
        drugId,
      ),
    );
  }

  num? _unitPrice(_PrescriptionLineFormState line) {
    final ClinicalActionCatalogOption? option = _drugOption(line);
    return option == null ? null : clinicalCatalogOptionUnitPrice(option);
  }

  String _priceLabel(BuildContext context, _PrescriptionLineFormState line) {
    final ClinicalActionCatalogOption? option = _drugOption(line);
    if (option == null) {
      return '—';
    }
    return clinicalRequestCatalogPriceLabel(context, option);
  }

  Future<void> _openLineDialog({int? editIndex}) async {
    final List<AppSelectOption<String>> drugOptions = _drugCatalogOptions(
      widget.referenceData.drugs,
    );
    final _PrescriptionLineFormState line = editIndex == null
        ? _createLine()
        : _lines[editIndex];
    final bool isNew = editIndex == null;

    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (BuildContext context) {
        final AppLocalizations l10n = context.l10n;
        final GlobalKey<FormState> lineFormKey = GlobalKey<FormState>();
        return AppDialog(
          title: Text(
            isNew
                ? l10n.clinicalPrescriptionLineDialogTitle
                : l10n.clinicalPrescriptionEditLineDialogTitle,
          ),
          icon: const Icon(Icons.medication_outlined),
          maxWidth: 640,
          scrollable: true,
          content: Form(
            key: lineFormKey,
            child: _PrescriptionLineCard(
              key: ValueKey<int>(line.id),
              index: editIndex ?? _lines.length,
              line: line,
              drugOptions: drugOptions,
              selectedDrugLabel: clinicalActionCatalogDisplayLabelById(
                widget.referenceData.drugs,
                line.drugId,
              ),
              enabled: !_isSaving,
              canRemove: false,
              onChanged: () {},
              onRemove: () {},
            ),
          ),
          actions: <Widget>[
            AppButton.tertiary(
              label: l10n.commonCancelActionLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppButton.primary(
              label: l10n.clinicalRequestCatalogPickerDoneAction,
              onPressed: () {
                if (!(lineFormKey.currentState?.validate() ?? false)) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (!mounted || saved != true) {
      if (isNew) {
        line.dispose();
      }
      return;
    }

    setState(() {
      if (isNew) {
        _lines.add(line);
      }
      _failure = null;
    });
  }

  Future<void> _openBillingDialog() async {
    final List<ClinicalRequestBillingLineItem> fallback =
        _prescriptionBillingLineItems()
            .map(
              (ClinicalRequestBillingLineItem item) => item.copyWith(
                catalogType: item.catalogType ?? 'DRUG',
                billingEntity: item.billingEntity ?? 'FACILITY',
              ),
            )
            .toList(growable: false);
    final List<ClinicalRequestBillingLineItem> resolved =
        await resolveClinicalRequestBillingLineItems(
          context: context,
          catalogFallbackItems: fallback,
          billingEntity: 'FACILITY',
          payerContext: widget.payerContext,
        );
    if (!mounted) {
      return;
    }
    final ClinicalRequestBillingSubmit? billing =
        await showClinicalRequestBillingDialog(
          context: context,
          lineItems: resolved,
          initialBilling: _billingSubmit,
          billingEntity: 'FACILITY',
          payerContext: widget.payerContext,
          enabled: !_isSaving,
        );
    if (!mounted || billing == null) {
      return;
    }
    setState(() => _billingSubmit = billing);
  }

  Future<void> _confirmAndDeleteLine(_PrescriptionLineFormState line) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: <ClinicalRequestRemovePreviewItem>[
            ClinicalRequestRemovePreviewItem(
              name: _medicineName(line, l10n),
              typeLabel: l10n.clinicalPrescriptionMedicineLabel,
            ),
          ],
        );
    if (!confirmed || !mounted) {
      return;
    }
    _removeLine(line);
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedLineKeys.isEmpty) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final List<_PrescriptionLineFormState> selected = _lines
        .where(
          (_PrescriptionLineFormState line) =>
              _selectedLineKeys.contains(_lineKey(line)),
        )
        .toList(growable: false);
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: selected
              .map(
                (_PrescriptionLineFormState line) =>
                    ClinicalRequestRemovePreviewItem(
                      name: _medicineName(line, l10n),
                      typeLabel: l10n.clinicalPrescriptionMedicineLabel,
                    ),
              )
              .toList(growable: false),
        );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      final List<_PrescriptionLineFormState> removed = _lines
          .where(
            (_PrescriptionLineFormState line) =>
                _selectedLineKeys.contains(_lineKey(line)),
          )
          .toList(growable: false);
      _lines.removeWhere(
        (_PrescriptionLineFormState line) =>
            _selectedLineKeys.contains(_lineKey(line)),
      );
      for (final _PrescriptionLineFormState line in removed) {
        line.dispose();
      }
      _selectedLineKeys.clear();
      _failure = null;
    });
  }

  _PrescriptionLineFormState _createLine() {
    final _PrescriptionLineFormState line = _PrescriptionLineFormState(
      id: _nextLineId,
    );
    _nextLineId += 1;
    return line;
  }

  void _removeLine(_PrescriptionLineFormState line) {
    setState(() {
      _selectedLineKeys.remove(_lineKey(line));
      _lines.remove(line);
      line.dispose();
      _pruneSelection();
      _failure = null;
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      for (final _PrescriptionLineFormState line in _lines)
        _withoutEmptyValues(<String, Object?>{
          'drug_id': line.drugId,
          'quantity': int.tryParse(line.quantityController.text.trim()) ?? 1,
          'quantity_unit': line.quantityUnit,
          'dose_amount': num.tryParse(line.doseAmountController.text.trim()),
          'dose_unit': line.doseUnit,
          'route': line.route,
          'frequency': line.frequency,
          'duration_value': int.tryParse(line.durationController.text.trim()),
          'duration_unit': line.durationController.text.trim().isEmpty
              ? null
              : line.durationUnit,
          'instructions': line.instructionsController.text.trim(),
        }),
    ];

    // Always attach request-time billing (bill-later when not reviewed).
    final ClinicalRequestBillingSubmit? billing = _pendingBillingSubmit();
    final AppFailure? failure = await widget.onSubmit(
      items: items,
      billing: billing,
    );
    _finishSubmit(failure);
  }

  ClinicalRequestBillingSubmit? _pendingBillingSubmit() {
    if (_billingSubmit != null) {
      return _billingSubmit;
    }
    final List<ClinicalRequestBillingLineItem> lineItems =
        _prescriptionBillingLineItems();
    if (lineItems.isEmpty) {
      return null;
    }
    final num total = clinicalRequestBillingTotal(lineItems);
    return ClinicalRequestBillingSubmit(
      mode: ClinicalRequestPaymentMode.billLater,
      totalAmount: total,
      currency: resolveClinicalRequestBillingCurrency(lineItems),
      paymentStatus: ClinicalRequestPaymentStatus.unpaid,
      lineItems: lineItems,
      billingEntity: 'FACILITY',
    );
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  List<ClinicalRequestBillingLineItem> _prescriptionBillingLineItems() {
    final List<ClinicalActionCatalogOption> options =
        <ClinicalActionCatalogOption>[];
    final Map<String, num> quantities = <String, num>{};
    for (final _PrescriptionLineFormState line in _lines) {
      final String? drugId = line.drugId?.trim();
      if (drugId == null || drugId.isEmpty) {
        continue;
      }
      quantities[drugId] =
          int.tryParse(line.quantityController.text.trim()) ?? 1;
      final ClinicalActionCatalogOption? option = _drugOption(line);
      if (option != null) {
        options.add(option);
      }
    }
    return clinicalRequestBillingLineItems(
      options: options,
      quantities: quantities,
    );
  }
}

class _PrescriptionLineFormState {
  _PrescriptionLineFormState({required this.id})
    : quantityController = TextEditingController(text: '1'),
      doseAmountController = TextEditingController(),
      durationController = TextEditingController(),
      instructionsController = TextEditingController();

  final int id;
  final TextEditingController quantityController;
  final TextEditingController doseAmountController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  String? drugId;
  String? quantityUnit;
  String? doseUnit;
  String? route = 'ORAL';
  String? frequency = 'BID';
  String? durationUnit = 'days';

  void dispose() {
    quantityController.dispose();
    doseAmountController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
}

class _PrescriptionLineCard extends StatelessWidget {
  const _PrescriptionLineCard({
    required this.index,
    required this.line,
    required this.drugOptions,
    required this.selectedDrugLabel,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _PrescriptionLineFormState line;
  final List<AppSelectOption<String>> drugOptions;
  final String? selectedDrugLabel;
  final bool enabled;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            _PrescriptionLineHeader(
              index: index,
              line: line,
              selectedDrugLabel: selectedDrugLabel,
              canRemove: canRemove,
              onRemove: onRemove,
            ),
            AppSelectField<String>.searchable(
              value: line.drugId,
              labelText: l10n.clinicalPrescriptionDrugLabel,
              enabled: enabled,
              isRequired: true,
              options: drugOptions,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (String? value) {
                line.drugId = value;
                onChanged();
              },
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.quantityController,
                  labelText: l10n.opdDrugQuantityLabel,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _requiredPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.quantityUnit,
                  labelText: l10n.clinicalPrescriptionQuantityUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_quantityUnits),
                  onChanged: (String? value) {
                    line.quantityUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.doseAmountController,
                  labelText: l10n.clinicalDoseAmountLabel,
                  prefixIcon: const Icon(Icons.science_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalFormatters,
                  validator: (String? value) =>
                      _requiredPositiveNumberValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.doseUnit,
                  labelText: l10n.clinicalDoseUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_doseUnits),
                  onChanged: (String? value) {
                    line.doseUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppSelectField<String>.searchable(
                  value: line.route,
                  labelText: l10n.opdMedicationRouteLabel,
                  enabled: enabled,
                  options: _medicationRouteOptions(),
                  onChanged: (String? value) {
                    line.route = value;
                    onChanged();
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.frequency,
                  labelText: l10n.opdFrequencyLabel,
                  enabled: enabled,
                  options: _medicationFrequencyOptions(),
                  onChanged: (String? value) {
                    line.frequency = value;
                    onChanged();
                  },
                ),
              ],
            ),
            _PrescriptionDurationField(
              line: line,
              enabled: enabled,
              onChanged: onChanged,
            ),
            AppTextField(
              controller: line.instructionsController,
              labelText: l10n.clinicalInstructionsLabel,
              prefixIcon: const Icon(Icons.notes_outlined),
              enabled: enabled,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionLineHeader extends StatelessWidget {
  const _PrescriptionLineHeader({
    required this.index,
    required this.line,
    required this.selectedDrugLabel,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _PrescriptionLineFormState line;
  final String? selectedDrugLabel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fallback = l10n.clinicalPrescriptionItemDescription;
    final String preview = clinicalPrescriptionReadableSummary(
      drugName: selectedDrugLabel,
      quantity: line.quantityController.text.trim(),
      quantityUnit: line.quantityUnit,
      doseAmount: line.doseAmountController.text.trim(),
      doseUnit: line.doseUnit,
      route: line.route,
      frequency: line.frequency,
      durationValue: line.durationController.text.trim(),
      durationUnit: line.durationUnit,
      instructions: line.instructionsController.text.trim(),
    );

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Icon(
              Icons.medication_outlined,
              color: colorScheme.onSecondaryContainer,
              size: theme.appTokens.listIconSize,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${l10n.clinicalPrescriptionMedicineLabel} ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                selectedDrugLabel ?? fallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (line.drugId != null)
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.delete_outline,
          label: l10n.clinicalPrescriptionRemoveMedicineAction,
          semanticLabel: l10n.clinicalPrescriptionRemoveMedicineAction,
          tooltip: l10n.clinicalPrescriptionRemoveMedicineAction,
          enabled: canRemove,
          onPressed: canRemove ? onRemove : null,
        ),
      ],
    );
  }
}

class _PrescriptionDurationField extends StatelessWidget {
  const _PrescriptionDurationField({
    required this.line,
    required this.enabled,
    required this.onChanged,
  });

  final _PrescriptionLineFormState line;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_repeat_outlined,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.xs),
                Text(
                  l10n.clinicalDurationValueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.durationController,
                  labelText: l10n.clinicalDurationValueLabel,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _optionalPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.durationUnit,
                  labelText: l10n.clinicalDurationUnitLabel,
                  enabled: enabled,
                  options: _durationUnitOptions(),
                  validator: (String? value) {
                    final bool hasDuration = line.durationController.text
                        .trim()
                        .isNotEmpty;
                    return hasDuration && value == null
                        ? l10n.validationRequired
                        : null;
                  },
                  onChanged: (String? value) {
                    line.durationUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<AppSelectOption<String>> _drugCatalogOptions(
  List<ClinicalActionCatalogOption> options,
) {
  return <AppSelectOption<String>>[
    for (final ClinicalActionCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: clinicalActionJoinDisplay(<String?>[
          option.displayTitle,
          option.displaySubtitle,
        ]),
        leadingIcon: const Icon(Icons.medication_outlined),
      ),
  ];
}

List<AppSelectOption<String>> _unitOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: value),
  ];
}

List<AppSelectOption<String>> _durationUnitOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _durationUnits)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
        leadingIcon: const Icon(Icons.event_repeat_outlined),
      ),
  ];
}

List<AppSelectOption<String>> _medicationRouteOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationRoutes)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
        leadingIcon: Icon(_medicationRouteIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _medicationFrequencyOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationFrequencies)
      AppSelectOption<String>(
        value: value,
        label: _medicationFrequencyLabel(value),
        leadingIcon: Icon(_medicationFrequencyIcon(value)),
      ),
  ];
}

String _medicationFrequencyLabel(String value) {
  final String? description = switch (value) {
    'ONCE' => 'One time',
    'OD' => 'Once daily',
    'BID' => 'Twice daily',
    'TID' => 'Three times daily',
    'QID' => 'Four times daily',
    'Q4H' => 'Every 4 hours',
    'Q6H' => 'Every 6 hours',
    'Q8H' => 'Every 8 hours',
    'Q12H' => 'Every 12 hours',
    'QHS' => 'At bedtime',
    'WEEKLY' => 'Weekly',
    'PRN' => 'As needed',
    'STAT' => 'Immediately',
    'CUSTOM' => 'Custom',
    _ => null,
  };
  return description == null
      ? clinicalActionApiLabel(value)
      : '$value - $description';
}

IconData _medicationFrequencyIcon(String value) {
  return switch (value) {
    'STAT' => Icons.priority_high_outlined,
    'PRN' => Icons.help_outline,
    'Q4H' || 'Q6H' || 'Q8H' || 'Q12H' || 'QHS' => Icons.schedule_outlined,
    'WEEKLY' => Icons.event_repeat_outlined,
    'CUSTOM' => Icons.tune_outlined,
    _ => Icons.repeat_outlined,
  };
}

IconData _medicationRouteIcon(String value) {
  return switch (value) {
    'IV' => Icons.water_drop_outlined,
    'IM' || 'SC' || 'INTRADERMAL' => Icons.vaccines_outlined,
    'TOPICAL' => Icons.spa_outlined,
    'INHALATION' || 'NASAL' => Icons.air_outlined,
    'OPHTHALMIC' => Icons.visibility_outlined,
    'OTIC' => Icons.hearing_outlined,
    'ORAL' || 'SUBLINGUAL' => Icons.medication_outlined,
    _ => Icons.medical_services_outlined,
  };
}

String? _requiredPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _optionalPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _requiredPositiveNumberValidator(AppLocalizations l10n, String? value) {
  final String normalized = value?.trim() ?? '';
  final num? parsed = num.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

Map<String, Object?> _withoutEmptyValues(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPrescriptionValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPrescriptionValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable<Object?>) {
    return value.isEmpty;
  }
  if (value is Map<Object?, Object?>) {
    return value.isEmpty;
  }
  return false;
}

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'OD',
  'BID',
  'TID',
  'QID',
  'Q4H',
  'Q6H',
  'Q8H',
  'Q12H',
  'QHS',
  'WEEKLY',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'SUBLINGUAL',
  'RECTAL',
  'VAGINAL',
  'TOPICAL',
  'INHALATION',
  'OPHTHALMIC',
  'OTIC',
  'NASAL',
  'INTRADERMAL',
  'OTHER',
];

const List<String> _quantityUnits = <String>[
  'tablet',
  'capsule',
  'vial',
  'ampoule',
  'bottle',
  'tube',
  'sachet',
  'patch',
  'drop',
  'mL',
  'dose',
  'pack',
];

const List<String> _doseUnits = <String>[
  'mg',
  'g',
  'mcg',
  'mL',
  'IU',
  'unit',
  'tablet',
  'capsule',
  'drop',
  'puff',
  'sachet',
  'patch',
];

const List<String> _durationUnits = <String>[
  'hours',
  'days',
  'weeks',
  'months',
];

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

final List<TextInputFormatter> _decimalFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];
