import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

Future<void> openReceptionPatientEditor(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) {
  return showPatientDetailDialog(
    context,
    ref,
    patientId,
    allowBillingNavigation: false,
  );
}

Future<bool> openReceptionInsuranceCapture({
  required BuildContext context,
  required WidgetRef ref,
  required String patientId,
}) async {
  final Result<ClaimsReferenceData> lookups = await ref
      .read(claimsRepositoryProvider)
      .loadReferenceData();
  if (!context.mounted) {
    return false;
  }
  final ClaimsReferenceData? referenceData = lookups.when(
    success: (ClaimsReferenceData value) => value,
    failure: (_) => null,
  );
  if (referenceData == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.receptionInsuranceLookupFailed)),
    );
    return false;
  }
  await openClaimsEnrollmentDialog(
    context: context,
    ref: ref,
    referenceData: referenceData,
    patientId: patientId,
  );
  return true;
}

/// Opens the reception patient picker (search + select, no mutation).
Future<Patient?> showReceptionPatientPickerDialog({
  required BuildContext context,
}) {
  return showAppDialog<Patient>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ReceptionPatientPickerDialog(),
  );
}

Future<bool> openReceptionScheduleAppointment({
  required BuildContext context,
  required WidgetRef ref,
  Patient? patient,
}) async {
  final AsyncValue<Result<PatientRegistryState>> registryAsync = ref.read(
    patientRegistryControllerProvider,
  );
  PatientRegistryState? registry = registryAsync.asData?.value.when(
    success: (PatientRegistryState state) => state,
    failure: (_) => null,
  );
  if (registry == null) {
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .refresh();
    if (!context.mounted) {
      return false;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return false;
    }
    registry = ref
        .read(patientRegistryControllerProvider)
        .asData
        ?.value
        .when(
          success: (PatientRegistryState state) => state,
          failure: (_) => null,
        );
  }
  if (registry == null || !context.mounted) {
    return false;
  }
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReceptionScheduleAppointmentDialog(
      initialPatient: patient,
      referenceData: registry!.referenceData,
      registrationScope: PatientRegistrationScope.resolve(
        referenceData: registry.referenceData,
        accessPolicy: ref.read(appAccessPolicyProvider),
      ),
    ),
  );
  return saved == true;
}

enum _SchedulePatientMode { existing, newPatient }

class _ReceptionScheduleAppointmentDialog extends ConsumerStatefulWidget {
  const _ReceptionScheduleAppointmentDialog({
    required this.referenceData,
    required this.registrationScope,
    this.initialPatient,
  });

  final Patient? initialPatient;
  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;

  @override
  ConsumerState<_ReceptionScheduleAppointmentDialog> createState() =>
      _ReceptionScheduleAppointmentDialogState();
}

