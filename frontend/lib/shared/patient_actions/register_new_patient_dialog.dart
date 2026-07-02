import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_gender_field.dart';
import 'package:hosspi_hms/shared/components/app_phone_field.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_identifier_type_labels.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_scope.dart';

typedef RegisterNewPatientSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

typedef RegisterNewPatientDuplicateLookup =
    Future<Result<AppPage<PatientDuplicateCandidate>>> Function(
      PatientDuplicateQuery query,
    );

/// Embeddable create-only patient registration fields shared by the registry
/// dialog and OPD intake.
class RegisterNewPatientForm extends StatefulWidget {
  const RegisterNewPatientForm({
    required this.referenceData,
    this.registrationScope = const PatientRegistrationScope(),
    this.onLookupDuplicates,
    this.enabled = true,
    this.includeNotes = true,
    this.includeActiveToggle = true,
    this.requireGender = true,
    super.key,
  });

  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;
  final RegisterNewPatientDuplicateLookup? onLookupDuplicates;
  final bool enabled;
  final bool includeNotes;
  final bool includeActiveToggle;
  final bool requireGender;

  @override
  RegisterNewPatientFormState createState() => RegisterNewPatientFormState();
}

class RegisterNewPatientFormState extends State<RegisterNewPatientForm> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _identifierTypeController;
  late final TextEditingController _identifierValueController;
  late final TextEditingController _notesController;
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  DateTime? _dateOfBirth;
  String? _gender;
  String? _tenantId;
  String? _facilityId;
  bool _isActive = true;
  bool _isCheckingDuplicates = false;
  bool _duplicateWarningAccepted = false;
  List<PatientDuplicateCandidate> _duplicateCandidates =
      const <PatientDuplicateCandidate>[];
  AppFailure? _failure;

  bool get isCheckingDuplicates => _isCheckingDuplicates;

  bool get duplicateWarningAccepted => _duplicateWarningAccepted;

  AppFailure? get failure => _failure;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _identifierTypeController = TextEditingController();
    _identifierValueController = TextEditingController();
    _notesController = TextEditingController();
    _tenantId = widget.registrationScope.defaultTenantId;
    _facilityId = widget.registrationScope.defaultFacilityId;
    _firstNameController.addListener(_clearDuplicateWarning);
    _lastNameController.addListener(_clearDuplicateWarning);
    _phoneController.addListener(_clearDuplicateWarning);
    _identifierValueController.addListener(_clearDuplicateWarning);
  }

  @override
  void didUpdateWidget(RegisterNewPatientForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registrationScope != widget.registrationScope) {
      if (!widget.registrationScope.showTenantPicker) {
        _tenantId = widget.registrationScope.defaultTenantId;
      }
      if (!widget.registrationScope.showFacilityPicker) {
        _facilityId = widget.registrationScope.defaultFacilityId;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _lastNameController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _phoneController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _emailController.dispose();
    _identifierTypeController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _identifierValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, Object?> buildPayload() {
    commitPendingFieldValues();
    final String notes = _notesController.text.trim();
    final String identifierType = _identifierTypeController.text
        .trim()
        .toUpperCase();
    return <String, Object?>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _nullableTrim(_lastNameController.text),
      'date_of_birth': _dateOnly(_dateOfBirth),
      'gender': _gender,
      'tenant_id': _resolvedTenantId(),
      'facility_id': _resolvedFacilityId(),
      'primary_phone': _nullableTrim(_phoneController.text),
      'primary_email': _nullableTrim(_emailController.text),
      'primary_identifier_type': identifierType.isEmpty ? null : identifierType,
      'primary_identifier_value': identifierType.isEmpty
          ? null
          : _nullableTrim(_identifierValueController.text),
      'is_active': _isActive,
      if (widget.includeNotes && notes.isNotEmpty)
        'extension_json': <String, Object?>{
          'registration': <String, Object?>{'notes': notes},
        },
    };
  }

  /// Runs duplicate lookup when configured. Returns false when the caller should
  /// wait for user confirmation after a duplicate warning.
  Future<bool> prepareSubmit() async {
    commitPendingFieldValues();
    if (_duplicateWarningAccepted || widget.onLookupDuplicates == null) {
      return true;
    }
    return _checkDuplicatesBeforeSave();
  }

  void commitPendingFieldValues() {
    AppPhoneField.commitPhone(_phoneFieldKey);
  }

  void setFailure(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = failure;
    });
  }

  void clearFailure() {
    if (!mounted || _failure == null) {
      return;
    }
    setState(() {
      _failure = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = widget.enabled && !_isCheckingDuplicates;
    final String? selectedIdentifierType = _selectedIdentifierType(
      _identifierTypeController.text,
    );
    final bool identifierValueDisabledAwaitingType =
        enabled && selectedIdentifierType == null;
    final bool identifierValueEnabled =
        enabled && selectedIdentifierType != null;
    final PatientRegistrationScope scope = widget.registrationScope;
    final List<PatientReferenceOption> visibleFacilities =
        PatientRegistrationScope.facilitiesForTenant(
          widget.referenceData.facilities,
          _tenantId ?? scope.defaultTenantId,
        );

    return AppFormSection(
      children: <Widget>[
        if (_duplicateCandidates.isNotEmpty)
          PatientDuplicateWarningPanel(duplicates: _duplicateCandidates),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppTextField(
            controller: _firstNameController,
            labelText: l10n.patientsFirstNameLabel,
            isRequired: true,
            textCapitalization: TextCapitalization.words,
            enabled: enabled,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          right: AppTextField(
            controller: _lastNameController,
            labelText: l10n.patientsLastNameLabel,
            textCapitalization: TextCapitalization.words,
            enabled: enabled,
          ),
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: PatientDateField(
            value: _dateOfBirth,
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            labelText: l10n.patientsDobLabel,
            enabled: enabled,
            onChanged: (DateTime? value) {
              setState(() {
                _dateOfBirth = value;
              });
            },
          ),
          right: AppGenderField(
            value: _gender,
            labelText: l10n.patientsGenderLabel,
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            enabled: enabled,
            isRequired: widget.requireGender,
            requiredMessage: l10n.validationRequired,
            onChanged: (String? value) {
              setState(() {
                _gender = value;
              });
            },
          ),
        ),
        if (scope.showTenantPicker)
          PatientTenantSelectField(
            tenants: widget.referenceData.tenants,
            value: _tenantId,
            enabled: enabled,
            isRequired: true,
            validator: AppValidators.requiredValue<String>(
              l10n.validationRequired,
            ),
            onChanged: (String? value) {
              setState(() {
                _tenantId = value;
                _facilityId = null;
              });
            },
          ),
        if (scope.showFacilityPicker)
          PatientFacilitySelectField(
            facilities: visibleFacilities,
            value: _facilityId,
            labelText: l10n.patientsFacilityLabel,
            enabled: enabled,
            isRequired: true,
            validator: AppValidators.requiredValue<String>(
              l10n.validationRequired,
            ),
            onChanged: (String? value) {
              setState(() {
                _facilityId = value;
              });
            },
          ),
        PatientPhoneField(
          phoneFieldKey: _phoneFieldKey,
          controller: _phoneController,
          labelText: l10n.patientsPhoneLabel,
          enabled: enabled,
        ),
        PatientEmailField(
          controller: _emailController,
          labelText: l10n.patientsEmailLabel,
          enabled: enabled,
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppSelectField<String>.searchable(
            value: selectedIdentifierType,
            labelText: l10n.patientsIdentifierTypeLabel,
            enabled: enabled,
            menuHeight: 320,
            onChanged: (String? value) {
              setState(() {
                _identifierTypeController.text = value ?? '';
                if (value == null || value.isEmpty) {
                  _identifierValueController.clear();
                }
              });
            },
            options: _identifierTypeSelectOptions(
              l10n,
              _identifierTypeController.text,
            ),
          ),
          right: AppTextField(
            controller: _identifierValueController,
            labelText: l10n.patientsIdentifierValueLabel,
            enabled: identifierValueEnabled,
            tooltip: identifierValueDisabledAwaitingType
                ? l10n.patientsIdentifierValueSelectTypeFirstTooltip
                : null,
          ),
        ),
        if (widget.includeNotes)
          AppTextField(
            controller: _notesController,
            labelText: l10n.patientsNotesLabel,
            enabled: enabled,
            maxLines: 3,
          ),
        if (widget.includeActiveToggle)
          AppCheckboxField(
            title: l10n.patientsActiveCheckboxLabel,
            value: _isActive,
            enabled: enabled,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
      ],
    );
  }

  Future<bool> _checkDuplicatesBeforeSave() async {
    setState(() {
      _isCheckingDuplicates = true;
      _failure = null;
    });

    final Result<AppPage<PatientDuplicateCandidate>> result =
        await widget.onLookupDuplicates!(
          PatientDuplicateQuery(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth,
            phone: _phoneController.text.trim(),
            identifierValue: _identifierValueController.text.trim(),
          ),
        );
    if (!mounted) {
      return false;
    }

    return result.when(
      success: (AppPage<PatientDuplicateCandidate> page) {
        if (page.items.isEmpty) {
          setState(() {
            _isCheckingDuplicates = false;
            _duplicateCandidates = const <PatientDuplicateCandidate>[];
          });
          return true;
        }

        setState(() {
          _isCheckingDuplicates = false;
          _duplicateCandidates = page.items;
          _duplicateWarningAccepted = true;
        });
        return false;
      },
      failure: (AppFailure failure) {
        setState(() {
          _isCheckingDuplicates = false;
          _failure = failure;
        });
        return false;
      },
    );
  }

  void _clearDuplicateWarning() {
    if (_duplicateCandidates.isEmpty && !_duplicateWarningAccepted) {
      return;
    }

    setState(() {
      _duplicateCandidates = const <PatientDuplicateCandidate>[];
      _duplicateWarningAccepted = false;
    });
  }

  String? _resolvedTenantId() {
    return _tenantId ?? widget.registrationScope.defaultTenantId;
  }

  String? _resolvedFacilityId() {
    return _facilityId ?? widget.registrationScope.defaultFacilityId;
  }
}

/// Create-only patient master-record registration dialog.
class RegisterNewPatientDialog extends StatefulWidget {
  const RegisterNewPatientDialog({
    required this.referenceData,
    required this.onSubmit,
    this.registrationScope = const PatientRegistrationScope(),
    this.onLookupDuplicates,
    super.key,
  });

  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;
  final RegisterNewPatientSubmit onSubmit;
  final RegisterNewPatientDuplicateLookup? onLookupDuplicates;

  @override
  State<RegisterNewPatientDialog> createState() =>
      _RegisterNewPatientDialogState();
}

class _RegisterNewPatientDialogState extends State<RegisterNewPatientDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<RegisterNewPatientFormState> _registrationFormKey =
      GlobalKey<RegisterNewPatientFormState>();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RegisterNewPatientFormState? formState =
        _registrationFormKey.currentState;
    final bool isCheckingDuplicates = formState?.isCheckingDuplicates ?? false;

    return AppDialog(
      title: Text(l10n.patientsRegisterNewPatientTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      closeEnabled: !_isSaving && !isCheckingDuplicates,
      initialMaximized: true,
      content: SizedBox(
        height: _formBodyHeight(context),
        child: AppFormShell(
          formKey: _formKey,
          enabled: !_isSaving && !isCheckingDuplicates,
          scrollable: true,
          formStatus: appFormFailureStatus(
            context,
            _registrationFormKey.currentState?.failure,
          ),
          children: <Widget>[
            RegisterNewPatientForm(
              key: _registrationFormKey,
              referenceData: widget.referenceData,
              registrationScope: widget.registrationScope,
              onLookupDuplicates: widget.onLookupDuplicates,
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _duplicateSaveAnywayLabel(l10n),
          leadingIcon: Icons.person_add_alt_1_outlined,
          isLoading: _isSaving || isCheckingDuplicates,
          onPressed: _submit,
        ),
      ],
    );
  }

  String _duplicateSaveAnywayLabel(AppLocalizations l10n) {
    final RegisterNewPatientFormState? formState =
        _registrationFormKey.currentState;
    if (formState == null) {
      return l10n.patientsRegisterNewPatientAction;
    }
    return formState.duplicateWarningAccepted
        ? l10n.patientsSaveAnywayAction
        : l10n.patientsRegisterNewPatientAction;
  }

  double _formBodyHeight(BuildContext context) {
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    return math.min(640, viewportHeight * 0.72);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final RegisterNewPatientFormState? formState =
        _registrationFormKey.currentState;
    if (formState == null) {
      return;
    }

    final bool canContinue = await formState.prepareSubmit();
    if (!canContinue) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
    });
    formState.clearFailure();

    final AppFailure? failure = await widget.onSubmit(formState.buildPayload());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
    });
    formState.setFailure(failure);
    setState(() {});
  }
}

