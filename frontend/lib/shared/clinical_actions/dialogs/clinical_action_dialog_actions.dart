import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

List<Widget> clinicalActionDialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback? onSubmit, {
  bool showCancel = true,
  IconData? submitLeadingIcon,
  bool destructive = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  return <Widget>[
    if (showCancel)
      AppButton.secondary(
        label: l10n.commonCancelActionLabel,
        leadingIcon: AppActionIcons.cancel,
        enabled: !isSaving,
        onPressed: isSaving
            ? null
            : () => Navigator.of(context).pop(false),
      ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon:
          submitLeadingIcon ?? (destructive ? AppActionIcons.delete : null),
      color: destructive ? colorScheme.error : null,
      isLoading: isSaving,
      enabled: onSubmit != null,
      onPressed: onSubmit,
    ),
  ];
}
