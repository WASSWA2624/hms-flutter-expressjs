import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Shared disposition/outcome dialog used by clinical and OPD encounter flows.
///
/// Compose through [AppDialog] only. Footer is Cancel → primary via
/// [clinicalActionDialogActions]. While saving, close and Cancel are disabled.
class ClinicalDispositionActionDialog extends StatefulWidget {
  const ClinicalDispositionActionDialog({
    required this.reasons,
    required this.onSubmit,
    this.title,
    this.reasonLabel,
    this.notesLabel,
    this.submitLabel,
    this.initialReason,
    this.icon = const Icon(AppActionIcons.complete),
    this.submitLeadingIcon = AppActionIcons.complete,
    this.leadingContent = const <Widget>[],
    this.scrollable = true,
    this.pinActionsToBottom = true,
    this.density = AppFormSectionDensity.compact,
    this.maxWidth = 720,
    super.key,
  });

  final List<String> reasons;
  final String? title;
  final String? reasonLabel;
  final String? notesLabel;
  final String? submitLabel;
  final String? initialReason;
  final Widget icon;
  final IconData submitLeadingIcon;
  final List<Widget> leadingContent;
  final bool scrollable;
  final bool pinActionsToBottom;
  final AppFormSectionDensity density;
  final double maxWidth;
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
    final String title = widget.title ?? l10n.clinicalCompleteDispositionAction;
    final String submitLabel =
        widget.submitLabel ?? l10n.clinicalCompleteDispositionAction;
    return AppDialog(
      title: Text(title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      scrollable: widget.scrollable,
      pinActionsToBottom: widget.pinActionsToBottom,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: widget.density,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
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
        submitLabel,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: widget.submitLeadingIcon,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? reason = _reason?.trim();
    if (reason == null || reason.isEmpty) {
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
        leadingIcon: const Icon(AppActionIcons.decision),
      ),
  ];
}
