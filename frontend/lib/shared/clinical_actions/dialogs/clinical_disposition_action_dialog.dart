import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalDispositionActionDialog extends StatefulWidget {
  const ClinicalDispositionActionDialog({
    required this.reasons,
    required this.onSubmit,
    this.title,
    this.reasonLabel,
    this.notesLabel,
    this.submitLabel,
    this.initialReason,
    this.icon = const Icon(Icons.task_alt_outlined),
    this.leadingContent = const <Widget>[],
    super.key,
  });

  final List<String> reasons;
  final String? title;
  final String? reasonLabel;
  final String? notesLabel;
  final String? submitLabel;
  final String? initialReason;
  final Widget icon;
  final List<Widget> leadingContent;
  final Future<AppFailure?> Function({
    required String reason,
    required String notes,
  })
  onSubmit;

  @override
  State<ClinicalDispositionActionDialog> createState() =>
      _ClinicalDispositionActionDialogState();
}

class _ClinicalDispositionActionDialogState
    extends State<ClinicalDispositionActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late String? _reason;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _reason = _initialReason();
  }

  String? _initialReason() {
    final String? requested = widget.initialReason;
    if (requested != null && widget.reasons.contains(requested)) {
      return requested;
    }
    return widget.reasons.isEmpty ? null : widget.reasons.first;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title ?? l10n.clinicalCompleteDispositionAction),
      icon: widget.icon,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFormInformationBanner.failure(context: context, failure: _failure!),
            ...widget.leadingContent,
            AppSelectField<String>.searchable(
              value: _reason,
              labelText:
                  widget.reasonLabel ?? l10n.clinicalDispositionReasonLabel,
              enabled: !_isSaving,
              isRequired: true,
              menuHeight: 320,
              options: _dispositionReasonOptions(widget.reasons),
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              onChanged: (String? value) => setState(() => _reason = value),
            ),
            AppTextField(
              controller: _notesController,
              labelText: widget.notesLabel ?? l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel ?? l10n.clinicalCompleteDispositionAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? reason = _reason;
    if (reason == null || reason.trim().isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      reason: reason,
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

List<AppSelectOption<String>> _dispositionReasonOptions(List<String> reasons) {
  return <AppSelectOption<String>>[
    for (final String reason in reasons)
      AppSelectOption<String>(
        value: reason,
        label: clinicalActionApiLabel(reason),
        leadingIcon: const Icon(Icons.fact_check_outlined),
      ),
  ];
}
