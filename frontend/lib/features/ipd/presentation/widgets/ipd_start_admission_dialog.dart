import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_admission_reference_data.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

/// Opens [IpdStartAdmissionDialog] with mutating-dialog dismiss rules.
///
/// Composes through [showAppDialog]. Mutation is delegated to
/// [IpdWorkspaceController.startAdmission].
Future<bool?> showIpdStartAdmissionDialog(
  BuildContext context, {
  required IpdReferenceData referenceData,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => IpdStartAdmissionDialog(referenceData: referenceData),
  );
}

/// Admission-desk dialog to start a new IPD admission (flow §2/§3).
///
/// Reuses [ClinicalAdmissionActionDialog] for shell, loading, footer, and
/// failure presentation. Patient search and mutation stay on the workspace
/// controller — the widget never calls repositories directly.
///
/// Admission deposit / fee / bed-day lines post through shared
/// [ClinicalRequestBillingPanel] → `persistAdmissionBilling` (no parallel
/// cashier). Billing chrome is a sibling trailing block (`embedded: true`) so
/// titled sections stay flat.
class IpdStartAdmissionDialog extends ConsumerStatefulWidget {
  const IpdStartAdmissionDialog({required this.referenceData, super.key});

  final IpdReferenceData referenceData;

  @override
  ConsumerState<IpdStartAdmissionDialog> createState() =>
      _IpdStartAdmissionDialogState();
}

class _IpdStartAdmissionDialogState
    extends ConsumerState<IpdStartAdmissionDialog> {
  Timer? _debounce;

  List<Patient> _results = <Patient>[];
  Patient? _selectedPatient;
  bool _isSearching = false;
  ClinicalRequestBillingSubmit? _billing;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ClinicalAdmissionActionDialog(
      title: l10n.ipdStartAdmissionTitle,
      submitLabel: l10n.ipdStartAdmissionAction,
      icon: const Icon(AppActionIcons.personAdd),
      submitLeadingIcon: AppActionIcons.add,
      referenceData: ipdAdmissionReferenceData(context, widget.referenceData),
      bedRequired: false,
      maxWidth: 560,
      leadingSectionsBuilder: _patientSection,
      trailingSectionsBuilder: _billingSection,
      onSubmit: _submit,
    );
  }

  List<Widget> _patientSection(BuildContext context, bool enabled) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppFormSection(
        title: l10n.ipdStartAdmissionPatientLabel,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _selectedPatient?.id,
            labelText: l10n.ipdStartAdmissionPatientLabel,
            hintText: l10n.ipdStartAdmissionPatientHint,
            isRequired: true,
            isLoading: _isSearching,
            enabled: enabled,
            options: _patientSelectOptions(),
            validator: AppValidators.requiredValue(l10n.validationRequired),
            onSearchTextChanged: _onSearchChanged,
            onChanged: _selectPatient,
          ),
        ],
      ),
    ];
  }

  List<Widget> _billingSection(BuildContext context, bool enabled) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> lineItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'ADMISSION_FEE',
            label: l10n.ipdAdmissionFeeLabel,
          ),
          ClinicalRequestBillingLineItem(
            id: 'ADMISSION_DEPOSIT',
            label: l10n.ipdAdmissionDepositLabel,
          ),
          ClinicalRequestBillingLineItem(
            id: 'BED_DAY',
            label: l10n.ipdBedDayFeeLabel,
          ),
        ];

    return <Widget>[
      AppAccessGate(
        requirement: ipdBillingPanelReadRequirement,
        child: ClinicalRequestBillingPanel(
          lineItems: lineItems,
          enabled: enabled,
          // Dialog already provides titled chrome — keep sections flat.
          embedded: true,
          onChanged: (ClinicalRequestBillingSubmit value) {
            _billing = value;
          },
        ),
      ),
    ];
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
        .read(ipdWorkspaceControllerProvider.notifier)
        .searchPatients(
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
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _results = <Patient>[];
          _isSearching = false;
        });
      },
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

  Future<AppFailure?> _submit(ClinicalActionAdmissionInput input) async {
    final Patient? patient = _selectedPatient;
    if (patient == null) {
      return AppFailure.validation();
    }
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    return ref.read(ipdWorkspaceControllerProvider.notifier).startAdmission(
      <String, Object?>{
        'patient_id': patient.id,
        'ward_id': ipdApiCatalogId(input.wardId),
        'room_id': ipdApiCatalogId(input.roomId),
        'bed_id': input.bed?.apiId,
        if (charge) 'billing': billing!.toPayloadMap(),
      },
    );
  }
}
