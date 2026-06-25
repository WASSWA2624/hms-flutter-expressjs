import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

typedef LabCatalogSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

typedef LabCatalogUpdateSubmit =
    Future<AppFailure?> Function(String id, Map<String, Object?> payload);

@immutable
final class LabOrderContextInput {
  const LabOrderContextInput({
    required this.patientId,
    this.encounterId,
    this.existingOrderId,
  });

  final String patientId;
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
                enabled:
                    _selectedPatientId != null &&
                    _selectedPatientId!.trim().isNotEmpty,
                isLoading: _isLoadingPatientContext,
                options: _toSelectOptions(_encounterOptions),
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
    required this.onCreate,
    required this.onUpdate,
    this.item,
    this.tenantId,
    super.key,
  });

  final List<LabCatalogItem> catalogTests;
  final LabCatalogItem? item;
  final String? tenantId;
  final LabCatalogSubmit onCreate;
  final LabCatalogUpdateSubmit onUpdate;

  @override
  State<LabCatalogTestDialog> createState() => _LabCatalogTestDialogState();
}

class _LabCatalogTestDialogState extends State<LabCatalogTestDialog> {
  static const String _anyGenderValue = '__ANY__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _specimenController;
  late final TextEditingController _unitController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rangeLabelController;
  late final TextEditingController _ageMinController;
  late final TextEditingController _ageMaxController;
  late final TextEditingController _rangeUnitController;
  late final TextEditingController _normalMinController;
  late final TextEditingController _normalMaxController;
  late final TextEditingController _criticalMinController;
  late final TextEditingController _criticalMaxController;
  late final TextEditingController _referenceTextController;
  late final TextEditingController _rangeNotesController;
  late List<_EditableLabValue> _unitOptions;
  late List<_EditableLabValue> _resultOptions;
  String? _resultKind;
  String? _gender;
  String? _ageUnit = 'YEAR';
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _isCreateMode => widget.item == null;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem? item = widget.item;
    final LabReferenceRange? range = item?.referenceRanges.isEmpty ?? true
        ? null
        : item!.referenceRanges.first;
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _specimenController = TextEditingController(text: item?.specimenType ?? '');
    _unitController = TextEditingController(text: item?.unit ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _unitOptions = (item?.unitOptions ?? const <LabUnitOption>[])
        .map(_EditableLabValue.fromUnitOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _resultOptions = (item?.resultOptions ?? const <LabResultOption>[])
        .map(_EditableLabValue.fromResultOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _rangeLabelController = TextEditingController(text: range?.label ?? '');
    _ageMinController = TextEditingController(
      text: range?.ageMinValue?.toString() ?? '',
    );
    _ageMaxController = TextEditingController(
      text: range?.ageMaxValue?.toString() ?? '',
    );
    _rangeUnitController = TextEditingController(
      text: range?.unit ?? item?.unit ?? '',
    );
    _normalMinController = TextEditingController(
      text: range?.normalMinValue ?? '',
    );
    _normalMaxController = TextEditingController(
      text: range?.normalMaxValue ?? '',
    );
    _criticalMinController = TextEditingController(
      text: range?.criticalMinValue ?? '',
    );
    _criticalMaxController = TextEditingController(
      text: range?.criticalMaxValue ?? '',
    );
    _referenceTextController = TextEditingController(
      text: range?.referenceText ?? '',
    );
    _rangeNotesController = TextEditingController(text: range?.notes ?? '');
    _resultKind = item?.resultKind ?? 'NUMERIC';
    _gender = range?.gender ?? _anyGenderValue;
    _ageUnit = range?.ageMinUnit ?? range?.ageMaxUnit ?? 'YEAR';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _specimenController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _rangeLabelController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    _rangeUnitController.dispose();
    _normalMinController.dispose();
    _normalMaxController.dispose();
    _criticalMinController.dispose();
    _criticalMaxController.dispose();
    _referenceTextController.dispose();
    _rangeNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isCreateMode
            ? l10n.labCreateTestDialogTitle
            : l10n.labConfigureTestDialogTitle,
      ),
      icon: Icon(
        _isCreateMode ? Icons.add_circle_outline : Icons.edit_outlined,
      ),
      scrollable: true,
      maxWidth: 820,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            LabSearchableTextField(
              controller: _nameController,
              labelText: l10n.labTestNameLabel,
              enabled: !_isSaving,
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
                enabled: !_isSaving,
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
            LabSearchableTextField(
              controller: _rangeLabelController,
              labelText: l10n.labReferenceRangeLabel,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.label_outline),
              options: _rangeLabelOptions(l10n),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppSelectField<String>.searchable(
                value: _gender,
                labelText: l10n.labGenderApplicabilityLabel,
                enabled: !_isSaving,
                allowClear: false,
                options: <AppSelectOption<String>>[
                  AppSelectOption<String>(
                    value: _anyGenderValue,
                    label: l10n.labGenderAnyLabel,
                    leadingIcon: const Icon(Icons.people_outline),
                  ),
                  AppSelectOption<String>(
                    value: 'MALE',
                    label: l10n.labGenderMaleLabel,
                    leadingIcon: const Icon(Icons.male),
                  ),
                  AppSelectOption<String>(
                    value: 'FEMALE',
                    label: l10n.labGenderFemaleLabel,
                    leadingIcon: const Icon(Icons.female),
                  ),
                  AppSelectOption<String>(
                    value: 'OTHER',
                    label: l10n.labGenderOtherLabel,
                    leadingIcon: const Icon(Icons.diversity_3_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'UNKNOWN',
                    label: l10n.labGenderUnknownLabel,
                    leadingIcon: const Icon(Icons.help_outline),
                  ),
                ],
                onChanged: (String? value) =>
                    setState(() => _gender = value ?? _anyGenderValue),
              ),
              right: AppSelectField<String>.searchable(
                value: _ageUnit,
                labelText: l10n.labAgeUnitLabel,
                enabled: !_isSaving,
                allowClear: false,
                options: <AppSelectOption<String>>[
                  AppSelectOption<String>(
                    value: 'DAY',
                    label: l10n.labAgeUnitDays,
                    leadingIcon: const Icon(Icons.today_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'WEEK',
                    label: l10n.labAgeUnitWeeks,
                    leadingIcon: const Icon(Icons.view_week_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'MONTH',
                    label: l10n.labAgeUnitMonths,
                    leadingIcon: const Icon(Icons.calendar_view_month_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'YEAR',
                    label: l10n.labAgeUnitYears,
                    leadingIcon: const Icon(Icons.event_outlined),
                  ),
                ],
                onChanged: (String? value) => setState(() => _ageUnit = value),
              ),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _ageMinController,
                labelText: l10n.labAgeMinLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: _nonNegativeNumberValidator(l10n),
              ),
              right: AppTextField(
                controller: _ageMaxController,
                labelText: l10n.labAgeMaxLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: _orderedNumberValidator(
                  l10n,
                  _ageMinController,
                  allowEqual: false,
                  integerOnly: true,
                  nonNegative: true,
                ),
              ),
            ),
            LabSearchableTextField(
              controller: _rangeUnitController,
              labelText: l10n.labResultUnitLabel,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.straighten_outlined),
              options: _unitOptionsCatalog,
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _normalMinController,
                labelText: l10n.labNormalMinLabel,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _decimalNumberValidator(l10n),
              ),
              right: AppTextField(
                controller: _normalMaxController,
                labelText: l10n.labNormalMaxLabel,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _orderedNumberValidator(
                  l10n,
                  _normalMinController,
                  allowEqual: true,
                  integerOnly: false,
                ),
              ),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _criticalMinController,
                labelText: l10n.labCriticalMinLabel,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _decimalNumberValidator(l10n),
              ),
              right: AppTextField(
                controller: _criticalMaxController,
                labelText: l10n.labCriticalMaxLabel,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _orderedNumberValidator(
                  l10n,
                  _criticalMinController,
                  allowEqual: true,
                  integerOnly: false,
                ),
              ),
            ),
            AppTextField(
              controller: _referenceTextController,
              labelText: l10n.labReferenceTextLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
            AppTextField(
              controller: _rangeNotesController,
              labelText: l10n.labReferenceNotesLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: _isCreateMode
            ? l10n.labCreateTestAction
            : l10n.commonSaveActionLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<String> get _testNameOptions {
    return _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.name),
    );
  }

  List<String> get _categoryOptions {
    return _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.category),
    );
  }

