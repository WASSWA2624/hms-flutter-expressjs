import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
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

typedef PatientQuickActiveWorkHandler =
    Future<void> Function(PatientActiveWorkItem item);

class PatientDetailQuickActions extends ConsumerWidget {
  const PatientDetailQuickActions({
    required this.detail,
    required this.onAction,
    required this.onContinueActiveWork,
    this.registrySection,
    this.applyAdmittedNestedReadFilter = false,
    super.key,
  });

  final PatientDetail detail;
  final PatientQuickActionHandler onAction;

  /// Continues in-flight work (appointment, diagnostics, theatre, therapy)
  /// that has no dedicated [PatientQuickAction].
  final PatientQuickActiveWorkHandler onContinueActiveWork;
  final PatientRegistrySection? registrySection;

  /// When true (Admitted tab detail), strips clinical/billing continue actions
  /// unless the Admitted nested-read grant is present.
  final bool applyAdmittedNestedReadFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Patient patient = detail.patient;
    final PatientVisitContext? visit = patient.currentVisit;
    final bool hasActiveOpdEncounter = isActiveOpdPatientVisit(visit);
    List<PatientActiveWorkItem> activeWork = collectPatientActiveWorkItems(
      detail,
    );
    if (applyAdmittedNestedReadFilter) {
      activeWork = filterPatientActiveWorkForAdmittedNestedRead(
        activeWork,
        ref.watch(appAccessPolicyProvider),
      );
    }
    final bool hasActiveOpdWorkItem = activeWork.any(
      (PatientActiveWorkItem item) =>
          item.kind == PatientActiveWorkKind.encounter ||
          item.kind == PatientActiveWorkKind.queue,
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
    final PatientActiveWorkItem? appointmentWork = _firstWorkOfKind(
      activeWork,
      PatientActiveWorkKind.appointment,
    );
    final List<PatientActiveWorkItem> departmentWork = activeWork
        .where(
          (PatientActiveWorkItem item) =>
              _departmentWorkKinds.contains(item.kind),
        )
        .toList(growable: false);

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (!hasOpenAppointment)
        AppPermissionActionItem(
          label: l10n.patientsQuickAppointmentAction,
          icon: Icons.event_available_outlined,
          tooltip: l10n.patientsQuickAppointmentTooltip,
          onPressed: () => onAction(PatientQuickAction.appointment),
          requirement: patientRegistryScheduleAppointmentAtom(registrySection),
        )
      else if (appointmentWork != null)
        AppPermissionActionItem(
          label: l10n.patientsActiveWorkManageAppointmentAction,
          icon: Icons.edit_calendar_outlined,
          tooltip: l10n.patientsActiveWorkManageAppointmentAction,
          onPressed: () => onContinueActiveWork(appointmentWork),
          requirement: patientActiveWorkContinueRequirement(
            PatientActiveWorkKind.appointment,
          ),
        ),
      if (hasActiveOpdEncounter || hasActiveOpdWorkItem)
        AppPermissionActionItem(
          label: l10n.patientsActiveWorkOpenOpdAction,
          icon: Icons.open_in_new_outlined,
          tooltip: l10n.patientsQuickViewActiveOpdTooltip,
          onPressed: () => onAction(PatientQuickAction.opdActions),
          requirement: patientRegistryViewActiveOpdAtom(registrySection),
        )
      else if (!hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickOpdCheckInAction,
          icon: AppActionIcons.personAdd,
          tooltip: l10n.patientsQuickOpdCheckInTooltip,
          onPressed: () => onAction(PatientQuickAction.opdCheckIn),
          requirement: patientRegistryStartOpdAtom(registrySection),
        ),
      if (!hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.patientsQuickAdmitPatientAction,
          icon: AppActionIcons.bed,
          tooltip: l10n.patientsQuickAdmitPatientTooltip,
          onPressed: () => onAction(PatientQuickAction.admission),
          requirement: patientRegistryRequestAdmissionAtom(registrySection),
        ),
      if (hasActiveAdmission)
        AppPermissionActionItem(
          label: l10n.navigationDischargeLabel,
          icon: Icons.logout_outlined,
          tooltip: l10n.patientsQuickDischargeTooltip,
          onPressed: () => onAction(PatientQuickAction.discharge),
          requirement: patientRegistryDischargeAtom(registrySection),
        ),
      if (!patientHasPendingLabRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickLabOrderAction,
          icon: Icons.science_outlined,
          tooltip: l10n.patientsQuickLabOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.labOrder),
          requirement: patientRegistryLabOrderAtom(registrySection),
        ),
      if (!patientHasPendingRadiologyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickRadiologyOrderAction,
          icon: Icons.monitor_heart_outlined,
          tooltip: l10n.patientsQuickRadiologyOrderTooltip,
          onPressed: () => onAction(PatientQuickAction.radiologyOrder),
          requirement: patientRegistryRadiologyOrderAtom(registrySection),
        ),
      if (!patientHasPendingTheaterCase(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickTheaterScheduleAction,
          icon: Icons.medical_services_outlined,
          tooltip: l10n.patientsQuickTheaterScheduleTooltip,
          onPressed: () => onAction(PatientQuickAction.theaterSchedule),
          requirement: patientRegistryTheaterScheduleAtom(registrySection),
        ),
      if (canStartPhysiotherapy && !patientHasPendingTherapyRequest(detail))
        AppPermissionActionItem(
          label: l10n.patientsQuickPhysiotherapyAction,
          icon: Icons.self_improvement_outlined,
          tooltip: l10n.patientsQuickPhysiotherapyTooltip,
          onPressed: () => onAction(PatientQuickAction.physiotherapy),
          requirement: patientRegistryPhysiotherapyAtom(registrySection),
        ),
      AppPermissionActionItem(
        label: l10n.patientsEnrollInsuranceAction,
        icon: Icons.badge_outlined,
        tooltip: l10n.patientsEnrollInsuranceAction,
        onPressed: () => onAction(PatientQuickAction.enrollInsurance),
        requirement: patientRegistryEnrollInsuranceAtom(registrySection),
      ),
      AppPermissionActionItem(
        label: l10n.patientsQuickReportAction,
        icon: Icons.summarize_outlined,
        tooltip: l10n.patientsQuickReportTooltip,
        onPressed: () => onAction(PatientQuickAction.report),
        requirement: patientRegistryReportAtom(registrySection),
      ),
      for (final PatientActiveWorkItem item in departmentWork)
        AppPermissionActionItem(
          label: patientActiveWorkActionLabel(l10n, item),
          icon: _departmentWorkIcon(item.kind),
          tooltip: patientActiveWorkNextStepLabel(l10n, item),
          onPressed: () => onContinueActiveWork(item),
          requirement: patientActiveWorkContinueRequirement(item.kind),
        ),
    ];

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      permissionActions: actions,
    );
  }
}

const Set<PatientActiveWorkKind> _departmentWorkKinds = <PatientActiveWorkKind>{
  PatientActiveWorkKind.labOrder,
  PatientActiveWorkKind.radiologyOrder,
  PatientActiveWorkKind.theater,
  PatientActiveWorkKind.therapy,
};

PatientActiveWorkItem? _firstWorkOfKind(
  List<PatientActiveWorkItem> items,
  PatientActiveWorkKind kind,
) {
  for (final PatientActiveWorkItem item in items) {
    if (item.kind == kind) {
      return item;
    }
  }
  return null;
}

IconData _departmentWorkIcon(PatientActiveWorkKind kind) {
  return switch (kind) {
    PatientActiveWorkKind.labOrder => Icons.science_outlined,
    PatientActiveWorkKind.radiologyOrder => Icons.monitor_heart_outlined,
    PatientActiveWorkKind.theater => Icons.medical_services_outlined,
    PatientActiveWorkKind.therapy => Icons.self_improvement_outlined,
    _ => Icons.play_arrow_outlined,
  };
}
