import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerWidget {
  const HomePage({this.request = HomeDashboardRequest.empty, super.key});

  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeControllerProvider(request));
    final l10n = context.l10n;

    return AsyncStateScaffold<HomeDashboard>(
      value: dashboard,
      loadingTitle: l10n.homeLoadingTitle,
      loadingBody: l10n.homeLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.invalidate(homeControllerProvider(request));
      },
      dataBuilder: (context, snapshot) {
        return _HomeDashboardContent(
          dashboard: snapshot,
          request: request,
          onRefresh: () {
            ref.invalidate(homeControllerProvider(request));
          },
        );
      },
    );
  }
}

class _HomeDashboardContent extends ConsumerWidget {
  const _HomeDashboardContent({
    required this.dashboard,
    required this.request,
    required this.onRefresh,
  });

  final HomeDashboard dashboard;
  final HomeDashboardRequest request;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final List<_HomeActionDefinition> actions = _visibleActions(
      dashboard.quickActionIds,
      policy,
    );
    final List<_HomeShortcutDefinition> shortcuts = _visibleShortcuts(
      dashboard.shortcutIds,
      policy,
    );
    final String contextLine = _contextLine(dashboard);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppWorkspaceHeader(
              title: dashboard.profile.homeTitle,
              leading: AppWorkspaceTitleIcon(
                icon: _profileIcon(dashboard.profile.role),
                semanticLabel: dashboard.profile.homeTitle,
              ),
              status: AppWorkspaceStatus(
                label: dashboard.profile.roleLabel,
                tone: _profileStatusTone(dashboard),
              ),
              secondaryActions: <Widget>[
                AppIconButton(
                  icon: Icons.refresh,
                  semanticLabel: 'Refresh dashboard',
                  tooltip: 'Refresh dashboard',
                  onPressed: onRefresh,
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            _HomeHeroPanel(
              subtitle: dashboard.profile.homeSubtitle,
              contextLine: contextLine,
              generatedAt: dashboard.generatedAt,
              usesFallbackData: dashboard.usesFallbackData,
            ),
            if (dashboard.isTenantContextRequired) ...<Widget>[
              SizedBox(height: spacing.lg),
              _TenantContextRequiredPanel(
                tenantOptions: dashboard.tenantOptions,
                request: request,
              ),
            ] else ...<Widget>[
              SizedBox(height: spacing.lg),
              _HomeStatusStrip(cards: dashboard.statusCards),
              SizedBox(height: spacing.lg),
              _HomeQuickActions(actions: actions),
              SizedBox(height: spacing.lg),
              _HomeMainGrid(
                dashboard: dashboard,
                actions: actions,
                shortcuts: shortcuts,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeHeroPanel extends StatelessWidget {
  const _HomeHeroPanel({
    required this.subtitle,
    required this.contextLine,
    required this.generatedAt,
    required this.usesFallbackData,
  });

  final String subtitle;
  final String contextLine;
  final DateTime? generatedAt;
  final bool usesFallbackData;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? generatedLabel = generatedAt == null
        ? null
        : 'Updated ${DateFormat('MMM d, HH:mm').format(generatedAt!.toLocal())}';

    return AppContentPanel(
      child: Wrap(
        spacing: theme.spacing.lg,
        runSpacing: theme.spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subtitle, style: theme.textTheme.bodyLarge),
                SizedBox(height: theme.spacing.xs),
                Text(
                  contextLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (generatedLabel != null || usesFallbackData)
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: usesFallbackData
                    ? 'Profile view'
                    : generatedLabel ?? 'Live dashboard',
                tone: usesFallbackData
                    ? AppWorkspaceStatusTone.info
                    : AppWorkspaceStatusTone.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeStatusStrip extends StatelessWidget {
  const _HomeStatusStrip({required this.cards});

  final List<HomeStatusCard> cards;

  @override
  Widget build(BuildContext context) {
    final List<HomeStatusCard> visibleCards = cards
        .take(6)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(title: 'Today at a glance'),
        SizedBox(height: Theme.of(context).spacing.sm),
        AppWorkspaceSummaryGrid(
          compact: true,
          children: <Widget>[
            for (final HomeStatusCard card in visibleCards)
              AppWorkspaceSummaryCard(
                label: card.label,
                value: _formatMetricValue(card),
                icon: _metricIcon(card.id),
                tone: _metricTone(card),
                compact: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({required this.actions});

  final List<_HomeActionDefinition> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_HomeActionDefinition> primaryActions = actions
        .take(4)
        .toList(growable: false);
    final List<_HomeActionDefinition> moreActions = actions
        .skip(4)
        .toList(growable: false);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(title: 'Quick actions'),
        SizedBox(height: theme.spacing.sm),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final _HomeActionDefinition action in primaryActions)
              AppButton.secondary(
                label: action.label,
                leadingIcon: action.icon,
                onPressed: () => _goToRoute(context, action.route),
              ),
            if (moreActions.isNotEmpty)
              PopupMenuButton<_HomeActionDefinition>(
                tooltip: 'More actions',
                onSelected: (_HomeActionDefinition action) {
                  _goToRoute(context, action.route);
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<_HomeActionDefinition>>[
                    for (final _HomeActionDefinition action in moreActions)
                      PopupMenuItem<_HomeActionDefinition>(
                        value: action,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              action.icon,
                              size: theme.appTokens.listIconSize,
                            ),
                            SizedBox(width: theme.spacing.sm),
                            Expanded(child: Text(action.label)),
                          ],
                        ),
                      ),
                  ];
                },
                child: IgnorePointer(
                  child: AppButton.tertiary(
                    label: 'More actions',
                    leadingIcon: Icons.more_horiz,
                    onPressed: () {},
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeMainGrid extends StatelessWidget {
  const _HomeMainGrid({
    required this.dashboard,
    required this.actions,
    required this.shortcuts,
  });

  final HomeDashboard dashboard;
  final List<_HomeActionDefinition> actions;
  final List<_HomeShortcutDefinition> shortcuts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 980;
        final double gap = theme.spacing.lg;
        final Widget primary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PrimaryQueuePanel(
              items: dashboard.queuePreview,
              emptyMessage: dashboard.profile.emptyMessage,
              emptyActions: _visibleEmptyActions(
                dashboard.profile.emptyActionIds,
                actions,
              ),
            ),
            SizedBox(height: gap),
            _ShortcutsSection(shortcuts: shortcuts),
          ],
        );
        final Widget secondary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AlertsPanel(alerts: dashboard.alerts),
            SizedBox(height: gap),
            _ActivityPanel(activity: dashboard.activity),
          ],
        );

        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              primary,
              SizedBox(height: gap),
              secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: primary),
            SizedBox(width: gap),
            Expanded(flex: 2, child: secondary),
          ],
        );
      },
    );
  }
}

class _PrimaryQueuePanel extends StatelessWidget {
  const _PrimaryQueuePanel({
    required this.items,
    required this.emptyMessage,
    required this.emptyActions,
  });

  final List<HomeQueueItem> items;
  final String emptyMessage;
  final List<_HomeActionDefinition> emptyActions;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: 'Primary queue',
      description: 'Pending work routed to your account.',
      leadingIcon: Icons.format_list_bulleted,
      trailing: _ViewAllButton(target: _firstQueueTarget(items)),
      children: <Widget>[
        if (items.isEmpty)
          _EmptyStateInline(message: emptyMessage, actions: emptyActions)
        else
          for (final HomeQueueItem item in items.take(5)) _QueueRow(item: item),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.alerts});

  final List<HomeAlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: 'Alerts and insights',
      description: 'Risk signals, blockers, and reminders.',
      leadingIcon: Icons.warning_amber_outlined,
      children: <Widget>[
        if (alerts.isEmpty)
          const _QuietState(message: 'No alerts need attention.')
        else
          for (final HomeAlertItem alert in alerts.take(4))
            _AlertRow(alert: alert),
      ],
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity});

