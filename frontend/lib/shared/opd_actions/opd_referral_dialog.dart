import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_referral_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Opens [ReferralDialog] with mutating-dialog dismiss rules.
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.createReferral].
Future<bool?> showReferralDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReferralDialog(flow: flow),
  );
}

/// OPD external referral dialog — reuses [ClinicalReferralActionDialog].
///
/// Creates a referral via `POST /api/v1/referrals` with `encounter_id`,
/// `external_facility_name`, `reason`, and optional `notes`. Widgets never
/// call the API; mutations go through [OpdWorkspaceController.createReferral],
/// which patches the selected flow (including referrals) after success.
class ReferralDialog extends ConsumerWidget {
  const ReferralDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _referralCurrentFlow(ref, flow);
    final OpdFlowDetail? currentDetail = _referralCurrentDetail(ref, flow);
    return ClinicalReferralActionDialog(
      title: l10n.opdReferAction,
      submitLabel: l10n.opdSaveReferralAction,
      leadingContent: <Widget>[
        OpdActionContextPanel(
          flow: currentFlow,
          detail: currentDetail,
          showTitle: false,
        ),
      ],
      onSubmit:
          ({
            required String externalFacilityName,
            required String reason,
            required String notes,
          }) {
            return ref
                .read(opdWorkspaceControllerProvider.notifier)
                .createReferral(
                  flow: currentFlow,
                  externalFacilityName: externalFacilityName,
                  reason: reason,
                  notes: notes,
                );
          },
    );
  }
}

OpdFlowSummary _referralCurrentFlow(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected.summary;
  }
  return flow;
}

OpdFlowDetail? _referralCurrentDetail(WidgetRef ref, OpdFlowSummary flow) {
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
