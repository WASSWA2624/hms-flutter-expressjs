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

  /// When false, Close and primary stay disabled without a submit spinner
  /// (e.g. parent reference-data load). [isSaving] still drives isLoading.
  bool enabled = true,
  String? cancelLabel,
  VoidCallback? onCancel,

  /// Value popped when Close is pressed. Defaults to `false` for bool
  /// confirmation dialogs; pass `null` when the route returns an entity.
  Object? cancelResult = false,

  /// When true, Close is placed after the primary in the actions list.
  /// Prefer false (default): author [Close, Primary] so [AppDialog] can
  /// reverse two-action footers and render Close extreme-right.
  bool cancelAfterPrimary = false,
  double? borderRadius,
}) {
  final bool canInteract = enabled && !isSaving;
  final ThemeData theme = Theme.of(context);
  final ColorScheme colorScheme = theme.colorScheme;
  final Widget? cancelButton = showCancel
      ? AppButton.secondary(
          label: cancelLabel ?? context.l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: canInteract,
          borderRadius: borderRadius,
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
    borderRadius: borderRadius,
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
