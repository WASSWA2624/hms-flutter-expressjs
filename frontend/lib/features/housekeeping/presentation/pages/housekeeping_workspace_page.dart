import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class HousekeepingWorkspacePage extends ConsumerWidget {
  const HousekeepingWorkspacePage({
    this.initialSection,
    this.initialSearch = '',
    super.key,
  });

  final HousekeepingSection? initialSection;
  final String initialSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<HousekeepingWorkspaceState>> workspace = ref.watch(
      housekeepingWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<HousekeepingWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.housekeepingTitle,
      loadingTitle: l10n.housekeepingLoadingTitle,
      loadingBody: l10n.housekeepingLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(housekeepingWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, HousekeepingWorkspaceState state) {
        return _HousekeepingWorkspaceContent(
          state: state,
          initialSection: initialSection,
          initialSearch: initialSearch,
        );
      },
    );
  }
}

class _HousekeepingWorkspaceContent extends ConsumerStatefulWidget {
  const _HousekeepingWorkspaceContent({
    required this.state,
    this.initialSection,
    this.initialSearch = '',
  });

  final HousekeepingWorkspaceState state;
  final HousekeepingSection? initialSection;
  final String initialSearch;

  @override
  ConsumerState<_HousekeepingWorkspaceContent> createState() {
    return _HousekeepingWorkspaceContentState();
  }
}

