import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum _StaffIdentityMode { createNew, linkExisting }

enum _CompensationPayType { monthly, daily, hourly, perVisit }

const Set<String> _clinicalRoleNames = <String>{
  'DOCTOR',
  'NURSE',
  'SPECIALIST',
};

/// Opens the canonical HR staff onboarding dialog (create or edit).
Future<void> showHrStaffOnboardingDialog(
  BuildContext context,
  WidgetRef ref, {
  HrStaffProfile? staff,
}) async {
  if (!canWriteHrAccess(ref)) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final String? tenantId = resolveHrAccessTenantId(ref);
  if (tenantId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.hrAccessTenantContextRequiredBody)),
    );
    return;
  }

  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_HrStaffOnboardingFieldsState> fieldsKey =
      GlobalKey<_HrStaffOnboardingFieldsState>();
  final bool isEdit = staff != null;
  final String? facilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;

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
    initialMaximized: true,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _HrStaffOnboardingFields(
        key: fieldsKey,
        staff: staff,
        referenceData: state?.referenceData ?? const HrReferenceData(),
        tenantId: tenantId,
        facilityId: facilityId,
      );
    },
    onSubmit: () {
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
}

class _HrStaffOnboardingFields extends ConsumerStatefulWidget {
  const _HrStaffOnboardingFields({
    required this.referenceData,
    required this.tenantId,
    this.staff,
    this.facilityId,
    super.key,
  });

  final HrReferenceData referenceData;
  final HrStaffProfile? staff;
  final String tenantId;
  final String? facilityId;

  @override
  ConsumerState<_HrStaffOnboardingFields> createState() =>
      _HrStaffOnboardingFieldsState();
}

