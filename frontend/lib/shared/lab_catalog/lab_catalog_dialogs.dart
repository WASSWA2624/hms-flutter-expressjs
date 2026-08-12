import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_constants.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_fields.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_test_definition_form.dart';

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
  bool _isRegisteringPatient = false;
  int _patientSearchGeneration = 0;
  int _patientContextGeneration = 0;

  bool get _isEditing => widget.order != null;

  bool get _canRegisterPatient {
    return canCreatePatientViaLab(ref.watch(appAccessPolicyProvider));
  }

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
      pinActionsToBottom: true,
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
              isLoading: _isLoadingPatients || _isRegisteringPatient,
              enabled: !_isRegisteringPatient,
              options: _toSelectOptions(_patientOptions),
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onSearchTextChanged: _schedulePatientSearch,
              onChanged: _selectPatient,
            ),
            if (!_isEditing && _canRegisterPatient)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.secondary(
                  label: l10n.patientsRegisterNewPatientTitle,
                  leadingIcon: AppActionIcons.personAdd,
                  isLoading: _isRegisteringPatient,
                  enabled: !_isRegisteringPatient,
                  onPressed: _registerNewPatient,
                ),
              ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppSelectField<String>.searchable(
                value: _selectedEncounterId,
                labelText: l10n.labEncounterContextLabel,
                hintText: l10n.labEncounterContextHint,
                enabled:
                    !_isRegisteringPatient &&
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
                enabled: !_isRegisteringPatient,
                options: _toSelectOptions(_orderOptions),
                onChanged: _selectOrderContext,
              ),
            ),
            Text(
              l10n.labEncounterAutoCreateHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          enabled: !_isRegisteringPatient,
          onPressed: _isRegisteringPatient ? null : _submit,
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

  Future<void> _registerNewPatient() async {
    if (_isRegisteringPatient || !_canRegisterPatient) {
      return;
    }
    setState(() {
      _isRegisteringPatient = true;
      _failure = null;
    });
    final Result<PatientReferenceData> referenceResult = await ref
        .read(patientRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return;
    }
    final PatientReferenceData? referenceData = referenceResult.when(
      success: (PatientReferenceData data) => data,
      failure: (AppFailure failure) {
        setState(() {
          _isRegisteringPatient = false;
          _failure = failure;
        });
        return null;
      },
    );
    if (referenceData == null || !mounted) {
      return;
    }

    final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
    final PatientRegistrationResult? registration =
        await showRegisterNewPatientDialog(
          context: context,
          referenceData: referenceData,
          registrationScope: PatientRegistrationScope.resolve(
            referenceData: referenceData,
            accessPolicy: accessPolicy,
          ),
          onSubmit: (Map<String, Object?> payload) {
            return ref.read(patientRepositoryProvider).createPatient(payload);
          },
          onLookupDuplicates: (PatientDuplicateQuery query) {
            return ref
                .read(patientRepositoryProvider)
                .listDuplicateCandidates(query);
          },
        );
    if (!mounted) {
      return;
    }
    if (registration == null) {
      setState(() => _isRegisteringPatient = false);
      return;
    }

    final Patient patient = registration.patient;
    final String patientId = _firstNonEmpty(<String?>[
      patient.publicId,
      patient.id,
    ]);
    final _LabContextOption option = _LabContextOption(
      value: patientId,
      label: patient.effectiveDisplayName.isEmpty
          ? patientId
          : patient.effectiveDisplayName,
      subtitle: patient.effectiveIdentifier,
      icon: Icons.person_outline,
      searchText: _joinNonEmpty(<String?>[
        patient.effectiveDisplayName,
        patient.publicId,
        patient.id,
        patient.primaryPhone,
      ]),
    );
    setState(() {
      _isRegisteringPatient = false;
      _selectedPatientId = patientId;
      _selectedPatientOption = option;
      _searchedPatientOptions
        ..removeWhere(
          (_LabContextOption item) =>
              item.value.toLowerCase() == patientId.toLowerCase(),
        )
        ..insert(0, option);
      _selectedEncounterId = null;
      _selectedOrderId = null;
      _patientEncounters.clear();
      _failure = null;
    });
    unawaited(_loadPatientContext(patientId));
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
  late List<EditableLabValue> _unitOptions;
  late List<EditableLabValue> _resultOptions;
  late List<EditableLabReferenceRange> _referenceRanges;
  late final TextEditingController _priceController;
  String? _resultKind;
  String _currency = appDefaultCurrencyCode;
  bool _isOfferedAtFacility = false;
  AppFailure? _failure;
  bool _isSaving = false;
  String? _rangeErrorText;

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
        .map(EditableLabValue.fromUnitOption)
        .where((EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _resultOptions = item.resultOptions
        .map(EditableLabValue.fromResultOption)
        .where((EditableLabValue value) => value.value.trim().isNotEmpty)
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

    _cachedCategoryOptions = labUniqueNonEmpty(<String?>[
      ...kLabCatalogCategories,
      for (final LabCatalogItem item in widget.catalogTests) item.category,
    ]);
    _cachedSpecimenOptions = labUniqueNonEmpty(<String?>[
      ...kLabCatalogSpecimenTypes,
      for (final LabCatalogItem item in widget.catalogTests) item.specimenType,
    ]);
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
            AppFormSection(
              title: l10n.labOfferAtFacilityLabel,
              description: widget.item.usesPlatformDefaults
                  ? l10n.labPlatformDefaultsHint
                  : null,
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.labOfferAtFacilityLabel),
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
                      ? (String? value) =>
                            _positiveUnitPriceValidator(l10n, value)
                      : null,
                ),
              ],
            ),
            LabTestDefinitionForm(
              nameController: _nameController,
              codeController: _codeController,
              categoryController: _categoryController,
              specimenController: _specimenController,
              unitController: _unitController,
              descriptionController: _descriptionController,
              resultKind: _resultKind,
              onResultKindChanged: (String? value) =>
                  setState(() => _resultKind = value),
              unitOptions: _unitOptions,
              resultOptions: _resultOptions,
              referenceRanges: _referenceRanges,
              categoryOptions: _categoryOptions,
              specimenOptions: _specimenOptions,
              unitSuggestions: _unitOptionsCatalog,
              resultSuggestions: _resultOptionsCatalog(l10n),
              enabled: !_isSaving,
              nameEnabled: false,
              codeEnabled: false,
              rangeErrorText: _rangeErrorText,
              namePrefixIcon: const Icon(Icons.science_outlined),
              nameValidator: (String? value) {
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
              codeValidator: (String? value) => _hasDuplicateCode(value)
                  ? l10n.labDuplicateTestCodeMessage
                  : null,
              onUnitOptionAdd: (String value) {
                setState(
                  () => _unitOptions.add(EditableLabValue(value: value)),
                );
              },
              onUnitOptionRemove: (EditableLabValue value) {
                setState(() => _unitOptions.remove(value));
              },
              onResultOptionAdd: (String value) {
                setState(
                  () => _resultOptions.add(EditableLabValue(value: value)),
                );
              },
              onResultOptionRemove: (EditableLabValue value) {
                setState(() => _resultOptions.remove(value));
              },
              onRangesChanged: () {
                setState(() => _syncRangeValidationFeedback());
              },
              onRangeAdd: () {
                final EditableLabReferenceRange next =
                    EditableLabReferenceRange(
                      defaultUnit: _unitController.text.trim(),
                      defaultLabel: context.l10n.labAgeAnyLabel,
                    );
                final List<EditableLabReferenceRange> proposed =
                    <EditableLabReferenceRange>[
                      ..._referenceRanges,
                      next,
                    ];
                if (labReferenceRangesHaveDuplicateApplicability(proposed)) {
                  next.dispose();
                  setState(
                    () => _rangeErrorText =
                        l10n.labReferenceRangeDuplicateMessage,
                  );
                  return;
                }
                setState(() {
                  _rangeErrorText = null;
                  _failure = null;
                  _referenceRanges.add(next);
                });
              },
              onRangeRemove: (EditableLabReferenceRange range) {
                setState(() {
                  range.dispose();
                  _referenceRanges.remove(range);
                  _syncRangeValidationFeedback();
                });
              },
            ),
          ],
        ),
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.commonSaveActionLabel,
        submitIcon: Icons.save_outlined,
        isSubmitting: _isSaving,
        onCancel: () => Navigator.of(context).pop(false),
        onSubmit: _submit,
      ),
    );
  }

  List<String> get _categoryOptions => _cachedCategoryOptions;

  List<String> get _specimenOptions => _cachedSpecimenOptions;

  List<String> get _unitOptionsCatalog {
    return labUniqueNonEmpty(<String?>[
      for (final LabCatalogItem item in widget.catalogTests) item.unit,
      for (final LabCatalogItem item in widget.catalogTests)
        for (final LabUnitOption option in item.unitOptions)
          option.unit ?? option.label,
      for (final EditableLabValue option in _unitOptions) option.value,
    ]);
  }

  List<String> _resultOptionsCatalog(AppLocalizations l10n) {
    return labUniqueNonEmpty(<String?>[
      l10n.labPositiveOption,
      l10n.labNegativeOption,
      for (final LabCatalogItem item in widget.catalogTests)
        for (final LabResultOption option in item.resultOptions)
          option.value ?? option.label,
      for (final EditableLabValue option in _resultOptions) option.value,
    ]);
  }

  bool _hasDuplicateName(String? value) {
    final String normalized = labNormalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogTests.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          labNormalizeCatalogToken(item.name) == normalized,
    );
  }

  bool _hasDuplicateCode(String? value) {
    final String normalized = labNormalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogTests.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          labNormalizeCatalogToken(item.code) == normalized,
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
      setState(() {
        _failure = AppFailure.validation();
        _rangeErrorText = _rangeValidationMessage();
      });
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
    if (labReferenceRangesHaveDuplicateApplicability(_referenceRanges)) {
      return false;
    }
    return _referenceRanges.every(
      (EditableLabReferenceRange range) => range.isValid(),
    );
  }

  String? _rangeValidationMessage() {
    final AppLocalizations l10n = context.l10n;
    if (labReferenceRangesHaveDuplicateApplicability(_referenceRanges)) {
      return l10n.labReferenceRangeDuplicateMessage;
    }
    for (final EditableLabReferenceRange range in _referenceRanges) {
      if (!range.isValid()) {
        if (range.contradictsCriticalVsNormal()) {
          return l10n.labReferenceRangeCriticalVsNormalMessage;
        }
        if (range.hasNonNumericBound()) {
          return l10n.labReferenceRangeInvalidValueMessage;
        }
        return l10n.labReferenceRangeInvalidBoundsMessage;
      }
    }
    return null;
  }

  void _syncRangeValidationFeedback() {
    final String? nextError = _rangeValidationMessage();
    _rangeErrorText = nextError;
    if (nextError == null) {
      _failure = null;
    }
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
          .map((MapEntry<int, EditableLabValue> entry) {
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
          .map((MapEntry<int, EditableLabValue> entry) {
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
      if (!range.hasContent(unit)) {
        continue;
      }
      payloads.addAll(
        range.toPayloads(
          startSortOrder: payloads.length,
          fallbackUnit: unit,
        ),
      );
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

    _cachedPanelNameOptions = labUniqueNonEmpty(
      widget.catalogPanels.map((LabCatalogItem item) => item.name),
    );
    _cachedPanelCategoryOptions = labUniqueNonEmpty(<String?>[
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
            AppSelectField<String>.searchable(
              value: () {
                final String trimmed = _categoryController.text.trim();
                return trimmed.isEmpty ? null : trimmed;
              }(),
              labelText: l10n.labCategoryLabel,
              enabled: !_isSaving,
              menuHeight: 320,
              emptyResultsText: l10n.appSelectNoResults,
              options: labCatalogStringSelectOptions(
                _categoryOptions,
                iconForValue: labCatalogCategoryIcon,
                includeValue: _categoryController.text.trim().isEmpty
                    ? null
                    : _categoryController.text.trim(),
              ),
              onChanged: (String? value) {
                setState(() {
                  _categoryController.text = value?.trim() ?? '';
                });
              },
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.labPanelDescriptionLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
            LabPanelTestPicker(
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
          labNormalizeCatalogToken(test.code) ==
              labNormalizeCatalogToken(panelItem.testCode)) {
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

enum _LabEnableWizardStep { catalog, price, preview }

class LabEnableFacilityOfferingDialog extends StatefulWidget {
  const LabEnableFacilityOfferingDialog({
    required this.kind,
    required this.scope,
    required this.onSearchCatalog,
    required this.onEnable,
    this.defaultCurrency = appDefaultCurrencyCode,
    this.showBackAction = false,
    super.key,
  });

  /// Sentinel popped when the user presses Back to return to the scope step.
  static const Object backResult = Object();

  final LabEnableOfferingKind kind;
  final LabCatalogScope scope;
  final LabEnableOfferingCatalogSearch onSearchCatalog;
  final LabEnableOfferingSubmit onEnable;
  final String defaultCurrency;

  /// When true, catalog-step Back returns [backResult] to revisit the scope step.
  final bool showBackAction;

  @override
  State<LabEnableFacilityOfferingDialog> createState() =>
      _LabEnableFacilityOfferingDialogState();
}

class _LabEnableFacilityOfferingDialogState
    extends State<LabEnableFacilityOfferingDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const int _searchLimit = 100;
  static const String _typeFilterKey = 'type';
  static const String _statusFilterKey = 'status';
  static const String _statusAvailableValue = 'available';
  static const String _statusConfiguredValue = 'configured';
  static const String _categoryFilterKey = 'category';
  static const String _resultKindFilterKey = 'result_kind';
  static const String _specimenFilterKey = 'specimen_type';
  static const String _sourceFilterKey = 'source';

  late final TextEditingController _searchController;
  late final ValueNotifier<Set<String>> _selectedIds;
  final GlobalKey<FormState> _priceFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _priceControllers =
      <String, TextEditingController>{};
  final Map<String, String> _currencies = <String, String>{};
  Timer? _searchDebounce;
  List<LabCatalogItem> _catalogItems = const <LabCatalogItem>[];
  AppFailure? _failure;
  bool _isSearching = true;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  bool _enabledAny = false;
  _LabEnableWizardStep _step = _LabEnableWizardStep.catalog;
  bool _isSaving = false;

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

  List<LabCatalogItem> get _availableCatalogItems {
    return _catalogItems
        .where((LabCatalogItem item) => !item.isOfferedAtFacility)
        .toList(growable: false);
  }

  List<LabCatalogItem> get _filteredCatalogItems {
    final String? category = _filterValue.option(_categoryFilterKey);
    final String? resultKind = _filterValue.option(_resultKindFilterKey);
    final String? specimen = _filterValue.option(_specimenFilterKey);
    final String? source = _filterValue.option(_sourceFilterKey);
    final String? status = _filterValue.option(_statusFilterKey);
    final String? type = _selectedType;
    return _catalogItems
        .where((LabCatalogItem item) {
          if (_showingAll && type != null && item.type.name != type) {
            return false;
          }
          if (status != null && status.isNotEmpty) {
            final String itemStatus = item.isOfferedAtFacility
                ? _statusConfiguredValue
                : _statusAvailableValue;
            if (itemStatus != status) {
              return false;
            }
          }
          if (category != null &&
              category.isNotEmpty &&
              (item.category ?? '').trim() != category) {
            return false;
          }
          if (_includeResultKindFilter &&
              item.type == LabCatalogItemType.test &&
              resultKind != null &&
              resultKind.isNotEmpty &&
              (item.resultKind ?? '').trim().toUpperCase() !=
                  resultKind.toUpperCase()) {
            return false;
          }
          if (specimen != null &&
              specimen.isNotEmpty &&
              (item.specimenType ?? '').trim() != specimen) {
            return false;
          }
          if (source != null &&
              source.isNotEmpty &&
              (item.source ?? '').trim() != source) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<LabCatalogItem> get _sortedFilteredCatalogItems {
    final List<LabCatalogItem> items = List<LabCatalogItem>.of(
      _filteredCatalogItems,
    );
    items.sort((LabCatalogItem left, LabCatalogItem right) {
      // Keep already-offered rows visible but below selectable ones.
      if (left.isOfferedAtFacility != right.isOfferedAtFacility) {
        return left.isOfferedAtFacility ? 1 : -1;
      }
      return appListTableCompareText(left.name, right.name);
    });
    return items;
  }

  List<LabCatalogItem> get _selectableListedCatalogItems {
    return _sortedFilteredCatalogItems
        .where((LabCatalogItem item) => !item.isOfferedAtFacility)
        .toList(growable: false);
  }

  List<LabCatalogItem> get _selectedAvailableItems {
    return _selectedAvailableItemsFor(_selectedIds.value);
  }

  List<LabCatalogItem> _selectedAvailableItemsFor(Set<String> selectedIds) {
    return _availableCatalogItems
        .where(
          (LabCatalogItem item) =>
              selectedIds.contains(_labEnableCatalogItemKey(item)),
        )
        .toList(growable: false)
      ..sort(
        (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.name, right.name),
      );
  }

  void _markItemsOfferedLocally(List<LabCatalogItem> items) {
    if (items.isEmpty) {
      return;
    }
    final Map<String, LabCatalogItem> byKey = <String, LabCatalogItem>{
      for (final LabCatalogItem item in items)
        _labEnableCatalogItemKey(item): item,
    };
    setState(() {
      _catalogItems = _catalogItems
          .map((LabCatalogItem catalogItem) {
            final LabCatalogItem? updated =
                byKey[_labEnableCatalogItemKey(catalogItem)];
            if (updated == null) {
              return catalogItem;
            }
            return catalogItem.copyWith(
              unitPrice: updated.unitPrice ?? catalogItem.unitPrice,
              currency: updated.currency ?? catalogItem.currency,
              isOfferedAtFacility: true,
              facilityOfferingId:
                  updated.facilityOfferingId ?? catalogItem.facilityOfferingId,
            );
          })
          .toList(growable: false);
      _selectedIds.value = Set<String>.of(_selectedIds.value)
        ..removeAll(byKey.keys);
      _enabledAny = true;
    });
  }

  void _pruneSelection() {
    final Set<String> valid = _availableCatalogItems
        .map(_labEnableCatalogItemKey)
        .toSet();
    final Set<String> next = _selectedIds.value
        .where(valid.contains)
        .toSet();
    if (next.length != _selectedIds.value.length ||
        !next.containsAll(_selectedIds.value)) {
      _selectedIds.value = next;
    }
  }

  void _toggleSelection(LabCatalogItem item, {required bool selected}) {
    if (item.isOfferedAtFacility) {
      return;
    }
    final String key = _labEnableCatalogItemKey(item);
    final Set<String> next = Set<String>.of(_selectedIds.value);
    if (selected) {
      next.add(key);
    } else {
      next.remove(key);
    }
    _selectedIds.value = next;
    // Catalog checkboxes listen via ValueListenableBuilder; rebuild only when
    // selection drives price/preview content.
    if (_step != _LabEnableWizardStep.catalog) {
      setState(() {});
    }
  }

  void _selectAllListed() {
    final Set<String> listed = _selectableListedCatalogItems
        .map(_labEnableCatalogItemKey)
        .toSet();
    if (listed.isEmpty) {
      return;
    }
    _selectedIds.value = Set<String>.of(_selectedIds.value)..addAll(listed);
  }

  void _deselectAllListed() {
    final Set<String> listed = _selectableListedCatalogItems
        .map(_labEnableCatalogItemKey)
        .toSet();
    if (listed.isEmpty || _selectedIds.value.isEmpty) {
      return;
    }
    _selectedIds.value = Set<String>.of(_selectedIds.value)..removeAll(listed);
  }

  void _setListedSelection({required bool selected}) {
    if (selected) {
      _selectAllListed();
    } else {
      _deselectAllListed();
    }
  }

  void _ensurePriceFields(List<LabCatalogItem> items) {
    for (final LabCatalogItem item in items) {
      final String key = _labEnableCatalogItemKey(item);
      _priceControllers.putIfAbsent(key, () {
        // Panels use an independent facility price. Never suggest a catalog
        // default that may have been derived from member-test pricing.
        if (item.type == LabCatalogItemType.panel) {
          return TextEditingController();
        }
        return TextEditingController(
          text: item.unitPrice == null
              ? ''
              : formatCurrencyAmountInput(item.unitPrice!),
        );
      });
      _currencies.putIfAbsent(
        key,
        () => item.currency ?? widget.defaultCurrency,
      );
    }
  }

  String _priceDisplay(LabCatalogItem item) {
    final String key = _labEnableCatalogItemKey(item);
    final TextEditingController? controller = _priceControllers[key];
    final String amount = controller?.text.trim().isNotEmpty == true
        ? controller!.text.trim()
        : (item.type == LabCatalogItemType.panel || item.unitPrice == null
              ? ''
              : formatCurrencyAmountInput(item.unitPrice!));
    final String currency =
        _currencies[key] ?? item.currency ?? widget.defaultCurrency;
    if (amount.isEmpty) {
      return currency;
    }
    return '$amount $currency';
  }

  bool _selectionHasValidPrices(List<LabCatalogItem> items) {
    for (final LabCatalogItem item in items) {
      final String raw =
          _priceControllers[_labEnableCatalogItemKey(item)]?.text ?? '';
      final String normalized = normalizeCurrencyAmount(raw);
      final num? parsed = num.tryParse(normalized);
      if (parsed == null || parsed <= 0) {
        return false;
      }
    }
    return items.isNotEmpty;
  }

  void _goToCatalog() {
    setState(() {
      _step = _LabEnableWizardStep.catalog;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPriceStep() {
    final List<LabCatalogItem> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    _ensurePriceFields(selected);
    setState(() {
      _step = _LabEnableWizardStep.price;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPreview() {
    final List<LabCatalogItem> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    if (!(_priceFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_selectionHasValidPrices(selected)) {
      return;
    }
    setState(() {
      _step = _LabEnableWizardStep.preview;
      _failure = null;
      _isSaving = false;
    });
  }

  void _onWizardBack() {
    switch (_step) {
      case _LabEnableWizardStep.catalog:
        if (widget.showBackAction) {
          Navigator.of(context).pop(LabEnableFacilityOfferingDialog.backResult);
          return;
        }
        Navigator.of(context).pop(_enabledAny);
      case _LabEnableWizardStep.price:
        _goToCatalog();
      case _LabEnableWizardStep.preview:
        setState(() {
          _step = _LabEnableWizardStep.price;
          _failure = null;
          _isSaving = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedIds = ValueNotifier<Set<String>>(<String>{});
    _searchRequest += 1;
    unawaited(_loadCatalog(query: null, requestId: _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _selectedIds.dispose();
    for (final TextEditingController controller in _priceControllers.values) {
      controller.dispose();
    }
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
          _catalogItems = _dedupeLabCatalogItems(items);
          _isSearching = false;
          _pruneSelection();
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <LabCatalogItem>[];
          _isSearching = false;
          _failure = value;
          _selectedIds.value = <String>{};
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

  Future<void> _submitAllSelected() async {
    final List<LabCatalogItem> selected = _selectedAvailableItems
        .where((LabCatalogItem item) => !item.isOfferedAtFacility)
        .toList(growable: false);
    if (selected.isEmpty || !_selectionHasValidPrices(selected)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final List<LabCatalogItem> enabled = <LabCatalogItem>[];
    for (final LabCatalogItem item in selected) {
      if (item.isOfferedAtFacility) {
        continue;
      }
      final String key = _labEnableCatalogItemKey(item);
      final String currency =
          _currencies[key] ?? item.currency ?? widget.defaultCurrency;
      final num unitPrice =
          num.tryParse(
            normalizeCurrencyAmount(_priceControllers[key]?.text ?? ''),
          ) ??
          0;
      final AppFailure? failure = await widget.onEnable(item, <String, Object?>{
        'is_active': true,
        'unit_price': unitPrice,
        'currency': currency,
      });
      if (!mounted) {
        return;
      }
      if (failure != null) {
        if (enabled.isNotEmpty) {
          _markItemsOfferedLocally(enabled);
          setState(() {
            _step = _LabEnableWizardStep.catalog;
            _failure = failure;
            _isSaving = false;
          });
        } else {
          setState(() {
            _failure = failure;
            _isSaving = false;
          });
        }
        return;
      }
      enabled.add(item.copyWith(unitPrice: unitPrice, currency: currency));
    }
    _markItemsOfferedLocally(enabled);
    if (!mounted) {
      return;
    }
    // Stay open so newly offered rows remain visible as Configured and
    // cannot be selected again in the same session.
    setState(() {
      _step = _LabEnableWizardStep.catalog;
      _failure = null;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(_titleForStep(l10n)),
      icon: Icon(_iconForStep),
      scrollable: true,
      maxWidth: _step == _LabEnableWizardStep.catalog ? 980 : 720,
      closeEnabled: !_isSaving,
      content: switch (_step) {
        _LabEnableWizardStep.catalog => _buildCatalogStep(context),
        _LabEnableWizardStep.price => _buildPriceStep(context),
        _LabEnableWizardStep.preview => _buildPreviewStep(context),
      },
      actions: _buildActions(context),
    );
  }

  String _titleForStep(AppLocalizations l10n) {
    return switch (_step) {
      _LabEnableWizardStep.catalog => l10n.labEnableOfferingDialogTitle,
      _LabEnableWizardStep.price => l10n.labEnableOfferingSetPricesTitle,
      _LabEnableWizardStep.preview => l10n.labEnableOfferingPreviewTitle,
    };
  }

  IconData get _iconForStep {
    return switch (_step) {
      _LabEnableWizardStep.catalog => _showingPanelsOnly
          ? Icons.add_box_outlined
          : Icons.add_circle_outline,
      _LabEnableWizardStep.price => Icons.payments_outlined,
      _LabEnableWizardStep.preview => Icons.checklist_outlined,
    };
  }

  VoidCallback? get _backPressed {
    if (_isSaving) {
      return null;
    }
    return _onWizardBack;
  }

  List<Widget> _buildActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return <Widget>[
      AppButton.tertiary(
        label: l10n.commonBackActionLabel,
        leadingIcon: Icons.arrow_back_outlined,
        onPressed: _backPressed,
      ),
      if (_step == _LabEnableWizardStep.catalog)
        ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedIds,
          builder: (BuildContext context, Set<String> selectedIds, _) {
            final int selectedCount =
                _selectedAvailableItemsFor(selectedIds).length;
            final bool catalogCanNext = selectedCount > 0;
            final String nextLabel = catalogCanNext
                ? '${l10n.commonNextActionLabel} ($selectedCount)'
                : l10n.commonNextActionLabel;
            return AppButton.primary(
              label: nextLabel,
              leadingIcon: Icons.arrow_forward_outlined,
              enabled: catalogCanNext,
              tooltip: catalogCanNext
                  ? nextLabel
                  : l10n.labSelectAtLeastOneItemMessage,
              onPressed: catalogCanNext ? _goToPriceStep : null,
            );
          },
        ),
      if (_step == _LabEnableWizardStep.price)
        ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedIds,
          builder: (BuildContext context, Set<String> selectedIds, _) {
            final int selectedCount =
                _selectedAvailableItemsFor(selectedIds).length;
            return AppButton.primary(
              label: l10n.commonNextActionLabel,
              leadingIcon: Icons.arrow_forward_outlined,
              enabled: selectedCount > 0,
              tooltip: selectedCount > 0
                  ? l10n.commonNextActionLabel
                  : l10n.labSelectAtLeastOneItemMessage,
              onPressed: selectedCount > 0 ? _goToPreview : null,
            );
          },
        ),
      if (_step == _LabEnableWizardStep.preview)
        ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedIds,
          builder: (BuildContext context, Set<String> selectedIds, _) {
            final List<LabCatalogItem> selected =
                _selectedAvailableItemsFor(selectedIds);
            final bool previewCanEnable =
                selected.isNotEmpty && _selectionHasValidPrices(selected);
            return AppButton.primary(
              label: l10n.labEnableSelectedItemsAction,
              leadingIcon: Icons.check_circle_outline,
              isLoading: _isSaving,
              enabled: previewCanEnable && !_isSaving,
              tooltip: previewCanEnable
                  ? l10n.labEnableSelectedItemsAction
                  : l10n.labSelectAtLeastOneItemMessage,
              onPressed: previewCanEnable && !_isSaving
                  ? () => unawaited(_submitAllSelected())
                  : null,
            );
          },
        ),
      AppButton.tertiary(
        label: l10n.commonCloseActionLabel,
        leadingIcon: Icons.close,
        onPressed: _isSaving
            ? null
            : () => Navigator.of(context).pop(_enabledAny),
      ),
    ];
  }

  Widget _buildCatalogStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<LabCatalogItem> items = _sortedFilteredCatalogItems;
    final bool hasSearchOrFilter =
        _searchController.text.trim().isNotEmpty || _filterValue.isActive;
    final bool catalogEmpty = !_isSearching && _catalogItems.isEmpty;
    final bool allAlreadyOffered =
        !_isSearching &&
        _catalogItems.isNotEmpty &&
        _availableCatalogItems.isEmpty &&
        !hasSearchOrFilter;
    final String emptyLabel = hasSearchOrFilter
        ? l10n.clinicalLabRequestNoCatalogOptions
        : (catalogEmpty
              ? l10n.labEnableOfferingNoPlatformItemsLabel
              : l10n.labEnableOfferingNoItemsLabel);

    return Column(
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
        if (allAlreadyOffered)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Text(
              l10n.labEnableOfferingNoItemsLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedIds,
          builder: (BuildContext context, Set<String> selectedIds, _) {
            final List<LabCatalogItem> selectableListed =
                _selectableListedCatalogItems;
            final int listedCount = selectableListed.length;
            final int selectedListedCount = selectableListed
                .where(
                  (LabCatalogItem item) =>
                      selectedIds.contains(_labEnableCatalogItemKey(item)),
                )
                .length;
            if (listedCount == 0 || selectedListedCount == 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(top: theme.spacing.xs),
              child: Text(
                l10n.labSelectedTestCount(selectedListedCount, listedCount),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        if (_isSearching && items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        AppListTable<LabCatalogItem>(
          items: items,
          maxVisibleItems: _maxVisibleLabCatalogDialogItems,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          tableHorizontalMargin: 0,
          isLoading: _isSearching,
          loadingBuilder: (BuildContext context) => Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
            child: AppLoadingIndicator(
              title: l10n.commonLoadingTitle,
              body: l10n.commonLoadingBody,
            ),
          ),
          itemKeyBuilder: (LabCatalogItem item) =>
              ValueKey<String>(_labEnableCatalogItemKey(item)),
          onRowSelected: (LabCatalogItem item) {
            if (item.isOfferedAtFacility) {
              return;
            }
            final String key = _labEnableCatalogItemKey(item);
            _toggleSelection(
              item,
              selected: !_selectedIds.value.contains(key),
            );
          },
          search: AppListTableSearch<LabCatalogItem>(
            controller: _searchController,
            semanticLabel: l10n.labCatalogSearchLabel,
            hintText: l10n.labReferenceRangesSearchHint,
            isLoading: _isSearching,
            matcher: (LabCatalogItem item, String query) => true,
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
                key: _statusFilterKey,
                label: l10n.accessAdminColumnStatus,
                allLabel: l10n.labScopeAll,
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(
                    value: _statusAvailableValue,
                    label: l10n.labEnableOfferingAvailableLabel,
                    icon: Icons.radio_button_unchecked,
                  ),
                  AppSearchBarFilterChoice(
                    value: _statusConfiguredValue,
                    label: l10n.tenantFacilitySummaryConfigured,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              AppSearchBarFilterGroup(
                key: _categoryFilterKey,
                label: l10n.labCategoryLabel,
                allLabel: l10n.labScopeAll,
                choices: _enableOfferingFilterChoices(
                  _catalogItems.map((LabCatalogItem item) => item.category),
                  iconForValue: labCatalogCategoryIcon,
                ),
              ),
              if (_includeResultKindFilter)
                AppSearchBarFilterGroup(
                  key: _resultKindFilterKey,
                  label: l10n.labResultKindLabel,
                  allLabel: l10n.labScopeAll,
                  choices: _enableOfferingResultKindChoices(
                    l10n,
                    _catalogItems
                        .where(
                          (LabCatalogItem item) =>
                              item.type == LabCatalogItemType.test,
                        )
                        .map((LabCatalogItem item) => item.resultKind),
                  ),
                ),
              if (_enableOfferingFilterChoices(
                _catalogItems.map((LabCatalogItem item) => item.specimenType),
              ).isNotEmpty)
                AppSearchBarFilterGroup(
                  key: _specimenFilterKey,
                  label: l10n.labSpecimenTypeLabel,
                  allLabel: l10n.labScopeAll,
                  choices: _enableOfferingFilterChoices(
                    _catalogItems.map(
                      (LabCatalogItem item) => item.specimenType,
                    ),
                  ),
                ),
              if (_enableOfferingFilterChoices(
                _catalogItems.map((LabCatalogItem item) => item.source),
              ).isNotEmpty)
                AppSearchBarFilterGroup(
                  key: _sourceFilterKey,
                  label: l10n.radiologySourceColumnLabel,
                  allLabel: l10n.labScopeAll,
                  choices: _enableOfferingFilterChoices(
                    _catalogItems.map((LabCatalogItem item) => item.source),
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
            child: AppMutedText(emptyLabel, textAlign: TextAlign.center),
          ),
          columns: _enableOfferingColumns(context),
          mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
            final String key = _labEnableCatalogItemKey(item);
            final bool offered = item.isOfferedAtFacility;
            return AppListTableMobileItem(
              leading: Align(
                alignment: Alignment.centerLeft,
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedIds,
                  builder: (BuildContext context, Set<String> selected, _) {
                    return Checkbox(
                      value: offered ? false : selected.contains(key),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: offered
                          ? null
                          : (bool? value) =>
                                _toggleSelection(item, selected: value ?? false),
                    );
                  },
                ),
              ),
              showAvatar: false,
              title: item.name ?? item.displayTitle,
              caption: item.code,
              meta: <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: item.isOfferedAtFacility
                      ? l10n.tenantFacilitySummaryConfigured
                      : l10n.labEnableOfferingAvailableLabel,
                  icon: item.isOfferedAtFacility
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                ),
                if (_showingAll)
                  AppListTableMobileMeta(
                    label: item.type == LabCatalogItemType.panel
                        ? l10n.clinicalLabRequestPanelTypeLabel
                        : l10n.clinicalLabRequestTestTypeLabel,
                  ),
                AppListTableMobileMeta(
                  label: _joinEnableOfferingSubtitle(l10n, item),
                ),
              ],
            );
          },
        ),
        if (!_isSearching && items.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: AppMutedText(emptyLabel),
          ),
      ],
    );
  }

  Widget _buildPriceStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<LabCatalogItem> selected = _selectedAvailableItems;

    return Form(
      key: _priceFormKey,
      child: Column(
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
            l10n.labEnableSelectedItemsBody(selected.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (selected.isEmpty)
            AppMutedText(l10n.labEnableOfferingPreviewEmptyLabel)
          else
            ...selected.map((LabCatalogItem item) {
              final String key = _labEnableCatalogItemKey(item);
              final TextEditingController? controller = _priceControllers[key];
              if (controller == null) {
                return const SizedBox.shrink();
              }
              final String currency =
                  _currencies[key] ?? widget.defaultCurrency;
              return Padding(
                key: ValueKey<String>('lab-enable-price-$key'),
                padding: EdgeInsets.only(bottom: theme.spacing.lg),
                child: AppFormSection(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                item.name ?? item.displayTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: AppFontWeight.emphasis,
                                ),
                              ),
                              AppMutedText(
                                _joinEnableOfferingSubtitle(l10n, item),
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
                          onPressed: _isSaving
                              ? null
                              : () => _toggleSelection(
                                  item,
                                  selected: false,
                                ),
                        ),
                      ],
                    ),
                    AppCurrencyAmountField(
                      key: ValueKey<String>('lab-enable-amount-$key'),
                      amountController: controller,
                      currency: currency,
                      amountLabelText: l10n.clinicalRequestUnitPriceLabel,
                      currencyLabelText: l10n.opdCurrencyLabel,
                      enabled: !_isSaving,
                      isRequired: true,
                      allowZero: false,
                      onCurrencyChanged: (String? value) {
                        setState(() {
                          _currencies[key] = value ?? appDefaultCurrencyCode;
                        });
                      },
                      validator: (String? value) =>
                          _positiveUnitPriceValidator(l10n, value),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<LabCatalogItem> selected = _selectedAvailableItems;

    return Column(
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
          l10n.labEnableOfferingPreviewBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (selected.isEmpty)
          AppMutedText(l10n.labEnableOfferingPreviewEmptyLabel)
        else
          AppListTable<LabCatalogItem>(
            items: selected,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            tableHorizontalMargin: 0,
            itemKeyBuilder: (LabCatalogItem item) =>
                ValueKey<String>(_labEnableCatalogItemKey(item)),
            columns: <AppListTableColumn<LabCatalogItem>>[
              AppListTableColumn<LabCatalogItem>(
                id: 'select',
                label: l10n.commonSelectActionLabel,
                alwaysVisible: true,
                cellBuilder: (_, LabCatalogItem item) {
                  final String key = _labEnableCatalogItemKey(item);
                  return Checkbox(
                    value: _selectedIds.value.contains(key),
                    onChanged: _isSaving
                        ? null
                        : (bool? value) =>
                              _toggleSelection(item, selected: value ?? false),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
              AppListTableColumn<LabCatalogItem>(
                id: 'name',
                label: l10n.accessAdminColumnName,
                alwaysVisible: true,
                cellBuilder: (_, LabCatalogItem item) =>
                    Text(item.name ?? item.displayTitle),
              ),
              if (_showingAll)
                AppListTableColumn<LabCatalogItem>(
                  id: 'type',
                  label: l10n.clinicalRequestSelectedTypeColumnLabel,
                  cellBuilder: (_, LabCatalogItem item) => Text(
                    item.type == LabCatalogItemType.panel
                        ? l10n.clinicalLabRequestPanelTypeLabel
                        : l10n.clinicalLabRequestTestTypeLabel,
                  ),
                ),
              AppListTableColumn<LabCatalogItem>(
                id: 'code',
                label: l10n.labTestCodeLabel,
                cellBuilder: (_, LabCatalogItem item) =>
                    Text(item.code ?? l10n.profileUnknownValue),
              ),
              AppListTableColumn<LabCatalogItem>(
                id: 'category',
                label: l10n.labCategoryLabel,
                cellBuilder: (_, LabCatalogItem item) =>
                    Text(item.category ?? l10n.profileUnknownValue),
              ),
              AppListTableColumn<LabCatalogItem>(
                id: 'price',
                label: l10n.clinicalRequestUnitPriceLabel,
                alwaysVisible: true,
                cellBuilder: (_, LabCatalogItem item) =>
                    Text(_priceDisplay(item)),
              ),
            ],
            mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
              final String key = _labEnableCatalogItemKey(item);
              return AppListTableMobileItem(
                leading: Checkbox(
                  value: _selectedIds.value.contains(key),
                  onChanged: _isSaving
                      ? null
                      : (bool? value) =>
                            _toggleSelection(item, selected: value ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                showAvatar: false,
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
                    label: _priceDisplay(item),
                    icon: Icons.payments_outlined,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  List<AppListTableColumn<LabCatalogItem>> _enableOfferingColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool showTypeColumn = _showingAll && _selectedType == null;
    final bool showSpecimen =
        _showingTestsOnly || (_showingAll && !_showingPanelsOnly);
    return <AppListTableColumn<LabCatalogItem>>[
      AppListTableColumn<LabCatalogItem>(
        id: 'select',
        label: l10n.commonSelectActionLabel,
        alwaysVisible: true,
        headerBuilder: (BuildContext context) {
          final AppLocalizations headerL10n = context.l10n;
          return ValueListenableBuilder<Set<String>>(
            valueListenable: _selectedIds,
            builder: (BuildContext context, Set<String> selected, _) {
              final List<LabCatalogItem> listed =
                  _selectableListedCatalogItems;
              final bool allSelected =
                  listed.isNotEmpty &&
                  listed.every(
                    (LabCatalogItem item) =>
                        selected.contains(_labEnableCatalogItemKey(item)),
                  );
              final bool someSelected = listed.any(
                (LabCatalogItem item) =>
                    selected.contains(_labEnableCatalogItemKey(item)),
              );
              final bool? checkboxValue = allSelected
                  ? true
                  : someSelected
                  ? null
                  : false;
              final String tooltip = listed.isEmpty
                  ? headerL10n.commonSelectActionLabel
                  : allSelected
                  ? headerL10n.labClearSelectionAction
                  : someSelected
                  ? headerL10n.labSelectedTestCount(
                      listed
                          .where(
                            (LabCatalogItem item) => selected.contains(
                              _labEnableCatalogItemKey(item),
                            ),
                          )
                          .length,
                      listed.length,
                    )
                  : headerL10n.labSelectAllTestsAction;
              return Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: tooltip,
                  child: Semantics(
                    label: tooltip,
                    checked: allSelected,
                    mixed: someSelected && !allSelected,
                    child: Checkbox(
                      tristate: true,
                      value: checkboxValue,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: listed.isEmpty
                          ? null
                          : (bool? checked) => _setListedSelection(
                              selected: checked ?? false,
                            ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        cellBuilder: (_, LabCatalogItem item) {
          final String key = _labEnableCatalogItemKey(item);
          final bool offered = item.isOfferedAtFacility;
          return Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedIds,
              builder: (BuildContext context, Set<String> selected, _) {
                return Checkbox(
                  value: offered ? false : selected.contains(key),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: offered
                      ? null
                      : (bool? value) =>
                            _toggleSelection(item, selected: value ?? false),
                );
              },
            ),
          );
        },
      ),
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
      AppListTableColumn<LabCatalogItem>(
        id: 'status',
        label: l10n.accessAdminColumnStatus,
        alwaysVisible: true,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) {
          if (left.isOfferedAtFacility == right.isOfferedAtFacility) {
            return 0;
          }
          return left.isOfferedAtFacility ? 1 : -1;
        },
        cellBuilder: (BuildContext context, LabCatalogItem item) {
          return _labEnableOfferingStatusCell(context, item);
        },
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

String _labEnableCatalogItemKey(LabCatalogItem item) {
  final String apiId = item.apiId.trim();
  if (apiId.isNotEmpty) {
    return '${item.type.name}:$apiId';
  }
  final String code = (item.code ?? '').trim();
  if (code.isNotEmpty) {
    return '${item.type.name}:code:${code.toUpperCase()}';
  }
  return '${item.type.name}:id:${item.id.trim()}';
}

List<LabCatalogItem> _dedupeLabCatalogItems(List<LabCatalogItem> items) {
  if (items.length < 2) {
    return List<LabCatalogItem>.of(items, growable: false);
  }
  final Map<String, LabCatalogItem> byKey = <String, LabCatalogItem>{};
  for (final LabCatalogItem item in items) {
    final String key = _labEnableCatalogItemKey(item);
    final LabCatalogItem? existing = byKey[key];
    if (existing == null) {
      byKey[key] = item;
      continue;
    }
    // Prefer the offered row when duplicates share an identity key.
    if (item.isOfferedAtFacility && !existing.isOfferedAtFacility) {
      byKey[key] = item;
    }
  }
  return byKey.values.toList(growable: false);
}

List<AppSearchBarFilterChoice> _enableOfferingFilterChoices(
  Iterable<String?> values, {
  IconData Function(String value)? iconForValue,
}) {
  return labUniqueNonEmpty(values)
      .map(
        (String value) => AppSearchBarFilterChoice(
          value: value,
          label: value,
          icon: iconForValue?.call(value),
        ),
      )
      .toList(growable: false);
}

List<AppSearchBarFilterChoice> _enableOfferingResultKindChoices(
  AppLocalizations l10n,
  Iterable<String?> values,
) {
  final List<String> kinds = labUniqueNonEmpty(<String?>[
    'NUMERIC',
    'QUALITATIVE',
    'TEXT',
    ...values,
  ]);
  return kinds
      .map(
        (String value) => AppSearchBarFilterChoice(
          value: value,
          label: switch (value.toUpperCase()) {
            'NUMERIC' => l10n.labResultKindNumeric,
            'QUALITATIVE' => l10n.labResultKindQualitative,
            'TEXT' => l10n.labResultKindText,
            _ => value,
          },
        ),
      )
      .toList(growable: false);
}

Widget _labEnableOfferingStatusCell(
  BuildContext context,
  LabCatalogItem item,
) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final bool offered = item.isOfferedAtFacility;
  final String label = offered
      ? l10n.tenantFacilitySummaryConfigured
      : l10n.labEnableOfferingAvailableLabel;
  final String tooltip = offered
      ? l10n.labEnableOfferingAlreadyOfferedLabel
      : l10n.labEnableOfferingAvailableLabel;
  final Color color = offered
      ? theme.colorScheme.primary
      : theme.colorScheme.onSurfaceVariant;
  return Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          offered ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ],
    ),
  );
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

/// Standalone single-item price dialog (workspace / nested callers).
class LabEnableOfferingPriceDialog extends StatefulWidget {
  const LabEnableOfferingPriceDialog({
    required this.item,
    required this.kind,
    required this.onEnable,
    required this.defaultCurrency,
    this.showBackAction = false,
    super.key,
  });

  final LabCatalogItem item;
  final LabEnableOfferingKind kind;
  final LabEnableOfferingSubmit onEnable;
  final String defaultCurrency;
  final bool showBackAction;

  @override
  State<LabEnableOfferingPriceDialog> createState() =>
      _LabEnableOfferingPriceDialogState();
}

class _LabEnableOfferingPriceDialogState
    extends State<LabEnableOfferingPriceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _showingTests => widget.kind == LabEnableOfferingKind.test;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.unitPrice?.toString() ?? '',
    );
    _currency = widget.item.currency ?? widget.defaultCurrency;
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
                fontWeight: AppFontWeight.emphasis,
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
      actions: <Widget>[
        if (widget.showBackAction)
          AppButton.tertiary(
            label: l10n.commonBackActionLabel,
            leadingIcon: Icons.arrow_back_outlined,
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(false),
          ),
        ..._dialogActions(
          context,
          submitLabel: _showingTests
              ? l10n.labEnableTestAction
              : l10n.labEnablePanelAction,
          isSaving: _isSaving,
          onSubmit: _submit,
          submitIcon: Icons.check_circle_outline,
        ),
      ],
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
    this.showCancelButton = true,
    this.destructiveSubmit = true,
    this.confirmationTitle,
    this.confirmationBody,
    this.confirmationSubmitLabel,
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
  final bool showCancelButton;
  final bool destructiveSubmit;

  /// When set with [confirmationBody], submit opens a final irreversible
  /// confirmation before calling [onDelete].
  final String? confirmationTitle;
  final String? confirmationBody;
  final String? confirmationSubmitLabel;
  final Future<AppFailure?> Function(String reason) onDelete;

  bool get _requiresFinalConfirmation =>
      confirmationTitle != null &&
      confirmationTitle!.trim().isNotEmpty &&
      confirmationBody != null &&
      confirmationBody!.trim().isNotEmpty;

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
      pinActionsToBottom: true,
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
              autofocus: true,
              validator: AppValidators.requiredText(
                l10n.labDeleteReasonValidationMessage,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.showCancelButton)
          AppButton.close(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            enabled: !_isSaving,
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          ),
        AppButton.tertiary(
          label: widget.submitLabel,
          leadingIcon: Icons.delete_outline,
          color: widget.destructiveSubmit ? colorScheme.error : null,
          isLoading: _isSaving && !widget._requiresFinalConfirmation,
          enabled: !_isSaving && _canSubmit,
          onPressed: _isSaving ? null : _submit,
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
    final String reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      return;
    }

    if (widget._requiresFinalConfirmation) {
      final bool? confirmed = await showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AppConfirmActionDialog(
          title: widget.confirmationTitle!,
          body: widget.confirmationBody!,
          submitLabel:
              widget.confirmationSubmitLabel ?? widget.submitLabel,
          icon: const Icon(Icons.warning_amber_rounded),
          destructive: true,
          submitLeadingIcon: Icons.delete_forever_outlined,
          onConfirm: () => widget.onDelete(reason),
        ),
      );
      if (!mounted) {
        return;
      }
      if (confirmed == true) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onDelete(reason);
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

class LabPanelTestPicker extends StatelessWidget {
  const LabPanelTestPicker({
    required this.tests,
    required this.selectedTests,
    required this.pendingTestId,
    required this.enabled,
    required this.onPendingChanged,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
    super.key,
  });

  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> selectedTests;
  final String? pendingTestId;
  final bool enabled;
  final ValueChanged<String?> onPendingChanged;
  final VoidCallback onAdd;
  final ValueChanged<LabCatalogItem> onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool compact = AppBreakpoints.of(context).isMobile;
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

    final Widget selectField = AppSelectField<String>.searchable(
      value: pendingTestId,
      labelText: l10n.labPanelTestSelectLabel,
      enabled: enabled,
      menuHeight: 360,
      options: options,
      onChanged: onPendingChanged,
    );
    final Widget addButton = AppButton.secondary(
      label: l10n.labPanelAddTestAction,
      leadingIcon: Icons.add,
      enabled: enabled && pendingTestId != null,
      onPressed: onAdd,
    );

    return AppFormSection(
      title: l10n.labPanelTestsLabel,
      children: <Widget>[
        if (compact) ...<Widget>[
          selectField,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: addButton,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: selectField),
              SizedBox(width: theme.spacing.sm),
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: addButton,
              ),
            ],
          ),
        if (selectedTests.isEmpty)
          AppMutedText(l10n.labPanelNoSelectedTests)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: theme.borders.all(),
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
                Divider(height: 1, color: theme.borders.faint),
                for (var index = 0; index < selectedTests.length; index += 1)
                  _SelectedPanelTestRow(
                    item: selectedTests[index],
                    enabled: enabled,
                    onRemove: () => onRemove(selectedTests[index]),
                  ),
              ],
            ),
          ),
        if (errorText != null && errorText!.trim().isNotEmpty)
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
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
                    fontWeight: AppFontWeight.emphasis,
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

/// Searchable multi-select member-test picker for the panel wizard tests step.
///
/// Uses [AppListTable] with shrink-wrap + non-scrolling physics so the parent
/// dialog owns the only scroll region (no nested scroll).
class LabPanelTestSelectionTable extends StatefulWidget {
  const LabPanelTestSelectionTable({
    required this.tests,
    required this.selectedTests,
    required this.enabled,
    required this.onToggle,
    this.errorText,
    super.key,
  });

  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> selectedTests;
  final bool enabled;
  final ValueChanged<LabCatalogItem> onToggle;
  final String? errorText;

  @override
  State<LabPanelTestSelectionTable> createState() =>
      _LabPanelTestSelectionTableState();
}

class _LabPanelTestSelectionTableState
    extends State<LabPanelTestSelectionTable> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _selectedIdentityKeys {
    final Set<String> keys = <String>{};
    for (final LabCatalogItem item in widget.selectedTests) {
      final String apiId = item.apiId.trim();
      final String id = item.id.trim();
      if (apiId.isNotEmpty) {
        keys.add(apiId);
      }
      if (id.isNotEmpty) {
        keys.add(id);
      }
    }
    return keys;
  }

  bool _isSelected(LabCatalogItem item, Set<String> selectedKeys) {
    final String apiId = item.apiId.trim();
    final String id = item.id.trim();
    return (apiId.isNotEmpty && selectedKeys.contains(apiId)) ||
        (id.isNotEmpty && selectedKeys.contains(id));
  }

  /// Selected members first (stable), then remaining catalog tests.
  List<LabCatalogItem> get _orderedTests {
    final Set<String> selectedKeys = _selectedIdentityKeys;
    final List<LabCatalogItem> selected = List<LabCatalogItem>.of(
      widget.selectedTests,
    );
    final List<LabCatalogItem> unselected = <LabCatalogItem>[
      for (final LabCatalogItem test in widget.tests)
        if (!_isSelected(test, selectedKeys)) test,
    ];
    return <LabCatalogItem>[...selected, ...unselected];
  }

  String _selectedSummary(AppLocalizations l10n) {
    if (widget.selectedTests.isEmpty) {
      return l10n.labPanelNoSelectedTests;
    }
    const int previewLimit = 6;
    final List<String> titles = widget.selectedTests
        .map((LabCatalogItem test) => test.displayTitle.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (titles.length <= previewLimit) {
      return titles.join(', ');
    }
    final int remaining = titles.length - previewLimit;
    return '${titles.take(previewLimit).join(', ')} (+$remaining)';
  }

  LocalKey _itemKey(LabCatalogItem item) {
    final String apiId = item.apiId.trim();
    if (apiId.isNotEmpty) {
      return ValueKey<String>(apiId);
    }
    return ValueKey<String>(item.id.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Set<String> selectedKeys = _selectedIdentityKeys;
    final List<LabCatalogItem> ordered = _orderedTests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.labPanelSelectedTestsCountLabel(widget.selectedTests.length),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        AppMutedText(_selectedSummary(l10n)),
        if (widget.errorText != null &&
            widget.errorText!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.sm),
        AppListTable<LabCatalogItem>(
          items: ordered,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          tableHorizontalMargin: 0,
          maxVisibleItems: _maxVisibleLabCatalogDialogItems,
          itemKeyBuilder: _itemKey,
          onRowSelected: widget.enabled ? widget.onToggle : null,
          search: AppListTableSearch<LabCatalogItem>(
            controller: _searchController,
            semanticLabel: l10n.labCatalogSearchLabel,
            hintText: l10n.labCatalogSearchLabel,
            enableDateFilter: false,
            matcher: (LabCatalogItem item, String query) =>
                item.matchesSearch(query),
          ),
          emptyBuilder: (_) => Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
            child: AppMutedText(
              l10n.labPanelTestTableEmptyLabel,
              textAlign: TextAlign.center,
            ),
          ),
          rowColorBuilder: (BuildContext context, LabCatalogItem item) {
            if (!_isSelected(item, selectedKeys)) {
              return null;
            }
            return Theme.of(context).colorScheme.primaryContainer.withValues(
              alpha: 0.35,
            );
          },
          columns: <AppListTableColumn<LabCatalogItem>>[
            AppListTableColumn<LabCatalogItem>(
              id: 'select',
              label: l10n.labPanelTestSelectColumnLabel,
              alwaysVisible: true,
              cellBuilder: (_, LabCatalogItem item) {
                final bool selected = _isSelected(item, selectedKeys);
                return Checkbox(
                  value: selected,
                  onChanged: widget.enabled
                      ? (_) => widget.onToggle(item)
                      : null,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
            AppListTableColumn<LabCatalogItem>(
              id: 'name',
              label: l10n.labTestNameLabel,
              cellBuilder: (_, LabCatalogItem item) => Text(
                item.name ?? item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppListTableColumn<LabCatalogItem>(
              id: 'code',
              label: l10n.labTestCodeLabel,
              cellBuilder: (_, LabCatalogItem item) => Text(
                (item.code ?? '').trim().isEmpty ? '—' : item.code!.trim(),
              ),
            ),
            AppListTableColumn<LabCatalogItem>(
              id: 'category',
              label: l10n.labCategoryLabel,
              cellBuilder: (_, LabCatalogItem item) => Text(
                (item.category ?? '').trim().isEmpty
                    ? '—'
                    : item.category!.trim(),
              ),
            ),
          ],
          mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
            final bool selected = _isSelected(item, selectedKeys);
            return AppListTableMobileItem(
              leading: Checkbox(
                value: selected,
                onChanged: widget.enabled
                    ? (_) => widget.onToggle(item)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              showAvatar: false,
              title: item.name ?? item.displayTitle,
              caption: item.code,
              meta: <AppListTableMobileMeta>[
                if ((item.category ?? '').trim().isNotEmpty)
                  AppListTableMobileMeta(label: item.category!.trim()),
              ],
            );
          },
        ),
      ],
    );
  }
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
    AppButton.close(
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
  final String normalizedId = labNormalizeCatalogToken(id);
  if (normalizedId.isNotEmpty) {
    if (labNormalizeCatalogToken(item.apiId) == normalizedId ||
        labNormalizeCatalogToken(item.id) == normalizedId ||
        labNormalizeCatalogToken(item.displayId) == normalizedId) {
      return true;
    }
  }
  final String normalizedCode = labNormalizeCatalogToken(code);
  return normalizedCode.isNotEmpty &&
      labNormalizeCatalogToken(item.code) == normalizedCode;
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