  List<String> get _specimenOptions {
    return _uniqueNonEmpty(
      widget.catalogTests.map((LabCatalogItem item) => item.specimenType),
    );
  }

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

  List<String> _rangeLabelOptions(AppLocalizations l10n) {
    return _uniqueNonEmpty(<String?>[
      l10n.labAdultRangeLabel,
      l10n.labPediatricRangeLabel,
      l10n.labNeonateRangeLabel,
      for (final LabCatalogItem item in widget.catalogTests)
        for (final LabReferenceRange range in item.referenceRanges) range.label,
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
    final LabCatalogItem? item = widget.item;
    if (item == null) {
      return false;
    }
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
    if (_isCreateMode && widget.tenantId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = _isCreateMode
        ? await widget.onCreate(_payload())
        : await widget.onUpdate(widget.item!.apiId, _payload());
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
    return _isRangeValid(
          _normalMinController.text,
          _normalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          _criticalMinController.text,
          _criticalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          _ageMinController.text,
          _ageMaxController.text,
          allowEqual: false,
        );
  }

  bool _isRangeValid(
    String minValue,
    String maxValue, {
    required bool allowEqual,
  }) {
    final String minText = minValue.trim();
    final String maxText = maxValue.trim();
    if (minText.isEmpty || maxText.isEmpty) {
      return true;
    }
    final num? minNumber = num.tryParse(minText);
    final num? maxNumber = num.tryParse(maxText);
    if (minNumber == null || maxNumber == null) {
      return false;
    }
    return allowEqual ? minNumber <= maxNumber : minNumber < maxNumber;
  }

  Map<String, Object?> _payload() {
    final String unit = _unitController.text.trim();
    final List<Map<String, Object?>> referenceRanges = _referenceRangePayloads(
      unit,
    );
    return <String, Object?>{
      if (_isCreateMode) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
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
    final LabReferenceRange? existingRange =
        widget.item?.referenceRanges.isEmpty ?? true
        ? null
        : widget.item!.referenceRanges.first;
    final Map<String, Object?> firstRange = <String, Object?>{
      if (existingRange != null) 'id': existingRange.id,
      'label': _rangeLabelController.text.trim(),
      if (_gender != null && _gender != _anyGenderValue) 'gender': _gender,
      'age_min_value': _ageMinController.text.trim(),
      'age_min_unit': _ageMinController.text.trim().isEmpty ? null : _ageUnit,
      'age_max_value': _ageMaxController.text.trim(),
      'age_max_unit': _ageMaxController.text.trim().isEmpty ? null : _ageUnit,
      'unit': _rangeUnitController.text.trim().isEmpty
          ? unit
          : _rangeUnitController.text.trim(),
      'normal_min_value': _normalMinController.text.trim(),
      'normal_max_value': _normalMaxController.text.trim(),
      'critical_min_value': _criticalMinController.text.trim(),
      'critical_max_value': _criticalMaxController.text.trim(),
      'reference_text': _referenceTextController.text.trim(),
      'notes': _rangeNotesController.text.trim(),
      'sort_order': 0,
    };
    if (_rangeHasContent(firstRange)) {
      payloads.add(firstRange);
    }
    final Iterable<LabReferenceRange> additionalRanges =
        widget.item?.referenceRanges.skip(1) ?? const <LabReferenceRange>[];
    for (final LabReferenceRange range in additionalRanges) {
      payloads.add(_existingRangePayload(range));
    }
    return payloads;
  }

  Map<String, Object?> _existingRangePayload(LabReferenceRange range) {
    return <String, Object?>{
      'id': range.id,
      'label': range.label,
      'gender': range.gender,
      'age_min_value': range.ageMinValue,
      'age_min_unit': range.ageMinUnit,
      'age_max_value': range.ageMaxValue,
      'age_max_unit': range.ageMaxUnit,
      'unit': range.unit,
      'normal_min_value': range.normalMinValue,
      'normal_max_value': range.normalMaxValue,
      'critical_min_value': range.criticalMinValue,
      'critical_max_value': range.criticalMaxValue,
      'reference_text': range.referenceText,
      'notes': range.notes,
      'sort_order': range.sortOrder,
    };
  }

  bool _rangeHasContent(Map<String, Object?> range) {
    return range.entries.any((MapEntry<String, Object?> entry) {
      if (entry.key == 'id' ||
          entry.key == 'sort_order' ||
          entry.key == 'unit' ||
          entry.key == 'age_min_unit' ||
          entry.key == 'age_max_unit') {
        return false;
      }
      final Object? value = entry.value;
      return value != null && value.toString().trim().isNotEmpty;
    });
  }
}

class LabCatalogPanelDialog extends StatefulWidget {
  const LabCatalogPanelDialog({
    required this.catalogTests,
    required this.catalogPanels,
    required this.onCreate,
    required this.onUpdate,
    this.item,
    this.tenantId,
    super.key,
  });

  final List<LabCatalogItem> catalogTests;
  final List<LabCatalogItem> catalogPanels;
  final LabCatalogItem? item;
  final String? tenantId;
  final LabCatalogSubmit onCreate;
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
  String? _pendingTestId;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _isCreateMode => widget.item == null;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem? item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _selectedTests = _initialSelectedTests(item);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isCreateMode
            ? l10n.labCreatePanelDialogTitle
            : l10n.labUpdatePanelDialogTitle,
      ),
      icon: Icon(
        _isCreateMode
            ? Icons.dashboard_customize_outlined
            : Icons.edit_outlined,
      ),
      scrollable: true,
      maxWidth: 860,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: LabSearchableTextField(
                controller: _nameController,
                labelText: l10n.labPanelNameLabel,
                enabled: !_isSaving,
                isRequired: true,
                prefixIcon: const Icon(Icons.dashboard_customize_outlined),
                options: _panelNameOptions,
                validator: (String? value) {
                  final String? requiredFailure = AppValidators.requiredText(
                    l10n.validationRequired,
                  )(value);
                  if (requiredFailure != null) {
                    return requiredFailure;
                  }
                  return _hasDuplicateName(value)
                      ? l10n.labDuplicatePanelNameMessage
                      : null;
                },
              ),
              right: AppTextField(
                controller: _codeController,
                labelText: l10n.labPanelCodeLabel,
                enabled: !_isSaving,
                prefixIcon: const Icon(Icons.tag_outlined),
                validator: (String? value) => _hasDuplicateCode(value)
                    ? l10n.labDuplicatePanelCodeMessage
                    : null,
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
              enabled: !_isSaving,
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
        submitLabel: _isCreateMode
            ? l10n.labCreatePanelAction
            : l10n.labUpdatePanelAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<LabCatalogItem> _initialSelectedTests(LabCatalogItem? item) {
    if (item == null) {
      return <LabCatalogItem>[];
    }
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

  List<String> get _panelNameOptions {
    return _uniqueNonEmpty(
      widget.catalogPanels.map((LabCatalogItem item) => item.name),
    );
  }

  List<String> get _categoryOptions {
    return _uniqueNonEmpty(<String?>[
      ...widget.catalogTests.map((LabCatalogItem item) => item.category),
      ...widget.catalogPanels.map((LabCatalogItem item) => item.category),
    ]);
  }

  bool _hasDuplicateName(String? value) {
    final String normalized = _normalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogPanels.any(
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
    return widget.catalogPanels.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          _normalizeCatalogToken(item.code) == normalized,
    );
  }

  bool _isCurrentItem(LabCatalogItem candidate) {
    final LabCatalogItem? item = widget.item;
    if (item == null) {
      return false;
    }
    return candidate.id == item.id ||
        candidate.apiId == item.apiId ||
        candidate.displayId == item.displayId;
  }

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
    if ((_isCreateMode && widget.tenantId == null) || _selectedTests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = _isCreateMode
        ? await widget.onCreate(_payload())
        : await widget.onUpdate(widget.item!.apiId, _payload());
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
      if (_isCreateMode) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'panel_items': _selectedTests
          .asMap()
          .entries
          .map((MapEntry<int, LabCatalogItem> entry) {
            return <String, Object?>{
              'lab_test_id': entry.value.apiId,
              'is_required': true,
              'instructions': null,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
    };
  }
}

class LabDeleteReasonDialog extends StatefulWidget {
  const LabDeleteReasonDialog({
    required this.title,
    required this.body,
    required this.submitLabel,
    required this.onDelete,
    this.icon = const Icon(Icons.delete_outline),
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
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
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.delete_outline,
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
          _EmptyInlineText(text: l10n.labPanelNoSelectedTests)
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
          AppIconButton(
            icon: Icons.close,
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
          suffixIcon: IconButton(
            tooltip: l10n.labAddValueAction,
            onPressed: widget.enabled ? _addCurrentValue : null,
            icon: const Icon(Icons.add),
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

class _EmptyInlineText extends StatelessWidget {
  const _EmptyInlineText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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

List<Widget> _dialogActions(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

FormFieldValidator<String> _decimalNumberValidator(AppLocalizations l10n) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty || num.tryParse(text) != null) {
      return null;
    }
    return l10n.labNumericRangeValidationMessage;
  };
}

FormFieldValidator<String> _nonNegativeNumberValidator(AppLocalizations l10n) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(text);
    if (parsed != null && parsed >= 0) {
      return null;
    }
    return l10n.labNumericRangeValidationMessage;
  };
}

FormFieldValidator<String> _orderedNumberValidator(
  AppLocalizations l10n,
  TextEditingController minController, {
  required bool allowEqual,
  required bool integerOnly,
  bool nonNegative = false,
}) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final num? parsed = integerOnly ? int.tryParse(text) : num.tryParse(text);
    if (parsed == null || (nonNegative && parsed < 0)) {
      return l10n.labNumericRangeValidationMessage;
    }
    final String minText = minController.text.trim();
    if (minText.isEmpty) {
      return null;
    }
    final num? minValue = integerOnly
        ? int.tryParse(minText)
        : num.tryParse(minText);
    if (minValue == null || (nonNegative && minValue < 0)) {
      return null;
    }
    final bool inOrder = allowEqual ? minValue <= parsed : minValue < parsed;
    return inOrder ? null : l10n.labNumericRangeValidationMessage;
  };
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
