import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
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

class SubscriptionReportAdminsDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool expired = headerState == TenantSubscriptionHeaderState.expired;
    final PlatformAdminContact? platform = platformAdminContact?.hasContact == true
        ? platformAdminContact
        : null;
    final bool hasOrgContacts =
        tenantAdmins.isNotEmpty || facilityAdmins.isNotEmpty;
    final bool hasAnyContacts = hasOrgContacts || platform != null;

    return AppDialog(
      title: Text(
        expired
            ? l10n.subscriptionExpiredPromptTitle
            : l10n.subscriptionReportAdminsDialogTitle,
      ),
      icon: Icon(
        expired ? Icons.warning_amber_rounded : Icons.support_agent_outlined,
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
          Text(
            expired
                ? l10n.subscriptionExpiredPromptContactAdminBody
                : l10n.subscriptionReportAdminsDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (facilityAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportFacilityAdminsLabel,
              contacts: facilityAdmins,
              roleFallback: l10n.subscriptionReportFacilityAdminRoleLabel,
              leadingIcon: Icons.apartment_outlined,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (tenantAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportTenantAdminsLabel,
              contacts: tenantAdmins,
              roleFallback: l10n.subscriptionReportTenantAdminRoleLabel,
              leadingIcon: Icons.business_outlined,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (platform != null)
            _PlatformContactPanel(contact: platform)
          else if (!hasAnyContacts)
            AppMessagePanel(
              message: l10n.subscriptionReportAdminsEmptyMessage,
              icon: Icons.info_outline,
              tone: AppWorkspaceStatusTone.warning,
              density: AppContentPanelDensity.compact,
            ),
        ],
      ),
      actions: buildAppDialogWizardActions(
        cancelLabel: l10n.commonCloseActionLabel,
        primaryLabel: l10n.subscriptionExpiredPromptContactAdminAction,
        onCancel: () => Navigator.of(context).maybePop(),
        onPrimary: () => Navigator.of(context).maybePop(),
        primaryIcon: Icons.check,
      ),
    );
  }
}

class _PlatformContactPanel extends StatelessWidget {
  const _PlatformContactPanel({required this.contact});

  final PlatformAdminContact contact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.subscriptionReportPlatformSupportLabel,
      leadingIcon: Icons.support_agent_outlined,
      tone: AppWorkspaceStatusTone.info,
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
  });

  final String title;
  final List<OrgAdminContact> contacts;
  final String roleFallback;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppSectionPanel(
      title: title,
      leadingIcon: leadingIcon,
      tone: AppWorkspaceStatusTone.info,
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
  const _AdminContactCard({
    required this.contact,
    required this.roleFallback,
  });

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
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            _initials(contact.displayName),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                roleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: colorScheme.primary),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
