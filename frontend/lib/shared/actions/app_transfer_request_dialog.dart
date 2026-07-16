import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Domain-neutral transfer-request chrome shared by ICU / IPD ward moves.
///
/// Callers supply localized copy and resolved ward options. Mutation stays in
/// the feature controller via [onSubmit]; this widget never calls APIs.
class AppTransferRequestDialog extends StatefulWidget {
  const AppTransferRequestDialog({
    required this.title,
    required this.wardLabel,
    required this.submitLabel,
    required this.requiredMessage,
    required this.onSubmit,
    this.wardOptions = const <AppSelectOption<String>>[],
    this.wardIdLabel,
    this.wardHint,
    this.semanticLabel,
    this.icon = const Icon(AppActionIcons.transfer),
    this.submitLeadingIcon = AppActionIcons.transfer,
    this.maxWidth = 600,
    super.key,
  });

  final String title;
  final String? semanticLabel;
  final String wardLabel;
  final String? wardIdLabel;
  final String? wardHint;
  final String submitLabel;
  final String requiredMessage;
  final List<AppSelectOption<String>> wardOptions;
  final Widget icon;
  final IconData submitLeadingIcon;
  final double maxWidth;
  final Future<AppFailure?> Function(String toWardId) onSubmit;

  @override
  State<AppTransferRequestDialog> createState() =>
      _AppTransferRequestDialogState();
}

class _AppTransferRequestDialogState extends State<AppTransferRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _wardIdController;
  String? _wardId;
  bool _isSaving = false;
  AppFailure? _failure;

  bool get _hasWardOptions => widget.wardOptions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _wardIdController = TextEditingController();
  }

  @override
  void dispose() {
    _wardIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      semanticLabel: widget.semanticLabel,
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: widget.maxWidth,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_hasWardOptions)
            AppSelectField<String>.searchable(
              value: _wardId,
              labelText: widget.wardLabel,
              hintText: widget.wardHint,
              enabled: !_isSaving,
              isRequired: true,
              options: widget.wardOptions,
              onChanged: _isSaving
                  ? null
                  : (String? value) => setState(() => _wardId = value),
              validator: AppValidators.requiredValue<String>(
                widget.requiredMessage,
              ),
            )
          else
            AppTextField(
              controller: _wardIdController,
              labelText: widget.wardIdLabel ?? widget.wardLabel,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(widget.requiredMessage),
            ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel,
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
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String toWardId = _hasWardOptions
        ? (_wardId ?? '').trim()
        : _wardIdController.text.trim();
    if (toWardId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(toWardId);
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

/// Opens [AppTransferRequestDialog] with mutating-dialog dismiss rules.
Future<bool?> showAppTransferRequestDialog({
  required BuildContext context,
  required String title,
  required String wardLabel,
  required String submitLabel,
  required String requiredMessage,
  required Future<AppFailure?> Function(String toWardId) onSubmit,
  List<AppSelectOption<String>> wardOptions = const <AppSelectOption<String>>[],
  String? wardIdLabel,
  String? wardHint,
  String? semanticLabel,
  Widget icon = const Icon(AppActionIcons.transfer),
  IconData submitLeadingIcon = AppActionIcons.transfer,
  double maxWidth = 600,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppTransferRequestDialog(
      title: title,
      wardLabel: wardLabel,
      wardIdLabel: wardIdLabel,
      wardHint: wardHint,
      submitLabel: submitLabel,
      requiredMessage: requiredMessage,
      wardOptions: wardOptions,
      semanticLabel: semanticLabel,
      icon: icon,
      submitLeadingIcon: submitLeadingIcon,
      maxWidth: maxWidth,
      onSubmit: onSubmit,
    ),
  );
}
