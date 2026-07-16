import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';

/// Nursing note dialog backed by [ClinicalFreeTextActionDialog].
class NursingNoteDialog extends StatelessWidget {
  const NursingNoteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ClinicalFreeTextActionDialog(
      title: context.l10n.nursingActionAddNote,
      label: context.l10n.nursingNoteLabel,
      submitLabel: context.l10n.nursingActionAddNote,
      icon: const Icon(Icons.note_add_outlined),
      onSubmit: (String note) {
        return ProviderScope.containerOf(context, listen: false)
            .read(nursingWorkspaceControllerProvider.notifier)
            .addNursingNote(note);
      },
    );
  }
}
