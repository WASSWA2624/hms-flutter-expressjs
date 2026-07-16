import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_routing_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Canonical triage / OPD route destinations for routing decision UIs.
const List<String> opdTriageRouteOptions = <String>[
  'CONSULTATION',
  'EMERGENCY',
  'ADMIT',
  'THEATRE',
  'MINOR_PROCEDURE',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'DISCHARGE',
];

/// Field options for [AppTriageDecisionField] / [ClinicalRoutingActionDialog].
List<AppTriageOption> opdTriageRouteFieldOptions() {
  return <AppTriageOption>[
    for (final String value in opdTriageRouteOptions)
      AppTriageOption(
        value: value,
        label: AppDisplay.apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

/// Opens [RoutingDecisionDialog] with mutating-dialog dismiss rules.
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.disposeFlow] → `POST /api/v1/triage/:id/route`.
Future<bool?> showRoutingDecisionDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RoutingDecisionDialog(flow: flow),
  );
}

/// OPD routing decision dialog — reuses [ClinicalRoutingActionDialog].
///
/// Records the next care-path destination for an OPD/triage encounter.
/// Widgets never call the API; mutations go through
/// [OpdWorkspaceController.disposeFlow], which patches flows/triage queue
/// slices after HTTP success.
class RoutingDecisionDialog extends ConsumerWidget {
  const RoutingDecisionDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _routingCurrentFlow(ref, flow);
    final OpdFlowDetail? currentDetail = _routingCurrentDetail(ref, flow);
    final String existingRoute = (currentFlow.lastRouteTo ?? '')
        .trim()
        .toUpperCase();
    return ClinicalRoutingActionDialog(
      title: l10n.opdRouteDecisionLabel,
      submitLabel: l10n.opdSaveRoutingDecisionAction,
      routeOptions: opdTriageRouteFieldOptions(),
      initialRoute: existingRoute,
      routeLabel: l10n.opdFieldRequiredLabel(l10n.opdRouteDecisionLabel),
      notesLabel: l10n.opdFieldOptionalLabel(l10n.opdNotesLabel),
      leadingContent: <Widget>[
        OpdActionContextPanel(
          flow: currentFlow,
          detail: currentDetail,
          showTitle: false,
        ),
      ],
      onSubmit: ({required String routeTo, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .disposeFlow(currentFlow, routeTo, notes);
      },
    );
  }
}

OpdFlowSummary _routingCurrentFlow(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected.summary;
  }
  return flow;
}

OpdFlowDetail? _routingCurrentDetail(WidgetRef ref, OpdFlowSummary flow) {
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
