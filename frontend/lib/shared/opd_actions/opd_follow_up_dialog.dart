import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Opens [FollowUpDialog] with mutating-dialog dismiss rules.
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.createFollowUp].
Future<bool?> showFollowUpDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FollowUpDialog(flow: flow),
  );
}

/// OPD follow-up scheduling dialog — reuses [ClinicalFollowUpActionDialog].
///
/// Creates a follow-up via `POST /api/v1/follow-ups` with public
/// `encounter_id`, UTC `scheduled_at`, `status`, and optional `notes`.
/// Widgets never call the API; mutations go through
/// [OpdWorkspaceController.createFollowUp], which patches the selected flow
/// (including follow-ups) after success.
class FollowUpDialog extends ConsumerWidget {
  const FollowUpDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _followUpCurrentFlow(ref, flow);
    final OpdFlowDetail? currentDetail = _followUpCurrentDetail(ref, flow);
    return ClinicalFollowUpActionDialog(
      title: l10n.opdFollowUpAction,
      submitLabel: l10n.opdSaveFollowUpAction,
      leadingContent: <Widget>[
        OpdActionContextPanel(
          flow: currentFlow,
          detail: currentDetail,
          showTitle: false,
        ),
      ],
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .createFollowUp(
              flow: currentFlow,
              scheduledAt: scheduledAt,
              notes: notes,
            );
      },
    );
  }
}

OpdFlowSummary _followUpCurrentFlow(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected.summary;
  }
  return flow;
}

OpdFlowDetail? _followUpCurrentDetail(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected;
  }
  return null;
}

OpdWorkspaceState? _workspaceState(WidgetRef ref) {
  final Result<OpdWorkspaceState>? workspaceResult = ref
      .watch(opdWorkspaceControllerProvider)
      .asData
      ?.value;
  return workspaceResult?.when(
    success: (OpdWorkspaceState state) => state,
    failure: (_) => null,
  );
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}
