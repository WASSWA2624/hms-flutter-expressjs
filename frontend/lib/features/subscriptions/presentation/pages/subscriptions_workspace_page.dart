import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/subscriptions_access.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

part 'subscriptions_workspace_table_columns.dart';

class SubscriptionsWorkspacePage extends ConsumerStatefulWidget {
  const SubscriptionsWorkspacePage({this.initialQuery, super.key});

  final SubscriptionsWorkspaceQuery? initialQuery;

  @override
  ConsumerState<SubscriptionsWorkspacePage> createState() {
    return _SubscriptionsWorkspacePageState();
  }
}

class _SubscriptionsWorkspacePageState
    extends ConsumerState<SubscriptionsWorkspacePage> {
  String? _appliedRouteSignature;
  String? _openedRouteDetailSignature;

  @override
  void initState() {
    super.initState();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant SubscriptionsWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(SubscriptionsWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    final String? signature = _querySignature(query);
    if (signature == null || _appliedRouteSignature == signature) {
      return;
    }
    _appliedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AsyncValue<Result<SubscriptionsWorkspaceState>> current = ref.read(
        subscriptionsWorkspaceControllerProvider,
      );
      final SubscriptionsWorkspaceState? currentState = current.maybeWhen(
        data: (Result<SubscriptionsWorkspaceState> r) => r.when(
          success: (SubscriptionsWorkspaceState s) => s,
          failure: (_) => null,
        ),
        orElse: () => null,
      );
      if (currentState != null &&
          currentState.query.panel == query.panel &&
          currentState.query.resource == query.resource &&
          query.recordId == null) {
        return;
      }
      ref
          .read(subscriptionsWorkspaceControllerProvider.notifier)
          .applyRouteQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<SubscriptionsWorkspaceState>> workspace = ref.watch(
      subscriptionsWorkspaceControllerProvider,
    );

    ref.listen<AsyncValue<Result<SubscriptionsWorkspaceState>>>(
      subscriptionsWorkspaceControllerProvider,
      (
        AsyncValue<Result<SubscriptionsWorkspaceState>>? previous,
        AsyncValue<Result<SubscriptionsWorkspaceState>> next,
      ) {
        final SubscriptionsWorkspaceQuery? query = widget.initialQuery;
        if (query == null || query.recordId == null) {
          return;
        }
        final SubscriptionsWorkspaceState? state = _subscriptionsStateFromAsync(
          next,
        );
        if (state == null || state.isRefreshing) {
          return;
        }
        final String? signature = _querySignature(query);
        if (signature == null || _openedRouteDetailSignature == signature) {
          return;
        }
        final SubscriptionItem? item = state.selectedItem;
        if (item == null) {
          return;
        }
        final String recordId = query.recordId!;
        if (item.id != recordId && item.effectiveDisplayId != recordId) {
          return;
        }
        _openedRouteDetailSignature = signature;
        final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
        // Deep-link detail inherits the tab's read/row-select gate: a route ∪
        // grant (platform:admin) alone must not mount the detail dialog.
        final bool canOpenDetail = switch (item.resource) {
          SubscriptionResource.subscriptionPlans ||
          SubscriptionResource.modules =>
            SubscriptionsPlansAtomPermissions.rowSelect.isAllowed(policy),
          SubscriptionResource.subscriptions ||
          SubscriptionResource.moduleSubscriptions =>
            SubscriptionsAtomPermissions.rowSelect.isAllowed(policy),
          SubscriptionResource.licenses =>
            SubscriptionsLicensesAtomPermissions.rowSelect.isAllowed(policy),
          SubscriptionResource.subscriptionInvoices =>
            SubscriptionsInvoicesAtomPermissions.rowSelect.isAllowed(policy),
        };
        if (!canOpenDetail) {
          return;
        }
        final bool canWrite = switch (item.resource) {
          SubscriptionResource.subscriptionPlans =>
            SubscriptionsPlansAtomPermissions.update.isAllowed(policy),
          // Catalog Modules is read-only; pack edits use Manage modules on a plan.
          SubscriptionResource.modules => false,
          SubscriptionResource.subscriptions ||
          SubscriptionResource.moduleSubscriptions =>
            SubscriptionsAtomPermissions.update.isAllowed(policy),
          SubscriptionResource.licenses =>
            SubscriptionsLicensesAtomPermissions.update.isAllowed(policy),
          SubscriptionResource.subscriptionInvoices =>
            SubscriptionsInvoicesAtomPermissions.update.isAllowed(policy),
        };
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(
            _openSubscriptionDetailDialog(context, ref, item, canWrite),
          );
        });
      },
    );

    return AsyncStateScaffold<SubscriptionsWorkspaceState>(
      value: workspace,
      appBarTitle: _SubscriptionsText.title,
      loadingTitle: _SubscriptionsText.loadingTitle,
      loadingBody: _SubscriptionsText.loadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(subscriptionsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, SubscriptionsWorkspaceState state) {
        return _SubscriptionsWorkspaceContent(state: state);
      },
    );
  }
}

class _SubscriptionsWorkspaceContent extends ConsumerStatefulWidget {
  const _SubscriptionsWorkspaceContent({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  ConsumerState<_SubscriptionsWorkspaceContent> createState() {
    return _SubscriptionsWorkspaceContentState();
  }
}

class _SubscriptionsWorkspaceContentState
    extends ConsumerState<_SubscriptionsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<SubscriptionItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<SubscriptionItem>();
  }

  @override
  void didUpdateWidget(covariant _SubscriptionsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<SubscriptionPanel> visiblePanels = subscriptionsAllowedPanels(
      accessPolicy,
    );
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and table.
    final Object? failure = state.lastFailure;
    final AppFailure? lastFailure = failure is AppFailure ? failure : null;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }
    final ThemeData theme = Theme.of(context);

    if (visiblePanels.isEmpty) {
      // No authorized panels — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }

    final bool canShowCurrentPanel = visiblePanels.contains(state.query.panel);
    if (!canShowCurrentPanel) {
      final SubscriptionPanel? fallback = subscriptionsFallbackPanel(
        accessPolicy,
      );
      if (fallback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              subscriptionsAllowedPanels(
                ref.read(appAccessPolicyProvider),
              ).contains(state.query.panel)) {
            return;
          }
          final SubscriptionResource resource = _defaultResourceForPanel(
            fallback,
          );
          unawaited(controller.applyPanel(fallback));
          context.go(
            state.query
                .copyWith(panel: fallback, resource: resource)
                .location(),
          );
        });
      }
    }

    final bool isOverview = state.query.panel == SubscriptionPanel.overview;
    final List<AppWorkspaceSummaryNotification> queueChips =
        _queueSummaryChips(state, accessPolicy);
    final List<SubscriptionResource> panelResources = _resourcesForPanel(
      state.query.panel,
    );

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SubscriptionsPanelTabBar(
              visiblePanels: visiblePanels,
              activePanel: canShowCurrentPanel
                  ? state.query.panel
                  : visiblePanels.first,
              isRefreshing: state.isRefreshing,
              deniedModulesCount: state.summaryValue(_SummaryIds.deniedModules),
              onPanelSelected: (SubscriptionPanel panel) {
                final SubscriptionResource resource =
                    _defaultResourceForPanel(panel);
                unawaited(controller.applyPanel(panel));
                context.go(
                  state.query
                      .resetFilters()
                      .copyWith(
                        panel: panel,
                        resource: resource,
                        queue: panel == SubscriptionPanel.denied
                            ? 'MODULE_BLOCKED'
                            : null,
                      )
                      .location(),
                );
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (canShowCurrentPanel) ...<Widget>[
              if (queueChips.isNotEmpty) ...<Widget>[
                _SubscriptionsQueueChipBar(chips: queueChips),
                SizedBox(height: theme.spacing.md),
              ],
              if (isOverview)
                _SubscriptionOverviewPanel(state: state)
              else ...<Widget>[
                if (panelResources.length > 1) ...<Widget>[
                  _SubscriptionsResourceTabBar(
                    resources: panelResources,
                    selected: state.query.resource,
                    isRefreshing: state.isRefreshing,
                    onResourceSelected: (SubscriptionResource resource) {
                      unawaited(controller.applyResource(resource));
                      context.go(
                        state.query
                            .copyWith(
                              panel: resource.defaultPanel,
                              resource: resource,
                            )
                            .location(),
                      );
                    },
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
                _SubscriptionsWorklistPanel(
                  state: state,
                  searchController: _searchController,
                  columnVisibilityController: _tableColumnController,
                  onItemSelected: (SubscriptionItem item) {
                    if (state.query.panel == SubscriptionPanel.billing &&
                        !SubscriptionsInvoicesAtomPermissions.rowSelect
                            .isAllowed(accessPolicy)) {
                      return;
                    }
                    if ((state.query.panel == SubscriptionPanel.catalog ||
                            state.query.panel == SubscriptionPanel.modules) &&
                        !SubscriptionsPlansAtomPermissions.rowSelect
                            .isAllowed(accessPolicy)) {
                      return;
                    }
                    if (state.query.panel == SubscriptionPanel.governance &&
                        !SubscriptionsLicensesAtomPermissions.rowSelect
                            .isAllowed(accessPolicy)) {
                      return;
                    }
                    if ((state.query.panel == SubscriptionPanel.operations ||
                            state.query.panel == SubscriptionPanel.denied) &&
                        !SubscriptionsAtomPermissions.rowSelect
                            .isAllowed(accessPolicy)) {
                      return;
                    }
                    final bool itemCanWrite = switch (item.resource) {
                      SubscriptionResource.subscriptionPlans =>
                        SubscriptionsPlansAtomPermissions.update
                            .isAllowed(accessPolicy),
                      // Catalog Modules is read-only; pack edits use Manage modules.
                      SubscriptionResource.modules => false,
                      SubscriptionResource.subscriptions ||
                      SubscriptionResource.moduleSubscriptions =>
                        SubscriptionsAtomPermissions.update
                            .isAllowed(accessPolicy),
                      SubscriptionResource.licenses =>
                        SubscriptionsLicensesAtomPermissions.update
                            .isAllowed(accessPolicy),
                      SubscriptionResource.subscriptionInvoices =>
                        SubscriptionsInvoicesAtomPermissions.update
                            .isAllowed(accessPolicy),
                    };
                    unawaited(
                      _openSubscriptionDetailDialog(
                        context,
                        ref,
                        item,
                        itemCanWrite,
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<AppWorkspaceSummaryNotification> _queueSummaryChips(
    SubscriptionsWorkspaceState state,
    AppAccessPolicy accessPolicy,
  ) {
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );

    AppWorkspaceSummaryNotification? chip({
      required String metricId,
      required String label,
      required IconData icon,
      required String queueId,
      AppWorkspaceStatusTone tone = AppWorkspaceStatusTone.neutral,
    }) {
      final SubscriptionQueueSummary? queue = _queueById(state, queueId);
      final int count = state.summaryValue(metricId);
      if (count <= 0 || queue == null) {
        return null;
      }
      if (!canViewSubscriptionsQueueChip(accessPolicy, queue)) {
        return null;
      }
      return AppWorkspaceSummaryNotification(
        label: label,
        count: count,
        icon: icon,
        tone: tone,
        isSelected: state.query.queue == queue.queue,
        onSelected: () {
          unawaited(controller.applyQueue(queue));
          context.go(
            state.query
                .copyWith(
                  panel: queue.panel,
                  resource: queue.resource,
                  queue: queue.queue,
                )
                .location(),
          );
        },
      );
    }

    return <AppWorkspaceSummaryNotification?>[
      chip(
        metricId: _SummaryIds.pendingChanges,
        label: _SubscriptionsText.pendingChanges,
        icon: Icons.pending_actions_outlined,
        queueId: _QueueIds.pendingChanges,
      ),
      chip(
        metricId: _SummaryIds.pastDueInvoices,
        label: _SubscriptionsText.pastDueInvoices,
        icon: Icons.receipt_long_outlined,
        tone: AppWorkspaceStatusTone.warning,
        queueId: _QueueIds.pastDueBilling,
      ),
      // Denied modules is a primary tab — omit the shared queue chip.
      chip(
        metricId: _SummaryIds.expiringLicenses,
        label: _SubscriptionsText.expiringLicenses,
        icon: Icons.event_busy_outlined,
        tone: AppWorkspaceStatusTone.warning,
        queueId: _QueueIds.renewalsDue,
      ),
      chip(
        metricId: _SummaryIds.approachingLimits,
        label: _SubscriptionsText.approachingLimits,
        icon: Icons.trending_up_outlined,
        tone: AppWorkspaceStatusTone.info,
        queueId: _QueueIds.upgradeRecommended,
      ),
    ].whereType<AppWorkspaceSummaryNotification>().toList(growable: false);
  }
}

class _SubscriptionsPanelTabBar extends StatelessWidget {
  const _SubscriptionsPanelTabBar({
    required this.visiblePanels,
    required this.activePanel,
    required this.isRefreshing,
    required this.onPanelSelected,
    this.deniedModulesCount = 0,
  });

  final List<SubscriptionPanel> visiblePanels;
  final SubscriptionPanel activePanel;
  final bool isRefreshing;
  final ValueChanged<SubscriptionPanel> onPanelSelected;
  final int deniedModulesCount;

  @override
  Widget build(BuildContext context) {
    return AppTabStrip(
      tabs: <AppTabItem>[
        for (final SubscriptionPanel panel in visiblePanels)
          AppTabItem(
            id: panel.serverValue,
            icon: _panelIcon(panel),
            label: _panelLabel(panel),
            count: panel == SubscriptionPanel.denied && deniedModulesCount > 0
                ? deniedModulesCount
                : null,
            countTone: AppTabCountTone.danger,
          ),
      ],
      selectedId: activePanel.serverValue,
      onTabTapped: isRefreshing
          ? (_) {}
          : (String tabId) {
              for (final SubscriptionPanel panel in visiblePanels) {
                if (panel.serverValue == tabId) {
                  onPanelSelected(panel);
                  return;
                }
              }
            },
    );
  }
}

class _SubscriptionsQueueChipBar extends StatelessWidget {
  const _SubscriptionsQueueChipBar({required this.chips});

  final List<AppWorkspaceSummaryNotification> chips;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final AppWorkspaceSummaryNotification chip in chips)
          FilterChip(
            selected: chip.isSelected,
            avatar: Icon(
              chip.icon,
              size: 18,
              color: workspaceStatusToneAccentColor(theme, chip.tone),
            ),
            label: Text('${chip.label} (${chip.count})'),
            onSelected: (_) => chip.onSelected(),
          ),
      ],
    );
  }
}

class _SubscriptionsResourceTabBar extends StatelessWidget {
  const _SubscriptionsResourceTabBar({
    required this.resources,
    required this.selected,
    required this.isRefreshing,
    required this.onResourceSelected,
  });

  final List<SubscriptionResource> resources;
  final SubscriptionResource selected;
  final bool isRefreshing;
  final ValueChanged<SubscriptionResource> onResourceSelected;

  @override
  Widget build(BuildContext context) {
    return AppTabStrip(
      variant: AppTabStripVariant.nested,
      tabs: <AppTabItem>[
        for (final SubscriptionResource resource in resources)
          AppTabItem(
            id: resource.serverValue,
            icon: _resourceIcon(resource),
            label: _resourceLabel(resource),
          ),
      ],
      selectedId: selected.serverValue,
      onTabTapped: isRefreshing
          ? (_) {}
          : (String tabId) {
              for (final SubscriptionResource resource in resources) {
                if (resource.serverValue == tabId) {
                  onResourceSelected(resource);
                  return;
                }
              }
            },
    );
  }
}

class _SubscriptionOverviewPanel extends ConsumerWidget {
  const _SubscriptionOverviewPanel({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    if (!SubscriptionsOverviewAtomPermissions.tab.isAllowed(accessPolicy)) {
      return const SizedBox.shrink();
    }

    final SubscriptionsOverview overview = state.overview;
    final ThemeData theme = Theme.of(context);
    final bool canCreate = SubscriptionsOverviewAtomPermissions.create
        .isAllowed(accessPolicy);
    final bool canUpdate = SubscriptionsOverviewAtomPermissions.update
        .isAllowed(accessPolicy);
    final bool showKpis =
        SubscriptionsOverviewAtomPermissions.kpi.isAllowed(accessPolicy);
    final bool showUsage =
        overview.usageSummary != null &&
        SubscriptionsOverviewAtomPermissions.usageLimits.isAllowed(
          accessPolicy,
        );
    final bool showRecommendations =
        overview.recommendations.isNotEmpty &&
        SubscriptionsOverviewAtomPermissions.recommendations.isAllowed(
          accessPolicy,
        );
    final bool showCharts = showKpis;
    final bool showAttention = showKpis &&
        (overview.nextInvoice != null ||
            overview.licenseSummary.activeCount > 0 ||
            overview.licenseSummary.expiringCount > 0 ||
            overview.pendingChangeStatus != null);

    if (!showKpis &&
        !showUsage &&
        !showRecommendations &&
        !showCharts &&
        !showAttention) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showKpis)
          AppResponsiveWrap(
            maxColumns: 3,
            minItemWidth: 200,
            children: <Widget>[
              _SubscriptionMetricCard(
                label: _SubscriptionsText.activePlans,
                value: overview.activePlanTenants.count.toString(),
                icon: Icons.verified_outlined,
                tone: AppWorkspaceStatusTone.success,
                onTap: () => unawaited(
                  _openTenantCohortDialog(
                    context,
                    ref,
                    state: state,
                    cohort: SubscriptionTenantCohort.active,
                    canCreate: canCreate,
                    canUpdate: canUpdate,
                  ),
                ),
              ),
              _SubscriptionMetricCard(
                label: _SubscriptionsText.notSubscribed,
                value: overview.notSubscribedTenants.count.toString(),
                icon: Icons.person_off_outlined,
                tone: AppWorkspaceStatusTone.warning,
                onTap: () => unawaited(
                  _openTenantCohortDialog(
                    context,
                    ref,
                    state: state,
                    cohort: SubscriptionTenantCohort.notSubscribed,
                    canCreate: canCreate,
                    canUpdate: canUpdate,
                  ),
                ),
              ),
              _SubscriptionMetricCard(
                label: _SubscriptionsText.closedSubscriptions,
                value: overview.closedSubscriptionTenants.count.toString(),
                icon: Icons.cancel_outlined,
                tone: AppWorkspaceStatusTone.neutral,
                onTap: () => unawaited(
                  _openTenantCohortDialog(
                    context,
                    ref,
                    state: state,
                    cohort: SubscriptionTenantCohort.closed,
                    canCreate: canCreate,
                    canUpdate: canUpdate,
                  ),
                ),
              ),
            ],
          ),
        if (showCharts) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          DashboardChartsRow(
            twoColumns: MediaQuery.sizeOf(context).width >= 900,
            data: _subscriptionsOverviewChartsData(state),
          ),
        ],
        if (showAttention) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _OverviewAttentionPanel(overview: overview, state: state),
        ],
        if (showUsage) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _UsageLimitPanel(
            usage: overview.usageSummary!,
            subscription: overview.currentSubscription,
          ),
        ],
        if (showRecommendations) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _RecommendationList(recommendations: overview.recommendations),
        ],
      ],
    );
  }
}

