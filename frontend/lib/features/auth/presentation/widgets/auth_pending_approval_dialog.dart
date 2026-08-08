import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
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
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<AuthPlatformAdminContact> resolvedContacts = contacts
        .where((AuthPlatformAdminContact c) => c.hasContactDetails)
        .map(_sanitizeContact)
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
      maxWidth: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PendingStatusCallout(
            title: l10n.authAccountPendingApprovalStatusLabel,
            message: emailJustVerified
                ? l10n.authEmailVerifiedAwaitingApprovalBody
                : l10n.authAccountPendingApprovalMessage,
          ),
          if (resolvedContacts.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.xl),
            Text(
              l10n.authAccountPendingApprovalContactsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              l10n.authAccountPendingApprovalContactHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            for (int i = 0; i < resolvedContacts.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: theme.spacing.sm),
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

class _PendingStatusCallout extends StatelessWidget {
  const _PendingStatusCallout({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(theme.radius.sm),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: colors.primary,
                size: 22,
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminContactCard extends StatelessWidget {
  const _AdminContactCard({required this.contact});

  final AuthPlatformAdminContact contact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String displayName = _displayName(l10n);
    final String? roleLabel = _roleLabel(l10n);
    final String? email = contact.email?.trim();
    final String? phone = contact.phone?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(
                _initials(displayName),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                  if (roleLabel != null) ...<Widget>[
                    SizedBox(height: 2),
                    Text(
                      roleLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ],
                  if (email != null && email.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.sm),
                    _ContactLine(
                      icon: Icons.mail_outline_rounded,
                      value: email,
                      copyTooltip: l10n.subscriptionReportCopyEmailAction,
                      copiedMessage: l10n.subscriptionReportEmailCopiedMessage,
                    ),
                  ],
                  if (phone != null && phone.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    _ContactLine(
                      icon: Icons.phone_outlined,
                      value: phone,
                      copyTooltip: l10n.subscriptionReportCopyPhoneAction,
                      copiedMessage: l10n.subscriptionReportPhoneCopiedMessage,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(AppLocalizations l10n) {
    final String? name = contact.fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (contact.isSupportChannel) {
      return l10n.subscriptionReportPlatformSupportName;
    }
    final String? email = contact.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return l10n.subscriptionReportPlatformSupportName;
  }

  String? _roleLabel(AppLocalizations l10n) {
    if (contact.isSupportChannel) {
      return l10n.subscriptionReportPlatformSupportRoleLabel;
    }
    final String? role = contact.roleName?.trim();
    if (role == null || role.isEmpty) {
      return l10n.authAccountPendingApprovalAdminRoleLabel;
    }
    return role.replaceAll('_', ' ');
  }

  String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final String token = parts.first;
      return token.substring(0, token.length >= 1 ? 1 : 0).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.value,
    required this.copyTooltip,
    required this.copiedMessage,
  });

  final IconData icon;
  final String value;
  final String copyTooltip;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: colors.primary),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: AppCopyableIdentifier(
            value: value,
            tooltip: copyTooltip,
            copiedTooltip: copiedMessage,
            copiedMessage: copiedMessage,
            semanticLabel: '$copyTooltip: $value',
            maxLines: 2,
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: AppFontWeight.emphasis,
              color: colors.onSurface,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

AuthPlatformAdminContact _sanitizeContact(AuthPlatformAdminContact contact) {
  final String? email = contact.email?.trim();
  final String? phone = contact.phone?.trim();
  return AuthPlatformAdminContact(
    fullName: contact.fullName,
    email: email != null && email.isNotEmpty ? email : null,
    phone: _isDisplayablePhone(phone) ? phone : null,
    roleName: contact.roleName,
    isSupportChannel: contact.isSupportChannel,
  );
}

bool _isDisplayablePhone(String? phone) {
  final String? value = phone?.trim();
  if (value == null || value.isEmpty) {
    return false;
  }
  if (!RegExp(r'^[\d\s+\-().]+$').hasMatch(value)) {
    return false;
  }
  final String digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7;
}
