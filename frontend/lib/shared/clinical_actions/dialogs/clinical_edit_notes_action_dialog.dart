import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

@immutable
final class ClinicalNoteEditEntry {
  const ClinicalNoteEditEntry({
    required this.id,
    required this.text,
    this.occurredAt,
  });

  final String id;
  final String text;
  final DateTime? occurredAt;
}

/// Edit one or more clinical notes with a flat formatted-note form.
class ClinicalEditNotesActionDialog extends StatefulWidget {
  const ClinicalEditNotesActionDialog({
    required this.notes,
    required this.onSubmit,
    this.maxWidth = 720,
    super.key,
  });

  final List<ClinicalNoteEditEntry> notes;
  final Future<AppFailure?> Function(Map<String, String> drafts) onSubmit;
  final double maxWidth;

  @override
  State<ClinicalEditNotesActionDialog> createState() =>
      _ClinicalEditNotesActionDialogState();
}

class _ClinicalEditNotesActionDialogState
    extends State<ClinicalEditNotesActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final ClinicalNoteEditEntry note in widget.notes)
        note.id: TextEditingController(text: note.text),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(l10n.clinicalEditNotesTitle),
      icon: const Icon(Icons.edit_note_outlined),
      maxWidth: widget.maxWidth,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) ...<Widget>[
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            for (var index = 0; index < widget.notes.length; index += 1) ...<
              Widget
            >[
              if (index > 0) SizedBox(height: theme.spacing.lg),
            AppRichTextEditor(
              controller: _controllers[widget.notes[index].id]!,
              labelText: l10n.opdClinicalNoteLabel,
              enabled: !_isSaving,
              isRequired: true,
              autofocus: index == 0,
            ),
            ],
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.clinicalSaveChangesAction,
        _isSaving,
        _submit,
        submitLeadingIcon: AppActionIcons.save,
        cancelAfterPrimary: true,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Map<String, String> drafts = <String, String>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    final AppFailure? failure = await widget.onSubmit(drafts);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}
