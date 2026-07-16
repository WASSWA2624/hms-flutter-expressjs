import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';

/// Escalation dialog — a handover dialog in escalation mode.
class NursingEscalationDialog extends StatelessWidget {
  const NursingEscalationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const NursingHandoverDialog(escalation: true);
  }
}
