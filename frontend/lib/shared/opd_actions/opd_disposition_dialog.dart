import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_disposition_actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_disposition_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Disposition outcomes supported by `POST /opd-flows/:id/disposition`.
List<String> opdDispositionOptions({required bool hasPharmacyOrder}) {
  return <String>[
    'DISCHARGE',
    if (hasPharmacyOrder) 'SEND_TO_PHARMACY',
    'REFER_PHYSIOTHERAPY',
    'ADMIT',
  ];
}

/// Opens [OpdDispositionDialog] with mutating-dialog dismiss rules.
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.completeDisposition].
Future<bool?> showOpdDispositionDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  required bool hasPharmacyOrder,
  ValueChanged<String>? onDispositionSubmitted,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OpdDispositionDialog(
      flow: flow,
      hasPharmacyOrder: hasPharmacyOrder,
      onDispositionSubmitted: onDispositionSubmitted,
    ),
  );
}

/// OPD disposition outcome dialog — reuses [ClinicalDispositionActionDialog].
///
/// Captures the encounter disposition decision (discharge, pharmacy, physio
/// referral, or admit) as part of OPD completion routing. Widgets never call
/// the API; mutations go through [OpdWorkspaceController.completeDisposition].
class OpdDispositionDialog extends ConsumerWidget {
  const OpdDispositionDialog({
    required this.flow,
    required this.hasPharmacyOrder,
    this.onDispositionSubmitted,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool hasPharmacyOrder;
  final ValueChanged<String>? onDispositionSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _dispositionCurrentFlow(ref, flow);
    final OpdFlowDetail? currentDetail = _dispositionCurrentDetail(ref, flow);
    final List<String> reasons = opdDispositionOptions(
      hasPharmacyOrder: hasPharmacyOrder,
    );
    final String preferred = hasPharmacyOrder
        ? 'SEND_TO_PHARMACY'
        : 'DISCHARGE';
    final String title = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: 'OPD',
      status: currentFlow.status,
      stage: currentFlow.stage,
      isOpdContext: true,
    );
    return ClinicalDispositionActionDialog(
      title: title,
      submitLabel: l10n.opdSaveDispositionAction,
      submitLeadingIcon: AppActionIcons.save,
      reasons: reasons,
      initialReason: reasons.contains(preferred) ? preferred : null,
      reasonLabel: l10n.opdFieldRequiredLabel(l10n.opdDecisionLabel),
      notesLabel: l10n.opdFieldOptionalLabel(l10n.opdNotesLabel),
      leadingContent: <Widget>[
        OpdActionContextPanel(
          flow: currentFlow,
          detail: currentDetail,
          showTitle: false,
        ),
      ],
      onSubmit: ({required String reason, required String notes}) async {
        final AppFailure? failure = await ref
            .read(opdWorkspaceControllerProvider.notifier)
            .completeDisposition(currentFlow, <String, Object?>{
              'decision': reason,
              'notes': notes,
            });
        if (failure == null) {
          onDispositionSubmitted?.call(reason);
        }
        return failure;
      },
    );
  }
}

OpdFlowSummary _dispositionCurrentFlow(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected.summary;
  }
  return flow;
}

OpdFlowDetail? _dispositionCurrentDetail(WidgetRef ref, OpdFlowSummary flow) {
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
