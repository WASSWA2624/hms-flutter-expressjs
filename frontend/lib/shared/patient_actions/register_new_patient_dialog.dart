import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
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
        if (_duplicateCandidates.isNotEmpty)
          PatientDuplicateWarningPanel(
            duplicates: _duplicateCandidates,
            onUseExistingPatient: widget.onUseExistingPatient,
          ),
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

    return result.when(
      success: (AppPage<PatientDuplicateCandidate> page) {
        if (page.items.isEmpty) {
          setState(() {
            _isCheckingDuplicates = false;
            _duplicateCandidates = const <PatientDuplicateCandidate>[];
          });
          widget.onDuplicateStateChanged?.call();
          return true;
        }

        setState(() {
          _isCheckingDuplicates = false;
          _duplicateCandidates = page.items;
          _duplicateWarningAccepted = true;
        });
        widget.onDuplicateStateChanged?.call();
        return false;
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
  }

  void _clearDuplicateWarning() {
    if (_duplicateCandidates.isEmpty && !_duplicateWarningAccepted) {
      return;
    }

    setState(() {
      _duplicateCandidates = const <PatientDuplicateCandidate>[];
      _duplicateWarningAccepted = false;
    });
    widget.onDuplicateStateChanged?.call();
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
    barrierDismissible: false,
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
        submitLabel: _duplicateSaveAnywayLabel(l10n),
        cancelIcon: AppActionIcons.cancel,
        submitIcon: AppActionIcons.personAdd,
        isSubmitting: isBusy,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
    );
  }

  String _duplicateSaveAnywayLabel(AppLocalizations l10n) {
    final RegisterNewPatientFormState? formState =
        _registrationFormKey.currentState;
    if (formState == null) {
      return l10n.patientsRegisterNewPatientAction;
    }
    return formState.duplicateWarningAccepted
        ? l10n.patientsRegisterAnywayAction
        : l10n.patientsRegisterNewPatientAction;
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

class PatientDuplicateWarningPanel extends StatelessWidget {
  const PatientDuplicateWarningPanel({
    required this.duplicates,
    this.onUseExistingPatient,
    super.key,
  });

  static const int _maxVisibleCandidates = 3;

  final List<PatientDuplicateCandidate> duplicates;
  final ValueChanged<Patient>? onUseExistingPatient;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PatientDuplicateCandidate> visible = duplicates
        .take(_maxVisibleCandidates)
        .toList(growable: false);
    final int hiddenCount = duplicates.length - visible.length;

    return AppFormInformationBanner(
      title: l10n.patientsDuplicateWarningTitle,
      message: l10n.patientsDuplicateWarningBody,
      variant: AppFormInformationVariant.warning,
      icon: AppActionIcons.copy,
      children: <Widget>[
        for (final PatientDuplicateCandidate duplicate in visible)
          _DuplicateCandidateCard(
            duplicate: duplicate,
            onUseExistingPatient: onUseExistingPatient,
          ),
        if (hiddenCount > 0)
          Text(
            l10n.patientsDuplicateMoreMatchesLabel(hiddenCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.statusColors.onWarningContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

class _DuplicateCandidateCard extends StatelessWidget {
  const _DuplicateCandidateCard({
    required this.duplicate,
    this.onUseExistingPatient,
  });

  final PatientDuplicateCandidate duplicate;
  final ValueChanged<Patient>? onUseExistingPatient;

  @override
  Widget build(BuildContext context) {
    final Patient? patient =
        duplicate.secondaryPatient ??
        duplicate.candidatePatient ??
        duplicate.primaryPatient;
    if (patient == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final _DuplicateSeverityStyle severity = _duplicateSeverityStyle(
      theme,
      l10n,
      duplicate.classification,
    );

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      backgroundColor: theme.colorScheme.surface,
      borderColor: severity.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CandidateCardHeader(
            patient: patient,
            duplicate: duplicate,
            severity: severity,
          ),
          if (duplicate.fieldComparisons.isNotEmpty) ...<Widget>[
            Divider(height: theme.spacing.lg),
            for (
              int index = 0;
              index < duplicate.fieldComparisons.length;
              index += 1
            ) ...<Widget>[
              if (index > 0) SizedBox(height: theme.spacing.sm),
              _FieldComparisonRow(
                comparison: duplicate.fieldComparisons[index],
              ),
            ],
          ] else if (duplicate.matchReasons.isNotEmpty) ...<Widget>[
            Divider(height: theme.spacing.lg),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                for (final String reason in duplicate.matchReasons)
                  _MatchReasonChip(label: AppDisplay.apiLabel(reason)),
              ],
            ),
          ],
          if (onUseExistingPatient != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton.secondary(
                label: l10n.patientsUseExistingPatientAction,
                leadingIcon: AppActionIcons.person,
                onPressed: () => onUseExistingPatient!(patient),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateCardHeader extends StatelessWidget {
  const _CandidateCardHeader({
    required this.patient,
    required this.duplicate,
    required this.severity,
  });

  final Patient patient;
  final PatientDuplicateCandidate duplicate;
  final _DuplicateSeverityStyle severity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String summary = _joinDisplay(<String?>[
      patient.effectiveIdentifier,
      _dateOfBirthLabel(context, patient.dateOfBirth),
      AppDisplay.apiLabel(patient.gender),
      patient.primaryPhone,
      patient.primaryEmail,
    ], separator: ' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          AppActionIcons.person,
          size: theme.appTokens.listIconSize,
          color: severity.accent,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                patient.effectiveDisplayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
              if (summary.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.xs / 2),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _DuplicateScoreBadge(
              label: l10n.patientsDuplicateScoreLabel(
                duplicate.confidenceScore,
              ),
              severity: severity,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              severity.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: severity.accent,
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DuplicateScoreBadge extends StatelessWidget {
  const _DuplicateScoreBadge({required this.label, required this.severity});

  final String label;
  final _DuplicateSeverityStyle severity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: severity.container,
        borderRadius: BorderRadius.circular(theme.radius.full),
        border: theme.borders.all(color: severity.accent),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: severity.onContainer,
          fontWeight: AppFontWeight.emphasis,
        ),
      ),
    );
  }
}

class _FieldComparisonRow extends StatelessWidget {
  const _FieldComparisonRow({required this.comparison});

  final PatientDuplicateFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final _ComparisonStatusStyle status = _comparisonStatusStyle(
      theme,
      l10n,
      comparison,
    );
    final String inputValue = _comparisonValueLabel(
      context,
      comparison.field,
      comparison.inputValue,
    );
    final String candidateValue = _comparisonValueLabel(
      context,
      comparison.field,
      comparison.candidateValue,
    );
    final bool valuesAgree = status.isMatch || inputValue == candidateValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          status.icon,
          size: theme.appTokens.listIconSize,
          color: status.color,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _comparisonFieldLabel(l10n, comparison.field),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ),
                  Text(
                    status.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status.color,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs / 2),
              if (valuesAgree)
                Text(candidateValue, style: theme.textTheme.bodySmall)
              else ...<Widget>[
                Text(
                  '${l10n.patientsDuplicateYourEntryLabel}: $inputValue',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.patientsDuplicateExistingRecordLabel}: '
                  '$candidateValue',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.color,
                    fontWeight: AppFontWeight.medium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchReasonChip extends StatelessWidget {
  const _MatchReasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(theme.radius.full),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: AppFontWeight.medium,
        ),
      ),
    );
  }
}

@immutable
final class _DuplicateSeverityStyle {
  const _DuplicateSeverityStyle({
    required this.label,
    required this.accent,
    required this.container,
    required this.onContainer,
  });

  final String label;
  final Color accent;
  final Color container;
  final Color onContainer;
}

_DuplicateSeverityStyle _duplicateSeverityStyle(
  ThemeData theme,
  AppLocalizations l10n,
  String classification,
) {
  final AppStatusColors statusColors = theme.statusColors;
  final String normalized = classification.trim().toUpperCase();
  if (normalized.contains('STRONG')) {
    return _DuplicateSeverityStyle(
      label: l10n.patientsDuplicateClassificationStrongLabel,
      accent: statusColors.error,
      container: statusColors.errorContainer,
      onContainer: statusColors.onErrorContainer,
    );
  }
  if (normalized.contains('POSSIBLE') || normalized.contains('MEDIUM')) {
    return _DuplicateSeverityStyle(
      label: l10n.patientsDuplicateClassificationPossibleLabel,
      accent: statusColors.warning,
      container: statusColors.warningContainer,
      onContainer: statusColors.onWarningContainer,
    );
  }
  if (normalized.contains('REVIEW')) {
    return _DuplicateSeverityStyle(
      label: l10n.patientsDuplicateClassificationReviewLabel,
      accent: statusColors.info,
      container: statusColors.infoContainer,
      onContainer: statusColors.onInfoContainer,
    );
  }
  return _DuplicateSeverityStyle(
    label: l10n.patientsDuplicateClassificationLowLabel,
    accent: theme.colorScheme.outline,
    container: theme.colorScheme.surfaceContainerHighest,
    onContainer: theme.colorScheme.onSurfaceVariant,
  );
}

@immutable
final class _ComparisonStatusStyle {
  const _ComparisonStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isMatch,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isMatch;
}

_ComparisonStatusStyle _comparisonStatusStyle(
  ThemeData theme,
  AppLocalizations l10n,
  PatientDuplicateFieldComparison comparison,
) {
  final AppStatusColors statusColors = theme.statusColors;
  final int? similarityPercent = comparison.similarityPercent;

  return switch (comparison.status.trim().toUpperCase()) {
    'MATCH' => _ComparisonStatusStyle(
      label: l10n.patientsDuplicateStatusMatchLabel,
      icon: Icons.check_circle_outline,
      color: statusColors.success,
      isMatch: true,
    ),
    'SIMILAR' => _ComparisonStatusStyle(
      label: similarityPercent == null
          ? l10n.patientsDuplicateStatusSimilarLabel
          : '${l10n.patientsDuplicateStatusSimilarLabel} · '
                '${l10n.patientsDuplicateSimilarityLabel(similarityPercent)}',
      icon: Icons.change_circle_outlined,
      color: statusColors.warning,
      isMatch: false,
    ),
    'CONFLICT' => _ComparisonStatusStyle(
      label: l10n.patientsDuplicateStatusConflictLabel,
      icon: Icons.cancel_outlined,
      color: statusColors.error,
      isMatch: false,
    ),
    _ => _ComparisonStatusStyle(
      label: AppDisplay.apiLabel(comparison.status),
      icon: Icons.info_outline,
      color: theme.colorScheme.onSurfaceVariant,
      isMatch: false,
    ),
  };
}

String _comparisonFieldLabel(AppLocalizations l10n, String field) {
  return switch (field.trim().toUpperCase()) {
    'NAME' => l10n.patientsNameLabel,
    'DATE_OF_BIRTH' || 'DOB' => l10n.patientsDobLabel,
    'GENDER' => l10n.patientsGenderLabel,
    'PHONE' => l10n.patientsPhoneLabel,
    'EMAIL' => l10n.patientsEmailLabel,
    'IDENTIFIER' => l10n.patientsIdentifierLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String _comparisonValueLabel(BuildContext context, String field, String raw) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return '—';
  }

  return switch (field.trim().toUpperCase()) {
    'GENDER' => AppDisplay.apiLabel(value),
    'DATE_OF_BIRTH' ||
    'DOB' => _dateOfBirthLabel(context, DateTime.tryParse(value)) ?? value,
    _ => value,
  };
}

String? _dateOfBirthLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
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

String _joinDisplay(Iterable<String?> values, {String separator = ' | '}) {
  return values
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(separator);
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
