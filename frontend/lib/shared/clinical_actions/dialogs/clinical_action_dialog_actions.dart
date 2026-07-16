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
}) {
  final bool canInteract = enabled && !isSaving;
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  return <Widget>[
    if (showCancel)
      AppButton.secondary(
        label: cancelLabel ?? context.l10n.commonCancelActionLabel,
        leadingIcon: AppActionIcons.cancel,
        enabled: canInteract,
        onPressed: canInteract
            ? () => Navigator.of(context).pop(false)
            : null,
      ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon:
          submitLeadingIcon ?? (destructive ? AppActionIcons.delete : null),
      color: destructive ? colorScheme.error : null,
      isLoading: isSaving,
      enabled: canInteract && onSubmit != null,
      onPressed: canInteract ? onSubmit : null,
    ),
  ];
}
