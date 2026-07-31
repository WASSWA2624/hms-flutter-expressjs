import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Add a clinical note with a flat formatted-note form (no nested sections).
class ClinicalAddNotesActionDialog extends StatefulWidget {
  const ClinicalAddNotesActionDialog({
    required this.onSubmit,
    this.maxWidth = 720,
    super.key,
  });

  final Future<AppFailure?> Function(String value) onSubmit;
  final double maxWidth;

  @override
  State<ClinicalAddNotesActionDialog> createState() =>
      _ClinicalAddNotesActionDialogState();
}

class _ClinicalAddNotesActionDialogState
    extends State<ClinicalAddNotesActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(l10n.clinicalAddNoteTitle),
      icon: const Icon(Icons.note_add_outlined),
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
            AppRichTextEditor(
              controller: _controller,
              labelText: l10n.opdClinicalNoteLabel,
              enabled: !_isSaving,
              isRequired: true,
              autofocus: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.clinicalAddNoteAction,
        _isSaving,
        _submit,
        submitLeadingIcon: Icons.note_add_outlined,
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
    final AppFailure? failure = await widget.onSubmit(_controller.text.trim());
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
