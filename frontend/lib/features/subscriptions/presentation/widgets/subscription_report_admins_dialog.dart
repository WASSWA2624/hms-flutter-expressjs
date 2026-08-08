import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

Future<void> showSubscriptionReportAdminsDialog(
  BuildContext context, {
  required TenantSubscriptionSummary summary,
  required List<OrgAdminContact> tenantAdmins,
  required List<OrgAdminContact> facilityAdmins,
  List<OrgAdminContact> platformAdmins = const <OrgAdminContact>[],
  PlatformAdminContact? platformAdminContact,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return SubscriptionReportAdminsDialog(
        summary: summary,
        tenantAdmins: tenantAdmins,
        facilityAdmins: facilityAdmins,
        platformAdmins: platformAdmins,
        platformAdminContact: platformAdminContact,
      );
    },
  );
}

class SubscriptionReportAdminsDialog extends ConsumerStatefulWidget {
  const SubscriptionReportAdminsDialog({
    required this.summary,
    required this.tenantAdmins,
    required this.facilityAdmins,
    this.platformAdmins = const <OrgAdminContact>[],
    this.platformAdminContact,
    super.key,
  });

  final TenantSubscriptionSummary summary;
  final List<OrgAdminContact> tenantAdmins;
  final List<OrgAdminContact> facilityAdmins;
  final List<OrgAdminContact> platformAdmins;
  final PlatformAdminContact? platformAdminContact;

  @override
  ConsumerState<SubscriptionReportAdminsDialog> createState() =>
      _SubscriptionReportAdminsDialogState();
}

