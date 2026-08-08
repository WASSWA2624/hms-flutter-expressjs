import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Explains that sign-in is blocked until a platform admin approves the account.
Future<void> showAuthPendingApprovalDialog(
  BuildContext context, {
  required List<AuthPlatformAdminContact> contacts,
  bool emailJustVerified = false,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => AuthPendingApprovalDialog(
      contacts: contacts,
      emailJustVerified: emailJustVerified,
    ),
  );
}

class AuthPendingApprovalDialog extends StatelessWidget {
  const AuthPendingApprovalDialog({
    required this.contacts,
    this.emailJustVerified = false,
    super.key,
  });

  final List<AuthPlatformAdminContact> contacts;
  final bool emailJustVerified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<AuthPlatformAdminContact> resolvedContacts = contacts
        .where((AuthPlatformAdminContact c) => c.hasContactDetails)
        .toList(growable: false);

    return AppDialog(
      title: Text(
        emailJustVerified
            ? l10n.authEmailVerifiedTitle
            : l10n.authAccountPendingApprovalTitle,
      ),
      scrollable: true,
      pinActionsToBottom: true,
      initialMaximized: true,
      maxWidth: 640,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            emailJustVerified
                ? l10n.authEmailVerifiedAwaitingApprovalBody
                : l10n.authAccountPendingApprovalMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (resolvedContacts.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.xl),
            Text(
              l10n.authAccountPendingApprovalContactHint,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            for (int i = 0; i < resolvedContacts.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: theme.spacing.md),
              _AdminContactCard(contact: resolvedContacts[i]),
            ],
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _AdminContactCard extends StatelessWidget {
  const _AdminContactCard({required this.contact});

  final AuthPlatformAdminContact contact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? name = contact.fullName?.trim();
    final String? email = contact.email?.trim();
    final String? phone = contact.phone?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (name != null && name.isNotEmpty)
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            if (email != null && email.isNotEmpty) ...<Widget>[
              if (name != null && name.isNotEmpty)
                SizedBox(height: theme.spacing.xs),
              Text(
                l10n.authAccountPendingApprovalEmailLine(email),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (phone != null && phone.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.authAccountPendingApprovalPhoneLine(phone),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
