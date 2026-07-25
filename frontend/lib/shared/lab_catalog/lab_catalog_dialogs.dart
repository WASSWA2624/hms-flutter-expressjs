import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const int _maxVisibleLabCatalogDialogItems = 160;

typedef LabCatalogUpdateSubmit =
    Future<AppFailure?> Function(String id, Map<String, Object?> payload);

typedef LabEnableOfferingSubmit =
    Future<AppFailure?> Function(
      LabCatalogItem item,
      Map<String, Object?> payload,
    );

@immutable
final class LabOrderContextInput {
  const LabOrderContextInput({
    required this.patientId,
    this.patientName,
    this.encounterId,
    this.existingOrderId,
  });

  final String patientId;
  final String? patientName;
  final String? encounterId;
  final String? existingOrderId;

  String? get normalizedExistingOrderId {
    final String value = existingOrderId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Map<String, Object?> toPayload({
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  }) {
    return mergeClinicalRequestBilling(<String, Object?>{
      'patient_id': patientId.trim(),
      'encounter_id': encounterId?.trim(),
      'requested_tests': labTestIds
          .map((String id) => <String, Object?>{'lab_test_id': id})
          .toList(growable: false),
      'requested_panels': labPanelIds
          .map((String id) => <String, Object?>{'lab_panel_id': id})
          .toList(growable: false),
    }, billing);
  }
}

class LabOrderContextDialog extends ConsumerStatefulWidget {
  const LabOrderContextDialog({required this.worklist, this.order, super.key});

  final List<LabOrderSummary> worklist;
  final LabOrderSummary? order;

  @override
  ConsumerState<LabOrderContextDialog> createState() =>
      _LabOrderContextDialogState();
}

class _LabOrderContextDialogState extends ConsumerState<LabOrderContextDialog> {
  static const Duration _patientSearchDebounceDuration = Duration(
    milliseconds: 250,
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_LabContextOption> _searchedPatientOptions = <_LabContextOption>[];
  final List<LabOrderEncounterContext> _patientEncounters =
      <LabOrderEncounterContext>[];

  Timer? _patientSearchDebounce;
  _LabContextOption? _selectedPatientOption;
  String? _selectedPatientId;
  String? _selectedEncounterId;
  String? _selectedOrderId;
  AppFailure? _failure;
  bool _isLoadingPatients = false;
  bool _isLoadingPatientContext = false;
  int _patientSearchGeneration = 0;
  int _patientContextGeneration = 0;

  bool get _isEditing => widget.order != null;

  @override
  void initState() {
    super.initState();
    final LabOrderSummary? order = widget.order;
    if (order != null) {
      _selectedPatientId = order.patientId;
      _selectedEncounterId = order.encounterId;
      _selectedOrderId = order.apiId;
      _selectedPatientOption = _patientOptionFromOrder(order);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_searchPatients(''));
      final String? patientId = _selectedPatientId;
      if (patientId != null && patientId.trim().isNotEmpty) {
        unawaited(_loadPatientContext(patientId));
      }
    });
  }

  @override
  void dispose() {
    _patientSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isEditing
            ? l10n.labEditOrderDialogTitle
            : l10n.labCreateOrderDialogTitle,
      ),
      icon: const Icon(Icons.assignment_outlined),
      scrollable: true,
      maxWidth: 640,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              l10n.labOrderContextDialogBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            AppSelectField<String>.searchable(
              value: _selectedPatientId,
              labelText: l10n.labPatientSearchLabel,
              hintText: l10n.labPatientSearchHint,
              isRequired: true,
              isLoading: _isLoadingPatients,
              options: _toSelectOptions(_patientOptions),
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onSearchTextChanged: _schedulePatientSearch,
              onChanged: _selectPatient,
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppSelectField<String>.searchable(
                value: _selectedEncounterId,
                labelText: l10n.labEncounterContextLabel,
                hintText: l10n.labEncounterContextHint,
                isRequired: true,
                enabled:
                    _selectedPatientId != null &&
                    _selectedPatientId!.trim().isNotEmpty,
                isLoading: _isLoadingPatientContext,
                options: _toSelectOptions(_encounterOptions),
                validator: AppValidators.requiredValue(
                  l10n.labEncounterRequiredValidation,
                ),
                onChanged: (String? value) {
                  setState(() => _selectedEncounterId = value);
                },
              ),
              right: AppSelectField<String>.searchable(
                value: _selectedOrderId,
                labelText: l10n.labExistingOrderContextLabel,
                hintText: l10n.labExistingOrderContextHint,
                options: _toSelectOptions(_orderOptions),
                onChanged: _selectOrderContext,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<_LabContextOption> get _patientOptions {
    return _mergeContextOptions(<_LabContextOption>[
      ?_selectedPatientOption,
      ..._searchedPatientOptions,
      ...widget.worklist
          .map(_patientOptionFromOrder)
          .whereType<_LabContextOption>(),
    ]);
  }

  List<_LabContextOption> get _encounterOptions {
    final Iterable<_LabContextOption> workspaceOptions = _patientEncounters
        .map(_encounterOptionFromSummary)
        .whereType<_LabContextOption>();
    final List<_LabContextOption> worklistOptions = widget.worklist
        .where(_matchesSelectedPatient)
        .map(_encounterOptionFromOrder)
        .whereType<_LabContextOption>()
        .toList(growable: false);
    return _mergeContextOptions(<_LabContextOption>[
      ...workspaceOptions,
      ...worklistOptions,
    ]);
  }

  List<_LabContextOption> get _orderOptions {
    final List<LabOrderSummary> orders = widget.worklist
        .where((LabOrderSummary order) => !order.isPatientGroup)
        .toList(growable: false);
    final List<_LabContextOption> options = orders
        .where(_matchesSelectedPatient)
        .map(_orderOption)
        .whereType<_LabContextOption>()
        .toList(growable: false);
    if (_selectedPatientId == null || options.isNotEmpty) {
      return _mergeContextOptions(options);
    }
    return _mergeContextOptions(
      orders.map(_orderOption).whereType<_LabContextOption>(),
    );
  }

  void _schedulePatientSearch(String value) {
    _patientSearchDebounce?.cancel();
    _patientSearchDebounce = Timer(_patientSearchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchPatients(value));
    });
  }