class _ReceptionScheduleAppointmentDialogState
    extends ConsumerState<_ReceptionScheduleAppointmentDialog> {
  final GlobalKey<FormState> _registrationFormKey = GlobalKey<FormState>();
  final GlobalKey<RegisterNewPatientFormState> _registrationKey =
      GlobalKey<RegisterNewPatientFormState>();
  _SchedulePatientMode _mode = _SchedulePatientMode.existing;
  Patient? _patient;
  bool _isRegistering = false;
  bool _isAppointmentBusy = false;

  bool get _isBusy => _isRegistering || _isAppointmentBusy;

  @override
  void initState() {
    super.initState();
    _patient = widget.initialPatient;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.patientsAppointmentDialogTitle),
      icon: const Icon(AppActionIcons.calendar),
      scrollable: true,
      pinActionsToBottom: _patient == null,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: _patient == null
          ? _buildPatientStep(context)
          : PatientAppointmentQuickDialog(
              patient: _patient!,
              referenceData: widget.referenceData,
              embedded: true,
              allowClinicalActions: false,
              allowVitalsActions: false,
              onCancel: () => setState(() {
                _patient = null;
                _isAppointmentBusy = false;
              }),
              onBusyChanged: (bool value) {
                if (mounted && value != _isAppointmentBusy) {
                  setState(() => _isAppointmentBusy = value);
                }
              },
              onSaved: () => Navigator.of(context).pop(true),
            ),
      actions: _patient == null
          ? _patientStepActions(context)
          : const <Widget>[],
    );
  }

  Widget _buildPatientStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[
            AppTabItem(
              id: _SchedulePatientMode.existing.name,
              label: l10n.receptionScheduleExistingPatientTab,
            ),
            AppTabItem(
              id: _SchedulePatientMode.newPatient.name,
              label: l10n.receptionScheduleNewPatientTab,
            ),
          ],
          selectedId: _mode.name,
          onTabTapped: (String id) {
            if (_isBusy) {
              return;
            }
            setState(() {
              _mode = _SchedulePatientMode.values.byName(id);
            });
          },
        ),
        const SizedBox(height: 16),
        if (_mode == _SchedulePatientMode.existing)
          _ReceptionPatientPickerDialog(
            embedded: true,
            onSelected: (Patient? value) {
              if (value != null) {
                setState(() => _patient = value);
              }
            },
          )
        else
          AppFormShell(
            formKey: _registrationFormKey,
            enabled: !_isRegistering,
            formStatus: appFormFailureStatus(
              context,
              _registrationKey.currentState?.failure,
              messageBuilder: (AppFailure failure) =>
                  failure.displayMessage(l10n),
            ),
            children: <Widget>[
              RegisterNewPatientForm(
                key: _registrationKey,
                referenceData: widget.referenceData,
                registrationScope: widget.registrationScope,
                enabled: !_isRegistering,
                onLookupDuplicates: (PatientDuplicateQuery query) => ref
                    .read(patientRegistryControllerProvider.notifier)
                    .loadDuplicateCandidates(query),
                onDuplicateStateChanged: () => setState(() {}),
                onUseExistingPatient: (Patient patient) {
                  setState(() {
                    _patient = patient;
                    _isRegistering = false;
                  });
                },
              ),
            ],
          ),
      ],
    );
  }

  List<Widget> _patientStepActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppButton.secondary(
        label: l10n.commonCancelActionLabel,
        leadingIcon: AppActionIcons.cancel,
        enabled: !_isBusy,
        onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
      ),
      if (_mode == _SchedulePatientMode.newPatient)
        AppButton.primary(
          label: _registrationKey.currentState?.duplicateWarningAccepted == true
              ? l10n.patientsRegisterAnywayAction
              : l10n.patientsRegisterNewPatientAction,
          leadingIcon: AppActionIcons.personAdd,
          isLoading: _isRegistering,
          enabled: !_isBusy,
          onPressed: _isBusy ? null : _registerPatient,
        ),
    ];
  }

  Future<void> _registerPatient() async {
    if (_isBusy || !validateAndSaveAppForm(_registrationFormKey)) {
      return;
    }
    final RegisterNewPatientFormState? formState =
        _registrationKey.currentState;
    if (formState == null) {
      return;
    }
    setState(() => _isRegistering = true);
    formState.clearFailure();
    final bool canContinue = await formState.prepareSubmit();
    if (!mounted) {
      return;
    }
    if (!canContinue) {
      setState(() => _isRegistering = false);
      return;
    }
    final Result<Patient> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .createPatient(formState.buildPayload());
    if (!mounted) {
      return;
    }
    result.when(
      success: (Patient patient) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.patientsSavedMessage)),
        );
        setState(() {
          _patient = patient;
          _isRegistering = false;
        });
      },
      failure: (AppFailure failure) {
        formState.setFailure(failure);
        setState(() => _isRegistering = false);
      },
    );
  }
}

class _ReceptionPatientPickerDialog extends ConsumerStatefulWidget {
  const _ReceptionPatientPickerDialog({this.embedded = false, this.onSelected});

  final bool embedded;
  final ValueChanged<Patient?>? onSelected;

  @override
  ConsumerState<_ReceptionPatientPickerDialog> createState() =>
      _ReceptionPatientPickerDialogState();
}