DashboardChartsData _subscriptionsOverviewChartsData(
  SubscriptionsWorkspaceState state,
) {
  final SubscriptionsOverview overview = state.overview;
  final int active = overview.activePlanTenants.count;
  final int notSubscribed = overview.notSubscribedTenants.count;
  final int closed = overview.closedSubscriptionTenants.count;
  final int cohortTotal = active + notSubscribed + closed;

  final List<DashboardTrendPointData> attentionPoints =
      <DashboardTrendPointData>[
        DashboardTrendPointData(
          value: state.summaryValue('active_subscriptions'),
          label: _SubscriptionsText.activeSubscriptionsChart,
        ),
        DashboardTrendPointData(
          value: state.summaryValue(_SummaryIds.pastDueInvoices),
          label: _SubscriptionsText.pastDue,
        ),
        DashboardTrendPointData(
          value: state.summaryValue(_SummaryIds.deniedModules),
          label: _SubscriptionsText.deniedModules,
        ),
        DashboardTrendPointData(
          value: state.summaryValue(_SummaryIds.expiringLicenses),
          label: _SubscriptionsText.expiringLicenses,
        ),
        DashboardTrendPointData(
          value: state.summaryValue(_SummaryIds.approachingLimits),
          label: _SubscriptionsText.approachingLimits,
        ),
      ].where((DashboardTrendPointData point) => point.value > 0).toList();

  return DashboardChartsData(
    trend: DashboardTrendChartData(
      title: _SubscriptionsText.attentionChartTitle,
      subtitle: _SubscriptionsText.attentionChartSubtitle,
      points: attentionPoints,
      emptyMessage: _SubscriptionsText.attentionChartEmpty,
    ),
    distribution: DashboardDistributionChartData(
      title: _SubscriptionsText.cohortChartTitle,
      total: cohortTotal,
      totalLabel: _SubscriptionsText.cohortChartTotalLabel,
      emptyMessage: _SubscriptionsText.cohortChartEmpty,
      segments: <DashboardDistributionSegmentData>[
        if (active > 0)
          DashboardDistributionSegmentData(
            label: _SubscriptionsText.activePlans,
            value: active,
          ),
        if (notSubscribed > 0)
          DashboardDistributionSegmentData(
            label: _SubscriptionsText.notSubscribed,
            value: notSubscribed,
          ),
        if (closed > 0)
          DashboardDistributionSegmentData(
            label: _SubscriptionsText.closedSubscriptions,
            value: closed,
          ),
      ],
    ),
  );
}

class _OverviewAttentionPanel extends StatelessWidget {
  const _OverviewAttentionPanel({
    required this.overview,
    required this.state,
  });

  final SubscriptionsOverview overview;
  final SubscriptionsWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> tiles = <Widget>[];

    final SubscriptionItem? nextInvoice = overview.nextInvoice;
    if (nextInvoice != null) {
      final num? invoiceAmount =
          nextInvoice.totalAmount ?? nextInvoice.price;
      tiles.add(
        _TwoLineCell(
          title: _SubscriptionsText.nextInvoiceAttention,
          subtitle:
              '${nextInvoice.invoiceStatus ?? nextInvoice.status ?? _SubscriptionsText.notRecorded}'
              '${invoiceAmount == null ? '' : ' · $invoiceAmount'}',
        ),
      );
    }

    final SubscriptionLicenseSummary licenses = overview.licenseSummary;
    if (licenses.activeCount > 0 || licenses.expiringCount > 0) {
      tiles.add(
        _TwoLineCell(
          title: _SubscriptionsText.licenseAttention,
          subtitle: _SubscriptionsText.licenseAttentionBody(
            licenses.activeCount,
            licenses.expiringCount,
          ),
        ),
      );
    }

    if (overview.pendingChangeStatus != null &&
        overview.pendingChangeStatus!.trim().isNotEmpty) {
      tiles.add(
        _TwoLineCell(
          title: _SubscriptionsText.pendingChanges,
          subtitle: overview.pendingChangeStatus!,
        ),
      );
    }

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSectionPanel(
      title: _SubscriptionsText.attentionSectionTitle,
      density: AppContentPanelDensity.compact,
      tone: AppWorkspaceStatusTone.info,
      children: <Widget>[
        for (final Widget tile in tiles) ...<Widget>[
          tile,
          SizedBox(height: theme.spacing.xs),
        ],
      ],
    );
  }
}

class _SubscriptionMetricCard extends StatefulWidget {
  const _SubscriptionMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppWorkspaceStatusTone tone;
  final VoidCallback onTap;

  @override
  State<_SubscriptionMetricCard> createState() =>
      _SubscriptionMetricCardState();
}

class _SubscriptionMetricCardState extends State<_SubscriptionMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = workspaceStatusToneAccentColor(theme, widget.tone);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.md),
            boxShadow: _hovered
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(theme.radius.md),
              hoverColor: accent.withValues(alpha: 0.08),
              child: AppContentPanel(
                tone: widget.tone,
                density: AppContentPanelDensity.compact,
                borderColor: Colors.transparent,
                backgroundColor: Color.alphaBlend(
                  accent.withValues(alpha: _hovered ? 0.16 : 0.10),
                  theme.colorScheme.surface,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(theme.radius.sm),
                      ),
                      child: Icon(widget.icon, color: accent, size: 22),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Text(
                      widget.value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: accent,
                        fontWeight: AppFontWeight.emphasis,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

SubscriptionQueueSummary? _queueById(
  SubscriptionsWorkspaceState state,
  String id,
) {
  for (final SubscriptionQueueSummary queue in state.queueSummaries) {
    if (queue.id == id) {
      return queue;
    }
  }
  return null;
}

class _UsageLimitPanel extends StatelessWidget {
  const _UsageLimitPanel({required this.usage, required this.subscription});

  final SubscriptionUsageSummary usage;
  final SubscriptionItem? subscription;

  @override
  Widget build(BuildContext context) {
    final List<_LimitRow> rows = <_LimitRow>[
      _LimitRow(
        label: _SubscriptionsText.users,
        used: usage.usersUsed,
        limit: subscription?.maxUsers,
      ),
      _LimitRow(
        label: _SubscriptionsText.facilities,
        used: usage.facilitiesUsed,
        limit: subscription?.maxFacilities,
      ),
      _LimitRow(
        label: _SubscriptionsText.storageMb,
        used: usage.storageUsedMb,
        limit: subscription?.maxStorageMb,
      ),
      _LimitRow(
        label: _SubscriptionsText.modules,
        used: usage.modulesUsed,
        limit: subscription?.maxModules,
      ),
    ];

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final _LimitRow row in rows) _LimitProgress(row: row),
        ],
      ),
    );
  }
}

class _LimitProgress extends StatelessWidget {
  const _LimitProgress({required this.row});

  final _LimitRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int used = row.used ?? 0;
    final int? limit = row.limit;
    final double progress = limit == null || limit <= 0
        ? 0
        : (used / limit).clamp(0, 1);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
              Text(
                limit == null
                    ? used.toString()
                    : _SubscriptionsText.limitValue(used, limit),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          LinearProgressIndicator(value: limit == null ? null : progress),
        ],
      ),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({required this.recommendations});

  final List<SubscriptionRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: _SubscriptionsText.recommendations,
      density: AppContentPanelDensity.compact,
      tone: AppWorkspaceStatusTone.info,
      children: <Widget>[
        for (final SubscriptionRecommendation item in recommendations)
          _TwoLineCell(title: item.title, subtitle: item.description),
      ],
    );
  }
}

class _SubscriptionsWorklistPanel extends ConsumerWidget {
  const _SubscriptionsWorklistPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onItemSelected,
  });

  final SubscriptionsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<SubscriptionItem>
  columnVisibilityController;
  final ValueChanged<SubscriptionItem> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final SubscriptionResource resource = state.query.resource;
    final String resourceKey = _subscriptionResourceStorageKey(resource);
    final AppSearchBarAction? createAction = _worklistCreateAction(
      context,
      ref,
      accessPolicy,
      state,
    );

    return AppListTable<SubscriptionItem>(
      page: state.items,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: context.l10n.commonTableSettingsTitle,
      columnVisibilityStorageKey: 'subscriptions_ws_$resourceKey',
      columnWidthStorageKey: 'subscriptions_cw_$resourceKey',
      search: AppListTableSearch<SubscriptionItem>(
        controller: searchController,
        semanticLabel: _SubscriptionsText.searchLabel,
        hintText: _SubscriptionsText.searchHint,
        clearLabel: _SubscriptionsText.clearSearch,
        matcher: (SubscriptionItem item, String query) {
          return _matchesSubscriptionTableSearch(
            context,
            item,
            query,
            resource,
          );
        },
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: context.l10n.commonFiltersActionLabel,
        advancedFilterTitle: context.l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: _SubscriptionsText.applyFilters,
        advancedFilterResetLabel: _SubscriptionsText.clearFilters,
        enableDateFilter: false,
        allFieldsLabel: _SubscriptionsText.all,
        filterGroups: _filterGroups(state),
        filterValue: _filterValue(state.query),
        hasActiveFilters: state.query.hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          controller.applyFilters(
            status: _emptyOption(value.option(_FilterKeys.status)),
            tierCode: _emptyOption(value.option(_FilterKeys.tier)),
            billingCycle: _emptyOption(value.option(_FilterKeys.billingCycle)),
            planId: _emptyOption(value.option(_FilterKeys.plan)),
            moduleId: _emptyOption(value.option(_FilterKeys.module)),
            fitStatus: _emptyOption(value.option(_FilterKeys.fit)),
            invoiceStatus: _emptyOption(value.option(_FilterKeys.invoice)),
            licenseType: _emptyOption(value.option(_FilterKeys.license)),
            eligibilityState: _emptyOption(
              value.option(_FilterKeys.eligibility),
            ),
            datePreset: _datePresetFromFilter(
              value.option(_FilterKeys.datePreset),
            ),
          );
        },
        trailingActions: <AppSearchBarAction>[
          ?createAction,
        ],
      ),
      itemKeyBuilder: (SubscriptionItem item) => ValueKey<String>(
        <String?>[
              item.resource.serverValue,
              item.id,
              item.tenantId,
              item.planId,
              item.moduleId,
              item.invoiceId,
            ]
            .whereType<String>()
            .where((String value) => value.isNotEmpty)
            .join(':'),
      ),
      onRowSelected: onItemSelected,
      previousPageLabel: _SubscriptionsText.previousPage,
      nextPageLabel: _SubscriptionsText.nextPage,
      pageLabelBuilder: (AppPage<SubscriptionItem> page) {
        final int total = page.totalItemCount ?? page.lastItemNumber;
        return _SubscriptionsText.pageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          total,
        );
      },
      onPageChanged: controller.changePage,
      emptyBuilder: (_) => const AppWorkspaceStatePanel.empty(
        title: _SubscriptionsText.emptyTitle,
        body: _SubscriptionsText.emptyBody,
      ),
      initialSortColumnKey:
          state.query.resource == SubscriptionResource.subscriptionPlans
          ? _SubscriptionColumnIds.monthlyPrice
          : null,
      rowColorBuilder:
          state.query.resource == SubscriptionResource.subscriptionPlans
          ? (BuildContext context, SubscriptionItem item) {
              return SubscriptionPlanTheme.of(
                context,
                item.tierCode ?? item.name ?? item.code,
              ).rowTint;
            }
          : state.query.resource == SubscriptionResource.subscriptions
          ? (BuildContext context, SubscriptionItem item) {
              return SubscriptionPlanTheme.of(
                context,
                item.tierCode ?? item.planCode ?? item.planLabel,
              ).rowTint;
            }
          : null,
      columns: _subscriptionWorklistColumns(context, resource),
      columnChoices: _subscriptionWorklistColumnChoices(context, resource),
      mobileItemBuilder: (BuildContext context, SubscriptionItem item) {
        final String title = switch (resource) {
          SubscriptionResource.subscriptionPlans =>
            item.name ?? item.title,
          SubscriptionResource.subscriptions =>
            item.tenantLabel ?? _SubscriptionsText.notRecorded,
          SubscriptionResource.modules =>
            item.name ?? item.title,
          SubscriptionResource.moduleSubscriptions =>
            item.moduleLabel ?? item.title,
          SubscriptionResource.subscriptionInvoices =>
            item.invoiceDisplayId ?? _SubscriptionsText.notRecorded,
          SubscriptionResource.licenses =>
            item.licenseType ?? _SubscriptionsText.notRecorded,
        };
        final String? caption = switch (resource) {
          SubscriptionResource.subscriptionPlans => item.code,
          SubscriptionResource.subscriptions =>
            item.planLabel ?? item.planCode,
          SubscriptionResource.modules => item.code,
          SubscriptionResource.moduleSubscriptions =>
            item.tenantLabel,
          SubscriptionResource.subscriptionInvoices =>
            item.tenantLabel,
          SubscriptionResource.licenses => item.tenantLabel,
        };
        final String amountMeta = switch (resource) {
          SubscriptionResource.subscriptionPlans =>
            '${_money(context, item.resolvedMonthlyPrice, item.currency)} / mo',
          SubscriptionResource.subscriptions =>
            _money(context, item.totalAmount ?? item.price, item.currency),
          SubscriptionResource.modules =>
            _amountOrLimit(context, item),
          SubscriptionResource.moduleSubscriptions =>
            _date(context, _timelineDate(item)),
          SubscriptionResource.subscriptionInvoices =>
            _money(context, item.totalAmount ?? item.price, item.currency),
          SubscriptionResource.licenses =>
            _date(context, _licenseExpiresAt(item)),
        };
        return AppListTableMobileItem(
          title: title,
          caption: caption,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(item.primaryStatus),
            ),
            if (amountMeta.isNotEmpty)
              AppListTableMobileMeta(
                label: amountMeta,
                icon: Icons.monetization_on_outlined,
              ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

class _SubscriptionDetailPanel extends ConsumerWidget {
  const _SubscriptionDetailPanel({required this.state, required this.canWrite});

  final SubscriptionsWorkspaceState state;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionItem? item = state.selectedItem;
    if (item == null) {
      return const AppStateView(
        title: _SubscriptionsText.noSelectionTitle,
        body: _SubscriptionsText.noSelectionBody,
        variant: AppStateViewVariant.empty,
      );
    }

    if (item.resource == SubscriptionResource.subscriptionPlans) {
      return _PlanDetailContent(
        state: state,
        item: item,
        canWrite: canWrite,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DetailHeader(item: item),
        SizedBox(height: Theme.of(context).spacing.md),
        _DetailActions(item: item, state: state),
        SizedBox(height: Theme.of(context).spacing.md),
        _DetailFields(item: item),
        if (item.resource == SubscriptionResource.subscriptions) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _SubscriptionModuleAccessSection(
            subscription: item,
            state: state,
          ),
        ],
        if (state.timeline.isNotEmpty) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _TimelinePanel(timeline: state.timeline),
        ],
      ],
    );
  }
}

class _PlanDetailContent extends ConsumerWidget {
  const _PlanDetailContent({
    required this.state,
    required this.item,
    required this.canWrite,
  });

