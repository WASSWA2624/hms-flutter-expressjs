import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

enum PatientQuickAction {
  appointment,
  opdCheckIn,
  opdActions,
  admission,
  discharge,
  report,
  labOrder,
  radiologyOrder,
  theaterSchedule,
  physiotherapy,
  enrollInsurance,
}

typedef PatientQuickActionHandler =
    Future<void> Function(PatientQuickAction action);

class PatientDetailQuickActions extends ConsumerWidget {
  const PatientDetailQuickActions({
    required this.detail,
    required this.onAction,
    super.key,
  });

  final PatientDetail detail;
  final PatientQuickActionHandler onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Patient patient = detail.patient;
    final PatientVisitContext? visit = patient.currentVisit;
    final bool hasActiveOpdEncounter = isActiveOpdPatientVisit(visit);
    final List<PatientActiveWorkItem> activeWork = collectPatientActiveWorkItems(
      detail,
    );
    final bool hasActiveOpdWorkItem = activeWork.any(
      (PatientActiveWorkItem item) =>
          item.kind == PatientActiveWorkKind.encounter ||
          item.kind == PatientActiveWorkKind.queue,
    );
    final bool hasAdmissionWorkItem = activeWork.any(
      (PatientActiveWorkItem item) => item.kind == PatientActiveWorkKind.admission,
    );
    final PatientSummaryRecord? activeAdmission = activePatientAdmissionRecord(
      detail.workspace.admissions,
    );
    final PatientVisitContext? activeAdmissionVisit =
        isActiveAdmissionPatientVisit(visit) ? visit : null;
    final bool hasActiveAdmission =
        activeAdmission != null || activeAdmissionVisit != null;
    final bool hasOpenAppointment = patientHasOpenAppointment(detail);
    final bool canStartPhysiotherapy =
        hasActiveAdmission || hasActiveOpdEncounter || hasActiveOpdWorkItem;

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (!hasOpenAppointment)
        AppPermissionActionItem(
          label: l10n.patientsQuickAppointmentAction,
          icon: Icons.event_available_outlined,
          tooltip: l10n.patientsQuickAppointmentTooltip,
          onPressed: () => onAction(PatientQuickAction.appointment),
          requirement: PatientActiveAtomPermissions.scheduleAppointment,
        ),
      if (hasActiveOpdEncounter && !hasActiveOpdWorkItem)
        AppPermissionActionItem(
          label: l10n.patientsQuickViewActiveOpdAction,
          icon: Icons.open_in_new_outlined,
          tooltip: l10n.patientsQuickViewActiveOpdTooltip,
          onPressed: () => onAction(PatientQuickAction.opdActions),
          requirement: PatientActiveAtomPermissions.viewActiveOpd,
        )
      else if (!hasActiveOpdEncounter &&
          !hasActiveOpdWorkItem &&
          !hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickOpdCheckInAction,
          icon: AppActionIcons.personAdd,
          tooltip: l10n.patientsQuickOpdCheckInTooltip,
          onPressed: () => onAction(PatientQuickAction.opdCheckIn),
          requirement: PatientActiveAtomPermissions.startOpd,
        ),
      if (!hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickAdmitPatientAction,
          icon: AppActionIcons.bed,
          tooltip: l10n.patientsQuickAdmitPatientTooltip,
          onPressed: () => onAction(PatientQuickAction.admission),
          requirement: PatientActiveAtomPermissions.requestAdmission,
        ),
      // Discharge / admission handoff continue solely via Active Work when that
      // panel already lists the in-flight admission.
      if (hasActiveAdmission && !hasAdmissionWorkItem)
        AppPermissionActionItem(
          label: l10n.navigationDischargeLabel,
          icon: Icons.logout_outlined,
          tooltip: l10n.patientsQuickDischargeTooltip,
          onPressed: () => onAction(PatientQuickAction.discharge),
          requirement: PatientActiveAtomPermissions.discharge,
        ),
      if (!patientHasPendingLabRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickLabOrderAction,
          icon: Icons.science_outlined,
          tooltip: l10n.patientsQuickLabOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.labOrder),
          requirement: PatientActiveAtomPermissions.labOrder,
        ),
      if (!patientHasPendingRadiologyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickRadiologyOrderAction,
          icon: Icons.monitor_heart_outlined,
          tooltip: l10n.patientsQuickRadiologyOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.radiologyOrder),
          requirement: PatientActiveAtomPermissions.radiologyOrder,
        ),
      if (!patientHasPendingTheaterCase(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickTheaterScheduleAction,
          icon: Icons.medical_services_outlined,
          tooltip: l10n.patientsQuickTheaterScheduleTooltip,
          onPressed: () => onAction(PatientQuickAction.theaterSchedule),
          requirement: PatientActiveAtomPermissions.theaterSchedule,
        ),
      if (canStartPhysiotherapy && !patientHasPendingTherapyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickPhysiotherapyAction,
          icon: Icons.self_improvement_outlined,
          tooltip: l10n.patientsQuickPhysiotherapyTooltip,
          onPressed: () => onAction(PatientQuickAction.physiotherapy),
          requirement: PatientActiveAtomPermissions.physiotherapy,
        ),
      AppPermissionActionItem(
        label: l10n.patientsEnrollInsuranceAction,
        icon: Icons.badge_outlined,
        tooltip: l10n.patientsEnrollInsuranceAction,
        onPressed: () => onAction(PatientQuickAction.enrollInsurance),
        requirement: PatientActiveAtomPermissions.enrollInsurance,
      ),
      AppPermissionActionItem(
        label: l10n.patientsQuickReportAction,
        icon: Icons.summarize_outlined,
        tooltip: l10n.patientsQuickReportTooltip,
        onPressed: () => onAction(PatientQuickAction.report),
        requirement: PatientActiveAtomPermissions.report,
      ),
    ];

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      permissionActions: actions,
    );
  }
}
