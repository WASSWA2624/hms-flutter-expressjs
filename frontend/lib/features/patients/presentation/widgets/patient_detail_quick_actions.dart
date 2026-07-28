import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_disposition_actions.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

enum PatientQuickAction {
  appointment,
  triage,
  billing,
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
    final List<PatientActiveWorkItem> activeWorkItems =
        collectPatientActiveWorkItems(detail);
    final bool hasActiveOpdEncounter = isActiveOpdPatientVisit(visit);
    final bool hasActiveOpdWorkItem = activeWorkItems.any(
      (PatientActiveWorkItem item) =>
          item.kind == PatientActiveWorkKind.encounter ||
          item.kind == PatientActiveWorkKind.queue,
    );
    final bool hasActiveWorkAdmission = activeWorkItems.any(
      (PatientActiveWorkItem item) =>
          item.kind == PatientActiveWorkKind.admission,
    );
    final PatientSummaryRecord? activeAdmission = activePatientAdmissionRecord(
      detail.workspace.admissions,
    );
    final PatientVisitContext? activeAdmissionVisit =
        isActiveAdmissionPatientVisit(visit) ? visit : null;
    final bool hasActiveAdmission =
        activeAdmission != null || activeAdmissionVisit != null;
    final bool hasOpenAppointment = patientHasOpenAppointment(detail);
    final String dischargeActionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: 'IPD',
      status: activeAdmission?.status ?? activeAdmissionVisit?.status,
      stage: activeAdmission?.status ?? activeAdmissionVisit?.status,
      location: activeAdmission?.subtitle ?? activeAdmissionVisit?.title,
      hasAdmission: hasActiveAdmission,
    );

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (!hasOpenAppointment)
        AppPermissionActionItem(
          label: l10n.patientsQuickAppointmentAction,
          icon: Icons.event_available_outlined,
          tooltip: l10n.patientsQuickAppointmentTooltip,
          onPressed: () => onAction(PatientQuickAction.appointment),
          requirement: const AccessRequirement(
            allPermissions: <AppPermission>[AppPermissions.patientWrite],
          ),
        ),
      if (!hasActiveOpdEncounter && !hasActiveOpdWorkItem)
        AppPermissionActionItem(
          label: l10n.patientsQuickTriageAction,
          icon: Icons.monitor_heart_outlined,
          tooltip: l10n.patientsTriageDialogTitle,
          onPressed: () => onAction(PatientQuickAction.triage),
          requirement: opdEncounterPermissionRequirement,
        ),
      if (!hasActiveOpdEncounter && !hasActiveOpdWorkItem)
        AppPermissionActionItem(
          label: l10n.patientsQuickBillingAction,
          icon: AppActionIcons.payment,
          tooltip: l10n.patientsBillingDialogTitle,
          onPressed: () => onAction(PatientQuickAction.billing),
          requirement: opdEncounterPermissionRequirement,
        ),
      if (hasActiveOpdEncounter && !hasActiveOpdWorkItem)
        AppPermissionActionItem(
          label: l10n.patientsQuickViewActiveOpdAction,
          icon: Icons.open_in_new_outlined,
          tooltip: l10n.patientsQuickViewActiveOpdTooltip,
          onPressed: () => onAction(PatientQuickAction.opdActions),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            ],
          ),
        )
      else if (!hasActiveOpdEncounter &&
          !hasActiveOpdWorkItem &&
          !hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickOpdCheckInAction,
          icon: opdEncounterIcon,
          tooltip: l10n.patientsQuickOpdCheckInTooltip,
          onPressed: () => onAction(PatientQuickAction.opdCheckIn),
          requirement: opdEncounterPermissionRequirement,
        ),
      if (!hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickAdmitPatientAction,
          icon: AppActionIcons.bed,
          tooltip: l10n.patientsQuickAdmitPatientTooltip,
          onPressed: () => onAction(PatientQuickAction.admission),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['inpatient-bed-management'],
          ),
        ),
      // Active work Continue is the sole discharge entry when an admission
      // work item is already listed; keep the chip only for visit-only cases.
      if (hasActiveAdmission && !hasActiveWorkAdmission)
        AppPermissionActionItem(
          label: dischargeActionLabel,
          icon: Icons.logout_outlined,
          tooltip: l10n.patientsQuickDischargeTooltip,
          onPressed: () => onAction(PatientQuickAction.discharge),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['inpatient-bed-management'],
          ),
        ),
      if (!patientHasPendingLabRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickLabOrderAction,
          icon: Icons.science_outlined,
          tooltip: l10n.patientsQuickLabOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.labOrder),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['lab'],
          ),
        ),
      if (!patientHasPendingRadiologyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickRadiologyOrderAction,
          icon: Icons.monitor_heart_outlined,
          tooltip: l10n.patientsQuickRadiologyOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.radiologyOrder),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['radiology'],
          ),
        ),
      if (!patientHasPendingTheaterCase(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickTheaterScheduleAction,
          icon: Icons.medical_services_outlined,
          tooltip: l10n.patientsQuickTheaterScheduleTooltip,
          onPressed: () => onAction(PatientQuickAction.theaterSchedule),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['theater'],
          ),
        ),
      if (!patientHasPendingTherapyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickPhysiotherapyAction,
          icon: Icons.self_improvement_outlined,
          tooltip: l10n.patientsQuickPhysiotherapyTooltip,
          onPressed: () => onAction(PatientQuickAction.physiotherapy),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['physiotherapy'],
          ),
        ),
      AppPermissionActionItem(
        label: l10n.patientsEnrollInsuranceAction,
        icon: Icons.badge_outlined,
        tooltip: l10n.patientsEnrollInsuranceAction,
        onPressed: () => onAction(PatientQuickAction.enrollInsurance),
        requirement: const AccessRequirement(
          anyPermissions: <AppPermission>[
            AppPermissions.patientWrite,
            AppPermissions.billingWrite,
            AppPermissions.clinicalWrite,
          ],
          activeModules: <String>['insurance-claims'],
        ),
      ),
      AppPermissionActionItem(
        label: l10n.patientsQuickReportAction,
        icon: Icons.summarize_outlined,
        tooltip: l10n.patientsQuickReportTooltip,
        onPressed: () => onAction(PatientQuickAction.report),
        requirement: const AccessRequirement(
          allPermissions: <AppPermission>[AppPermissions.reportsRead],
        ),
      ),
    ];

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      permissionActions: actions,
    );
  }
}