  final SubscriptionsWorkspaceState state;
  final SubscriptionItem item;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.of(
      context,
      item.tierCode ?? item.name ?? item.code,
    );
    final bool isFree = SubscriptionPlanTheme.isFreeTier(item.tierCode);
    final SubscriptionPlanDetail? detail = state.planDetail;
    final List<SubscriptionLookupItem> modules = state.lookups.modules;
    final List<String> includedModuleIds = _resolveInitialIncludedModuleIds(
      storedIds: item.includedModuleIds,
      tierCode: item.tierCode,
      modules: modules,
    ).toList(growable: false);
    final List<String> includedLabels = _includedModuleLabels(
      includedModuleIds,
      modules,
    );
    final String? description = _sanitizedPlanDescription(item.description);
    final String planName = item.name ?? item.title;
    final String planId = item.effectiveDisplayId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppContentPanel(
          borderColor: Colors.transparent,
          backgroundColor: planTheme.rowTint,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.workspace_premium_outlined,
                size: 28,
                color: planTheme.foreground,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: theme.spacing.md,
                      runSpacing: theme.spacing.xs,
                      children: <Widget>[
                        Text(
                          planName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                            color: planTheme.foreground,
                          ),
                        ),
                        if (planId.trim().isNotEmpty)
                          Text(
                            planId,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: AppFontWeight.emphasis,
                            ),
                          ),
                      ],
                    ),
                    if (description != null) ...<Widget>[
                      SizedBox(height: theme.spacing.sm),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: planTheme.background,
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                  border: theme.borders.all(color: planTheme.border),
                ),
                child: Text(
                  isFree
                      ? _SubscriptionsText.freePlan
                      : (item.tierCode ?? item.name ?? item.title),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: planTheme.foreground,
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.md),
        AppResponsiveWrap(
          maxColumns: 5,
          minItemWidth: 150,
          children: <Widget>[
            if (isFree)
              const _PlanMetricChip(
                icon: Icons.payments_outlined,
                label: _SubscriptionsText.pricing,
                value: _SubscriptionsText.freePlan,
              )
            else ...<Widget>[
              _PlanMetricChip(
                icon: Icons.payments_outlined,
                label: _SubscriptionsText.monthlyPriceUsd,
                value: _money(
                  context,
                  item.resolvedMonthlyPrice,
                  item.currency,
                ),
              ),
              _PlanMetricChip(
                icon: Icons.calendar_month_outlined,
                label: _SubscriptionsText.annualPriceUsd,
                value: _money(context, item.resolvedAnnualPrice, item.currency),
              ),
            ],
            _PlanMetricChip(
              icon: Icons.group_outlined,
              label: _SubscriptionsText.maxUsers,
              value:
                  item.maxUsers?.toString() ?? _SubscriptionsText.notRecorded,
            ),
            _PlanMetricChip(
              icon: Icons.apartment_outlined,
              label: _SubscriptionsText.maxFacilities,
              value:
                  item.maxFacilities?.toString() ??
                  _SubscriptionsText.notRecorded,
            ),
            _PlanMetricChip(
              icon: Icons.sd_storage_outlined,
              label: _SubscriptionsText.maxStorage,
              value:
                  item.maxStorageMb?.toString() ??
                  _SubscriptionsText.notRecorded,
            ),
            _PlanMetricChip(
              icon: Icons.update_outlined,
              label: _SubscriptionsText.updated,
              value: _date(context, item.updatedAt),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: _SubscriptionsText.includedModules,
          description: _SubscriptionsText.includedModulesAccessHint,
          titleIcon: Icons.extension_outlined,
          actions: <Widget>[
            if (SubscriptionsPlansAtomPermissions.manageModules.isAllowed(
              ref.watch(appAccessPolicyProvider),
            ))
              AppButton.secondary(
                label: _SubscriptionsText.manageModules,
                leadingIcon: Icons.extension_outlined,
                onPressed: () async {
                  await _showPlanModulesDialog(context, ref, item);
                },
              ),
          ],
          child: includedLabels.isEmpty
              ? Text(
                  _SubscriptionsText.noModulesIncluded,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final String label in includedLabels)
                      Chip(label: Text(label)),
                  ],
                ),
        ),
        SizedBox(height: theme.spacing.md),
        if (state.isLoadingPlanDetail)
          const AppStateView(
            title: _SubscriptionsText.loadingTitle,
            body: _SubscriptionsText.loadingBody,
            variant: AppStateViewVariant.loading,
          )
        else ...<Widget>[
          AppResponsiveWrap(
            maxColumns: 3,
            minItemWidth: 160,
            children: <Widget>[
              _PlanStatCard(
                label: _SubscriptionsText.activeTenants,
                value: (detail?.stats.activeCount ?? 0).toString(),
                tone: AppWorkspaceStatusTone.success,
                icon: Icons.verified_outlined,
              ),
              _PlanStatCard(
                label: _SubscriptionsText.pendingApprovals,
                value: (detail?.stats.pendingCount ?? 0).toString(),
                tone: AppWorkspaceStatusTone.warning,
                icon: Icons.hourglass_top_outlined,
              ),
              _PlanStatCard(
                label: _SubscriptionsText.closedSubscriptions,
                value: (detail?.stats.closedCount ?? 0).toString(),
                tone: AppWorkspaceStatusTone.neutral,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          ...appCollapsibleSectionSpacing(context, <Widget>[
            _PlanAccountsSection(
              title: _SubscriptionsText.linkedTenants,
              emptyLabel: _SubscriptionsText.noLinkedTenants,
              accounts:
                  detail?.activeAccounts ?? const <SubscriptionTenantAccount>[],
            ),
            _PlanAccountsSection(
              title: _SubscriptionsText.pendingApprovals,
              emptyLabel: _SubscriptionsText.noPendingApprovals,
              accounts:
                  detail?.pendingAccounts ?? const <SubscriptionTenantAccount>[],
            ),
          ]),
        ],
      ],
    );
  }
}

class _PlanMetricChip extends StatelessWidget {
  const _PlanMetricChip({
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
    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          SizedBox(width: theme.spacing.xs),
          Flexible(
            child: Text(
              '$label · $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _sanitizedPlanDescription(String? value) {
  final String? normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized == '[object Object]' ||
      normalized.toLowerCase() == 'null' ||
      normalized.toLowerCase() == 'undefined') {
    return null;
  }
  return normalized;
}

class _PlanStatCard extends StatelessWidget {
  const _PlanStatCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
  });

  final String label;
  final String value;
  final AppWorkspaceStatusTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = workspaceStatusToneAccentColor(theme, tone);
    return AppContentPanel(
      tone: tone,
      density: AppContentPanelDensity.compact,
      borderColor: Colors.transparent,
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent),
          SizedBox(width: theme.spacing.sm),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: accent,
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanAccountsSection extends StatelessWidget {
  const _PlanAccountsSection({
    required this.title,
    required this.emptyLabel,
    required this.accounts,
  });

  final String title;
  final String emptyLabel;
  final List<SubscriptionTenantAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCollapsibleSection(
      title: title,
      titleIcon: Icons.business_outlined,
      child: accounts.isEmpty
          ? Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SubscriptionTenantAccount account in accounts)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.sm),
                    child: AppContentPanel(
                      density: AppContentPanelDensity.compact,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  account.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: AppFontWeight.emphasis,
                                  ),
                                ),
                                SizedBox(height: theme.spacing.xs),
                                Text(
                                  _joinDisplay(<String?>[
                                    _statusLabel(account.status),
                                    _date(context, account.startDate),
                                    _date(context, account.endDate),
                                  ]),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(status: account.status),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

List<String> _includedModuleLabels(
  List<String> moduleIds,
  List<SubscriptionLookupItem> modules,
) {
  if (moduleIds.isEmpty) {
    return const <String>[];
  }
  final Map<String, String> labelsById = <String, String>{
    for (final SubscriptionLookupItem module in modules)
      module.id: module.label,
  };
  final List<String> labels = <String>[];
  for (final String id in moduleIds) {
    labels.add(labelsById[id] ?? id);
  }
  return labels;
}

const Map<String, int> _planTierRank = <String, int>{
  'FREE': 0,
  'BASIC': 1,
  'ADVANCED': 2,
  'PRO': 3,
  'CUSTOM': 4,
  'DEVELOPER': 5,
};

int _tierRank(String? tierCode) {
  final String normalized = (tierCode ?? '').trim().toUpperCase();
  return _planTierRank[normalized] ?? -1;
}

bool _moduleIsAddOn(SubscriptionLookupItem module) {
  final Object? value = module.meta['is_add_on'];
  return value == true || value == 'true' || value == 1;
}

bool _moduleIsDeprecated(SubscriptionLookupItem module) {
  final Object? extension = module.meta['extension_json'];
  if (extension is Map) {
    final Object? deprecated = extension['deprecated'];
    if (deprecated == true || deprecated == 'true' || deprecated == 1) {
      return true;
    }
  }
  final Object? value = module.meta['deprecated'];
  return value == true || value == 'true' || value == 1;
}

bool _moduleIsPlatformInfrastructure(SubscriptionLookupItem module) {
  final Object? extension = module.meta['extension_json'];
  if (extension is Map) {
    final Object? flag = extension['is_platform_infrastructure'];
    if (flag == true || flag == 'true' || flag == 1) {
      return true;
    }
  }
  final Object? value = module.meta['is_platform_infrastructure'];
  return value == true || value == 'true' || value == 1;
}

String? _moduleMinimumTier(SubscriptionLookupItem module) {
  final Object? value = module.meta['minimum_plan_tier_code'];
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

/// Core modules whose minimum tier is at or below [tierCode].
List<String> _defaultIncludedModuleIdsForTier(
  String? tierCode,
  List<SubscriptionLookupItem> modules,
) {
  if (tierCode == null || tierCode.trim().isEmpty || modules.isEmpty) {
    return const <String>[];
  }
  final int planRank = _tierRank(tierCode);
  if (planRank < 0) {
    return const <String>[];
  }

  return modules
      .where((SubscriptionLookupItem module) {
        if (_moduleIsAddOn(module) || _moduleIsDeprecated(module)) {
          return false;
        }
        if (_moduleIsPlatformInfrastructure(module)) {
          return true;
        }
        final String? minimum = _moduleMinimumTier(module);
        if (minimum == null) {
          return true;
        }
        return planRank >= _tierRank(minimum);
      })
      .map((SubscriptionLookupItem module) => module.id)
      .toList(growable: false);
}

Set<String> _resolveInitialIncludedModuleIds({
  required List<String> storedIds,
  required String? tierCode,
  required List<SubscriptionLookupItem> modules,
}) {
  if (storedIds.isNotEmpty) {
    return Set<String>.of(storedIds);
  }
  return Set<String>.of(_defaultIncludedModuleIdsForTier(tierCode, modules));
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    return AppContentPanel(
      tone: _statusTone(item.primaryStatus),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_resourceIcon(item.resource), size: 28),
          SizedBox(width: Theme.of(context).spacing.sm),
          Expanded(
            child: _CopyableRecordCell(
              title: item.title,
              subtitle: _joinDisplay(<String?>[
                _resourceLabel(item.resource),
                item.subtitle,
              ]),
              identifier: item.effectiveDisplayId,
            ),
          ),
          _StatusBadge(status: item.primaryStatus),
        ],
      ),
    );
  }
}

class _DetailActions extends ConsumerWidget {
  const _DetailActions({
    required this.item,
    required this.state,
  });

  final SubscriptionItem item;
  final SubscriptionsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canUpdateSubscription =
        SubscriptionsAtomPermissions.update.isAllowed(accessPolicy);
    final List<Widget> actions = <Widget>[
      if (item.resource == SubscriptionResource.subscriptions &&
          canUpdateSubscription) ...<Widget>[
        if (SubscriptionsAtomPermissions.edit.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.editSubscription,
            leadingIcon: Icons.edit_outlined,
            enabled: !state.isSaving,
            onPressed: () =>
                _showEditSubscriptionDialog(context, ref, state, item),
          ),
        if (SubscriptionsAtomPermissions.assignModule.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.assignModule,
            leadingIcon: Icons.extension_outlined,
            enabled: !state.isSaving && state.lookups.modules.isNotEmpty,
            onPressed: () => _showModuleSubscriptionDialog(
              context,
              ref,
              state,
              initialSubscriptionId: item.id,
            ),
          ),
        if (item.canRenewSubscription &&
            SubscriptionsAtomPermissions.renew.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.renew,
            leadingIcon: Icons.event_repeat_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showRenewalDialog(context, ref),
          ),
        if (state.lookups.plans.isNotEmpty &&
            SubscriptionsAtomPermissions.changePlan.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.changePlan,
            leadingIcon: Icons.swap_horiz_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showPlanChangeDialog(context, ref, state),
          ),
        if (item.canActivateSubscription &&
            SubscriptionsAtomPermissions.activate.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.activate,
            leadingIcon: Icons.play_circle_outline,
            enabled: !state.isSaving,
            onPressed: () => _submitAndNotify(
              context,
              ref
                  .read(subscriptionsWorkspaceControllerProvider.notifier)
                  .activateSelectedSubscription(),
            ),
          ),
        if (item.canCancelSubscription &&
            SubscriptionsAtomPermissions.cancel.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.cancelSubscription,
            leadingIcon: Icons.block_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showCancelSubscriptionDialog(context, ref),
          ),
      ],
      if (item.resource == SubscriptionResource.moduleSubscriptions &&
          item.canToggleModule &&
          SubscriptionsAtomPermissions.toggleModule.isAllowed(accessPolicy))
        AppButton.secondary(
          label: item.isActive == true
              ? _SubscriptionsText.disableModule
              : _SubscriptionsText.enableModule,
          leadingIcon: item.isActive == true
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          enabled: !state.isSaving,
          onPressed: () => _showToggleModuleDialog(context, ref, item),
        ),
      if (item.resource == SubscriptionResource.licenses) ...<Widget>[
        if (SubscriptionsLicensesAtomPermissions.update.isAllowed(
          accessPolicy,
        ))
          AppButton.secondary(
            label: _SubscriptionsText.updateLicense,
            leadingIcon: Icons.key_outlined,
            enabled: !state.isSaving,
            onPressed: () =>
                _showLicenseDialog(context, ref, state, initial: item),
          ),
        if (SubscriptionsLicensesAtomPermissions.delete.isAllowed(
          accessPolicy,
        ))
          AppButton.secondary(
            label: _SubscriptionsText.revokeLicense,
            leadingIcon: Icons.key_off_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showRevokeLicenseDialog(context, ref),
          ),
      ],
      // Invoices: Collect / Retry = write ∩; no create/delete mounts on this tab.
      if (item.resource == SubscriptionResource.subscriptionInvoices) ...<Widget>[
        if (item.canCollectInvoice &&
            SubscriptionsInvoicesAtomPermissions.collect.isAllowed(
              accessPolicy,
            ))
          AppButton.secondary(
            label: _SubscriptionsText.collectInvoice,
            leadingIcon: Icons.payments_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showCollectInvoiceDialog(context, ref),
          ),
        if (SubscriptionsInvoicesAtomPermissions.retry.isAllowed(accessPolicy))
          AppButton.secondary(
            label: _SubscriptionsText.retryInvoice,
            leadingIcon: Icons.replay_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showRetryInvoiceDialog(context, ref),
          ),
      ],
    ];
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppQuickActions(
      title: _SubscriptionsText.quickActions,
      extraActions: actions,
    );
  }
}

class _SubscriptionModuleAccessSection extends ConsumerStatefulWidget {
  const _SubscriptionModuleAccessSection({
    required this.subscription,
    required this.state,
  });

  final SubscriptionItem subscription;
  final SubscriptionsWorkspaceState state;

  @override
  ConsumerState<_SubscriptionModuleAccessSection> createState() =>
      _SubscriptionModuleAccessSectionState();
}

