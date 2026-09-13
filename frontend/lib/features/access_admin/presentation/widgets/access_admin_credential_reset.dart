import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Confirms, then issues a single-use credential reset for [user] and reports
/// where the link went.
///
/// A failure stays inside the confirm dialog so the admin can retry or cancel.
/// Returns true only when the API issued a reset.
Future<bool> confirmAccessAdminCredentialReset(
  BuildContext context, {
  required AccessAdminItem user,
  required Future<Result<AccessAdminCredentialResetResult>> Function() issue,
}) async {
  final AppLocalizations l10n = context.l10n;
  AccessAdminCredentialResetResult? issued;

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.accessAdminResetCredentialsConfirmTitle,
      body: l10n.accessAdminResetCredentialsConfirmBody(user.title),
      highlightedText: user.title,
      submitLabel: l10n.accessAdminResetCredentialsAction,
      submitLeadingIcon: Icons.lock_reset_outlined,
      icon: const Icon(Icons.lock_reset_outlined),
      onConfirm: () async {
        final Result<AccessAdminCredentialResetResult> result = await issue();
        return result.when(
          success: (AccessAdminCredentialResetResult value) {
            issued = value;
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    ),
  );

  final AccessAdminCredentialResetResult? result = issued;
  if (confirmed != true || result == null || !context.mounted) {
    return false;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(accessAdminCredentialResetMessage(l10n, result))),
    );
  return true;
}

/// Truthful outcome copy: only an explicit SENT is reported as delivered.
String accessAdminCredentialResetMessage(
  AppLocalizations l10n,
  AccessAdminCredentialResetResult result,
) {
  final String destination =
      (result.maskedEmail ?? '').trim().isNotEmpty
      ? result.maskedEmail!.trim()
      : l10n.accessAdminResetCredentialsUnknownDestination;
  return switch (result.delivery) {
    AccessAdminCredentialDelivery.sent =>
      l10n.accessAdminResetCredentialsSentMessage(destination),
    AccessAdminCredentialDelivery.pending =>
      l10n.accessAdminResetCredentialsPendingMessage(destination),
    AccessAdminCredentialDelivery.failed =>
      l10n.accessAdminResetCredentialsFailedMessage,
  };
}
