import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

enum _IcuResolvedAction {
  workflow,
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

    final _IcuResolvedAction action = _resolveAction(summary, section);
    final AppLocalizations l10n = context.l10n;
    final String label = _labelForAction(l10n, action);
    final IconData icon = _iconForAction(action);
    final bool requiresWrite = action != _IcuResolvedAction.openIpd;

    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        final bool enabled = !requiresWrite || isAllowed;
        return _IcuCompactActionButton(
          label: label,
          icon: icon,
          enabled: enabled,
          onPressed: enabled
              ? () => unawaited(_handleAction(context, ref, action))
              : null,
        );
      },
    );
  }

  _IcuResolvedAction _resolveAction(
    IcuPatientSummary item,
    IcuWorkspaceSection activeSection,
  ) {
    switch (activeSection) {
      case IcuWorkspaceSection.critical:
        if (item.hasCriticalAlert) {
          return _IcuResolvedAction.acknowledgeAlert;
        }
      case IcuWorkspaceSection.transfers:
        if (item.hasOpenTransfer) {
          return _IcuResolvedAction.manageTransfer;
        }
        return _IcuResolvedAction.requestTransfer;
      case IcuWorkspaceSection.discharge:
        if (item.isDischargePlanned) {
          return _IcuResolvedAction.openDischargeClearance;
        }
        return _IcuResolvedAction.markReadiness;
      case IcuWorkspaceSection.ended:
        return _IcuResolvedAction.openIpd;
      case IcuWorkspaceSection.active:
      case IcuWorkspaceSection.all:
      case IcuWorkspaceSection.beds:
        break;
    }

    if (_isEligibleToStartStay(item)) {
      return _IcuResolvedAction.startStay;
    }
    if (item.hasCriticalAlert) {
      return _IcuResolvedAction.acknowledgeAlert;
    }
    if (item.hasOpenTransfer) {
      return _IcuResolvedAction.manageTransfer;
    }
    if (item.isDischargePlanned) {
      return _IcuResolvedAction.openDischargeClearance;
    }
    if (!item.hasActiveBed) {
      return _IcuResolvedAction.assignBed;
    }
    if (item.isEndedIcu) {
      return _IcuResolvedAction.openIpd;
    }
    return _IcuResolvedAction.recordObservation;
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

  String _labelForAction(AppLocalizations l10n, _IcuResolvedAction action) {
    return switch (action) {
      _IcuResolvedAction.workflow => l10n.icuActionRecordObservation,
      _IcuResolvedAction.startStay => l10n.icuActionStartStay,
      _IcuResolvedAction.acknowledgeAlert => l10n.icuActionAcknowledgeAlert,
      _IcuResolvedAction.manageTransfer => l10n.icuActionManageTransfer,
      _IcuResolvedAction.requestTransfer => l10n.icuActionRequestTransfer,
      _IcuResolvedAction.openDischargeClearance =>
        l10n.icuActionOpenDischargeClearance,
      _IcuResolvedAction.markReadiness => l10n.icuActionMarkReadiness,
      _IcuResolvedAction.assignBed => l10n.icuActionAssignBed,
      _IcuResolvedAction.openIpd => l10n.icuActionOpenIpd,
      _IcuResolvedAction.recordObservation => l10n.icuActionRecordObservation,
    };
  }

  IconData _iconForAction(_IcuResolvedAction action) {
    return switch (action) {
      _IcuResolvedAction.workflow => Icons.arrow_forward_outlined,
      _IcuResolvedAction.startStay => Icons.play_circle_outline,
      _IcuResolvedAction.acknowledgeAlert => Icons.done_all_outlined,
      _IcuResolvedAction.manageTransfer =>
        Icons.published_with_changes_outlined,
      _IcuResolvedAction.requestTransfer => Icons.compare_arrows_outlined,
      _IcuResolvedAction.openDischargeClearance =>
        Icons.assignment_turned_in_outlined,
      _IcuResolvedAction.markReadiness => Icons.fact_check_outlined,
      _IcuResolvedAction.assignBed => Icons.bed_outlined,
      _IcuResolvedAction.openIpd => Icons.open_in_new_outlined,
      _IcuResolvedAction.recordObservation => Icons.note_add_outlined,
    };
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _IcuResolvedAction action,
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
      case _IcuResolvedAction.workflow:
      case _IcuResolvedAction.recordObservation:
        await ensureSelected();
        if (!context.mounted) {
          return;
        }
        await openIcuObservationDialog(context);
      case _IcuResolvedAction.startStay:
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
      case _IcuResolvedAction.acknowledgeAlert:
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
      case _IcuResolvedAction.manageTransfer:
        await ensureSelected();
        if (!context.mounted) {
          return;
        }
        await openIcuManageTransferDialog(context);
      case _IcuResolvedAction.requestTransfer:
        await ensureSelected();
        if (!context.mounted) {
          return;
        }
        final IcuWorkspaceState? state = readIcuWorkspaceState(ref);
        if (state == null || !context.mounted) {
          return;
        }
        await openIcuTransferDialog(context, state.referenceData);
      case _IcuResolvedAction.openDischargeClearance:
        openIpdDischargeClearance(context, summary);
      case _IcuResolvedAction.markReadiness:
        await ensureSelected();
        if (!context.mounted) {
          return;
        }
        await openIcuReadinessDialog(context);
      case _IcuResolvedAction.assignBed:
        await ensureSelected();
        if (!context.mounted) {
          return;
        }
        await openIcuAssignBedDialog(context);
      case _IcuResolvedAction.openIpd:
        openIpdWorkspace(context, summary);
    }
  }
}

class _IcuCompactActionButton extends StatelessWidget {
  const _IcuCompactActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
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
                  if (!enabled) ...<Widget>[
                    SizedBox(width: theme.spacing.xs),
                    Icon(
                      Icons.lock_outlined,
                      size: 10,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
