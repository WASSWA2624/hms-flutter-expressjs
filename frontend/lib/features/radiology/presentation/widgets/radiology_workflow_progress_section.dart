import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Workflow Assign / Start mutations — ∩ `radiology:write` + module.
const AccessRequirement radiologyWorkflowMutationRequirement =
    radiologyMutationRequirement;

/// Maps backend order status + next_actions into the shared workflow stepper.
class RadiologyWorkflowProgressSection extends ConsumerWidget {
  const RadiologyWorkflowProgressSection({
    required this.workflow,
    required this.canMutate,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onStepTap,
    this.isSaving = false,
    this.onAssign,
    this.onStart,
    super.key,
  });

  final RadiologyWorkflow workflow;
  final bool canMutate;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<int> onStepTap;
  final bool isSaving;
  final VoidCallback? onAssign;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final int activeIndex = radiologyWorkflowStepIndex(workflow);
    final RadiologyNextActions next = workflow.nextActions;
    final List<AppWorkflowStepAction> currentActions =
        <AppWorkflowStepAction>[];

    if (canMutate &&
        !next.billingGateBlocked &&
        next.canAssign &&
        onAssign != null) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'assign',
          label: l10n.radiologyAssignAction,
          icon: Icons.event_available_outlined,
          requirement: radiologyWorkflowMutationRequirement,
          capabilityAllowed: next.canAssign,
          isLoading: isSaving,
          onPressed: isSaving ? null : onAssign,
        ),
      );
    }
    if (canMutate && next.canStart && onStart != null) {
      currentActions.add(
        AppWorkflowStepAction(
          id: 'start',
          label: l10n.radiologyStartImagingAction,
          icon: Icons.play_arrow_outlined,
          requirement: radiologyWorkflowMutationRequirement,
          capabilityAllowed: next.canStart,
          isLoading: isSaving,
          onPressed: isSaving ? null : onStart,
        ),
      );
    }

    final List<({String id, String label, String? help})> defs =
        <({String id, String label, String? help})>[
          (
            id: 'received',
            label: l10n.radiologyWorkflowStepOrderReceived,
            help: next.billingGateBlocked
                ? l10n.radiologyWorkflowNextAwaitPayment
                : l10n.radiologyWorkflowStepOrderReceivedDescription,
          ),
          (
            id: 'billing',
            label: l10n.radiologyWorkflowStepBillingGate,
            help: next.billingGateBlocked
                ? l10n.radiologyWorkflowNextAwaitPayment
                : l10n.radiologyWorkflowStepBillingGateDescription,
          ),
          (
            id: 'schedule',
            label: l10n.radiologyWorkflowStepSchedule,
            help: l10n.radiologyWorkflowStepScheduleDescription,
          ),
          (
            id: 'study_started',
            label: l10n.radiologyWorkflowStepStudyStarted,
            help: l10n.radiologyWorkflowStepStudyStartedDescription,
          ),
          (
            id: 'study_completed',
            label: l10n.radiologyWorkflowStepStudyCompleted,
            help: l10n.radiologyWorkflowStepStudyCompletedDescription,
          ),
          (
            id: 'report_draft',
            label: l10n.radiologyWorkflowStepReportDraft,
            help: l10n.radiologyWorkflowStepReportDraftDescription,
          ),
          (
            id: 'report_final',
            label: l10n.radiologyWorkflowStepReportFinal,
            help: l10n.radiologyWorkflowStepReportFinalDescription,
          ),
          (
            id: 'addendum',
            label: l10n.radiologyWorkflowStepAddendum,
            help: l10n.radiologyWorkflowStepAddendumDescription,
          ),
        ];

    final bool canCollapse = activeIndex >= 3;

    return AppCollapsibleSection(
      title: l10n.radiologyWorkflowProgressTitle,
      collapsible: false,
      actions: canCollapse
          ? <Widget>[
              AppButton(
                iconOnly: true,
                dense: true,
                leadingIcon: expanded ? Icons.unfold_less : Icons.unfold_more,
                label: l10n.radiologyWorkflowProgressTitle,
                semanticLabel: l10n.radiologyWorkflowProgressTitle,
                tooltip: l10n.radiologyWorkflowProgressTitle,
                onPressed: () => onExpandedChanged(!expanded),
              ),
            ]
          : const <Widget>[],
      child: !expanded && canCollapse
          ? AppButton.tertiary(
              label: l10n.radiologyWorkflowProgressCollapsedSummary(
                activeIndex,
                defs.length,
              ),
              leadingIcon: Icons.timeline_outlined,
              onPressed: () => onExpandedChanged(true),
            )
          : AppWorkflowStepper(
              semanticLabel: l10n.radiologyWorkflowProgressTitle,
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
                    onTap: index <= activeIndex ? () => onStepTap(index) : null,
                  ),
              ],
            ),
    );
  }

  static AppWorkflowStepState _stepState(
    int index,
    int activeIndex,
    RadiologyWorkflow workflow,
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
}

/// Derives the active radiology workflow step (0–7) from order + capabilities.
int radiologyWorkflowStepIndex(RadiologyWorkflow workflow) {
  final RadiologyOrder order = workflow.order;
  final RadiologyNextActions next = workflow.nextActions;
  final bool hasAddendum = order.results.any(
    (RadiologyResult result) => result.normalizedStatus == 'AMENDED',
  );
  if (hasAddendum) {
    return 7;
  }
  if (order.hasFinalResult) {
    return 6;
  }
  if (order.latestDraftResult != null) {
    return 5;
  }
  if (workflow.studies.any((ImagingStudy study) => study.hasAssets)) {
    return 4;
  }
  if (workflow.studies.isNotEmpty || order.normalizedStatus == 'IN_PROCESS') {
    return 3;
  }
  if (next.hasAssignment || order.hasAssignment) {
    return next.billingGateBlocked ? 1 : 2;
  }
  if (next.billingGateBlocked) {
    return 1;
  }
  return 0;
}
