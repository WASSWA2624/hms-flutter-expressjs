import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

/// Registers dialog openers for actions whose dialogs can open inline
/// without navigating to the target module.
///
/// Call during bootstrap after [initializeWorkflowActionRegistry].
void registerWorkflowDialogOpeners() {
  final WorkflowActionRegistry registry = WorkflowActionRegistry.instance;

  registry.registerDialogOpener(
    'ASSIGN_DOCTOR',
    _openAssignDoctorDialog,
    onSuccess: _invalidateOpdWorkspace,
  );
}

/// Opens [AssignDoctorDialog] inline by fetching the OPD flow via the
/// repository. Returns `true` on success, `false` on cancel, or `null`
/// if the flow could not be fetched.
Future<bool?> _openAssignDoctorDialog(
  BuildContext context,
  WidgetRef ref,
  WorkflowAction action,
) async {
  final String? flowId = action.encounterId;
  if (flowId == null || flowId.isEmpty) return null;

  final Result<OpdFlowDetail> result =
      await ref.read(opdRepositoryProvider).getOpdFlow(flowId);

  OpdFlowSummary? flow;
  result.when(
    success: (OpdFlowDetail detail) => flow = detail.summary,
    failure: (_) {},
  );

  if (flow == null || !context.mounted) return null;

  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AssignDoctorDialog(flow: flow!),
  );
}

void _invalidateOpdWorkspace(WidgetRef ref) {
  ref.invalidate(opdWorkspaceControllerProvider);
}
