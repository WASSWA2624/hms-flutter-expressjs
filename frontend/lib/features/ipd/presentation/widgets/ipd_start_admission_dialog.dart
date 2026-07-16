import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Admission-desk dialog to start a new IPD admission (flow §2/§3).
class IpdStartAdmissionDialog extends ConsumerStatefulWidget {
  const IpdStartAdmissionDialog({required this.referenceData, super.key});

  final IpdReferenceData referenceData;

  @override
  ConsumerState<IpdStartAdmissionDialog> createState() =>
      _IpdStartAdmissionDialogState();
}

class _IpdStartAdmissionDialogState
    extends ConsumerState<IpdStartAdmissionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Timer? _debounce;

  List<Patient> _results = <Patient>[];
  Patient? _selectedPatient;
  String? _wardId;
  String? _bedId;
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(value));
    });
  }

  Future<void> _runSearch(String value) async {
    final String term = value.trim();
    if (term.length < 2) {
      setState(() {
        _results = <Patient>[];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
        .listPatients(
          PatientListQuery(
            search: term,
            pageRequest: const AppPageRequest(pageSize: 12),
          ),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _results = page.items;
          _isSearching = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _results = <Patient>[];
          _isSearching = false;
          _failure = failure;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.ipdStartAdmissionTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 560,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _selectedPatient?.id,
            labelText: l10n.ipdStartAdmissionPatientLabel,
            hintText: l10n.ipdStartAdmissionPatientHint,
            isRequired: true,
            isLoading: _isSearching,
            enabled: !_isSaving,
            options: _patientSelectOptions(),
            validator: AppValidators.requiredValue(l10n.validationRequired),
            onSearchTextChanged: _onSearchChanged,
            onChanged: _selectPatient,
          ),
          AppSelectField<String>.searchable(
            value: _wardId,
            labelText: l10n.ipdStartAdmissionWardLabel,
            hintText: l10n.ipdSelectWardHint,
            enabled: !_isSaving,
            options: <AppSelectOption<String>>[
              for (final IpdWardOption ward in widget.referenceData.wards)
                AppSelectOption<String>(
                  value: ward.id,
                  label: ward.displayTitle,
                ),
            ],
            onChanged: (String? value) => setState(() {
              _wardId = value;
              _bedId = null;
            }),
          ),
          AppSelectField<String>.searchable(
            value: _bedId,
            labelText: l10n.ipdStartAdmissionBedLabel,
            hintText: l10n.ipdSelectBedHint,
            enabled: !_isSaving,
            options: <AppSelectOption<String>>[
              for (final IpdBedOption bed in _bedsForWard())
                AppSelectOption<String>(
                  value: bed.id,
                  label: <String?>[bed.displayTitle, bed.displaySubtitle]
                      .where((String? v) => v != null && v.trim().isNotEmpty)
                      .join(' • '),
                ),
            ],
            onChanged: (String? value) => setState(() => _bedId = value),
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.ipdStartAdmissionAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.add,
      ),
    );
  }

  List<AppSelectOption<String>> _patientSelectOptions() {
    final Map<String, Patient> byId = <String, Patient>{
      for (final Patient patient in _results) patient.id: patient,
    };
    final Patient? selected = _selectedPatient;
    if (selected != null) {
      byId[selected.id] = selected;
    }
    return <AppSelectOption<String>>[
      for (final Patient patient in byId.values)
        AppSelectOption<String>(
          value: patient.id,
          label: _patientOptionLabel(patient),
          searchText: <String?>[
            patient.effectiveDisplayName,
            patient.effectiveIdentifier,
          ].whereType<String>().join(' '),
        ),
    ];
  }

  String _patientOptionLabel(Patient patient) {
    final String name = patient.effectiveDisplayName;
    final String? identifier = patient.effectiveIdentifier?.trim();
    if (identifier == null || identifier.isEmpty) {
      return name;
    }
    return '$name • $identifier';
  }

  void _selectPatient(String? patientId) {
    setState(() {
      if (patientId == null || patientId.trim().isEmpty) {
        _selectedPatient = null;
        return;
      }
      _selectedPatient = _patientById(patientId);
      _failure = null;
    });
  }

  Patient? _patientById(String patientId) {
    final Patient? selected = _selectedPatient;
    if (selected != null && selected.id == patientId) {
      return selected;
    }
    for (final Patient patient in _results) {
      if (patient.id == patientId) {
        return patient;
      }
    }
    return null;
  }

  List<IpdBedOption> _bedsForWard() {
    final List<IpdBedOption> beds = widget.referenceData.availableBeds;
    if (_wardId == null) {
      return beds;
    }
    return beds
        .where((IpdBedOption bed) => bed.wardId == _wardId)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final Patient? patient = _selectedPatient;
    if (patient == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .startAdmission(<String, Object?>{
          'patient_id': patient.id,
          'ward_id': _wardId,
          'bed_id': _bedId,
        });
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
