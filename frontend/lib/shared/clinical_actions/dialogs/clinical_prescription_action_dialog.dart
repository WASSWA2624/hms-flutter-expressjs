import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalPrescriptionActionDialog extends StatefulWidget {
  const ClinicalPrescriptionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_PrescriptionLineFormState> _lines =
      <_PrescriptionLineFormState>[];
  int _nextLineId = 0;
  bool _isSaving = false;
  AppFailure? _failure;
  ClinicalRequestBillingSubmit? _billingSubmit;
  ClinicalRequestPaymentMode _dispenseBillingMode =
      ClinicalRequestPaymentMode.billLater;
  String? _focusedLineId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final _PrescriptionLineFormState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalRequestBillingLineItem> lineItems =
        _prescriptionBillingLineItems();

    return AppDialog(
      title: Text(l10n.clinicalPrescribeAction),
      icon: const Icon(Icons.medication_outlined),
      maxWidth: 560,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: (MediaQuery.sizeOf(context).height * 0.5).clamp(360.0, 520.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_failure != null) AppFailureStateView(failure: _failure!),
              Text(
                l10n.clinicalRequestMainPanelHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.md),
              ClinicalRequestFlowToolbar(
                enabled: !_isSaving,
                addItemsLabel: l10n.clinicalPrescriptionAddMedicineAction,
                onAddItems: () => _openLineDialog(),
                onReviewBilling:
                    _dispenseBillingMode == ClinicalRequestPaymentMode.payNow &&
                        lineItems.isNotEmpty
                    ? _openBillingDialog
                    : null,
              ),
              SizedBox(height: theme.spacing.sm),
              SegmentedButton<ClinicalRequestPaymentMode>(
                segments: <ButtonSegment<ClinicalRequestPaymentMode>>[
                  ButtonSegment<ClinicalRequestPaymentMode>(
                    value: ClinicalRequestPaymentMode.billLater,
                    icon: const Icon(Icons.local_pharmacy_outlined),
                    label: Text(l10n.radiologyPrescriptionBillOnDispenseLabel),
                  ),
                  ButtonSegment<ClinicalRequestPaymentMode>(
                    value: ClinicalRequestPaymentMode.payNow,
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.radiologyPrescriptionPayAtPrescribeLabel),
                  ),
                ],
                selected: <ClinicalRequestPaymentMode>{_dispenseBillingMode},
                showSelectedIcon: false,
                onSelectionChanged: _isSaving
                    ? null
                    : (Set<ClinicalRequestPaymentMode> values) {
                        setState(() => _dispenseBillingMode = values.first);
                      },
              ),
              if (_dispenseBillingMode == ClinicalRequestPaymentMode.payNow) ...<Widget>[
                SizedBox(height: theme.spacing.md),
                ClinicalRequestFlowSummaryBar(
                  itemCount: _lines.where((line) => line.drugId?.isNotEmpty ?? false).length,
                  lineItems: lineItems,
                  billing: _billingSubmit,
                ),
              ],
              SizedBox(height: theme.spacing.md),
              Expanded(child: _buildSelectedLinesPanel(context)),
            ],
          ),
        ),
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
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSelectedLinesPanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final _PrescriptionLineFormState? focusedLine = _focusedLine();
    final List<AppSelectOption<String>> options = <AppSelectOption<String>>[
      for (final _PrescriptionLineFormState line in _lines)
        AppSelectOption<String>(
          value: line.id.toString(),
          label: clinicalActionCatalogDisplayLabelById(
                widget.referenceData.drugs,
                line.drugId,
              ) ??
              l10n.clinicalPrescriptionNoMedicinesLabel,
          searchText: clinicalPrescriptionReadableSummary(
            drugName: clinicalActionCatalogDisplayLabelById(
              widget.referenceData.drugs,
              line.drugId,
            ),
            quantity: line.quantityController.text.trim(),
            quantityUnit: line.quantityUnit,
            doseAmount: line.doseAmountController.text.trim(),
            doseUnit: line.doseUnit,
            route: line.route,
            frequency: line.frequency,
            durationValue: line.durationController.text.trim(),
            durationUnit: line.durationUnit,
            instructions: line.instructionsController.text.trim(),
          ).toLowerCase(),
          leadingIcon: const Icon(Icons.medication_outlined),
          labelWidget: Text(
            clinicalPrescriptionReadableSummary(
              drugName: clinicalActionCatalogDisplayLabelById(
                widget.referenceData.drugs,
                line.drugId,
              ),
              quantity: line.quantityController.text.trim(),
              quantityUnit: line.quantityUnit,
              doseAmount: line.doseAmountController.text.trim(),
              doseUnit: line.doseUnit,
              route: line.route,
              frequency: line.frequency,
              durationValue: line.durationController.text.trim(),
              durationUnit: line.durationUnit,
              instructions: line.instructionsController.text.trim(),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
    ];

    return ClinicalRequestSelectionManager(
      title: l10n.clinicalPrescriptionHeaderTitle,
      emptyLabel: l10n.clinicalPrescriptionNoMedicinesLabel,
      options: options,
      value: _focusedLineId,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _focusedLineId = value);
      },
      onEdit: focusedLine == null
          ? null
          : () => _openLineDialog(
              editIndex: _lines.indexWhere(
                (_PrescriptionLineFormState line) =>
                    line.id == focusedLine.id,
              ),
            ),
      onDelete: focusedLine == null || _lines.length <= 1
          ? null
          : () => _removeLine(focusedLine),
    );
  }

  _PrescriptionLineFormState? _focusedLine() {
    if (_focusedLineId == null) {
      return null;
    }
    for (final _PrescriptionLineFormState line in _lines) {
      if (line.id.toString() == _focusedLineId) {
        return line;
      }
    }
    return null;
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
    final ClinicalRequestBillingSubmit? billing =
        await showClinicalRequestBillingDialog(
          context: context,
          lineItems: _prescriptionBillingLineItems(),
          initialBilling: _billingSubmit,
          enabled: !_isSaving,
        );
    if (!mounted || billing == null) {
      return;
    }
    setState(() => _billingSubmit = billing);
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
      if (_focusedLineId == line.id.toString()) {
        _focusedLineId = null;
      }
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
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

    final AppFailure? failure = await widget.onSubmit(
      items: items,
      billing: _dispenseBillingMode == ClinicalRequestPaymentMode.payNow
          ? _billingSubmit
          : null,
    );
    _finishSubmit(failure);
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
      quantities[drugId] = int.tryParse(line.quantityController.text.trim()) ?? 1;
      ClinicalActionCatalogOption? option;
      for (final ClinicalActionCatalogOption drug
          in widget.referenceData.drugs) {
        if (drug.apiId == drugId) {
          option = drug;
          break;
        }
      }
      options.add(
        option ??
            ClinicalActionCatalogOption(
              id: drugId,
              name: clinicalActionCatalogDisplayLabelById(
                widget.referenceData.drugs,
                drugId,
              ),
            ),
      );
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
                  fontWeight: FontWeight.w700,
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
        IconButton(
          tooltip: l10n.clinicalPrescriptionRemoveMedicineAction,
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.delete_outline),
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
                    fontWeight: FontWeight.w700,
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
