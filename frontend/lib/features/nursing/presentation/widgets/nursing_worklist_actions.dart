import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_escalation_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

const AccessRequirement nursingWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
    AppPermissions.lastOfficeWrite,
  ],
  anyRoles: <AppRole>[
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.facilityAdmin,
    AppRole.tenantAdmin,
    AppRole.superAdmin,
  ],
  activeModules: <String>['inpatient-bed-management'],
);

/// Stage-aware next-action kinds for the nursing worklist.
enum NursingNextActionKind {
  vitals,
  medication,
  handover,
  transfer,
  discharge,
  escalate,
}

NursingNextActionKind nursingResolveNextActionKind(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  if (scope == NursingQueueScope.urgent && item.hasCriticalAlert) {
    return NursingNextActionKind.escalate;
  }

  return switch (scope) {
    NursingQueueScope.medicationDue => NursingNextActionKind.medication,
    NursingQueueScope.handoverPending => NursingNextActionKind.handover,
    NursingQueueScope.transferPending => NursingNextActionKind.transfer,
    NursingQueueScope.dischargePending => NursingNextActionKind.discharge,
    NursingQueueScope.all ||
    NursingQueueScope.assignedWard ||
    NursingQueueScope.urgent => switch (item.taskTypeCode) {
      'MEDICATION_DUE' => NursingNextActionKind.medication,
      'HANDOVER_PENDING' => NursingNextActionKind.handover,
      'TRANSFER_PENDING' => NursingNextActionKind.transfer,
      'DISCHARGE_PENDING' => NursingNextActionKind.discharge,
      _ => NursingNextActionKind.vitals,
    },
  };
}

String nursingResolveNextActionLabel(
  AppLocalizations l10n,
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  return switch (nursingResolveNextActionKind(item, scope)) {
    NursingNextActionKind.escalate => l10n.nursingActionEscalate,
    NursingNextActionKind.medication => l10n.nursingActionAdministerMedication,
    NursingNextActionKind.handover => l10n.nursingActionCreateHandover,
    NursingNextActionKind.transfer => l10n.nursingActionAcknowledgeTransfer,
    NursingNextActionKind.discharge => l10n.nursingActionDischargeClearance,
    NursingNextActionKind.vitals =>
      scope == NursingQueueScope.all ||
          scope == NursingQueueScope.assignedWard ||
          scope == NursingQueueScope.urgent
      ? l10n.nursingActionRecordVitals
      : nursingPrimaryActionLabel(l10n, scope),
  };
}

IconData nursingResolveNextActionIcon(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  return switch (nursingResolveNextActionKind(item, scope)) {
    NursingNextActionKind.escalate => Icons.report_problem_outlined,
    NursingNextActionKind.medication => Icons.medication_outlined,
    NursingNextActionKind.handover => Icons.swap_horiz_outlined,
    NursingNextActionKind.transfer => Icons.transfer_within_a_station_outlined,
    NursingNextActionKind.discharge => Icons.fact_check_outlined,
    NursingNextActionKind.vitals =>
      scope == NursingQueueScope.all ||
          scope == NursingQueueScope.assignedWard ||
          scope == NursingQueueScope.urgent
      ? Icons.monitor_heart_outlined
      : nursingPrimaryActionIcon(scope),
  };
}

Future<void> nursingExecuteRowAction(
  BuildContext context,
  WidgetRef ref,
  NursingWorkItem item,
  NursingQueueScope scope,
) async {
  final NursingWorkspaceController controller = ref.read(
    nursingWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(item);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    nursingShowFailureIfNeeded(context, failure);
    return;
  }

  switch (nursingResolveNextActionKind(item, scope)) {
    case NursingNextActionKind.escalate:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingEscalationDialog(),
        ),
      );
    case NursingNextActionKind.medication:
      final NursingPatientDetail? detail = nursingSelectedDetailFromState(
        ref.read(nursingWorkspaceControllerProvider),
      );
      if (detail == null || !context.mounted) {
        return;
      }
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingMedicationDialog(detail: detail),
        ),
      );
    case NursingNextActionKind.handover:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingHandoverDialog(),
        ),
      );
    case NursingNextActionKind.transfer:
      final NursingPatientDetail? detail = nursingSelectedDetailFromState(
        ref.read(nursingWorkspaceControllerProvider),
      );
      if (detail == null || !context.mounted) {
        return;
      }
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingTransferDialog(detail: detail),
        ),
      );
    case NursingNextActionKind.discharge:
      final NursingPatientDetail? detail = nursingSelectedDetailFromState(
        ref.read(nursingWorkspaceControllerProvider),
      );
      if (detail == null || !context.mounted) {
        return;
      }
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingDischargeClearanceDialog(detail: detail),
        ),
      );
    case NursingNextActionKind.vitals:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingVitalsDialog(),
        ),
      );
  }
}

class NursingNextActionCell extends ConsumerWidget {
  const NursingNextActionCell({
    required this.item,
    required this.scope,
    super.key,
  });

  final NursingWorkItem item;
  final NursingQueueScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String label = nursingResolveNextActionLabel(l10n, item, scope);
    final IconData icon = nursingResolveNextActionIcon(item, scope);

    return AppAccessActionGate(
      requirement: nursingWriteRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppButton.tertiary(
          label: label,
          leadingIcon: icon,
          enabled: isAllowed,
          tooltip: label,
          onPressed: isAllowed
              ? () => nursingExecuteRowAction(context, ref, item, scope)
              : null,
        );
      },
    );
  }
}
