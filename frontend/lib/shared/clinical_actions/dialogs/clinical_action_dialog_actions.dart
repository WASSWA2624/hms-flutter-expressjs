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
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    if (showCancel)
      AppButton.tertiary(
        label: l10n.commonCancelActionLabel,
        leadingIcon: AppActionIcons.cancel,
        enabled: !isSaving,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitLeadingIcon,
      isLoading: isSaving,
      enabled: onSubmit != null,
      onPressed: onSubmit,
    ),
  ];
}
