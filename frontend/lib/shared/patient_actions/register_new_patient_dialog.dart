import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
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
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_identifier_type_labels.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_scope.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_similarity_dialog.dart';

typedef RegisterNewPatientSubmit =
    Future<Result<Patient>> Function(Map<String, Object?> payload);

typedef RegisterNewPatientDuplicateLookup =
    Future<Result<AppPage<PatientDuplicateCandidate>>> Function(
      PatientDuplicateQuery query,
    );

enum PatientRegistrationOutcome { created, existing }

@immutable
final class PatientRegistrationResult {
  const PatientRegistrationResult({
    required this.patient,
    required this.outcome,
  });

  final Patient patient;
  final PatientRegistrationOutcome outcome;

  bool get wasCreated => outcome == PatientRegistrationOutcome.created;
}

/// Embeddable create-only patient registration fields shared by the registry
/// dialog and OPD intake.
class RegisterNewPatientForm extends StatefulWidget {
  const RegisterNewPatientForm({
    required this.referenceData,
    this.registrationScope = const PatientRegistrationScope(),
    this.onLookupDuplicates,
    this.onDuplicateStateChanged,
    this.onUseExistingPatient,
    this.enabled = true,
    this.includeNotes = true,
    this.includeActiveToggle = true,
    this.requireGender = true,
    super.key,
  });

  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;
  final RegisterNewPatientDuplicateLookup? onLookupDuplicates;
  final VoidCallback? onDuplicateStateChanged;
  final ValueChanged<Patient>? onUseExistingPatient;
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
  AppFailure? _failure;

  bool get isCheckingDuplicates => _isCheckingDuplicates;

  /// True after the shared similarity dialog accepted "Register anyway".
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
    _emailController.addListener(_clearDuplicateWarning);
    _identifierTypeController.addListener(_clearDuplicateWarning);
    _identifierValueController.addListener(_clearDuplicateWarning);
    _notesController.addListener(_clearDuplicateWarning);
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
    _emailController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _identifierTypeController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _identifierValueController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
    _notesController
      ..removeListener(_clearDuplicateWarning)
      ..dispose();
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

  /// Runs duplicate lookup when configured and opens the shared similarity
  /// dialog when matches are found. Returns false when registration should
  /// stop (cancel, use-existing, or lookup failure).
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
    final String? selectedTenantId = scope.showTenantPicker
        ? _tenantId
        : (_tenantId ?? scope.defaultTenantId);
    final bool facilityDisabledAwaitingTenant =
        scope.showTenantPicker &&
        scope.showFacilityPicker &&
        (selectedTenantId == null || selectedTenantId.isEmpty);
    final List<PatientReferenceOption> visibleFacilities =
        facilityDisabledAwaitingTenant
        ? const <PatientReferenceOption>[]
        : PatientRegistrationScope.facilitiesForTenant(
            widget.referenceData.facilities,
            selectedTenantId,
          );

    return AppFormSection(
      children: <Widget>[
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
              _clearDuplicateWarning();
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
              _clearDuplicateWarning();
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
              _clearDuplicateWarning();
            },
          ),
        if (scope.showFacilityPicker)
          _wrapFacilityTooltip(
            disabledAwaitingTenant: facilityDisabledAwaitingTenant,
            message: l10n.patientsFacilitySelectTenantFirstTooltip,
            child: PatientFacilitySelectField(
              facilities: visibleFacilities,
              value: _facilityId,
              labelText: l10n.patientsFacilityLabel,
              enabled: enabled && !facilityDisabledAwaitingTenant,
              isRequired: true,
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              onChanged: (String? value) {
                setState(() {
                  _facilityId = value;
                });
                _clearDuplicateWarning();
              },
            ),
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
              _clearDuplicateWarning();
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
              _clearDuplicateWarning();
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
    widget.onDuplicateStateChanged?.call();

    final Result<AppPage<PatientDuplicateCandidate>> result =
        await widget.onLookupDuplicates!(
          PatientDuplicateQuery(
            tenantId: _resolvedTenantId() ?? '',
            facilityId: _resolvedFacilityId() ?? '',
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth,
            gender: _gender ?? '',
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            identifierType: _identifierTypeController.text.trim(),
            identifierValue: _identifierValueController.text.trim(),
          ),
        );
    if (!mounted) {
      return false;
    }

    late final AppPage<PatientDuplicateCandidate> page;
    final bool lookupOk = result.when(
      success: (AppPage<PatientDuplicateCandidate> value) {
        page = value;
        return true;
      },
      failure: (AppFailure failure) {
        setState(() {
          _isCheckingDuplicates = false;
          _failure = failure;
        });
        widget.onDuplicateStateChanged?.call();
        return false;
      },
    );
    if (!lookupOk) {
      return false;
    }

    if (page.items.isEmpty) {
      setState(() {
        _isCheckingDuplicates = false;
      });
      widget.onDuplicateStateChanged?.call();
      return true;
    }

    setState(() {
      _isCheckingDuplicates = false;
    });
    widget.onDuplicateStateChanged?.call();

    final PatientRegistrationSimilarityDialogResult review =
        await showPatientRegistrationSimilarityDialog(
          context,
          proposed: _similarityProposed(),
          matches: page.items,
        );
    if (!mounted) {
      return false;
    }

    switch (review.action) {
      case PatientRegistrationSimilarityAction.cancel:
        return false;
      case PatientRegistrationSimilarityAction.useExisting:
        final Patient? patient = review.selectedPatient;
        if (patient != null) {
          widget.onUseExistingPatient?.call(patient);
        }
        return false;
      case PatientRegistrationSimilarityAction.proceed:
        setState(() {
          _duplicateWarningAccepted = true;
        });
        widget.onDuplicateStateChanged?.call();
        return true;
    }
  }

