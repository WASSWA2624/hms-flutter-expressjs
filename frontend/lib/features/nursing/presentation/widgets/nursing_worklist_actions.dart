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

String nursingResolveNextActionLabel(
  AppLocalizations l10n,
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  if (scope == NursingQueueScope.urgent && item.hasCriticalAlert) {
    return l10n.nursingActionEscalate;
  }

  if (scope == NursingQueueScope.all ||
      scope == NursingQueueScope.assignedWard) {
    return switch (item.taskTypeCode) {
      'MEDICATION_DUE' => l10n.nursingActionAdministerMedication,
      'HANDOVER_PENDING' => l10n.nursingActionCreateHandover,
      'TRANSFER_PENDING' => l10n.nursingActionAcknowledgeTransfer,
      'DISCHARGE_PENDING' => l10n.nursingActionDischargeClearance,
      _ => l10n.nursingActionRecordVitals,
    };
  }

  return nursingPrimaryActionLabel(l10n, scope);
}

IconData nursingResolveNextActionIcon(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  if (scope == NursingQueueScope.urgent && item.hasCriticalAlert) {
    return Icons.report_problem_outlined;
  }

  if (scope == NursingQueueScope.all ||
      scope == NursingQueueScope.assignedWard) {
    return switch (item.taskTypeCode) {
      'MEDICATION_DUE' => Icons.medication_outlined,
      'HANDOVER_PENDING' => Icons.swap_horiz_outlined,
      'TRANSFER_PENDING' => Icons.transfer_within_a_station_outlined,
      'DISCHARGE_PENDING' => Icons.fact_check_outlined,
      _ => Icons.monitor_heart_outlined,
    };
  }

  return nursingPrimaryActionIcon(scope);
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

  if (scope == NursingQueueScope.urgent && item.hasCriticalAlert) {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NursingEscalationDialog(),
      ),
    );
    return;
  }

  switch (_resolveRowActionKind(item, scope)) {
    case _NursingRowActionKind.medication:
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
    case _NursingRowActionKind.handover:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingHandoverDialog(),
        ),
      );
    case _NursingRowActionKind.transfer:
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
    case _NursingRowActionKind.discharge:
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
    case _NursingRowActionKind.vitals:
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

enum _NursingRowActionKind { vitals, medication, handover, transfer, discharge }

_NursingRowActionKind _resolveRowActionKind(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  return switch (scope) {
    NursingQueueScope.medicationDue => _NursingRowActionKind.medication,
    NursingQueueScope.handoverPending => _NursingRowActionKind.handover,
    NursingQueueScope.transferPending => _NursingRowActionKind.transfer,
    NursingQueueScope.dischargePending => _NursingRowActionKind.discharge,
    NursingQueueScope.all ||
    NursingQueueScope.assignedWard ||
    NursingQueueScope.urgent => switch (item.taskTypeCode) {
      'MEDICATION_DUE' => _NursingRowActionKind.medication,
      'HANDOVER_PENDING' => _NursingRowActionKind.handover,
      'TRANSFER_PENDING' => _NursingRowActionKind.transfer,
      'DISCHARGE_PENDING' => _NursingRowActionKind.discharge,
      _ => _NursingRowActionKind.vitals,
    },
  };
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
