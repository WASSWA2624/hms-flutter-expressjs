import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
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
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Patient patient = detail.patient;
    final PatientVisitContext? visit = patient.currentVisit;
    final bool hasActiveOpdEncounter = isActiveOpdPatientVisit(visit);
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
          onPressed: () => onAction(PatientQuickAction.appointment),
          requirement: const AccessRequirement(
            allPermissions: <AppPermission>[AppPermissions.patientWrite],
          ),
        ),
      if (hasActiveOpdEncounter)
        AppPermissionActionItem(
          label: l10n.patientsQuickViewActiveOpdAction,
          icon: Icons.open_in_new_outlined,
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
      else
        AppPermissionActionItem(
          label: l10n.patientsQuickOpdCheckInAction,
          icon: opdEncounterIcon,
          onPressed: () => onAction(PatientQuickAction.opdCheckIn),
          requirement: opdEncounterPermissionRequirement,
        ),
      if (!hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickAdmitPatientAction,
          icon: Icons.local_hospital_outlined,
          onPressed: () => onAction(PatientQuickAction.admission),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['inpatient-bed-management'],
          ),
        ),
      if (hasActiveAdmission)
        AppPermissionActionItem(
          label: dischargeActionLabel,
          icon: Icons.logout_outlined,
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
          onPressed: () => onAction(PatientQuickAction.physiotherapy),
          requirement: const AccessRequirement(
            anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
            activeModules: <String>['physiotherapy'],
          ),
        ),
      AppPermissionActionItem(
        label: l10n.patientsQuickReportAction,
        icon: Icons.summarize_outlined,
        onPressed: () => onAction(PatientQuickAction.report),
        requirement: const AccessRequirement(
          allPermissions: <AppPermission>[AppPermissions.reportsRead],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.patientsQuickActionsTitle, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        AppPermissionActionList(actions: actions),
      ],
    );
  }
}
