import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';

/// Opens reception appointment actions through the shared OPD appointment hub.
///
/// [omitPrimaryAction] defaults to true so Check in / Continue stay on the
/// worklist next-action and are not duplicated inside the hub.
Future<bool?> showReceptionAppointmentActionsDialog({
  required BuildContext context,
  required OpdAppointment appointment,
  OpdWorkspaceState? workspaceState,
  bool omitPrimaryAction = true,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionAppointmentActionsDialog(
      appointment: appointment,
      workspaceState: workspaceState,
      omitPrimaryAction: omitPrimaryAction,
    ),
  );
}

/// Reception front-desk appointment actions.
///
/// Composes [OpdAppointmentActionsDialog] with
/// [ReceptionAppointmentsAtomPermissions.frontDesk] rather than forking a
/// divergent shell. Nested billing / clinical panels stay stripped.
class ReceptionAppointmentActionsDialog extends StatelessWidget {
  const ReceptionAppointmentActionsDialog({
    required this.appointment,
    this.workspaceState,
    this.omitPrimaryAction = true,
    super.key,
  });

  final OpdAppointment appointment;
  final OpdWorkspaceState? workspaceState;

  /// When true, omits Check in / Continue so the desk next-action is sole primary.
  final bool omitPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return OpdAppointmentActionsDialog(
      appointment: appointment,
      workspaceState: workspaceState,
      // Source front-desk gate (matrix update/delete document patient:write /
      // patient:delete — keep source; see ReceptionAppointmentsAtomPermissions).
      // ignore: avoid_redundant_argument_values
      actionRequirement: ReceptionAppointmentsAtomPermissions.frontDesk,
      allowClinicalActions: false,
      allowVitalsActions: false,
      omitPrimaryAction: omitPrimaryAction,
    );
  }
}
