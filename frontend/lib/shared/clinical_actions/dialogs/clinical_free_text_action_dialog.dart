import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalFreeTextActionDialog extends StatefulWidget {
  const ClinicalFreeTextActionDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.onSubmit,
    this.sectionTitle,
    this.description,
    this.initialValue,
    this.leadingContent = const <Widget>[],
    this.icon = const Icon(Icons.edit_note_outlined),
    this.prefixIcon,
    this.submitLeadingIcon,
    this.minLines,
    this.maxLines = 5,
    this.maxWidth = 720,
    this.autofocus = true,
    this.isRequired = true,
    this.cancelAfterPrimary = false,
    super.key,
  });

  final String title;
  final String? sectionTitle;
  final String? description;
  final String label;
  final String submitLabel;
  final Widget icon;
  final Widget? prefixIcon;
  final IconData? submitLeadingIcon;
  final String? initialValue;
  final List<Widget> leadingContent;
  final int? minLines;
  final int maxLines;
  final double maxWidth;
  final bool autofocus;
  final bool isRequired;

  /// When true, Cancel is rendered to the right of the primary submit button.
  final bool cancelAfterPrimary;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<ClinicalFreeTextActionDialog> createState() =>
      _ClinicalFreeTextActionDialogState();
}

class _ClinicalFreeTextActionDialogState
    extends State<ClinicalFreeTextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: widget.sectionTitle,
          description: widget.description,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ...widget.leadingContent,
            AppTextField(
              controller: _controller,
              labelText: widget.label,
              prefixIcon: widget.prefixIcon,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              enabled: !_isSaving,
              isRequired: widget.isRequired,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.sentences,
              validator: widget.isRequired
                  ? AppValidators.requiredText(l10n.validationRequired)
                  : null,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel,
        _isSaving,
        _submit,
        submitLeadingIcon: widget.submitLeadingIcon,
        cancelAfterPrimary: widget.cancelAfterPrimary,
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
