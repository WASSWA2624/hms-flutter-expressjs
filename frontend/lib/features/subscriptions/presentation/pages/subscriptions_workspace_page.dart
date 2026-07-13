import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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
        final bool canWrite = ref
            .read(appAccessPolicyProvider)
            .grants(AppPermissions.subscriptionsWrite);
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
    final bool canWrite = accessPolicy.grants(
      AppPermissions.subscriptionsWrite,
    );
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    final Object? failure = state.lastFailure;
    final AppFailure? lastFailure = failure is AppFailure ? failure : null;

    final List<Widget> panelActions = <Widget>[
      for (final SubscriptionPanel panel in SubscriptionPanel.values)
        AppButton(
          label: _panelLabel(panel),
          leadingIcon: _panelIcon(panel),
          variant: state.query.panel == panel
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: state.query.panel == panel || state.isRefreshing
              ? null
              : () => controller.applyPanel(panel),
        ),
    ];

    return AppWorkspace(
      title: _SubscriptionsText.title,
      leadingIcon: AppRouteIcons.subscriptions,
      toolbar: appWorkspaceToolbarWithLabels(
        context.l10n,
        maxVisibleScreenActions: 2,
        summaryNotifications: _summaryNotifications(context, state),
        primary: _primaryAction(context, canWrite, state),
        onRefresh: controller.refresh,
        isRefreshing: state.isRefreshing,
        overflowSections: <AppToolbarOverflowSection>[
          AppToolbarOverflowSection(
            headerLabel: _SubscriptionsText.viewsMenu,
            actions: panelActions,
          ),
          const AppToolbarOverflowSection(showsNotifications: true),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _SubscriptionOverviewPanel(
            state: state,
            canWrite: canWrite,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _SubscriptionsWorklistPanel(
            state: state,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
            onItemSelected: (SubscriptionItem item) {
              unawaited(
                _openSubscriptionDetailDialog(context, ref, item, canWrite),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget? _primaryAction(
    BuildContext context,
    bool canWrite,
    SubscriptionsWorkspaceState state,
  ) {
    if (!canWrite) {
      return null;
    }
    return switch (state.query.resource) {
      SubscriptionResource.subscriptionPlans => AppButton.primary(
        label: _SubscriptionsText.createPlan,
        leadingIcon: Icons.add,
        enabled: !state.isSaving,
        onPressed: () => _showPlanDialog(context, ref),
      ),
      SubscriptionResource.subscriptions => AppButton.primary(
        label: _SubscriptionsText.activateSubscription,
        leadingIcon: Icons.play_circle_outline,
        enabled: !state.isSaving && state.lookups.tenants.isNotEmpty,
        onPressed: () => _showSubscriptionDialog(context, ref, state),
      ),
      SubscriptionResource.moduleSubscriptions => AppButton.primary(
        label: _SubscriptionsText.assignModule,
        leadingIcon: Icons.extension_outlined,
        enabled: !state.isSaving && state.lookups.modules.isNotEmpty,
        onPressed: () => _showModuleSubscriptionDialog(context, ref, state),
      ),
      SubscriptionResource.licenses => AppButton.primary(
        label: _SubscriptionsText.addLicense,
        leadingIcon: Icons.key_outlined,
        enabled: !state.isSaving && state.lookups.tenants.isNotEmpty,
        onPressed: () => _showLicenseDialog(context, ref, state),
      ),
      _ => null,
    };
  }

  List<AppWorkspaceSummaryNotification> _summaryNotifications(
    BuildContext context,
    SubscriptionsWorkspaceState state,
  ) {
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    SubscriptionQueueSummary? queueById(String id) {
      for (final SubscriptionQueueSummary queue in state.queueSummaries) {
        if (queue.id == id) {
          return queue;
        }
      }
      return null;
    }

    AppWorkspaceSummaryNotification card({
      required String metricId,
      required String label,
      required IconData icon,
      AppWorkspaceStatusTone tone = AppWorkspaceStatusTone.neutral,
      String? queueId,
    }) {
      final SubscriptionQueueSummary? queue = queueId == null
          ? null
          : queueById(queueId);
      return AppWorkspaceSummaryNotification(
        label: label,
        count: state.summaryValue(metricId),
        icon: icon,
        tone: tone,
        onSelected: queue == null ? () {} : () => controller.applyQueue(queue),
      );
    }

    return <AppWorkspaceSummaryNotification>[
      card(
        metricId: _SummaryIds.activeSubscriptions,
        label: _SubscriptionsText.activeSubscriptions,
        icon: Icons.verified_outlined,
        tone: AppWorkspaceStatusTone.success,
      ),
      card(
        metricId: _SummaryIds.pendingChanges,
        label: _SubscriptionsText.pendingChanges,
        icon: Icons.pending_actions_outlined,
        queueId: _QueueIds.pendingChanges,
      ),
      card(
        metricId: _SummaryIds.pastDueInvoices,
        label: _SubscriptionsText.pastDueInvoices,
        icon: Icons.receipt_long_outlined,
        tone: AppWorkspaceStatusTone.warning,
        queueId: _QueueIds.pastDueBilling,
      ),
      card(
        metricId: _SummaryIds.deniedModules,
        label: _SubscriptionsText.deniedModules,
        icon: Icons.block_outlined,
        tone: AppWorkspaceStatusTone.error,
        queueId: _QueueIds.moduleBlocked,
      ),
      card(
        metricId: _SummaryIds.expiringLicenses,
        label: _SubscriptionsText.expiringLicenses,
        icon: Icons.event_busy_outlined,
        tone: AppWorkspaceStatusTone.warning,
        queueId: _QueueIds.renewalsDue,
      ),
      card(
        metricId: _SummaryIds.approachingLimits,
        label: _SubscriptionsText.approachingLimits,
        icon: Icons.trending_up_outlined,
        tone: AppWorkspaceStatusTone.info,
        queueId: _QueueIds.upgradeRecommended,
      ),
    ];
  }
}

class _SubscriptionOverviewPanel extends ConsumerWidget {
  const _SubscriptionOverviewPanel({
    required this.state,
    required this.canWrite,
  });

  final SubscriptionsWorkspaceState state;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionsOverview overview = state.overview;
    final ThemeData theme = Theme.of(context);
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    final SubscriptionQueueSummary? pastDueQueue = _queueById(
      state,
      _QueueIds.pastDueBilling,
    );
    final int pastDueCount = state.summaryValue(_SummaryIds.pastDueInvoices);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppResponsiveWrap(
          maxColumns: 4,
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
                  canWrite: canWrite,
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
                  canWrite: canWrite,
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
                  canWrite: canWrite,
                ),
              ),
            ),
            _SubscriptionMetricCard(
              label: _SubscriptionsText.pastDue,
              value: pastDueCount.toString(),
              icon: Icons.receipt_long_outlined,
              tone: AppWorkspaceStatusTone.error,
              onTap: pastDueQueue == null
                  ? () {}
                  : () => controller.applyQueue(pastDueQueue),
            ),
          ],
        ),
        if (overview.usageSummary != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _UsageLimitPanel(
            usage: overview.usageSummary!,
            subscription: overview.currentSubscription,
          ),
        ],
        if (overview.recommendations.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _RecommendationList(recommendations: overview.recommendations),
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
                        fontWeight: FontWeight.w800,
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
                          fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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

    return AppWorkspaceDetailPanel(
      title: _resourceLabel(state.query.resource),
      titleIcon: _resourceIcon(state.query.resource),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppListTable<SubscriptionItem>(
            page: state.items,
            isLoading: state.isRefreshing,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            columnVisibilityController: columnVisibilityController,
            columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
            search: AppListTableSearch<SubscriptionItem>(
              controller: searchController,
              semanticLabel: _SubscriptionsText.searchLabel,
              hintText: _SubscriptionsText.searchHint,
              clearLabel: _SubscriptionsText.clearSearch,
              matcher: (_, _) => true,
              onSubmitted: controller.applySearch,
              onClear: () => controller.applySearch(''),
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: _SubscriptionsText.filters,
              advancedFilterTitle: _SubscriptionsText.filters,
              advancedFilterApplyLabel: _SubscriptionsText.applyFilters,
              advancedFilterResetLabel: _SubscriptionsText.clearFilters,
              enableDateFilter: false,
              allFieldsLabel: _SubscriptionsText.all,
              filterGroups: _filterGroups(state),
              filterValue: _filterValue(state.query),
              hasActiveFilters: state.query.hasActiveFilters,
              onFilterChanged: (AppSearchBarFilterValue value) {
                final SubscriptionResource resource = _resourceFromFilter(
                  value.option(_FilterKeys.resource),
                  state.query.resource,
                );
                if (resource != state.query.resource) {
                  controller.applyResource(resource);
                  return;
                }
                controller.applyFilters(
                  status: _emptyOption(value.option(_FilterKeys.status)),
                  tierCode: _emptyOption(value.option(_FilterKeys.tier)),
                  billingCycle: _emptyOption(
                    value.option(_FilterKeys.billingCycle),
                  ),
                  planId: _emptyOption(value.option(_FilterKeys.plan)),
                  moduleId: _emptyOption(value.option(_FilterKeys.module)),
                  fitStatus: _emptyOption(value.option(_FilterKeys.fit)),
                  invoiceStatus: _emptyOption(
                    value.option(_FilterKeys.invoice),
                  ),
                  licenseType: _emptyOption(value.option(_FilterKeys.license)),
                  eligibilityState: _emptyOption(
                    value.option(_FilterKeys.eligibility),
                  ),
                  datePreset: _datePresetFromFilter(
                    value.option(_FilterKeys.datePreset),
                  ),
                );
              },
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
                ? _PlanColumnIds.monthlyPrice
                : null,
            rowColorBuilder: state.query.resource ==
                    SubscriptionResource.subscriptionPlans
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
            columns: _worklistColumns(state.query.resource),
            mobileItemBuilder: (BuildContext context, SubscriptionItem item) {
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: Theme.of(context).spacing.sm,
                ),
                child: _SubscriptionMobileTile(item: item),
              );
            },
          ),
        ],
      ),
    );
  }
}

