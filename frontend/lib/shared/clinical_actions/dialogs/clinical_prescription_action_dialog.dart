import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_dosing.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_resolve.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_prescription_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalPrescriptionActionDialog extends StatefulWidget {
  const ClinicalPrescriptionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    this.payerContext,
    this.header,
    this.dialogTitle,
    this.submitLabel,
    this.dialogIcon,
    this.maxWidth = 880,
    this.enableBilling = true,
    this.defaultBillingEntity = 'FACILITY',
    this.allowAddMedicines = true,
    this.loadCatalogDrugs,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final ClinicalRequestPayerContext? payerContext;

  /// Optional content above the medicines table (e.g. pharmacy patient shell).
  final Widget? header;

  /// Overrides [AppLocalizations.clinicalPrescribeAction] for the dialog title.
  final String? dialogTitle;

  /// Overrides the primary submit button label.
  final String? submitLabel;

  /// Overrides the dialog leading icon.
  final IconData? dialogIcon;

  final double maxWidth;

  /// When false, hides Review billing and submits without a billing payload.
  final bool enableBilling;

  /// Billing entity stamped on review / bill-later payloads.
  final String defaultBillingEntity;

  /// When false, Add medicine stays inactive (e.g. Existing patient with no
  /// patient selected yet on pharmacy Create order).
  final bool allowAddMedicines;

  /// Optional remote medicine catalog loader (search + barcode scan).
  final ClinicalPrescriptionCatalogLoader? loadCatalogDrugs;

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
      title: Text(widget.dialogTitle ?? l10n.clinicalPrescribeAction),
      icon: Icon(widget.dialogIcon ?? Icons.medication_outlined),
      maxWidth: widget.maxWidth,
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
          if (widget.header != null) ...<Widget>[
            widget.header!,
            SizedBox(height: theme.spacing.md),
          ],
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
              displayMode: AppListTableDisplayMode.list,
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
                    return _PrescriptionRxListTile(
                      line: line,
                      drug: _drugOption(line),
                      selected: _selectedLineKeys.contains(_lineKey(line)),
                      enabled: !_isSaving,
                      onSelectedChanged: (bool selected) =>
                          _toggleKey(_lineKey(line), selected),
                      onChanged: () => setState(() {}),
                      onFieldEdited: (ClinicalPrescriptionDosingField field) {
                        _applyLineDosingSync(line, edited: field);
                        setState(() {});
                      },
                      onExpandedChanged: (bool expanded) {
                        line.expanded = expanded;
                        setState(() {});
                      },
                      onRemove: () => unawaited(_confirmAndDeleteLine(line)),
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
          label: widget.submitLabel ?? l10n.clinicalPrescribeAction,
          leadingIcon: widget.submitLabel == null
              ? Icons.send_outlined
              : Icons.add_shopping_cart_outlined,
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
        enabled: !_isSaving && widget.allowAddMedicines,
        onPressed: _isSaving || !widget.allowAddMedicines
            ? null
            : () => unawaited(_openCatalogPicker()),
      ),
      if (widget.enableBilling)
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
              label: l10n.clinicalPrescriptionEditDetailsAction,
              semanticLabel: l10n.clinicalPrescriptionEditDetailsAction,
              tooltip: l10n.clinicalPrescriptionEditDetailsAction,
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
      _paperDirections(line),
      _doseLabel(line),
      _sigLabel(line),
      _quantityLabel(line),
      _durationLabel(line),
      line.instructionsController.text,
      clinicalPrescriptionDrugGenericName(_drugOption(line)),
      clinicalPrescriptionDrugStrength(_drugOption(line)),
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
    final String heading = clinicalPrescriptionDrugHeading(_drugOption(line));
    if (heading.isNotEmpty) {
      return heading;
    }
    return clinicalActionCatalogDisplayLabelById(
          widget.referenceData.drugs,
          line.drugId,
        ) ??
        l10n.clinicalPrescriptionMedicineLabel;
  }

  String _paperDirections(_PrescriptionLineFormState line) {
    return clinicalPrescriptionPaperDirections(
      doseAmount: clinicalActionTrimmedOrNull(line.doseAmountController.text),
      doseUnit: line.doseUnit,
      route: line.route,
      frequency: line.frequency,
      durationValue: clinicalActionTrimmedOrNull(line.durationController.text),
      durationUnit: line.durationController.text.trim().isEmpty
          ? null
          : line.durationUnit,
    );
  }

  String _doseLabel(_PrescriptionLineFormState line) {
    final String label = clinicalActionJoinDisplay(<String?>[
      clinicalActionTrimmedOrNull(line.doseAmountController.text),
      clinicalActionTrimmedOrNull(line.doseUnit),
    ], separator: ' ');
    return label.isEmpty ? '—' : label;
  }

  String _sigLabel(_PrescriptionLineFormState line) {
    final String directions = _paperDirections(line);
    if (directions.isNotEmpty) {
      return directions;
    }
    return clinicalActionJoinDisplay(<String?>[
      if ((line.route ?? '').trim().isNotEmpty)
        clinicalPrescriptionRouteReadable(line.route!.trim()),
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
    return option == null
        ? null
        : clinicalCatalogOptionUnitPrice(
            option,
            billingEntity: widget.defaultBillingEntity,
          );
  }

  String _priceLabel(BuildContext context, _PrescriptionLineFormState line) {
    final ClinicalActionCatalogOption? option = _drugOption(line);
    if (option == null) {
      return '—';
    }
    return clinicalRequestCatalogPriceLabel(
      context,
      option,
      billingEntity: widget.defaultBillingEntity,
    );
  }

  Future<void> _openCatalogPicker() async {
    final Set<String> alreadySelected = <String>{
      for (final _PrescriptionLineFormState line in _lines)
        if ((line.drugId ?? '').trim().isNotEmpty) line.drugId!.trim(),
    };
    final List<ClinicalActionCatalogOption>? selected =
        await showClinicalPrescriptionCatalogDialog(
          context: context,
          drugs: widget.referenceData.drugs,
          alreadySelectedDrugIds: alreadySelected,
          loadDrugs: widget.loadCatalogDrugs,
          billingEntity: widget.defaultBillingEntity,
        );
    if (!mounted || selected == null || selected.isEmpty) {
      return;
    }

    final Set<String> existingIds = alreadySelected
        .map((String id) => id.toLowerCase())
        .toSet();
    final List<_PrescriptionLineFormState> toAdd =
        <_PrescriptionLineFormState>[];
    for (final ClinicalActionCatalogOption option in selected) {
      final String drugId = option.apiId.trim();
      if (drugId.isEmpty || existingIds.contains(drugId.toLowerCase())) {
        continue;
      }
      existingIds.add(drugId.toLowerCase());
      final _PrescriptionLineFormState line = _createLine();
      _seedLineFromDrug(line, option);
      toAdd.add(line);
    }
    if (toAdd.isEmpty) {
      return;
    }
    setState(() {
      _lines.addAll(toAdd);
      _failure = null;
    });
  }

  Future<void> _openLineDialog({required int editIndex}) async {
    final List<AppSelectOption<String>> drugOptions = _drugCatalogOptions(
      widget.referenceData.drugs,
    );
    final _PrescriptionLineFormState line = _lines[editIndex];

    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (BuildContext context) {
        final AppLocalizations l10n = context.l10n;
        final GlobalKey<FormState> lineFormKey = GlobalKey<FormState>();
        return AppDialog(
          title: Text(l10n.clinicalPrescriptionEditLineDialogTitle),
          icon: const Icon(Icons.medication_outlined),
          maxWidth: 640,
          scrollable: true,
          content: Form(
            key: lineFormKey,
            child: _PrescriptionLineCard(
              key: ValueKey<int>(line.id),
              index: editIndex,
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
      return;
    }

    setState(() => _failure = null);
  }

  Future<void> _openBillingDialog() async {
    final String billingEntity = widget.defaultBillingEntity;
    final List<ClinicalRequestBillingLineItem> fallback =
        _prescriptionBillingLineItems()
            .map(
              (ClinicalRequestBillingLineItem item) => item.copyWith(
                catalogType: item.catalogType ?? 'DRUG',
                billingEntity: item.billingEntity ?? billingEntity,
              ),
            )
            .toList(growable: false);
    final List<ClinicalRequestBillingLineItem> resolved =
        await resolveClinicalRequestBillingLineItems(
          context: context,
          catalogFallbackItems: fallback,
          billingEntity: billingEntity,
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
          billingEntity: billingEntity,
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
    if (_lines.isEmpty || !_linesAreValid()) {
      setState(() {
        _failure = AppFailure.validation();
        for (final _PrescriptionLineFormState line in _lines) {
          _applyLineFieldErrors(line);
          if (!_lineIsComplete(line) || line.consistencyError != null) {
            line.expanded = true;
          }
        }
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
      for (final _PrescriptionLineFormState line in _lines) {
        line.clearFieldErrors();
      }
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

    // Attach request-time billing when enabled (bill-later when not reviewed).
    final ClinicalRequestBillingSubmit? billing =
        widget.enableBilling ? _pendingBillingSubmit() : null;
    final AppFailure? failure = await widget.onSubmit(
      items: items,
      billing: billing,
    );
    _finishSubmit(failure);
  }

  bool _linesAreValid() {
    for (final _PrescriptionLineFormState line in _lines) {
      _refreshLineConsistency(line);
      if (!_lineIsComplete(line) || line.consistencyError != null) {
        return false;
      }
    }
    return true;
  }

  bool _lineIsComplete(_PrescriptionLineFormState line) {
    final String? drugId = line.drugId?.trim();
    if (drugId == null || drugId.isEmpty) {
      return false;
    }
    final int? quantity = int.tryParse(line.quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      return false;
    }
    if ((line.quantityUnit ?? '').trim().isEmpty) {
      return false;
    }
    final num? doseAmount = num.tryParse(line.doseAmountController.text.trim());
    if (doseAmount == null || doseAmount <= 0) {
      return false;
    }
    if ((line.doseUnit ?? '').trim().isEmpty) {
      return false;
    }
    if ((line.route ?? '').trim().isEmpty) {
      return false;
    }
    if ((line.frequency ?? '').trim().isEmpty) {
      return false;
    }
    if (!clinicalPrescriptionDurationOptional(line.frequency)) {
      final int? duration = int.tryParse(line.durationController.text.trim());
      if (duration == null || duration <= 0) {
        return false;
      }
      if ((line.durationUnit ?? '').trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _applyLineFieldErrors(_PrescriptionLineFormState line) {
    final AppLocalizations l10n = context.l10n;
    final String required = l10n.validationRequired;
    line.clearFieldErrors();

    final int? quantity = int.tryParse(line.quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      line.quantityError = required;
    }
    if ((line.quantityUnit ?? '').trim().isEmpty) {
      line.quantityUnitError = required;
    }
    final num? doseAmount = num.tryParse(line.doseAmountController.text.trim());
    if (doseAmount == null || doseAmount <= 0) {
      line.doseAmountError = required;
    }
    if ((line.doseUnit ?? '').trim().isEmpty) {
      line.doseUnitError = required;
    }
    if ((line.route ?? '').trim().isEmpty) {
      line.routeError = required;
    }
    if ((line.frequency ?? '').trim().isEmpty) {
      line.frequencyError = required;
    }
    if (!clinicalPrescriptionDurationOptional(line.frequency)) {
      final int? duration = int.tryParse(line.durationController.text.trim());
      if (duration == null || duration <= 0) {
        line.durationValueError = required;
      }
      if ((line.durationUnit ?? '').trim().isEmpty) {
        line.durationUnitError = required;
      }
    }
  }

  void _seedLineFromDrug(
    _PrescriptionLineFormState line,
    ClinicalActionCatalogOption option,
  ) {
    line.drugId = option.apiId.trim();
    final String strengthLabel = clinicalPrescriptionDrugStrength(option);
    final ClinicalParsedStrength? strength = clinicalParseDrugStrength(
      strengthLabel,
    );
    if (strength != null) {
      if (line.doseAmountController.text.trim().isEmpty) {
        line.doseAmountController.text = _formatDoseAmount(strength.amount);
      }
      if ((line.doseUnit ?? '').trim().isEmpty) {
        line.doseUnit =
            clinicalPrescriptionCanonicalDoseUnit(strength.unit) ?? 'unit';
      }
    }
    if ((line.doseUnit ?? '').trim().isEmpty) {
      line.doseUnit =
          clinicalPrescriptionCanonicalDoseUnit(
            strengthLabel
                .replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*'), '')
                .split('/')
                .first
                .trim(),
          ) ??
          'unit';
    }
    if (line.doseAmountController.text.trim().isEmpty) {
      line.doseAmountController.text = '1';
    }
    line.quantityUnit = clinicalPrescriptionResolveQuantityUnit(
      form: option.metadata['form']?.toString(),
      strength: strengthLabel,
      secondaryText: option.secondaryText,
    );
    // Seed a standard course so BID/etc. lines are submit-ready; quantity syncs.
    if (!clinicalPrescriptionDurationOptional(line.frequency) &&
        line.durationController.text.trim().isEmpty) {
      line.durationController.text = '$clinicalPrescriptionDefaultDurationDays';
      line.durationUnit =
          (line.durationUnit ?? '').trim().isEmpty ? 'days' : line.durationUnit;
    }
    line.quantityAutoDerived = true;
    line.consistencyError = null;
    _refreshLineConsistency(
      line,
      edited: ClinicalPrescriptionDosingField.durationValue,
      applyDerivedValues: true,
    );
  }

  void _applyLineDosingSync(
    _PrescriptionLineFormState line, {
    required ClinicalPrescriptionDosingField edited,
  }) {
    line.lastEditedField = edited;
    if (edited == ClinicalPrescriptionDosingField.quantity) {
      line.quantityAutoDerived = false;
      line.quantityError = null;
    } else if (edited == ClinicalPrescriptionDosingField.doseAmount) {
      line.doseAmountError = null;
    } else if (edited == ClinicalPrescriptionDosingField.doseUnit) {
      line.doseUnitError = null;
    } else if (edited == ClinicalPrescriptionDosingField.frequency) {
      line.frequencyError = null;
    } else if (edited == ClinicalPrescriptionDosingField.durationValue) {
      line.durationValueError = null;
    } else if (edited == ClinicalPrescriptionDosingField.durationUnit) {
      line.durationUnitError = null;
    }
    _refreshLineConsistency(line, edited: edited, applyDerivedValues: true);
    if (line.durationController.text.trim().isNotEmpty) {
      line.durationValueError = null;
    }
    if ((line.durationUnit ?? '').trim().isNotEmpty) {
      line.durationUnitError = null;
    }
    if (line.quantityController.text.trim().isNotEmpty) {
      line.quantityError = null;
    }
  }

  void _refreshLineConsistency(
    _PrescriptionLineFormState line, {
    ClinicalPrescriptionDosingField? edited,
    bool applyDerivedValues = false,
  }) {
    final ClinicalActionCatalogOption? drug = _drugOption(line);
    final ClinicalParsedStrength? strength = clinicalParseDrugStrength(
      clinicalPrescriptionDrugStrength(drug),
    );
    final ClinicalPrescriptionDosingField lastEdited =
        edited ??
        line.lastEditedField ??
        ClinicalPrescriptionDosingField.durationValue;
    final ClinicalPrescriptionDosingSyncResult sync =
        clinicalSyncPrescriptionDosing(
          lastEdited: lastEdited,
          doseAmount: num.tryParse(line.doseAmountController.text.trim()),
          doseUnit: line.doseUnit,
          frequency: line.frequency,
          durationValue: num.tryParse(line.durationController.text.trim()),
          durationUnit: line.durationUnit,
          quantity: int.tryParse(line.quantityController.text.trim()),
          strengthAmount: strength?.amount,
          strengthUnit: strength?.unit,
          quantityWasAutoDerived: line.quantityAutoDerived,
        );

    if (applyDerivedValues) {
      if (sync.quantity != null &&
          (line.quantityAutoDerived ||
              lastEdited != ClinicalPrescriptionDosingField.quantity)) {
        final String nextQty = sync.quantity!.toString();
        if (line.quantityController.text.trim() != nextQty) {
          line.quantityController.text = nextQty;
        }
        if (lastEdited != ClinicalPrescriptionDosingField.quantity) {
          line.quantityAutoDerived = true;
        }
      }
      if (lastEdited == ClinicalPrescriptionDosingField.quantity &&
          sync.durationValue != null) {
        final String nextDuration = sync.durationValue!.toString();
        if (line.durationController.text.trim() != nextDuration) {
          line.durationController.text = nextDuration;
        }
        if (sync.durationUnit != null) {
          line.durationUnit = sync.durationUnit;
        }
      }
    }

    final AppLocalizations l10n = context.l10n;
    line.consistencyError = switch (sync.inconsistency) {
      ClinicalPrescriptionDosingInconsistency.unitMismatch =>
        l10n.clinicalPrescriptionDosingUnitMismatchMessage(
          strength?.unit ?? line.doseUnit ?? '',
        ),
      ClinicalPrescriptionDosingInconsistency.quantityMismatch =>
        l10n.clinicalPrescriptionDosingQuantityMismatchMessage,
      null => null,
    };
  }

  String _formatDoseAmount(num amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount.toString();
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
      billingEntity: widget.defaultBillingEntity,
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
      catalogType: 'DRUG',
      billingEntity: widget.defaultBillingEntity,
    );
  }
}

class _PrescriptionRxListTile extends StatelessWidget {
  const _PrescriptionRxListTile({
    required this.line,
    required this.drug,
    required this.selected,
    required this.enabled,
    required this.onSelectedChanged,
    required this.onChanged,
    required this.onFieldEdited,
    required this.onExpandedChanged,
    required this.onRemove,
  });

  final _PrescriptionLineFormState line;
  final ClinicalActionCatalogOption? drug;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onChanged;
  final ValueChanged<ClinicalPrescriptionDosingField> onFieldEdited;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String title = clinicalPrescriptionCardTitle(
      drug: drug,
      quantity: clinicalActionTrimmedOrNull(line.quantityController.text),
      fallbackDrugName:
          drug?.displayTitle ?? l10n.clinicalPrescriptionMedicineLabel,
    );
    final TextStyle? titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: AppFontWeight.regular,
      color: colorScheme.onSurface,
      letterSpacing: 0.1,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: AppCollapsibleSection(
        expanded: line.expanded,
        onExpandedChanged: onExpandedChanged,
        initiallyExpanded: false,
        backgroundColor: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.28)
            : colorScheme.surfaceContainerLowest,
        borderColor: selected
            ? colorScheme.primary
            : theme.borders.faint,
        contentPadding: EdgeInsets.fromLTRB(
          theme.spacing.md,
          theme.spacing.sm,
          theme.spacing.md,
          theme.spacing.md,
        ),
        titleWidget: Row(
          children: <Widget>[
            Checkbox(
              value: selected,
              onChanged: enabled
                  ? (bool? value) => onSelectedChanged(value ?? false)
                  : null,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Text(
                title,
                style: titleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        headerActions: <Widget>[
          AppButton(
            dense: true,
            leadingIcon: Icons.delete_outline,
            label: l10n.commonRemoveActionLabel,
            semanticLabel: l10n.commonRemoveActionLabel,
            tooltip: l10n.commonRemoveActionLabel,
            enabled: enabled,
            color: colorScheme.error,
            onPressed: enabled ? onRemove : null,
          ),
        ],
        child: AppFormSection(
          framed: false,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.quantityController,
                  labelText: l10n.opdDrugQuantityLabel,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  enabled: enabled,
                  isDense: true,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  errorText: line.quantityError ?? line.consistencyError,
                  onChanged: (_) =>
                      onFieldEdited(ClinicalPrescriptionDosingField.quantity),
                ),
                AppSelectField<String>.searchable(
                  value: line.quantityUnit,
                  labelText: l10n.clinicalPrescriptionQuantityUnitLabel,
                  enabled: false,
                  isDense: true,
                  isRequired: true,
                  options: _unitOptions(_quantityUnits),
                  errorText: line.quantityUnitError,
                  onChanged: (_) {},
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.durationController,
                  labelText: l10n.clinicalDurationValueLabel,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  enabled: enabled,
                  isDense: true,
                  isRequired: !clinicalPrescriptionDurationOptional(
                    line.frequency,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  errorText: line.durationValueError,
                  onChanged: (_) => onFieldEdited(
                    ClinicalPrescriptionDosingField.durationValue,
                  ),
                ),
                AppSelectField<String>.searchable(
                  value: line.durationUnit,
                  labelText: l10n.clinicalDurationUnitLabel,
                  enabled: enabled,
                  isDense: true,
                  isRequired: !clinicalPrescriptionDurationOptional(
                    line.frequency,
                  ),
                  options: _durationUnitOptions(),
                  errorText: line.durationUnitError,
                  onChanged: (String? value) {
                    line.durationUnit = value;
                    line.durationUnitError = null;
                    onFieldEdited(
                      ClinicalPrescriptionDosingField.durationUnit,
                    );
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
                  isDense: true,
                  isRequired: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalFormatters,
                  errorText: line.doseAmountError,
                  onChanged: (_) => onFieldEdited(
                    ClinicalPrescriptionDosingField.doseAmount,
                  ),
                ),
                AppSelectField<String>.searchable(
                  value: line.doseUnit,
                  labelText: l10n.clinicalDoseUnitLabel,
                  enabled: false,
                  isDense: true,
                  isRequired: true,
                  options: _unitOptions(_doseUnits),
                  errorText: line.doseUnitError,
                  onChanged: (_) {},
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
                  isDense: true,
                  isRequired: true,
                  options: _medicationRouteOptions(),
                  errorText: line.routeError,
                  onChanged: (String? value) {
                    line.route = value;
                    line.routeError = null;
                    onChanged();
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.frequency,
                  labelText: l10n.opdFrequencyLabel,
                  enabled: enabled,
                  isDense: true,
                  isRequired: true,
                  options: _medicationFrequencyOptions(),
                  errorText: line.frequencyError,
                  onChanged: (String? value) {
                    line.frequency = value;
                    line.frequencyError = null;
                    onFieldEdited(ClinicalPrescriptionDosingField.frequency);
                  },
                ),
              ],
            ),
            AppTextField(
              controller: line.instructionsController,
              labelText: l10n.clinicalInstructionsLabel,
              prefixIcon: const Icon(Icons.notes_outlined),
              enabled: enabled,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
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
  bool expanded = false;
  bool quantityAutoDerived = true;
  ClinicalPrescriptionDosingField? lastEditedField;
  String? consistencyError;
  String? quantityError;
  String? quantityUnitError;
  String? doseAmountError;
  String? doseUnitError;
  String? routeError;
  String? frequencyError;
  String? durationValueError;
  String? durationUnitError;

  void clearFieldErrors() {
    quantityError = null;
    quantityUnitError = null;
    doseAmountError = null;
    doseUnitError = null;
    routeError = null;
    frequencyError = null;
    durationValueError = null;
    durationUnitError = null;
  }

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
        border: theme.borders.all(),
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
                  isDense: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  errorText: line.consistencyError,
                  validator: (String? value) =>
                      _requiredPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.quantityUnit,
                  labelText: l10n.clinicalPrescriptionQuantityUnitLabel,
                  enabled: false,
                  isDense: true,
                  isRequired: true,
                  options: _unitOptions(_quantityUnits),
                  validator: AppValidators.requiredValue(l10n.validationRequired),
                  onChanged: (_) {},
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
                  isDense: true,
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
                  enabled: false,
                  isDense: true,
                  isRequired: true,
                  options: _unitOptions(_doseUnits),
                  validator: AppValidators.requiredValue(l10n.validationRequired),
                  onChanged: (_) {},
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
                  isRequired: true,
                  options: _medicationRouteOptions(),
                  validator: AppValidators.requiredValue(l10n.validationRequired),
                  onChanged: (String? value) {
                    line.route = value;
                    onChanged();
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.frequency,
                  labelText: l10n.opdFrequencyLabel,
                  enabled: enabled,
                  isRequired: true,
                  options: _medicationFrequencyOptions(),
                  validator: AppValidators.requiredValue(l10n.validationRequired),
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
                  fontWeight: AppFontWeight.emphasis,
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
        border: theme.borders.all(),
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
                    fontWeight: AppFontWeight.emphasis,
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
                  isDense: true,
                  isRequired: !clinicalPrescriptionDurationOptional(
                    line.frequency,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) {
                    if (clinicalPrescriptionDurationOptional(line.frequency)) {
                      return _optionalPositiveIntegerValidator(l10n, value);
                    }
                    return _requiredPositiveIntegerValidator(l10n, value);
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.durationUnit,
                  labelText: l10n.clinicalDurationUnitLabel,
                  enabled: enabled,
                  isDense: true,
                  isRequired: !clinicalPrescriptionDurationOptional(
                    line.frequency,
                  ),
                  options: _durationUnitOptions(),
                  validator: (String? value) {
                    if (clinicalPrescriptionDurationOptional(line.frequency)) {
                      final bool hasDuration = line.durationController.text
                          .trim()
                          .isNotEmpty;
                      return hasDuration && value == null
                          ? l10n.validationRequired
                          : null;
                    }
                    return value == null ? l10n.validationRequired : null;
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