  final List<HomeActivityItem> activity;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: 'Recent activity',
      description: 'Updates relevant to this dashboard.',
      leadingIcon: Icons.history,
      children: <Widget>[
        if (activity.isEmpty)
          const _QuietState(message: 'No recent activity is available.')
        else
          for (final HomeActivityItem item in activity.take(6))
            _ActivityRow(item: item),
      ],
    );
  }
}

class _ShortcutsSection extends StatelessWidget {
  const _ShortcutsSection({required this.shortcuts});

  final List<_HomeShortcutDefinition> shortcuts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(title: 'Shortcuts'),
        SizedBox(height: theme.spacing.sm),
        AppResponsiveWrap(
          children: <Widget>[
            for (final _HomeShortcutDefinition shortcut in shortcuts)
              _ShortcutTile(shortcut: shortcut),
          ],
        ),
      ],
    );
  }
}

class _TenantContextRequiredPanel extends StatelessWidget {
  const _TenantContextRequiredPanel({
    required this.tenantOptions,
    required this.request,
  });

  final List<HomeTenantOption> tenantOptions;
  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: 'Tenant context required',
      description: 'Choose a tenant to view operational dashboard content.',
      leadingIcon: Icons.account_tree_outlined,
      children: <Widget>[
        if (tenantOptions.isEmpty)
          const _QuietState(message: 'No tenant options were returned.')
        else
          AppResponsiveWrap(
            minItemWidth: 220,
            children: <Widget>[
              for (final HomeTenantOption option in tenantOptions)
                AppButton.secondary(
                  label: option.label,
                  leadingIcon: Icons.business_outlined,
                  onPressed: () {
                    context.go(
                      AppRoutes.home.location(
                        queryParameters: <String, String>{
                          'tenant_id': option.id,
                          if (request.facilityId != null)
                            'facility_id': request.facilityId!,
                          if (request.branchId != null)
                            'branch_id': request.branchId!,
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});

  final HomeQueueItem item;

  @override
  Widget build(BuildContext context) {
    final AppWorkspaceStatus status = AppWorkspaceStatus(
      label: _statusLabel(item.status),
      tone: _severityTone(item.severity ?? item.status),
    );

    return _LinkedDashboardRow(
      icon: _moduleIcon(item.moduleSlug),
      title: item.label,
      subtitle: _timeLabel(item.occurredAt),
      status: status,
      target: item.target,
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final HomeAlertItem alert;

  @override
  Widget build(BuildContext context) {
    return _LinkedDashboardRow(
      icon: Icons.warning_amber_outlined,
      title: alert.label,
      subtitle: alert.count > 0 ? '${alert.count} item(s)' : 'Monitor',
      status: AppWorkspaceStatus(
        label: _statusLabel(alert.severity),
        tone: _severityTone(alert.severity),
      ),
      target: alert.target,
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final HomeActivityItem item;

  @override
  Widget build(BuildContext context) {
    return _LinkedDashboardRow(
      icon: _moduleIcon(item.moduleSlug),
      title: item.label,
      subtitle: _timeLabel(item.occurredAt),
      status: item.status == null
          ? null
          : AppWorkspaceStatus(
              label: _statusLabel(item.status),
              tone: _severityTone(item.status),
            ),
      target: item.target,
    );
  }
}

class _LinkedDashboardRow extends StatelessWidget {
  const _LinkedDashboardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.target,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppWorkspaceStatus? status;
  final HomeRouteTarget? target;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppRouteData? route = _routeForTarget(target);
    final Widget row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            AppWorkspaceStatusBadge(status: status!),
          ],
        ],
      ),
    );

    if (route == null) {
      return row;
    }

    return InkWell(onTap: () => _goToRoute(context, route), child: row);
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.shortcut});

  final _HomeShortcutDefinition shortcut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _goToRoute(context, shortcut.route),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerLowest,
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                shortcut.icon,
                size: theme.appTokens.listIconSize,
                color: colorScheme.primary,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  shortcut.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Icon(
                Icons.chevron_right,
                size: theme.appTokens.listIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.target});

  final HomeRouteTarget? target;

  @override
  Widget build(BuildContext context) {
    final AppRouteData? route = _routeForTarget(target);
    if (route == null) {
      return const SizedBox.shrink();
    }

    return AppButton.tertiary(
      label: 'View all',
      leadingIcon: Icons.open_in_new,
      onPressed: () => _goToRoute(context, route),
    );
  }
}

class _EmptyStateInline extends StatelessWidget {
  const _EmptyStateInline({required this.message, required this.actions});

  final String message;
  final List<_HomeActionDefinition> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppMessagePanel(message: message, icon: Icons.inbox_outlined),
        if (actions.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              for (final _HomeActionDefinition action in actions.take(3))
                AppButton.secondary(
                  label: action.label,
                  leadingIcon: action.icon,
                  onPressed: () => _goToRoute(context, action.route),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

final class _HomeActionDefinition {
  const _HomeActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.requiredAnyPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;
  final List<AppPermission> requiredAnyPermissions;

  bool isAllowed(AppAccessPolicy policy) {
    return route.accessRequirement.isAllowed(policy) &&
        (requiredAnyPermissions.isEmpty ||
            policy.grantsAny(requiredAnyPermissions));
  }
}

final class _HomeShortcutDefinition {
  const _HomeShortcutDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;

  bool isAllowed(AppAccessPolicy policy) {
    return route.accessRequirement.isAllowed(policy);
  }
}

const Map<String, _HomeActionDefinition> _actionLibrary =
    <String, _HomeActionDefinition>{
      'new_patient': _HomeActionDefinition(
        id: 'new_patient',
        label: 'Register patient',
        icon: Icons.person_add_alt_1_outlined,
        route: AppRoutes.patients,
        requiredAnyPermissions: <AppPermission>[AppPermissions.patientWrite],
      ),
      'appointment': _HomeActionDefinition(
        id: 'appointment',
        label: 'Book appointment',
        icon: Icons.event_available_outlined,
        route: AppRoutes.opd,
      ),
      'start_consultation': _HomeActionDefinition(
        id: 'start_consultation',
        label: 'Start consultation',
        icon: Icons.medical_services_outlined,
        route: AppRoutes.clinical,
        requiredAnyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
      ),
      'record_vitals': _HomeActionDefinition(
        id: 'record_vitals',
        label: 'Record vitals',
        icon: Icons.monitor_heart_outlined,
        route: AppRoutes.nursing,
        requiredAnyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
      ),
      'start_admission': _HomeActionDefinition(
        id: 'start_admission',
        label: 'Start admission',
        icon: Icons.local_hospital_outlined,
        route: AppRoutes.ipd,
      ),
      'lab_order': _HomeActionDefinition(
        id: 'lab_order',
        label: 'Create lab order',
        icon: Icons.biotech_outlined,
        route: AppRoutes.lab,
      ),
      'radiology_order': _HomeActionDefinition(
        id: 'radiology_order',
        label: 'Create imaging order',
        icon: Icons.camera_outdoor_outlined,
        route: AppRoutes.radiology,
      ),
      'invoice': _HomeActionDefinition(
        id: 'invoice',
        label: 'Create invoice',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.billing,
        requiredAnyPermissions: <AppPermission>[AppPermissions.billingWrite],
      ),
      'receive_payment': _HomeActionDefinition(
        id: 'receive_payment',
        label: 'Receive payment',
        icon: Icons.payments_outlined,
        route: AppRoutes.billing,
        requiredAnyPermissions: <AppPermission>[AppPermissions.billingWrite],
      ),
      'sale': _HomeActionDefinition(
        id: 'sale',
        label: 'Pharmacy sale',
        icon: Icons.medication_liquid_outlined,
        route: AppRoutes.pharmacy,
        requiredAnyPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
      ),
      'staff_profile': _HomeActionDefinition(
        id: 'staff_profile',
        label: 'Add staff profile',
        icon: Icons.badge_outlined,
        route: AppRoutes.hr,
        requiredAnyPermissions: <AppPermission>[AppPermissions.hrWrite],
      ),
      'publish_roster': _HomeActionDefinition(
        id: 'publish_roster',
        label: 'Publish roster',
        icon: Icons.calendar_month_outlined,
        route: AppRoutes.hr,
        requiredAnyPermissions: <AppPermission>[AppPermissions.rosterPublish],
      ),
      'report_maintenance_issue': _HomeActionDefinition(
        id: 'report_maintenance_issue',
        label: 'Report maintenance issue',
        icon: Icons.handyman_outlined,
        route: AppRoutes.operations,
        requiredAnyPermissions: <AppPermission>[AppPermissions.operationsWrite],
      ),
      'report_equipment_issue': _HomeActionDefinition(
        id: 'report_equipment_issue',
        label: 'Report equipment issue',
        icon: Icons.precision_manufacturing_outlined,
        route: AppRoutes.biomedical,
        requiredAnyPermissions: <AppPermission>[AppPermissions.biomedWrite],
      ),
      'cleaning_task': _HomeActionDefinition(
        id: 'cleaning_task',
        label: 'Create cleaning task',
        icon: Icons.cleaning_services_outlined,
        route: AppRoutes.housekeeping,
        requiredAnyPermissions: <AppPermission>[AppPermissions.operationsWrite],
      ),
      'dispatch_ambulance': _HomeActionDefinition(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance',
        icon: Icons.emergency_share_outlined,
        route: AppRoutes.emergency,
        requiredAnyPermissions: <AppPermission>[AppPermissions.emergencyWrite],
      ),
      'mortuary_case': _HomeActionDefinition(
        id: 'mortuary_case',
        label: 'Open mortuary case',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.mortuary,
        requiredAnyPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
      ),
      'release_authorisation': _HomeActionDefinition(
        id: 'release_authorisation',
        label: 'Review release authorization',
        icon: Icons.verified_user_outlined,
        route: AppRoutes.mortuary,
        requiredAnyPermissions: <AppPermission>[
          AppPermissions.mortuaryRelease,
          AppPermissions.mortuaryApprove,
        ],
      ),
      'run_report': _HomeActionDefinition(
        id: 'run_report',
        label: 'Run report',
        icon: Icons.analytics_outlined,
        route: AppRoutes.reports,
      ),
      'manage_subscription': _HomeActionDefinition(
        id: 'manage_subscription',
        label: 'Manage subscription',
        icon: Icons.workspace_premium_outlined,
        route: AppRoutes.subscriptions,
      ),
      'select_context': _HomeActionDefinition(
        id: 'select_context',
        label: 'Select tenant/facility',
        icon: Icons.account_tree_outlined,
        route: AppRoutes.tenantFacilitySetup,
      ),
      'open_profile': _HomeActionDefinition(
        id: 'open_profile',
        label: 'Open profile',
        icon: Icons.account_circle_outlined,
        route: AppRoutes.profile,
      ),
    };

const Map<String, _HomeShortcutDefinition> _shortcutLibrary =
    <String, _HomeShortcutDefinition>{
      'patients': _HomeShortcutDefinition(
        id: 'patients',
        label: 'Patients',
        icon: Icons.people_alt_outlined,
        route: AppRoutes.patients,
      ),
      'opd': _HomeShortcutDefinition(
        id: 'opd',
        label: 'OPD',
        icon: Icons.event_note_outlined,
        route: AppRoutes.opd,
      ),
      'emergency': _HomeShortcutDefinition(
        id: 'emergency',
        label: 'Emergency',
        icon: Icons.emergency_outlined,
        route: AppRoutes.emergency,
      ),
      'ipd': _HomeShortcutDefinition(
        id: 'ipd',
        label: 'IPD',
        icon: Icons.local_hospital_outlined,
        route: AppRoutes.ipd,
      ),
      'rooms_beds': _HomeShortcutDefinition(
        id: 'rooms_beds',
        label: 'Rooms and beds',
        icon: Icons.bed_outlined,
        route: AppRoutes.roomsBeds,
      ),
      'icu': _HomeShortcutDefinition(
        id: 'icu',
        label: 'ICU',
        icon: Icons.monitor_heart_outlined,
        route: AppRoutes.icu,
      ),
      'nursing': _HomeShortcutDefinition(
        id: 'nursing',
        label: 'Nursing',
        icon: Icons.health_and_safety_outlined,
        route: AppRoutes.nursing,
      ),
      'clinical': _HomeShortcutDefinition(
        id: 'clinical',
        label: 'Clinical',
        icon: Icons.medical_services_outlined,
        route: AppRoutes.clinical,
      ),
      'lab': _HomeShortcutDefinition(
        id: 'lab',
        label: 'Laboratory',
        icon: Icons.biotech_outlined,
        route: AppRoutes.lab,
      ),
      'radiology': _HomeShortcutDefinition(
        id: 'radiology',
        label: 'Radiology',
        icon: Icons.camera_outdoor_outlined,
        route: AppRoutes.radiology,
      ),
      'pharmacy': _HomeShortcutDefinition(
        id: 'pharmacy',
        label: 'Pharmacy',
        icon: Icons.local_pharmacy_outlined,
        route: AppRoutes.pharmacy,
      ),
      'billing': _HomeShortcutDefinition(
        id: 'billing',
        label: 'Billing',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.billing,
      ),
      'claims': _HomeShortcutDefinition(
        id: 'claims',
        label: 'Claims',
        icon: Icons.assignment_turned_in_outlined,
        route: AppRoutes.claims,
      ),
      'hr': _HomeShortcutDefinition(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        route: AppRoutes.hr,
      ),
      'operations': _HomeShortcutDefinition(
        id: 'operations',
        label: 'Operations',
        icon: Icons.handyman_outlined,
        route: AppRoutes.operations,
      ),
      'housekeeping': _HomeShortcutDefinition(
        id: 'housekeeping',
        label: 'Housekeeping',
        icon: Icons.cleaning_services_outlined,
        route: AppRoutes.housekeeping,
      ),
      'biomedical': _HomeShortcutDefinition(
        id: 'biomedical',
        label: 'Biomedical',
        icon: Icons.precision_manufacturing_outlined,
        route: AppRoutes.biomedical,
      ),
      'communications': _HomeShortcutDefinition(
        id: 'communications',
        label: 'Communications',
        icon: Icons.forum_outlined,
        route: AppRoutes.communications,
      ),
      'integrations': _HomeShortcutDefinition(
        id: 'integrations',
        label: 'Integrations',
        icon: Icons.hub_outlined,
        route: AppRoutes.integrations,
      ),
      'discharge': _HomeShortcutDefinition(
        id: 'discharge',
        label: 'Discharge',
        icon: Icons.output_outlined,
        route: AppRoutes.discharge,
      ),
      'mortuary': _HomeShortcutDefinition(
        id: 'mortuary',
        label: 'Mortuary',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.mortuary,
      ),
      'theater': _HomeShortcutDefinition(
        id: 'theater',
        label: 'Theatre',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.theater,
      ),
      'reports': _HomeShortcutDefinition(
        id: 'reports',
        label: 'Reports',
        icon: Icons.analytics_outlined,
        route: AppRoutes.reports,
      ),
      'subscriptions': _HomeShortcutDefinition(
        id: 'subscriptions',
        label: 'Subscriptions',
        icon: Icons.workspace_premium_outlined,
        route: AppRoutes.subscriptions,
      ),
      'tenant_facility_setup': _HomeShortcutDefinition(
        id: 'tenant_facility_setup',
        label: 'Tenant and facility setup',
        icon: Icons.account_tree_outlined,
        route: AppRoutes.tenantFacilitySetup,
      ),
      'settings': _HomeShortcutDefinition(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
      ),
      'profile': _HomeShortcutDefinition(
        id: 'profile',
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        route: AppRoutes.profile,
      ),
    };

List<_HomeActionDefinition> _visibleActions(
  List<String> ids,
  AppAccessPolicy policy,
) {
  return ids
      .map((String id) => _actionLibrary[id])
      .whereType<_HomeActionDefinition>()
      .where((_HomeActionDefinition action) => action.isAllowed(policy))
      .toList(growable: false);
}

List<_HomeShortcutDefinition> _visibleShortcuts(
  List<String> ids,
  AppAccessPolicy policy,
) {
  return ids
      .map((String id) => _shortcutLibrary[id])
      .whereType<_HomeShortcutDefinition>()
      .where((_HomeShortcutDefinition shortcut) => shortcut.isAllowed(policy))
      .toList(growable: false);
}

List<_HomeActionDefinition> _visibleEmptyActions(
  List<String> ids,
  List<_HomeActionDefinition> visibleActions,
) {
  final Set<String> allowedIds = visibleActions
      .map((_HomeActionDefinition action) => action.id)
      .toSet();
  return ids
      .where(allowedIds.contains)
      .map((String id) => _actionLibrary[id])
      .whereType<_HomeActionDefinition>()
      .toList(growable: false);
}

HomeRouteTarget? _firstQueueTarget(List<HomeQueueItem> items) {
  for (final HomeQueueItem item in items) {
    if (item.target != null) {
      return item.target;
    }
  }
  return null;
}

AppRouteData? _routeForTarget(HomeRouteTarget? target) {
  final String moduleSlug = (target?.moduleSlug ?? '').trim().toLowerCase();
  if (moduleSlug.isEmpty) {
    return null;
  }

  return switch (moduleSlug) {
    'patients' || 'patient' => AppRoutes.patients,
    'scheduling' || 'opd' || 'appointments' => AppRoutes.opd,
    'emergency' => AppRoutes.emergency,
    'clinical' => AppRoutes.clinical,
    'nursing' => AppRoutes.nursing,
    'ipd' => AppRoutes.ipd,
    'icu' => AppRoutes.icu,
    'theatre' || 'theater' => AppRoutes.theater,
    'lab' || 'laboratory' => AppRoutes.lab,
    'radiology' || 'imaging' => AppRoutes.radiology,
    'pharmacy' => AppRoutes.pharmacy,
    'billing' => AppRoutes.billing,
    'claims' => AppRoutes.claims,
    'hr' || 'roster' => AppRoutes.hr,
    'operations' => AppRoutes.operations,
    'housekeeping' => AppRoutes.housekeeping,
    'biomedical' || 'biomed' => AppRoutes.biomedical,
    'mortuary' => AppRoutes.mortuary,
    'reports' || 'audit' || 'dashboard' => AppRoutes.reports,
    'subscriptions' => AppRoutes.subscriptions,
    'settings' => AppRoutes.settings,
    _ => null,
  };
}

void _goToRoute(BuildContext context, AppRouteData route) {
  context.go(route.location());
}

String _contextLine(HomeDashboard dashboard) {
  final List<String> parts = <String>[
    if (_hasText(dashboard.context.facilityName))
      dashboard.context.facilityName!,
    if (_hasText(dashboard.context.facilityType))
      _formatToken(dashboard.context.facilityType!),
    if (_hasText(dashboard.context.tenantId))
      'Tenant ${dashboard.context.tenantId}',
    if (_hasText(dashboard.context.branchId))
      'Branch ${dashboard.context.branchId}',
  ];

  if (parts.isEmpty) {
    return 'Dashboard context follows your assigned account scope.';
  }

  return parts.join(' | ');
}

String _formatMetricValue(HomeStatusCard card) {
  if (card.format == 'currency') {
    return NumberFormat.compactCurrency(symbol: 'UGX ').format(card.value);
  }
  return NumberFormat.compact().format(card.value);
}

String _statusLabel(String? value) {
  if (!_hasText(value)) {
    return 'Open';
  }
  return _formatToken(value!);
}

String _timeLabel(DateTime? value) {
  if (value == null) {
    return 'No timestamp';
  }
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}

String _formatToken(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

AppWorkspaceStatusTone _profileStatusTone(HomeDashboard dashboard) {
  if (dashboard.isTenantContextRequired) {
    return AppWorkspaceStatusTone.warning;
  }
  if (dashboard.usesFallbackData) {
    return AppWorkspaceStatusTone.info;
  }
  return AppWorkspaceStatusTone.success;
}

AppWorkspaceStatusTone _metricTone(HomeStatusCard card) {
  final String id = card.id.toLowerCase();
  if (id.contains('critical') ||
      id.contains('overdue') ||
      id.contains('warning') ||
      id.contains('risk')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.error
        : AppWorkspaceStatusTone.success;
  }
  if (id.contains('pending') ||
      id.contains('queue') ||
      id.contains('open') ||
      id.contains('pressure')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.warning
        : AppWorkspaceStatusTone.neutral;
  }
  if (id.contains('completed') ||
      id.contains('available') ||
      id.contains('ready') ||
      id.contains('active')) {
    return AppWorkspaceStatusTone.success;
  }
  return AppWorkspaceStatusTone.info;
}

AppWorkspaceStatusTone _severityTone(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return switch (normalized) {
    'CRITICAL' ||
    'ERROR' ||
    'HIGH' ||
    'OVERDUE' ||
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'MEDIUM' ||
    'WARNING' ||
    'PENDING' ||
    'OPEN' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.warning,
    'LOW' ||
    'INFO' ||
    'SCHEDULED' ||
    'CONFIRMED' => AppWorkspaceStatusTone.info,
    'SUCCESS' ||
    'COMPLETED' ||
    'FINAL' ||
    'PAID' => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _metricIcon(String id) {
  final String normalized = id.toLowerCase();
  if (normalized.contains('patient')) return Icons.people_alt_outlined;
  if (normalized.contains('appointment')) return Icons.event_available_outlined;
  if (normalized.contains('admission') || normalized.contains('bed')) {
    return Icons.local_hospital_outlined;
  }
  if (normalized.contains('invoice') ||
      normalized.contains('payment') ||
      normalized.contains('revenue') ||
      normalized.contains('collection')) {
    return Icons.receipt_long_outlined;
  }
  if (normalized.contains('lab')) return Icons.biotech_outlined;
  if (normalized.contains('radiology')) return Icons.camera_outdoor_outlined;
  if (normalized.contains('stock') || normalized.contains('medication')) {
    return Icons.local_pharmacy_outlined;
  }
  if (normalized.contains('staff') ||
      normalized.contains('shift') ||
      normalized.contains('roster')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('maintenance') || normalized.contains('work_order')) {
    return Icons.handyman_outlined;
  }
  if (normalized.contains('clean') || normalized.contains('housekeeping')) {
    return Icons.cleaning_services_outlined;
  }
  if (normalized.contains('alert') ||
      normalized.contains('critical') ||
      normalized.contains('risk')) {
    return Icons.warning_amber_outlined;
  }
  return Icons.insights_outlined;
}

IconData _moduleIcon(String moduleSlug) {
  return switch (moduleSlug.toLowerCase()) {
    'patients' || 'patient' => Icons.people_alt_outlined,
    'scheduling' || 'opd' => Icons.event_note_outlined,
    'clinical' => Icons.medical_services_outlined,
    'nursing' => Icons.health_and_safety_outlined,
    'ipd' => Icons.local_hospital_outlined,
    'icu' => Icons.monitor_heart_outlined,
    'lab' => Icons.biotech_outlined,
    'radiology' => Icons.camera_outdoor_outlined,
    'pharmacy' => Icons.local_pharmacy_outlined,
    'billing' => Icons.receipt_long_outlined,
    'housekeeping' => Icons.cleaning_services_outlined,
    'biomedical' => Icons.precision_manufacturing_outlined,
    'hr' => Icons.badge_outlined,
    'emergency' => Icons.emergency_outlined,
    'mortuary' => Icons.inventory_2_outlined,
    _ => Icons.insights_outlined,
  };
}

IconData _profileIcon(AppRole role) {
  return switch (role) {
    AppRole.superAdmin ||
    AppRole.tenantAdmin ||
    AppRole.facilityAdmin => Icons.admin_panel_settings_outlined,
    AppRole.doctor => Icons.medical_services_outlined,
    AppRole.nurse ||
    AppRole.wardManager ||
    AppRole.icuManager => Icons.health_and_safety_outlined,
    AppRole.labTech => Icons.biotech_outlined,
    AppRole.radiologyTech => Icons.camera_outdoor_outlined,
    AppRole.pharmacist => Icons.local_pharmacy_outlined,
    AppRole.receptionist => Icons.support_agent_outlined,
    AppRole.billing => Icons.receipt_long_outlined,
    AppRole.operations => Icons.handyman_outlined,
    AppRole.hr || AppRole.unitManager => Icons.badge_outlined,
    AppRole.biomed ||
    AppRole.biomedManager => Icons.precision_manufacturing_outlined,
    AppRole.houseKeeper ||
    AppRole.housekeepingManager => Icons.cleaning_services_outlined,
    AppRole.ambulanceOperator => Icons.emergency_share_outlined,
    AppRole.theatreManager => Icons.fact_check_outlined,
    AppRole.mortuaryStaff ||
    AppRole.mortuaryManager => Icons.inventory_2_outlined,
    AppRole.patient => Icons.account_circle_outlined,
    AppRole.other => Icons.home_outlined,
  };
}