List<AppListTableColumn<SubscriptionItem>> _worklistColumns(
  SubscriptionResource resource,
) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans =>
      <AppListTableColumn<SubscriptionItem>>[
        AppListTableColumn<SubscriptionItem>(
          id: _PlanColumnIds.planName,
          label: _SubscriptionsText.plan,
          sortComparator: (SubscriptionItem left, SubscriptionItem right) {
            return appListTableCompareText(left.name, right.name);
          },
          cellBuilder: (BuildContext context, SubscriptionItem item) {
            return Text(
              item.name ?? item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
        AppListTableColumn<SubscriptionItem>(
          id: _PlanColumnIds.planId,
          label: _SubscriptionsText.planId,
          sortComparator: (SubscriptionItem left, SubscriptionItem right) {
            return appListTableCompareText(
              left.effectiveDisplayId,
              right.effectiveDisplayId,
            );
          },
          cellBuilder: (BuildContext context, SubscriptionItem item) {
            return Text(
              item.effectiveDisplayId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
        AppListTableColumn<SubscriptionItem>(
          id: _PlanColumnIds.monthlyPrice,
          label: _SubscriptionsText.monthlyPriceUsd,
          numeric: true,
          sortComparator: (SubscriptionItem left, SubscriptionItem right) {
            return appListTableCompareNumber(
              left.resolvedMonthlyPrice,
              right.resolvedMonthlyPrice,
            );
          },
          cellBuilder: (BuildContext context, SubscriptionItem item) {
            return Text(
              _money(context, item.resolvedMonthlyPrice, item.currency),
            );
          },
        ),
        AppListTableColumn<SubscriptionItem>(
          id: _PlanColumnIds.annualPrice,
          label: _SubscriptionsText.annualPriceUsd,
          numeric: true,
          sortComparator: (SubscriptionItem left, SubscriptionItem right) {
            return appListTableCompareNumber(
              left.resolvedAnnualPrice,
              right.resolvedAnnualPrice,
            );
          },
          cellBuilder: (BuildContext context, SubscriptionItem item) {
            return Text(
              _money(context, item.resolvedAnnualPrice, item.currency),
            );
          },
        ),
      ],
    SubscriptionResource.subscriptions => <AppListTableColumn<SubscriptionItem>>[
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.tenant,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(left.tenantLabel, right.tenantLabel);
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return _CopyableRecordCell(
            title: item.tenantLabel ?? _SubscriptionsText.notRecorded,
            identifier: item.effectiveDisplayId,
            dense: true,
          );
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.plan,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(left.planLabel, right.planLabel);
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return Text(
            item.planLabel ?? _SubscriptionsText.notRecorded,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.status,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(
            left.primaryStatus,
            right.primaryStatus,
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return _StatusBadge(status: item.primaryStatus);
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.amount,
        numeric: true,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareNumber(
            left.totalAmount ?? left.price,
            right.totalAmount ?? right.price,
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return Text(_amountOrLimit(context, item));
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.expiryDate,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareDateTime(
            _timelineDate(left),
            _timelineDate(right),
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return Text(_date(context, _timelineDate(item)));
        },
      ),
    ],
    _ => <AppListTableColumn<SubscriptionItem>>[
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.record,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(
            _primaryRecordLabel(left),
            _primaryRecordLabel(right),
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return _CopyableRecordCell(
            title: _primaryRecordLabel(item),
            identifier: item.effectiveDisplayId,
            dense: true,
          );
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.status,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(
            left.primaryStatus,
            right.primaryStatus,
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return _StatusBadge(status: item.primaryStatus);
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.plan,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareText(
            _uniquePlanLabel(left),
            _uniquePlanLabel(right),
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return _PlanBadge(
            label: _uniquePlanLabel(item),
            code: item.tierCode ?? item.planCode,
          );
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.amountLimit,
        numeric: true,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareNumber(
            left.totalAmount ?? left.price,
            right.totalAmount ?? right.price,
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return Text(_amountOrLimit(context, item));
        },
      ),
      AppListTableColumn<SubscriptionItem>(
        label: _SubscriptionsText.renewalExpiry,
        sortComparator: (SubscriptionItem left, SubscriptionItem right) {
          return appListTableCompareDateTime(
            _timelineDate(left),
            _timelineDate(right),
          );
        },
        cellBuilder: (BuildContext context, SubscriptionItem item) {
          return Text(_date(context, _timelineDate(item)));
        },
      ),
    ],
  };
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
      return _PlanDetailContent(state: state, item: item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DetailHeader(item: item),
        SizedBox(height: Theme.of(context).spacing.md),
        if (canWrite) _DetailActions(item: item, state: state),
        if (canWrite) SizedBox(height: Theme.of(context).spacing.md),
        _DetailFields(item: item),
        if (state.timeline.isNotEmpty) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _TimelinePanel(timeline: state.timeline),
        ],
      ],
    );
  }
}

class _PlanDetailContent extends ConsumerWidget {
  const _PlanDetailContent({required this.state, required this.item});

  final SubscriptionsWorkspaceState state;
  final SubscriptionItem item;

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
                            fontWeight: FontWeight.w800,
                            color: planTheme.foreground,
                          ),
                        ),
                        if (planId.trim().isNotEmpty)
                          Text(
                            planId,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
                  border: Border.all(color: planTheme.border),
                ),
                child: Text(
                  isFree
                      ? _SubscriptionsText.freePlan
                      : (item.tierCode ?? item.name ?? item.title),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: planTheme.foreground,
                    fontWeight: FontWeight.w700,
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
                value: _money(
                  context,
                  item.resolvedAnnualPrice,
                  item.currency,
                ),
              ),
            ],
            _PlanMetricChip(
              icon: Icons.group_outlined,
              label: _SubscriptionsText.maxUsers,
              value: item.maxUsers?.toString() ?? _SubscriptionsText.notRecorded,
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
        AppSectionPanel(
          title: _SubscriptionsText.includedModules,
          description: _SubscriptionsText.includedModulesAccessHint,
          leadingIcon: Icons.extension_outlined,
          density: AppContentPanelDensity.compact,
          trailing: AppButton.secondary(
            label: _SubscriptionsText.addModules,
            leadingIcon: Icons.add,
            onPressed: () async {
              await _showPlanModulesDialog(context, ref, item);
            },
          ),
          children: <Widget>[
            if (includedLabels.isEmpty)
              Text(
                _SubscriptionsText.noModulesIncluded,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final String label in includedLabels)
                    Chip(label: Text(label)),
                ],
              ),
          ],
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
          _PlanAccountsSection(
            title: _SubscriptionsText.linkedTenants,
            emptyLabel: _SubscriptionsText.noLinkedTenants,
            accounts:
                detail?.activeAccounts ?? const <SubscriptionTenantAccount>[],
          ),
          SizedBox(height: theme.spacing.md),
          _PlanAccountsSection(
            title: _SubscriptionsText.pendingApprovals,
            emptyLabel: _SubscriptionsText.noPendingApprovals,
            accounts:
                detail?.pendingAccounts ?? const <SubscriptionTenantAccount>[],
          ),
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
                fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
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
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.business_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (accounts.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
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
                              fontWeight: FontWeight.w700,
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
    for (final SubscriptionLookupItem module in modules) module.id: module.label,
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
  'PRO': 2,
  'ADVANCED': 3,
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
  const _DetailActions({required this.item, required this.state});

  final SubscriptionItem item;
  final SubscriptionsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: Theme.of(context).spacing.sm,
      runSpacing: Theme.of(context).spacing.sm,
      children: <Widget>[
        if (item.resource == SubscriptionResource.subscriptions) ...<Widget>[
          AppButton.secondary(
            label: _SubscriptionsText.editSubscription,
            leadingIcon: Icons.edit_outlined,
            enabled: !state.isSaving && state.lookups.plans.isNotEmpty,
            onPressed: () => _showEditSubscriptionDialog(
              context,
              ref,
              state,
              item,
            ),
          ),
          AppButton.secondary(
            label: _SubscriptionsText.renew,
            leadingIcon: Icons.event_repeat_outlined,
            enabled: item.canRenewSubscription && !state.isSaving,
            onPressed: () => _showRenewalDialog(context, ref),
          ),
          AppButton.secondary(
            label: _SubscriptionsText.changePlan,
            leadingIcon: Icons.swap_horiz_outlined,
            enabled: !state.isSaving && state.lookups.plans.isNotEmpty,
            onPressed: () => _showPlanChangeDialog(context, ref, state),
          ),
          AppButton.secondary(
            label: _SubscriptionsText.activate,
            leadingIcon: Icons.play_circle_outline,
            enabled: item.canActivateSubscription && !state.isSaving,
            onPressed: () => _submitAndNotify(
              context,
              ref
                  .read(subscriptionsWorkspaceControllerProvider.notifier)
                  .activateSelectedSubscription(),
            ),
          ),
          AppButton.secondary(
            label: _SubscriptionsText.cancelSubscription,
            leadingIcon: Icons.block_outlined,
            enabled: item.canCancelSubscription && !state.isSaving,
            onPressed: () => _showCancelSubscriptionDialog(context, ref),
          ),
        ],
        if (item.resource == SubscriptionResource.moduleSubscriptions)
          AppButton.secondary(
            label: item.isActive == true
                ? _SubscriptionsText.disableModule
                : _SubscriptionsText.enableModule,
            leadingIcon: item.isActive == true
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            enabled: item.canToggleModule && !state.isSaving,
            onPressed: () => _showToggleModuleDialog(context, ref, item),
          ),
        if (item.resource == SubscriptionResource.licenses)
          AppButton.secondary(
            label: _SubscriptionsText.updateLicense,
            leadingIcon: Icons.key_outlined,
            enabled: !state.isSaving,
            onPressed: () =>
                _showLicenseDialog(context, ref, state, initial: item),
          ),
        if (item.resource ==
            SubscriptionResource.subscriptionInvoices) ...<Widget>[
          AppButton.secondary(
            label: _SubscriptionsText.collectInvoice,
            leadingIcon: Icons.payments_outlined,
            enabled: item.canCollectInvoice && !state.isSaving,
            onPressed: () => _showCollectInvoiceDialog(context, ref),
          ),
          AppButton.secondary(
            label: _SubscriptionsText.retryInvoice,
            leadingIcon: Icons.replay_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showRetryInvoiceDialog(context, ref),
          ),
          AppReportActionButton.download(
            label: _SubscriptionsText.printInvoice,
            tooltip: _SubscriptionsText.reportEndpointPending,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(_SubscriptionsText.reportEndpointPending),
                ),
              );
            },
          ),
        ],
      ],
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
      items: <AppInfoTileData>[
        AppInfoTileData(
          label: _SubscriptionsText.tenant,
          value: item.tenantLabel ?? item.tenantId,
          icon: Icons.business_outlined,
        ),
        AppInfoTileData(
          label: _SubscriptionsText.plan,
          value: item.planLabel ?? item.name,
          icon: Icons.workspace_premium_outlined,
        ),
        AppInfoTileData(
          label: _SubscriptionsText.module,
          value: item.moduleLabel ?? item.moduleSlug,
          icon: Icons.extension_outlined,
        ),
        if (item.resource == SubscriptionResource.subscriptionPlans) ...<
          AppInfoTileData
        >[
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
        ] else ...<AppInfoTileData>[
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
        ],
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
        AppInfoTileData(
          label: _SubscriptionsText.updated,
          value: _date(context, item.updatedAt),
          icon: Icons.update_outlined,
        ),
      ],
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.timeline});

  final List<SubscriptionTimelineItem> timeline;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: _SubscriptionsText.timeline,
      leadingIcon: Icons.history_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        for (final SubscriptionTimelineItem item in timeline.take(5))
          _TwoLineCell(
            title: item.title,
            subtitle: _joinDisplay(<String?>[
              _resourceLabel(item.resource),
              _statusLabel(item.status),
              _date(context, item.occurredAt),
            ]),
          ),
      ],
    );
  }
}

