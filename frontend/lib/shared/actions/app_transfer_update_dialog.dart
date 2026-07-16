import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Backend `update-transfer` action tokens shared by IPD / rooms & beds.
abstract final class AppTransferUpdateActions {
  static const String approve = 'APPROVE';
  static const String start = 'START';
  static const String complete = 'COMPLETE';
  static const String cancel = 'CANCEL';
}

/// Default next transfer action for an open transfer status.
String appTransferDefaultActionForStatus(String? transferStatus) {
  return switch ((transferStatus ?? '').trim().toUpperCase()) {
    'APPROVED' => AppTransferUpdateActions.start,
    'IN_PROGRESS' => AppTransferUpdateActions.complete,
    _ => AppTransferUpdateActions.approve,
  };
}

/// Whether [action] requires a destination bed id (`COMPLETE`).
bool appTransferRequiresDestinationBed(String action) {
  return action.trim().toUpperCase() == AppTransferUpdateActions.complete;
}

/// Domain-neutral transfer-update chrome shared by IPD and rooms & beds.
///
/// Callers supply localized copy, action options, and bed options. Mutation
/// stays in the feature controller via [onSubmit]; this widget never calls APIs.
class AppTransferUpdateDialog extends StatefulWidget {
  const AppTransferUpdateDialog({
    required this.title,
    required this.actionLabel,
    required this.actionOptions,
    required this.initialAction,
    required this.submitLabel,
    required this.requiredMessage,
    required this.onSubmit,
    this.destinationBedLabel,
    this.destinationBedHint,
    this.bedOptions = const <AppSelectOption<String>>[],
    this.semanticLabel,
    this.icon = const Icon(AppActionIcons.transfer),
    this.submitLeadingIcon = AppActionIcons.edit,
    this.maxWidth = 600,
    super.key,
  });

  final String title;
  final String? semanticLabel;
  final String actionLabel;
  final List<AppSelectOption<String>> actionOptions;
  final String initialAction;
  final String? destinationBedLabel;
  final String? destinationBedHint;
  final List<AppSelectOption<String>> bedOptions;
  final String submitLabel;
  final String requiredMessage;
  final Widget icon;
  final IconData submitLeadingIcon;
  final double maxWidth;
  final Future<AppFailure?> Function({
    required String action,
    String? toBedId,
  })
  onSubmit;

  @override
  State<AppTransferUpdateDialog> createState() =>
      _AppTransferUpdateDialogState();
}

class _AppTransferUpdateDialogState extends State<AppTransferUpdateDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _action;
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
  }

  @override
  Widget build(BuildContext context) {
    final bool needsBed = appTransferRequiresDestinationBed(_action);

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
          AppSelectField<String>(
            value: _action,
            labelText: widget.actionLabel,
            enabled: !_isSaving,
            options: widget.actionOptions,
            onChanged: _isSaving
                ? null
                : (String? value) {
                    if (value != null) {
                      setState(() => _action = value);
                    }
                  },
          ),
          if (needsBed)
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: widget.destinationBedLabel ?? '',
              hintText: widget.destinationBedHint,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredValue<String>(
                widget.requiredMessage,
              ),
              options: widget.bedOptions,
              onChanged: _isSaving
                  ? null
                  : (String? value) => setState(() => _bedId = value),
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
    final bool needsBed = appTransferRequiresDestinationBed(_action);
    if (needsBed && (_bedId == null || _bedId!.trim().isEmpty)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      action: _action,
      toBedId: needsBed ? _bedId : null,
    );
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

/// Opens [AppTransferUpdateDialog] with mutating-dialog dismiss rules.
Future<bool?> showAppTransferUpdateDialog({
  required BuildContext context,
  required String title,
  required String actionLabel,
  required List<AppSelectOption<String>> actionOptions,
  required String initialAction,
  required String submitLabel,
  required String requiredMessage,
  required Future<AppFailure?> Function({
    required String action,
    String? toBedId,
  })
  onSubmit,
  String? destinationBedLabel,
  String? destinationBedHint,
  List<AppSelectOption<String>> bedOptions = const <AppSelectOption<String>>[],
  String? semanticLabel,
  Widget icon = const Icon(AppActionIcons.transfer),
  IconData submitLeadingIcon = AppActionIcons.edit,
  double maxWidth = 600,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppTransferUpdateDialog(
      title: title,
      actionLabel: actionLabel,
      actionOptions: actionOptions,
      initialAction: initialAction,
      destinationBedLabel: destinationBedLabel,
      destinationBedHint: destinationBedHint,
      bedOptions: bedOptions,
      submitLabel: submitLabel,
      requiredMessage: requiredMessage,
      semanticLabel: semanticLabel,
      icon: icon,
      submitLeadingIcon: submitLeadingIcon,
      maxWidth: maxWidth,
      onSubmit: onSubmit,
    ),
  );
}
