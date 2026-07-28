import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_admission_handoff_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_eligibility.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_payment_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_disposition_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_next_action_key.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/opd_actions/record_vitals_dialog.dart';

export 'opd_flow_next_action_key.dart';

/// Stage-aware next-action kinds for the OPD worklist.
enum OpdBoardNextActionKind {
  checkInAppointment,
  continueAppointmentEncounter,
  payConsultation,
  recordVitals,
  assignDoctor,
  doctorReview,
  departmentHandoff,
  disposition,
  admissionHandoff,
  correctStage,
  none,
}

/// Maps a Flow Actions quick-action key to a board next-action kind.
OpdBoardNextActionKind? opdBoardNextActionKindFromActionKey(String? key) {
  return switch ((key ?? '').trim().toLowerCase()) {
    'billing' => OpdBoardNextActionKind.payConsultation,
    'vitals' => OpdBoardNextActionKind.recordVitals,
    'assign_doctor' => OpdBoardNextActionKind.assignDoctor,
    'doctor_review' => OpdBoardNextActionKind.doctorReview,
    'handoff' => OpdBoardNextActionKind.departmentHandoff,
    'disposition' => OpdBoardNextActionKind.disposition,
    'admission_handoff' => OpdBoardNextActionKind.admissionHandoff,
    'correct_stage' => OpdBoardNextActionKind.correctStage,
    _ => null,
  };
}

/// Maps a board next-action kind to the Flow Actions quick-action key.
String? opdFlowActionKeyForBoardKind(OpdBoardNextActionKind kind) {
  return switch (kind) {
    OpdBoardNextActionKind.payConsultation => 'billing',
    OpdBoardNextActionKind.recordVitals => 'vitals',
    OpdBoardNextActionKind.assignDoctor => 'assign_doctor',
    OpdBoardNextActionKind.doctorReview => 'doctor_review',
    OpdBoardNextActionKind.departmentHandoff => 'handoff',
    OpdBoardNextActionKind.disposition => 'disposition',
    OpdBoardNextActionKind.admissionHandoff => 'admission_handoff',
    OpdBoardNextActionKind.correctStage => 'correct_stage',
    OpdBoardNextActionKind.checkInAppointment ||
    OpdBoardNextActionKind.continueAppointmentEncounter ||
    OpdBoardNextActionKind.none => null,
  };
}

/// Resolves board next-action for an active OPD flow row.
OpdBoardNextActionKind opdBoardNextActionKindForFlow(
  OpdFlowSummary flow, {
  OpdFlowDetail? detail,
}) {
  if (flow.isTerminal) {
    return OpdBoardNextActionKind.none;
  }
  return opdBoardNextActionKindFromActionKey(
        resolveOpdFlowNextActionKey(flow, detail: detail),
      ) ??
      OpdBoardNextActionKind.none;
}

/// Maps `/opd?panel=` deep-link values to a focused mutation when [flowId] is set.
OpdBoardNextActionKind? opdBoardNextActionKindFromPanel(String panel) {
  final String key = panel.trim().toUpperCase();
  if (key.isEmpty) {
    return null;
  }
  return switch (key) {
    'PAYMENT' ||
    'BILLING' ||
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' => OpdBoardNextActionKind.payConsultation,
    'VITALS' ||
    'VITALS_NEEDED' ||
    'WAITING_VITALS' => OpdBoardNextActionKind.recordVitals,
    'DOCTOR' ||
    'DOCTOR_NEEDED' ||
    'ASSIGNMENT' ||
    'WAITING_DOCTOR_ASSIGNMENT' => OpdBoardNextActionKind.assignDoctor,
    'REVIEW' ||
    'WITH_DOCTOR' ||
    'WAITING_DOCTOR_REVIEW' => OpdBoardNextActionKind.doctorReview,
    'LAB' ||
    'LAB_PENDING' ||
    'LAB_REQUESTED' ||
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'IMAGING' ||
    'RADIOLOGY' ||
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' ||
    'PHARMACY' ||
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' => OpdBoardNextActionKind.departmentHandoff,
    'DISPOSITION' ||
    'DECISION' ||
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' => OpdBoardNextActionKind.disposition,
    'ADMISSION' ||
    'ADMISSION_PENDING' ||
    'ADMITTED' => OpdBoardNextActionKind.admissionHandoff,
    _ => null,
  };
}