class _HousekeepingWorkspaceContentState
    extends ConsumerState<_HousekeepingWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<HousekeepingWorkItem>
  _tableColumnController;
  late HousekeepingSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? HousekeepingSection.tasks;
    _searchController = TextEditingController(
      text: widget.initialSearch.isNotEmpty
          ? widget.initialSearch
          : widget.state.query.search,
    );
    _tableColumnController =
        AppListTableColumnVisibilityController<HousekeepingWorkItem>();

    if (_section != HousekeepingSection.tasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(housekeepingWorkspaceControllerProvider.notifier)
            .applyResource(_section.resource);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HousekeepingWorkspaceContent oldWidget) {
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

  void _updateUrlForSection(HousekeepingSection section) {
    if (!mounted) return;
    final String location = AppRoutes.housekeeping.location(
      queryParameters: <String, String>{'section': section.queryValue},
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HousekeepingWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final _HousekeepingCapabilities capabilities = _capabilities(accessPolicy);
    final controller = ref.read(
      housekeepingWorkspaceControllerProvider.notifier,
    );
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTabStrip(
                    tabs: <AppTabItem>[
                      for (final HousekeepingSection section
                          in HousekeepingSection.values)
                        AppTabItem(
                          id: section.name,
                          icon: _sectionIcon(section),
                          label:
                              '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                        ),
                    ],
                    selectedId: _section.name,
                    onTabTapped: (String tabId) {
                      for (final HousekeepingSection section
                          in HousekeepingSection.values) {
                        if (section.name == tabId) {
                          setState(() => _section = section);
                          _updateUrlForSection(section);
                          controller.applyResource(section.resource);
                          break;
                        }
                      }
                    },
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                if (capabilities.canReport)
                  Padding(
                    padding: EdgeInsets.only(right: theme.spacing.xs),
                    child: AppReportActionButton.preview(
                      label: l10n.housekeepingReportSummaryAction,
                      enabled: capabilities.canReport,
                      onPressed: capabilities.canReport
                          ? () => _showReportPreviewDialog(context, state)
                          : null,
                    ),
                  ),
                _primaryActionButton(l10n, capabilities, state),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            if (lastFailure != null) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            _HousekeepingWorklistPanel(
              state: state,
              section: _section,
              capabilities: capabilities,
              searchController: _searchController,
              columnVisibilityController: _tableColumnController,
              onItemSelected: (HousekeepingWorkItem item) {
                unawaited(_openTaskDetailDialog(context, item, capabilities));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryActionButton(
    AppLocalizations l10n,
    _HousekeepingCapabilities capabilities,
    HousekeepingWorkspaceState state,
  ) {
    return switch (_section) {
      HousekeepingSection.tasks => AppButton.primary(
        label: l10n.housekeepingCreateTaskAction,
        leadingIcon: Icons.add_task_outlined,
        enabled: capabilities.canManage && !state.isSaving,
        onPressed: capabilities.canManage
            ? () => _showTaskDialog(context, ref, state)
            : null,
      ),
      HousekeepingSection.schedules => AppButton.primary(
        label: l10n.housekeepingCreateScheduleAction,
        leadingIcon: Icons.event_repeat_outlined,
        enabled: capabilities.canManage && !state.isSaving,
        onPressed: capabilities.canManage
            ? () => _showScheduleDialog(context, ref, state)
            : null,
      ),
      HousekeepingSection.maintenance => AppButton.primary(
        label: l10n.housekeepingRequestMaintenanceAction,
        leadingIcon: Icons.build_circle_outlined,
        enabled: capabilities.canUpdateTasks && !state.isSaving,
        onPressed: capabilities.canUpdateTasks
            ? () => _showMaintenanceRequestDialog(context, ref, state)
            : null,
      ),
    };
  }

  Future<void> _openTaskDetailDialog(
    BuildContext context,
    HousekeepingWorkItem item,
    _HousekeepingCapabilities capabilities,
  ) async {
    ref.read(housekeepingWorkspaceControllerProvider.notifier).selectItem(item);
    await showAppDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
          final HousekeepingWorkspaceState dialogState =
              _housekeepingStateFromAsync(
                dialogRef.watch(housekeepingWorkspaceControllerProvider),
              ) ??
              widget.state;
          return AppDialog(
            title: Text(dialogContext.l10n.housekeepingDetailTitle),
            icon: const Icon(Icons.cleaning_services_outlined),
            scrollable: true,
            maxWidth: 980,
            content: _HousekeepingDetailPanel(
              state: dialogState,
              capabilities: capabilities,
            ),
          );
        },
      ),
    );
  }
}

IconData _sectionIcon(HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks => Icons.cleaning_services_outlined,
    HousekeepingSection.schedules => Icons.event_repeat_outlined,
    HousekeepingSection.maintenance => Icons.build_circle_outlined,
  };
}

String _sectionLabel(AppLocalizations l10n, HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks => l10n.housekeepingResourceTasks,
    HousekeepingSection.schedules => l10n.housekeepingResourceSchedules,
    HousekeepingSection.maintenance =>
      l10n.housekeepingResourceMaintenanceRequests,
  };
}

int _sectionCount(
  HousekeepingWorkspaceState state,
  HousekeepingSection section,
) {
  return switch (section) {
    HousekeepingSection.tasks => state.overview.summaryValue('pending_tasks'),
    HousekeepingSection.schedules => state.overview.summaryValue(
      'active_schedules',
    ),
    HousekeepingSection.maintenance => state.overview.summaryValue(
      'open_requests',
    ),
  };
}

class _HousekeepingWorklistPanel extends ConsumerWidget {
  const _HousekeepingWorklistPanel({
    required this.state,
    required this.section,
    required this.capabilities,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onItemSelected,
  });

  final HousekeepingWorkspaceState state;
  final HousekeepingSection section;
  final _HousekeepingCapabilities capabilities;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HousekeepingWorkItem>
  columnVisibilityController;
  final ValueChanged<HousekeepingWorkItem> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(
      housekeepingWorkspaceControllerProvider.notifier,
    );

    return AppListTable<HousekeepingWorkItem>(
      page: state.items,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'housekeeping_${section.name}',
      columnWidthStorageKey: 'housekeeping_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: AppListTableSearch<HousekeepingWorkItem>(
        controller: searchController,
        semanticLabel: l10n.housekeepingSearchLabel,
        hintText: l10n.housekeepingSearchHint,
        clearLabel: l10n.housekeepingClearSearchAction,
        matcher: (_, _) => true,
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.housekeepingFiltersAction,
        advancedFilterTitle: l10n.housekeepingFiltersTitle,
        advancedFilterApplyLabel: l10n.housekeepingApplyFiltersAction,
        advancedFilterResetLabel: l10n.housekeepingClearFiltersAction,
        enableDateFilter: false,
        filterGroups: _filterGroupsForSection(l10n, state, section),
        filterValue: _filterValue(state.query),
        hasActiveFilters: _hasActiveFilters(state.query),
        onFilterChanged: (AppSearchBarFilterValue value) {
          controller.applyFilters(
            resource: section.resource,
            queue:
                _queueFromFilter(value.option(_queueFilterKey)) ??
                HousekeepingQueue.all,
            status: value.option(_statusFilterKey),
            facilityId: value.option(_facilityFilterKey),
            roomId: value.option(_roomFilterKey),
            assigneeId: value.option(_assigneeFilterKey),
            datePreset:
                _datePresetFromFilter(value.option(_datePresetFilterKey)) ??
                HousekeepingDatePreset.all,
          );
        },
      ),
      itemKeyBuilder: (HousekeepingWorkItem item) =>
          ValueKey<String>('${item.resource.serverValue}:${item.id}'),
      onRowSelected: onItemSelected,
      previousPageLabel: l10n.housekeepingPreviousPageLabel,
      nextPageLabel: l10n.housekeepingNextPageLabel,
      pageLabelBuilder: (AppPage<HousekeepingWorkItem> page) {
        final int total = page.totalItemCount ?? page.lastItemNumber;
        return l10n.housekeepingPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          total,
        );
      },
      onPageChanged: controller.changePage,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.housekeepingEmptyQueueTitle,
        body: l10n.housekeepingEmptyQueueBody,
      ),
      columns: _columnsForSection(l10n, section, capabilities),
      mobileItemBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return switch (section) {
          HousekeepingSection.tasks => _taskMobileItem(context, l10n, item),
          HousekeepingSection.schedules => _scheduleMobileItem(
            context,
            l10n,
            item,
          ),
          HousekeepingSection.maintenance => _maintenanceMobileItem(
            context,
            l10n,
            item,
          ),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Per-section columns
// ---------------------------------------------------------------------------

List<AppListTableColumn<HousekeepingWorkItem>> _columnsForSection(
  AppLocalizations l10n,
  HousekeepingSection section,
  _HousekeepingCapabilities capabilities,
) {
  switch (section) {
    case HousekeepingSection.tasks:
      return _taskColumns(l10n, capabilities);
    case HousekeepingSection.schedules:
      return _scheduleColumns(l10n);
    case HousekeepingSection.maintenance:
      return _maintenanceColumns(l10n, capabilities);
  }
}

List<AppListTableColumn<HousekeepingWorkItem>> _taskColumns(
  AppLocalizations l10n,
  _HousekeepingCapabilities capabilities,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingTaskColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _CopyableTaskCell(
          title: item.title,
          identifier: item.effectiveDisplayId,
        );
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingLocationColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(
          left.locationDisplay,
          right.locationDisplay,
        );
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_locationLabel(l10n, item));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingAssigneeColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.assigneeLabel, right.assigneeLabel);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(item.assigneeLabel ?? l10n.housekeepingUnassigned);
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingDueColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareDateTime(left.scheduledAt, right.scheduledAt);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_dateTimeLabel(context, item.scheduledAt));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingStatusColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _HousekeepingStatusBadge(item: item);
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingNextActionColumnLabel,
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_nextActionLabel(l10n, item, capabilities));
      },
    ),
  ];
}

List<AppListTableColumn<HousekeepingWorkItem>> _scheduleColumns(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingScheduleColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _CopyableTaskCell(
          title: item.title,
          identifier: item.effectiveDisplayId,
        );
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingLocationColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(
          left.locationDisplay,
          right.locationDisplay,
        );
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_locationLabel(l10n, item));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingFrequencyColumnLabel,
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(item.subtitle ?? '');
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingStartDateColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareDateTime(left.startDate, right.startDate);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_dateTimeLabel(context, item.startDate));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingEndDateColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareDateTime(left.endDate, right.endDate);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_dateTimeLabel(context, item.endDate));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingStatusColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _HousekeepingStatusBadge(item: item);
      },
    ),
  ];
}