class _SubscriptionReportAdminsDialogState
    extends ConsumerState<SubscriptionReportAdminsDialog> {
  late TenantSubscriptionSummary _summary;
  late List<OrgAdminContact> _tenantAdmins;
  late List<OrgAdminContact> _facilityAdmins;
  late List<OrgAdminContact> _platformAdmins;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _tenantAdmins = widget.tenantAdmins;
    _facilityAdmins = widget.facilityAdmins;
    _platformAdmins = _resolvePlatformAdmins(
      listed: widget.platformAdmins,
      legacy: widget.platformAdminContact,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshContacts());
    });
  }

  List<OrgAdminContact> _resolvePlatformAdmins({
    required List<OrgAdminContact> listed,
    PlatformAdminContact? legacy,
  }) {
    if (listed.isNotEmpty) {
      return listed;
    }
    if (legacy == null || !legacy.hasContact) {
      return const <OrgAdminContact>[];
    }
    return <OrgAdminContact>[
      OrgAdminContact(
        email: legacy.email,
        phone: legacy.phone,
        roleName: 'PLATFORM_SUPPORT',
        isSupportChannel: true,
      ),
    ];
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
          _summary = refreshed.subscriptionSummary ?? _summary;
          _tenantAdmins = refreshed.tenantAdminContacts;
          _facilityAdmins = refreshed.facilityAdminContacts;
          _platformAdmins = _resolvePlatformAdmins(
            listed: refreshed.platformAdminContacts,
            legacy: refreshed.platformAdminContact,
          );
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
    final Locale locale = Localizations.localeOf(context);
    final TenantSubscriptionHeaderState headerState = _summary.headerState;
    final bool expired = headerState == TenantSubscriptionHeaderState.expired;
    final bool expiringSoon =
        headerState == TenantSubscriptionHeaderState.expiringSoon;
    final bool hasContacts =
        _tenantAdmins.isNotEmpty ||
        _facilityAdmins.isNotEmpty ||
        _platformAdmins.isNotEmpty;

    final bool freeTier =
        !_hasText(_summary.subscriptionId) ||
        !_hasText(_summary.tierCode) ||
        SubscriptionPlanTheme.isFreeTier(_summary.tierCode);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      freeTier ? 'FREE' : _summary.tierCode,
    );
    final String packageLabel = _hasText(_summary.planLabel)
        ? _summary.planLabel!.trim()
        : (freeTier
              ? l10n.subscriptionHeaderFreeLabel
              : l10n.subscriptionHeaderActiveLabel);
    final String? nextPlanLabel = _hasText(_summary.nextPlanLabel)
        ? _summary.nextPlanLabel!.trim()
        : null;
    final String? endDateLabel = _summary.endDate == null
        ? null
        : AppFormatters.mediumDate(_summary.endDate!.toLocal(), locale);

    final String dialogTitle = expired
        ? l10n.subscriptionReportExpiredTitle
        : l10n.subscriptionReportAdminsDialogTitle;
    final String guidanceMessage = nextPlanLabel == null
        ? l10n.subscriptionReportAdminsDialogBody
        : l10n.subscriptionReportAdminsDialogBodyWithNextPlan(nextPlanLabel);

    return AppDialog(
      title: Text(dialogTitle),
      icon: Icon(
        expired
            ? Icons.workspace_premium_outlined
            : Icons.auto_awesome_outlined,
        color: planTheme.foreground,
      ),
      maxWidth: 760,
      initialMaximized: true,
      showMaximizeButton: true,
      resizable: true,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PackageHeroCard(
            planTheme: planTheme,
            packageLabel: packageLabel,
            nextPlanLabel: nextPlanLabel,
            endDateLabel: endDateLabel,
            headerState: headerState,
            guidanceMessage: guidanceMessage,
          ),
          if (expiringSoon) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            _ExpiryNoticeCard(
              planTheme: planTheme,
              title: l10n.subscriptionReportExpirySoonTitle,
              message: _summary.daysUntilExpiry == null
                  ? l10n.subscriptionReportExpirySoonBodyGeneric
                  : l10n.subscriptionReportExpirySoonBody(
                      _summary.daysUntilExpiry!,
                    ),
              icon: Icons.schedule_outlined,
              urgent: false,
            ),
          ],
          if (expired) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            _ExpiryNoticeCard(
              planTheme: planTheme,
              title: l10n.subscriptionReportExpiredTitle,
              message: l10n.subscriptionReportExpiredBody,
              icon: Icons.error_outline,
              urgent: true,
            ),
          ],
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.subscriptionReportContactsIntro,
            style: theme.textTheme.titleSmall?.copyWith(
              color: planTheme.foreground,
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          if (_refreshing)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.sm),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: planTheme.foreground,
                backgroundColor: planTheme.border.withValues(alpha: 0.35),
              ),
            ),
          if (_facilityAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportFacilityAdminsLabel,
              contacts: _facilityAdmins,
              roleFallback: l10n.subscriptionReportFacilityAdminRoleLabel,
              leadingIcon: Icons.apartment_outlined,
              planTheme: planTheme,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (_tenantAdmins.isNotEmpty) ...<Widget>[
            _AdminContactGroup(
              title: l10n.subscriptionReportTenantAdminsLabel,
              contacts: _tenantAdmins,
              roleFallback: l10n.subscriptionReportTenantAdminRoleLabel,
              leadingIcon: Icons.business_outlined,
              planTheme: planTheme,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          if (_platformAdmins.isNotEmpty)
            _AdminContactGroup(
              title: l10n.subscriptionReportPlatformSupportLabel,
              contacts: _platformAdmins,
              roleFallback: l10n.subscriptionReportPlatformSupportRoleLabel,
              leadingIcon: Icons.support_agent_outlined,
              planTheme: planTheme,
              supportDisplayName: l10n.subscriptionReportPlatformSupportName,
              supportRoleLabel: l10n.subscriptionReportPlatformSupportRoleLabel,
            )
          else if (!_refreshing && !hasContacts)
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
            backgroundColor: planTheme.foreground,
            foregroundColor: theme.colorScheme.surface,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.check, size: 18),
          label: Text(l10n.subscriptionExpiredPromptContactAdminAction),
        ),
      ],
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _PackageHeroCard extends StatelessWidget {
  const _PackageHeroCard({
    required this.planTheme,
    required this.packageLabel,
    required this.nextPlanLabel,
    required this.endDateLabel,
    required this.headerState,
    required this.guidanceMessage,
  });

  final SubscriptionPlanTheme planTheme;
  final String packageLabel;
  final String? nextPlanLabel;
  final String? endDateLabel;
  final TenantSubscriptionHeaderState headerState;
  final String guidanceMessage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String statusLabel = switch (headerState) {
      TenantSubscriptionHeaderState.expired =>
        l10n.subscriptionReportStatusExpiredLabel,
      TenantSubscriptionHeaderState.expiringSoon =>
        l10n.subscriptionReportStatusExpiringSoonLabel,
      TenantSubscriptionHeaderState.active ||
      TenantSubscriptionHeaderState.unknown =>
        l10n.subscriptionReportStatusActiveLabel,
    };
    final String? dateCaption = endDateLabel == null
        ? null
        : (headerState == TenantSubscriptionHeaderState.expired
              ? l10n.subscriptionReportExpiredOnLabel(endDateLabel!)
              : l10n.subscriptionReportExpiresOnLabel(endDateLabel!));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radius.md),
        color: planTheme.background,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: planTheme.foreground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: planTheme.foreground,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.subscriptionReportCurrentPackageLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: planTheme.foreground.withValues(alpha: 0.9),
                          fontWeight: AppFontWeight.emphasis,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        packageLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: planTheme.foreground,
                          fontWeight: AppFontWeight.emphasis,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: statusLabel,
                  foreground: planTheme.foreground,
                  background: theme.colorScheme.surface.withValues(alpha: 0.72),
                ),
              ],
            ),
            if (dateCaption != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: planTheme.foreground,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      dateCaption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: planTheme.foreground,
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (nextPlanLabel != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: planTheme.foreground,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Text(
                    '${l10n.subscriptionReportNextPlanLabel}: ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      nextPlanLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: planTheme.foreground,
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: theme.spacing.xs),
            Text(
              guidanceMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryNoticeCard extends StatelessWidget {
  const _ExpiryNoticeCard({
    required this.planTheme,
    required this.title,
    required this.message,
    required this.icon,
    required this.urgent,
  });

  final SubscriptionPlanTheme planTheme;
  final String title;
  final String message;
  final IconData icon;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = urgent
        ? theme.statusColors.error
        : planTheme.foreground;
    final Color background = urgent
        ? theme.statusColors.errorContainer
        : planTheme.background;

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      backgroundColor: background,
      borderColor: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: AppFontWeight.emphasis,
        ),
      ),
    );
  }
}

