import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';

@immutable
final class AppWorkspaceMutationAction {
  const AppWorkspaceMutationAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final Future<AppFailure?> Function() onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDestructive;
}

/// Shows a workspace dialog with scrollable form content and fixed footer actions.
///
/// [buildFields] receives the shared [FormState] key; validation runs before
/// [onSubmit]. The dialog stays open on failure and closes with `true` on success.
Future<bool?> showAppWorkspaceMutationDialog({
  required BuildContext context,
  required Widget title,
  required Widget Function(
    BuildContext context,
    GlobalKey<FormState> formKey,
    bool isSubmitting, [
    AppFailure? failure,
  ])
  buildFields,
  required Future<AppFailure?> Function() onSubmit,
  required String cancelLabel,
  required String submitLabel,
  IconData? submitIcon,
  List<AppWorkspaceMutationAction> extraActions =
      const <AppWorkspaceMutationAction>[],
  Widget? icon,
  double maxWidth = 600,
  bool initialMaximized = false,
  bool barrierDismissible = false,
  bool showCancelButton = true,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppWorkspaceMutationDialog(
      title: title,
      icon: icon,
      maxWidth: maxWidth,
      initialMaximized: initialMaximized,
      buildFields: buildFields,
      onSubmit: onSubmit,
      cancelLabel: cancelLabel,
      submitLabel: submitLabel,
      submitIcon: submitIcon,
      extraActions: extraActions,
      showCancelButton: showCancelButton,
    ),
  );
}

class _AppWorkspaceMutationDialog extends StatefulWidget {
  const _AppWorkspaceMutationDialog({
    required this.title,
    required this.buildFields,
    required this.onSubmit,
    required this.cancelLabel,
    required this.submitLabel,
    this.icon,
    this.submitIcon,
    this.extraActions = const <AppWorkspaceMutationAction>[],
    this.maxWidth = 600,
    this.initialMaximized = false,
    this.showCancelButton = true,
  });

  final Widget title;
  final Widget? icon;
  final double maxWidth;
  final bool initialMaximized;
  final Widget Function(
    BuildContext context,
    GlobalKey<FormState> formKey,
    bool isSubmitting, [
    AppFailure? failure,
  ])
  buildFields;
  final Future<AppFailure?> Function() onSubmit;
  final String cancelLabel;
  final String submitLabel;
  final IconData? submitIcon;
  final List<AppWorkspaceMutationAction> extraActions;
  final bool showCancelButton;

  @override
  State<_AppWorkspaceMutationDialog> createState() =>
      _AppWorkspaceMutationDialogState();
}

class _AppWorkspaceMutationDialogState
    extends State<_AppWorkspaceMutationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  AppFailure? _failure;

  Future<void> _runSubmit(Future<AppFailure?> Function() submit) async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await submit();
    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  List<Widget> _buildActions(BuildContext context) {
    final List<Widget> actions = <Widget>[
      if (widget.showCancelButton)
        AppButton.tertiary(
          label: widget.cancelLabel,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
      for (final AppWorkspaceMutationAction action in widget.extraActions)
        action.isDestructive
            ? AppButton.tertiary(
                label: action.label,
                leadingIcon: action.icon,
                enabled: !_isSubmitting,
                onPressed: _isSubmitting
                    ? null
                    : () => _runSubmit(action.onPressed),
              )
            : action.isPrimary
            ? AppButton.primary(
                label: action.label,
                leadingIcon: action.icon,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting
                    ? null
                    : () => _runSubmit(action.onPressed),
              )
            : AppButton.secondary(
                label: action.label,
                leadingIcon: action.icon,
                enabled: !_isSubmitting,
                onPressed: _isSubmitting
                    ? null
                    : () => _runSubmit(action.onPressed),
              ),
      AppButton.primary(
        label: widget.submitLabel,
        leadingIcon: widget.submitIcon,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : () => _runSubmit(widget.onSubmit),
      ),
    ];

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      icon: widget.icon,
      scrollable: true,
      maxWidth: widget.maxWidth,
      initialMaximized: widget.initialMaximized,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: <Widget>[
          widget.buildFields(context, _formKey, _isSubmitting, _failure),
        ],
      ),
      actions: _buildActions(context),
    );
  }
}
