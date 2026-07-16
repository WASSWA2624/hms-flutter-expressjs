import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_clinical_quick_actions.dart';

/// Opens the patient-registry quick admission request dialog.
///
/// Composes [ClinicalAdmissionActionDialog] through [showAppDialog]. Mutation
/// is delegated to [PatientRegistryController.requestAdmission].
Future<bool?> showPatientAdmissionQuickDialog(
  BuildContext context, {
  required Patient patient,
  required PatientReferenceData referenceData,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientAdmissionQuickDialog(
      patient: patient,
      referenceData: referenceData,
    ),
  );
}

/// Patient registry quick action to request IPD admission.
///
/// Reuses [ClinicalAdmissionActionDialog] for shell, loading, footer, and
/// failure presentation. Does not call repositories directly.
class PatientAdmissionQuickDialog extends ConsumerStatefulWidget {
  const PatientAdmissionQuickDialog({
    required this.patient,
    required this.referenceData,
    super.key,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<PatientAdmissionQuickDialog> createState() =>
      _PatientAdmissionQuickDialogState();
}

class _PatientAdmissionQuickDialogState
    extends ConsumerState<PatientAdmissionQuickDialog> {
  String? _facilityId;

  @override
  void initState() {
    super.initState();
    _facilityId = _initialFacilityId();
  }

  String? _initialFacilityId() {
    if (widget.patient.facilityId != null &&
        widget.patient.facilityId!.trim().isNotEmpty) {
      return widget.patient.facilityId;
    }
    if (widget.referenceData.facilities.length == 1) {
      return widget.referenceData.facilities.first.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ClinicalAdmissionActionDialog(
      key: ValueKey<String?>(_facilityId),
      title: l10n.patientsAdmissionDialogTitle,
      submitLabel: l10n.patientsQuickAdmitPatientAction,
      referenceData: const ClinicalActionReferenceData(),
      requiresBed: false,
      reasonLabel: l10n.patientsAdmissionReasonLabel,
      reasonRequired: true,
      notesLabel: l10n.opdFieldOptionalLabel(l10n.patientsNotesLabel),
      submitLeadingIcon: AppActionIcons.bed,
      leadingSectionsBuilder: _workflowFields,
      onSubmit: _submitAdmission,
    );
  }

  List<Widget> _workflowFields(BuildContext context, bool enabled) {
    if (widget.referenceData.facilities.length <= 1) {
      return const <Widget>[];
    }
    return <Widget>[
      AppFormSection(
        title: context.l10n.patientsWorkflowSectionTitle,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          PatientFacilitySelectField(
            facilities: widget.referenceData.facilities,
            value: _facilityId,
            labelText: context.l10n.opdFieldOptionalLabel(
              context.l10n.patientsFacilityLabel,
            ),
            enabled: enabled,
            onChanged: (String? value) => setState(() => _facilityId = value),
          ),
        ],
      ),
    ];
  }

  Future<AppFailure?> _submitAdmission(
    ClinicalActionAdmissionInput input,
  ) {
    return ref
        .read(patientRegistryControllerProvider.notifier)
        .requestAdmission(
          patientId: widget.patient.id,
          apiPatientId: patientApiId(widget.patient),
          tenantId: widget.patient.tenantId,
          facilityId: _resolvedFacilityId(),
          reason: input.reason,
          notes: input.notes,
        );
  }

  String? _resolvedFacilityId() {
    if (_facilityId != null && _facilityId!.trim().isNotEmpty) {
      return _facilityId;
    }
    if (widget.referenceData.facilities.length == 1) {
      return widget.referenceData.facilities.first.id;
    }
    return widget.patient.facilityId;
  }
}