  void _clearDuplicateWarning() {
    if (!_duplicateWarningAccepted) {
      return;
    }

    setState(() {
      _duplicateWarningAccepted = false;
    });
    widget.onDuplicateStateChanged?.call();
  }

  PatientRegistrationSimilarityProposed _similarityProposed() {
    final String? tenantId = _resolvedTenantId();
    final String? facilityId = _resolvedFacilityId();
    return PatientRegistrationSimilarityProposed(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender ?? '',
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      identifierType: _identifierTypeController.text.trim(),
      identifierValue: _identifierValueController.text.trim(),
      tenantId: tenantId ?? '',
      facilityId: facilityId ?? '',
      tenantLabel: _referenceLabel(
        widget.referenceData.tenants,
        tenantId,
      ),
      facilityLabel: _referenceLabel(
        widget.referenceData.facilities,
        facilityId,
      ),
    );
  }

  String _referenceLabel(
    List<PatientReferenceOption> options,
    String? id,
  ) {
    final String? normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '';
    }
    for (final PatientReferenceOption option in options) {
      if (option.id == normalized) {
        return option.label.trim();
      }
    }
    return '';
  }

  String? _resolvedTenantId() {
    return _tenantId ?? widget.registrationScope.defaultTenantId;
  }

  String? _resolvedFacilityId() {
    return _facilityId ?? widget.registrationScope.defaultFacilityId;
  }
}

/// Opens [RegisterNewPatientDialog] with mutating-dialog dismiss rules.
Future<PatientRegistrationResult?> showRegisterNewPatientDialog({
  required BuildContext context,
  required PatientReferenceData referenceData,
  required RegisterNewPatientSubmit onSubmit,
  PatientRegistrationScope registrationScope = const PatientRegistrationScope(),
  RegisterNewPatientDuplicateLookup? onLookupDuplicates,
}) async {
  PatientRegistrationOutcome outcome = PatientRegistrationOutcome.created;
  final Patient? patient = await showAppDialog<Patient>(
    context: context,
    builder: (_) => RegisterNewPatientDialog(
      referenceData: referenceData,
      registrationScope: registrationScope,
      onLookupDuplicates: onLookupDuplicates,
      onSubmit: onSubmit,
      onOutcome: (PatientRegistrationOutcome value) => outcome = value,
    ),
  );
  if (patient == null) {
    return null;
  }
  return PatientRegistrationResult(patient: patient, outcome: outcome);
}

/// Create-only patient master-record registration dialog.
class RegisterNewPatientDialog extends StatefulWidget {
  const RegisterNewPatientDialog({
    required this.referenceData,
    required this.onSubmit,
    this.registrationScope = const PatientRegistrationScope(),
    this.onLookupDuplicates,
    this.onOutcome,
    super.key,
  });

  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;
  final RegisterNewPatientSubmit onSubmit;
  final RegisterNewPatientDuplicateLookup? onLookupDuplicates;
  final ValueChanged<PatientRegistrationOutcome>? onOutcome;

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
    final bool isBusy = _isSaving || isCheckingDuplicates;

    return AppDialog(
      title: Text(l10n.patientsRegisterNewPatientTitle),
      icon: const Icon(AppActionIcons.personAdd),
      pinActionsToBottom: true,
      closeEnabled: !isBusy,
      maxWidth: 720,
      content: SizedBox(
        height: _formBodyHeight(context),
        child: AppFormShell(
          formKey: _formKey,
          enabled: !isBusy,
          scrollable: true,
          formStatus: appFormFailureStatus(
            context,
            formState?.failure,
            messageBuilder: (AppFailure failure) =>
                failure.displayMessage(l10n),
          ),
          children: <Widget>[
            RegisterNewPatientForm(
              key: _registrationFormKey,
              referenceData: widget.referenceData,
              registrationScope: widget.registrationScope,
              onLookupDuplicates: widget.onLookupDuplicates,
              onDuplicateStateChanged: () => setState(() {}),
              onUseExistingPatient: (Patient patient) {
                widget.onOutcome?.call(PatientRegistrationOutcome.existing);
                Navigator.of(context).pop(patient);
              },
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.patientsRegisterNewPatientAction,
        cancelIcon: AppActionIcons.cancel,
        submitIcon: AppActionIcons.personAdd,
        isSubmitting: isBusy,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
    );
  }

  double _formBodyHeight(BuildContext context) {
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    return math.min(640, viewportHeight * 0.72);
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    final RegisterNewPatientFormState? formState =
        _registrationFormKey.currentState;
    if (formState == null) {
      return;
    }

    setState(() => _isSaving = true);
    formState.clearFailure();

    final bool canContinue = await formState.prepareSubmit();
    if (!canContinue) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      return;
    }

    final Result<Patient> result = await widget.onSubmit(
      formState.buildPayload(),
    );
    if (!mounted) {
      return;
    }
    return result.when(
      success: (Patient patient) {
        widget.onOutcome?.call(PatientRegistrationOutcome.created);
        Navigator.of(context).pop(patient);
      },
      failure: (AppFailure failure) {
        formState.setFailure(failure);
        setState(() => _isSaving = false);
      },
    );
  }
}

Widget _wrapFacilityTooltip({
  required bool disabledAwaitingTenant,
  required String message,
  required Widget child,
}) {
  if (!disabledAwaitingTenant) {
    return child;
  }

  return Tooltip(message: message, child: child);
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
