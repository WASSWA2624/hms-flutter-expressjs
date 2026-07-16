import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Opens the IPD release-bed confirmation dialog (mutating; not barrier-dismissible).
///
/// On confirm, runs [onConfirm]. Persisted success pops `true`; Cancel pops
/// `false`; failure keeps the dialog open with shared failure UI and patches
/// nothing.
Future<bool?> showIpdReleaseBedDialog({
  required BuildContext context,
  required Future<AppFailure?> Function() onConfirm,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => IpdReleaseBedDialog(onConfirm: onConfirm),
  );
}

/// Confirm release of the active IPD bed assignment for an admission.
class IpdReleaseBedDialog extends StatelessWidget {
  const IpdReleaseBedDialog({required this.onConfirm, super.key});

  final Future<AppFailure?> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppConfirmActionDialog(
      title: l10n.ipdReleaseBedAction,
      body: l10n.ipdReleaseBedConfirmationBody,
      submitLabel: l10n.ipdReleaseBedAction,
      icon: const Icon(AppActionIcons.cleaning),
      submitLeadingIcon: AppActionIcons.cleaning,
      onConfirm: onConfirm,
    );
  }
}
