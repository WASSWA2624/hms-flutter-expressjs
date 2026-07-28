import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

Future<void> showSubscriptionReportAdminsDialog(
  BuildContext context, {
  required TenantSubscriptionHeaderState headerState,
  required List<OrgAdminContact> tenantAdmins,
  required List<OrgAdminContact> facilityAdmins,
  PlatformAdminContact? platformAdminContact,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return SubscriptionReportAdminsDialog(
        headerState: headerState,
        tenantAdmins: tenantAdmins,
        facilityAdmins: facilityAdmins,
        platformAdminContact: platformAdminContact,
      );
    },
  );
}

class SubscriptionReportAdminsDialog extends ConsumerStatefulWidget {
  const SubscriptionReportAdminsDialog({
    required this.headerState,
    required this.tenantAdmins,
    required this.facilityAdmins,
    this.platformAdminContact,
    super.key,
  });

  final TenantSubscriptionHeaderState headerState;
  final List<OrgAdminContact> tenantAdmins;
  final List<OrgAdminContact> facilityAdmins;
  final PlatformAdminContact? platformAdminContact;

  @override
  ConsumerState<SubscriptionReportAdminsDialog> createState() =>
      _SubscriptionReportAdminsDialogState();
}

class _SubscriptionReportAdminsDialogState
    extends ConsumerState<SubscriptionReportAdminsDialog> {
  late List<OrgAdminContact> _tenantAdmins;
  late List<OrgAdminContact> _facilityAdmins;
  PlatformAdminContact? _platformAdminContact;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tenantAdmins = widget.tenantAdmins;
    _facilityAdmins = widget.facilityAdmins;
    _platformAdminContact = widget.platformAdminContact;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshContacts());
    });
  }

  Future<void> _refreshContacts() async {
    final AuthSession? session = ref.read(sessionStateProvider).session;
    if (session == null || _refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    final result = await ref
        .read(authRepositoryProvider)
        .fetchCurrentUser(session);
    if (!mounted) {
      return;
    }
    result.when(
      success: (AuthSession refreshed) {
        ref.read(sessionStateProvider.notifier).persistSession(refreshed);
        setState(() {
          _tenantAdmins = refreshed.tenantAdminContacts;
          _facilityAdmins = refreshed.facilityAdminContacts;
          _platformAdminContact = refreshed.platformAdminContact;
          _refreshing = false;
        });
      },
      failure: (_) {
        setState(() => _refreshing = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool expired =
        widget.headerState == TenantSubscriptionHeaderState.expired;
    final PlatformAdminContact? platform =
        _platformAdminContact?.hasContact == true
        ? _platformAdminContact
        : null;
    final bool hasOrgContacts =
        _tenantAdmins.isNotEmpty || _facilityAdmins.isNotEmpty;

    return AppDialog(
      title: Text(
        expired
            ? l10n.subscriptionExpiredPromptTitle
            : l10n.subscriptionReportAdminsDialogTitle,
      ),
      icon: Icon(
        expired ? Icons.error_outline : Icons.support_agent_outlined,
        color: expired ? colorScheme.error : null,
      ),
      maxWidth: 520,
      initialMaximized: false,
      showMaximizeButton: false,
      resizable: false,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppMessagePanel(
            title: expired
                ? l10n.subscriptionExpiredRiskTitle
                : l10n.subscriptionReportRiskTitle,
            message: expired
                ? l10n.subscriptionExpiredPromptContactAdminBody
                : l10n.subscriptionReportAdminsDialogBody,
            icon: Icons.priority_high_rounded,
            tone: AppWorkspaceStatusTone.error,
            density: AppContentPanelDensity.compact,
          ),
          SizedBox(height: theme.spacing.md),
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_facilityAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportFacilityAdminsLabel,
              contacts: _facilityAdmins,
              roleFallback: l10n.subscriptionReportFacilityAdminRoleLabel,
              leadingIcon: Icons.apartment_outlined,
              tone: AppWorkspaceStatusTone.error,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (_tenantAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportTenantAdminsLabel,
              contacts: _tenantAdmins,
              roleFallback: l10n.subscriptionReportTenantAdminRoleLabel,
              leadingIcon: Icons.business_outlined,
              tone: AppWorkspaceStatusTone.error,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (platform != null)
            _PlatformContactPanel(
              contact: platform,
              tone: AppWorkspaceStatusTone.error,
            )
          else if (!_refreshing && !hasOrgContacts)
            AppMessagePanel(
              message: l10n.subscriptionReportAdminsEmptyMessage,
              icon: Icons.info_outline,
              tone: AppWorkspaceStatusTone.warning,
              density: AppContentPanelDensity.compact,
            ),
        ],
      ),
      actions: <Widget>[
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.check, size: 18),
          label: Text(l10n.subscriptionExpiredPromptContactAdminAction),
        ),
      ],
    );
  }
}

class _PlatformContactPanel extends StatelessWidget {
  const _PlatformContactPanel({required this.contact, required this.tone});

  final PlatformAdminContact contact;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.subscriptionReportPlatformSupportLabel,
      leadingIcon: Icons.support_agent_outlined,
      tone: tone,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        _AdminContactCard(
          contact: OrgAdminContact(
            fullName: l10n.subscriptionReportPlatformSupportName,
            email: contact.email,
            phone: contact.phone,
            roleName: l10n.subscriptionReportPlatformSupportRoleLabel,
          ),
          roleFallback: l10n.subscriptionReportPlatformSupportRoleLabel,
        ),
      ],
    );
  }
}

class _AdminContactGroup extends StatelessWidget {
  const _AdminContactGroup({
    required this.title,
    required this.contacts,
    required this.roleFallback,
    required this.leadingIcon,
    required this.tone,
  });

  final String title;
  final List<OrgAdminContact> contacts;
  final String roleFallback;
  final IconData leadingIcon;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppSectionPanel(
      title: title,
      leadingIcon: leadingIcon,
      tone: tone,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        for (int index = 0; index < contacts.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          _AdminContactCard(
            contact: contacts[index],
            roleFallback: roleFallback,
          ),
        ],
      ],
    );
  }
}

class _AdminContactCard extends StatelessWidget {
  const _AdminContactCard({required this.contact, required this.roleFallback});

  final OrgAdminContact contact;
  final String roleFallback;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String roleLabel = contact.roleName?.trim().isNotEmpty == true
        ? contact.roleName!.trim().replaceAll('_', ' ')
        : roleFallback;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
          child: Text(
            _initials(contact.displayName),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                contact.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                roleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (contact.email != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                _ContactLine(
                  icon: Icons.mail_outline,
                  label: l10n.subscriptionUpgradeAdminContactEmailLabel,
                  value: contact.email!,
                ),
              ],
              if (contact.phone != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                _ContactLine(
                  icon: Icons.phone_outlined,
                  label: l10n.subscriptionUpgradeAdminContactPhoneLabel,
                  value: contact.phone!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label: $value',
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.error),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
