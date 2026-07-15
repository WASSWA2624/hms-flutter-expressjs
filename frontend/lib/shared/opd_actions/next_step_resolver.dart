import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Context needed to resolve a next-step navigation target.
@immutable
final class NextStepContext {
  const NextStepContext({
    required this.encounterId,
    this.patientId,
    this.stage,
    this.nextStep,
    this.displayNextStep,
    this.assignedStaffId,
    this.flow,
  });

  final String encounterId;
  final String? patientId;
  final String? stage;
  final String? nextStep;
  final String? displayNextStep;
  final String? assignedStaffId;
  final OpdFlowSummary? flow;

  String get effectiveNextStep =>
      (displayNextStep ?? nextStep ?? stage ?? '').trim().toUpperCase();
}

/// Resolved navigation target for a workflow step.
@immutable
final class NextStepTarget {
  const NextStepTarget({
    required this.label,
    required this.route,
    this.icon,
    this.tooltip,
  });

  final String label;
  final String route;
  final IconData? icon;
  final String? tooltip;
}

/// Central registry mapping step identifiers to navigation routes.
///
/// Adding a new step only requires a new entry here — no changes to individual
/// module tables.
NextStepTarget? resolveNextStepTarget(
  BuildContext context,
  NextStepContext stepContext,
) {
  final AppLocalizations l10n = context.l10n;
  final String step = stepContext.effectiveNextStep;
  final String encounterId = stepContext.encounterId;

  return switch (step) {
    'PAY_CONSULTATION' ||
    'WAITING_CONSULTATION_PAYMENT' ||
    'PAYMENT_DUE' =>
      NextStepTarget(
        label: l10n.opdPayConsultationAction,
        route: AppRoutes.billing.location(
          queryParameters: <String, String>{'encounter': encounterId},
        ),
        icon: Icons.payments_outlined,
        tooltip: _targetModuleLabel(l10n, 'billing'),
      ),
    'RECORD_VITALS' || 'WAITING_VITALS' || 'VITALS_NEEDED' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.nursing.location(
        queryParameters: <String, String>{
          'encounterId': encounterId,
          'panel': 'vitals',
        },
      ),
      icon: Icons.monitor_heart_outlined,
      tooltip: _targetModuleLabel(l10n, 'nursing'),
    ),
    'ASSIGN_DOCTOR' ||
    'WAITING_DOCTOR_ASSIGNMENT' ||
    'DOCTOR_NEEDED' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.opd.location(
          queryParameters: <String, String>{
            'flowId': encounterId,
            'panel': 'DOCTOR',
          },
        ),
        icon: Icons.assignment_ind_outlined,
        tooltip: _targetModuleLabel(l10n, 'opd'),
      ),
    'DOCTOR_REVIEW' || 'WAITING_DOCTOR_REVIEW' || 'WITH_DOCTOR' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.clinical.location(
          queryParameters: <String, String>{'encounterId': encounterId},
        ),
        icon: Icons.edit_note_outlined,
        tooltip: _targetModuleLabel(l10n, 'clinical'),
      ),
    'COLLECT_SAMPLE' ||
    'PROCESS_LAB' ||
    'LAB_WORKSPACE' ||
    'LAB_REQUESTED' ||
    'LAB_PENDING' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.lab.location(
          queryParameters: <String, String>{'encounterId': encounterId},
        ),
        icon: Icons.science_outlined,
        tooltip: _targetModuleLabel(l10n, 'laboratory'),
      ),
    'REVIEW_RESULTS' || 'RESULTS_READY' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.clinical.location(
        queryParameters: <String, String>{
          'encounterId': encounterId,
          'panel': 'results',
        },
      ),
      icon: Icons.biotech_outlined,
      tooltip: _targetModuleLabel(l10n, 'clinical'),
    ),
    'PERFORM_IMAGING' ||
    'COMPLETE_IMAGING_REPORT' ||
    'RADIOLOGY_WORKSPACE' ||
    'RADIOLOGY_REQUESTED' ||
    'IMAGING_PENDING' ||
    'REPORT_PENDING' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.radiology.location(
          queryParameters: <String, String>{'encounterId': encounterId},
        ),
        icon: Icons.image_search_outlined,
        tooltip: _targetModuleLabel(l10n, 'radiology'),
      ),
    'REVIEW_REPORT' || 'REPORT_READY' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.clinical.location(
        queryParameters: <String, String>{
          'encounterId': encounterId,
          'panel': 'imaging',
        },
      ),
      icon: Icons.image_outlined,
      tooltip: _targetModuleLabel(l10n, 'clinical'),
    ),
    'LAB_AND_RADIOLOGY_REQUESTED' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.lab.location(
        queryParameters: <String, String>{'encounterId': encounterId},
      ),
      icon: Icons.science_outlined,
      tooltip: _targetModuleLabel(l10n, 'laboratory'),
    ),
    'DIAGNOSTICS_PENDING' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.lab.location(
        queryParameters: <String, String>{'encounterId': encounterId},
      ),
      icon: Icons.science_outlined,
      tooltip: _targetModuleLabel(l10n, 'laboratory'),
    ),
    'DISPENSE_MEDICINE' ||
    'PHARMACY_WORKSPACE' ||
    'PHARMACY_REQUESTED' ||
    'PHARMACY_PENDING' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.pharmacy.location(
          queryParameters: <String, String>{'encounterId': encounterId},
        ),
        icon: Icons.medication_outlined,
        tooltip: _targetModuleLabel(l10n, 'pharmacy'),
      ),
    'MEDICINES_DISPENSED' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.clinical.location(
        queryParameters: <String, String>{'encounterId': encounterId},
      ),
      icon: Icons.task_alt_outlined,
      tooltip: _targetModuleLabel(l10n, 'clinical'),
    ),
    'DISPOSITION' ||
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' =>
      NextStepTarget(
        label: opdNextStepDisplayLabel(l10n, step),
        route: AppRoutes.clinical.location(
          queryParameters: <String, String>{
            'encounterId': encounterId,
            'panel': 'disposition',
          },
        ),
        icon: Icons.task_alt_outlined,
        tooltip: _targetModuleLabel(l10n, 'clinical'),
      ),
    'ADMISSION_HANDOFF' || 'ADMISSION_PENDING' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.ipd.location(
        queryParameters: <String, String>{'encounterId': encounterId},
      ),
      icon: Icons.bed_outlined,
      tooltip: _targetModuleLabel(l10n, 'ipd'),
    ),
    'ADMITTED' => NextStepTarget(
      label: opdNextStepDisplayLabel(l10n, step),
      route: AppRoutes.ipd.location(
        queryParameters: <String, String>{'encounterId': encounterId},
      ),
      icon: Icons.bed_outlined,
      tooltip: _targetModuleLabel(l10n, 'ipd'),
    ),
    _ => _fallbackTarget(l10n, step, encounterId),
  };
}

