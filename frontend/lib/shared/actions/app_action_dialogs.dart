import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Shared confirmation dialog for module actions that either return a boolean
/// confirmation or run an async action before closing.
class AppConfirmActionDialog extends StatefulWidget {
  const AppConfirmActionDialog({
    required this.title,
    required this.body,
    required this.submitLabel,
    this.onConfirm,
    this.icon = const Icon(Icons.help_outline),
    this.maxWidth = 600,
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
  final double maxWidth;
  final Future<AppFailure?> Function()? onConfirm;

  @override
  State<AppConfirmActionDialog> createState() => _AppConfirmActionDialogState();
}

class _AppConfirmActionDialogState extends State<AppConfirmActionDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      closeEnabled: !_isSaving,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          Text(widget.body),
        ],
      ),
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final Future<AppFailure?> Function()? onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await onConfirm();
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

/// Shared free-text action dialog for notes, summaries, handovers, and similar
/// module workflows.
class AppTextActionDialog extends StatefulWidget {
  const AppTextActionDialog({
    required this.title,
    required this.fieldLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.icon = const Icon(Icons.edit_note_outlined),
    this.description,
    this.sectionTitle,
    this.initialValue,
    this.prefixIcon,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxWidth = 720,
    this.autofocus = true,
    this.isRequired = true,
    super.key,
  });

  final String title;
  final String? sectionTitle;
  final String? description;
  final String fieldLabel;
  final String submitLabel;
  final Widget icon;
  final Widget? prefixIcon;
  final String? initialValue;
  final int minLines;
  final int maxLines;
  final double maxWidth;
  final bool autofocus;
  final bool isRequired;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<AppTextActionDialog> createState() => _AppTextActionDialogState();
}

class _AppTextActionDialogState extends State<AppTextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _controller,
              labelText: widget.fieldLabel,
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
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
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

List<Widget> _actionDialogButtons(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}