AccessRequirement? opdBoardNextActionRequirement(OpdBoardNextActionKind kind) {
  return switch (kind) {
    OpdBoardNextActionKind.checkInAppointment ||
    OpdBoardNextActionKind.continueAppointmentEncounter =>
      opdFrontDeskActionRequirement,
    OpdBoardNextActionKind.payConsultation => opdBillingActionRequirement,
    OpdBoardNextActionKind.recordVitals => opdVitalsActionRequirement,
    OpdBoardNextActionKind.assignDoctor ||
    OpdBoardNextActionKind.departmentHandoff ||
    OpdBoardNextActionKind.correctStage => opdReceptionActionRequirement,
    OpdBoardNextActionKind.doctorReview ||
    OpdBoardNextActionKind.disposition => opdDoctorActionRequirement,
    OpdBoardNextActionKind.admissionHandoff => opdAdmissionHandoffRequirement,
    OpdBoardNextActionKind.none => null,
  };
}

String opdBoardNextActionLabel(
  BuildContext context,
  OpdBoardNextActionKind kind, {
  OpdFlowSummary? flow,
}) {
  final AppLocalizations l10n = context.l10n;
  return switch (kind) {
    OpdBoardNextActionKind.checkInAppointment => l10n.opdCheckInAction,
    OpdBoardNextActionKind.continueAppointmentEncounter =>
      l10n.opdContinueEncounterAction,
    OpdBoardNextActionKind.payConsultation => l10n.opdPayConsultationAction,
    OpdBoardNextActionKind.recordVitals => l10n.opdRecordVitalsAction,
    OpdBoardNextActionKind.assignDoctor =>
      _isNonEmpty(flow?.providerUserId)
          ? l10n.opdChangeDoctorAction
          : l10n.opdAssignDoctorAction,
    OpdBoardNextActionKind.doctorReview => l10n.opdDoctorReviewAction,
    OpdBoardNextActionKind.departmentHandoff => () {
      final String label = opdNextStepDisplayLabel(
        l10n,
        flow?.displayNextStep ?? flow?.nextStep,
      );
      return label.isNotEmpty ? label : l10n.opdNextDiagnosticsPendingLabel;
    }(),
    OpdBoardNextActionKind.disposition => clinicalDispositionActionLabel(
      l10n,
      sourceQueue: 'OPD',
      status: flow?.status,
      stage: flow?.stage,
      isOpdContext: true,
    ),
    OpdBoardNextActionKind.admissionHandoff => l10n.opdOpenAdmissionAction,
    OpdBoardNextActionKind.correctStage => l10n.opdCorrectStageAction,
    OpdBoardNextActionKind.none => l10n.profileUnknownValue,
  };
}

IconData opdBoardNextActionIcon(OpdBoardNextActionKind kind) {
  return switch (kind) {
    OpdBoardNextActionKind.checkInAppointment ||
    OpdBoardNextActionKind.continueAppointmentEncounter => Icons.login_outlined,
    OpdBoardNextActionKind.payConsultation => AppActionIcons.payment,
    OpdBoardNextActionKind.recordVitals => Icons.monitor_heart_outlined,
    OpdBoardNextActionKind.assignDoctor => AppActionIcons.assignDoctor,
    OpdBoardNextActionKind.doctorReview => Icons.edit_note_outlined,
    OpdBoardNextActionKind.departmentHandoff => Icons.science_outlined,
    OpdBoardNextActionKind.disposition => AppActionIcons.complete,
    OpdBoardNextActionKind.admissionHandoff => AppActionIcons.bed,
    OpdBoardNextActionKind.correctStage => AppActionIcons.move,
    OpdBoardNextActionKind.none => Icons.arrow_forward,
  };
}