class _ReceptionPatientPickerDialogState
    extends ConsumerState<_ReceptionPatientPickerDialog> {
  static const Duration _searchDebounce = Duration(milliseconds: 250);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  int _searchGeneration = 0;
  bool _isLoading = false;
  AppFailure? _failure;
  List<Patient> _patients = const <Patient>[];
  Patient? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch(String raw) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      unawaited(_search(raw));
    });
  }

  Future<void> _search(String raw) async {
    final int generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .loadPatientPage(
          PatientListQuery(
            search: raw.trim(),
            pageRequest: const AppPageRequest(pageSize: 12),
          ),
        );
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        final String? selectedKey = _patientOptionValue(_selected);
        Patient? nextSelected = _selected;
        if (selectedKey != null) {
          nextSelected = null;
          for (final Patient patient in page.items) {
            if (_patientOptionValue(patient) == selectedKey) {
              nextSelected = patient;
              break;
            }
          }
          // Keep the prior selection visible when it falls outside this page.
          nextSelected ??= _selected;
        }
        setState(() {
          _patients = page.items;
          _selected = nextSelected;
          _isLoading = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _patients = const <Patient>[];
          _selected = null;
          _isLoading = false;
        });
      },
    );
  }

  void _selectPatient(String? value) {
    final Patient? patient = _patientByOptionValue(value);
    setState(() {
      _selected = patient;
      if (_selected != null) {
        _failure = null;
      }
    });
    if (widget.embedded) {
      widget.onSelected?.call(patient);
    }
  }

  void _confirmSelection() {
    if (_isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final Patient? selected = _selected;
    if (selected == null) {
      return;
    }
    Navigator.of(context).pop(selected);
  }

  List<AppSelectOption<String>> _patientSelectOptions() {
    final Map<String, Patient> byKey = <String, Patient>{
      for (final Patient patient in _patients)
        if (_patientOptionValue(patient) != null)
          _patientOptionValue(patient)!: patient,
    };
    final Patient? selected = _selected;
    final String? selectedKey = _patientOptionValue(selected);
    if (selected != null && selectedKey != null) {
      byKey[selectedKey] = selected;
    }
    return <AppSelectOption<String>>[
      for (final Patient patient in byKey.values)
        AppSelectOption<String>(
          value: _patientOptionValue(patient)!,
          label: _patientOptionLabel(patient),
          searchText: <String?>[
            patient.effectiveDisplayName,
            patient.effectiveIdentifier,
            patient.primaryPhone,
            patient.publicId,
            patient.id,
          ].whereType<String>().join(' '),
        ),
    ];
  }

  Patient? _patientByOptionValue(String? value) {
    final String? key = value?.trim();
    if (key == null || key.isEmpty) {
      return null;
    }
    final Patient? selected = _selected;
    if (_patientOptionValue(selected) == key) {
      return selected;
    }
    for (final Patient patient in _patients) {
      if (_patientOptionValue(patient) == key) {
        return patient;
      }
    }
    return null;
  }

  static String? _patientOptionValue(Patient? patient) {
    if (patient == null) {
      return null;
    }
    final String? publicId = patient.publicId?.trim();
    if (publicId != null && publicId.isNotEmpty) {
      return publicId;
    }
    final String id = patient.id.trim();
    return id.isEmpty ? null : id;
  }

  static String _patientOptionLabel(Patient patient) {
    final String name = patient.effectiveDisplayName.trim();
    final String? identifier = patient.effectiveIdentifier?.trim();
    if (identifier == null || identifier.isEmpty) {
      return name;
    }
    if (name.isEmpty) {
      return identifier;
    }
    return '$name • $identifier';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canConfirm = !_isLoading && _selected != null;
    final String? emptyHelper =
        !_isLoading && _failure == null && _patients.isEmpty
        ? l10n.receptionPatientPickerEmpty
        : null;

    final Widget form = AppFormShell(
      formKey: _formKey,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        if (_failure != null)
          AppFormInformationBanner.failure(
            context: context,
            failure: _failure!,
          ),
        AppSelectField<String>.searchable(
          value: _patientOptionValue(_selected),
          labelText: l10n.receptionPatientPickerSearchHint,
          helperText: emptyHelper,
          isRequired: true,
          isLoading: _isLoading,
          options: _patientSelectOptions(),
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onSearchTextChanged: _scheduleSearch,
          onChanged: _selectPatient,
        ),
      ],
    );
    if (widget.embedded) {
      return form;
    }
    return AppDialog(
      title: Text(l10n.receptionPatientPickerTitle),
      icon: const Icon(AppActionIcons.person),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isLoading,
      maxWidth: 560,
      content: form,
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isLoading,
          onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.commonSelectActionLabel,
          leadingIcon: AppActionIcons.person,
          enabled: canConfirm,
          onPressed: canConfirm ? _confirmSelection : null,
        ),
      ],
    );
  }
}