class _HrStaffOnboardingFieldsState
    extends ConsumerState<_HrStaffOnboardingFields> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _passwordController;
  late final TextEditingController _staffNumberController;
  late final TextEditingController _newPositionController;
  late final TextEditingController _compensationRateController;
  late final TextEditingController _compensationCurrencyController;
  late final TextEditingController _feeController;
  late final TextEditingController _feeCurrencyController;

  _StaffIdentityMode _identityMode = _StaffIdentityMode.createNew;
  _CompensationPayType _payType = _CompensationPayType.monthly;
  String? _linkedUserId;
  String? _position;
  String? _departmentId;
  String? _practitionerType;
  DateTime? _hireDate;
  DateTime? _compensationEffectiveFrom = DateTime.now();
  bool _isAddingPosition = false;
  bool _showCompensation = false;
  bool _showConsultationFee = false;
  final Set<String> _selectedRoleIds = <String>{};
  final Set<String> _previewPermissions = <String>{};
  bool _loadingPermissions = false;

  bool get _isEdit => widget.staff != null;

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
    _newPositionController = TextEditingController();
    _compensationRateController = TextEditingController();
    _compensationCurrencyController = TextEditingController(
      text: staff?.compensations.firstOrNull?.currency ??
          staff?.consultationCurrency ??
          'USD',
    );
    _feeController = TextEditingController(
      text: staff?.consultationFee?.toString(),
    );
    _feeCurrencyController = TextEditingController(
      text: staff?.consultationCurrency ?? 'USD',
    );
    _position = (staff?.position ?? '').trim().isEmpty ? null : staff!.position;
    _departmentId = staff?.departmentDisplayId ?? staff?.departmentId;
    _practitionerType = staff?.practitionerType;
    _hireDate = staff?.hireDate;
    if (staff != null && staff.compensations.isNotEmpty) {
      final HrStaffCompensation compensation = staff.compensations.first;
      _compensationRateController.text = compensation.rate?.toString() ?? '';
      _payType = _payTypeFromApi(compensation.payType);
      _compensationEffectiveFrom = compensation.effectiveFrom ?? DateTime.now();
      _showCompensation = compensation.rate != null;
    }
    _recomputeClinicalSections();
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
    _newPositionController.dispose();
    _compensationRateController.dispose();
    _compensationCurrencyController.dispose();
    _feeController.dispose();
    _feeCurrencyController.dispose();
    super.dispose();
  }

  _CompensationPayType _payTypeFromApi(String? value) {
    return switch ((value ?? '').toUpperCase()) {
      'PER_HOUR' => _CompensationPayType.hourly,
      'PER_DAY' => _CompensationPayType.daily,
      'PER_PROCEDURE' => _CompensationPayType.perVisit,
      _ => _CompensationPayType.monthly,
    };
  }

  String _payTypeApiValue(_CompensationPayType type) {
    return switch (type) {
      _CompensationPayType.hourly => 'PER_HOUR',
      _CompensationPayType.daily => 'PER_DAY',
      _CompensationPayType.perVisit => 'PER_PROCEDURE',
      _CompensationPayType.monthly => 'PER_MONTH',
    };
  }

  void _recomputeClinicalSections() {
    final bool clinical = _isClinicalBillingProvider();
    setState(() {
      _showConsultationFee = clinical;
      if (!clinical) {
        _feeController.clear();
        _feeCurrencyController.text = 'USD';
      }
    });
  }

  bool _isClinicalBillingProvider() {
    final String? practitioner = _practitionerType?.toUpperCase();
    if (practitioner == 'MO' || practitioner == 'SPECIALIST') {
      return true;
    }
    for (final String roleId in _selectedRoleIds) {
      HrOption? role;
      for (final HrOption option in widget.referenceData.roles) {
        if (option.value == roleId) {
          role = option;
          break;
        }
      }
      if (role == null) {
        continue;
      }
      final String roleName =
          (role.extra['name'] ?? role.label.split(' | ').first)
              .toString()
              .trim()
              .toUpperCase();
      if (_clinicalRoleNames.contains(roleName) ||
          roleName.contains('DOCTOR')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _refreshPermissionPreview() async {
    if (_selectedRoleIds.isEmpty) {
      setState(() {
        _previewPermissions.clear();
        _loadingPermissions = false;
      });
      return;
    }
    setState(() => _loadingPermissions = true);
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Set<String> permissions = <String>{};
    for (final String roleId in _selectedRoleIds) {
      final Result<AppPage<HrOption>> result = await controller
          .listRolePermissionOptions(roleId);
      result.when(
        success: (AppPage<HrOption> page) {
          for (final HrOption permission in page.items) {
            permissions.add(permission.label);
          }
        },
        failure: (_) {},
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _previewPermissions
        ..clear()
        ..addAll(permissions);
      _loadingPermissions = false;
    });
  }

  List<AppSelectOption<String>> _linkableUserOptions() {
    return <AppSelectOption<String>>[
      for (final HrOption user in widget.referenceData.users)
        if (user.extra['has_staff_profile'] != true)
          AppSelectOption<String>(
            value: user.value,
            label: _formatUserOptionLabel(user),
          ),
    ];
  }

  String _formatUserOptionLabel(HrOption user) {
    final String email = user.extra['email']?.toString() ?? '';
    final String roleHint = user.extra['role_hint']?.toString() ?? '';
    final List<String> parts = user.label.split(' · ');
    final String name = parts.isNotEmpty ? parts.first.trim() : '';
    final StringBuffer buffer = StringBuffer();
    if (name.isNotEmpty) {
      buffer.write(name);
    }
    if (email.isNotEmpty && email != name) {
      if (buffer.isNotEmpty) {
        buffer.write(' · ');
      }
      buffer.write(email);
    }
    if (roleHint.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write(' · ');
      }
      buffer.write(roleHint);
    }
    return buffer.isEmpty ? user.label : buffer.toString();
  }

  List<AppSelectOption<String>> _positionOptions() {
    final Map<String, String> byLabel = <String, String>{};
    for (final HrOption option in widget.referenceData.staffPositions) {
      final String label = option.label.trim().isEmpty
          ? option.value.trim()
          : option.label.trim();
      if (label.isNotEmpty) {
        byLabel[label] = label;
      }
    }
    final String? current = _position;
    if (current != null && current.isNotEmpty) {
      byLabel.putIfAbsent(current, () => current);
    }
    return <AppSelectOption<String>>[
      for (final String label in byLabel.keys)
        AppSelectOption<String>(value: label, label: label),
    ];
  }

  List<AppSelectOption<String>> _selectOptions(List<HrOption> options) {
    return <AppSelectOption<String>>[
      for (final HrOption option in options)
        AppSelectOption<String>(value: option.value, label: option.label),
    ];
  }

  List<AppSelectOption<String>> _payTypeOptions(AppLocalizations l10n) {
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: _CompensationPayType.monthly.name,
        label: l10n.hrCompensationMonthlyRateLabel,
      ),
      AppSelectOption<String>(
        value: _CompensationPayType.daily.name,
        label: l10n.hrStaffOnboardingDailyRateLabel,
      ),
      AppSelectOption<String>(
        value: _CompensationPayType.hourly.name,
        label: l10n.hrCompensationHourlyRateLabel,
      ),
      AppSelectOption<String>(
        value: _CompensationPayType.perVisit.name,
        label: l10n.hrCompensationProcedureRateLabel,
      ),
    ];
  }

  Map<String, Object?> toPayload() {
    final String position = _isAddingPosition
        ? _newPositionController.text.trim()
        : (_position ?? '').trim();
    final List<Map<String, Object?>> compensations = <Map<String, Object?>>[];
    if (_showCompensation) {
      final num? rate = num.tryParse(_compensationRateController.text.trim());
      if (rate != null) {
        compensations.add(<String, Object?>{
          'pay_type': _payTypeApiValue(_payType),
          'rate': rate,
          'currency': _compensationCurrencyController.text
              .trim()
              .toUpperCase(),
          'effective_from': _datePayload(_compensationEffectiveFrom),
        });
      }
    }

    return <String, Object?>{
      if (!_isEdit) '_link_existing': _identityMode == _StaffIdentityMode.linkExisting,
      if (!_isEdit && _identityMode == _StaffIdentityMode.linkExisting)
        'user_id': _linkedUserId,
      if (!_isEdit && _identityMode == _StaffIdentityMode.createNew) ...<String, Object?>{
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'phone': _phoneController.text.trim(),
        'position_title': position.isNotEmpty ? position : 'Staff',
        'status': 'ACTIVE',
        '_first_name': _firstNameController.text.trim(),
        '_last_name': _lastNameController.text.trim(),
      },
      '_role_ids': _selectedRoleIds.toList(growable: false),
      'staff_number': _staffNumberController.text.trim(),
      'position': position,
      'department_id': _departmentId,
      'practitioner_type': _practitionerType,
      'hire_date': _datePayload(_hireDate),
      if (_showConsultationFee) ...<String, Object?>{
        'consultation_fee': num.tryParse(_feeController.text.trim()),
        'consultation_currency': _feeCurrencyController.text.trim().toUpperCase(),
      },
      if (compensations.isNotEmpty) 'compensations': compensations,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_isEdit) ...<Widget>[
          Text(
            l10n.hrStaffOnboardingPersonSectionTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          SegmentedButton<_StaffIdentityMode>(
            segments: <ButtonSegment<_StaffIdentityMode>>[
              ButtonSegment<_StaffIdentityMode>(
                value: _StaffIdentityMode.createNew,
                label: Text(l10n.hrStaffOnboardingCreateNewUserLabel),
                icon: const Icon(Icons.person_add_outlined),
              ),
              ButtonSegment<_StaffIdentityMode>(
                value: _StaffIdentityMode.linkExisting,
                label: Text(l10n.hrStaffOnboardingLinkExistingUserLabel),
                icon: const Icon(Icons.link_outlined),
              ),
            ],
            selected: <_StaffIdentityMode>{_identityMode},
            onSelectionChanged: (Set<_StaffIdentityMode> value) {
              setState(() => _identityMode = value.first);
            },
          ),
          SizedBox(height: theme.spacing.md),
          if (_identityMode == _StaffIdentityMode.createNew)
            AppFormSection(
              children: <Widget>[
                AppTextField(
                  controller: _firstNameController,
                  labelText: l10n.profileEditFirstNameLabel,
                  isRequired: true,
                  validator: AppValidators.requiredText(
                    l10n.hrFieldRequiredLabel(l10n.profileEditFirstNameLabel),
                  ),
                ),
                AppTextField(
                  controller: _lastNameController,
                  labelText: l10n.profileEditLastNameLabel,
                  isRequired: true,
                  validator: AppValidators.requiredText(
                    l10n.hrFieldRequiredLabel(l10n.profileEditLastNameLabel),
                  ),
                ),
                AppTextField(
                  controller: _emailController,
                  labelText: l10n.hrEmailLabel,
                  isRequired: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.requiredText(
                    l10n.hrFieldRequiredLabel(l10n.hrEmailLabel),
                  ),
                ),
                AppTextField(
                  controller: _phoneController,
                  labelText: l10n.profilePhoneLabel,
                  keyboardType: TextInputType.phone,
                ),
                AppTextField(
                  controller: _addressController,
                  labelText: l10n.hrStaffOnboardingAddressLabel,
                  maxLines: 2,
                ),
                AppTextField(
                  controller: _passwordController,
                  labelText: l10n.hrPasswordLabel,
                  isRequired: true,
                  obscureText: true,
                  validator: AppValidators.requiredText(
                    l10n.hrFieldRequiredLabel(l10n.hrPasswordLabel),
                  ),
                ),
              ],
            )
          else
            AppSelectField<String>.searchable(
              value: _linkedUserId,
              labelText: l10n.hrSelectUserLabel,
              isRequired: true,
              options: _linkableUserOptions(),
              validator: AppValidators.requiredValue(
                l10n.hrFieldRequiredLabel(l10n.hrSelectUserLabel),
              ),
              onChanged: (String? value) =>
                  setState(() => _linkedUserId = value),
            ),
          SizedBox(height: theme.spacing.lg),
        ],
        Text(
          l10n.hrStaffOnboardingEmploymentSectionTitle,
          style: theme.textTheme.titleSmall,
        ),
        SizedBox(height: theme.spacing.sm),
        AppFormSection(
          children: <Widget>[
            AppTextField(
              controller: _staffNumberController,
              labelText: l10n.hrStaffNumberLabel,
            ),
            if (_isAddingPosition)
              AppTextField(
                controller: _newPositionController,
                labelText: l10n.hrNewPositionLabel,
                isRequired: true,
                validator: AppValidators.requiredText(
                  l10n.hrFieldRequiredLabel(l10n.hrNewPositionLabel),
                ),
              )
            else
              AppSelectField<String>.searchable(
                value: _position,
                labelText: l10n.hrPositionLabel,
                options: _positionOptions(),
                onChanged: (String? value) => setState(() => _position = value),
              ),
            AppCheckboxField(
              title: l10n.hrAddNewPositionLabel,
              value: _isAddingPosition,
              onChanged: (bool value) => setState(() => _isAddingPosition = value),
            ),
            AppSelectField<String>.searchable(
              value: _departmentId,
              labelText: l10n.hrDepartmentLabel,
              options: _selectOptions(widget.referenceData.departments),
              onChanged: (String? value) =>
                  setState(() => _departmentId = value),
            ),
            AppSelectField<String>(
              value: _practitionerType,
              labelText: l10n.hrPractitionerTypeLabel,
              options: _selectOptions(widget.referenceData.practitionerTypes),
              onChanged: (String? value) {
                setState(() => _practitionerType = value);
                _recomputeClinicalSections();
              },
            ),
            AppDateField(
              value: _hireDate,
              labelText: l10n.hrHireDateLabel,
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.hrPickDateAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              onChanged: (DateTime? value) => setState(() => _hireDate = value),
            ),
          ],
        ),
        if (!_isEdit) ...<Widget>[
          SizedBox(height: theme.spacing.lg),
          Text(
            l10n.hrRolesSectionTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          if (_selectedRoleIds.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_outlined,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      l10n.hrStaffOnboardingNoRolesWarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              AppButton.secondary(
                label: l10n.hrAccessSelectAllRolesAction,
                onPressed: () {
                  setState(() {
                    _selectedRoleIds
                      ..clear()
                      ..addAll(
                        widget.referenceData.roles
                            .map((HrOption role) => role.value),
                      );
                  });
                  _recomputeClinicalSections();
                  unawaited(_refreshPermissionPreview());
                },
              ),
              AppButton.secondary(
                label: l10n.hrAccessClearRolesAction,
                onPressed: () {
                  setState(_selectedRoleIds.clear);
                  _recomputeClinicalSections();
                  unawaited(_refreshPermissionPreview());
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          for (final HrOption role in widget.referenceData.roles)
            AppCheckboxField(
              title: role.label,
              value: _selectedRoleIds.contains(role.value),
              onChanged: (bool checked) {
                setState(() {
                  if (checked) {
                    _selectedRoleIds.add(role.value);
                  } else {
                    _selectedRoleIds.remove(role.value);
                  }
                });
                _recomputeClinicalSections();
                unawaited(_refreshPermissionPreview());
              },
            ),
          SizedBox(height: theme.spacing.sm),
          Text(
            l10n.hrEffectivePermissionsTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.xs),
          if (_loadingPermissions)
            const LinearProgressIndicator(minHeight: 2)
          else if (_previewPermissions.isEmpty)
            Text(
              l10n.hrStaffOnboardingPermissionsPreviewEmpty,
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _previewPermissions
                  .take(32)
                  .map((String permission) => Chip(label: Text(permission)))
                  .toList(growable: false),
            ),
        ],
        SizedBox(height: theme.spacing.lg),
        Text(
          l10n.hrStaffOnboardingCompensationSectionTitle,
          style: theme.textTheme.titleSmall,
        ),
        SizedBox(height: theme.spacing.sm),
        AppFormSection(
          children: <Widget>[
            AppCheckboxField(
              title: l10n.hrCompensationSectionTitle,
              value: _showCompensation,
              onChanged: (bool value) => setState(() => _showCompensation = value),
            ),
            if (_showCompensation) ...<Widget>[
              AppSelectField<String>(
                value: _payType.name,
                labelText: l10n.hrStaffOnboardingPayTypeLabel,
                options: _payTypeOptions(l10n),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(
                    () => _payType = _CompensationPayType.values.byName(value),
                  );
                },
              ),
              AppTextField(
                controller: _compensationRateController,
                labelText: switch (_payType) {
                  _CompensationPayType.monthly =>
                    l10n.hrCompensationMonthlyRateLabel,
                  _CompensationPayType.daily =>
                    l10n.hrStaffOnboardingDailyRateLabel,
                  _CompensationPayType.hourly =>
                    l10n.hrCompensationHourlyRateLabel,
                  _CompensationPayType.perVisit =>
                    l10n.hrCompensationProcedureRateLabel,
                },
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              AppTextField(
                controller: _compensationCurrencyController,
                labelText: l10n.hrConsultationCurrencyLabel,
                textCapitalization: TextCapitalization.characters,
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
          ],
        ),
        if (_showConsultationFee) ...<Widget>[
          SizedBox(height: theme.spacing.lg),
          Text(
            l10n.hrStaffOnboardingConsultationSectionTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          AppFormSection(
            children: <Widget>[
              AppTextField(
                controller: _feeController,
                labelText: l10n.hrConsultationFeeLabel,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          ),
        ],
      ],
    );
  }
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String();
}