  Future<void> _searchPatients(String query) async {
    final int generation = ++_patientSearchGeneration;
    setState(() {
      _isLoadingPatients = true;
      _failure = null;
    });
    final Result<List<LabOrderPatientContext>> result = await ref
        .read(labRepositoryProvider)
        .searchOrderContextPatients(search: query.trim());
    if (!mounted || generation != _patientSearchGeneration) {
      return;
    }
    result.when(
      success: (List<LabOrderPatientContext> patients) {
        setState(() {
          _searchedPatientOptions
            ..clear()
            ..addAll(
              patients.map(_patientOption).whereType<_LabContextOption>(),
            );
          _isLoadingPatients = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingPatients = false;
          _failure = failure;
        });
      },
    );
  }

  void _selectPatient(String? patientId) {
    final String? normalizedPatientId = _emptyToNull(patientId);
    final _LabContextOption? option = _optionByValue(
      _patientOptions,
      normalizedPatientId,
    );
    setState(() {
      _selectedPatientId = normalizedPatientId;
      _selectedPatientOption = option;
      _selectedEncounterId = null;
      _selectedOrderId = null;
      _patientEncounters.clear();
      _failure = null;
      if (normalizedPatientId == null) {
        _patientSearchGeneration += 1;
        _patientContextGeneration += 1;
        _isLoadingPatients = false;
        _isLoadingPatientContext = false;
      }
    });
    if (normalizedPatientId == null) {
      return;
    }
    unawaited(_loadPatientContext(normalizedPatientId));
  }

  Future<void> _loadPatientContext(String patientId) async {
    final int generation = ++_patientContextGeneration;
    setState(() {
      _isLoadingPatientContext = true;
      _failure = null;
    });
    final Result<LabOrderPatientContextDetail> result = await ref
        .read(labRepositoryProvider)
        .loadOrderPatientContext(patientId);
    if (!mounted || generation != _patientContextGeneration) {
      return;
    }
    result.when(
      success: (LabOrderPatientContextDetail detail) {
        setState(() {
          _selectedPatientOption ??= _patientOption(detail.patient);
          _patientEncounters
            ..clear()
            ..addAll(detail.encounters);
          _isLoadingPatientContext = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingPatientContext = false;
          _failure = failure;
        });
      },
    );
  }

  void _selectOrderContext(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) {
      setState(() => _selectedOrderId = null);
      return;
    }
    final LabOrderSummary? order = widget.worklist
        .where((LabOrderSummary item) => item.apiId == orderId)
        .firstOrNull;
    if (order == null) {
      setState(() => _selectedOrderId = orderId);
      return;
    }
    final _LabContextOption? patientOption = _patientOptionFromOrder(order);
    setState(() {
      _selectedOrderId = order.apiId;
      _selectedPatientId = order.patientId;
      _selectedPatientOption = patientOption;
      _selectedEncounterId = order.encounterId;
      _failure = null;
    });
    final String? patientId = order.patientId;
    if (patientId != null && patientId.trim().isNotEmpty) {
      unawaited(_loadPatientContext(patientId));
    }
  }

  List<AppSelectOption<String>> _toSelectOptions(
    List<_LabContextOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final _LabContextOption option in options)
        AppSelectOption<String>(
          value: option.value,
          label: option.label,
          labelWidget: _LabContextOptionLabel(option: option),
          leadingIcon: Icon(option.icon),
          searchText: option.searchText,
        ),
    ];
  }

  _LabContextOption? _patientOption(LabOrderPatientContext patient) {
    final String value = _firstNonEmpty(<String?>[
      patient.id,
      patient.displayId,
    ]);
    if (value.isEmpty) {
      return null;
    }
    return _LabContextOption(
      value: value,
      label: patient.displayTitle,
      subtitle: patient.displaySubtitle,
      icon: Icons.person_outline,
      searchText: patient.searchText,
    );
  }

  _LabContextOption? _patientOptionFromOrder(LabOrderSummary order) {
    final String value = _firstNonEmpty(<String?>[order.patientId]);
    if (value.isEmpty) {
      return null;
    }
    return _LabContextOption(
      value: value,
      label: _firstNonEmpty(<String?>[order.patientDisplayName, value]),
      subtitle: _joinNonEmpty(<String?>[order.patientId, order.encounterId]),
      icon: Icons.person_outline,
      searchText: _joinNonEmpty(<String?>[
        order.patientDisplayName,
        order.patientId,
        order.encounterId,
      ]),
    );
  }

  _LabContextOption? _encounterOptionFromSummary(
    LabOrderEncounterContext record,
  ) {
    if (record.id.trim().isEmpty) {
      return null;
    }
    return _LabContextOption(
      value: record.id,
      label: record.displayTitle,
      subtitle: record.displaySubtitle,
      icon: Icons.medical_information_outlined,
      searchText: record.searchText,
    );
  }

  _LabContextOption? _encounterOptionFromOrder(LabOrderSummary order) {
    final String value = _firstNonEmpty(<String?>[order.encounterId]);
    if (value.isEmpty) {
      return null;
    }
    return _LabContextOption(
      value: value,
      label: value,
      subtitle: _joinNonEmpty(<String?>[order.patientDisplayName, order.apiId]),
      icon: Icons.medical_information_outlined,
      searchText: _joinNonEmpty(<String?>[
        value,
        order.patientDisplayName,
        order.apiId,
      ]),
    );
  }

  _LabContextOption? _orderOption(LabOrderSummary order) {
    final String value = order.apiId.trim();
    if (value.isEmpty) {
      return null;
    }
    return _LabContextOption(
      value: value,
      label: order.displayId ?? order.id,
      subtitle: _joinNonEmpty(<String?>[
        order.patientDisplayName,
        order.patientId,
        order.encounterId,
        order.testsLabel,
      ]),
      icon: Icons.assignment_outlined,
      searchText: _joinNonEmpty(<String?>[
        order.displayId,
        order.id,
        order.patientDisplayName,
        order.patientId,
        order.encounterId,
        order.testsLabel,
      ]),
    );
  }

  bool _matchesSelectedPatient(LabOrderSummary order) {
    final String? selected = _selectedPatientId?.trim().toLowerCase();
    if (selected == null || selected.isEmpty) {
      return true;
    }
    return (order.patientId ?? '').trim().toLowerCase() == selected;
  }

  _LabContextOption? _optionByValue(
    List<_LabContextOption> options,
    String? value,
  ) {
    if (value == null) {
      return null;
    }
    for (final _LabContextOption option in options) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  List<_LabContextOption> _mergeContextOptions(
    Iterable<_LabContextOption?> options,
  ) {
    final Set<String> seen = <String>{};
    final List<_LabContextOption> result = <_LabContextOption>[];
    for (final _LabContextOption? option in options) {
      final String value = option?.value.trim() ?? '';
      if (option == null || value.isEmpty || !seen.add(value.toLowerCase())) {
        continue;
      }
      result.add(option);
    }
    return result.take(12).toList(growable: false);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      LabOrderContextInput(
        patientId: _selectedPatientId?.trim() ?? '',
        patientName: _selectedPatientOption?.label,
        encounterId: _emptyToNull(_selectedEncounterId),
        existingOrderId: _emptyToNull(_selectedOrderId),
      ),
    );
  }
}

