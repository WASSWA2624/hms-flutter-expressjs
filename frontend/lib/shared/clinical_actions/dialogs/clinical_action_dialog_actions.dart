import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

List<Widget> clinicalActionDialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback? onSubmit, {
  bool showCancel = true,
  IconData? submitLeadingIcon,
  bool destructive = false,

  /// When false, Cancel and primary stay disabled without a submit spinner
  /// (e.g. parent reference-data load). [isSaving] still drives isLoading.
  bool enabled = true,
  String? cancelLabel,
  VoidCallback? onCancel,

  /// Value popped when Cancel is pressed. Defaults to `false` for bool
  /// confirmation dialogs; pass `null` when the route returns an entity.
  Object? cancelResult = false,

  /// When true, Cancel is placed after the primary submit action.
  bool cancelAfterPrimary = false,
}) {
  final bool canInteract = enabled && !isSaving;
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final Widget? cancelButton = showCancel
      ? AppButton.secondary(
          label: cancelLabel ?? context.l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: canInteract,
          onPressed: canInteract
              ? onCancel ?? () => Navigator.of(context).pop(cancelResult)
              : null,
        )
      : null;
  final Widget primaryButton = AppButton.primary(
    label: submitLabel,
    leadingIcon:
        submitLeadingIcon ?? (destructive ? AppActionIcons.delete : null),
    color: destructive ? colorScheme.error : null,
    isLoading: isSaving,
    enabled: canInteract && onSubmit != null,
    onPressed: canInteract ? onSubmit : null,
  );
  if (cancelButton == null) {
    return <Widget>[primaryButton];
  }
  if (cancelAfterPrimary) {
    return <Widget>[primaryButton, cancelButton];
  }
  return <Widget>[cancelButton, primaryButton];
}
