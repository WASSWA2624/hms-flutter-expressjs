import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_escalation_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

export 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart'
    show nursingWriteRequirement;
export 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';

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
    this.compact = false,
    super.key,
  });

  final NursingWorkItem item;
  final NursingQueueScope scope;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingNextActionKind kind = nursingResolveNextActionKind(
      item,
      scope,
    );
    final String label = nursingResolveNextActionLabel(l10n, item, scope);
    final IconData icon = nursingResolveNextActionIcon(item, scope);

    // hideWhenDenied (default): unauthorized next-action does not render.
    return AppAccessActionGate(
      requirement: nursingNextActionRequirement(kind),
      builder: (BuildContext context, bool isAllowed) {
        void onPressed() => nursingExecuteRowAction(context, ref, item, scope);
        if (compact) {
          return AppButton(
            iconOnly: true,
            icon: icon,
            label: label,
            tooltip: label,
            semanticLabel: label,
            onPressed: isAllowed ? onPressed : null,
          );
        }
        return AppButton.tertiary(
          label: label,
          leadingIcon: icon,
          tooltip: label,
          onPressed: isAllowed ? onPressed : null,
        );
      },
    );
  }
}