class _AdminContactGroup extends StatelessWidget {
  const _AdminContactGroup({
    required this.title,
    required this.contacts,
    required this.roleFallback,
    required this.leadingIcon,
    required this.planTheme,
    this.supportDisplayName,
    this.supportRoleLabel,
  });

  final String title;
  final List<OrgAdminContact> contacts;
  final String roleFallback;
  final IconData leadingIcon;
  final SubscriptionPlanTheme planTheme;
  final String? supportDisplayName;
  final String? supportRoleLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color dividerColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );

    return AppCollapsibleSection(
      title: title,
      titleIcon: leadingIcon,
      initiallyExpanded: true,
      backgroundColor: planTheme.rowTint,
      borderColor: Colors.transparent,
      accentColor: planTheme.foreground,
      contentPadding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < contacts.length; index += 1) ...<Widget>[
            if (index > 0) Divider(height: 1, thickness: 1, color: dividerColor),
            _AdminContactCard(
              contact: contacts[index],
              roleFallback: roleFallback,
              planTheme: planTheme,
              supportDisplayName: supportDisplayName,
              supportRoleLabel: supportRoleLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminContactCard extends StatelessWidget {
  const _AdminContactCard({
    required this.contact,
    required this.roleFallback,
    required this.planTheme,
    this.supportDisplayName,
    this.supportRoleLabel,
  });

  final OrgAdminContact contact;
  final String roleFallback;
  final SubscriptionPlanTheme planTheme;
  final String? supportDisplayName;
  final String? supportRoleLabel;

  static const double _horizontalLayoutMinWidth = 560;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool support = contact.isSupportChannel;
    final String displayName = support
        ? (supportDisplayName ?? l10n.subscriptionReportPlatformSupportName)
        : contact.displayName;
    final String roleLabel = support
        ? (supportRoleLabel ?? l10n.subscriptionReportPlatformSupportRoleLabel)
        : (contact.roleName?.trim().isNotEmpty == true
              ? contact.roleName!.trim().replaceAll('_', ' ')
              : roleFallback);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool horizontal =
              constraints.maxWidth >= _horizontalLayoutMinWidth;
          final Widget avatar = CircleAvatar(
            radius: 16,
            backgroundColor: planTheme.background,
            foregroundColor: planTheme.foreground,
            child: Text(
              _initials(displayName),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
                color: planTheme.foreground,
              ),
            ),
          );

          if (horizontal) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                avatar,
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  flex: 3,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  flex: 2,
                  child: Text(
                    roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: planTheme.foreground,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ),
                if (contact.email != null) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    flex: 3,
                    child: _ContactLine(
                      icon: Icons.mail_outline,
                      label: l10n.subscriptionUpgradeAdminContactEmailLabel,
                      value: contact.email!,
                      accent: planTheme.foreground,
                      compact: true,
                    ),
                  ),
                ],
                if (contact.phone != null) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    flex: 2,
                    child: _ContactLine(
                      icon: Icons.phone_outlined,
                      label: l10n.subscriptionUpgradeAdminContactPhoneLabel,
                      value: contact.phone!,
                      accent: planTheme.foreground,
                      compact: true,
                    ),
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              avatar,
              SizedBox(width: theme.spacing.sm),
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
                    Text(
                      roleLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: planTheme.foreground,
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    if (contact.email != null) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      _ContactLine(
                        icon: Icons.mail_outline,
                        label: l10n.subscriptionUpgradeAdminContactEmailLabel,
                        value: contact.email!,
                        accent: planTheme.foreground,
                      ),
                    ],
                    if (contact.phone != null) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      _ContactLine(
                        icon: Icons.phone_outlined,
                        label: l10n.subscriptionUpgradeAdminContactPhoneLabel,
                        value: contact.phone!,
                        accent: planTheme.foreground,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
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
    required this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label: $value',
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.max,
        children: <Widget>[
          Icon(icon, size: 18, color: accent),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: SelectableText(
              value,
              maxLines: compact ? 1 : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppFontWeight.emphasis,
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
