import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const double _kOnboardingTwoColumnBreakpoint = 900;

const Set<String> _clinicalPrescriberRoleNames = <String>{
  'DOCTOR',
  'SPECIALIST',
  'ATTENDING_PHYSICIAN',
  'RESIDENT_PHYSICIAN',
  'SURGEON',
  'ANESTHESIOLOGIST',
  'PHYSICIAN_ASSISTANT',
  'EMERGENCY_PHYSICIAN',
  'NURSE_PRACTITIONER',
};

enum StaffNumberEntryMode { generate, manual }

/// Opens the canonical HR staff onboarding dialog (create or edit).
Future<bool?> showHrStaffOnboardingDialog(
  BuildContext context,
  WidgetRef ref, {
  HrStaffProfile? staff,
}) async {
  final bool isEdit = staff != null;
  final AccessRequirement writeGate = isEdit
      ? HrHumanResourcesAtomPermissions.editStaff
      : HrHumanResourcesAtomPermissions.addStaff;
  if (!writeGate.isAllowed(ref.read(appAccessPolicyProvider))) {
    return null;
  }

  final AppLocalizations l10n = context.l10n;
  final String? tenantId = resolveHrAccessTenantId(ref);
  if (tenantId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.hrAccessTenantContextRequiredBody)),
    );
    return null;
  }

  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String? facilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;
  await controller.ensureOnboardingReferenceData(facilityId: facilityId);
  if (!context.mounted) {
    return null;
  }

  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final GlobalKey<HrStaffOnboardingFormState> fieldsKey =
      GlobalKey<HrStaffOnboardingFormState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      isEdit ? l10n.hrEditStaffDialogTitle : l10n.hrAddStaffDialogTitle,
    ),
    icon: const Icon(Icons.badge_outlined),
    submitLabel: isEdit ? l10n.hrSaveStaffAction : l10n.hrCreateStaffAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 980,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrStaffOnboardingForm(
            key: fieldsKey,
            staff: staff,
            referenceData: state?.referenceData ?? const HrReferenceData(),
            tenantId: tenantId,
            facilityId: facilityId,
            serverFailure: failure,
          );
        },
    onSubmit: () {
      fieldsKey.currentState?.prepareForSubmit();
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      payload['tenant_id'] = tenantId;
      if (facilityId != null && facilityId.isNotEmpty) {
        payload['facility_id'] = facilityId;
      }
      if (isEdit) {
        payload['_edit'] = true;
        payload['_staff_profile_id'] = staff.effectiveId;
      }
      return controller.onboardStaff(payload);
    },
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }

  return saved;
}

/// Staff onboarding form fields used by [showHrStaffOnboardingDialog].
class HrStaffOnboardingForm extends ConsumerStatefulWidget {
  const HrStaffOnboardingForm({
    required this.referenceData,
    required this.tenantId,
    this.staff,
    this.facilityId,
    this.serverFailure,
    super.key,
  });

  final HrReferenceData referenceData;
  final HrStaffProfile? staff;
  final String tenantId;
  final String? facilityId;
  final AppFailure? serverFailure;

  @override
  ConsumerState<HrStaffOnboardingForm> createState() =>
      HrStaffOnboardingFormState();
}

