import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

class AuthFailureText extends StatelessWidget {
  const AuthFailureText({required this.failure, super.key});

  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      _messageFor(AppLocalizations.of(context), failure),
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
    );
  }

  static String _messageFor(AppLocalizations l10n, AppFailure failure) {
    if (failure.code == 'auth.account_pending') {
      return l10n.authAccountPendingMessage;
    }
    if (failure.code == 'auth.account_not_found') {
      return l10n.authAccountNotFoundMessage;
    }
    if (failure.code == 'auth.wrong_password') {
      return l10n.authWrongPasswordMessage;
    }
    if (failure.code == 'network.rate_limited') {
      return l10n.authRateLimitedMessage;
    }

    return switch (failure.category) {
      AppFailureCategory.unauthorized => l10n.authInvalidCredentialsMessage,
      AppFailureCategory.forbidden => l10n.authForbiddenMessage,
      AppFailureCategory.validation => l10n.errorValidationMessage,
      AppFailureCategory.offline => l10n.errorOfflineMessage,
      AppFailureCategory.timeout => l10n.errorTimeoutMessage,
      AppFailureCategory.network => l10n.errorNetworkMessage,
      _ => l10n.errorUnexpectedMessage,
    };
  }
}
