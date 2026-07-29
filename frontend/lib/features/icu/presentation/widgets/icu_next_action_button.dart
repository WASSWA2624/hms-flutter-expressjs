import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

/// Stage-aware primary board action for an ICU row.
///
/// When a registered workflow [IcuPatientSummary.nextStep] owns the row, this
/// is null so detail Quick Actions keep complementary writes.
enum IcuNextActionKind {
  startStay,
  acknowledgeAlert,
  manageTransfer,
  requestTransfer,
  openDischargeClearance,
  markReadiness,
  assignBed,
  openIpd,
  recordObservation,
}

IcuNextActionKind? icuBoardNextActionKind(
  IcuPatientSummary summary,
  IcuWorkspaceSection section,
) {
  final String? nextStep = summary.nextStep?.trim();
  if (nextStep != null &&
      nextStep.isNotEmpty &&
      WorkflowActionRegistry.instance.isRegistered(nextStep)) {
    return null;
  }
  return _resolveIcuNextAction(summary, section);
}

String icuNextActionLabel(AppLocalizations l10n, IcuNextActionKind action) {
  return switch (action) {
    IcuNextActionKind.startStay => l10n.icuActionStartStay,
    IcuNextActionKind.acknowledgeAlert => l10n.icuActionAcknowledgeAlert,
    IcuNextActionKind.manageTransfer => l10n.icuActionManageTransfer,
    IcuNextActionKind.requestTransfer => l10n.icuActionRequestTransfer,
    IcuNextActionKind.openDischargeClearance =>
      l10n.icuActionOpenDischargeClearance,
    IcuNextActionKind.markReadiness => l10n.icuActionMarkReadiness,
    IcuNextActionKind.assignBed => l10n.icuActionAssignBed,
    IcuNextActionKind.openIpd => l10n.icuActionOpenIpd,
    IcuNextActionKind.recordObservation => l10n.icuActionRecordObservation,
  };
}

IconData icuNextActionIcon(IcuNextActionKind action) {
  return switch (action) {
    IcuNextActionKind.startStay => Icons.play_circle_outline,
    IcuNextActionKind.acknowledgeAlert => Icons.done_all_outlined,
    IcuNextActionKind.manageTransfer => Icons.published_with_changes_outlined,
    IcuNextActionKind.requestTransfer => AppActionIcons.transfer,
    IcuNextActionKind.openDischargeClearance =>
      Icons.assignment_turned_in_outlined,
    IcuNextActionKind.markReadiness => Icons.fact_check_outlined,
    IcuNextActionKind.assignBed => Icons.bed_outlined,
    IcuNextActionKind.openIpd => Icons.open_in_new_outlined,
    IcuNextActionKind.recordObservation => Icons.note_add_outlined,
  };
}

bool icuNextActionRequiresWrite(IcuNextActionKind action) {
  return action != IcuNextActionKind.openIpd &&
      action != IcuNextActionKind.openDischargeClearance;
}

/// Requirement for a board next-action kind (write ∪ vs navigate).
AccessRequirement icuNextActionRequirement(
  IcuNextActionKind kind, [
  AccessRequirement writeRequirement = icuWorkspaceWriteRequirement,
]) {
  if (!icuNextActionRequiresWrite(kind)) {
    return icuNavigationRequirement;
  }
  return writeRequirement;
}

IcuNextActionKind _resolveIcuNextAction(
  IcuPatientSummary item,
  IcuWorkspaceSection activeSection,
) {
  switch (activeSection) {
    case IcuWorkspaceSection.critical:
      if (item.hasCriticalAlert) {
        return IcuNextActionKind.acknowledgeAlert;
      }
    case IcuWorkspaceSection.transfers:
      if (item.hasOpenTransfer) {
        return IcuNextActionKind.manageTransfer;
      }
      return IcuNextActionKind.requestTransfer;
    case IcuWorkspaceSection.discharge:
      if (item.isDischargePlanned) {
        return IcuNextActionKind.openDischargeClearance;
      }
      return IcuNextActionKind.markReadiness;
    case IcuWorkspaceSection.ended:
      return IcuNextActionKind.openIpd;
    case IcuWorkspaceSection.active:
    case IcuWorkspaceSection.all:
    case IcuWorkspaceSection.beds:
    case IcuWorkspaceSection.followUps:
      break;
  }

  if (_isEligibleToStartStay(item)) {
    return IcuNextActionKind.startStay;
  }
  if (item.hasCriticalAlert) {
    return IcuNextActionKind.acknowledgeAlert;
  }
  if (item.hasOpenTransfer) {
    return IcuNextActionKind.manageTransfer;
  }
  if (item.isDischargePlanned) {
    return IcuNextActionKind.openDischargeClearance;
  }
  if (!item.hasActiveBed) {
    return IcuNextActionKind.assignBed;
  }
  if (item.isEndedIcu) {
    return IcuNextActionKind.openIpd;
  }
  return IcuNextActionKind.recordObservation;
}

