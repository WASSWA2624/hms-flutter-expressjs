import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';

/// Opens reception queue actions through the shared OPD queue action hub.
Future<bool?> showReceptionQueueActionsDialog({
  required BuildContext context,
  required OpdQueueEntry entry,
  AccessRequirement actionRequirement =
      ReceptionDeskQueueAtomPermissions.frontDesk,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionQueueActionsDialog(
      entry: entry,
      actionRequirement: actionRequirement,
    ),
  );
}

/// Reception front-desk queue actions.
///
/// Composes [QueueActionsDialog] with a reception front-desk write requirement
/// (Desk queue / High priority atoms) rather than forking a divergent shell.
/// Nested billing / clinical panels stay stripped.
class ReceptionQueueActionsDialog extends StatelessWidget {
  const ReceptionQueueActionsDialog({
    required this.entry,
    this.actionRequirement = ReceptionDeskQueueAtomPermissions.frontDesk,
    super.key,
  });

  final OpdQueueEntry entry;

  /// Source front-desk gate (matrix update documents patient:write — keep
  /// source; see [ReceptionDeskQueueAtomPermissions] /
  /// [ReceptionHighPriorityAtomPermissions]).
  final AccessRequirement actionRequirement;

  @override
  Widget build(BuildContext context) {
    return QueueActionsDialog(
      entry: entry,
      // ignore: avoid_redundant_argument_values
      actionRequirement: actionRequirement,
    );
  }
}