@immutable
final class _LabContextOption {
  const _LabContextOption({
    required this.value,
    required this.label,
    required this.icon,
    this.subtitle,
    this.searchText,
  });

  final String value;
  final String label;
  final String? subtitle;
  final IconData icon;
  final String? searchText;
}

class _LabContextOptionLabel extends StatelessWidget {
  const _LabContextOptionLabel({required this.option});

  final _LabContextOption option;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (option.subtitle != null && option.subtitle!.isNotEmpty)
          Text(
            option.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class LabCatalogTestDialog extends StatefulWidget {
  const LabCatalogTestDialog({
    required this.catalogTests,
    required this.item,
    required this.onUpdate,
    super.key,
  });

  final List<LabCatalogItem> catalogTests;
  final LabCatalogItem item;
  final LabCatalogUpdateSubmit onUpdate;

  @override
  State<LabCatalogTestDialog> createState() => _LabCatalogTestDialogState();
}

class _LabCatalogTestDialogState extends State<LabCatalogTestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _specimenController;
  late final TextEditingController _unitController;
  late final TextEditingController _descriptionController;
  late List<_EditableLabValue> _unitOptions;
  late List<_EditableLabValue> _resultOptions;
  late List<EditableLabReferenceRange> _referenceRanges;
  late final TextEditingController _priceController;
  String? _resultKind;
  String _currency = appDefaultCurrencyCode;
  bool _isOfferedAtFacility = false;
  AppFailure? _failure;
  bool _isSaving = false;

  late final List<String> _cachedTestNameOptions;
  late final List<String> _cachedCategoryOptions;
  late final List<String> _cachedSpecimenOptions;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem item = widget.item;
    _nameController = TextEditingController(text: item.name ?? '');
    _codeController = TextEditingController(text: item.code ?? '');
    _categoryController = TextEditingController(text: item.category ?? '');
    _specimenController = TextEditingController(text: item.specimenType ?? '');
    _unitController = TextEditingController(text: item.unit ?? '');
    _descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    _unitOptions = item.unitOptions
        .map(_EditableLabValue.fromUnitOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _resultOptions = item.resultOptions
        .map(_EditableLabValue.fromResultOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _referenceRanges = item.referenceRanges.isEmpty
        ? <EditableLabReferenceRange>[
            EditableLabReferenceRange(defaultUnit: item.unit),
          ]
        : item.referenceRanges
              .map(
                (LabReferenceRange range) => EditableLabReferenceRange(
                  range: range,
                  defaultUnit: item.unit,
                ),
              )
              .toList(growable: true);
    _priceController = TextEditingController(
      text: item.unitPrice?.toString() ?? '',
    );
    _currency = item.currency ?? appDefaultCurrencyCode;
    _isOfferedAtFacility = item.isOfferedAtFacility;
    _resultKind = item.resultKind ?? 'NUMERIC';

    _cachedTestNameOptions = _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.name),
    );
    _cachedCategoryOptions = _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.category),
    );
    _cachedSpecimenOptions = _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.specimenType),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _specimenController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    for (final EditableLabReferenceRange range in _referenceRanges) {
      range.dispose();
    }
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labConfigureTestDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 820,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.labOfferAtFacilityLabel),
              subtitle: widget.item.usesPlatformDefaults
                  ? Text(l10n.labPlatformDefaultsHint)
                  : null,
              value: _isOfferedAtFacility,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() => _isOfferedAtFacility = value);
                    },
            ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving && _isOfferedAtFacility,
              isRequired: _isOfferedAtFacility,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: _isOfferedAtFacility
                  ? (String? value) => _positiveUnitPriceValidator(l10n, value)
                  : null,
            ),
            const Divider(height: 24),
            LabSearchableTextField(
              controller: _nameController,
              labelText: l10n.labTestNameLabel,
              enabled: false,
              isRequired: true,
              prefixIcon: const Icon(Icons.science_outlined),
              options: _testNameOptions,
              validator: (String? value) {
                final String? requiredFailure = AppValidators.requiredText(
                  l10n.validationRequired,
                )(value);
                if (requiredFailure != null) {
                  return requiredFailure;
                }
                return _hasDuplicateName(value)
                    ? l10n.labDuplicateTestNameMessage
                    : null;
              },
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _codeController,
                labelText: l10n.labTestCodeLabel,
                enabled: false,
                prefixIcon: const Icon(Icons.tag_outlined),
                validator: (String? value) => _hasDuplicateCode(value)
                    ? l10n.labDuplicateTestCodeMessage
                    : null,
              ),
              right: LabSearchableTextField(
                controller: _categoryController,
                labelText: l10n.labCategoryLabel,
                enabled: !_isSaving,
                prefixIcon: const Icon(Icons.category_outlined),
                options: _categoryOptions,
              ),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: LabSearchableTextField(
                controller: _specimenController,
                labelText: l10n.labSpecimenTypeLabel,
                enabled: !_isSaving,
                prefixIcon: const Icon(Icons.bloodtype_outlined),
                options: _specimenOptions,
              ),
              right: AppSelectField<String>.searchable(
                value: _resultKind,
                labelText: l10n.labResultKindLabel,
                enabled: !_isSaving,
                allowClear: false,
                isRequired: true,
                validator: AppValidators.requiredValue(l10n.validationRequired),
                options: <AppSelectOption<String>>[
                  AppSelectOption<String>(
                    value: 'NUMERIC',
                    label: l10n.labResultKindNumeric,
                    leadingIcon: const Icon(Icons.pin_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'QUALITATIVE',
                    label: l10n.labResultKindQualitative,
                    leadingIcon: const Icon(Icons.checklist_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'TEXT',
                    label: l10n.labResultKindText,
                    leadingIcon: const Icon(Icons.notes_outlined),
                  ),
                ],
                onChanged: (String? value) =>
                    setState(() => _resultKind = value),
              ),
            ),
            LabSearchableTextField(
              controller: _unitController,
              labelText: l10n.labDefaultUnitLabel,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.straighten_outlined),
              options: _unitOptionsCatalog,
            ),
            _EditableValueListField(
              labelText: l10n.labUnitOptionsLabel,
              values: _unitOptions,
              suggestions: _unitOptionsCatalog,
              enabled: !_isSaving,
              onAdd: (String value) {
                setState(
                  () => _unitOptions.add(_EditableLabValue(value: value)),
                );
              },
              onRemove: (_EditableLabValue value) {
                setState(() => _unitOptions.remove(value));
              },
            ),
            _EditableValueListField(
              labelText: l10n.labQualitativeOptionsLabel,
              values: _resultOptions,
              suggestions: _resultOptionsCatalog(l10n),
              enabled: !_isSaving,
              onAdd: (String value) {
                setState(
                  () => _resultOptions.add(_EditableLabValue(value: value)),
                );
              },
              onRemove: (_EditableLabValue value) {
                setState(() => _resultOptions.remove(value));
              },
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.labTestDescriptionLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
            const Divider(height: 24),
            LabReferenceRangeListField(
              ranges: _referenceRanges,
              enabled: !_isSaving,
              fallbackUnit: _unitController.text.trim(),
              onChanged: () => setState(() {}),
              onAdd: () {
                setState(
                  () => _referenceRanges.add(
                    EditableLabReferenceRange(
                      defaultUnit: _unitController.text.trim(),
                    ),
                  ),
                );
              },
              onRemove: (EditableLabReferenceRange range) {
                setState(() {
                  range.dispose();
                  _referenceRanges.remove(range);
                });
              },
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.commonSaveActionLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<String> get _testNameOptions => _cachedTestNameOptions;

  List<String> get _categoryOptions => _cachedCategoryOptions;

  List<String> get _specimenOptions => _cachedSpecimenOptions;

  List<String> get _unitOptionsCatalog {
    return _uniqueNonEmpty(<String?>[
      for (final LabCatalogItem item in widget.catalogTests) item.unit,
      for (final LabCatalogItem item in widget.catalogTests)
        for (final LabUnitOption option in item.unitOptions)
          option.unit ?? option.label,
      for (final _EditableLabValue option in _unitOptions) option.value,
    ]);
  }

  List<String> _resultOptionsCatalog(AppLocalizations l10n) {
    return _uniqueNonEmpty(<String?>[
      l10n.labPositiveOption,
      l10n.labNegativeOption,
      for (final LabCatalogItem item in widget.catalogTests)
        for (final LabResultOption option in item.resultOptions)
          option.value ?? option.label,
      for (final _EditableLabValue option in _resultOptions) option.value,
    ]);
  }

  bool _hasDuplicateName(String? value) {
    final String normalized = _normalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogTests.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          _normalizeCatalogToken(item.name) == normalized,
    );
  }

  bool _hasDuplicateCode(String? value) {
    final String normalized = _normalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogTests.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          _normalizeCatalogToken(item.code) == normalized,
    );
  }

  bool _isCurrentItem(LabCatalogItem candidate) {
    final LabCatalogItem item = widget.item;
    return candidate.id == item.id ||
        candidate.apiId == item.apiId ||
        candidate.displayId == item.displayId;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_rangesAreValid()) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onUpdate(
      widget.item.apiId,
      _payload(),
    );
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

  bool _rangesAreValid() {
    return _referenceRanges.every(
      (EditableLabReferenceRange range) => range.isValid(),
    );
  }

  Map<String, Object?> _payload() {
    final String unit = _unitController.text.trim();
    final List<Map<String, Object?>> referenceRanges = _referenceRangePayloads(
      unit,
    );
    return <String, Object?>{
      'is_active': _isOfferedAtFacility,
      'unit_price': _resolvedOfferingUnitPrice(
        isOffered: _isOfferedAtFacility,
        controller: _priceController,
        fallback: widget.item.unitPrice,
      ),
      if (_isOfferedAtFacility) 'currency': _currency,
      'category': _categoryController.text.trim(),
      'specimen_type': _specimenController.text.trim(),
      'result_kind': _resultKind,
      'unit': unit,
      'description': _descriptionController.text.trim(),
      'unit_options': _unitOptions
          .asMap()
          .entries
          .map((MapEntry<int, _EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'unit': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'is_default': entry.key == 0,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'result_options': _resultOptions
          .asMap()
          .entries
          .map((MapEntry<int, _EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'value': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'status': 'NORMAL',
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'reference_ranges': referenceRanges,
    };
  }

  List<Map<String, Object?>> _referenceRangePayloads(String unit) {
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    for (int index = 0; index < _referenceRanges.length; index++) {
      final EditableLabReferenceRange range = _referenceRanges[index];
      final Map<String, Object?> payload = range.toPayload(
        sortOrder: index,
        fallbackUnit: unit,
      );
      if (range.hasContent(unit)) {
        payloads.add(payload);
      }
    }
    return payloads;
  }
}

class LabCatalogPanelDialog extends StatefulWidget {
  const LabCatalogPanelDialog({
    required this.catalogTests,
    required this.catalogPanels,
    required this.item,
    required this.onUpdate,
    super.key,
  });

  final List<LabCatalogItem> catalogTests;
  final List<LabCatalogItem> catalogPanels;
  final LabCatalogItem item;
  final LabCatalogUpdateSubmit onUpdate;

  @override
  State<LabCatalogPanelDialog> createState() => _LabCatalogPanelDialogState();
}

class _LabCatalogPanelDialogState extends State<LabCatalogPanelDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final List<LabCatalogItem> _selectedTests;
  late final TextEditingController _priceController;
  String? _pendingTestId;
  String _currency = appDefaultCurrencyCode;
  bool _isOfferedAtFacility = false;
  AppFailure? _failure;
  bool _isSaving = false;
  late final List<String> _cachedPanelNameOptions;
  late final List<String> _cachedPanelCategoryOptions;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem item = widget.item;
    _nameController = TextEditingController(text: item.name ?? '');
    _codeController = TextEditingController(text: item.code ?? '');
    _categoryController = TextEditingController(text: item.category ?? '');
    _descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    _priceController = TextEditingController(
      text: item.unitPrice?.toString() ?? '',
    );
    _currency = item.currency ?? appDefaultCurrencyCode;
    _isOfferedAtFacility = item.isOfferedAtFacility;
    _selectedTests = _initialSelectedTests(item);

    _cachedPanelNameOptions = _uniqueNonEmpty(
      widget.catalogPanels.map((LabCatalogItem item) => item.name),
    );
    _cachedPanelCategoryOptions = _uniqueNonEmpty(<String?>[
      ...widget.catalogTests.map((LabCatalogItem item) => item.category),
      ...widget.catalogPanels.map((LabCatalogItem item) => item.category),
    ]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labUpdatePanelDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 860,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.labOfferAtFacilityLabel),
              subtitle: widget.item.usesPlatformDefaults
                  ? Text(l10n.labPlatformDefaultsHint)
                  : null,
              value: _isOfferedAtFacility,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() => _isOfferedAtFacility = value);
                    },
            ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving && _isOfferedAtFacility,
              isRequired: _isOfferedAtFacility,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: _isOfferedAtFacility
                  ? (String? value) => _positiveUnitPriceValidator(l10n, value)
                  : null,
            ),
            const Divider(height: 24),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: LabSearchableTextField(
                controller: _nameController,
                labelText: l10n.labPanelNameLabel,
                enabled: false,
                isRequired: true,
                prefixIcon: const Icon(Icons.dashboard_customize_outlined),
                options: _panelNameOptions,
              ),
              right: AppTextField(
                controller: _codeController,
                labelText: l10n.labPanelCodeLabel,
                enabled: false,
                prefixIcon: const Icon(Icons.tag_outlined),
              ),
            ),
            LabSearchableTextField(
              controller: _categoryController,
              labelText: l10n.labCategoryLabel,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.category_outlined),
              options: _categoryOptions,
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.labPanelDescriptionLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
            _PanelTestPicker(
              tests: widget.catalogTests,
              selectedTests: _selectedTests,
              pendingTestId: _pendingTestId,
              enabled: false,
              onPendingChanged: (String? value) {
                setState(() => _pendingTestId = value);
              },
              onAdd: _addPendingTest,
              onRemove: _removeTest,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labUpdatePanelAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<LabCatalogItem> _initialSelectedTests(LabCatalogItem item) {
    return item.panelItems.map(_testForPanelItem).toList(growable: true);
  }

  LabCatalogItem _testForPanelItem(LabPanelItem panelItem) {
    for (final LabCatalogItem test in widget.catalogTests) {
      if (_isSameCatalogIdentity(
            test,
            panelItem.labTestId,
            panelItem.testCode,
          ) ||
          _normalizeCatalogToken(test.code) ==
              _normalizeCatalogToken(panelItem.testCode)) {
        return test;
      }
    }
    return LabCatalogItem(
      id: panelItem.labTestId ?? panelItem.id,
      displayId: panelItem.labTestId,
      type: LabCatalogItemType.test,
      name: panelItem.testDisplayName,
      code: panelItem.testCode,
      unit: panelItem.unit,
    );
  }

  List<String> get _panelNameOptions => _cachedPanelNameOptions;

  List<String> get _categoryOptions => _cachedPanelCategoryOptions;

  void _addPendingTest() {
    final String? testId = _pendingTestId;
    if (testId == null) {
      return;
    }
    final LabCatalogItem? test = widget.catalogTests
        .where((LabCatalogItem item) => item.apiId == testId)
        .firstOrNull;
    if (test == null || _containsCatalogItem(_selectedTests, test)) {
      return;
    }
    setState(() {
      _selectedTests.add(test);
      _pendingTestId = null;
    });
  }

  void _removeTest(LabCatalogItem item) {
    setState(
      () => _selectedTests.removeWhere(
        (LabCatalogItem selected) =>
            selected.apiId == item.apiId || selected.id == item.id,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onUpdate(
      widget.item.apiId,
      _payload(),
    );
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

  Map<String, Object?> _payload() {
    return <String, Object?>{
      'is_active': _isOfferedAtFacility,
      'unit_price': _resolvedOfferingUnitPrice(
        isOffered: _isOfferedAtFacility,
        controller: _priceController,
        fallback: widget.item.unitPrice,
      ),
      if (_isOfferedAtFacility) 'currency': _currency,
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
    };
  }
}

enum LabEnableOfferingKind { test, panel, all }

typedef LabEnableOfferingCatalogSearch =
    Future<Result<List<LabCatalogItem>>> Function({
      required LabEnableOfferingKind kind,
      required LabCatalogScope scope,
      String? query,
      int limit,
    });

class LabEnableFacilityOfferingDialog extends StatefulWidget {
  const LabEnableFacilityOfferingDialog({
    required this.kind,
    required this.scope,
    required this.onSearchCatalog,
    required this.onEnable,
    this.defaultCurrency = appDefaultCurrencyCode,
    super.key,
  });

  final LabEnableOfferingKind kind;
  final LabCatalogScope scope;
  final LabEnableOfferingCatalogSearch onSearchCatalog;
  final LabEnableOfferingSubmit onEnable;
  final String defaultCurrency;

  @override
  State<LabEnableFacilityOfferingDialog> createState() =>
      _LabEnableFacilityOfferingDialogState();
}

class _LabEnableFacilityOfferingDialogState
    extends State<LabEnableFacilityOfferingDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const int _searchLimit = 100;
  static const String _typeFilterKey = 'type';
  static const String _categoryFilterKey = 'category';
  static const String _resultKindFilterKey = 'result_kind';

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  List<LabCatalogItem> _catalogItems = const <LabCatalogItem>[];
  AppFailure? _failure;
  bool _isSearching = true;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  bool get _showingAll => widget.kind == LabEnableOfferingKind.all;

  String? get _selectedType => _filterValue.option(_typeFilterKey);

  bool get _showingTestsOnly =>
      widget.kind == LabEnableOfferingKind.test ||
      (_showingAll && _selectedType == LabCatalogItemType.test.name);

  bool get _showingPanelsOnly =>
      widget.kind == LabEnableOfferingKind.panel ||
      (_showingAll && _selectedType == LabCatalogItemType.panel.name);

  bool get _includeResultKindFilter =>
      widget.kind == LabEnableOfferingKind.test ||
      (_showingAll && _selectedType != LabCatalogItemType.panel.name);

  List<LabCatalogItem> get _filteredCatalogItems {
    final String? category = _filterValue.option(_categoryFilterKey);
    final String? resultKind = _filterValue.option(_resultKindFilterKey);
    final String? type = _selectedType;
    return _catalogItems
        .where((LabCatalogItem item) {
          if (_showingAll &&
              type != null &&
              item.type.name != type) {
            return false;
          }
          if (category != null && item.category != category) {
            return false;
          }
          if (_includeResultKindFilter &&
              item.type == LabCatalogItemType.test &&
              resultKind != null &&
              item.resultKind != resultKind) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchRequest += 1;
    unawaited(_loadCatalog(query: null, requestId: _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({
    required String? query,
    required int requestId,
  }) async {
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    final Result<List<LabCatalogItem>> result = await widget.onSearchCatalog(
      kind: widget.kind,
      scope: widget.scope,
      query: query?.trim().isEmpty ?? true ? null : query?.trim(),
      limit: _searchLimit,
    );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<LabCatalogItem> items) {
        setState(() {
          _catalogItems = items;
          _isSearching = false;
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <LabCatalogItem>[];
          _isSearching = false;
          _failure = value;
        });
      },
    );
  }

  void _scheduleCatalogSearch(String query) {
    _searchDebounce?.cancel();
    _searchRequest += 1;
    final int requestId = _searchRequest;
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_loadCatalog(query: query, requestId: requestId));
    });
  }

  LabEnableOfferingKind _kindForItem(LabCatalogItem item) {
    if (widget.kind != LabEnableOfferingKind.all) {
      return widget.kind;
    }
    return item.type == LabCatalogItemType.panel
        ? LabEnableOfferingKind.panel
        : LabEnableOfferingKind.test;
  }

  Future<void> _openPriceDialog(LabCatalogItem item) async {
    if (item.isOfferedAtFacility) {
      return;
    }
    final bool? enabled = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LabEnableOfferingPriceDialog(
        item: item,
        kind: _kindForItem(item),
        defaultCurrency: widget.defaultCurrency,
        onEnable: widget.onEnable,
      ),
    );
    if (!mounted) {
      return;
    }
    if (enabled == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<LabCatalogItem> filtered = _filteredCatalogItems;
    final List<LabCatalogItem> available = filtered
        .where((LabCatalogItem item) => !item.isOfferedAtFacility)
        .toList(growable: false);

    return AppDialog(
      title: Text(l10n.labEnableOfferingDialogTitle),
      icon: Icon(
        _showingPanelsOnly
            ? Icons.add_box_outlined
            : Icons.add_circle_outline,
      ),
      scrollable: true,
      maxWidth: 980,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.md),
              child: AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ),
          Text(
            l10n.labEnableOfferingDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (_isSearching && _catalogItems.isEmpty)
            AppWorkspaceStatePanel.loading(
              title: l10n.labConfigurationsLoadingTitle,
              body: l10n.labConfigurationsLoadingBody,
              minHeight: 120,
            )
          else if (!_isSearching && _catalogItems.isEmpty)
            AppMutedText(l10n.labEnableOfferingNoPlatformItemsLabel)
          else if (!_isSearching && filtered.isEmpty)
            AppMutedText(l10n.labEnableOfferingNoItemsLabel)
          else if (!_isSearching && available.isEmpty)
            AppMutedText(l10n.labEnableOfferingNoItemsLabel)
          else
            AppListTable<LabCatalogItem>(
              items: filtered,
              maxVisibleItems: _maxVisibleLabCatalogDialogItems,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              tableHorizontalMargin: 0,
              isLoading: _isSearching,
              onRowSelected: (LabCatalogItem item) {
                if (!item.isOfferedAtFacility) {
                  unawaited(_openPriceDialog(item));
                }
              },
              search: AppListTableSearch<LabCatalogItem>(
                controller: _searchController,
                semanticLabel: l10n.labCatalogSearchLabel,
                hintText: l10n.labReferenceRangesSearchHint,
                isLoading: _isSearching,
                matcher: (LabCatalogItem item, String query) =>
                    item.matchesSearch(query),
                onChanged: _scheduleCatalogSearch,
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.labFiltersLabel,
                advancedFilterTitle: l10n.labFiltersLabel,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.labScopeAll,
                filterGroups: <AppSearchBarFilterGroup>[
                  if (_showingAll)
                    AppSearchBarFilterGroup(
                      key: _typeFilterKey,
                      label: l10n.clinicalRequestSelectedTypeColumnLabel,
                      allLabel: l10n.labScopeAll,
                      choices: <AppSearchBarFilterChoice>[
                        AppSearchBarFilterChoice(
                          value: LabCatalogItemType.test.name,
                          label: l10n.clinicalLabRequestTestTypeLabel,
                        ),
                        AppSearchBarFilterChoice(
                          value: LabCatalogItemType.panel.name,
                          label: l10n.clinicalLabRequestPanelTypeLabel,
                        ),
                      ],
                    ),
                  AppSearchBarFilterGroup(
                    key: _categoryFilterKey,
                    label: l10n.labCategoryLabel,
                    allLabel: l10n.labScopeAll,
                    choices: _enableOfferingFilterChoices(
                      _catalogItems.map((LabCatalogItem item) => item.category),
                    ),
                  ),
                  if (_includeResultKindFilter)
                    AppSearchBarFilterGroup(
                      key: _resultKindFilterKey,
                      label: l10n.labResultKindLabel,
                      allLabel: l10n.labScopeAll,
                      choices: _enableOfferingFilterChoices(
                        _catalogItems
                            .where(
                              (LabCatalogItem item) =>
                                  item.type == LabCatalogItemType.test,
                            )
                            .map((LabCatalogItem item) => item.resultKind),
                      ),
                    ),
                ],
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
              ),
              emptyBuilder: (_) => Center(
                child: AppMutedText(
                  _showingPanelsOnly
                      ? l10n.labNoOfferedPanelsLabel
                      : l10n.labNoOfferedTestsLabel,
                  textAlign: TextAlign.center,
                ),
              ),
              columns: _enableOfferingColumns(context),
              mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
                return AppListTableMobileItem(
                  title: item.name ?? item.displayTitle,
                  caption: item.code,
                  meta: <AppListTableMobileMeta>[
                    if (_showingAll)
                      AppListTableMobileMeta(
                        label: item.type == LabCatalogItemType.panel
                            ? l10n.clinicalLabRequestPanelTypeLabel
                            : l10n.clinicalLabRequestTestTypeLabel,
                      ),
                    AppListTableMobileMeta(
                      label: _joinEnableOfferingSubtitle(l10n, item),
                    ),
                    if (item.isOfferedAtFacility)
                      AppListTableMobileMeta(
                        label: l10n.labEnableOfferingAlreadyOfferedLabel,
                        icon: AppActionIcons.success,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  List<AppListTableColumn<LabCatalogItem>> _enableOfferingColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool showTypeColumn = _showingAll && _selectedType == null;
    final bool showSpecimen = _showingTestsOnly ||
        (_showingAll && !_showingPanelsOnly);
    return <AppListTableColumn<LabCatalogItem>>[
      AppListTableColumn<LabCatalogItem>(
        id: 'name',
        label: _showingAll
            ? l10n.accessAdminColumnName
            : (_showingTestsOnly
                  ? l10n.labTestNameLabel
                  : l10n.labPanelNameLabel),
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.name, right.name),
        cellBuilder: (_, LabCatalogItem item) =>
            _catalogOfferingNameCell(item.name ?? item.displayTitle),
      ),
      if (showTypeColumn)
        AppListTableColumn<LabCatalogItem>(
          id: 'type',
          label: l10n.clinicalRequestSelectedTypeColumnLabel,
          sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
              left.type.name.compareTo(right.type.name),
          cellBuilder: (_, LabCatalogItem item) => Text(
            item.type == LabCatalogItemType.panel
                ? l10n.clinicalLabRequestPanelTypeLabel
                : l10n.clinicalLabRequestTestTypeLabel,
          ),
        ),
      AppListTableColumn<LabCatalogItem>(
        id: 'code',
        label: _showingAll
            ? l10n.labTestCodeLabel
            : (_showingTestsOnly
                  ? l10n.labTestCodeLabel
                  : l10n.labPanelCodeLabel),
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.code, right.code),
        cellBuilder: (_, LabCatalogItem item) =>
            Text(item.code ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'category',
        label: l10n.labCategoryLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.category, right.category),
        cellBuilder: (_, LabCatalogItem item) =>
            Text(item.category ?? l10n.profileUnknownValue),
      ),
      if (showSpecimen)
        AppListTableColumn<LabCatalogItem>(
          id: 'specimen',
          label: l10n.labSpecimenTypeLabel,
          cellBuilder: (_, LabCatalogItem item) => Text(
            item.type == LabCatalogItemType.test
                ? (item.specimenType ?? l10n.profileUnknownValue)
                : l10n.profileUnknownValue,
          ),
        ),
      AppListTableColumn<LabCatalogItem>(
        id: 'status',
        label: l10n.labActionColumnLabel,
        cellBuilder: (_, LabCatalogItem item) {
          if (!item.isOfferedAtFacility) {
            return const SizedBox.shrink();
          }
          return AppMutedText(l10n.labEnableOfferingAlreadyOfferedLabel);
        },
      ),
    ];
  }
}

String _joinEnableOfferingSubtitle(AppLocalizations l10n, LabCatalogItem item) {
  final List<String?> parts = <String?>[
    item.category,
    if (item.type == LabCatalogItemType.test) item.specimenType,
    if (item.type == LabCatalogItemType.panel)
      l10n.clinicalLabOrderItemCount(item.testCount),
  ];
  return parts
      .map((String? value) => value?.trim())
      .whereType<String>()
      .where((String value) => value.isNotEmpty)
      .join(' · ');
}

List<AppSearchBarFilterChoice> _enableOfferingFilterChoices(
  Iterable<String?> values,
) {
  return _uniqueNonEmpty(values)
      .map(
        (String value) => AppSearchBarFilterChoice(value: value, label: value),
      )
      .toList(growable: false);
}

Widget _catalogOfferingNameCell(String label, {double maxWidth = 280}) {
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Tooltip(
      message: label,
      child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _LabEnableOfferingPriceDialog extends StatefulWidget {
  const _LabEnableOfferingPriceDialog({
    required this.item,
    required this.kind,
    required this.onEnable,
    required this.defaultCurrency,
  });

  final LabCatalogItem item;
  final LabEnableOfferingKind kind;
  final LabEnableOfferingSubmit onEnable;
  final String defaultCurrency;

  @override
  State<_LabEnableOfferingPriceDialog> createState() =>
      _LabEnableOfferingPriceDialogState();
}

class _LabEnableOfferingPriceDialogState
    extends State<_LabEnableOfferingPriceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _showingTests => widget.kind == LabEnableOfferingKind.test;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _currency = widget.defaultCurrency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final LabCatalogItem item = widget.item;

    return AppDialog(
      title: Text(
        _showingTests ? l10n.labEnableTestAction : l10n.labEnablePanelAction,
      ),
      icon: Icon(
        _showingTests ? Icons.science_outlined : Icons.inventory_2_outlined,
      ),
      scrollable: true,
      maxWidth: 520,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              item.displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.displaySubtitle != null &&
                item.displaySubtitle!.isNotEmpty)
              AppMutedText(item.displaySubtitle!),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) =>
                  _positiveUnitPriceValidator(l10n, value),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: _showingTests
            ? l10n.labEnableTestAction
            : l10n.labEnablePanelAction,
        isSaving: _isSaving,
        onSubmit: _submit,
        submitIcon: Icons.check_circle_outline,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onEnable(
      widget.item,
      <String, Object?>{
        'is_active': true,
        'unit_price':
            num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0,
        'currency': _currency,
      },
    );
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
}

class LabDeleteReasonDialog extends StatefulWidget {
  const LabDeleteReasonDialog({
    required this.title,
    required this.body,
    required this.submitLabel,
    required this.onDelete,
    this.icon = const Icon(Icons.delete_outline),
    this.showCancelButton = false,
    this.destructiveSubmit = false,
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
  final bool showCancelButton;
  final bool destructiveSubmit;
  final Future<AppFailure?> Function(String reason) onDelete;

  @override
  State<LabDeleteReasonDialog> createState() => _LabDeleteReasonDialogState();
}

class _LabDeleteReasonDialogState extends State<LabDeleteReasonDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController()..addListener(_handleChanged);
  }

  @override
  void dispose() {
    _reasonController.removeListener(_handleChanged);
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              widget.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.labDeleteReasonLabel,
              hintText: l10n.labDeleteReasonHint,
              enabled: !_isSaving,
              isRequired: true,
              maxLines: 3,
              validator: AppValidators.requiredText(
                l10n.labDeleteReasonValidationMessage,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.showCancelButton)
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            enabled: !_isSaving,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.delete_outline,
          color: widget.destructiveSubmit ? colorScheme.error : null,
          isLoading: _isSaving,
          enabled: !_isSaving && _canSubmit,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _handleChanged() {
    setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onDelete(
      _reasonController.text.trim(),
    );
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
}

class _PanelTestPicker extends StatelessWidget {
  const _PanelTestPicker({
    required this.tests,
    required this.selectedTests,
    required this.pendingTestId,
    required this.enabled,
    required this.onPendingChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> selectedTests;
  final String? pendingTestId;
  final bool enabled;
  final ValueChanged<String?> onPendingChanged;
  final VoidCallback onAdd;
  final ValueChanged<LabCatalogItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppSelectOption<String>> options = <AppSelectOption<String>>[
      for (final LabCatalogItem test in tests)
        AppSelectOption<String>(
          value: test.apiId,
          label: test.displayTitle,
          leadingIcon: const Icon(Icons.science_outlined),
          searchText: test.searchText,
          enabled: !_containsCatalogItem(selectedTests, test),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.labPanelTestsLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppSelectField<String>.searchable(
                value: pendingTestId,
                labelText: l10n.labPanelTestSelectLabel,
                enabled: enabled,
                menuHeight: 360,
                options: options,
                onChanged: onPendingChanged,
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.xs),
              child: AppButton.secondary(
                label: l10n.labPanelAddTestAction,
                leadingIcon: Icons.add,
                enabled: enabled && pendingTestId != null,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        if (selectedTests.isEmpty)
          AppMutedText(l10n.labPanelNoSelectedTests)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Text(
                    l10n.labPanelSelectedTestsTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                for (var index = 0; index < selectedTests.length; index += 1)
                  _SelectedPanelTestRow(
                    item: selectedTests[index],
                    enabled: enabled,
                    onRemove: () => onRemove(selectedTests[index]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SelectedPanelTestRow extends StatelessWidget {
  const _SelectedPanelTestRow({
    required this.item,
    required this.enabled,
    required this.onRemove,
  });

  final LabCatalogItem item;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String subtitle = _joinNonEmpty(<String?>[
      item.code,
      item.specimenType,
      item.unit,
    ]);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.science_outlined,
            color: theme.colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.close,
            label: l10n.commonRemoveActionLabel,

            semanticLabel: l10n.commonRemoveActionLabel,
            tooltip: l10n.commonRemoveActionLabel,
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _EditableValueListField extends StatefulWidget {
  const _EditableValueListField({
    required this.labelText,
    required this.values,
    required this.suggestions,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final String labelText;
  final List<_EditableLabValue> values;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<_EditableLabValue> onRemove;

  @override
  State<_EditableValueListField> createState() =>
      _EditableValueListFieldState();
}

class _EditableValueListFieldState extends State<_EditableValueListField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LabSearchableTextField(
          controller: _controller,
          labelText: widget.labelText,
          hintText: l10n.labAddValueFieldHint,
          enabled: widget.enabled,
          prefixIcon: const Icon(Icons.search),
          options: widget.suggestions,
          suffixIcon: AppButton(
            iconOnly: true,
            leadingIcon: Icons.add,
            label: l10n.labAddValueAction,
            semanticLabel: l10n.labAddValueAction,
            tooltip: l10n.labAddValueAction,
            enabled: widget.enabled,
            onPressed: widget.enabled ? _addCurrentValue : null,
          ),
          onFieldSubmitted: (_) => _addCurrentValue(),
        ),
        if (widget.values.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final _EditableLabValue value in widget.values)
                InputChip(
                  label: Text(value.value),
                  onDeleted: widget.enabled
                      ? () => widget.onRemove(value)
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _addCurrentValue() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (widget.values.any(
      (_EditableLabValue existing) =>
          _normalizeCatalogToken(existing.value) ==
          _normalizeCatalogToken(value),
    )) {
      _controller.clear();
      return;
    }
    widget.onAdd(value);
    _controller.clear();
  }
}

class LabSearchableTextField extends StatefulWidget {
  const LabSearchableTextField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.enabled = true,
    this.isRequired = false,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final bool enabled;
  final bool isRequired;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<LabSearchableTextField> createState() => _LabSearchableTextFieldState();
}

class _LabSearchableTextFieldState extends State<LabSearchableTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        final List<String> matches = widget.options
            .where(
              (String option) =>
                  query.isEmpty || option.toLowerCase().contains(query),
            )
            .take(10)
            .toList(growable: false);
        if (query.isEmpty ||
            matches.any((String option) => option.toLowerCase() == query)) {
          return matches;
        }
        return <String>[value.text.trim(), ...matches];
      },
      onSelected: (String value) {
        widget.controller.text = value;
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return AppTextField(
              controller: controller,
              focusNode: focusNode,
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              enabled: widget.enabled,
              isRequired: widget.isRequired,
              validator: widget.validator,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
                widget.onFieldSubmitted?.call(value);
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final ThemeData theme = Theme.of(context);
            final List<String> visibleOptions = options.toList(growable: false);
            if (visibleOptions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 420,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: visibleOptions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = visibleOptions[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}

@immutable
final class _EditableLabValue {
  const _EditableLabValue({required this.value, this.id, this.label});

  factory _EditableLabValue.fromUnitOption(LabUnitOption option) {
    return _EditableLabValue(
      id: option.id,
      value: option.unit ?? option.label ?? '',
      label: option.label,
    );
  }

  factory _EditableLabValue.fromResultOption(LabResultOption option) {
    return _EditableLabValue(
      id: option.id,
      value: option.value ?? option.label ?? '',
      label: option.label,
    );
  }

  final String value;
  final String? id;
  final String? label;
}

String? _positiveUnitPriceValidator(AppLocalizations l10n, String? value) {
  final String? requiredFailure = AppValidators.requiredText(
    l10n.validationRequired,
  )(value);
  if (requiredFailure != null) {
    return requiredFailure;
  }
  final num? parsed = num.tryParse(normalizeCurrencyAmount(value ?? ''));
  if (parsed == null || parsed <= 0) {
    return l10n.validationRequired;
  }
  return null;
}

num _resolvedOfferingUnitPrice({
  required bool isOffered,
  required TextEditingController controller,
  required num? fallback,
}) {
  if (isOffered) {
    return num.tryParse(normalizeCurrencyAmount(controller.text)) ?? 0;
  }
  return fallback ?? 0;
}

List<Widget> _dialogActions(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  VoidCallback? onSubmit,
  IconData submitIcon = Icons.check,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      leadingIcon: Icons.close,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitIcon,
      isLoading: isSaving,
      enabled: onSubmit != null && !isSaving,
      onPressed: onSubmit,
    ),
  ];
}

bool _containsCatalogItem(List<LabCatalogItem> items, LabCatalogItem item) {
  return items.any(
    (LabCatalogItem selected) =>
        selected.apiId == item.apiId || selected.id == item.id,
  );
}

bool _isSameCatalogIdentity(LabCatalogItem item, String? id, String? code) {
  final String normalizedId = _normalizeCatalogToken(id);
  if (normalizedId.isNotEmpty) {
    if (_normalizeCatalogToken(item.apiId) == normalizedId ||
        _normalizeCatalogToken(item.id) == normalizedId ||
        _normalizeCatalogToken(item.displayId) == normalizedId) {
      return true;
    }
  }
  final String normalizedCode = _normalizeCatalogToken(code);
  return normalizedCode.isNotEmpty &&
      _normalizeCatalogToken(item.code) == normalizedCode;
}

String _normalizeCatalogToken(String? value) {
  return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

List<String> _uniqueNonEmpty(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      continue;
    }
    final String key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  result.sort(
    (String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return result;
}

String? _emptyToNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String _joinNonEmpty(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}