bool _isEligibleToStartStay(IcuPatientSummary item) {
  if (item.isActiveIcu) {
    return false;
  }
  final String admissionStatus = (item.admissionStatus ?? '').toUpperCase();
  if (admissionStatus == 'DISCHARGED' || admissionStatus == 'CANCELLED') {
    return false;
  }
  return (item.icuStatus ?? '').toUpperCase() != 'ACTIVE';
}

class IcuNextActionButton extends ConsumerWidget {
  const IcuNextActionButton({
    required this.summary,
    required this.section,
    required this.writeRequirement,
    super.key,
  });

  final IcuPatientSummary summary;
  final IcuWorkspaceSection section;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? nextStep = summary.nextStep?.trim();
    if (nextStep != null &&
        nextStep.isNotEmpty &&
        WorkflowActionRegistry.instance.isRegistered(nextStep)) {
      final String encounterId = summary.encounterId ?? summary.id;
      if (encounterId.trim().isNotEmpty) {
        return WorkflowActionButton(
          encounterId: encounterId,
          patientId: summary.patientId,
          admissionId: summary.admissionId,
          nextStep: summary.nextStep,
          stage: summary.stage,
          sourceModule: 'ipd',
          compact: true,
        );
      }
    }

    final IcuNextActionKind action = _resolveIcuNextAction(summary, section);
    final AppLocalizations l10n = context.l10n;
    final String label = icuNextActionLabel(l10n, action);
    final IconData icon = icuNextActionIcon(action);
    final AccessRequirement requirement = icuNextActionRequirement(
      action,
      writeRequirement,
    );

    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return _IcuCompactActionButton(
          label: label,
          icon: icon,
          onPressed: () =>
              unawaited(runIcuNextAction(context, ref, summary, action)),
        );
      },
    );
  }
}

Future<void> runIcuNextAction(
  BuildContext context,
  WidgetRef ref,
  IcuPatientSummary summary,
  IcuNextActionKind action,
) async {
  final IcuWorkspaceController controller = ref.read(
    icuWorkspaceControllerProvider.notifier,
  );
  final AppLocalizations l10n = context.l10n;

  Future<void> ensureSelected() async {
    final AppFailure? failure = await controller.selectPatient(summary);
    if (context.mounted) {
      showIcuFailureIfNeeded(context, failure);
    }
  }

  switch (action) {
    case IcuNextActionKind.recordObservation:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await openIcuObservationDialog(context);
    case IcuNextActionKind.startStay:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await confirmIcuAction(
        context: context,
        title: l10n.icuStartStayTitle,
        body: l10n.icuStartStayBody,
        actionLabel: l10n.icuStartStayActionLabel,
        onConfirmed: controller.startIcuStay,
      );
    case IcuNextActionKind.acknowledgeAlert:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await confirmIcuAction(
        context: context,
        title: l10n.icuAcknowledgeTitle,
        body: l10n.icuAcknowledgeBody,
        actionLabel: l10n.icuActionAcknowledgeAlert,
        onConfirmed: controller.acknowledgeLatestAlert,
      );
    case IcuNextActionKind.manageTransfer:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await openIcuManageTransferDialog(context);
    case IcuNextActionKind.requestTransfer:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      final IcuWorkspaceState? state = readIcuWorkspaceState(ref);
      if (state == null || !context.mounted) {
        return;
      }
      await openIcuTransferDialog(context, state.referenceData);
    case IcuNextActionKind.openDischargeClearance:
      openIpdDischargeClearance(context, summary);
    case IcuNextActionKind.markReadiness:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await openIcuReadinessDialog(context);
    case IcuNextActionKind.assignBed:
      await ensureSelected();
      if (!context.mounted) {
        return;
      }
      await openIcuAssignBedDialog(context);
    case IcuNextActionKind.openIpd:
      openIpdWorkspace(context, summary);
  }
}

class _IcuCompactActionButton extends StatelessWidget {
  const _IcuCompactActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

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
                        fontWeight: FontWeight.w500,
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