/// Compact labeled next-action control for flow / appointment rows.
class OpdBoardNextActionCell extends ConsumerWidget {
  const OpdBoardNextActionCell({
    required this.kind,
    required this.onPressed,
    this.flow,
    this.labelOverride,
    super.key,
  });

  final OpdBoardNextActionKind kind;
  final VoidCallback onPressed;
  final OpdFlowSummary? flow;
  final String? labelOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kind == OpdBoardNextActionKind.none) {
      return const SizedBox.shrink();
    }

    final AccessRequirement? requirement = opdBoardNextActionRequirement(kind);
    final String label =
        labelOverride ??
        opdBoardNextActionLabel(context, kind, flow: flow);
    final IconData icon = opdBoardNextActionIcon(kind);
    final Widget button = _OpdCompactNextAction(
      label: label,
      icon: icon,
      onPressed: onPressed,
    );

    if (requirement == null) {
      return button;
    }
    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return button;
      },
    );
  }
}

class _OpdCompactNextAction extends StatelessWidget {
  const _OpdCompactNextAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: primaryColor),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs the OPD-owned stage mutation (or department handoff) for [flow].
Future<bool?> runOpdBoardNextAction({
  required BuildContext context,
  required WidgetRef ref,
  required OpdFlowSummary flow,
  OpdBoardNextActionKind? kind,
  OpdFlowDetail? detail,
}) async {
  final OpdBoardNextActionKind resolved =
      kind ?? opdBoardNextActionKindForFlow(flow, detail: detail);
  if (resolved == OpdBoardNextActionKind.none) {
    return null;
  }

  switch (resolved) {
    case OpdBoardNextActionKind.payConsultation:
      return showConsultationPaymentDialog(context: context, flow: flow);
    case OpdBoardNextActionKind.recordVitals:
      return showRecordVitalsDialog(
        context: context,
        flow: flow,
        detail: detail,
      );
    case OpdBoardNextActionKind.assignDoctor:
      return showAssignDoctorDialog(context: context, flow: flow);
    case OpdBoardNextActionKind.doctorReview:
      return _openDoctorReviewDialog(context, ref, flow, detail: detail);
    case OpdBoardNextActionKind.departmentHandoff:
      _navigateToDepartmentHandoff(context, flow);
      return true;
    case OpdBoardNextActionKind.disposition:
      return showOpdDispositionDialog(
        context: context,
        flow: flow,
        hasPharmacyOrder:
            detail?.pharmacyOrders.isNotEmpty ??
            (flow.stage ?? '').toUpperCase() == 'PHARMACY_REQUESTED',
      );
    case OpdBoardNextActionKind.admissionHandoff:
      final bool? openIpd = await showOpdAdmissionHandoffDialog(
        context: context,
        flow: flow,
      );
      if (openIpd == true && context.mounted) {
        _navigateToIpdHandoff(context, flow, detail);
        return true;
      }
      return openIpd;
    case OpdBoardNextActionKind.correctStage:
      return showCorrectStageDialog(context: context, flow: flow);
    case OpdBoardNextActionKind.checkInAppointment ||
        OpdBoardNextActionKind.continueAppointmentEncounter ||
        OpdBoardNextActionKind.none:
      return null;
  }
}

