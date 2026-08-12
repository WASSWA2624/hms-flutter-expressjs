import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_admission_reference_data.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_nursing_note_dialog.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_transfer_request_dialog.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_transfer_update_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

/// Stage-aware next-action kinds for the IPD admission worklist.
enum IpdBoardNextActionKind {
  approveAdmission,
  assignBed,
  manageTransfer,
  requestTransfer,
  recordNursingNote,
  planOrManageDischarge,
  completeTheatreHandover,
  continueCare,
}

IpdBoardNextActionKind ipdBoardNextActionKind(IpdAdmissionSummary admission) {
  final String step = (admission.nextStep ?? '').toUpperCase();
  switch (step) {
    case 'ASSIGN_BED':
      return IpdBoardNextActionKind.assignBed;
    case 'RECORD_NURSING_NOTE':
      return IpdBoardNextActionKind.recordNursingNote;
    case 'APPROVE_TRANSFER':
    case 'START_TRANSFER':
    case 'COMPLETE_TRANSFER':
      return IpdBoardNextActionKind.manageTransfer;
    case 'COMPLETE_THEATRE_HANDOVER':
      return IpdBoardNextActionKind.completeTheatreHandover;
    case 'FINALIZE_DISCHARGE':
      return IpdBoardNextActionKind.planOrManageDischarge;
    case 'APPROVE_ADMISSION':
      return IpdBoardNextActionKind.approveAdmission;
  }

  return switch ((admission.stage ?? '').toUpperCase()) {
    'ADMISSION_REQUESTED' => IpdBoardNextActionKind.approveAdmission,
    'ADMITTED_PENDING_BED' => IpdBoardNextActionKind.assignBed,
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' => IpdBoardNextActionKind.manageTransfer,
    'DISCHARGE_PLANNED' => IpdBoardNextActionKind.planOrManageDischarge,
    _ => IpdBoardNextActionKind.continueCare,
  };
}

AccessRequirement? ipdBoardNextActionRequirement(IpdBoardNextActionKind kind) {
  return switch (kind) {
    IpdBoardNextActionKind.approveAdmission ||
    IpdBoardNextActionKind.assignBed ||
    IpdBoardNextActionKind.manageTransfer ||
    IpdBoardNextActionKind.requestTransfer => ipdOperationalWriteRequirement,
    IpdBoardNextActionKind.recordNursingNote ||
    IpdBoardNextActionKind.planOrManageDischarge => ipdClinicalWriteRequirement,
    IpdBoardNextActionKind.completeTheatreHandover => null,
    IpdBoardNextActionKind.continueCare => null,
  };
}

String ipdBoardNextActionLabel(
  BuildContext context,
  IpdAdmissionSummary admission,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (ipdBoardNextActionKind(admission)) {
    IpdBoardNextActionKind.approveAdmission => l10n.ipdApproveAdmissionAction,
    IpdBoardNextActionKind.assignBed => l10n.ipdAssignBedAction,
    IpdBoardNextActionKind.manageTransfer => l10n.ipdManageTransferAction,
    IpdBoardNextActionKind.requestTransfer => l10n.ipdRequestTransferAction,
    IpdBoardNextActionKind.recordNursingNote => l10n.ipdAddNursingNoteAction,
    IpdBoardNextActionKind.planOrManageDischarge =>
      (admission.stage ?? '').toUpperCase() == 'DISCHARGE_PLANNED'
          ? l10n.ipdManageDischargeTitle
          : l10n.ipdPlanDischargeAction,
    IpdBoardNextActionKind.completeTheatreHandover =>
      l10n.ipdNextCompleteTheatreHandover,
    IpdBoardNextActionKind.continueCare => l10n.ipdNextContinueCare,
  };
}

IconData ipdBoardNextActionIcon(IpdAdmissionSummary admission) {
  return switch (ipdBoardNextActionKind(admission)) {
    IpdBoardNextActionKind.approveAdmission => Icons.check_circle_outline,
    IpdBoardNextActionKind.assignBed => Icons.bed_outlined,
    IpdBoardNextActionKind.manageTransfer ||
    IpdBoardNextActionKind.requestTransfer => Icons.swap_horiz,
    IpdBoardNextActionKind.recordNursingNote => Icons.note_add_outlined,
    IpdBoardNextActionKind.planOrManageDischarge => Icons.fact_check_outlined,
    IpdBoardNextActionKind.completeTheatreHandover => Icons.event_note_outlined,
    IpdBoardNextActionKind.continueCare => Icons.arrow_forward,
  };
}

/// Compact labeled next-action control for the admission worklist.
class IpdBoardNextActionCell extends ConsumerWidget {
  const IpdBoardNextActionCell({
    required this.admission,
    required this.state,
    super.key,
  });

