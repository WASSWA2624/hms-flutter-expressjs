import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

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
  IconData? cancelIcon,
  List<AppWorkspaceMutationAction> extraActions =
      const <AppWorkspaceMutationAction>[],
  Widget? icon,
  double maxWidth = 600,
  bool initialMaximized = true,
  bool barrierDismissible = false,
  bool showCancelButton = true,
  bool scrollable = true,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppWorkspaceMutationDialog(
      title: title,
      icon: icon,
      maxWidth: maxWidth,
      initialMaximized: initialMaximized,
      scrollable: scrollable,
      buildFields: buildFields,
      onSubmit: onSubmit,
      cancelLabel: cancelLabel,
      submitLabel: submitLabel,
      submitIcon: submitIcon,
      cancelIcon: cancelIcon,
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
    this.cancelIcon,
    this.extraActions = const <AppWorkspaceMutationAction>[],
    this.maxWidth = 600,
    this.initialMaximized = true,
    this.showCancelButton = true,
    this.scrollable = true,
  });

  final Widget title;
  final Widget? icon;
  final double maxWidth;
  final bool initialMaximized;
  final bool scrollable;
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
  final IconData? cancelIcon;
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

    // Soft cancel (e.g. dismiss similarity review) keeps the form open without
    // treating the dismissal as a validation/conflict failure banner.
    if (failure.category == AppFailureCategory.cancelled) {
      setState(() {
        _failure = null;
        _isSubmitting = false;
      });
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  List<Widget> _buildActions(BuildContext context) {
    final Widget closeButton = AppButton.close(
      label: widget.cancelLabel,
      leadingIcon: widget.cancelIcon ?? AppActionIcons.cancel,
      enabled: !_isSubmitting,
      onPressed: _isSubmitting
          ? null
          : () => Navigator.of(context).pop(false),
    );
    final List<Widget> body = <Widget>[
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

    if (!widget.showCancelButton) {
      return body;
    }
    // Two-action: [Close, Primary] so AppDialog reverses Close to the right.
    // Longer footers keep Close trailing (no reverse for length > 2).
    if (widget.extraActions.isEmpty) {
      return <Widget>[closeButton, ...body];
    }
    return <Widget>[...body, closeButton];
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      icon: widget.icon,
      scrollable: widget.scrollable,
      pinActionsToBottom: true,
      maxWidth: widget.maxWidth,
      initialMaximized: widget.initialMaximized,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          widget.buildFields(context, _formKey, _isSubmitting, _failure),
        ],
      ),
      actions: _buildActions(context),
    );
  }
}
