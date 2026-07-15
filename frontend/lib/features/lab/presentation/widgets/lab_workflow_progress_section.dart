import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

const AccessRequirement _labWorkflowMutationRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.labWrite],
  activeModules: <String>['lab-workflows'],
);

/// Maps backend order status + next_actions into the shared workflow stepper.
class LabWorkflowProgressSection extends ConsumerWidget {
  const LabWorkflowProgressSection({
    required this.workflow,
    required this.canMutate,
    this.isSaving = false,
    this.onVerifyResults,
    super.key,
  });

  final LabOrderWorkflow workflow;
  final bool canMutate;
  final bool isSaving;
  final VoidCallback? onVerifyResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int activeIndex = labWorkflowStepIndex(workflow);
    final LabWorkflowNextActions next = workflow.nextActions;
    final List<AppWorkflowStepAction> currentActions =
        <AppWorkflowStepAction>[];

    if (canMutate && next.canCollect) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'collect',
          label: l10n.labCollectSampleAction,
          icon: Icons.bloodtype_outlined,
          requirement: _labWorkflowMutationRequirement,
          capabilityAllowed: next.canCollect,
          isLoading: isSaving,
          confirmTitle: l10n.labCollectDialogTitle,
          confirmBody: l10n.labCollectConfirmBody,
          confirmSubmitLabel: l10n.labCollectSampleAction,
          onPressed: isSaving ? null : () => _collect(context, ref),
        ),
      );
    } else if (canMutate && next.billingGateBlocked) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'billing_gate',
          label: l10n.labBillingGateBlockedAction,
          icon: Icons.payments_outlined,
          requirement: _labWorkflowMutationRequirement,
          capabilityAllowed: false,
          onPressed: null,
        ),
      );
    }
    if (canMutate && next.canReceiveSample) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'receive',
          label: l10n.labReceiveSampleAction,
          icon: Icons.inbox_outlined,
          requirement: _labWorkflowMutationRequirement,
          capabilityAllowed: next.canReceiveSample,
          isLoading: isSaving,
          confirmTitle: l10n.labReceiveDialogTitle,
          confirmBody: l10n.labReceiveConfirmBody,
          confirmSubmitLabel: l10n.labReceiveSampleAction,
          onPressed: isSaving ? null : () => _receive(context, ref),
        ),
      );
    }
    if (canMutate &&
        (next.canVerifyResult || next.canVerifyAll) &&
        onVerifyResults != null) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'verify',
          label: l10n.labWorkflowNextVerifyResults,
          icon: Icons.verified_outlined,
          requirement: _labWorkflowMutationRequirement,
          capabilityAllowed: next.canVerifyResult || next.canVerifyAll,
          variant: AppButtonVariant.primary,
          isLoading: isSaving,
          onPressed: isSaving ? null : onVerifyResults,
        ),
      );
    }
    if (canMutate && next.canReverseWorkflow) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'reverse',
          label: l10n.labReverseWorkflowAction,
          icon: Icons.undo_outlined,
          requirement: _labWorkflowMutationRequirement,
          capabilityAllowed: next.canReverseWorkflow,
          isLoading: isSaving,
          variant: AppButtonVariant.tertiary,
          onPressed: isSaving ? null : () => _reverse(context, ref),
        ),
      );
    }

    final List<({String id, String label, String? help})> defs =
        <({String id, String label, String? help})>[
          (
            id: 'ordered',
            label: l10n.labWorkflowStepOrdered,
            help: next.billingGateBlocked
                ? l10n.labWorkflowNextAwaitPayment
                : l10n.labWorkflowNextCollectSample,
          ),
          (
            id: 'sample',
            label: l10n.labWorkflowStepSample,
            help: next.canReceiveSample
                ? l10n.labWorkflowNextReceiveSample
                : l10n.labWorkflowNextEnterResults,
          ),
          (
            id: 'processing',
            label: l10n.labWorkflowStepInProcess,
            help: l10n.labWorkflowNextEnterResults,
          ),
          (
            id: 'results_entered',
            label: l10n.labWorkflowStepResultsEntered,
            help: l10n.labWorkflowNextVerifyResults,
          ),
          (id: 'verified', label: l10n.labWorkflowStepVerified, help: null),
        ];

    return AppSectionPanel(
      title: l10n.labWorkflowProgressTitle,
      spacing: theme.spacing.sm,
      children: <Widget>[
        AppWorkflowStepper(
          semanticLabel: l10n.labWorkflowProgressTitle,
          steps: <AppWorkflowStepItem>[
            for (var index = 0; index < defs.length; index += 1)
              AppWorkflowStepItem(
                id: defs[index].id,
                label: defs[index].label,
                helpText: defs[index].help,
                state: _stepState(index, activeIndex, workflow),
                actions: index == activeIndex
                    ? currentActions
                    : const <AppWorkflowStepAction>[],
              ),
          ],
        ),
      ],
    );
  }

  static AppWorkflowStepState _stepState(
    int index,
    int activeIndex,
    LabOrderWorkflow workflow,
  ) {
    final String status = (workflow.order.status ?? '').toUpperCase();
    if (status == 'CANCELLED') {
      return index == 0
          ? AppWorkflowStepState.reverted
          : AppWorkflowStepState.unavailable;
    }
    if (index < activeIndex) {
      return AppWorkflowStepState.completed;
    }
    if (index == activeIndex) {
      return AppWorkflowStepState.current;
    }
    return AppWorkflowStepState.upcoming;
  }

  Future<void> _collect(BuildContext context, WidgetRef ref) async {
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .collectSelected(const <String, Object?>{});
    if (!context.mounted || failure == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.failureMessage(failure))),
    );
  }

  Future<void> _receive(BuildContext context, WidgetRef ref) async {
    final LabSample? sample = workflow.firstReceivableSample;
    if (sample == null) {
      return;
    }
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .receiveSample(sample.apiId, const <String, Object?>{});
    if (!context.mounted || failure == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.failureMessage(failure))),
    );
  }

  Future<void> _reverse(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppTextActionDialog(
          title: l10n.labReverseDialogTitle,
          fieldLabel: l10n.labReverseReasonLabel,
          submitLabel: l10n.labReverseWorkflowAction,
          icon: const Icon(Icons.undo_outlined),
          onSubmit: (String reason) {
            return ref
                .read(labWorkspaceControllerProvider.notifier)
                .reverseSelected(<String, Object?>{'reason': reason});
          },
        );
      },
    );
  }
}

/// Derives the active lab workflow step from order status and item progress.
int labWorkflowStepIndex(LabOrderWorkflow workflow) {
  final String status = (workflow.order.status ?? '').toUpperCase();
  if (status == 'COMPLETED') {
    return 4;
  }
  if (status == 'IN_PROCESS') {
    final bool allEntered =
        workflow.order.items.isNotEmpty &&
        workflow.order.items.every(
          (LabOrderItem item) =>
              item.isCompleted ||
              (item.resultId != null && item.resultId!.trim().isNotEmpty),
        );
    return allEntered ? 3 : 2;
  }
  if (status == 'COLLECTED') {
    return workflow.nextActions.canReceiveSample ? 1 : 2;
  }
  if (status == 'ORDERED') {
    return 0;
  }
  if (workflow.order.verifiableItemCount > 0) {
    return 3;
  }
  return 0;
}