  final IpdAdmissionSummary admission;
  final IpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IpdBoardNextActionKind kind = ipdBoardNextActionKind(admission);
    if (kind == IpdBoardNextActionKind.continueCare) {
      return Text(
        ipdBoardNextActionLabel(context, admission),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final AccessRequirement? requirement = ipdBoardNextActionRequirement(kind);
    final String label = ipdBoardNextActionLabel(context, admission);
    final IconData icon = ipdBoardNextActionIcon(admission);
    final Widget button = _IpdCompactNextAction(
      label: label,
      icon: icon,
      onPressed: () => unawaited(
        runIpdBoardNextAction(
          context,
          ref,
          state: state,
          admission: admission,
          kind: kind,
        ),
      ),
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

class _IpdCompactNextAction extends StatelessWidget {
  const _IpdCompactNextAction({
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

Future<void> runIpdBoardNextAction(
  BuildContext context,
  WidgetRef ref, {
  required IpdWorkspaceState state,
  required IpdAdmissionSummary admission,
  IpdBoardNextActionKind? kind,
}) async {
  final IpdBoardNextActionKind resolved =
      kind ?? ipdBoardNextActionKind(admission);
  if (resolved == IpdBoardNextActionKind.continueCare) {
    return;
  }
  if (resolved == IpdBoardNextActionKind.completeTheatreHandover) {
    _openTheaterWorkspace(context, admission);
    return;
  }

  final IpdWorkspaceController controller = ref.read(
    ipdWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmission(admission);
  if (context.mounted) {
    showAppFailureSnackBar(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IpdWorkspaceState? latest = _readIpdState(ref);
  final IpdAdmissionDetail? detail = latest?.selectedAdmission;
  if (detail == null || latest == null) {
    return;
  }

  final bool? saved = await switch (resolved) {
    IpdBoardNextActionKind.approveAdmission => _confirmApproveAdmission(
      context,
      ref,
      detail.summary,
    ),
    IpdBoardNextActionKind.assignBed => _openAssignBedDialog(
      context,
      ref,
      detail: detail,
      referenceData: latest.referenceData,
    ),
    IpdBoardNextActionKind.manageTransfer => _openTransferUpdateDialog(
      context,
      detail: detail,
      beds: latest.referenceData.availableBeds,
    ),
    IpdBoardNextActionKind.requestTransfer => _openTransferRequestDialog(
      context,
      detail: detail,
      wards: latest.referenceData.wards,
    ),
    IpdBoardNextActionKind.recordNursingNote => _openNursingNoteDialog(
      context,
      ref,
      detail.summary,
    ),
    IpdBoardNextActionKind.planOrManageDischarge =>
      _openDischargePlanningForAdmission(context, ref, detail),
    IpdBoardNextActionKind.completeTheatreHandover ||
    IpdBoardNextActionKind.continueCare => Future<bool?>.value(),
  };

  if (saved == true && context.mounted) {
    _showIpdSaved(context);
  }
}

/// Opens a deep-linked mutation dialog without an empty detail shell.
///
/// Returns `false` when the caller should open admission detail instead
/// (unknown / secondary panels such as medication or rounds).
Future<bool> runIpdFocusedMutation(
  BuildContext context,
  WidgetRef ref, {
  required IpdWorkspaceState fallbackState,
  required String admissionId,
  IpdDetailPanel? panel,
  String? action,
}) async {
  final AccessRequirement? mutationRequirement = ipdFocusedMutationRequirement(
    panel: panel,
    action: action,
  );
  if (mutationRequirement != null) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!mutationRequirement.isAllowed(policy)) {
      return true;
    }
  }

  final IpdWorkspaceController controller = ref.read(
    ipdWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmissionById(admissionId);
  if (context.mounted) {
    showAppFailureSnackBar(context, failure);
  }
  if (failure != null || !context.mounted) {
    return true;
  }

  final IpdWorkspaceState state = _readIpdState(ref) ?? fallbackState;
  final IpdAdmissionDetail? detail = state.selectedAdmission;
  if (detail == null) {
    return true;
  }

  final String normalizedAction = (action ?? '').trim().toLowerCase();
  if (normalizedAction == 'approve' &&
      (detail.summary.stage ?? '').toUpperCase() == 'ADMISSION_REQUESTED') {
    final bool? saved = await _confirmApproveAdmission(
      context,
      ref,
      detail.summary,
    );
    if (saved == true && context.mounted) {
      _showIpdSaved(context);
    }
    return true;
  }

  final IpdBoardNextActionKind? fromPanel = switch (panel) {
    IpdDetailPanel.beds => IpdBoardNextActionKind.assignBed,
    IpdDetailPanel.transfer => detail.openTransferRequest != null
        ? IpdBoardNextActionKind.manageTransfer
        : IpdBoardNextActionKind.requestTransfer,
    IpdDetailPanel.discharge => IpdBoardNextActionKind.planOrManageDischarge,
    IpdDetailPanel.nursing => IpdBoardNextActionKind.recordNursingNote,
    IpdDetailPanel.medication ||
    IpdDetailPanel.rounds ||
    null => null,
  };

  if (fromPanel == null) {
    return false;
  }

  final bool? saved = await switch (fromPanel) {
    IpdBoardNextActionKind.approveAdmission => _confirmApproveAdmission(
      context,
      ref,
      detail.summary,
    ),
    IpdBoardNextActionKind.assignBed => _openAssignBedDialog(
      context,
      ref,
      detail: detail,
      referenceData: state.referenceData,
    ),
    IpdBoardNextActionKind.manageTransfer => _openTransferUpdateDialog(
      context,
      detail: detail,
      beds: state.referenceData.availableBeds,
    ),
    IpdBoardNextActionKind.requestTransfer => _openTransferRequestDialog(
      context,
      detail: detail,
      wards: state.referenceData.wards,
    ),
    IpdBoardNextActionKind.recordNursingNote => _openNursingNoteDialog(
      context,
      ref,
      detail.summary,
    ),
    IpdBoardNextActionKind.planOrManageDischarge =>
      _openDischargePlanningForAdmission(context, ref, detail),
    IpdBoardNextActionKind.completeTheatreHandover ||
    IpdBoardNextActionKind.continueCare => Future<bool?>.value(),
  };

  if (saved == true && context.mounted) {
    _showIpdSaved(context);
  }
  return true;
}

IpdWorkspaceState? _readIpdState(WidgetRef ref) {
  return ref
      .read(ipdWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (IpdWorkspaceState state) => state, failure: (_) => null);
}

void _openTheaterWorkspace(BuildContext context, IpdAdmissionSummary summary) {
  final String? caseId = summary.activeTheatreCaseId?.trim();
  final String location = caseId == null || caseId.isEmpty
      ? AppRoutes.theater.path
      : AppRoutes.theater.location(
          queryParameters: <String, String>{'id': caseId},
        );
  context.go(location);
}

Future<bool?> _confirmApproveAdmission(
  BuildContext context,
  WidgetRef ref,
  IpdAdmissionSummary summary,
) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: l10n.ipdApproveAdmissionAction,
      body: l10n.ipdApproveAdmissionBody,
      submitLabel: l10n.ipdApproveAdmissionAction,
      icon: const Icon(Icons.check_circle_outline),
      onConfirm: () => ref
          .read(ipdWorkspaceControllerProvider.notifier)
          .approveAdmission(summary),
    ),
  );
}

Future<bool?> _openAssignBedDialog(
  BuildContext context,
  WidgetRef ref, {
  required IpdAdmissionDetail detail,
  required IpdReferenceData referenceData,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalAdmissionActionDialog(
      title: l10n.ipdAssignBedAction,
      submitLabel: l10n.ipdAssignBedAction,
      referenceData: ipdAdmissionReferenceData(context, referenceData),
      onSubmit: (ClinicalActionAdmissionInput input) {
        final ClinicalActionCatalogOption? bed = input.bed;
        if (bed == null) {
          return Future<AppFailure?>.value(AppFailure.validation());
        }
        return ref
            .read(ipdWorkspaceControllerProvider.notifier)
            .assignBed(detail.summary, bed.apiId);
      },
    ),
  );
}

Future<bool?> _openTransferUpdateDialog(
  BuildContext context, {
  required IpdAdmissionDetail detail,
  required List<IpdBedOption> beds,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TransferUpdateDialog(admission: detail, beds: beds),
  );
}

Future<bool?> _openTransferRequestDialog(
  BuildContext context, {
  required IpdAdmissionDetail detail,
  required List<IpdWardOption> wards,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TransferRequestDialog(admission: detail, wards: wards),
  );
}

Future<bool?> _openNursingNoteDialog(
  BuildContext context,
  WidgetRef ref,
  IpdAdmissionSummary summary,
) {
  return showIpdNursingNoteDialog(context, summary: summary);
}

Future<bool?> _openDischargePlanningForAdmission(
  BuildContext context,
  WidgetRef ref,
  IpdAdmissionDetail admission,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool dischargePlanned =
      (admission.latestDischargeSummary?.status ?? '').toUpperCase() ==
      'PLANNED';
  final bool? saved = await showDischargePlanningDialog(
    context: context,
    ref: ref,
    admissionId: admission.summary.apiId,
    title: Text(
      dischargePlanned
          ? l10n.ipdManageDischargeTitle
          : l10n.ipdPlanDischargeAction,
    ),
    onFailure: (AppFailure failure) => showAppFailureSnackBar(context, failure),
  );
  if (saved == true) {
    await ref.read(ipdWorkspaceControllerProvider.notifier).refresh();
  }
  return saved;
}

void _showIpdSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.ipdSavedMessage)));
}
