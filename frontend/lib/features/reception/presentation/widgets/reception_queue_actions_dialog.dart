import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';

/// Opens reception queue actions through the shared OPD queue action hub.
Future<bool?> showReceptionQueueActionsDialog({
  required BuildContext context,
  required OpdQueueEntry entry,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionQueueActionsDialog(entry: entry),
  );
}

/// Reception front-desk queue actions.
///
/// Composes [QueueActionsDialog] with
/// [ReceptionDeskQueueAtomPermissions.frontDesk] rather than forking a
/// divergent reception shell. Nested billing / clinical panels stay stripped.
class ReceptionQueueActionsDialog extends StatelessWidget {
  const ReceptionQueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    return QueueActionsDialog(
      entry: entry,
      // Source front-desk gate (matrix update documents patient:write — keep
      // source; see ReceptionDeskQueueAtomPermissions).
      // ignore: avoid_redundant_argument_values
      actionRequirement: ReceptionDeskQueueAtomPermissions.frontDesk,
    );
  }
}
