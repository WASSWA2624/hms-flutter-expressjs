import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class SubscriptionsWorkspacePage extends ConsumerWidget {
  const SubscriptionsWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<SubscriptionsWorkspaceState>> workspace = ref.watch(
      subscriptionsWorkspaceControllerProvider,
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
    _searchController = TextEditingController(
      text: widget.state.query.search,
    );
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
    final bool canWrite = accessPolicy.grants(AppPermissions.subscriptionsWrite);
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );
    final Object? failure = state.lastFailure;
    final AppFailure? lastFailure = failure is AppFailure ? failure : null;

    return AppWorkspace(
      title: _SubscriptionsText.title,
      leadingIcon: AppRouteIcons.subscriptions,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? _SubscriptionsText.savingStatus
            : _SubscriptionsText.liveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving
            ? Icons.sync_outlined
            : Icons.workspace_premium_outlined,
      ),
      primaryAction: _primaryAction(context, canWrite, state),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      summaryCards: _summaryCards(context, state),
      compactSummaryCards: true,
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
          _SubscriptionOverviewPanel(state: state),
          SizedBox(height: Theme.of(context).spacing.md),
          _SubscriptionsWorklistPanel(
            state: state,
            canWrite: canWrite,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
          ),
        ],
      ),
      detail: _SubscriptionDetailPanel(state: state, canWrite: canWrite),
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

  List<Widget> _summaryCards(
    BuildContext context,
    SubscriptionsWorkspaceState state,
  ) {
    final Locale locale = Localizations.localeOf(context);
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

    Widget card({
      required String metricId,
      required String label,
      required IconData icon,
      AppWorkspaceStatusTone tone = AppWorkspaceStatusTone.neutral,
      String? queueId,
    }) {
      final SubscriptionQueueSummary? queue = queueId == null
          ? null
          : queueById(queueId);
      return AppWorkspaceSummaryCard(
        label: label,
        value: AppFormatters.compactNumber(
          state.summaryValue(metricId),
          locale,
        ),
        icon: icon,
        tone: tone,
        compact: true,
        onPressed: queue == null ? null : () => controller.applyQueue(queue),
      );
    }

    return <Widget>[
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
  const _SubscriptionOverviewPanel({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionsOverview overview = state.overview;
    final SubscriptionItem? subscription = overview.currentSubscription;
    final SubscriptionPlanReference? plan = overview.currentPlan;
    final SubscriptionItem? invoice = overview.nextInvoice;
    final SubscriptionUsageSummary? usage = overview.usageSummary;
    final ThemeData theme = Theme.of(context);

    return AppSectionPanel(
      title: _SubscriptionsText.overview,
      description: _SubscriptionsText.overviewDescription,
      leadingIcon: Icons.dashboard_customize_outlined,
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: _SubscriptionsText.notRecorded,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: _SubscriptionsText.activePlan,
              value: plan?.label ?? subscription?.planLabel,
              icon: Icons.workspace_premium_outlined,
            ),
            AppInfoTileData(
              label: _SubscriptionsText.subscriptionStatus,
              value: _statusLabel(subscription?.status),
              icon: Icons.verified_user_outlined,
            ),
            AppInfoTileData(
              label: _SubscriptionsText.renewalExpiry,
              value: _date(context, subscription?.endDate),
              icon: Icons.event_outlined,
            ),
            AppInfoTileData(
              label: _SubscriptionsText.nextInvoice,
              value: invoice == null
                  ? null
                  : _money(context, invoice.totalAmount, invoice.currency),
              icon: Icons.receipt_long_outlined,
            ),
            AppInfoTileData(
              label: _SubscriptionsText.licenses,
              value: overview.licenseSummary.activeCount.toString(),
              icon: Icons.key_outlined,
            ),
            AppInfoTileData(
              label: _SubscriptionsText.modulesUsed,
              value: usage?.modulesUsed?.toString(),
              icon: Icons.extension_outlined,
            ),
          ],
        ),
        if (usage != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _UsageLimitPanel(usage: usage, subscription: subscription),
        ],
        if (overview.recommendations.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _RecommendationList(recommendations: overview.recommendations),
        ],
      ],
    );
  }
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
    required this.canWrite,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final SubscriptionsWorkspaceState state;
  final bool canWrite;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<SubscriptionItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      subscriptionsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: _resourceLabel(state.query.resource),
      description: _SubscriptionsText.worklistDescription,
      child: AppListTable<SubscriptionItem>(
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
          advancedFilterCancelLabel: context.l10n.commonCancelActionLabel,
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
            AppSearchBarAction(
              icon: Icons.filter_alt_off_outlined,
              label: _SubscriptionsText.clearFilters,
              enabled: state.query.hasActiveFilters,
              active: state.query.hasActiveFilters,
              onPressed: state.query.hasActiveFilters
                  ? controller.resetFilters
                  : null,
            ),
          ],
        ),
        itemKeyBuilder: (SubscriptionItem item) => ValueKey<String>(
          '${item.resource.serverValue}:${item.id}',
        ),
        onRowSelected: controller.selectItem,
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
        emptyBuilder: (BuildContext context) {
          return const AppStateView(
            title: _SubscriptionsText.emptyTitle,
            body: _SubscriptionsText.emptyBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<SubscriptionItem>>[
          AppListTableColumn<SubscriptionItem>(
            label: _SubscriptionsText.record,
            sortComparator: (SubscriptionItem left, SubscriptionItem right) {
              return appListTableCompareText(left.title, right.title);
            },
            cellBuilder: (BuildContext context, SubscriptionItem item) {
              return _TwoLineCell(
                title: item.title,
                subtitle: _joinDisplay(<String?>[
                  item.subtitle,
                  item.effectiveDisplayId,
                ]),
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
            label: _SubscriptionsText.planModule,
            sortComparator: (SubscriptionItem left, SubscriptionItem right) {
              return appListTableCompareText(
                _planModuleText(left),
                _planModuleText(right),
              );
            },
            cellBuilder: (BuildContext context, SubscriptionItem item) {
              return Text(_planModuleText(item));
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
          AppListTableColumn<SubscriptionItem>(
            label: _SubscriptionsText.nextAction,
            cellBuilder: (BuildContext context, SubscriptionItem item) {
              return Text(_nextAction(item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, SubscriptionItem item) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: Theme.of(context).spacing.sm),
            child: _SubscriptionMobileTile(item: item),
          );
        },
      ),
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
      return const AppWorkspaceDetailPanel(
        title: _SubscriptionsText.detailTitle,
        child: AppStateView(
          title: _SubscriptionsText.noSelectionTitle,
          body: _SubscriptionsText.noSelectionBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: _SubscriptionsText.detailTitle,
      description: item.title,
      child: Column(
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
      ),
    );
  }
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
            child: _TwoLineCell(
              title: item.title,
              subtitle: _joinDisplay(<String?>[
                _resourceLabel(item.resource),
                item.effectiveDisplayId,
                item.subtitle,
              ]),
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
        if (item.resource == SubscriptionResource.subscriptionPlans)
          AppButton.secondary(
            label: _SubscriptionsText.editPlan,
            leadingIcon: Icons.edit_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showPlanDialog(context, ref, initial: item),
          ),
        if (item.resource == SubscriptionResource.subscriptions) ...<Widget>[
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
            onPressed: () => _showLicenseDialog(context, ref, state, initial: item),
          ),
        if (item.resource == SubscriptionResource.subscriptionInvoices) ...<Widget>[
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(_resourceIcon(item.resource), size: 22),
        SizedBox(width: Theme.of(context).spacing.sm),
        Expanded(
          child: _TwoLineCell(
            title: item.title,
            subtitle: _joinDisplay(<String?>[
              item.subtitle,
              _planModuleText(item),
              _date(context, _timelineDate(item)),
            ]),
          ),
        ),
        SizedBox(width: Theme.of(context).spacing.sm),
        _StatusBadge(status: item.primaryStatus),
      ],
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
            maxLines: 2,
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

class _PlanForm extends StatefulWidget {
  const _PlanForm({required this.submitLabel, this.initial});

  final String submitLabel;
  final SubscriptionItem? initial;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _priceController;
  late final TextEditingController _usersController;
  late final TextEditingController _facilitiesController;
  late final TextEditingController _storageController;
  late final TextEditingController _modulesController;
  String? _tierCode;
  String _billingCycle = _BillingCycles.monthly;

  @override
  void initState() {
    super.initState();
    final SubscriptionItem? initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _codeController = TextEditingController(text: initial?.code ?? '');
    _priceController = TextEditingController(
      text: initial?.price == null ? '' : initial!.price.toString(),
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _usersController.dispose();
    _facilitiesController.dispose();
    _storageController.dispose();
    _modulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _nameController,
          labelText: _SubscriptionsText.planName,
          isRequired: true,
          validator: AppValidators.requiredText(
            _SubscriptionsText.planNameRequired,
          ),
        ),
        AppTextField(
          controller: _codeController,
          labelText: _SubscriptionsText.planCode,
        ),
        AppSelectField<String>(
          value: _tierCode,
          labelText: _SubscriptionsText.tier,
          options: _tierOptions(),
          onChanged: (String? value) => setState(() => _tierCode = value),
        ),
        AppSelectField<String>(
          value: _billingCycle,
          labelText: _SubscriptionsText.billingCycle,
          isRequired: true,
          allowClear: false,
          options: _billingCycleOptions(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _billingCycle = value);
            }
          },
        ),
        AppTextField(
          controller: _priceController,
          labelText: _SubscriptionsText.price,
          isRequired: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: AppValidators.pattern(
            RegExp(r'^\d+(\.\d{1,2})?$'),
            _SubscriptionsText.amountInvalid,
            allowEmpty: false,
          ),
        ),
        AppTextField(
          controller: _usersController,
          labelText: _SubscriptionsText.maxUsers,
          keyboardType: TextInputType.number,
          validator: _optionalIntegerValidator,
        ),
        AppTextField(
          controller: _facilitiesController,
          labelText: _SubscriptionsText.maxFacilities,
          keyboardType: TextInputType.number,
          validator: _optionalIntegerValidator,
        ),
        AppTextField(
          controller: _storageController,
          labelText: _SubscriptionsText.maxStorage,
          keyboardType: TextInputType.number,
          validator: _optionalIntegerValidator,
        ),
        AppTextField(
          controller: _modulesController,
          labelText: _SubscriptionsText.maxModules,
          keyboardType: TextInputType.number,
          validator: _optionalIntegerValidator,
        ),
        AppFormActions(
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
                price: _priceController.text.trim(),
                billingCycle: _billingCycle,
                maxUsers: _emptyToNull(_usersController.text),
                maxFacilities: _emptyToNull(_facilitiesController.text),
                maxStorageMb: _emptyToNull(_storageController.text),
                maxModules: _emptyToNull(_modulesController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubscriptionForm extends StatefulWidget {
  const _SubscriptionForm({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  State<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<_SubscriptionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  String? _tenantId;
  String? _planId;
  String _status = _SubscriptionStatuses.active;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
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
        AppTextField(
          controller: _startController,
          labelText: _SubscriptionsText.startDate,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppTextField(
          controller: _endController,
          labelText: _SubscriptionsText.endDate,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: _SubscriptionsText.activateSubscription,
          submitIcon: Icons.play_circle_outline,
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
                startDate: _emptyToNull(_startController.text),
                endDate: _emptyToNull(_endController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PlanChangeForm extends StatefulWidget {
  const _PlanChangeForm({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  State<_PlanChangeForm> createState() => _PlanChangeFormState();
}

class _PlanChangeFormState extends State<_PlanChangeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _effectiveAtController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String? _targetPlanId;
  String _changeType = _SubscriptionChangeTypes.upgrade;

  @override
  void dispose() {
    _effectiveAtController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
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
        AppTextField(
          controller: _effectiveAtController,
          labelText: _SubscriptionsText.effectiveAt,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppTextField(
          controller: _reasonController,
          labelText: _SubscriptionsText.reason,
          maxLines: 3,
        ),
        AppFormActions(
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
                effectiveAt: _emptyToNull(_effectiveAtController.text),
                reason: _emptyToNull(_reasonController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RenewalForm extends StatefulWidget {
  const _RenewalForm();

  @override
  State<_RenewalForm> createState() => _RenewalFormState();
}

class _RenewalFormState extends State<_RenewalForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _endController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _endController,
          labelText: _SubscriptionsText.newEndDate,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppTextField(
          controller: _reasonController,
          labelText: _SubscriptionsText.reason,
          maxLines: 3,
        ),
        AppFormActions(
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
                endDate: _emptyToNull(_endController.text),
                reason: _emptyToNull(_reasonController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ModuleSubscriptionForm extends StatefulWidget {
  const _ModuleSubscriptionForm({required this.state});

  final SubscriptionsWorkspaceState state;

  @override
  State<_ModuleSubscriptionForm> createState() => _ModuleSubscriptionFormState();
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
    final List<SubscriptionLookupItem> subscriptions =
        <SubscriptionLookupItem>[
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

    return AppFormShell(
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
        AppFormActions(
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
      ],
    );
  }
}

class _LicenseForm extends StatefulWidget {
  const _LicenseForm({required this.state, this.initial});

  final SubscriptionsWorkspaceState state;
  final SubscriptionItem? initial;

  @override
  State<_LicenseForm> createState() => _LicenseFormState();
}

class _LicenseFormState extends State<_LicenseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _issuedController = TextEditingController();
  final TextEditingController _expiresController = TextEditingController();
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
    _issuedController.text = _isoText(initial?.issuedAt);
    _expiresController.text = _isoText(initial?.expiresAt);
  }

  @override
  void dispose() {
    _issuedController.dispose();
    _expiresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
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
        AppTextField(
          controller: _issuedController,
          labelText: _SubscriptionsText.issuedAt,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppTextField(
          controller: _expiresController,
          labelText: _SubscriptionsText.expiresAt,
          hintText: _SubscriptionsText.dateTimeHint,
        ),
        AppFormActions(
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
                issuedAt: _emptyToNull(_issuedController.text),
                expiresAt: _emptyToNull(_expiresController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({required this.submitLabel, required this.reasonLabel});

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
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _reasonController,
          labelText: widget.reasonLabel,
          maxLines: 3,
        ),
        AppFormActions(
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
      ],
    );
  }
}

class _InvoiceCollectForm extends StatefulWidget {
  const _InvoiceCollectForm();

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
    return AppFormShell(
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
        AppFormActions(
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
      ],
    );
  }
}

Future<void> _showPlanDialog(
  BuildContext context,
  WidgetRef ref, {
  SubscriptionItem? initial,
}) async {
  final SubscriptionPlanDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(
      initial == null ? _SubscriptionsText.createPlan : _SubscriptionsText.editPlan,
    ),
    icon: const Icon(Icons.workspace_premium_outlined),
    content: _PlanForm(
      submitLabel:
          initial == null ? _SubscriptionsText.createPlan : _SubscriptionsText.savePlan,
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

Future<void> _showSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state,
) async {
  final SubscriptionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.activateSubscription),
    icon: const Icon(Icons.play_circle_outline),
    content: _SubscriptionForm(state: state),
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

Future<void> _showPlanChangeDialog(
  BuildContext context,
  WidgetRef ref,
  SubscriptionsWorkspaceState state,
) async {
  final SubscriptionPlanChangeDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.changePlan),
    icon: const Icon(Icons.swap_horiz_outlined),
    content: _PlanChangeForm(state: state),
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
  final SubscriptionRenewalDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.renew),
    icon: const Icon(Icons.event_repeat_outlined),
    content: const _RenewalForm(),
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
  final ModuleSubscriptionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.assignModule),
    icon: const Icon(Icons.extension_outlined),
    content: _ModuleSubscriptionForm(state: state),
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
  final LicenseDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(
      initial == null ? _SubscriptionsText.addLicense : _SubscriptionsText.updateLicense,
    ),
    icon: const Icon(Icons.key_outlined),
    content: _LicenseForm(state: state, initial: initial),
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
  final SubscriptionActionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(
      item.isActive == true
          ? _SubscriptionsText.disableModule
          : _SubscriptionsText.enableModule,
    ),
    icon: const Icon(Icons.extension_outlined),
    content: _ReasonForm(
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
  final SubscriptionActionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.cancelSubscription),
    icon: const Icon(Icons.block_outlined),
    content: const _ReasonForm(
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
  final SubscriptionActionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.collectInvoice),
    icon: const Icon(Icons.payments_outlined),
    content: const _InvoiceCollectForm(),
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

Future<void> _showRetryInvoiceDialog(BuildContext context, WidgetRef ref) async {
  final SubscriptionActionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_SubscriptionsText.retryInvoice),
    icon: const Icon(Icons.replay_outlined),
    content: const _ReasonForm(
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

List<AppSearchBarFilterChoice> _statusChoices(SubscriptionsWorkspaceState state) {
  return switch (state.query.resource) {
    SubscriptionResource.moduleSubscriptions => const <AppSearchBarFilterChoice>[
      AppSearchBarFilterChoice(value: _SubscriptionStatuses.active, label: _SubscriptionsText.active),
      AppSearchBarFilterChoice(value: _SubscriptionStatuses.inactive, label: _SubscriptionsText.inactive),
    ],
    SubscriptionResource.subscriptionInvoices => _choices(
      state.lookups.invoiceStatuses,
    ),
    SubscriptionResource.licenses || SubscriptionResource.subscriptions =>
      _choices(state.lookups.statuses),
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
    AppSelectOption<String>(value: _TierValues.basic, label: _SubscriptionsText.basic),
    AppSelectOption<String>(value: _TierValues.standard, label: _SubscriptionsText.standard),
    AppSelectOption<String>(value: _TierValues.premium, label: _SubscriptionsText.premium),
    AppSelectOption<String>(value: _TierValues.enterprise, label: _SubscriptionsText.enterprise),
  ];
}

List<AppSelectOption<String>> _billingCycleOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: _BillingCycles.monthly, label: _SubscriptionsText.monthly),
    AppSelectOption<String>(value: _BillingCycles.quarterly, label: _SubscriptionsText.quarterly),
    AppSelectOption<String>(value: _BillingCycles.yearly, label: _SubscriptionsText.yearly),
  ];
}

List<AppSelectOption<String>> _subscriptionStatusOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: _SubscriptionStatuses.active, label: _SubscriptionsText.active),
    AppSelectOption<String>(value: _SubscriptionStatuses.trial, label: _SubscriptionsText.trial),
    AppSelectOption<String>(value: _SubscriptionStatuses.pastDue, label: _SubscriptionsText.pastDue),
    AppSelectOption<String>(value: _SubscriptionStatuses.cancelled, label: _SubscriptionsText.cancelled),
  ];
}

List<AppSelectOption<String>> _licenseTypeOptions(
  SubscriptionsWorkspaceState state,
) {
  if (state.lookups.licenseTypes.isNotEmpty) {
    return _lookupOptions(state.lookups.licenseTypes);
  }
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: _LicenseTypes.perUser, label: _SubscriptionsText.perUser),
    AppSelectOption<String>(value: _LicenseTypes.perFacility, label: _SubscriptionsText.perFacility),
    AppSelectOption<String>(value: _LicenseTypes.enterprise, label: _SubscriptionsText.enterprise),
  ];
}

List<AppSelectOption<String>> _paymentMethodOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: _PaymentMethods.cash, label: _SubscriptionsText.cash),
    AppSelectOption<String>(value: _PaymentMethods.mobileMoney, label: _SubscriptionsText.mobileMoney),
    AppSelectOption<String>(value: _PaymentMethods.bankTransfer, label: _SubscriptionsText.bankTransfer),
    AppSelectOption<String>(value: _PaymentMethods.card, label: _SubscriptionsText.card),
    AppSelectOption<String>(value: _PaymentMethods.other, label: _SubscriptionsText.other),
  ];
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

String _planModuleText(SubscriptionItem item) {
  return _joinDisplay(<String?>[
    item.planLabel ?? item.name,
    item.moduleLabel ?? item.moduleSlug,
    item.tierCode,
  ]);
}

String _amountOrLimit(BuildContext context, SubscriptionItem item) {
  final num? amount = item.totalAmount ?? item.price;
  if (amount != null) {
    return _money(context, amount, item.currency);
  }
  final List<String> limits = <String>[
    if (item.maxUsers != null)
      _SubscriptionsText.usersLimit(item.maxUsers!),
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
    currencyCode: currencyCode ?? appDefaultCurrencyCode,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}

String _date(BuildContext context, DateTime? value) {
  return value == null
      ? _SubscriptionsText.notRecorded
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

DateTime? _timelineDate(SubscriptionItem item) {
  return item.endDate ??
      item.expiresAt ??
      item.issuedAt ??
      item.updatedAt ??
      item.paidAt;
}

String _nextAction(SubscriptionItem item) {
  return switch (item.resource) {
    SubscriptionResource.subscriptionPlans => _SubscriptionsText.reviewLimits,
    SubscriptionResource.modules => item.isAddOn == true
        ? _SubscriptionsText.addOnAvailable
        : _SubscriptionsText.includedByPlan,
    SubscriptionResource.subscriptions => item.canActivateSubscription
        ? _SubscriptionsText.activate
        : item.canCancelSubscription
            ? _SubscriptionsText.monitorRenewal
            : _SubscriptionsText.review,
    SubscriptionResource.moduleSubscriptions => item.entitlementDenied
        ? _SubscriptionsText.reviewEntitlement
        : item.isActive == true
            ? _SubscriptionsText.disableModule
            : _SubscriptionsText.enableModule,
    SubscriptionResource.subscriptionInvoices => item.canCollectInvoice
        ? _SubscriptionsText.collectInvoice
        : _SubscriptionsText.printInvoice,
    SubscriptionResource.licenses => _SubscriptionsText.reviewExpiry,
  };
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
  if (<String>{'ACTIVE', 'TRIAL', 'PAID', 'HEALTHY', 'FIT'}.contains(normalized)) {
    return AppWorkspaceStatusTone.success;
  }
  if (<String>{'PAST_DUE', 'OVERDUE', 'PARTIAL', 'WARNING', 'PENDING', 'SENT'}.contains(normalized)) {
    return AppWorkspaceStatusTone.warning;
  }
  if (<String>{'DENIED', 'CANCELLED', 'CRITICAL', 'INACTIVE', 'DISABLED'}.contains(normalized)) {
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

String _isoText(DateTime? value) {
  return value?.toUtc().toIso8601String() ?? '';
}

final class _LimitRow {
  const _LimitRow({required this.label, required this.used, required this.limit});

  final String label;
  final int? used;
  final int? limit;
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
  static const String basic = 'BASIC';
  static const String standard = 'STANDARD';
  static const String premium = 'PREMIUM';
  static const String enterprise = 'ENTERPRISE';
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
  static const String liveStatus = 'Live';
  static const String savingStatus = 'Saving';
  static const String savedMessage = 'Subscription workspace updated.';
  static const String overview = 'Overview';
  static const String overviewDescription =
      'Current plan, renewal, entitlement, invoice, and license state.';
  static const String worklistDescription =
      'Search and filter subscription records backed by confirmed APIs.';
  static const String activePlan = 'Active plan';
  static const String activeSubscriptions = 'Active subscriptions';
  static const String subscriptionStatus = 'Subscription status';
  static const String pendingChanges = 'Pending changes';
  static const String pastDueInvoices = 'Past due invoices';
  static const String deniedModules = 'Denied modules';
  static const String expiringLicenses = 'Expiring licenses';
  static const String approachingLimits = 'Approaching limits';
  static const String renewalExpiry = 'Renewal / expiry';
  static const String nextInvoice = 'Next invoice';
  static const String licenses = 'Licenses';
  static const String modulesUsed = 'Modules used';
  static const String users = 'Users';
  static const String facilities = 'Facilities';
  static const String storageMb = 'Storage MB';
  static const String modules = 'Modules';
  static const String recommendations = 'Recommendations';
  static const String searchLabel = 'Search subscriptions';
  static const String searchHint = 'Tenant, plan, module, invoice, status, or date';
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
  static const String planModule = 'Plan / module';
  static const String amountLimit = 'Amount / limit';
  static const String nextAction = 'Next action';
  static const String detailTitle = 'Subscription detail';
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
      'Generated subscription invoice report endpoint is pending the reports implementation.';
  static const String tenant = 'Tenant';
  static const String plan = 'Plan';
  static const String module = 'Module';
  static const String billingCycle = 'Billing cycle';
  static const String amount = 'Amount';
  static const String fitStatus = 'Fit status';
  static const String startDate = 'Start date';
  static const String endDate = 'End date';
  static const String updated = 'Updated';
  static const String timeline = 'Activity';
  static const String notRecorded = 'Not recorded';
  static const String planName = 'Plan name';
  static const String planCode = 'Plan code';
  static const String tier = 'Tier';
  static const String price = 'Price';
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
  static const String dateTimeHint = 'YYYY-MM-DDTHH:MM:SS';
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
  static const String basic = 'Basic';
  static const String standard = 'Standard';
  static const String premium = 'Premium';
  static const String enterprise = 'Enterprise';
  static const String monthly = 'Monthly';
  static const String quarterly = 'Quarterly';
  static const String yearly = 'Yearly';
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String trial = 'Trial';
  static const String pastDue = 'Past due';
  static const String cancelled = 'Cancelled';
  static const String perUser = 'Per user';
  static const String perFacility = 'Per facility';
  static const String cash = 'Cash';
  static const String mobileMoney = 'Mobile money';
  static const String bankTransfer = 'Bank transfer';
  static const String card = 'Card';
  static const String other = 'Other';
  static const String reviewLimits = 'Review limits';
  static const String addOnAvailable = 'Add-on available';
  static const String includedByPlan = 'Included by plan';
  static const String monitorRenewal = 'Monitor renewal';
  static const String review = 'Review';
  static const String reviewEntitlement = 'Review entitlement';
  static const String reviewExpiry = 'Review expiry';

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