/// Opens appointment check-in or continue-encounter without an empty hub shell.
Future<bool?> runOpdAppointmentNextAction({
  required BuildContext context,
  required WidgetRef ref,
  required OpdAppointment appointment,
  required OpdWorkspaceState state,
  OpdAppointmentPrimaryAction? primaryAction,
}) async {
  final OpdFlowSummary? linkedFlow = findActiveOpdFlowForAppointment(
    appointment: appointment,
    flows: <OpdFlowSummary>[...state.flows.items, ...state.triageQueue.items],
  );
  final OpdAppointmentPrimaryAction resolved =
      primaryAction ??
      resolveOpdAppointmentPrimaryAction(
        appointment: appointment,
        linkedFlow: linkedFlow,
      );

  if (resolved == OpdAppointmentPrimaryAction.continueEncounter &&
      linkedFlow != null) {
    final String omitKey = resolveOpdFlowNextActionKey(linkedFlow);
    return showFlowActionsDialog(
      context: context,
      flow: linkedFlow,
      omitNextActionKey: omitKey,
    );
  }

  if (resolved != OpdAppointmentPrimaryAction.startEncounter) {
    return null;
  }

  OpdFlowSummary? activeEncounterToOpen;
  final OpdEncounterDialogResult? dialogResult = await showOpdEncounterDialog(
    context: context,
    dialog: buildOpdWorkspaceEncounterDialog(
      ref: ref,
      state: state,
      initialAppointment: appointment,
      initialAppointmentId: appointment.apiId,
      defaultArrivalMode: 'ONLINE_APPOINTMENT',
      defaultProviderId: appointment.providerUserId,
      includeEncounterLifecycleCallbacks: false,
      onExistingActiveEncounter: (OpdFlowSummary flow) {
        activeEncounterToOpen = flow;
      },
    ),
  );
  if (!context.mounted || dialogResult == null) {
    return null;
  }

  final OpdFlowSummary? activeEncounter =
      dialogResult.action == OpdEncounterDialogAction.continueWorkflow
      ? dialogResult.flow
      : activeEncounterToOpen;
  if (activeEncounter == null) {
    return true;
  }
  final String omitKey = resolveOpdFlowNextActionKey(activeEncounter);
  return showFlowActionsDialog(
    context: context,
    flow: activeEncounter,
    omitNextActionKey: omitKey,
  );
}

Future<bool?> _openDoctorReviewDialog(
  BuildContext context,
  WidgetRef ref,
  OpdFlowSummary flow, {
  OpdFlowDetail? detail,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalFreeTextActionDialog(
      title: l10n.opdDoctorReviewAction,
      label: l10n.opdFieldRequiredLabel(l10n.opdClinicalNoteLabel),
      submitLabel: l10n.opdDoctorReviewAction,
      minLines: 3,
      maxLines: 4,
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: flow, showTitle: false),
      ],
      onSubmit: (String note) {
        return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
          flow,
          <String, Object?>{'note': note},
        );
      },
    ),
  );
}

void _navigateToDepartmentHandoff(BuildContext context, OpdFlowSummary flow) {
  final String encounterTarget = flow.apiId.trim();
  final String stage = (flow.stage ?? '').trim().toUpperCase();
  final Map<String, String> queryParameters = encounterTarget.isEmpty
      ? const <String, String>{}
      : <String, String>{'encounterId': encounterTarget};
  final String location = switch (stage) {
    'RADIOLOGY_REQUESTED' || 'IMAGING_PENDING' || 'REPORT_PENDING' =>
      AppRoutes.radiology.location(queryParameters: queryParameters),
    'PHARMACY_REQUESTED' || 'PHARMACY_PENDING' => AppRoutes.pharmacy.location(
      queryParameters: queryParameters,
    ),
    _ => AppRoutes.lab.location(queryParameters: queryParameters),
  };
  context.go(location);
}

void _navigateToIpdHandoff(
  BuildContext context,
  OpdFlowSummary flow,
  OpdFlowDetail? detail,
) {
  final String target = _admissionHandoffTarget(flow, detail);
  context.go(
    AppRoutes.ipd.location(
      queryParameters: target.isEmpty
          ? const <String, String>{}
          : <String, String>{'admission': target},
    ),
  );
}

String _admissionHandoffTarget(OpdFlowSummary flow, OpdFlowDetail? detail) {
  final List<OpdRelatedRecord> admissions =
      detail?.admissions ?? const <OpdRelatedRecord>[];
  for (final OpdRelatedRecord record in admissions) {
    final String status = (record.status ?? '').trim().toUpperCase();
    if (status == 'DISCHARGED' || status == 'CANCELLED') {
      continue;
    }
    if (record.id.trim().isNotEmpty) {
      return record.id.trim();
    }
  }
  for (final OpdRelatedRecord record in admissions) {
    if (record.id.trim().isNotEmpty) {
      return record.id.trim();
    }
  }
  return flow.patientIdentifier?.trim() ?? '';
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}