class PatientDuplicateWarningPanel extends StatelessWidget {
  const PatientDuplicateWarningPanel({required this.duplicates, super.key});

  final List<PatientDuplicateCandidate> duplicates;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Iterable<PatientDuplicateCandidate> visible = duplicates.take(3);

    return AppFormInformationBanner(
      title: l10n.patientsDuplicateWarningTitle,
      message: l10n.patientsDuplicateWarningBody,
      variant: AppFormInformationVariant.warning,
      icon: Icons.content_copy_outlined,
      children: <Widget>[
        for (final PatientDuplicateCandidate duplicate in visible)
          _DuplicateCandidateLine(duplicate: duplicate),
      ],
    );
  }
}

class _DuplicateCandidateLine extends StatelessWidget {
  const _DuplicateCandidateLine({required this.duplicate});

  final PatientDuplicateCandidate duplicate;

  @override
  Widget build(BuildContext context) {
    final Patient? patient =
        duplicate.secondaryPatient ??
        duplicate.candidatePatient ??
        duplicate.primaryPatient;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.patientsDuplicateScoreLabel(duplicate.confidenceScore),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              _joinDisplay(<String?>[
                patient?.effectiveDisplayName,
                patient?.effectiveIdentifier,
                duplicate.matchReasons.map(AppDisplay.apiLabel).join(', '),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

String? _nullableTrim(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String().split('T').first;
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

List<AppSelectOption<String>> _identifierTypeSelectOptions(
  AppLocalizations l10n,
  String currentValue,
) {
  return <AppSelectOption<String>>[
    for (final String value in patientIdentifierTypeOptions(currentValue))
      AppSelectOption<String>(
        value: value,
        label: patientIdentifierTypeLabel(l10n, value),
        leadingIcon: Icon(_identifierTypeIcon(value)),
      ),
  ];
}

String? _selectedIdentifierType(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

IconData _identifierTypeIcon(String value) {
  return switch (value.trim().toUpperCase()) {
    'MRN' => Icons.badge_outlined,
    'NATIONAL_ID' => Icons.credit_card_outlined,
    'PASSPORT' => Icons.card_travel_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    'DRIVER_LICENSE' => Icons.directions_car_outlined,
    'BIRTH_CERTIFICATE' => Icons.child_care_outlined,
    _ => Icons.tag_outlined,
  };
}