List<AppListTableColumn<HousekeepingWorkItem>> _maintenanceColumns(
  AppLocalizations l10n,
  _HousekeepingCapabilities capabilities,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingRequestColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _CopyableTaskCell(
          title: item.title,
          identifier: item.effectiveDisplayId,
        );
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingLocationColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(
          left.locationDisplay,
          right.locationDisplay,
        );
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_locationLabel(l10n, item));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingAssetColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.assetLabel, right.assetLabel);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(item.assetLabel ?? '');
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingReportedColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareDateTime(left.reportedAt, right.reportedAt);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_dateTimeLabel(context, item.reportedAt));
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingStatusColumnLabel,
      sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return _HousekeepingStatusBadge(item: item);
      },
    ),
    AppListTableColumn<HousekeepingWorkItem>(
      label: l10n.housekeepingNextActionColumnLabel,
      cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return Text(_nextActionLabel(l10n, item, capabilities));
      },
    ),
  ];
}

// ---------------------------------------------------------------------------
// Per-section mobile item builders
// ---------------------------------------------------------------------------

Widget _taskMobileItem(
  BuildContext context,
  AppLocalizations l10n,
  HousekeepingWorkItem item,
) {
  return AppListItemRow(
    title: item.title,
    subtitle: _locationLabel(l10n, item),
    leadingIcon: Icons.cleaning_services_outlined,
    trailing: _HousekeepingStatusBadge(item: item),
    details: <Widget>[
      AppCopyableIdentifier(
        value: item.effectiveDisplayId,
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
      AppInlineMetaText(
        icon: Icons.person_outline,
        label: item.assigneeLabel ?? l10n.housekeepingUnassigned,
      ),
      AppInlineMetaText(
        icon: Icons.schedule_outlined,
        label: _dateTimeLabel(context, item.scheduledAt),
      ),
    ],
  );
}

Widget _scheduleMobileItem(
  BuildContext context,
  AppLocalizations l10n,
  HousekeepingWorkItem item,
) {
  return AppListItemRow(
    title: item.title,
    subtitle: item.subtitle ?? '',
    leadingIcon: Icons.event_repeat_outlined,
    trailing: _HousekeepingStatusBadge(item: item),
    details: <Widget>[
      AppCopyableIdentifier(
        value: item.effectiveDisplayId,
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
      AppInlineMetaText(
        icon: Icons.meeting_room_outlined,
        label: _locationLabel(l10n, item),
      ),
      AppInlineMetaText(
        icon: Icons.date_range_outlined,
        label: _dateTimeLabel(context, item.startDate),
      ),
    ],
  );
}

Widget _maintenanceMobileItem(
  BuildContext context,
  AppLocalizations l10n,
  HousekeepingWorkItem item,
) {
  return AppListItemRow(
    title: item.title,
    subtitle: _locationLabel(l10n, item),
    leadingIcon: Icons.build_circle_outlined,
    trailing: _HousekeepingStatusBadge(item: item),
    details: <Widget>[
      AppCopyableIdentifier(
        value: item.effectiveDisplayId,
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
      AppInlineMetaText(
        icon: Icons.inventory_2_outlined,
        label: item.assetLabel ?? '',
      ),
      AppInlineMetaText(
        icon: Icons.schedule_outlined,
        label: _dateTimeLabel(context, item.reportedAt),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Filter groups (section-aware, resource filter removed)
// ---------------------------------------------------------------------------

List<AppSearchBarFilterGroup> _filterGroupsForSection(
  AppLocalizations l10n,
  HousekeepingWorkspaceState state,
  HousekeepingSection section,
) {
  final HousekeepingLookups lookups = state.overview.lookups;
  return <AppSearchBarFilterGroup>[
    if (section == HousekeepingSection.tasks)
      AppSearchBarFilterGroup(
        key: _queueFilterKey,
        label: l10n.housekeepingQueueFilterLabel,
        allLabel: l10n.housekeepingQueueAll,
        choices: <AppSearchBarFilterChoice>[
          for (final HousekeepingQueue queue in HousekeepingQueue.values)
            if (queue != HousekeepingQueue.all && !queue.isRequestQueue)
              AppSearchBarFilterChoice(
                value: queue.name,
                label: _queueLabel(l10n, queue),
                icon: _queueIcon(queue),
              ),
        ],
      ),
    if (section == HousekeepingSection.maintenance)
      AppSearchBarFilterGroup(
        key: _queueFilterKey,
        label: l10n.housekeepingQueueFilterLabel,
        allLabel: l10n.housekeepingQueueAll,
        choices: <AppSearchBarFilterChoice>[
          for (final HousekeepingQueue queue in HousekeepingQueue.values)
            if (queue != HousekeepingQueue.all && !queue.isTaskQueue)
              AppSearchBarFilterChoice(
                value: queue.name,
                label: _queueLabel(l10n, queue),
                icon: _queueIcon(queue),
              ),
        ],
      ),
    AppSearchBarFilterGroup(
      key: _statusFilterKey,
      label: l10n.housekeepingStatusFilterLabel,
      allLabel: l10n.housekeepingStatusAll,
      choices: <AppSearchBarFilterChoice>[
        for (final String status in _statusChoicesFor(section.resource))
          AppSearchBarFilterChoice(
            value: status,
            label: _statusLabelForResource(l10n, section.resource, status),
            icon: Icons.flag_outlined,
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: _facilityFilterKey,
      label: l10n.housekeepingFacilityFilterLabel,
      allLabel: l10n.housekeepingAllFacilities,
      choices: _lookupFilterChoices(lookups.facilities, Icons.business),
    ),
    AppSearchBarFilterGroup(
      key: _roomFilterKey,
      label: l10n.housekeepingRoomFilterLabel,
      allLabel: l10n.housekeepingAllRooms,
      choices: _lookupFilterChoices(lookups.rooms, Icons.meeting_room_outlined),
    ),
    if (section == HousekeepingSection.tasks)
      AppSearchBarFilterGroup(
        key: _assigneeFilterKey,
        label: l10n.housekeepingAssigneeFilterLabel,
        allLabel: l10n.housekeepingAllAssignees,
        choices: _lookupFilterChoices(lookups.assignees, Icons.person_outline),
      ),
    AppSearchBarFilterGroup(
      key: _datePresetFilterKey,
      label: l10n.housekeepingDateFilterLabel,
      allLabel: l10n.housekeepingDateAll,
      choices: <AppSearchBarFilterChoice>[
        for (final HousekeepingDatePreset preset
            in HousekeepingDatePreset.values)
          if (preset != HousekeepingDatePreset.all)
            AppSearchBarFilterChoice(
              value: preset.name,
              label: _datePresetLabel(l10n, preset),
              icon: Icons.event_outlined,
            ),
      ],
    ),
  ];
}

// ---------------------------------------------------------------------------
// Detail panel
// ---------------------------------------------------------------------------

class _HousekeepingDetailPanel extends ConsumerWidget {
  const _HousekeepingDetailPanel({
    required this.state,
    required this.capabilities,
  });

  final HousekeepingWorkspaceState state;
  final _HousekeepingCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final HousekeepingWorkItem? item = state.selectedItem;
    if (item == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.housekeepingNoSelectionTitle,
        description: l10n.housekeepingNoSelectionBody,
        child: AppStateView(
          title: l10n.housekeepingNoSelectionTitle,
          body: l10n.housekeepingNoSelectionBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.housekeepingDetailTitle,
      description: item.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppInfoTileGrid(
            maxColumns: 2,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.housekeepingReferenceLabel,
                value: item.effectiveDisplayId,
                icon: Icons.tag_outlined,
                copyable: true,
              ),
              AppInfoTileData(
                label: l10n.housekeepingLocationLabel,
                value: _locationLabel(l10n, item),
                icon: Icons.meeting_room_outlined,
              ),
              AppInfoTileData(
                label: l10n.housekeepingAssigneeLabel,
                value: item.assigneeLabel ?? l10n.housekeepingUnassigned,
                icon: Icons.person_outline,
              ),
              AppInfoTileData(
                label: l10n.housekeepingDueLabel,
                value: _dateTimeLabel(context, _primaryDate(item)),
                icon: Icons.schedule_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _DetailActions(
            item: item,
            isSaving: state.isSaving,
            capabilities: capabilities,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppReportPreviewPanel(
            title: l10n.housekeepingReadinessTitle,
            child: _ReadinessPreview(item: item),
          ),
        ],
      ),
    );
  }
}

class _DetailActions extends ConsumerWidget {
  const _DetailActions({
    required this.item,
    required this.isSaving,
    required this.capabilities,
  });

  final HousekeepingWorkItem item;
  final bool isSaving;
  final _HousekeepingCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AppActionList(
      actions: <AppActionItem>[
        if (item.isTask)
          AppActionItem(
            label: l10n.housekeepingAssignAction,
            leadingIcon: Icons.assignment_ind_outlined,
            enabled: capabilities.canManage && !isSaving && !item.isTerminal,
            onPressed: () => _showAssignDialog(context, ref, item),
          ),
        if (item.isTask)
          AppActionItem(
            label: l10n.housekeepingStartAction,
            leadingIcon: Icons.play_arrow_outlined,
            enabled:
                capabilities.canUpdateTasks &&
                !isSaving &&
                _normalizedStatus(item) == 'PENDING',
            variant: AppActionVariant.primary,
            onPressed: () => _confirmTaskAction(
              context,
              ref,
              item,
              title: l10n.housekeepingStartDialogTitle,
              body: l10n.housekeepingStartDialogBody,
              submitLabel: l10n.housekeepingStartAction,
              submit: () {
                return ref
                    .read(housekeepingWorkspaceControllerProvider.notifier)
                    .startTask(item);
              },
            ),
          ),
        if (item.isTask)
          AppActionItem(
            label: l10n.housekeepingCompleteAction,
            leadingIcon: Icons.task_alt_outlined,
            enabled:
                capabilities.canUpdateTasks &&
                !isSaving &&
                _normalizedStatus(item) == 'IN_PROGRESS',
            variant: AppActionVariant.primary,
            onPressed: () => _confirmTaskAction(
              context,
              ref,
              item,
              title: l10n.housekeepingCompleteDialogTitle,
              body: l10n.housekeepingCompleteDialogBody,
              submitLabel: l10n.housekeepingCompleteAction,
              submit: () {
                return ref
                    .read(housekeepingWorkspaceControllerProvider.notifier)
                    .completeTask(item);
              },
            ),
          ),
        if (item.isTask)
          AppActionItem(
            label: l10n.housekeepingCancelAction,
            leadingIcon: Icons.cancel_outlined,
            enabled: capabilities.canManage && !isSaving && !item.isTerminal,
            onPressed: () => _confirmTaskAction(
              context,
              ref,
              item,
              title: l10n.housekeepingCancelDialogTitle,
              body: l10n.housekeepingCancelDialogBody,
              submitLabel: l10n.housekeepingCancelAction,
              submit: () {
                return ref
                    .read(housekeepingWorkspaceControllerProvider.notifier)
                    .cancelTask(item);
              },
            ),
          ),
        if (item.isTask)
          AppActionItem(
            label: l10n.housekeepingMarkReadyAction,
            leadingIcon: Icons.hotel_outlined,
            enabled: false,
            tooltip: l10n.housekeepingBackendGapTooltip,
            onPressed: null,
          ),
        if (item.isMaintenanceRequest)
          AppActionItem(
            label: l10n.housekeepingTriageAction,
            leadingIcon: Icons.rule_outlined,
            enabled:
                capabilities.canManage &&
                !isSaving &&
                !_isMaintenanceTerminal(item),
            variant: AppActionVariant.primary,
            onPressed: () => _showTriageDialog(context, ref, item),
          ),
        if (item.isMaintenanceRequest)
          AppActionItem(
            label: l10n.housekeepingCompleteRequestAction,
            leadingIcon: Icons.task_alt_outlined,
            enabled:
                capabilities.canManage &&
                !isSaving &&
                !_isMaintenanceTerminal(item),
            onPressed: () => _confirmTaskAction(
              context,
              ref,
              item,
              title: l10n.housekeepingCompleteRequestDialogTitle,
              body: l10n.housekeepingCompleteRequestDialogBody,
              submitLabel: l10n.housekeepingCompleteRequestAction,
              submit: () {
                return ref
                    .read(housekeepingWorkspaceControllerProvider.notifier)
                    .completeMaintenanceRequest(item);
              },
            ),
          ),
        if (item.isMaintenanceRequest)
          AppActionItem(
            label: l10n.housekeepingCancelRequestAction,
            leadingIcon: Icons.cancel_outlined,
            enabled:
                capabilities.canManage &&
                !isSaving &&
                !_isMaintenanceTerminal(item),
            onPressed: () => _confirmTaskAction(
              context,
              ref,
              item,
              title: l10n.housekeepingCancelRequestDialogTitle,
              body: l10n.housekeepingCancelRequestDialogBody,
              submitLabel: l10n.housekeepingCancelRequestAction,
              submit: () {
                return ref
                    .read(housekeepingWorkspaceControllerProvider.notifier)
                    .cancelMaintenanceRequest(item);
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _ReadinessPreview extends StatelessWidget {
  const _ReadinessPreview({required this.item});

  final HousekeepingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HousekeepingStatusBadge(item: item),
        SizedBox(height: theme.spacing.sm),
        Text(
          item.isTask
              ? l10n.housekeepingTaskReadinessBody
              : item.isSchedule
              ? l10n.housekeepingScheduleReadinessBody
              : l10n.housekeepingMaintenanceReadinessBody,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _CopyableTaskCell extends StatelessWidget {
  const _CopyableTaskCell({required this.title, required this.identifier});

  final String title;
  final String identifier;

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
          style: theme.textTheme.bodyMedium,
        ),
        AppCopyableIdentifier(
          value: identifier,
          textStyle: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HousekeepingStatusBadge extends StatelessWidget {
  const _HousekeepingStatusBadge({required this.item});

  final HousekeepingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _statusLabel(l10n, item),
        tone: _statusTone(item),
        icon: _statusIcon(item),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forms
// ---------------------------------------------------------------------------

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.state});

  final HousekeepingWorkspaceState state;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _status = 'PENDING';
  String? _facilityId;
  String? _roomId;
  String? _assigneeId;
  DateTime? _scheduledAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _facilityId,
          labelText: l10n.housekeepingFacilityFieldLabel,
          hintText: l10n.housekeepingFacilityFieldHint,
          options: _selectOptions(widget.state.overview.lookups.facilities),
          onChanged: (String? value) => setState(() => _facilityId = value),
        ),
        AppSelectField<String>.searchable(
          value: _roomId,
          labelText: l10n.housekeepingRoomFieldLabel,
          hintText: l10n.housekeepingRoomFieldHint,
          options: _selectOptions(widget.state.overview.lookups.rooms),
          onChanged: (String? value) => setState(() => _roomId = value),
        ),
        AppSelectField<String>.searchable(
          value: _assigneeId,
          labelText: l10n.housekeepingAssigneeFieldLabel,
          hintText: l10n.housekeepingAssigneeFieldHint,
          options: _selectOptions(widget.state.overview.lookups.assignees),
          onChanged: (String? value) => setState(() => _assigneeId = value),
        ),
        AppSelectField<String>(
          value: _status,
          labelText: l10n.housekeepingStatusFieldLabel,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final String status in housekeepingTaskStatusValues)
              AppSelectOption<String>(
                value: status,
                label: _taskStatusLabel(l10n, status),
              ),
          ],
          validator: AppValidators.requiredValue(
            l10n.housekeepingStatusRequiredMessage,
          ),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        _HousekeepingDateField(
          value: _scheduledAt,
          labelText: l10n.housekeepingScheduledDateFieldLabel,
          onChanged: (DateTime? value) => setState(() => _scheduledAt = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.housekeepingCreateTaskSubmitAction,
          submitIcon: Icons.add_task_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              HousekeepingTaskDraft(
                status: _status,
                facilityId: _facilityId,
                roomId: _roomId,
                assigneeId: _assigneeId,
                scheduledAt: _scheduledAt,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({required this.state});

  final HousekeepingWorkspaceState state;

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _frequencyController = TextEditingController();
  String? _facilityId;
  String? _roomId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _frequencyController,
          labelText: l10n.housekeepingFrequencyFieldLabel,
          hintText: l10n.housekeepingFrequencyFieldHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.housekeepingFrequencyRequiredMessage,
          ),
        ),
        AppSelectField<String>.searchable(
          value: _facilityId,
          labelText: l10n.housekeepingFacilityFieldLabel,
          hintText: l10n.housekeepingFacilityFieldHint,
          options: _selectOptions(widget.state.overview.lookups.facilities),
          onChanged: (String? value) => setState(() => _facilityId = value),
        ),
        AppSelectField<String>.searchable(
          value: _roomId,
          labelText: l10n.housekeepingRoomFieldLabel,
          hintText: l10n.housekeepingRoomFieldHint,
          options: _selectOptions(widget.state.overview.lookups.rooms),
          onChanged: (String? value) => setState(() => _roomId = value),
        ),
        _HousekeepingDateField(
          value: _startDate,
          labelText: l10n.housekeepingStartDateFieldLabel,
          onChanged: (DateTime? value) => setState(() => _startDate = value),
        ),
        _HousekeepingDateField(
          value: _endDate,
          labelText: l10n.housekeepingEndDateFieldLabel,
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.housekeepingCreateScheduleSubmitAction,
          submitIcon: Icons.event_repeat_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              HousekeepingScheduleDraft(
                frequency: _frequencyController.text.trim(),
                facilityId: _facilityId,
                roomId: _roomId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MaintenanceRequestForm extends StatefulWidget {
  const _MaintenanceRequestForm({required this.state});

  final HousekeepingWorkspaceState state;

  @override
  State<_MaintenanceRequestForm> createState() =>
      _MaintenanceRequestFormState();
}

class _MaintenanceRequestFormState extends State<_MaintenanceRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  String? _facilityId;
  String? _assetId;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _facilityId,
          labelText: l10n.housekeepingFacilityFieldLabel,
          hintText: l10n.housekeepingFacilityFieldHint,
          options: _selectOptions(widget.state.overview.lookups.facilities),
          onChanged: (String? value) => setState(() => _facilityId = value),
        ),
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.housekeepingAssetFieldLabel,
          hintText: l10n.housekeepingAssetFieldHint,
          options: _selectOptions(widget.state.overview.lookups.assets),
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _descriptionController,
          labelText: l10n.housekeepingDescriptionFieldLabel,
          hintText: l10n.housekeepingDescriptionFieldHint,
          isRequired: true,
          maxLines: 4,
          validator: AppValidators.requiredText(
            l10n.housekeepingDescriptionRequiredMessage,
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.housekeepingRequestMaintenanceSubmitAction,
          submitIcon: Icons.build_circle_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              HousekeepingMaintenanceRequestDraft(
                status: 'OPEN',
                facilityId: _facilityId,
                assetId: _assetId,
                description: _descriptionController.text.trim(),
                reportedAt: DateTime.now(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AssignForm extends StatefulWidget {
  const _AssignForm({required this.state, required this.item});

  final HousekeepingWorkspaceState state;
  final HousekeepingWorkItem item;

  @override
  State<_AssignForm> createState() => _AssignFormState();
}

class _AssignFormState extends State<_AssignForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String? _assigneeId = widget.item.assigneeId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _assigneeId,
          labelText: l10n.housekeepingAssigneeFieldLabel,
          hintText: l10n.housekeepingAssigneeFieldHint,
          options: _selectOptions(widget.state.overview.lookups.assignees),
          onChanged: (String? value) => setState(() => _assigneeId = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.housekeepingAssignSubmitAction,
          submitIcon: Icons.assignment_ind_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(_assigneeId);
          },
        ),
      ],
    );
  }
}

class _TriageForm extends StatefulWidget {
  const _TriageForm();

  @override
  State<_TriageForm> createState() => _TriageFormState();
}

class _TriageFormState extends State<_TriageForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _slaController = TextEditingController();
  String _status = 'IN_PROGRESS';

  @override
  void dispose() {
    _summaryController.dispose();
    _slaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _status,
          labelText: l10n.housekeepingStatusFieldLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'OPEN',
              label: l10n.housekeepingStatusOpenLabel,
            ),
            AppSelectOption<String>(
              value: 'IN_PROGRESS',
              label: l10n.housekeepingStatusInProgressLabel,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _summaryController,
          labelText: l10n.housekeepingTriageSummaryFieldLabel,
          maxLines: 4,
        ),
        AppTextField(
          controller: _slaController,
          labelText: l10n.housekeepingSlaHoursFieldLabel,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.housekeepingTriageSubmitAction,
          submitIcon: Icons.rule_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              HousekeepingMaintenanceTriageDraft(
                status: _status,
                summary: _emptyToNull(_summaryController.text),
                slaHours: int.tryParse(_slaController.text.trim()),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ConfirmationForm extends StatelessWidget {
  const _ConfirmationForm({
    required this.body,
    required this.submitLabel,
    required this.submitIcon,
  });

  final String body;
  final String submitLabel;
  final IconData submitIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    return AppFormShell(
      formKey: formKey,
      children: <Widget>[
        Text(body),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: submitLabel,
          submitIcon: submitIcon,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _HousekeepingDateField extends StatelessWidget {
  const _HousekeepingDateField({
    required this.value,
    required this.labelText,
    required this.onChanged,
  });

  final DateTime? value;
  final String labelText;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final DateTime now = DateTime.now();
    return AppDateField(
      value: value,
      labelText: labelText,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialPickerDate: value ?? now,
      pickerButtonLabel: l10n.housekeepingPickDateAction,
      invalidDateMessage: l10n.appDateInvalidMessage,
      hintText: l10n.appDateFormatHint,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level dialog functions
// ---------------------------------------------------------------------------

HousekeepingWorkspaceState? _housekeepingStateFromAsync(
  AsyncValue<Result<HousekeepingWorkspaceState>> asyncState,
) {
  return switch (asyncState.asData?.value) {
    ResultSuccess<HousekeepingWorkspaceState>(value: final value) => value,
    _ => null,
  };
}

Future<void> _showTaskDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkspaceState state,
) async {
  final l10n = context.l10n;
  final HousekeepingTaskDraft? draft =
      await showAppWorkspaceActionDialog<HousekeepingTaskDraft>(
        context: context,
        title: Text(l10n.housekeepingCreateTaskDialogTitle),
        icon: const Icon(Icons.add_task_outlined),
        content: _TaskForm(state: state),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(housekeepingWorkspaceControllerProvider.notifier)
      .createTask(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showScheduleDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkspaceState state,
) async {
  final l10n = context.l10n;
  final HousekeepingScheduleDraft? draft =
      await showAppWorkspaceActionDialog<HousekeepingScheduleDraft>(
        context: context,
        title: Text(l10n.housekeepingCreateScheduleDialogTitle),
        icon: const Icon(Icons.event_repeat_outlined),
        content: _ScheduleForm(state: state),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(housekeepingWorkspaceControllerProvider.notifier)
      .createSchedule(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showMaintenanceRequestDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkspaceState state,
) async {
  final l10n = context.l10n;
  final HousekeepingMaintenanceRequestDraft? draft =
      await showAppWorkspaceActionDialog<HousekeepingMaintenanceRequestDraft>(
        context: context,
        title: Text(l10n.housekeepingRequestMaintenanceDialogTitle),
        icon: const Icon(Icons.build_circle_outlined),
        content: _MaintenanceRequestForm(state: state),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(housekeepingWorkspaceControllerProvider.notifier)
      .createMaintenanceRequest(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showAssignDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item,
) async {
  final l10n = context.l10n;
  final HousekeepingWorkspaceState? state = _readState(ref);
  if (state == null) {
    return;
  }
  final String? assigneeId = await showAppWorkspaceActionDialog<String?>(
    context: context,
    title: Text(l10n.housekeepingAssignDialogTitle),
    icon: const Icon(Icons.assignment_ind_outlined),
    content: _AssignForm(state: state, item: item),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(housekeepingWorkspaceControllerProvider.notifier)
      .assignTask(item, assigneeId: assigneeId);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showTriageDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item,
) async {
  final l10n = context.l10n;
  final HousekeepingMaintenanceTriageDraft? draft =
      await showAppWorkspaceActionDialog<HousekeepingMaintenanceTriageDraft>(
        context: context,
        title: Text(l10n.housekeepingTriageDialogTitle),
        icon: const Icon(Icons.rule_outlined),
        content: const _TriageForm(),
      );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(housekeepingWorkspaceControllerProvider.notifier)
      .triageMaintenanceRequest(item, draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _confirmTaskAction(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item, {
  required String title,
  required String body,
  required String submitLabel,
  required Future<AppFailure?> Function() submit,
}) async {
  final bool? confirmed = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    icon: Icon(_resourceIcon(item.resource)),
    content: _ConfirmationForm(
      body: body,
      submitLabel: submitLabel,
      submitIcon: Icons.task_alt_outlined,
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await submit();
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showReportPreviewDialog(
  BuildContext context,
  HousekeepingWorkspaceState state,
) {
  final l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  return showAppWorkspaceActionDialog<void>(
    context: context,
    title: Text(l10n.housekeepingReportSummaryTitle),
    icon: const Icon(Icons.assessment_outlined),
    maxWidth: 760,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: l10n.housekeepingPendingTasksSummaryLabel,
              value: AppFormatters.compactNumber(
                state.overview.summaryValue('pending_tasks'),
                locale,
              ),
              icon: Icons.cleaning_services_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.housekeepingCompletedTodaySummaryLabel,
              value: AppFormatters.compactNumber(
                state.overview.summaryValue('completed_today'),
                locale,
              ),
              icon: Icons.task_alt_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.housekeepingOpenRequestsSummaryLabel,
              value: AppFormatters.compactNumber(
                state.overview.summaryValue('open_requests'),
                locale,
              ),
              icon: Icons.build_circle_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.housekeepingOverdueRequestsSummaryLabel,
              value: AppFormatters.compactNumber(
                state.overview.summaryValue('overdue_requests'),
                locale,
              ),
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppReportPreviewPanel(
          title: l10n.housekeepingReportPreviewTitle,
          child: Text(l10n.housekeepingReportPreviewBody),
        ),
      ],
    ),
  );
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? l10n.housekeepingSavedMessage
            : l10n.failureMessage(failure),
      ),
    ),
  );
}

HousekeepingWorkspaceState? _readState(WidgetRef ref) {
  final Result<HousekeepingWorkspaceState>? result = ref
      .read(housekeepingWorkspaceControllerProvider)
      .asData
      ?.value;
  return switch (result) {
    ResultSuccess<HousekeepingWorkspaceState>(value: final value) => value,
    _ => null,
  };
}

// ---------------------------------------------------------------------------
// Filter helpers
// ---------------------------------------------------------------------------

List<AppSearchBarFilterChoice> _lookupFilterChoices(
  List<HousekeepingLookupOption> options,
  IconData icon,
) {
  return <AppSearchBarFilterChoice>[
    for (final HousekeepingLookupOption option in options)
      AppSearchBarFilterChoice(
        value: option.id,
        label: option.label,
        icon: icon,
      ),
  ];
}

AppSearchBarFilterValue _filterValue(HousekeepingWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.queue != HousekeepingQueue.all)
        _queueFilterKey: query.queue.name,
      if (_notEmpty(query.status)) _statusFilterKey: query.status!,
      if (_notEmpty(query.facilityId)) _facilityFilterKey: query.facilityId!,
      if (_notEmpty(query.roomId)) _roomFilterKey: query.roomId!,
      if (_notEmpty(query.assigneeId)) _assigneeFilterKey: query.assigneeId!,
      if (query.datePreset != HousekeepingDatePreset.all)
        _datePresetFilterKey: query.datePreset.name,
    },
  );
}

bool _hasActiveFilters(HousekeepingWorkspaceQuery query) {
  return query.queue != HousekeepingQueue.all ||
      _notEmpty(query.status) ||
      _notEmpty(query.facilityId) ||
      _notEmpty(query.roomId) ||
      _notEmpty(query.assigneeId) ||
      query.datePreset != HousekeepingDatePreset.all;
}

List<AppSelectOption<String>> _selectOptions(
  List<HousekeepingLookupOption> options,
) {
  return <AppSelectOption<String>>[
    for (final HousekeepingLookupOption option in options)
      AppSelectOption<String>(
        value: option.id,
        label: option.subtitle == null
            ? option.label
            : '${option.label} - ${option.subtitle}',
      ),
  ];
}

// ---------------------------------------------------------------------------
// Capabilities
// ---------------------------------------------------------------------------

_HousekeepingCapabilities _capabilities(AppAccessPolicy policy) {
  final bool isHousekeepingRole =
      policy.hasRole(AppRole.houseKeeper) ||
      policy.hasRole(AppRole.housekeepingManager);
  final bool canManage =
      policy.grants(AppPermissions.operationsWrite) ||
      policy.hasRole(AppRole.operations) ||
      policy.hasRole(AppRole.housekeepingManager);
  return _HousekeepingCapabilities(
    canManage: canManage,
    canUpdateTasks: canManage || isHousekeepingRole,
    canReport:
        policy.grants(AppPermissions.reportsRead) ||
        policy.grants(AppPermissions.operationsRead),
  );
}

final class _HousekeepingCapabilities {
  const _HousekeepingCapabilities({
    required this.canManage,
    required this.canUpdateTasks,
    required this.canReport,
  });

  final bool canManage;
  final bool canUpdateTasks;
  final bool canReport;
}

// ---------------------------------------------------------------------------
// Label / icon helpers
// ---------------------------------------------------------------------------

String _queueLabel(AppLocalizations l10n, HousekeepingQueue queue) {
  return switch (queue) {
    HousekeepingQueue.all => l10n.housekeepingQueueAll,
    HousekeepingQueue.today => l10n.housekeepingQueueToday,
    HousekeepingQueue.overdueTasks => l10n.housekeepingQueueOverdueTasks,
    HousekeepingQueue.openRequests => l10n.housekeepingQueueOpenRequests,
    HousekeepingQueue.overdueRequests => l10n.housekeepingQueueOverdueRequests,
  };
}

String _datePresetLabel(AppLocalizations l10n, HousekeepingDatePreset preset) {
  return switch (preset) {
    HousekeepingDatePreset.all => l10n.housekeepingDateAll,
    HousekeepingDatePreset.today => l10n.housekeepingDateToday,
    HousekeepingDatePreset.nextSevenDays => l10n.housekeepingDateNextSevenDays,
    HousekeepingDatePreset.overdue => l10n.housekeepingDateOverdue,
    HousekeepingDatePreset.thisMonth => l10n.housekeepingDateThisMonth,
  };
}

String _statusLabel(AppLocalizations l10n, HousekeepingWorkItem item) {
  return _statusLabelForResource(l10n, item.resource, item.status);
}

String _statusLabelForResource(
  AppLocalizations l10n,
  HousekeepingResource resource,
  String? status,
) {
  return switch (resource) {
    HousekeepingResource.tasks => _taskStatusLabel(l10n, status),
    HousekeepingResource.schedules => l10n.housekeepingStatusScheduled,
    HousekeepingResource.maintenanceRequests => _maintenanceStatusLabel(
      l10n,
      status,
    ),
  };
}

String _taskStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'PENDING' => l10n.housekeepingStatusPending,
    'IN_PROGRESS' => l10n.housekeepingStatusInProgress,
    'COMPLETED' => l10n.housekeepingStatusCompleted,
    'CANCELLED' => l10n.housekeepingStatusCancelled,
    _ => l10n.housekeepingStatusUnknown,
  };
}

String _maintenanceStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => l10n.housekeepingStatusOpen,
    'IN_PROGRESS' => l10n.housekeepingStatusInProgress,
    'COMPLETED' => l10n.housekeepingStatusCompleted,
    'CANCELLED' => l10n.housekeepingStatusCancelled,
    _ => l10n.housekeepingStatusUnknown,
  };
}

AppWorkspaceStatusTone _statusTone(HousekeepingWorkItem item) {
  return switch (_normalizedStatus(item)) {
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.neutral,
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'OPEN' => AppWorkspaceStatusTone.warning,
    'PENDING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _statusIcon(HousekeepingWorkItem item) {
  return switch (_normalizedStatus(item)) {
    'COMPLETED' => Icons.task_alt_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    'IN_PROGRESS' => Icons.cleaning_services_outlined,
    'OPEN' => Icons.report_problem_outlined,
    'PENDING' => Icons.pending_actions_outlined,
    _ => Icons.flag_outlined,
  };
}

String _nextActionLabel(
  AppLocalizations l10n,
  HousekeepingWorkItem item,
  _HousekeepingCapabilities capabilities,
) {
  if (item.isSchedule) {
    return l10n.housekeepingNextActionReviewSchedule;
  }
  if (item.isMaintenanceRequest) {
    if (_isMaintenanceTerminal(item)) {
      return l10n.housekeepingNextActionNoAction;
    }
    return capabilities.canManage
        ? l10n.housekeepingNextActionTriage
        : l10n.housekeepingNextActionView;
  }
  if (!item.isTask || item.isTerminal) {
    return l10n.housekeepingNextActionNoAction;
  }
  final String status = _normalizedStatus(item);
  if (status == 'PENDING' && item.assigneeId == null) {
    return capabilities.canManage
        ? l10n.housekeepingNextActionAssign
        : l10n.housekeepingNextActionView;
  }
  if (status == 'PENDING') {
    return capabilities.canUpdateTasks
        ? l10n.housekeepingNextActionStart
        : l10n.housekeepingNextActionView;
  }
  if (status == 'IN_PROGRESS') {
    return capabilities.canUpdateTasks
        ? l10n.housekeepingNextActionComplete
        : l10n.housekeepingNextActionView;
  }
  return l10n.housekeepingNextActionView;
}

String _locationLabel(AppLocalizations l10n, HousekeepingWorkItem item) {
  final String location = item.locationDisplay.trim();
  return location.isEmpty ? l10n.housekeepingLocationNotSet : location;
}

DateTime? _primaryDate(HousekeepingWorkItem item) {
  return item.scheduledAt ??
      item.startDate ??
      item.reportedAt ??
      item.servicedAt ??
      item.timelineAt;
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.housekeepingNotRecorded
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

IconData _resourceIcon(HousekeepingResource resource) {
  return switch (resource) {
    HousekeepingResource.tasks => Icons.cleaning_services_outlined,
    HousekeepingResource.schedules => Icons.event_repeat_outlined,
    HousekeepingResource.maintenanceRequests => Icons.build_circle_outlined,
  };
}

IconData _queueIcon(HousekeepingQueue queue) {
  return switch (queue) {
    HousekeepingQueue.all => Icons.view_list_outlined,
    HousekeepingQueue.today => Icons.today_outlined,
    HousekeepingQueue.overdueTasks => Icons.warning_amber_outlined,
    HousekeepingQueue.openRequests => Icons.build_circle_outlined,
    HousekeepingQueue.overdueRequests => Icons.report_problem_outlined,
  };
}

List<String> _statusChoicesFor(HousekeepingResource resource) {
  return switch (resource) {
    HousekeepingResource.tasks => housekeepingTaskStatusValues,
    HousekeepingResource.schedules => const <String>[],
    HousekeepingResource.maintenanceRequests =>
      housekeepingMaintenanceStatusValues,
  };
}

HousekeepingQueue? _queueFromFilter(String? value) {
  if (value == null) {
    return null;
  }
  for (final HousekeepingQueue queue in HousekeepingQueue.values) {
    if (queue.name == value) {
      return queue;
    }
  }
  return null;
}

HousekeepingDatePreset? _datePresetFromFilter(String? value) {
  if (value == null) {
    return null;
  }
  for (final HousekeepingDatePreset preset in HousekeepingDatePreset.values) {
    if (preset.name == value) {
      return preset;
    }
  }
  return null;
}

bool _isMaintenanceTerminal(HousekeepingWorkItem item) {
  final String status = _normalizedStatus(item);
  return status == 'COMPLETED' || status == 'CANCELLED';
}

String _normalizedStatus(HousekeepingWorkItem item) {
  return (item.status ?? '').trim().toUpperCase();
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool _notEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

const String _queueFilterKey = 'queue';
const String _statusFilterKey = 'status';
const String _facilityFilterKey = 'facility';
const String _roomFilterKey = 'room';
const String _assigneeFilterKey = 'assignee';
const String _datePresetFilterKey = 'date_preset';