class HrStaffOnboardingFormState extends ConsumerState<HrStaffOnboardingForm> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _passwordController;
  late final TextEditingController _staffNumberController;
  late final TextEditingController _compensationRateController;
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  late final TextEditingController _feeController;
  late final TextEditingController _feeCurrencyController;

  StaffNumberEntryMode _staffNumberMode = StaffNumberEntryMode.generate;
  String _payType = 'PER_MONTH';
  String? _position;
  String? _positionSearchText;
  String? _departmentId;
  String? _practitionerType;
  String _compensationCurrency = appDefaultCurrencyCode;
  DateTime? _hireDate;
  DateTime? _compensationEffectiveFrom = DateTime.now();
  bool _showPractitionerType = false;
  bool _showConsultationFee = false;
  final Set<String> _selectedRoleIds = <String>{};

  bool get isEdit => widget.staff != null;

  @visibleForTesting
  StaffNumberEntryMode get staffNumberMode => _staffNumberMode;

  @visibleForTesting
  DateTime? get hireDate => _hireDate;

  @visibleForTesting
  Set<String> get selectedRoleIds => Set<String>.unmodifiable(_selectedRoleIds);

  @visibleForTesting
  String resolvedPositionForTest() => _resolvedPosition();

  @visibleForTesting
  void setPositionDraftForTest({String? position, String? searchText}) {
    _position = position;
    _positionSearchText = searchText;
  }

  @visibleForTesting
  bool get showPractitionerTypeForTest => _showPractitionerType;

  @visibleForTesting
  int positionOptionCountForTest() => _positionOptions(context.l10n).length;

  @visibleForTesting
  int departmentOptionCountForTest() =>
      _selectOptions(_referenceData.departments, context.l10n).length;

  @visibleForTesting
  void setSelectedRolesForTest(Set<String> roleIds) {
    _selectedRoleIds
      ..clear()
      ..addAll(roleIds);
    _recomputeClinicalSections();
  }

  void prepareForSubmit() {
    AppPhoneField.commitPhone(_phoneFieldKey);
  }

  HrReferenceData get _referenceData {
    final HrWorkspaceState? workspaceState = readHrWorkspaceState(ref);
    final HrReferenceData workspaceRefs =
        workspaceState?.referenceData ?? const HrReferenceData();
    if (hasHrOnboardingReferenceData(workspaceRefs)) {
      return workspaceRefs;
    }
    return widget.referenceData;
  }

  @override
  void initState() {
    super.initState();
    final HrStaffProfile? staff = widget.staff;
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _passwordController = TextEditingController();
    _staffNumberController = TextEditingController(text: staff?.staffNumber);
    _compensationRateController = TextEditingController();
    _feeController = TextEditingController(
      text: staff?.consultationFee?.toString(),
    );
    _feeCurrencyController = TextEditingController(
      text: staff?.consultationCurrency ?? appDefaultCurrencyCode,
    );
    _position = (staff?.position ?? '').trim().isEmpty ? null : staff!.position;
    _departmentId = staff?.departmentDisplayId ?? staff?.departmentId;
    _practitionerType = staff?.practitionerType;
    _hireDate = staff?.hireDate ?? DateTime.now();
    if (staff != null && staff.compensations.isNotEmpty) {
      final HrStaffCompensation compensation = staff.compensations.first;
      _compensationRateController.text = compensation.rate?.toString() ?? '';
      _compensationCurrency = compensation.currency ?? appDefaultCurrencyCode;
      _payType = hrCompensationPayTypeFromApi(compensation.payType);
      _compensationEffectiveFrom = compensation.effectiveFrom ?? DateTime.now();
    }
    if (staff?.staffNumber != null && staff!.staffNumber!.isNotEmpty) {
      _staffNumberMode = StaffNumberEntryMode.manual;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _recomputeClinicalSections();
      unawaited(
        ref
            .read(hrWorkspaceControllerProvider.notifier)
            .ensureOnboardingReferenceData(facilityId: widget.facilityId),
      );
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _staffNumberController.dispose();
    _compensationRateController.dispose();
    _feeController.dispose();
    _feeCurrencyController.dispose();
    super.dispose();
  }

  String _resolvedPosition() {
    final String selected = (_position ?? '').trim();
    if (selected.isNotEmpty) {
      return selected;
    }
    return (_positionSearchText ?? '').trim();
  }

  bool _isClinicalPrescriberRoleSelected() {
    for (final String roleId in _selectedRoleIds) {
      final HrOption? role = _roleOptionById(roleId);
      if (role == null) {
        continue;
      }
      final String roleName =
          (role.extra['name'] ?? role.label.split(' | ').first)
              .toString()
              .trim()
              .toUpperCase();
      if (_clinicalPrescriberRoleNames.contains(roleName) ||
          roleName.contains('DOCTOR')) {
        return true;
      }
    }
    return false;
  }

  void _recomputeClinicalSections() {
    final AppLocalizations l10n = context.l10n;
    final bool showPractitioner = isEdit || _isClinicalPrescriberRoleSelected();
    final String? practitioner = _practitionerType?.toUpperCase();
    final bool showFee =
        showPractitioner &&
        practitioner != null &&
        l10n.isConsultationFeePractitionerType(practitioner);
    setState(() {
      _showPractitionerType = showPractitioner;
      _showConsultationFee = showFee;
      if (!showPractitioner) {
        _practitionerType = null;
      }
      if (!showFee) {
        _feeController.clear();
        _feeCurrencyController.text = appDefaultCurrencyCode;
      }
    });
  }

  HrOption? _roleOptionById(String roleId) {
    for (final HrOption option in _referenceData.roles) {
      if (option.value == roleId) {
        return option;
      }
    }
    return null;
  }

  List<AppRoleAssignmentOption> _roleAssignmentOptions() {
    return <AppRoleAssignmentOption>[
      for (final HrOption role in _referenceData.roles)
        AppRoleAssignmentOption(
          id: role.value,
          label: context.l10n.hrLocalizedOptionLabel(role),
          permissionCount: (role.extra['permission_count'] as int?) ?? 0,
          isSystemCritical: role.extra['is_system_critical'] == true,
        ),
    ];
  }

  Future<Set<String>> _loadRolePermissions(String roleId) async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<AppPage<HrOption>> result = await controller
        .listRolePermissionOptions(roleId);
    return result.when(
      success: (AppPage<HrOption> page) =>
          page.items.map((HrOption permission) => permission.label).toSet(),
      failure: (_) => <String>{},
    );
  }

  List<AppSelectOption<String>> _positionOptions(AppLocalizations l10n) {
    final Map<String, String> byLabel = <String, String>{};
    for (final HrOption option in _referenceData.staffPositions) {
      final String label = option.label.trim().isEmpty
          ? option.value.trim()
          : l10n.hrLocalizedOptionLabel(option);
      if (label.isNotEmpty) {
        byLabel[label] = label;
      }
    }
    final String? current = _position;
    if (current != null && current.isNotEmpty) {
      byLabel.putIfAbsent(
        l10n.hrReferenceStaffPositionLabel(current, fallback: current),
        () => current,
      );
    }
    return <AppSelectOption<String>>[
      for (final String label in byLabel.keys)
        AppSelectOption<String>(value: label, label: label),
    ];
  }

  List<AppSelectOption<String>> _selectOptions(
    List<HrOption> options,
    AppLocalizations l10n,
  ) {
    return hrLocalizedSelectOptions(l10n, options);
  }

  Map<String, Object?> toPayload() {
    final String position = _resolvedPosition();
    final List<Map<String, Object?>> compensations = <Map<String, Object?>>[];
    final num? rate = num.tryParse(_compensationRateController.text.trim());
    if (rate != null && rate > 0) {
      compensations.add(<String, Object?>{
        'pay_type': _payType,
        'rate': rate,
        'currency': _compensationCurrency.trim().toUpperCase(),
        'effective_from': _datePayload(_compensationEffectiveFrom),
      });
    }

    final bool useGeneratedStaffNumber =
        !isEdit && _staffNumberMode == StaffNumberEntryMode.generate;
    final String password = _passwordController.text.trim();

    return <String, Object?>{
      if (!isEdit) ...<String, Object?>{
        'email': _emailController.text.trim(),
        if (password.length >= 8) 'password': password,
        'phone': _phoneController.text.trim(),
        'position_title': position.isNotEmpty ? position : 'Staff',
        'status': 'ACTIVE',
        '_first_name': _firstNameController.text.trim(),
        '_last_name': _lastNameController.text.trim(),
      },
      '_role_ids': _selectedRoleIds.toList(growable: false),
      if (useGeneratedStaffNumber)
        'generate_staff_number': true
      else
        'staff_number': _staffNumberController.text.trim(),
      'position': position,
      'department_id': _departmentId,
      'practitioner_type': _practitionerType,
      'hire_date': _datePayload(_hireDate),
      if (_showConsultationFee) ...<String, Object?>{
        'consultation_fee': num.tryParse(_feeController.text.trim()),
        'consultation_currency': _feeCurrencyController.text
            .trim()
            .toUpperCase(),
      },
      if (compensations.isNotEmpty) 'compensations': compensations,
    };
  }

  Widget _emailField(AppLocalizations l10n) {
    return AppEmailField(
      controller: _emailController,
      labelText: l10n.hrStaffEmailLabel,
      isRequired: true,
      invalidEmailMessage: l10n.authEmailInvalidMessage,
      requiredMessage: l10n.hrFieldRequiredLabel(l10n.hrStaffEmailLabel),
      errorText: widget.serverFailure?.messageForField('email'),
    );
  }

  Widget _phoneField(AppLocalizations l10n) {
    return AppPhoneField(
      key: _phoneFieldKey,
      controller: _phoneController,
      labelText: l10n.hrStaffPhoneLabel,
      countryLabelText: l10n.appPhoneCountryLabel,
      countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
      countryNoResultsText: l10n.appPhoneCountryNoResults,
      numberLabelText: l10n.appPhoneNumberLabel,
      numberHintText: l10n.appPhoneNumberHint,
      invalidPhoneMessage: l10n.appPhoneInvalidMessage,
      isRequired: true,
      requiredMessage: l10n.hrFieldRequiredLabel(l10n.hrStaffPhoneLabel),
      errorText: widget.serverFailure?.messageForField('phone'),
    );
  }

  Widget _passwordField(AppLocalizations l10n) {
    return AppTextField(
      controller: _passwordController,
      labelText: l10n.hrStaffTemporaryPasswordLabel,
      obscureText: true,
      enableObscureTextToggle: true,
      showObscuredTextLabel: l10n.authShowPasswordLabel,
      hideObscuredTextLabel: l10n.authHidePasswordLabel,
      helperText: l10n.hrStaffPasswordOptionalHint,
      validator: (String? value) {
        final String trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty || trimmed.length >= 8) {
          return null;
        }
        return l10n.authPasswordMinLengthMessage;
      },
    );
  }

  Widget _addressField(AppLocalizations l10n) {
    return AppTextField(
      controller: _addressController,
      labelText: l10n.hrStaffOnboardingAddressLabel,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _staffNumberModePicker(AppLocalizations l10n, {required bool wide}) {
    final ThemeData theme = Theme.of(context);
    final Widget generateTile = RadioListTile<StaffNumberEntryMode>(
      value: StaffNumberEntryMode.generate,
      title: Text(l10n.hrStaffNumberAutoGenerateLabel),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
    final Widget manualTile = RadioListTile<StaffNumberEntryMode>(
      value: StaffNumberEntryMode.manual,
      title: Text(l10n.hrStaffNumberManualEntryLabel),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );

    return RadioGroup<StaffNumberEntryMode>(
      groupValue: _staffNumberMode,
      onChanged: (StaffNumberEntryMode? value) {
        if (value == null) {
          return;
        }
        setState(() => _staffNumberMode = value);
      },
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: generateTile),
                SizedBox(width: theme.spacing.md),
                Expanded(child: manualTile),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[generateTile, manualTile],
            ),
    );
  }

  Widget _responsivePair({required Widget left, required Widget right}) {
    return AppResponsiveFieldRow.two(
      left: left,
      right: right,
      breakpoint: _kOnboardingTwoColumnBreakpoint,
      gap: AppResponsiveFieldRowGap.form,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hrWorkspaceControllerProvider);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide =
            constraints.hasBoundedWidth &&
            constraints.maxWidth >= _kOnboardingTwoColumnBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!isEdit) ...<Widget>[
              AppFormSection(
                title: l10n.hrStaffOnboardingPersonSectionTitle,
                children: <Widget>[
                  if (wide)
                    _responsivePair(
                      left: AppTextField(
                        controller: _firstNameController,
                        labelText: l10n.hrStaffFirstNameLabel,
                        isRequired: true,
                        validator: AppValidators.requiredText(
                          l10n.hrFieldRequiredLabel(l10n.hrStaffFirstNameLabel),
                        ),
                      ),
                      right: AppTextField(
                        controller: _lastNameController,
                        labelText: l10n.hrStaffLastNameLabel,
                        isRequired: true,
                        validator: AppValidators.requiredText(
                          l10n.hrFieldRequiredLabel(l10n.hrStaffLastNameLabel),
                        ),
                      ),
                    )
                  else ...<Widget>[
                    AppTextField(
                      controller: _firstNameController,
                      labelText: l10n.hrStaffFirstNameLabel,
                      isRequired: true,
                      validator: AppValidators.requiredText(
                        l10n.hrFieldRequiredLabel(l10n.hrStaffFirstNameLabel),
                      ),
                    ),
                    AppTextField(
                      controller: _lastNameController,
                      labelText: l10n.hrStaffLastNameLabel,
                      isRequired: true,
                      validator: AppValidators.requiredText(
                        l10n.hrFieldRequiredLabel(l10n.hrStaffLastNameLabel),
                      ),
                    ),
                  ],
                  if (wide)
                    _responsivePair(
                      left: _emailField(l10n),
                      right: _phoneField(l10n),
                    )
                  else ...<Widget>[_emailField(l10n), _phoneField(l10n)],
                  _addressField(l10n),
                  _passwordField(l10n),
                ],
              ),
              SizedBox(height: theme.spacing.lg),
            ],
            AppFormSection(
              title: l10n.hrStaffOnboardingEmploymentSectionTitle,
              children: <Widget>[
                _staffNumberModePicker(l10n, wide: wide),
                if (_staffNumberMode == StaffNumberEntryMode.manual)
                  AppTextField(
                    controller: _staffNumberController,
                    labelText: l10n.hrStaffNumberLabel,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.hrFieldRequiredLabel(l10n.hrStaffNumberLabel),
                    ),
                  ),
                if (wide)
                  _responsivePair(
                    left: AppSelectField<String>.searchable(
                      value: _position,
                      labelText: l10n.hrPositionLabel,
                      options: _positionOptions(l10n),
                      onChanged: (String? value) =>
                          setState(() => _position = value),
                      onSearchTextChanged: (String value) =>
                          _positionSearchText = value.trim(),
                    ),
                    right: AppSelectField<String>.searchable(
                      value: _departmentId,
                      labelText: l10n.hrDepartmentLabel,
                      options: _selectOptions(_referenceData.departments, l10n),
                      onChanged: (String? value) =>
                          setState(() => _departmentId = value),
                    ),
                  )
                else ...<Widget>[
                  AppSelectField<String>.searchable(
                    value: _position,
                    labelText: l10n.hrPositionLabel,
                    options: _positionOptions(l10n),
                    onChanged: (String? value) =>
                        setState(() => _position = value),
                    onSearchTextChanged: (String value) =>
                        _positionSearchText = value.trim(),
                  ),
                  AppSelectField<String>.searchable(
                    value: _departmentId,
                    labelText: l10n.hrDepartmentLabel,
                    options: _selectOptions(_referenceData.departments, l10n),
                    onChanged: (String? value) =>
                        setState(() => _departmentId = value),
                  ),
                ],
                AppDateField(
                  value: _hireDate,
                  labelText: l10n.hrHireDateLabel,
                  firstDate: DateTime(1950),
                  lastDate: DateTime(2100),
                  currentDate: DateTime.now(),
                  pickerButtonLabel: l10n.hrPickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  onChanged: (DateTime? value) =>
                      setState(() => _hireDate = value),
                ),
              ],
            ),
            if (!isEdit) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              AppFormSection(
                title: l10n.hrStaffOnboardingRolesSectionTitle,
                children: <Widget>[
                  AppRoleAssignmentPicker(
                    roles: _roleAssignmentOptions(),
                    selectedRoleIds: _selectedRoleIds,
                    loadRolePermissions: _loadRolePermissions,
                    onSelectionChanged: (Set<String> value) {
                      setState(() {
                        _selectedRoleIds
                          ..clear()
                          ..addAll(value);
                      });
                      _recomputeClinicalSections();
                    },
                  ),
                ],
              ),
            ],
            if (_showPractitionerType) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              AppFormSection(
                title: l10n.hrPractitionerTypeLabel,
                children: <Widget>[
                  AppSelectField<String>.searchable(
                    value: _practitionerType,
                    labelText: l10n.hrPractitionerTypeLabel,
                    options: _selectOptions(
                      _referenceData.practitionerTypes,
                      l10n,
                    ),
                    onChanged: (String? value) {
                      setState(() => _practitionerType = value);
                      _recomputeClinicalSections();
                    },
                  ),
                ],
              ),
            ],
            SizedBox(height: theme.spacing.lg),
            AppFormSection(
              title: l10n.hrStaffOnboardingCompensationSectionTitle,
              description: isEdit
                  ? l10n.hrStaffOnboardingCompensationEditHint
                  : l10n.hrStaffOnboardingCompensationCreateHint,
              children: <Widget>[
                AppSelectField<String>(
                  value: _payType,
                  labelText: l10n.hrStaffOnboardingPayTypeLabel,
                  options: hrCompensationPayTypeSelectOptions(l10n),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _payType = value);
                  },
                ),
                AppCurrencyAmountField(
                  amountController: _compensationRateController,
                  currency: _compensationCurrency,
                  onCurrencyChanged: (String? value) {
                    setState(
                      () => _compensationCurrency =
                          value ?? appDefaultCurrencyCode,
                    );
                  },
                  amountLabelText: hrCompensationRateLabel(l10n, _payType),
                  currencyLabelText: l10n.hrCompensationCurrencyLabel,
                  currencySearchLabelText: l10n.appPhoneCountrySearchLabel,
                ),
                AppDateField(
                  value: _compensationEffectiveFrom,
                  labelText: l10n.hrEffectiveFromLabel,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  currentDate: DateTime.now(),
                  pickerButtonLabel: l10n.hrPickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  onChanged: (DateTime? value) =>
                      setState(() => _compensationEffectiveFrom = value),
                ),
              ],
            ),
            if (_showConsultationFee) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              AppFormSection(
                title: l10n.hrStaffOnboardingConsultationSectionTitle,
                children: <Widget>[
                  if (wide)
                    _responsivePair(
                      left: AppTextField(
                        controller: _feeController,
                        labelText: l10n.hrConsultationFeeLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                      right: AppTextField(
                        controller: _feeCurrencyController,
                        labelText: l10n.hrConsultationCurrencyLabel,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    )
                  else ...<Widget>[
                    AppTextField(
                      controller: _feeController,
                      labelText: l10n.hrConsultationFeeLabel,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    AppTextField(
                      controller: _feeCurrencyController,
                      labelText: l10n.hrConsultationCurrencyLabel,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String();
}