class _SubscriptionMobileTile extends StatelessWidget {
  const _SubscriptionMobileTile({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(_resourceIcon(item.resource), size: 22),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _primaryRecordLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  _StatusBadge(status: item.primaryStatus),
                  _PlanBadge(
                    label: _uniquePlanLabel(item),
                    code: item.tierCode ?? item.planCode,
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                _date(context, _timelineDate(item)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
            fontWeight: FontWeight.w700,
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
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatusTone tone = _statusTone(status);
    final Color accent = workspaceStatusToneAccentColor(theme, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: _statusLabel(status),
          tone: tone,
          icon: _statusIcon(status),
        ),
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
        fontWeight: FontWeight.w700,
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          Text(
            _SubscriptionsText.includedModules,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
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
            side: BorderSide(
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
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
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
                          fontWeight: FontWeight.w700,
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
        : colors.outlineVariant.withValues(alpha: 0.55);

    return Material(
      color: baseFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor),
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
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.14),
                  ),
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
                        fontWeight: FontWeight.w700,
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
      title: const Text(_SubscriptionsText.addModules),
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
    this.submitLabel = _SubscriptionsText.activateSubscription,
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

  @override
  void initState() {
    super.initState();
    final SubscriptionItem? initial = widget.initial;
    _tenantId = initial?.tenantId ?? widget.initialTenantId;
    _planId = initial?.planId;
    _status = initial?.status ?? _SubscriptionStatuses.active;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.initial != null;
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
          Navigator.of(context).pop(
            SubscriptionDraft(
              tenantId: _tenantId!,
              planId: _planId!,
              status: _status,
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
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final SubscriptionsWorkspaceState state;

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
    _subscriptionId = widget.state.overview.currentSubscription?.id;
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
    ];

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
            options: _lookupOptions(subscriptions),
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
  final controller = ref.read(subscriptionsWorkspaceControllerProvider.notifier);
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
        if (isPlan && canWrite)
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
    includedModuleIds:
        includedModuleIds ?? item.includedModuleIds,
  );
}

Future<void> _showSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state, {
  String? initialTenantId,
}) async {
  final SubscriptionDraft? draft = await showAppDialog<SubscriptionDraft>(
    context: context,
    builder: (_) => _SubscriptionForm(
      dialogTitle: Text(
        initialTenantId == null
            ? _SubscriptionsText.activateSubscription
            : _SubscriptionsText.assignSubscription,
      ),
      dialogIcon: const Icon(Icons.play_circle_outline),
      state: state,
      initialTenantId: initialTenantId,
      submitLabel: initialTenantId == null
          ? _SubscriptionsText.activateSubscription
          : _SubscriptionsText.assignSubscription,
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
  required bool canWrite,
}) async {
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
                  fontWeight: FontWeight.w700,
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
            else
              ...<Widget>[
                for (final SubscriptionTenantAccount account
                    in summary.accounts) ...<Widget>[
                  _CohortAccountCard(
                    account: account,
                    canWrite: canWrite,
                    isSaving: state.isSaving,
                    onAction: canWrite
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
                              canWrite: canWrite,
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
    required this.canWrite,
    required this.isSaving,
    required this.onAction,
  });

  final SubscriptionTenantAccount account;
  final bool canWrite;
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
                    fontWeight: FontWeight.w800,
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
              _PlanBadge(
                label: account.planLabel,
                code: account.planCode,
              ),
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
                    ? _SubscriptionsText.assignSubscription
                    : _SubscriptionsText.modify,
                leadingIcon: account.subscriptionId == null
                    ? Icons.add_circle_outline
                    : Icons.edit_outlined,
                enabled: canWrite && !isSaving,
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

Future<void> _handleCohortAccountAction(
  BuildContext context,
  WidgetRef ref, {
  required SubscriptionsWorkspaceState state,
  required SubscriptionTenantAccount account,
  required bool canWrite,
}) async {
  if (!canWrite) {
    return;
  }
  final String? subscriptionId = account.subscriptionId;
  if (subscriptionId == null || subscriptionId.isEmpty) {
    await _showSubscriptionDialog(
      context,
      ref,
      state,
      initialTenantId: account.tenantId,
    );
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
  SubscriptionsWorkspaceState state,
) async {
  final ModuleSubscriptionDraft? draft =
      await showAppDialog<ModuleSubscriptionDraft>(
        context: context,
        builder: (_) => _ModuleSubscriptionForm(
          dialogTitle: const Text(_SubscriptionsText.assignModule),
          dialogIcon: const Icon(Icons.extension_outlined),
          state: state,
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

Future<void> _showToggleModuleDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionItem item,
) async {
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
      .toggleSelectedModule(reason: draft.reason);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showCancelSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final SubscriptionActionDraft? draft =
      await showAppDialog<SubscriptionActionDraft>(
        context: context,
        builder: (_) => const _ReasonForm(
          dialogTitle: Text(_SubscriptionsText.cancelSubscription),
          dialogIcon: Icon(Icons.block_outlined),
          submitLabel: _SubscriptionsText.cancelSubscription,
          reasonLabel: _SubscriptionsText.reason,
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(subscriptionsWorkspaceControllerProvider.notifier)
      .cancelSelectedSubscription();
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showCollectInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
    AppSearchBarFilterGroup(
      key: _FilterKeys.resource,
      label: _SubscriptionsText.resource,
      allLabel: _resourceLabel(state.query.resource),
      choices: <AppSearchBarFilterChoice>[
        for (final SubscriptionResource resource in SubscriptionResource.values)
          AppSearchBarFilterChoice(
            value: resource.serverValue,
            label: _resourceLabel(resource),
            icon: _resourceIcon(resource),
          ),
      ],
    ),
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
    _FilterKeys.resource: query.resource.serverValue,
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

SubscriptionResource _resourceFromFilter(
  String? value,
  SubscriptionResource fallback,
) {
  if (!_hasText(value)) {
    return fallback;
  }
  return SubscriptionResource.fromServer(value);
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

List<AppSelectOption<String>> _subscriptionStatusOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _SubscriptionStatuses.active,
      label: _SubscriptionsText.active,
    ),
    AppSelectOption<String>(
      value: _SubscriptionStatuses.trial,
      label: _SubscriptionsText.trial,
    ),
    AppSelectOption<String>(
      value: _SubscriptionStatuses.pastDue,
      label: _SubscriptionsText.pastDue,
    ),
    AppSelectOption<String>(
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
  final String key =
      '${module.subtitle ?? ''} ${module.id} ${module.label}'.toLowerCase();

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
  if (_moduleKeyMatches(key, const <String>['encounter', 'vital', 'clinical'])) {
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
  if (_moduleKeyMatches(key, const <String>[
    'integrat',
    'webhook',
    'api',
  ])) {
    return AppRouteIcons.integrations;
  }
  if (_moduleKeyMatches(key, const <String>[
    'report',
    'analytic',
    'insight',
  ])) {
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
  if (_moduleKeyMatches(key, const <String>['auth', 'rbac', 'access', 'role'])) {
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
    SubscriptionPanel.operations => _SubscriptionsText.subscriptions,
    SubscriptionPanel.billing => _SubscriptionsText.invoices,
    SubscriptionPanel.governance => _SubscriptionsText.licenses,
  };
}

IconData _panelIcon(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => Icons.dashboard_customize_outlined,
    SubscriptionPanel.catalog => Icons.workspace_premium_outlined,
    SubscriptionPanel.operations => Icons.verified_user_outlined,
    SubscriptionPanel.billing => Icons.receipt_long_outlined,
    SubscriptionPanel.governance => Icons.key_outlined,
  };
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

String _primaryRecordLabel(SubscriptionItem item) {
  return switch (item.resource) {
    SubscriptionResource.subscriptions =>
      item.tenantLabel ?? item.title,
    SubscriptionResource.subscriptionPlans => item.name ?? item.title,
    SubscriptionResource.modules => item.name ?? item.title,
    SubscriptionResource.moduleSubscriptions =>
      item.moduleLabel ?? item.title,
    SubscriptionResource.subscriptionInvoices =>
      item.invoiceDisplayId ?? item.title,
    SubscriptionResource.licenses => item.licenseType ?? item.title,
  };
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

abstract final class _PlanColumnIds {
  static const String planName = 'plan_name';
  static const String planId = 'plan_id';
  static const String monthlyPrice = 'monthly_price';
  static const String annualPrice = 'annual_price';
}

abstract final class _FilterKeys {
  static const String resource = 'resource';
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
  static const String activeSubscriptions = 'active_subscriptions';
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
  static const String moduleBlocked = 'module_blocked';
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
  static const String viewsMenu = 'Views';
  static const String activePlans = 'Active plans';
  static const String notSubscribed = 'Not subscribed';
  static const String closedSubscriptions = 'Closed subscriptions';
  static const String activeSubscriptions = 'Active subscriptions';
  static const String pendingChanges = 'Pending changes';
  static const String pastDueInvoices = 'Past due invoices';
  static const String pastDue = 'Past due';
  static const String deniedModules = 'Denied modules';
  static const String expiringLicenses = 'Expiring licenses';
  static const String approachingLimits = 'Approaching limits';
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
  static const String addModules = 'Add modules';
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
  static const String filters = 'Subscription filters';
  static const String applyFilters = 'Apply filters';
  static const String clearFilters = 'Clear filters';
  static const String all = 'All';
  static const String emptyTitle = 'No subscription records';
  static const String emptyBody =
      'Adjust the filters or activate a subscription to populate this view.';
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
  static const String plans = 'Plans';
  static const String subscriptions = 'Subscriptions';
  static const String moduleSubscriptions = 'Module subscriptions';
  static const String invoices = 'Invoices';
  static const String createPlan = 'Create plan';
  static const String editPlan = 'Edit plan';
  static const String savePlan = 'Save plan';
  static const String activateSubscription = 'Activate subscription';
  static const String assignSubscription = 'Assign subscription';
  static const String editSubscription = 'Edit subscription';
  static const String saveSubscription = 'Save subscription';
  static const String modify = 'Modify';
  static const String assignModule = 'Assign module';
  static const String addLicense = 'Add license';
  static const String updateLicense = 'Update license';
  static const String renew = 'Renew';
  static const String changePlan = 'Change plan';
  static const String activate = 'Activate';
  static const String cancelSubscription = 'Cancel subscription';
  static const String enableModule = 'Enable module';
  static const String disableModule = 'Disable module';
  static const String collectInvoice = 'Collect invoice';
  static const String retryInvoice = 'Retry invoice';
  static const String printInvoice = 'Print invoice';
  static const String reportEndpointPending =
      'Generated subscription invoice reports are not available yet.';
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
  static const String resource = 'Resource';
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