/// Navigate to the resolved next step target.
void navigateToNextStep(BuildContext context, NextStepTarget target) {
  GoRouter.of(context).go(target.route);
}

String _targetModuleLabel(AppLocalizations l10n, String module) {
  return switch (module) {
    'billing' => l10n.navigationBillingLabel,
    'nursing' => l10n.navigationNursingLabel,
    'opd' => l10n.navigationOpdLabel,
    'clinical' => l10n.navigationClinicalLabel,
    'laboratory' => l10n.navigationLabLabel,
    'radiology' => l10n.navigationRadiologyLabel,
    'pharmacy' => l10n.navigationPharmacyLabel,
    'ipd' => l10n.navigationIpdLabel,
    'emergency' => l10n.navigationEmergencyLabel,
    _ => module,
  };
}

NextStepTarget? _fallbackTarget(
  AppLocalizations l10n,
  String step,
  String encounterId,
) {
  if (step.isEmpty) {
    return null;
  }
  return NextStepTarget(
    label: opdNextStepDisplayLabel(l10n, step),
    route: AppRoutes.opd.location(
      queryParameters: <String, String>{'flowId': encounterId},
    ),
    icon: Icons.arrow_forward_outlined,
    tooltip: _targetModuleLabel(l10n, 'opd'),
  );
}