class _SubscriptionModuleAccessSectionState
    extends ConsumerState<_SubscriptionModuleAccessSection> {
  bool _loading = true;
  AppFailure? _failure;
  List<SubscriptionItem> _moduleSubscriptions = const <SubscriptionItem>[];
  List<SubscriptionLookupItem> _catalogModules =
      const <SubscriptionLookupItem>[];
  bool? _wasSaving;

  @override
  void initState() {
    super.initState();
    _wasSaving = widget.state.isSaving;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _SubscriptionModuleAccessSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscription.id != widget.subscription.id ||
        oldWidget.subscription.tenantId != widget.subscription.tenantId) {
      unawaited(_load());
      return;
    }
    if (_wasSaving == true && !widget.state.isSaving) {
      unawaited(_load());
    }
    _wasSaving = widget.state.isSaving;
  }

  Future<void> _load() async {
    final String? tenantId = widget.subscription.tenantId;
    if (tenantId == null || tenantId.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failure = null;
        _moduleSubscriptions = const <SubscriptionItem>[];
        _catalogModules = widget.state.lookups.modules;
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final SubscriptionsRepository repository = ref.read(
      subscriptionsRepositoryProvider,
    );
    final Result<SubscriptionsWorkspaceData> result = await repository
        .getWorkspace(
          SubscriptionsWorkspaceQuery(
            panel: SubscriptionPanel.operations,
            resource: SubscriptionResource.moduleSubscriptions,
            tenantId: tenantId,
            pageRequest: const AppPageRequest(pageSize: 200),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (SubscriptionsWorkspaceData data) {
        setState(() {
          _loading = false;
          _failure = null;
          _moduleSubscriptions = data.items.items
              .where(
                (SubscriptionItem item) =>
                    item.resource == SubscriptionResource.moduleSubscriptions,
              )
              .toList(growable: false);
          _catalogModules = data.lookups.modules.isNotEmpty
              ? data.lookups.modules
              : widget.state.lookups.modules;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          _moduleSubscriptions = const <SubscriptionItem>[];
          _catalogModules = widget.state.lookups.modules;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canAssign = SubscriptionsAtomPermissions.assignModule.isAllowed(
      accessPolicy,
    );
    final bool canToggle = SubscriptionsAtomPermissions.toggleModule.isAllowed(
      accessPolicy,
    );

    final List<SubscriptionItem> granted = _moduleSubscriptions
        .where(
          (SubscriptionItem item) =>
              item.isActive == true && !item.entitlementDenied,
        )
        .toList(growable: false);
    final List<SubscriptionItem> unavailableAssigned = _moduleSubscriptions
        .where(
          (SubscriptionItem item) =>
              item.isActive != true || item.entitlementDenied,
        )
        .toList(growable: false);
    final Set<String> assignedModuleIds = <String>{
      for (final SubscriptionItem item in _moduleSubscriptions)
        if ((item.moduleId ?? '').trim().isNotEmpty) item.moduleId!,
    };
    final List<SubscriptionLookupItem> unavailableCatalog = _catalogModules
        .where(
          (SubscriptionLookupItem module) =>
              module.id.trim().isNotEmpty &&
              !assignedModuleIds.contains(module.id),
        )
        .toList(growable: false);

    return AppCollapsibleSection(
      title: _SubscriptionsText.moduleAccessTitle,
      subtitle: _SubscriptionsText.moduleAccessSubtitle,
      titleIcon: Icons.extension_outlined,
      initiallyExpanded: true,
      headerActions: <Widget>[
        if (canAssign)
          AppButton.secondary(
            label: _SubscriptionsText.assignModule,
            leadingIcon: Icons.extension_outlined,
            enabled: !widget.state.isSaving && _catalogModules.isNotEmpty,
            onPressed: () async {
              await _showModuleSubscriptionDialog(
                context,
                ref,
                widget.state,
                initialSubscriptionId: widget.subscription.id,
              );
              if (mounted) {
                unawaited(_load());
              }
            },
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_loading)
            const AppStateView(
              title: _SubscriptionsText.moduleAccessLoadingTitle,
              body: _SubscriptionsText.moduleAccessLoadingBody,
              variant: AppStateViewVariant.loading,
            )
          else if (_failure != null)
            AppFailureStateView(failure: _failure!, onRetry: _load)
          else ...<Widget>[
            _ModuleAccessGroup(
              title: _SubscriptionsText.grantedModules,
              emptyLabel: _SubscriptionsText.grantedModulesEmpty,
              children: <Widget>[
                for (final SubscriptionItem item in granted)
                  _ModuleAccessRow(
                    title: item.moduleLabel ?? item.title,
                    subtitle:
                        item.entitlementDenialReason ??
                        item.primaryStatus ??
                        _SubscriptionsText.moduleActiveStatus,
                    trailing: canToggle
                        ? AppButton.secondary(
                            label: _SubscriptionsText.disableModule,
                            leadingIcon: Icons.visibility_off_outlined,
                            enabled: !widget.state.isSaving,
                            onPressed: () async {
                              await _showToggleModuleDialog(
                                context,
                                ref,
                                item,
                              );
                              if (mounted) {
                                unawaited(_load());
                              }
                            },
                          )
                        : null,
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            _ModuleAccessGroup(
              title: _SubscriptionsText.unavailableModules,
              emptyLabel: _SubscriptionsText.unavailableModulesEmpty,
              children: <Widget>[
                for (final SubscriptionItem item in unavailableAssigned)
                  _ModuleAccessRow(
                    title: item.moduleLabel ?? item.title,
                    subtitle: item.entitlementDenied
                        ? (item.entitlementDenialReason ??
                              _SubscriptionsText.deniedModules)
                        : (item.primaryStatus ??
                              _SubscriptionsText.inactiveModule),
                    trailing: canToggle && item.canToggleModule
                        ? AppButton.secondary(
                            label: item.isActive == true
                                ? _SubscriptionsText.disableModule
                                : _SubscriptionsText.enableModule,
                            leadingIcon: item.isActive == true
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            enabled: !widget.state.isSaving,
                            onPressed: () async {
                              await _showToggleModuleDialog(
                                context,
                                ref,
                                item,
                              );
                              if (mounted) {
                                unawaited(_load());
                              }
                            },
                          )
                        : null,
                  ),
                for (final SubscriptionLookupItem module in unavailableCatalog)
                  _ModuleAccessRow(
                    title: module.label,
                    subtitle:
                        module.subtitle ?? _SubscriptionsText.moduleNotAssigned,
                    trailing: canAssign
                        ? AppButton.secondary(
                            label: _SubscriptionsText.assignModule,
                            leadingIcon: Icons.add,
                            enabled:
                                !widget.state.isSaving &&
                                _catalogModules.isNotEmpty,
                            onPressed: () async {
                              await _showModuleSubscriptionDialog(
                                context,
                                ref,
                                widget.state,
                                initialSubscriptionId: widget.subscription.id,
                              );
                              if (mounted) {
                                unawaited(_load());
                              }
                            },
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleAccessGroup extends StatelessWidget {
  const _ModuleAccessGroup({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        if (children.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final Widget child in children) ...<Widget>[
            child,
            SizedBox(height: theme.spacing.xs),
          ],
      ],
    );
  }
}

class _ModuleAccessRow extends StatelessWidget {
  const _ModuleAccessRow({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
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
          if (trailing != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _DetailFields extends StatelessWidget {
  const _DetailFields({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    return AppInfoTileGrid(
      emptyValue: _SubscriptionsText.notRecorded,
      items: _detailFieldItems(context, item),
    );
  }
}

List<AppInfoTileData> _detailFieldItems(
  BuildContext context,
  SubscriptionItem item,
) {
  final AppInfoTileData tenant = AppInfoTileData(
    label: _SubscriptionsText.tenant,
    value: item.tenantLabel ?? item.tenantId,
    icon: Icons.business_outlined,
  );
  final AppInfoTileData plan = AppInfoTileData(
    label: _SubscriptionsText.plan,
    value: item.planLabel ?? item.name,
    icon: Icons.workspace_premium_outlined,
  );
  final AppInfoTileData updated = AppInfoTileData(
    label: _SubscriptionsText.updated,
    value: _date(context, item.updatedAt),
    icon: Icons.update_outlined,
  );

  return switch (item.resource) {
    SubscriptionResource.subscriptions => <AppInfoTileData>[
      tenant,
      plan,
      AppInfoTileData(
        label: _SubscriptionsText.billingCycle,
        value: _statusLabel(item.billingCycle),
        icon: Icons.calendar_month_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.amount,
        value: _amountOrLimit(context, item),
        icon: Icons.payments_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.fitStatus,
        value: _statusLabel(item.fitStatus),
        icon: Icons.monitor_heart_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.startDate,
        value: _date(context, item.startDate),
        icon: Icons.play_arrow_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.endDate,
        value: _date(context, item.endDate ?? item.expiresAt),
        icon: Icons.event_busy_outlined,
      ),
      updated,
    ],
    SubscriptionResource.moduleSubscriptions => <AppInfoTileData>[
      tenant,
      plan,
      AppInfoTileData(
        label: _SubscriptionsText.module,
        value: item.moduleLabel ?? item.moduleSlug,
        icon: Icons.extension_outlined,
      ),
      updated,
    ],
    SubscriptionResource.subscriptionInvoices => <AppInfoTileData>[
      tenant,
      plan,
      AppInfoTileData(
        label: _SubscriptionsText.amount,
        value: _amountOrLimit(context, item),
        icon: Icons.payments_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.billingCycle,
        value: _statusLabel(item.billingCycle),
        icon: Icons.calendar_month_outlined,
      ),
      updated,
    ],
    SubscriptionResource.licenses => <AppInfoTileData>[
      tenant,
      AppInfoTileData(
        label: _SubscriptionsText.licenseType,
        value: _statusLabel(item.licenseType),
        icon: Icons.key_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.startDate,
        value: _date(context, item.startDate ?? item.issuedAt),
        icon: Icons.play_arrow_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.endDate,
        value: _date(context, item.endDate ?? item.expiresAt),
        icon: Icons.event_busy_outlined,
      ),
      updated,
    ],
    SubscriptionResource.modules => <AppInfoTileData>[
      AppInfoTileData(
        label: _SubscriptionsText.module,
        value: item.moduleLabel ?? item.name ?? item.code,
        icon: Icons.extension_outlined,
      ),
      updated,
    ],
    SubscriptionResource.subscriptionPlans => <AppInfoTileData>[
      plan,
      AppInfoTileData(
        label: _SubscriptionsText.monthlyPriceUsd,
        value: _money(context, item.resolvedMonthlyPrice, item.currency),
        icon: Icons.payments_outlined,
      ),
      AppInfoTileData(
        label: _SubscriptionsText.annualPriceUsd,
        value: _money(context, item.resolvedAnnualPrice, item.currency),
        icon: Icons.calendar_month_outlined,
      ),
      updated,
    ],
  };
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.timeline});

  final List<SubscriptionTimelineItem> timeline;

  @override
  Widget build(BuildContext context) {
    return AppTimeline(
      title: _SubscriptionsText.timeline,
      maxItems: 5,
      asActivityList: true,
      items: <AppTimelineItem>[
        for (final SubscriptionTimelineItem item in timeline)
          AppTimelineItem(
            title: item.title,
            occurredAt: item.occurredAt,
            description: _joinDisplay(<String?>[
              _resourceLabel(item.resource),
              _statusLabel(item.status),
            ]),
            icon: Icons.history_outlined,
          ),
      ],
    );
  }
}


class _CopyableRecordCell extends StatelessWidget {
  const _CopyableRecordCell({
    required this.title,
    this.subtitle,
    this.identifier,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final String? identifier;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasIdentifier = (identifier ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _TwoLineCell(
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: dense ? 1 : 2,
        ),
        if (hasIdentifier) ...<Widget>[
          if (!dense) SizedBox(height: theme.spacing.xs),
          AppCopyableIdentifier(
            value: identifier,
            textStyle: theme.textTheme.bodySmall,
            showCopyIcon: !dense,
          ),
        ],
      ],
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
  });

  final String title;
  final String? subtitle;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Text(
            subtitle!,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _statusLabel(status),
        tone: _statusTone(status),
        icon: _statusIcon(status),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({this.label, this.code});

  final String? label;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String display = (label ?? code)?.trim().isNotEmpty == true
        ? (label ?? code)!.trim()
        : _SubscriptionsText.notRecorded;
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.of(
      context,
      code ?? label,
    );

    return Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(
        color: planTheme.foreground,
        fontWeight: AppFontWeight.emphasis,
      ),
    );
  }
}

class _PlanForm extends StatefulWidget {
  const _PlanForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.submitLabel,
    required this.modules,
    this.initial,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;
  final List<SubscriptionLookupItem> modules;
  final SubscriptionItem? initial;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _monthlyPriceController;
  late final TextEditingController _annualPriceController;
  late final TextEditingController _usersController;
  late final TextEditingController _facilitiesController;
  late final TextEditingController _storageController;
  late final TextEditingController _modulesController;
  late final Set<String> _includedModuleIds;
  String? _tierCode;
  String _billingCycle = _BillingCycles.monthly;

  bool get _isFreeTier => SubscriptionPlanTheme.isFreeTier(_tierCode);

  @override
  void initState() {
    super.initState();
    final SubscriptionItem? initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _codeController = TextEditingController(text: initial?.code ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _monthlyPriceController = TextEditingController(
      text: initial?.resolvedMonthlyPrice == null
          ? ''
          : initial!.resolvedMonthlyPrice.toString(),
    );
    _annualPriceController = TextEditingController(
      text: initial?.resolvedAnnualPrice == null
          ? ''
          : initial!.resolvedAnnualPrice.toString(),
    );
    _usersController = TextEditingController(
      text: initial?.maxUsers?.toString() ?? '',
    );
    _facilitiesController = TextEditingController(
      text: initial?.maxFacilities?.toString() ?? '',
    );
    _storageController = TextEditingController(
      text: initial?.maxStorageMb?.toString() ?? '',
    );
    _modulesController = TextEditingController(
      text: initial?.maxModules?.toString() ?? '',
    );
    _tierCode = initial?.tierCode;
    _billingCycle = initial?.billingCycle ?? _BillingCycles.monthly;
    _includedModuleIds = _resolveInitialIncludedModuleIds(
      storedIds: initial?.includedModuleIds ?? const <String>[],
      tierCode: _tierCode,
      modules: widget.modules,
    );
    if (_isFreeTier) {
      _monthlyPriceController.text = '0';
      _annualPriceController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _monthlyPriceController.dispose();
    _annualPriceController.dispose();
    _usersController.dispose();
    _facilitiesController.dispose();
    _storageController.dispose();
    _modulesController.dispose();
    super.dispose();
  }

  void _onTierChanged(String? value) {
    setState(() {
      _tierCode = value;
      if (SubscriptionPlanTheme.isFreeTier(value)) {
        _monthlyPriceController.text = '0';
        _annualPriceController.text = '0';
      }
      _includedModuleIds
        ..clear()
        ..addAll(_defaultIncludedModuleIdsForTier(value, widget.modules));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SubscriptionLookupItem> modules = widget.modules;
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: AppFormShell(
        formKey: _formKey,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _nameController,
              labelText: _SubscriptionsText.planName,
              isRequired: true,
              validator: AppValidators.requiredText(
                _SubscriptionsText.planNameRequired,
              ),
            ),
            right: AppTextField(
              controller: _codeController,
              labelText: _SubscriptionsText.planCode,
            ),
          ),
          AppTextField(
            controller: _descriptionController,
            labelText: _SubscriptionsText.planDescription,
            maxLines: 2,
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppSelectField<String>(
              value: _tierCode,
              labelText: _SubscriptionsText.tier,
              options: _tierOptions(),
              onChanged: _onTierChanged,
            ),
            right: AppSelectField<String>(
              value: _billingCycle,
              labelText: _SubscriptionsText.defaultBillingCycle,
              isRequired: true,
              allowClear: false,
              enabled: !_isFreeTier,
              options: _billingCycleOptions(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _billingCycle = value);
                }
              },
            ),
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _monthlyPriceController,
              labelText: _SubscriptionsText.monthlyPriceUsd,
              isRequired: !_isFreeTier,
              enabled: !_isFreeTier,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _isFreeTier
                  ? null
                  : AppValidators.pattern(
                      RegExp(r'^\d+(\.\d{1,2})?$'),
                      _SubscriptionsText.amountInvalid,
                      allowEmpty: false,
                    ),
            ),
            right: AppTextField(
              controller: _annualPriceController,
              labelText: _SubscriptionsText.annualPriceUsd,
              isRequired: !_isFreeTier,
              enabled: !_isFreeTier,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _isFreeTier
                  ? null
                  : AppValidators.pattern(
                      RegExp(r'^\d+(\.\d{1,2})?$'),
                      _SubscriptionsText.amountInvalid,
                      allowEmpty: false,
                    ),
            ),
          ),
          if (_isFreeTier)
            Text(
              _SubscriptionsText.freePlanPricingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _usersController,
              labelText: _SubscriptionsText.maxUsers,
              keyboardType: TextInputType.number,
              validator: _optionalIntegerValidator,
            ),
            right: AppTextField(
              controller: _facilitiesController,
              labelText: _SubscriptionsText.maxFacilities,
              keyboardType: TextInputType.number,
              validator: _optionalIntegerValidator,
            ),
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _storageController,
              labelText: _SubscriptionsText.maxStorage,
              keyboardType: TextInputType.number,
              validator: _optionalIntegerValidator,
            ),
            right: AppTextField(
              controller: _modulesController,
              labelText: _SubscriptionsText.maxModules,
              keyboardType: TextInputType.number,
              validator: _optionalIntegerValidator,
            ),
          ),
          if (widget.initial == null) ...<Widget>[
            Text(
              _SubscriptionsText.includedModules,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            Text(
              _SubscriptionsText.includedModulesCheckboxHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _PlanModulesCheckboxPanel(
              modules: modules,
              selectedIds: _includedModuleIds,
              onChanged: (Set<String> next) {
                setState(() {
                  _includedModuleIds
                    ..clear()
                    ..addAll(next);
                });
              },
            ),
          ],
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionPlanDraft(
              name: _nameController.text.trim(),
              code: _emptyToNull(_codeController.text),
              tierCode: _tierCode,
              description: _emptyToNull(_descriptionController.text),
              monthlyPrice: _isFreeTier
                  ? '0'
                  : _monthlyPriceController.text.trim(),
              annualPrice: _isFreeTier
                  ? '0'
                  : _annualPriceController.text.trim(),
              billingCycle: _billingCycle,
              maxUsers: _emptyToNull(_usersController.text),
              maxFacilities: _emptyToNull(_facilitiesController.text),
              maxStorageMb: _emptyToNull(_storageController.text),
              maxModules: _emptyToNull(_modulesController.text),
              includedModuleIds: _includedModuleIds.toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}

class _PlanModulesCheckboxPanel extends StatelessWidget {
  const _PlanModulesCheckboxPanel({
    required this.modules,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<SubscriptionLookupItem> modules;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (modules.isEmpty) {
      return Text(
        _SubscriptionsText.noModulesAvailable,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final bool allSelected =
        modules.isNotEmpty && selectedIds.length >= modules.length;
    final bool noneSelected = selectedIds.isEmpty;
    final BorderRadius selectAllRadius = BorderRadius.circular(theme.radius.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: selectAllRadius,
            side: theme.borders.side(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (allSelected) {
                onChanged(<String>{});
                return;
              }
              onChanged(
                modules
                    .map((SubscriptionLookupItem module) => module.id)
                    .toSet(),
              );
            },
            borderRadius: selectAllRadius,
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    tristate: true,
                    value: allSelected
                        ? true
                        : noneSelected
                        ? false
                        : null,
                    onChanged: (_) {
                      if (allSelected) {
                        onChanged(<String>{});
                        return;
                      }
                      onChanged(
                        modules
                            .map((SubscriptionLookupItem module) => module.id)
                            .toSet(),
                      );
                    },
                  ),
                  Icon(
                    Icons.view_module_outlined,
                    size: theme.appTokens.listIconSize,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      allSelected
                          ? _SubscriptionsText.clearAllModules
                          : _SubscriptionsText.selectAllModules,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                      border: theme.borders.all(),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.sm,
                        vertical: 2,
                      ),
                      child: Text(
                        _SubscriptionsText.modulesSelectedCount(
                          selectedIds.length,
                          modules.length,
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: AppFontWeight.emphasis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppResponsiveWrap(
          minItemWidth: 240,
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final SubscriptionLookupItem module in modules)
              _PlanModuleOptionTile(
                module: module,
                selected: selectedIds.contains(module.id),
                onChanged: (bool selected) {
                  final Set<String> next = Set<String>.of(selectedIds);
                  if (selected) {
                    next.add(module.id);
                  } else {
                    next.remove(module.id);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _PlanModuleOptionTile extends StatelessWidget {
  const _PlanModuleOptionTile({
    required this.module,
    required this.selected,
    required this.onChanged,
  });

  final SubscriptionLookupItem module;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);
    final Color baseFill = selected
        ? colors.primaryContainer.withValues(alpha: 0.42)
        : colors.surfaceContainerHighest.withValues(alpha: 0.55);
    final Color borderColor = selected
        ? colors.primary.withValues(alpha: 0.35)
        : theme.borders.faint;

    return Material(
      color: baseFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: theme.borders.side(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: radius,
        hoverColor: colors.primary.withValues(alpha: 0.10),
        splashColor: colors.primary.withValues(alpha: 0.12),
        highlightColor: colors.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.xs,
            theme.spacing.sm,
            theme.spacing.sm,
            theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Checkbox(
                value: selected,
                onChanged: (bool? value) => onChanged(value ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                  border: theme.borders.all(color: colors.primary.withValues(alpha: 0.14)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  child: Icon(
                    _moduleIconForLookup(module),
                    size: theme.appTokens.listIconSize,
                    color: colors.primary,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      module.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                        height: 1.2,
                      ),
                    ),
                    if ((module.subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        module.subtitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanModulesForm extends StatefulWidget {
  const _PlanModulesForm({
    required this.modules,
    required this.initialSelectedIds,
  });

  final List<SubscriptionLookupItem> modules;
  final List<String> initialSelectedIds;

  @override
  State<_PlanModulesForm> createState() => _PlanModulesFormState();
}

class _PlanModulesFormState extends State<_PlanModulesForm> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.of(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: const Text(_SubscriptionsText.manageModules),
      icon: const Icon(Icons.extension_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _SubscriptionsText.includedModulesCheckboxHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          _PlanModulesCheckboxPanel(
            modules: widget.modules,
            selectedIds: _selectedIds,
            onChanged: (Set<String> next) {
              setState(() {
                _selectedIds
                  ..clear()
                  ..addAll(next);
              });
            },
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        cancelIcon: Icons.close,
        submitLabel: _SubscriptionsText.saveModules,
        submitIcon: Icons.save_outlined,
        emphasized: true,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          Navigator.of(context).pop(_selectedIds.toList(growable: false));
        },
      ),
    );
  }
}

class _SubscriptionForm extends StatefulWidget {
  const _SubscriptionForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.state,
    this.initial,
    this.initialTenantId,
    this.submitLabel = _SubscriptionsText.newSubscription,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final SubscriptionsWorkspaceState state;
  final SubscriptionItem? initial;
  final String? initialTenantId;
  final String submitLabel;

  @override
  State<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<_SubscriptionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _tenantId;
  String? _planId;
  String _status = _SubscriptionStatuses.active;
  bool _statusIsCancelled = false;

  @override
  void initState() {
    super.initState();
    final SubscriptionItem? initial = widget.initial;
    _tenantId = initial?.tenantId ?? widget.initialTenantId;
    _planId = initial?.planId;
    final String initialStatus =
        initial?.status ?? _SubscriptionStatuses.active;
    _statusIsCancelled =
        initialStatus.trim().toUpperCase() == _SubscriptionStatuses.cancelled;
    _status = _statusIsCancelled
        ? _SubscriptionStatuses.cancelled
        : initialStatus;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.initial != null;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _tenantId,
            labelText: _SubscriptionsText.tenant,
            isRequired: true,
            enabled: !isEdit && widget.initialTenantId == null,
            options: _lookupOptions(widget.state.lookups.tenants),
            validator: AppValidators.requiredValue(
              _SubscriptionsText.tenantRequired,
            ),
            onChanged: (String? value) => setState(() => _tenantId = value),
          ),
          if (!isEdit)
            AppSelectField<String>.searchable(
              value: _planId,
              labelText: _SubscriptionsText.plan,
              isRequired: true,
              options: _lookupOptions(widget.state.lookups.plans),
              validator: AppValidators.requiredValue(
                _SubscriptionsText.planRequired,
              ),
              onChanged: (String? value) => setState(() => _planId = value),
            ),
          if (_statusIsCancelled)
            AppContentPanel(
              density: AppContentPanelDensity.compact,
              child: Text(
                _SubscriptionsText.cancelledStatusEditHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            AppSelectField<String>(
              value: _status,
              labelText: _SubscriptionsText.status,
              allowClear: false,
              options: _subscriptionStatusOptions(includeCancelled: false),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.startDate,
            value: _startDate,
            onChanged: (DateTime? value) => setState(() => _startDate = value),
          ),
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.endDate,
            value: _endDate,
            onChanged: (DateTime? value) => setState(() => _endDate = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          final String? planId = isEdit
              ? widget.initial?.planId ?? _planId
              : _planId;
          if (planId == null || planId.isEmpty) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionDraft(
              tenantId: _tenantId!,
              planId: planId,
              status: _statusIsCancelled
                  ? _SubscriptionStatuses.cancelled
                  : _status,
              startDate: _datePayload(_startDate),
              endDate: _datePayload(_endDate),
            ),
          );
        },
      ),
    );
  }
}

class _PlanChangeForm extends StatefulWidget {
  const _PlanChangeForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.state,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final SubscriptionsWorkspaceState state;

  @override
  State<_PlanChangeForm> createState() => _PlanChangeFormState();
}

class _PlanChangeFormState extends State<_PlanChangeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _effectiveAt;
  String? _targetPlanId;
  String _changeType = _SubscriptionChangeTypes.upgrade;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _targetPlanId,
            labelText: _SubscriptionsText.targetPlan,
            isRequired: true,
            options: _lookupOptions(widget.state.lookups.plans),
            validator: AppValidators.requiredValue(
              _SubscriptionsText.planRequired,
            ),
            onChanged: (String? value) => setState(() => _targetPlanId = value),
          ),
          AppSelectField<String>(
            value: _changeType,
            labelText: _SubscriptionsText.changeType,
            allowClear: false,
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: _SubscriptionChangeTypes.upgrade,
                label: _SubscriptionsText.upgrade,
              ),
              AppSelectOption<String>(
                value: _SubscriptionChangeTypes.downgrade,
                label: _SubscriptionsText.downgrade,
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _changeType = value);
              }
            },
          ),
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.effectiveAt,
            value: _effectiveAt,
            onChanged: (DateTime? value) =>
                setState(() => _effectiveAt = value),
          ),
          AppTextField(
            controller: _reasonController,
            labelText: _SubscriptionsText.reason,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: _SubscriptionsText.changePlan,
        submitIcon: Icons.swap_horiz_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionPlanChangeDraft(
              targetPlanId: _targetPlanId!,
              changeType: _changeType,
              effectiveAt: _datePayload(_effectiveAt),
              reason: _emptyToNull(_reasonController.text),
            ),
          );
        },
      ),
    );
  }
}

class _RenewalForm extends StatefulWidget {
  const _RenewalForm({required this.dialogTitle, required this.dialogIcon});

  final Widget dialogTitle;
  final Widget? dialogIcon;

  @override
  State<_RenewalForm> createState() => _RenewalFormState();
}

class _RenewalFormState extends State<_RenewalForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _endDate;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.newEndDate,
            value: _endDate,
            onChanged: (DateTime? value) => setState(() => _endDate = value),
          ),
          AppTextField(
            controller: _reasonController,
            labelText: _SubscriptionsText.reason,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: _SubscriptionsText.renew,
        submitIcon: Icons.event_repeat_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionRenewalDraft(
              endDate: _datePayload(_endDate),
              reason: _emptyToNull(_reasonController.text),
            ),
          );
        },
      ),
    );
  }
}

class _ModuleSubscriptionForm extends StatefulWidget {
  const _ModuleSubscriptionForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.state,
    this.initialSubscriptionId,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final SubscriptionsWorkspaceState state;
  final String? initialSubscriptionId;

  @override
  State<_ModuleSubscriptionForm> createState() =>
      _ModuleSubscriptionFormState();
}

class _ModuleSubscriptionFormState extends State<_ModuleSubscriptionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _subscriptionId;
  String? _moduleId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _subscriptionId =
        widget.initialSubscriptionId ??
        widget.state.overview.currentSubscription?.id;
  }

  @override
  Widget build(BuildContext context) {
    final List<SubscriptionLookupItem> subscriptions = <SubscriptionLookupItem>[
      if (widget.state.overview.currentSubscription case final item?)
        SubscriptionLookupItem(
          id: item.id,
          label: item.title,
          subtitle: item.tenantLabel,
        ),
      for (final SubscriptionItem item in widget.state.items.items)
        if (item.resource == SubscriptionResource.subscriptions)
          SubscriptionLookupItem(
            id: item.id,
            label: item.title,
            subtitle: item.tenantLabel,
          ),
      if (widget.state.selectedItem case final SubscriptionItem selected?
          when selected.resource == SubscriptionResource.subscriptions)
        SubscriptionLookupItem(
          id: selected.id,
          label: selected.title,
          subtitle: selected.tenantLabel,
        ),
    ];
    final Map<String, SubscriptionLookupItem> uniqueSubscriptions =
        <String, SubscriptionLookupItem>{
          for (final SubscriptionLookupItem entry in subscriptions)
            if (entry.id.trim().isNotEmpty) entry.id: entry,
        };

    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _subscriptionId,
            labelText: _SubscriptionsText.subscription,
            isRequired: true,
            options: _lookupOptions(uniqueSubscriptions.values.toList()),
            validator: AppValidators.requiredValue(
              _SubscriptionsText.subscriptionRequired,
            ),
            onChanged: (String? value) {
              setState(() => _subscriptionId = value);
            },
          ),
          AppSelectField<String>.searchable(
            value: _moduleId,
            labelText: _SubscriptionsText.module,
            isRequired: true,
            options: _lookupOptions(widget.state.lookups.modules),
            validator: AppValidators.requiredValue(
              _SubscriptionsText.moduleRequired,
            ),
            onChanged: (String? value) => setState(() => _moduleId = value),
          ),
          AppCheckboxField(
            title: _SubscriptionsText.enabled,
            value: _isActive,
            onChanged: (bool value) => setState(() => _isActive = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: _SubscriptionsText.assignModule,
        submitIcon: Icons.extension_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            ModuleSubscriptionDraft(
              subscriptionId: _subscriptionId!,
              moduleId: _moduleId!,
              isActive: _isActive,
            ),
          );
        },
      ),
    );
  }
}

class _LicenseForm extends StatefulWidget {
  const _LicenseForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.state,
    this.initial,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final SubscriptionsWorkspaceState state;
  final SubscriptionItem? initial;

  @override
  State<_LicenseForm> createState() => _LicenseFormState();
}

class _LicenseFormState extends State<_LicenseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _issuedAt;
  DateTime? _expiresAt;
  String? _tenantId;
  String _licenseType = _LicenseTypes.enterprise;
  String _status = _SubscriptionStatuses.active;

  @override
  void initState() {
    super.initState();
    final SubscriptionItem? initial = widget.initial;
    _tenantId = initial?.tenantId;
    _licenseType = initial?.licenseType ?? _LicenseTypes.enterprise;
    _status = initial?.status ?? _SubscriptionStatuses.active;
    _issuedAt = _dateOnly(initial?.issuedAt);
    _expiresAt = _dateOnly(initial?.expiresAt);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _tenantId,
            labelText: _SubscriptionsText.tenant,
            isRequired: true,
            options: _lookupOptions(widget.state.lookups.tenants),
            validator: AppValidators.requiredValue(
              _SubscriptionsText.tenantRequired,
            ),
            onChanged: (String? value) => setState(() => _tenantId = value),
          ),
          AppSelectField<String>(
            value: _licenseType,
            labelText: _SubscriptionsText.licenseType,
            allowClear: false,
            options: _licenseTypeOptions(widget.state),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _licenseType = value);
              }
            },
          ),
          AppSelectField<String>(
            value: _status,
            labelText: _SubscriptionsText.status,
            allowClear: false,
            options: _subscriptionStatusOptions(),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.issuedAt,
            value: _issuedAt,
            onChanged: (DateTime? value) => setState(() => _issuedAt = value),
          ),
          _subscriptionDateField(
            context: context,
            labelText: _SubscriptionsText.expiresAt,
            value: _expiresAt,
            onChanged: (DateTime? value) => setState(() => _expiresAt = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.initial == null
            ? _SubscriptionsText.addLicense
            : _SubscriptionsText.updateLicense,
        submitIcon: Icons.key_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            LicenseDraft(
              tenantId: _tenantId!,
              licenseType: _licenseType,
              status: _status,
              issuedAt: _datePayload(_issuedAt),
              expiresAt: _datePayload(_expiresAt),
            ),
          );
        },
      ),
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({
    required this.dialogTitle,
    required this.dialogIcon,
    required this.submitLabel,
    required this.reasonLabel,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;
  final String reasonLabel;

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: widget.reasonLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionActionDraft(
              reason: _emptyToNull(_reasonController.text),
              notes: _emptyToNull(_reasonController.text),
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceCollectForm extends StatefulWidget {
  const _InvoiceCollectForm({
    required this.dialogTitle,
    required this.dialogIcon,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;

  @override
  State<_InvoiceCollectForm> createState() => _InvoiceCollectFormState();
}

class _InvoiceCollectFormState extends State<_InvoiceCollectForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = _PaymentMethods.cash;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _paymentMethod,
            labelText: _SubscriptionsText.paymentMethod,
            allowClear: false,
            options: _paymentMethodOptions(),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _paymentMethod = value);
              }
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: _SubscriptionsText.notes,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: _SubscriptionsText.collectInvoice,
        submitIcon: Icons.payments_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            SubscriptionActionDraft(
              paymentMethod: _paymentMethod,
              notes: _emptyToNull(_notesController.text),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _openSubscriptionDetailDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionItem item,
  bool canWrite,
) async {
  final controller = ref.read(
    subscriptionsWorkspaceControllerProvider.notifier,
  );
  controller.selectItem(item);
  if (item.resource == SubscriptionResource.subscriptionPlans) {
    unawaited(controller.loadPlanDetail(item.id));
  }
  final l10n = context.l10n;
  final bool isPlan = item.resource == SubscriptionResource.subscriptionPlans;
  final String dialogTitle = isPlan
      ? _SubscriptionsText.planDetailTitleWithName(item.name ?? item.title)
      : _SubscriptionsText.detailTitle;

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(dialogTitle),
      icon: Icon(_resourceIcon(item.resource)),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 980,
      content: Consumer(
        builder: (BuildContext context, WidgetRef dialogRef, _) {
          final SubscriptionsWorkspaceState? dialogState =
              _subscriptionsStateFromAsync(
                dialogRef.watch(subscriptionsWorkspaceControllerProvider),
              );
          if (dialogState == null) {
            return const AppStateView(
              title: _SubscriptionsText.loadingTitle,
              body: _SubscriptionsText.loadingBody,
              variant: AppStateViewVariant.loading,
            );
          }
          return _SubscriptionDetailPanel(
            state: dialogState,
            canWrite: canWrite,
          );
        },
      ),
      actions: <Widget>[
        if (isPlan &&
            SubscriptionsPlansAtomPermissions.edit.isAllowed(
              ref.read(appAccessPolicyProvider),
            ))
          AppButton.secondary(
            label: _SubscriptionsText.editPlan,
            leadingIcon: Icons.edit_outlined,
            onPressed: () async {
              final SubscriptionItem? selected =
                  _subscriptionsStateFromAsync(
                    ref.read(subscriptionsWorkspaceControllerProvider),
                  )?.selectedItem ??
                  item;
              await _showPlanDialog(dialogContext, ref, initial: selected);
            },
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(dialogContext).maybePop(),
        ),
      ],
    ),
  );
}

Future<void> _showPlanDialog(
  BuildContext context,
  WidgetRef ref, {
  SubscriptionItem? initial,
}) async {
  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final bool allowed = initial == null
      ? SubscriptionsPlansAtomPermissions.create.isAllowed(accessPolicy)
      : SubscriptionsPlansAtomPermissions.edit.isAllowed(accessPolicy);
  if (!allowed) {
    return;
  }
  final SubscriptionsWorkspaceState? state = _subscriptionsStateFromAsync(
    ref.read(subscriptionsWorkspaceControllerProvider),
  );
  final SubscriptionPlanDraft? draft =
      await showAppDialog<SubscriptionPlanDraft>(
        context: context,
        builder: (_) => _PlanForm(
          dialogTitle: Text(
            initial == null
                ? _SubscriptionsText.createPlan
                : _SubscriptionsText.editPlan,
          ),
          dialogIcon: const Icon(Icons.workspace_premium_outlined),
          submitLabel: initial == null
              ? _SubscriptionsText.createPlan
              : _SubscriptionsText.savePlan,
          modules: state?.lookups.modules ?? const <SubscriptionLookupItem>[],
          initial: initial,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = initial == null
      ? await ref
            .read(subscriptionsWorkspaceControllerProvider.notifier)
            .createPlan(draft)
      : await ref
            .read(subscriptionsWorkspaceControllerProvider.notifier)
            .updateSelectedPlan(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showPlanModulesDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionItem plan,
) async {
  if (!SubscriptionsPlansAtomPermissions.manageModules.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionsWorkspaceState? state = _subscriptionsStateFromAsync(
    ref.read(subscriptionsWorkspaceControllerProvider),
  );
  final List<String>? selectedIds = await showAppDialog<List<String>>(
    context: context,
    builder: (_) => _PlanModulesForm(
      modules: state?.lookups.modules ?? const <SubscriptionLookupItem>[],
      initialSelectedIds: _resolveInitialIncludedModuleIds(
        storedIds: plan.includedModuleIds,
        tierCode: plan.tierCode,
        modules: state?.lookups.modules ?? const <SubscriptionLookupItem>[],
      ).toList(growable: false),
    ),
  );
  if (selectedIds == null || !context.mounted) {
    return;
  }

  final SubscriptionPlanDraft draft = _planDraftFromItem(
    plan,
    includedModuleIds: selectedIds,
  );
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .updateSelectedPlan(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

SubscriptionPlanDraft _planDraftFromItem(
  SubscriptionItem item, {
  List<String>? includedModuleIds,
}) {
  return SubscriptionPlanDraft(
    name: item.name ?? item.title,
    code: item.code,
    tierCode: item.tierCode,
    description: item.description,
    monthlyPrice: (item.resolvedMonthlyPrice ?? item.price ?? 0).toString(),
    annualPrice: (item.resolvedAnnualPrice ?? item.price ?? 0).toString(),
    billingCycle: item.billingCycle ?? _BillingCycles.monthly,
    maxUsers: item.maxUsers?.toString(),
    maxFacilities: item.maxFacilities?.toString(),
    maxStorageMb: item.maxStorageMb?.toString(),
    maxModules: item.maxModules?.toString(),
    includedModuleIds: includedModuleIds ?? item.includedModuleIds,
  );
}

Future<void> _showSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state, {
  String? initialTenantId,
}) async {
  if (!SubscriptionsAtomPermissions.create.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionDraft? draft = await showAppDialog<SubscriptionDraft>(
    context: context,
    builder: (_) => _SubscriptionForm(
      dialogTitle: const Text(_SubscriptionsText.newSubscription),
      dialogIcon: const Icon(Icons.add),
      state: state,
      initialTenantId: initialTenantId,
      submitLabel: _SubscriptionsText.newSubscription,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .createSubscription(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showEditSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state,
  SubscriptionItem item,
) async {
  if (!SubscriptionsAtomPermissions.edit.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionDraft? draft = await showAppDialog<SubscriptionDraft>(
    context: context,
    builder: (_) => _SubscriptionForm(
      dialogTitle: const Text(_SubscriptionsText.editSubscription),
      dialogIcon: const Icon(Icons.edit_outlined),
      state: state,
      initial: item,
      submitLabel: _SubscriptionsText.saveSubscription,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .updateSubscription(item.id, draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _openTenantCohortDialog(
  BuildContext context,
  WidgetRef ref, {
  required SubscriptionsWorkspaceState state,
  required SubscriptionTenantCohort cohort,
  required bool canCreate,
  required bool canUpdate,
}) async {
  if (!SubscriptionsOverviewAtomPermissions.cohortDialog.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionTenantCohortSummary summary = state.overview.cohortSummary(
    cohort,
  );
  final AppWorkspaceStatusTone tone = switch (cohort) {
    SubscriptionTenantCohort.active => AppWorkspaceStatusTone.success,
    SubscriptionTenantCohort.notSubscribed => AppWorkspaceStatusTone.warning,
    SubscriptionTenantCohort.closed => AppWorkspaceStatusTone.neutral,
  };
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AppDialog(
        title: Text(_cohortTitle(cohort)),
        icon: Icon(
          _cohortIcon(cohort),
          color: workspaceStatusToneAccentColor(theme, tone),
        ),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppContentPanel(
              tone: tone,
              density: AppContentPanelDensity.compact,
              child: Text(
                _SubscriptionsText.cohortDialogDescription(summary.count),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
            SizedBox(height: theme.spacing.md),
            if (summary.accounts.isEmpty)
              AppContentPanel(
                density: AppContentPanelDensity.compact,
                child: Text(
                  _SubscriptionsText.noAccountsInCohort,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...<Widget>[
              for (final SubscriptionTenantAccount account
                  in summary.accounts) ...<Widget>[
                _CohortAccountCard(
                  account: account,
                  canMutate: _cohortAccountCanMutate(
                    account,
                    canCreate: canCreate,
                    canUpdate: canUpdate,
                  ),
                  isSaving: state.isSaving,
                  onAction: _cohortAccountCanMutate(
                        account,
                        canCreate: canCreate,
                        canUpdate: canUpdate,
                      )
                      ? () async {
                          await Navigator.of(dialogContext).maybePop();
                          if (!context.mounted) {
                            return;
                          }
                          await _handleCohortAccountAction(
                            context,
                            ref,
                            state: state,
                            account: account,
                            canCreate: canCreate,
                            canUpdate: canUpdate,
                          );
                        }
                      : null,
                ),
                SizedBox(height: theme.spacing.sm),
              ],
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: dialogContext.l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).maybePop(),
          ),
        ],
      );
    },
  );
}

class _CohortAccountCard extends StatelessWidget {
  const _CohortAccountCard({
    required this.account,
    required this.canMutate,
    required this.isSaving,
    required this.onAction,
  });

  final SubscriptionTenantAccount account;
  final bool canMutate;
  final bool isSaving;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.of(
      context,
      account.planCode ?? account.planLabel,
    );
    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      borderColor: Colors.transparent,
      backgroundColor: planTheme.rowTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  account.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
              _StatusBadge(status: account.status),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _PlanBadge(label: account.planLabel, code: account.planCode),
              _CohortMetaChip(
                icon: Icons.play_arrow_outlined,
                label: _date(context, account.startDate),
              ),
              _CohortMetaChip(
                icon: Icons.event_outlined,
                label: _date(context, account.endDate),
              ),
              _CohortMetaChip(
                icon: Icons.timelapse_outlined,
                label: _periodRemaining(account.endDate),
              ),
            ],
          ),
          if (onAction != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton.secondary(
                label: account.subscriptionId == null
                    ? _SubscriptionsText.newSubscription
                    : _SubscriptionsText.editSubscription,
                leadingIcon: account.subscriptionId == null
                    ? Icons.add_circle_outline
                    : Icons.edit_outlined,
                enabled: canMutate && !isSaving,
                onPressed: onAction == null
                    ? null
                    : () => unawaited(onAction!()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CohortMetaChip extends StatelessWidget {
  const _CohortMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ],
    );
  }
}

bool _cohortAccountCanMutate(
  SubscriptionTenantAccount account, {
  required bool canCreate,
  required bool canUpdate,
}) {
  final bool hasSubscription =
      account.subscriptionId != null && account.subscriptionId!.isNotEmpty;
  return hasSubscription ? canUpdate : canCreate;
}

Future<void> _handleCohortAccountAction(
  BuildContext context,
  WidgetRef ref, {
  required SubscriptionsWorkspaceState state,
  required SubscriptionTenantAccount account,
  required bool canCreate,
  required bool canUpdate,
}) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  final String? subscriptionId = account.subscriptionId;
  if (subscriptionId == null || subscriptionId.isEmpty) {
    // Re-check Overview create ∩ at action time (stale grants / deep entry).
    if (!canCreate ||
        !SubscriptionsOverviewAtomPermissions.create.isAllowed(policy)) {
      return;
    }
    await _showSubscriptionDialog(
      context,
      ref,
      state,
      initialTenantId: account.tenantId,
    );
    return;
  }

  if (!canUpdate ||
      !SubscriptionsOverviewAtomPermissions.update.isAllowed(policy)) {
    return;
  }

  final SubscriptionItem synthetic = SubscriptionItem(
    id: subscriptionId,
    resource: SubscriptionResource.subscriptions,
    displayId: subscriptionId,
    tenantId: account.tenantId,
    tenantLabel: account.tenantLabel,
    planId: account.planId,
    planLabel: account.planLabel,
    planCode: account.planCode,
    status: account.status,
    startDate: account.startDate,
    endDate: account.endDate,
  );
  ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .selectItem(synthetic);
  if (!context.mounted) {
    return;
  }
  await _showEditSubscriptionDialog(context, ref, state, synthetic);
}

Future<void> _showPlanChangeDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state,
) async {
  if (!SubscriptionsAtomPermissions.changePlan.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionPlanChangeDraft? draft =
      await showAppDialog<SubscriptionPlanChangeDraft>(
        context: context,
        builder: (_) => _PlanChangeForm(
          dialogTitle: const Text(_SubscriptionsText.changePlan),
          dialogIcon: const Icon(Icons.swap_horiz_outlined),
          state: state,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .changeSelectedSubscriptionPlan(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showRenewalDialog(BuildContext context, WidgetRef ref) async {
  if (!SubscriptionsAtomPermissions.renew.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionRenewalDraft? draft =
      await showAppDialog<SubscriptionRenewalDraft>(
        context: context,
        builder: (_) => const _RenewalForm(
          dialogTitle: Text(_SubscriptionsText.renew),
          dialogIcon: Icon(Icons.event_repeat_outlined),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .renewSelectedSubscription(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showModuleSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state, {
  String? initialSubscriptionId,
}) async {
  if (!SubscriptionsAtomPermissions.assignModule.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final ModuleSubscriptionDraft? draft =
      await showAppDialog<ModuleSubscriptionDraft>(
        context: context,
        builder: (_) => _ModuleSubscriptionForm(
          dialogTitle: const Text(_SubscriptionsText.assignModule),
          dialogIcon: const Icon(Icons.extension_outlined),
          state: state,
          initialSubscriptionId: initialSubscriptionId,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .createModuleSubscription(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showLicenseDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state, {
  SubscriptionItem? initial,
}) async {
  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final bool allowed = initial == null
      ? SubscriptionsLicensesAtomPermissions.create.isAllowed(accessPolicy)
      : SubscriptionsLicensesAtomPermissions.update.isAllowed(accessPolicy);
  if (!allowed) {
    return;
  }
  final LicenseDraft? draft = await showAppDialog<LicenseDraft>(
    context: context,
    builder: (_) => _LicenseForm(
      dialogTitle: Text(
        initial == null
            ? _SubscriptionsText.addLicense
            : _SubscriptionsText.updateLicense,
      ),
      dialogIcon: const Icon(Icons.key_outlined),
      state: state,
      initial: initial,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = initial == null
      ? await ref
            .read(subscriptionsWorkspaceControllerProvider.notifier)
            .createLicense(draft)
      : await ref
            .read(subscriptionsWorkspaceControllerProvider.notifier)
            .updateSelectedLicense(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showRevokeLicenseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!SubscriptionsLicensesAtomPermissions.delete.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: _SubscriptionsText.revokeLicense,
      body: _SubscriptionsText.revokeLicenseBody,
      submitLabel: _SubscriptionsText.revokeLicense,
      icon: const Icon(Icons.key_off_outlined),
      destructive: true,
      submitLeadingIcon: Icons.key_off_outlined,
      onConfirm: () => ref
          .read(subscriptionsWorkspaceControllerProvider.notifier)
          .deleteSelectedLicense(),
    ),
  );
  if (confirmed == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showToggleModuleDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionItem item,
) async {
  if (!SubscriptionsAtomPermissions.toggleModule.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionActionDraft? draft =
      await showAppDialog<SubscriptionActionDraft>(
        context: context,
        builder: (_) => _ReasonForm(
          dialogTitle: Text(
            item.isActive == true
                ? _SubscriptionsText.disableModule
                : _SubscriptionsText.enableModule,
          ),
          dialogIcon: const Icon(Icons.extension_outlined),
          submitLabel: item.isActive == true
              ? _SubscriptionsText.disableModule
              : _SubscriptionsText.enableModule,
          reasonLabel: _SubscriptionsText.reason,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .toggleModuleSubscription(item, reason: draft.reason);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showCancelSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!SubscriptionsAtomPermissions.cancel.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: _SubscriptionsText.cancelSubscription,
      body: _SubscriptionsText.cancelSubscriptionBody,
      submitLabel: _SubscriptionsText.cancelSubscription,
      icon: const Icon(Icons.block_outlined),
      destructive: true,
      submitLeadingIcon: Icons.block_outlined,
      onConfirm: () => ref
          .read(subscriptionsWorkspaceControllerProvider.notifier)
          .cancelSelectedSubscription(),
    ),
  );
  if (confirmed == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showCollectInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!SubscriptionsInvoicesAtomPermissions.collect.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionActionDraft? draft =
      await showAppDialog<SubscriptionActionDraft>(
        context: context,
        builder: (_) => const _InvoiceCollectForm(
          dialogTitle: Text(_SubscriptionsText.collectInvoice),
          dialogIcon: Icon(Icons.payments_outlined),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .collectSelectedInvoice(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showRetryInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!SubscriptionsInvoicesAtomPermissions.retry.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  final SubscriptionActionDraft? draft =
      await showAppDialog<SubscriptionActionDraft>(
        context: context,
        builder: (_) => const _ReasonForm(
          dialogTitle: Text(_SubscriptionsText.retryInvoice),
          dialogIcon: Icon(Icons.replay_outlined),
          submitLabel: _SubscriptionsText.retryInvoice,
          reasonLabel: _SubscriptionsText.retryReason,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .retrySelectedInvoice(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

SubscriptionsWorkspaceState? _subscriptionsStateFromAsync(
  AsyncValue<Result<SubscriptionsWorkspaceState>> asyncState,
) {
  return asyncState.asData?.value.when(
    success: (SubscriptionsWorkspaceState state) => state,
    failure: (_) => null,
  );
}

Future<void> _submitAndNotify(
  BuildContext context,
  Future<AppFailure?> submission,
) async {
  final AppFailure? failure = await submission;
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? _SubscriptionsText.savedMessage
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

List<AppSearchBarFilterGroup> _filterGroups(SubscriptionsWorkspaceState state) {
  final SubscriptionLookups lookups = state.lookups;
  return <AppSearchBarFilterGroup>[
    if (_statusChoices(state).isNotEmpty)
      AppSearchBarFilterGroup(
        key: _FilterKeys.status,
        label: _SubscriptionsText.status,
        allLabel: _SubscriptionsText.allStatuses,
        choices: _statusChoices(state),
      ),
    if (lookups.tiers.isNotEmpty)
      AppSearchBarFilterGroup(
        key: _FilterKeys.tier,
        label: _SubscriptionsText.tier,
        allLabel: _SubscriptionsText.allTiers,
        choices: _choices(lookups.tiers),
      ),
    if (lookups.billingCycles.isNotEmpty &&
        state.query.resource == SubscriptionResource.subscriptionPlans)
      AppSearchBarFilterGroup(
        key: _FilterKeys.billingCycle,
        label: _SubscriptionsText.billingCycle,
        allLabel: _SubscriptionsText.allBillingCycles,
        choices: _choices(lookups.billingCycles),
      ),
    if (lookups.plans.isNotEmpty &&
        state.query.resource != SubscriptionResource.subscriptionPlans)
      AppSearchBarFilterGroup(
        key: _FilterKeys.plan,
        label: _SubscriptionsText.plan,
        allLabel: _SubscriptionsText.allPlans,
        choices: _choices(lookups.plans),
      ),
    if (lookups.modules.isNotEmpty &&
        state.query.resource == SubscriptionResource.moduleSubscriptions)
      AppSearchBarFilterGroup(
        key: _FilterKeys.module,
        label: _SubscriptionsText.module,
        allLabel: _SubscriptionsText.allModules,
        choices: _choices(lookups.modules),
      ),
    if (lookups.fitStatuses.isNotEmpty &&
        <SubscriptionResource>{
          SubscriptionResource.subscriptions,
          SubscriptionResource.moduleSubscriptions,
        }.contains(state.query.resource))
      AppSearchBarFilterGroup(
        key: _FilterKeys.fit,
        label: _SubscriptionsText.fitStatus,
        allLabel: _SubscriptionsText.allFitStatuses,
        choices: _choices(lookups.fitStatuses),
      ),
    if (lookups.invoiceStatuses.isNotEmpty &&
        state.query.resource == SubscriptionResource.subscriptionInvoices)
      AppSearchBarFilterGroup(
        key: _FilterKeys.invoice,
        label: _SubscriptionsText.invoiceStatus,
        allLabel: _SubscriptionsText.allInvoiceStatuses,
        choices: _choices(lookups.invoiceStatuses),
      ),
    if (lookups.licenseTypes.isNotEmpty &&
        state.query.resource == SubscriptionResource.licenses)
      AppSearchBarFilterGroup(
        key: _FilterKeys.license,
        label: _SubscriptionsText.licenseType,
        allLabel: _SubscriptionsText.allLicenseTypes,
        choices: _choices(lookups.licenseTypes),
      ),
    if (state.query.resource == SubscriptionResource.moduleSubscriptions)
      AppSearchBarFilterGroup(
        key: _FilterKeys.eligibility,
        label: _SubscriptionsText.eligibility,
        allLabel: _SubscriptionsText.allEligibility,
        choices: _choices(lookups.eligibilityStates),
      ),
    AppSearchBarFilterGroup(
      key: _FilterKeys.datePreset,
      label: _SubscriptionsText.datePreset,
      allLabel: _SubscriptionsText.anyDate,
      choices: _datePresetChoices(),
    ),
  ];
}

AppSearchBarFilterValue _filterValue(SubscriptionsWorkspaceQuery query) {
  final Map<String, String> options = <String, String>{
    if (_hasText(query.status)) _FilterKeys.status: query.status!,
    if (_hasText(query.tierCode)) _FilterKeys.tier: query.tierCode!,
    if (_hasText(query.billingCycle))
      _FilterKeys.billingCycle: query.billingCycle!,
    if (_hasText(query.planId)) _FilterKeys.plan: query.planId!,
    if (_hasText(query.moduleId)) _FilterKeys.module: query.moduleId!,
    if (_hasText(query.fitStatus)) _FilterKeys.fit: query.fitStatus!,
    if (_hasText(query.invoiceStatus))
      _FilterKeys.invoice: query.invoiceStatus!,
    if (_hasText(query.licenseType)) _FilterKeys.license: query.licenseType!,
    if (_hasText(query.eligibilityState))
      _FilterKeys.eligibility: query.eligibilityState!,
    if (query.datePreset != SubscriptionDatePreset.none)
      _FilterKeys.datePreset: query.datePreset.serverValue,
  };
  return AppSearchBarFilterValue(options: options);
}

List<AppSearchBarFilterChoice> _choices(List<SubscriptionLookupItem> items) {
  return <AppSearchBarFilterChoice>[
    for (final SubscriptionLookupItem item in items)
      AppSearchBarFilterChoice(value: item.id, label: item.label),
  ];
}

List<AppSearchBarFilterChoice> _statusChoices(
  SubscriptionsWorkspaceState state,
) {
  return switch (state.query.resource) {
    SubscriptionResource.moduleSubscriptions =>
      const <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: _SubscriptionStatuses.active,
          label: _SubscriptionsText.active,
        ),
        AppSearchBarFilterChoice(
          value: _SubscriptionStatuses.inactive,
          label: _SubscriptionsText.inactive,
        ),
      ],
    SubscriptionResource.subscriptionInvoices => _choices(
      state.lookups.invoiceStatuses,
    ),
    SubscriptionResource.licenses ||
    SubscriptionResource.subscriptions => _choices(state.lookups.statuses),
    _ => const <AppSearchBarFilterChoice>[],
  };
}

List<AppSearchBarFilterChoice> _datePresetChoices() {
  return const <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: _DatePresetValues.today,
      label: _SubscriptionsText.today,
      icon: Icons.today_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _DatePresetValues.last30Days,
      label: _SubscriptionsText.last30Days,
      icon: Icons.history_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _DatePresetValues.next30Days,
      label: _SubscriptionsText.next30Days,
      icon: Icons.event_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _DatePresetValues.nextRenewal,
      label: _SubscriptionsText.nextRenewal,
      icon: Icons.event_repeat_outlined,
    ),
  ];
}

SubscriptionDatePreset _datePresetFromFilter(String? value) {
  return SubscriptionDatePreset.fromServer(value);
}

String? _emptyOption(String? value) {
  return _hasText(value) ? value : null;
}

List<AppSelectOption<String>> _lookupOptions(
  List<SubscriptionLookupItem> items,
) {
  final seen = <String>{};
  return <AppSelectOption<String>>[
    for (final SubscriptionLookupItem item in items)
      if (seen.add(item.id))
        AppSelectOption<String>(
          value: item.id,
          label: _joinDisplay(<String?>[item.label, item.subtitle]),
        ),
  ];
}

List<AppSelectOption<String>> _tierOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _TierValues.free,
      label: _SubscriptionsText.free,
    ),
    AppSelectOption<String>(
      value: _TierValues.basic,
      label: _SubscriptionsText.basic,
    ),
    AppSelectOption<String>(
      value: _TierValues.pro,
      label: _SubscriptionsText.pro,
    ),
    AppSelectOption<String>(
      value: _TierValues.advanced,
      label: _SubscriptionsText.advanced,
    ),
    AppSelectOption<String>(
      value: _TierValues.custom,
      label: _SubscriptionsText.custom,
    ),
  ];
}

List<AppSelectOption<String>> _billingCycleOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _BillingCycles.monthly,
      label: _SubscriptionsText.monthly,
    ),
    AppSelectOption<String>(
      value: _BillingCycles.quarterly,
      label: _SubscriptionsText.quarterly,
    ),
    AppSelectOption<String>(
      value: _BillingCycles.yearly,
      label: _SubscriptionsText.yearly,
    ),
  ];
}

List<AppSelectOption<String>> _subscriptionStatusOptions({
  bool includeCancelled = true,
}) {
  return <AppSelectOption<String>>[
    const AppSelectOption<String>(
      value: _SubscriptionStatuses.active,
      label: _SubscriptionsText.active,
    ),
    const AppSelectOption<String>(
      value: _SubscriptionStatuses.trial,
      label: _SubscriptionsText.trial,
    ),
    const AppSelectOption<String>(
      value: _SubscriptionStatuses.pastDue,
      label: _SubscriptionsText.pastDue,
    ),
    if (includeCancelled)
      const AppSelectOption<String>(
        value: _SubscriptionStatuses.cancelled,
        label: _SubscriptionsText.cancelled,
      ),
  ];
}

List<AppSelectOption<String>> _licenseTypeOptions(
  SubscriptionsWorkspaceState state,
) {
  if (state.lookups.licenseTypes.isNotEmpty) {
    return _lookupOptions(state.lookups.licenseTypes);
  }
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _LicenseTypes.perUser,
      label: _SubscriptionsText.perUser,
    ),
    AppSelectOption<String>(
      value: _LicenseTypes.perFacility,
      label: _SubscriptionsText.perFacility,
    ),
    AppSelectOption<String>(
      value: _LicenseTypes.enterprise,
      label: _SubscriptionsText.enterprise,
    ),
  ];
}

List<AppSelectOption<String>> _paymentMethodOptions() {
  return buildAppPaymentMethodSelectOptions(
    methods: const <String>[
      _PaymentMethods.cash,
      _PaymentMethods.mobileMoney,
      _PaymentMethods.bankTransfer,
      _PaymentMethods.card,
      _PaymentMethods.other,
    ],
    labelOf: (String method) => switch (method) {
      _PaymentMethods.cash => _SubscriptionsText.cash,
      _PaymentMethods.mobileMoney => _SubscriptionsText.mobileMoney,
      _PaymentMethods.bankTransfer => _SubscriptionsText.bankTransfer,
      _PaymentMethods.card => _SubscriptionsText.card,
      _PaymentMethods.other => _SubscriptionsText.other,
      _ => method,
    },
  );
}

String? _optionalIntegerValidator(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized) == null
      ? _SubscriptionsText.integerInvalid
      : null;
}

String _resourceLabel(SubscriptionResource resource) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans => _SubscriptionsText.plans,
    SubscriptionResource.modules => _SubscriptionsText.modules,
    SubscriptionResource.subscriptions => _SubscriptionsText.subscriptions,
    SubscriptionResource.moduleSubscriptions =>
      _SubscriptionsText.moduleSubscriptions,
    SubscriptionResource.subscriptionInvoices => _SubscriptionsText.invoices,
    SubscriptionResource.licenses => _SubscriptionsText.licenses,
  };
}

IconData _resourceIcon(SubscriptionResource resource) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans => Icons.workspace_premium_outlined,
    SubscriptionResource.modules => Icons.view_module_outlined,
    SubscriptionResource.subscriptions => Icons.verified_user_outlined,
    SubscriptionResource.moduleSubscriptions => Icons.extension_outlined,
    SubscriptionResource.subscriptionInvoices => Icons.receipt_long_outlined,
    SubscriptionResource.licenses => Icons.key_outlined,
  };
}

IconData _moduleIconForLookup(SubscriptionLookupItem module) {
  final String key = '${module.subtitle ?? ''} ${module.id} ${module.label}'
      .toLowerCase();

  if (_moduleKeyMatches(key, const <String>[
    'patient',
    'registry',
    'consent',
  ])) {
    return AppRouteIcons.patients;
  }
  if (_moduleKeyMatches(key, const <String>[
    'schedul',
    'queue',
    'opd',
    'appointment',
  ])) {
    return AppRouteIcons.opd;
  }
  if (_moduleKeyMatches(key, const <String>[
    'encounter',
    'vital',
    'clinical',
  ])) {
    return AppRouteIcons.clinical;
  }
  if (_moduleKeyMatches(key, const <String>['nurs'])) {
    return AppRouteIcons.nursing;
  }
  if (_moduleKeyMatches(key, const <String>['ipd', 'bed', 'ward'])) {
    return AppRouteIcons.ipd;
  }
  if (_moduleKeyMatches(key, const <String>['icu', 'critical'])) {
    return AppRouteIcons.icu;
  }
  if (_moduleKeyMatches(key, const <String>['lab', 'patholog'])) {
    return AppRouteIcons.lab;
  }
  if (_moduleKeyMatches(key, const <String>['radiolog', 'imaging'])) {
    return AppRouteIcons.radiology;
  }
  if (_moduleKeyMatches(key, const <String>['pharmac', 'dispens'])) {
    return AppRouteIcons.pharmacy;
  }
  if (_moduleKeyMatches(key, const <String>[
    'billing',
    'payment',
    'insurance',
    'claim',
  ])) {
    return AppRouteIcons.billing;
  }
  if (_moduleKeyMatches(key, const <String>['housekeep', 'cleaning'])) {
    return AppRouteIcons.housekeeping;
  }
  if (_moduleKeyMatches(key, const <String>['biomed', 'equipment'])) {
    return AppRouteIcons.biomedical;
  }
  if (_moduleKeyMatches(key, const <String>['hr', 'roster', 'staff'])) {
    return AppRouteIcons.hr;
  }
  if (_moduleKeyMatches(key, const <String>['emergenc', 'triage'])) {
    return AppRouteIcons.emergency;
  }
  if (_moduleKeyMatches(key, const <String>['mortuar'])) {
    return AppRouteIcons.mortuary;
  }
  if (_moduleKeyMatches(key, const <String>[
    'notif',
    'sms',
    'communicat',
    'message',
  ])) {
    return AppRouteIcons.communications;
  }
  if (_moduleKeyMatches(key, const <String>['integrat', 'webhook', 'api'])) {
    return AppRouteIcons.integrations;
  }
  if (_moduleKeyMatches(key, const <String>['report', 'analytic', 'insight'])) {
    return AppRouteIcons.reports;
  }
  if (_moduleKeyMatches(key, const <String>[
    'subscription',
    'licens',
    'plan',
  ])) {
    return AppRouteIcons.subscriptions;
  }
  if (_moduleKeyMatches(key, const <String>[
    'facilit',
    'maintenance',
    'operation',
  ])) {
    return AppRouteIcons.operations;
  }
  if (_moduleKeyMatches(key, const <String>['theater', 'theatre', 'surgery'])) {
    return AppRouteIcons.theater;
  }
  if (_moduleKeyMatches(key, const <String>['discharge'])) {
    return AppRouteIcons.discharge;
  }
  if (_moduleKeyMatches(key, const <String>[
    'auth',
    'rbac',
    'access',
    'role',
  ])) {
    return AppRouteIcons.accessAdmin;
  }
  if (_moduleKeyMatches(key, const <String>['compliance', 'audit'])) {
    return Icons.policy_outlined;
  }
  if (_moduleKeyMatches(key, const <String>['storage', 'disk'])) {
    return Icons.sd_storage_outlined;
  }
  if (_moduleKeyMatches(key, const <String>['inventory', 'procure'])) {
    return Icons.inventory_2_outlined;
  }
  if (_moduleKeyMatches(key, const <String>['setting', 'config'])) {
    return AppRouteIcons.settings;
  }

  return Icons.extension_outlined;
}

bool _moduleKeyMatches(String key, List<String> tokens) {
  for (final String token in tokens) {
    if (key.contains(token)) {
      return true;
    }
  }
  return false;
}

String _panelLabel(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => _SubscriptionsText.overview,
    SubscriptionPanel.catalog => _SubscriptionsText.plans,
    SubscriptionPanel.modules => _SubscriptionsText.modules,
    SubscriptionPanel.operations => _SubscriptionsText.subscriptions,
    SubscriptionPanel.billing => _SubscriptionsText.invoices,
    SubscriptionPanel.governance => _SubscriptionsText.licenses,
    SubscriptionPanel.denied => _SubscriptionsText.deniedModules,
  };
}

IconData _panelIcon(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => Icons.dashboard_customize_outlined,
    SubscriptionPanel.catalog => Icons.workspace_premium_outlined,
    SubscriptionPanel.modules => Icons.view_module_outlined,
    SubscriptionPanel.operations => Icons.verified_user_outlined,
    SubscriptionPanel.billing => Icons.receipt_long_outlined,
    SubscriptionPanel.governance => Icons.key_outlined,
    SubscriptionPanel.denied => Icons.block_outlined,
  };
}

SubscriptionResource _defaultResourceForPanel(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => SubscriptionResource.subscriptions,
    SubscriptionPanel.catalog => SubscriptionResource.subscriptionPlans,
    SubscriptionPanel.modules => SubscriptionResource.modules,
    SubscriptionPanel.operations => SubscriptionResource.subscriptions,
    SubscriptionPanel.billing => SubscriptionResource.subscriptionInvoices,
    SubscriptionPanel.governance => SubscriptionResource.licenses,
    SubscriptionPanel.denied => SubscriptionResource.moduleSubscriptions,
  };
}

List<SubscriptionResource> _resourcesForPanel(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => const <SubscriptionResource>[],
    SubscriptionPanel.catalog => const <SubscriptionResource>[
      SubscriptionResource.subscriptionPlans,
    ],
    SubscriptionPanel.modules => const <SubscriptionResource>[
      SubscriptionResource.modules,
    ],
    SubscriptionPanel.operations => const <SubscriptionResource>[
      SubscriptionResource.subscriptions,
    ],
    SubscriptionPanel.billing => const <SubscriptionResource>[
      SubscriptionResource.subscriptionInvoices,
    ],
    SubscriptionPanel.governance => const <SubscriptionResource>[
      SubscriptionResource.licenses,
    ],
    SubscriptionPanel.denied => const <SubscriptionResource>[
      SubscriptionResource.moduleSubscriptions,
    ],
  };
}

AppSearchBarAction? _worklistCreateAction(
  BuildContext context,
  WidgetRef ref,
  AppAccessPolicy accessPolicy,
  SubscriptionsWorkspaceState state,
) {
  // Denied / Modules / Invoices / Overview: no create primary on the worklist.
  if (state.query.panel == SubscriptionPanel.denied ||
      state.query.panel == SubscriptionPanel.modules ||
      state.query.panel == SubscriptionPanel.billing ||
      state.query.panel == SubscriptionPanel.overview) {
    return null;
  }

  if (state.query.resource == SubscriptionResource.subscriptionPlans) {
    if (!SubscriptionsPlansAtomPermissions.create.isAllowed(accessPolicy)) {
      return null;
    }
    return AppSearchBarAction(
      icon: Icons.add,
      label: _SubscriptionsText.createPlan,
      tooltip: _SubscriptionsText.createPlan,
      enabled: !state.isSaving,
      onPressed: state.isSaving
          ? null
          : () => _showPlanDialog(context, ref),
    );
  }

  if (state.query.resource == SubscriptionResource.subscriptions) {
    if (!SubscriptionsAtomPermissions.create.isAllowed(accessPolicy)) {
      return null;
    }
    return AppSearchBarAction(
      icon: Icons.add,
      label: _SubscriptionsText.newSubscription,
      tooltip: _SubscriptionsText.newSubscription,
      enabled: !state.isSaving && state.lookups.tenants.isNotEmpty,
      onPressed: state.isSaving || state.lookups.tenants.isEmpty
          ? null
          : () => _showSubscriptionDialog(context, ref, state),
    );
  }

  if (state.query.resource == SubscriptionResource.licenses) {
    if (!SubscriptionsLicensesAtomPermissions.create.isAllowed(accessPolicy)) {
      return null;
    }
    return AppSearchBarAction(
      icon: Icons.key_outlined,
      label: _SubscriptionsText.addLicense,
      tooltip: _SubscriptionsText.addLicense,
      enabled: !state.isSaving && state.lookups.tenants.isNotEmpty,
      onPressed: state.isSaving || state.lookups.tenants.isEmpty
          ? null
          : () => _showLicenseDialog(context, ref, state),
    );
  }

  return null;
}

String? _querySignature(SubscriptionsWorkspaceQuery? query) {
  if (query == null) {
    return null;
  }
  return <Object?>[
    query.panel.serverValue,
    query.resource.serverValue,
    query.queue,
    query.search,
    query.tenantId,
    query.recordId,
    query.action,
    query.status,
    query.tierCode,
    query.billingCycle,
    query.planId,
    query.moduleId,
    query.fitStatus,
    query.changeStatus,
    query.invoiceStatus,
    query.licenseType,
    query.eligibilityState,
    query.datePreset.serverValue,
  ].join('::');
}

String _uniquePlanLabel(SubscriptionItem item) {
  return switch (item.resource) {
    SubscriptionResource.subscriptionPlans =>
      item.tierCode ?? item.name ?? item.title,
    SubscriptionResource.modules =>
      item.tierCode ?? item.code ?? _SubscriptionsText.notRecorded,
    SubscriptionResource.moduleSubscriptions =>
      item.planLabel ?? item.moduleLabel ?? _SubscriptionsText.notRecorded,
    _ => item.planLabel ?? item.name ?? _SubscriptionsText.notRecorded,
  };
}

String _amountOrLimit(BuildContext context, SubscriptionItem item) {
  final num? amount = item.totalAmount ?? item.price;
  if (amount != null) {
    return _money(context, amount, item.currency);
  }
  final List<String> limits = <String>[
    if (item.maxUsers != null) _SubscriptionsText.usersLimit(item.maxUsers!),
    if (item.maxModules != null)
      _SubscriptionsText.modulesLimit(item.maxModules!),
  ];
  return limits.isEmpty ? _SubscriptionsText.notRecorded : limits.join(' | ');
}

String _money(BuildContext context, num? value, String? currencyCode) {
  if (value == null) {
    return _SubscriptionsText.notRecorded;
  }
  return AppFormatters.currency(
    value,
    Localizations.localeOf(context),
    currencyCode: currencyCode ?? subscriptionPlanBaseCurrencyCode,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}

String _date(BuildContext context, DateTime? value) {
  return value == null
      ? _SubscriptionsText.notRecorded
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

String _periodRemaining(DateTime? endDate) {
  if (endDate == null) {
    return _SubscriptionsText.notRecorded;
  }
  final DateTime today = DateTime.now();
  final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
  final DateTime start = DateTime(today.year, today.month, today.day);
  final int days = end.difference(start).inDays;
  if (days < 0) {
    return 'Expired';
  }
  if (days == 0) {
    return 'Expires today';
  }
  if (days == 1) {
    return '1 day';
  }
  return '$days days';
}

String _cohortTitle(SubscriptionTenantCohort cohort) {
  return switch (cohort) {
    SubscriptionTenantCohort.active => _SubscriptionsText.activePlans,
    SubscriptionTenantCohort.notSubscribed => _SubscriptionsText.notSubscribed,
    SubscriptionTenantCohort.closed => _SubscriptionsText.closedSubscriptions,
  };
}

IconData _cohortIcon(SubscriptionTenantCohort cohort) {
  return switch (cohort) {
    SubscriptionTenantCohort.active => Icons.verified_outlined,
    SubscriptionTenantCohort.notSubscribed => Icons.person_off_outlined,
    SubscriptionTenantCohort.closed => Icons.cancel_outlined,
  };
}

DateTime? _timelineDate(SubscriptionItem item) {
  return item.endDate ??
      item.expiresAt ??
      item.issuedAt ??
      item.updatedAt ??
      item.paidAt;
}

String _statusLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return _SubscriptionsText.notRecorded;
  }
  return normalized
      .replaceAll('-', '_')
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

AppWorkspaceStatusTone _statusTone(String? status) {
  final String normalized = status?.trim().toUpperCase() ?? '';
  if (<String>{
    'ACTIVE',
    'TRIAL',
    'PAID',
    'HEALTHY',
    'FIT',
  }.contains(normalized)) {
    return AppWorkspaceStatusTone.success;
  }
  if (<String>{
    'PAST_DUE',
    'OVERDUE',
    'PARTIAL',
    'WARNING',
    'PENDING',
    'SENT',
    'NOT_SUBSCRIBED',
  }.contains(normalized)) {
    return AppWorkspaceStatusTone.warning;
  }
  if (<String>{
    'DENIED',
    'CANCELLED',
    'CRITICAL',
    'INACTIVE',
    'DISABLED',
  }.contains(normalized)) {
    return AppWorkspaceStatusTone.error;
  }
  return AppWorkspaceStatusTone.neutral;
}

IconData _statusIcon(String? status) {
  final AppWorkspaceStatusTone tone = _statusTone(status);
  return switch (tone) {
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
    AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
  };
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

final DateTime _subscriptionFirstDate = DateTime(2000);
final DateTime _subscriptionLastDate = DateTime(2100, 12, 31);

DateTime? _dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day);
}

String? _datePayload(DateTime? value) {
  final DateTime? normalized = _dateOnly(value);
  if (normalized == null) {
    return null;
  }
  return normalized.toUtc().toIso8601String();
}

Widget _subscriptionDateField({
  required BuildContext context,
  required String labelText,
  required DateTime? value,
  required ValueChanged<DateTime?> onChanged,
}) {
  return AppDateField(
    value: value,
    labelText: labelText,
    hintText: _SubscriptionsText.dateHint,
    firstDate: _subscriptionFirstDate,
    lastDate: _subscriptionLastDate,
    currentDate: DateTime.now(),
    pickerButtonLabel: _SubscriptionsText.pickDate,
    invalidDateMessage: context.l10n.appDateInvalidMessage,
    onChanged: onChanged,
  );
}

final class _LimitRow {
  const _LimitRow({
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int? used;
  final int? limit;
}

abstract final class _FilterKeys {
  static const String status = 'status';
  static const String tier = 'tier';
  static const String billingCycle = 'billing_cycle';
  static const String plan = 'plan';
  static const String module = 'module';
  static const String fit = 'fit';
  static const String invoice = 'invoice';
  static const String license = 'license';
  static const String eligibility = 'eligibility';
  static const String datePreset = 'date_preset';
}

abstract final class _SummaryIds {
  static const String pendingChanges = 'pending_changes';
  static const String pastDueInvoices = 'past_due_invoices';
  static const String deniedModules = 'denied_modules';
  static const String expiringLicenses = 'expiring_licenses';
  static const String approachingLimits = 'approaching_limits';
}

abstract final class _QueueIds {
  static const String renewalsDue = 'renewals_due';
  static const String pastDueBilling = 'past_due_billing';
  static const String upgradeRecommended = 'upgrade_recommended';
  static const String pendingChanges = 'pending_changes';
}

abstract final class _BillingCycles {
  static const String monthly = 'MONTHLY';
  static const String quarterly = 'QUARTERLY';
  static const String yearly = 'YEARLY';
}

abstract final class _TierValues {
  static const String free = 'FREE';
  static const String basic = 'BASIC';
  static const String pro = 'PRO';
  static const String advanced = 'ADVANCED';
  static const String custom = 'CUSTOM';
}

abstract final class _SubscriptionStatuses {
  static const String active = 'ACTIVE';
  static const String inactive = 'INACTIVE';
  static const String trial = 'TRIAL';
  static const String pastDue = 'PAST_DUE';
  static const String cancelled = 'CANCELLED';
}

abstract final class _SubscriptionChangeTypes {
  static const String upgrade = 'upgrade';
  static const String downgrade = 'downgrade';
}

abstract final class _LicenseTypes {
  static const String perUser = 'PER_USER';
  static const String perFacility = 'PER_FACILITY';
  static const String enterprise = 'ENTERPRISE';
}

abstract final class _PaymentMethods {
  static const String cash = 'CASH';
  static const String mobileMoney = 'MOBILE_MONEY';
  static const String bankTransfer = 'BANK_TRANSFER';
  static const String card = 'CREDIT_CARD';
  static const String other = 'OTHER';
}

abstract final class _DatePresetValues {
  static const String today = 'today';
  static const String last30Days = 'last_30_days';
  static const String next30Days = 'next_30_days';
  static const String nextRenewal = 'next_renewal';
}

abstract final class _SubscriptionsText {
  static const String title = 'Subscriptions';
  static const String loadingTitle = 'Loading subscriptions';
  static const String loadingBody =
      'Fetching plans, subscriptions, modules, licenses, and invoices.';
  static const String savedMessage = 'Subscription workspace updated.';
  static const String overview = 'Overview';
  static const String activePlans = 'Active plans';
  static const String notSubscribed = 'Not subscribed';
  static const String closedSubscriptions = 'Closed subscriptions';
  static const String pendingChanges = 'Pending changes';
  static const String pastDueInvoices = 'Past due invoices';
  static const String pastDue = 'Past due';
  static const String deniedModules = 'Denied modules';
  static const String expiringLicenses = 'Expiring licenses';
  static const String approachingLimits = 'Approaching limits';
  static const String attentionChartTitle = 'Workspace attention';
  static const String attentionChartSubtitle =
      'Current counts from subscription summary metrics';
  static const String attentionChartEmpty = 'No attention metrics yet.';
  static const String cohortChartTitle = 'Tenant cohorts';
  static const String cohortChartTotalLabel = 'Tenants';
  static const String cohortChartEmpty = 'No tenant cohort data yet.';
  static const String activeSubscriptionsChart = 'Active subscriptions';
  static const String attentionSectionTitle = 'Billing and license attention';
  static const String nextInvoiceAttention = 'Next invoice';
  static const String licenseAttention = 'Licenses';
  static String licenseAttentionBody(int active, int expiring) {
    return '$active active · $expiring expiring';
  }
  static const String renewalExpiry = 'Renewal / expiry';
  static const String licenses = 'Licenses';
  static const String users = 'Users';
  static const String facilities = 'Facilities';
  static const String storageMb = 'Storage MB';
  static const String modules = 'Modules';
  static const String includedModules = 'Included modules';
  static const String includedModulesCheckboxHint =
      'Checked modules are visible in the app menu for tenants on this plan.';
  static const String includedModulesAccessHint =
      'Modules control what appears in the app menu and what the tenant can access.';
  static const String manageModules = 'Manage modules';
  static const String addOn = 'Add-on';
  static const String saveModules = 'Save modules';
  static const String selectAllModules = 'Select all';
  static const String clearAllModules = 'Clear all';
  static const String noModulesAvailable = 'No modules are available yet.';
  static String modulesSelectedCount(int selected, int total) {
    return '$selected of $total selected';
  }

  static const String noModulesIncluded = 'No modules included yet.';
  static const String planDescription = 'Short description';
  static const String freePlan = 'Free';
  static const String freePlanPricingHint =
      'Free plans have no monthly or annual charge.';
  static const String pricing = 'Pricing';
  static const String activeTenants = 'Active tenants';
  static const String pendingApprovals = 'Pending approvals';
  static const String linkedTenants = 'Tenants on this plan';
  static const String noLinkedTenants = 'No active tenants on this plan yet.';
  static const String noPendingApprovals =
      'No pending approvals for this plan.';
  static const String recommendations = 'Recommendations';
  static const String searchLabel = 'Search subscriptions';
  static const String searchHint =
      'Tenant, plan, module, invoice, status, or date';
  static const String clearSearch = 'Clear subscription search';
  static const String applyFilters = 'Apply filters';
  static const String clearFilters = 'Clear filters';
  static const String all = 'All';
  static const String emptyTitle = 'No subscription records';
  static const String emptyBody =
      'Adjust the filters or create a subscription to populate this view.';
  static const String previousPage = 'Previous subscription page';
  static const String nextPage = 'Next subscription page';
  static const String record = 'Record';
  static const String status = 'Status';
  static const String amountLimit = 'Amount / limit';
  static const String detailTitle = 'Subscription detail';
  static const String planDetailTitle = 'Subscription plan details';
  static String planDetailTitleWithName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return planDetailTitle;
    }
    return '$planDetailTitle · $trimmed';
  }

  static const String noSelectionTitle = 'Select a record';
  static const String noSelectionBody =
      'Choose a subscription record to review plan limits, modules, invoices, licenses, and next actions.';
  static const String quickActions = 'Quick actions';
  static const String plans = 'Plans';
  static const String subscriptions = 'Subscriptions';
  static const String moduleSubscriptions = 'Module subscriptions';
  static const String invoices = 'Invoices';
  static const String createPlan = 'Create plan';
  static const String editPlan = 'Edit plan';
  static const String savePlan = 'Save plan';
  static const String newSubscription = 'New subscription';
  static const String editSubscription = 'Edit subscription';
  static const String saveSubscription = 'Save subscription';
  static const String assignModule = 'Assign module';
  static const String moduleAccessTitle = 'Module access';
  static const String moduleAccessSubtitle =
      'Modules this tenant can use, and modules still unavailable';
  static const String moduleAccessLoadingTitle = 'Loading modules';
  static const String moduleAccessLoadingBody =
      'Fetching granted and unavailable modules for this subscription.';
  static const String grantedModules = 'Granted modules';
  static const String grantedModulesEmpty =
      'No active modules are granted to this tenant yet.';
  static const String unavailableModules = 'Unavailable modules';
  static const String unavailableModulesEmpty =
      'All catalog modules are already assigned and active.';
  static const String moduleNotAssigned = 'Not assigned';
  static const String inactiveModule = 'Inactive';
  static const String moduleActiveStatus = 'Active';
  static const String addLicense = 'Add license';
  static const String updateLicense = 'Update license';
  static const String revokeLicense = 'Revoke license';
  static const String revokeLicenseBody =
      'Revoke this license? The tenant loses license access according to plan rules.';
  static const String renew = 'Renew';
  static const String changePlan = 'Change plan';
  static const String activate = 'Activate';
  static const String cancelSubscription = 'Cancel subscription';
  static const String cancelSubscriptionBody =
      'Cancel this subscription? Paid subscriptions cannot be cancelled. Free or unpaid access may end according to plan rules.';
  static const String cancelledStatusEditHint =
      'Status is Cancelled. Use Activate to restore access; this form only updates dates.';
  static const String enableModule = 'Enable module';
  static const String disableModule = 'Disable module';
  static const String collectInvoice = 'Collect invoice';
  static const String retryInvoice = 'Retry invoice';
  static const String tenant = 'Tenant';
  static const String plan = 'Plan';
  static const String planId = 'Plan ID';
  static const String module = 'Module';
  static const String billingCycle = 'Billing cycle';
  static const String defaultBillingCycle = 'Default billing cycle';
  static const String amount = 'Amount';
  static const String fitStatus = 'Fit status';
  static const String allFitStatuses = 'All fit statuses';
  static const String startDate = 'Start date';
  static const String endDate = 'End date';
  static const String expiryDate = 'Expiry date';
  static const String noAccountsInCohort = 'No accounts in this group yet.';
  static const String updated = 'Updated';
  static const String timeline = 'Activity';
  static const String notRecorded = 'Not recorded';
  static const String planName = 'Plan name';
  static const String planCode = 'Plan code';
  static const String tier = 'Tier';
  static const String monthlyPriceUsd = 'Monthly (USD)';
  static const String annualPriceUsd = 'Annual (USD)';
  static const String maxUsers = 'Max users';
  static const String maxFacilities = 'Max facilities';
  static const String maxStorage = 'Max storage MB';
  static const String maxModules = 'Max modules';
  static const String planNameRequired = 'Enter a plan name.';
  static const String amountInvalid = 'Enter a valid amount.';
  static const String integerInvalid = 'Enter a whole number.';
  static const String tenantRequired = 'Select a tenant.';
  static const String planRequired = 'Select a plan.';
  static const String subscriptionRequired = 'Select a subscription.';
  static const String moduleRequired = 'Select a module.';
  static const String dateHint = 'DD / MM / YYYY';
  static const String pickDate = 'Pick date';
  static const String targetPlan = 'Target plan';
  static const String changeType = 'Change type';
  static const String upgrade = 'Upgrade';
  static const String downgrade = 'Downgrade';
  static const String effectiveAt = 'Effective at';
  static const String reason = 'Reason';
  static const String newEndDate = 'New end date';
  static const String subscription = 'Subscription';
  static const String enabled = 'Enabled';
  static const String licenseType = 'License type';
  static const String issuedAt = 'Issued at';
  static const String expiresAt = 'Expires at';
  static const String paymentMethod = 'Payment method';
  static const String notes = 'Notes';
  static const String retryReason = 'Retry reason';
  static const String allStatuses = 'All statuses';
  static const String allTiers = 'All tiers';
  static const String allBillingCycles = 'All billing cycles';
  static const String allPlans = 'All plans';
  static const String allModules = 'All modules';
  static const String invoiceStatus = 'Invoice status';
  static const String allInvoiceStatuses = 'All invoice statuses';
  static const String allLicenseTypes = 'All license types';
  static const String eligibility = 'Eligibility';
  static const String allEligibility = 'All eligibility';
  static const String datePreset = 'Date';
  static const String anyDate = 'Any date';
  static const String today = 'Today';
  static const String last30Days = 'Last 30 days';
  static const String next30Days = 'Next 30 days';
  static const String nextRenewal = 'Next renewal';
  static const String free = 'Free';
  static const String basic = 'Basic';
  static const String pro = 'Pro';
  static const String advanced = 'Advanced';
  static const String custom = 'Custom';
  static const String monthly = 'Monthly';
  static const String quarterly = 'Quarterly';
  static const String yearly = 'Yearly';
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String trial = 'Trial';
  static const String cancelled = 'Cancelled';
  static const String perUser = 'Per user';
  static const String perFacility = 'Per facility';
  static const String enterprise = 'Enterprise';
  static const String cash = 'Cash';
  static const String mobileMoney = 'Mobile money';
  static const String bankTransfer = 'Bank transfer';
  static const String card = 'Card';
  static const String other = 'Other';

  static String cohortDialogDescription(int count) {
    return count == 1
        ? '1 account in this group.'
        : '$count accounts in this group.';
  }

  static String pageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  static String limitValue(int used, int limit) {
    return '$used / $limit';
  }

  static String usersLimit(int value) {
    return '$value users';
  }

  static String modulesLimit(int value) {
    return '$value modules';
  }
}
