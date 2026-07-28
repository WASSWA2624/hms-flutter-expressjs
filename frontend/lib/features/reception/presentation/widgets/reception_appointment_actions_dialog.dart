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
/// [receptionFrontDeskWriteRequirement] rather than forking a divergent shell.
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
      // Explicit reception gate (alias of OPD front-desk write) for RBAC clarity.
      // ignore: avoid_redundant_argument_values
      actionRequirement: receptionFrontDeskWriteRequirement,
      allowClinicalActions: false,
      allowVitalsActions: false,
      omitPrimaryAction: omitPrimaryAction,
    );
  }
}
