import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalReferralActionDialog extends StatefulWidget {
  const ClinicalReferralActionDialog({
    required this.onSubmit,
    this.leadingContent = const <Widget>[],
    super.key,
  });

  final Future<AppFailure?> Function({
    required String externalFacilityName,
    required String reason,
    required String notes,
  })
  onSubmit;
  final List<Widget> leadingContent;

  @override
  State<ClinicalReferralActionDialog> createState() =>
      _ClinicalReferralActionDialogState();
}

class _ClinicalReferralActionDialogState
    extends State<ClinicalReferralActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(l10n.opdReferAction),
      icon: const Icon(Icons.alt_route_outlined),
      maxWidth: 720,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFormInformationBanner.failure(context: context, failure: _failure!),
            ...widget.leadingContent,
            AppFormSection(
              title: l10n.clinicalReferralDetailsTitle,
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  controller: _facilityController,
                  labelText: l10n.opdExternalFacilityLabel,
                  enabled: !_isSaving,
                  isRequired: true,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
                AppTextField(
                  controller: _reasonController,
                  labelText: l10n.opdReasonLabel,
                  enabled: !_isSaving,
                  isRequired: true,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppFormSection(
              title: l10n.clinicalReferralNotesTitle,
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  controller: _notesController,
                  labelText: l10n.opdNotesLabel,
                  enabled: !_isSaving,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdReferAction,
        _isSaving,
        _submit,
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
    final AppFailure? failure = await widget.onSubmit(
      externalFacilityName: _facilityController.text.trim(),
      reason: _reasonController.text.trim(),
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
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
