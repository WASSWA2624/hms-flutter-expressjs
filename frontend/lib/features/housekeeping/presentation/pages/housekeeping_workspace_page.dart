import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_access.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/widgets/housekeeping_triage_dialog.dart';
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
    final HousekeepingCapabilities capabilities =
        HousekeepingCapabilities.fromPolicy(accessPolicy);
    final List<HousekeepingSection> visibleSections =
        housekeepingAllowedSections(accessPolicy);
    if (visibleSections.isEmpty) {
      // No authorized sections — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    final bool canShowCurrentSection = visibleSections.contains(_section);
    if (!canShowCurrentSection) {
      final HousekeepingSection fallback =
          housekeepingFallbackSection(accessPolicy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        setState(() => _section = fallback);
        _updateUrlForSection(fallback);
        ref
            .read(housekeepingWorkspaceControllerProvider.notifier)
            .applyResource(fallback.resource);
      });
    }
    final controller = ref.read(
      housekeepingWorkspaceControllerProvider.notifier,
    );
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and table.
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }
    final HousekeepingSection activeSection = canShowCurrentSection
        ? _section
        : visibleSections.first;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final HousekeepingSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: activeSection.name,
              onTabTapped: (String tabId) {
                for (final HousekeepingSection section in visibleSections) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    controller.applyResource(section.resource);
                    break;
                  }
                }
              },
              secondaryActions: <Widget>[
                AppAccessGate(
                  requirement: housekeepingReportRequirement,
                  child: AppReportActionButton.preview(
                    label: l10n.housekeepingReportSummaryAction,
                    onPressed: () => _showReportPreviewDialog(context, state),
                  ),
                ),
              ],
              primaryAction: _primaryActionButton(
                l10n,
                capabilities,
                state,
                activeSection,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (canShowCurrentSection)
              _HousekeepingWorklistPanel(
                state: state,
                section: activeSection,
                capabilities: capabilities,
                searchController: _searchController,
                columnVisibilityController: _tableColumnController,
                onItemSelected: (HousekeepingWorkItem item) {
                  unawaited(
                    _openTaskDetailDialog(context, ref, item, capabilities),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget? _primaryActionButton(
    AppLocalizations l10n,
    HousekeepingCapabilities capabilities,
    HousekeepingWorkspaceState state,
    HousekeepingSection section,
  ) {
    return switch (section) {
      // Tasks: gate via atom map create ∩ (AppAccessActionGate hides when denied).
      HousekeepingSection.tasks => AppAccessActionGate(
          requirement: HousekeepingTasksAtomPermissions.createTask,
          builder: (BuildContext context, bool isAllowed) {
            return AppTabToolbarPrimary(
              label: l10n.housekeepingCreateTaskAction,
              icon: Icons.add_task_outlined,
              enabled: !state.isSaving,
              onPressed: () => _showTaskDialog(context, ref, state),
            );
          },
        ),
      // Schedules: create ∩ operations:write via atom map (not canUpdateTasks).
      HousekeepingSection.schedules => AppAccessActionGate(
          requirement: HousekeepingSchedulesAtomPermissions.createSchedule,
          builder: (BuildContext context, bool isAllowed) {
            return AppTabToolbarPrimary(
              label: l10n.housekeepingCreateScheduleAction,
              icon: Icons.event_repeat_outlined,
              enabled: !state.isSaving,
              onPressed: () => _showScheduleDialog(context, ref, state),
            );
          },
        ),
      // Source inventory: Request maintenance uses canUpdateTasks (manage or
      // housekeeper + read). Matrix create ∩ write is covered by canManage;
      // housekeeper path is intentional source mapping.
      HousekeepingSection.maintenance => capabilities.canUpdateTasks
          ? AppTabToolbarPrimary(
              label: l10n.housekeepingRequestMaintenanceAction,
              icon: Icons.build_circle_outlined,
              enabled: !state.isSaving,
              onPressed: () =>
                  _showMaintenanceRequestDialog(context, ref, state),
            )
          : null,
    };
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

AppTabCountTone _sectionCountTone(HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks ||
    HousekeepingSection.maintenance => AppTabCountTone.warning,
    HousekeepingSection.schedules => AppTabCountTone.info,
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
  final HousekeepingCapabilities capabilities;
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
    final List<AppListTableColumn<HousekeepingWorkItem>> columns =
        _columnsForSection(context, l10n, section, capabilities);
    final List<AppListTableColumn<HousekeepingWorkItem>> columnChoices =
        _columnChoicesForSection(context, l10n, section, capabilities);

    return AppListTable<HousekeepingWorkItem>(
      page: state.items,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'housekeeping_${section.name}',
      columnWidthStorageKey: 'housekeeping_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columns: columns,
      columnChoices: columnChoices,
      search: AppListTableSearch<HousekeepingWorkItem>(
        controller: searchController,
        semanticLabel: l10n.housekeepingSearchLabel,
        hintText: l10n.housekeepingSearchHint,
        clearLabel: l10n.housekeepingClearSearchAction,
        matcher: _housekeepingSearchMatcher(context, section, capabilities),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
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
      mobileItemBuilder: (BuildContext context, HousekeepingWorkItem item) {
        return AppListTableMobileItem(
          title: item.title,
          caption: item.effectiveDisplayId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(l10n, item),
            ),
            switch (section) {
              HousekeepingSection.tasks => AppListTableMobileMeta(
                label: item.assigneeLabel ?? l10n.housekeepingUnassigned,
                icon: Icons.person_outline,
              ),
              HousekeepingSection.schedules => AppListTableMobileMeta(
                label: _locationLabel(l10n, item),
                icon: Icons.meeting_room_outlined,
              ),
              HousekeepingSection.maintenance => AppListTableMobileMeta(
                label: item.assetLabel ?? '',
                icon: Icons.inventory_2_outlined,
              ),
            },
          ],
          showAvatar: false,
          trailing: _HousekeepingNextActionCell(
            item: item,
            capabilities: capabilities,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Per-section columns
// ---------------------------------------------------------------------------

List<AppListTableColumn<HousekeepingWorkItem>> _columnsForSection(
  BuildContext context,
  AppLocalizations l10n,
  HousekeepingSection section,
  HousekeepingCapabilities capabilities,
) {
  switch (section) {
    case HousekeepingSection.tasks:
      return _taskColumns(l10n, capabilities);
    case HousekeepingSection.schedules:
      return _scheduleColumns(l10n, capabilities);
    case HousekeepingSection.maintenance:
      return _maintenanceColumns(l10n, capabilities);
  }
}

List<AppListTableColumn<HousekeepingWorkItem>> _columnChoicesForSection(
  BuildContext context,
  AppLocalizations l10n,
  HousekeepingSection section,
  HousekeepingCapabilities capabilities,
) {
  switch (section) {
    case HousekeepingSection.tasks:
      return <AppListTableColumn<HousekeepingWorkItem>>[
        _housekeepingDueColumn(context, l10n),
      ];
    case HousekeepingSection.schedules:
      return <AppListTableColumn<HousekeepingWorkItem>>[
        _housekeepingStartDateColumn(context, l10n),
        _housekeepingEndDateColumn(context, l10n),
      ];
    case HousekeepingSection.maintenance:
      return <AppListTableColumn<HousekeepingWorkItem>>[
        _housekeepingReportedColumn(context, l10n),
      ];
  }
}

List<AppListTableColumn<HousekeepingWorkItem>> _taskColumns(
  AppLocalizations l10n,
  HousekeepingCapabilities capabilities,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    _housekeepingTaskColumn(l10n),
    _housekeepingLocationColumn(l10n),
    _housekeepingAssigneeColumn(l10n),
    _housekeepingStatusColumn(l10n),
    _housekeepingNextActionColumn(l10n, capabilities),
  ];
}

List<AppListTableColumn<HousekeepingWorkItem>> _scheduleColumns(
  AppLocalizations l10n,
  HousekeepingCapabilities capabilities,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    _housekeepingScheduleColumn(l10n),
    _housekeepingLocationColumn(l10n),
    _housekeepingFrequencyColumn(l10n),
    _housekeepingStatusColumn(l10n),
    _housekeepingNextActionColumn(l10n, capabilities),
  ];
}

List<AppListTableColumn<HousekeepingWorkItem>> _maintenanceColumns(
  AppLocalizations l10n,
  HousekeepingCapabilities capabilities,
) {
  return <AppListTableColumn<HousekeepingWorkItem>>[
    _housekeepingRequestColumn(l10n),
    _housekeepingLocationColumn(l10n),
    _housekeepingAssetColumn(l10n),
    _housekeepingStatusColumn(l10n),
    _housekeepingNextActionColumn(l10n, capabilities),
  ];
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingTaskColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'task',
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
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingScheduleColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'schedule',
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
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingRequestColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'request',
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
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingLocationColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'location',
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
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingAssigneeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'assignee',
    label: l10n.housekeepingAssigneeColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareText(left.assigneeLabel, right.assigneeLabel);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(item.assigneeLabel ?? l10n.housekeepingUnassigned);
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingDueColumn(
  BuildContext context,
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'due',
    label: l10n.housekeepingDueColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareDateTime(left.scheduledAt, right.scheduledAt);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(_dateTimeLabel(context, item.scheduledAt));
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingFrequencyColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'frequency',
    label: l10n.housekeepingFrequencyColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareText(left.subtitle, right.subtitle);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(item.subtitle ?? '');
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingStartDateColumn(
  BuildContext context,
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'start_date',
    label: l10n.housekeepingStartDateColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareDateTime(left.startDate, right.startDate);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(_dateTimeLabel(context, item.startDate));
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingEndDateColumn(
  BuildContext context,
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'end_date',
    label: l10n.housekeepingEndDateColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareDateTime(left.endDate, right.endDate);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(_dateTimeLabel(context, item.endDate));
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingAssetColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'asset',
    label: l10n.housekeepingAssetColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareText(left.assetLabel, right.assetLabel);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(item.assetLabel ?? '');
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingReportedColumn(
  BuildContext context,
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'reported',
    label: l10n.housekeepingReportedColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareDateTime(left.reportedAt, right.reportedAt);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return Text(_dateTimeLabel(context, item.reportedAt));
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'status',
    label: l10n.housekeepingStatusColumnLabel,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareText(left.status, right.status);
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return _HousekeepingStatusBadge(item: item);
    },
  );
}

AppListTableColumn<HousekeepingWorkItem> _housekeepingNextActionColumn(
  AppLocalizations l10n,
  HousekeepingCapabilities capabilities,
) {
  return AppListTableColumn<HousekeepingWorkItem>(
    id: 'next_action',
    label: l10n.housekeepingNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (HousekeepingWorkItem left, HousekeepingWorkItem right) {
      return appListTableCompareText(
        _nextActionLabel(
          l10n,
          _nextActionKind(left, capabilities),
          item: left,
        ),
        _nextActionLabel(
          l10n,
          _nextActionKind(right, capabilities),
          item: right,
        ),
      );
    },
    cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
      return _HousekeepingNextActionCell(
        item: item,
        capabilities: capabilities,
      );
    },
  );
}

class _HousekeepingNextActionCell extends ConsumerWidget {
  const _HousekeepingNextActionCell({
    required this.item,
    required this.capabilities,
  });

  final HousekeepingWorkItem item;
  final HousekeepingCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final _HousekeepingNextActionKind kind = _nextActionKind(
      item,
      capabilities,
    );
    if (kind == _HousekeepingNextActionKind.none) {
      return Text(
        l10n.housekeepingNextActionNoAction,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final String label = _nextActionLabel(l10n, kind, item: item);
    return AppButton.tertiary(
      label: label,
      onPressed: () {
        unawaited(
          _handleHousekeepingNextAction(context, ref, item, capabilities),
        );
      },
    );
  }
}

bool Function(HousekeepingWorkItem, String) _housekeepingSearchMatcher(
  BuildContext context,
  HousekeepingSection section,
  HousekeepingCapabilities capabilities,
) {
  final AppLocalizations l10n = context.l10n;
  return (HousekeepingWorkItem item, String query) {
    return _matchesHousekeepingSearch(
      context,
      item,
      query,
      section,
      l10n,
      capabilities,
    );
  };
}

bool _matchesHousekeepingSearch(
  BuildContext context,
  HousekeepingWorkItem item,
  String query,
  HousekeepingSection section,
  AppLocalizations l10n,
  HousekeepingCapabilities capabilities,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final List<String?> values = <String?>[
    item.title,
    item.effectiveDisplayId,
    item.subtitle,
    item.locationDisplay,
    _locationLabel(l10n, item),
    item.assigneeLabel,
    item.assigneeLabel == null ? l10n.housekeepingUnassigned : null,
    item.assetLabel,
    _dateTimeLabel(context, item.scheduledAt),
    _dateTimeLabel(context, item.startDate),
    _dateTimeLabel(context, item.endDate),
    _dateTimeLabel(context, item.reportedAt),
    _statusLabel(l10n, item),
    _nextActionLabel(l10n, _nextActionKind(item, capabilities), item: item),
  ];

  return values.whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

Future<void> _handleHousekeepingNextAction(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item,
  HousekeepingCapabilities capabilities,
) async {
  final _HousekeepingNextActionKind kind = _nextActionKind(
    item,
    capabilities,
  );
  switch (kind) {
    case _HousekeepingNextActionKind.assign:
      await _showAssignDialog(context, ref, item);
      return;
    case _HousekeepingNextActionKind.start:
      await _mutateHousekeeping(
        context,
        ref,
        () => ref
            .read(housekeepingWorkspaceControllerProvider.notifier)
            .startTask(item),
      );
      return;
    case _HousekeepingNextActionKind.complete:
      await _mutateHousekeeping(
        context,
        ref,
        () => ref
            .read(housekeepingWorkspaceControllerProvider.notifier)
            .completeTask(item),
      );
      return;
    case _HousekeepingNextActionKind.triage:
      await _showTriageDialog(context, ref, item);
      return;
    case _HousekeepingNextActionKind.review:
      await _openTaskDetailDialog(context, ref, item, capabilities);
      return;
    case _HousekeepingNextActionKind.none:
      return;
  }
}

Future<void> _openTaskDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item,
  HousekeepingCapabilities capabilities,
) async {
  ref.read(housekeepingWorkspaceControllerProvider.notifier).selectItem(item);
  await showAppDialog<void>(
    context: context,
    builder: (_) => Consumer(
      builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
        final HousekeepingWorkspaceState? dialogState =
            _housekeepingStateFromAsync(
              dialogRef.watch(housekeepingWorkspaceControllerProvider),
            ) ??
            _readState(dialogRef);
        if (dialogState == null) {
          return const SizedBox.shrink();
        }
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
  final HousekeepingCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HousekeepingWorkItem? item = state.selectedItem;
    if (item == null) {
      return AppCollapsibleSection(
        title: l10n.housekeepingNoSelectionTitle,
        description: l10n.housekeepingNoSelectionBody,
        child: AppStateView(
          title: l10n.housekeepingNoSelectionTitle,
          body: l10n.housekeepingNoSelectionBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    // Sibling titled sections only — never nest Quick actions inside Detail.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DetailActions(
          item: item,
          isSaving: state.isSaving,
          capabilities: capabilities,
        ),
        SizedBox(height: theme.spacing.md),
        ...appCollapsibleSectionSpacing(context, <Widget>[
          AppCollapsibleSection(
            title: l10n.housekeepingDetailTitle,
            description: item.title,
            titleIcon: _resourceIcon(item.resource),
            child: AppInfoTileGrid(
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
                AppInfoTileData(
                  label: l10n.housekeepingStatusColumnLabel,
                  value: _statusLabel(l10n, item),
                  icon: _statusIcon(item),
                ),
                if (item.isMaintenanceRequest && _notEmpty(item.assetLabel))
                  AppInfoTileData(
                    label: l10n.housekeepingAssetColumnLabel,
                    value: item.assetLabel!,
                    icon: Icons.inventory_2_outlined,
                  ),
              ],
            ),
          ),
        ]),
      ],
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
  final HousekeepingCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final _HousekeepingNextActionKind nextKind = _nextActionKind(
      item,
      capabilities,
    );
    final String status = _normalizedStatus(item);
    final List<AppActionItem> actions = <AppActionItem>[
      if (item.isTask &&
          capabilities.canManage &&
          !item.isTerminal &&
          nextKind != _HousekeepingNextActionKind.assign)
        AppActionItem(
          label: l10n.housekeepingAssignAction,
          leadingIcon: Icons.assignment_ind_outlined,
          enabled: !isSaving,
          onPressed: () => _showAssignDialog(context, ref, item),
        ),
      if (item.isTask &&
          capabilities.canUpdateTasks &&
          status == 'PENDING' &&
          nextKind != _HousekeepingNextActionKind.start)
        AppActionItem(
          label: l10n.housekeepingStartAction,
          leadingIcon: Icons.play_arrow_outlined,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: () => unawaited(
            _mutateHousekeeping(
              context,
              ref,
              () => ref
                  .read(housekeepingWorkspaceControllerProvider.notifier)
                  .startTask(item),
            ),
          ),
        ),
      if (item.isTask &&
          capabilities.canUpdateTasks &&
          status == 'IN_PROGRESS' &&
          nextKind != _HousekeepingNextActionKind.complete)
        AppActionItem(
          label: l10n.housekeepingCompleteAction,
          leadingIcon: Icons.task_alt_outlined,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: () => unawaited(
            _mutateHousekeeping(
              context,
              ref,
              () => ref
                  .read(housekeepingWorkspaceControllerProvider.notifier)
                  .completeTask(item),
            ),
          ),
        ),
      if (item.isTask && capabilities.canManage && !item.isTerminal)
        AppActionItem(
          label: l10n.housekeepingCancelAction,
          leadingIcon: Icons.cancel_outlined,
          enabled: !isSaving,
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
      if (item.isMaintenanceRequest &&
          capabilities.canManage &&
          !_isMaintenanceTerminal(item) &&
          nextKind != _HousekeepingNextActionKind.triage)
        AppActionItem(
          label: l10n.housekeepingTriageAction,
          leadingIcon: AppActionIcons.triage,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: () => _showTriageDialog(context, ref, item),
        ),
      if (item.isMaintenanceRequest &&
          capabilities.canManage &&
          !_isMaintenanceTerminal(item))
        AppActionItem(
          label: l10n.housekeepingCompleteRequestAction,
          leadingIcon: Icons.task_alt_outlined,
          enabled: !isSaving,
          onPressed: () => unawaited(
            _mutateHousekeeping(
              context,
              ref,
              () => ref
                  .read(housekeepingWorkspaceControllerProvider.notifier)
                  .completeMaintenanceRequest(item),
            ),
          ),
        ),
      if (item.isMaintenanceRequest &&
          capabilities.canManage &&
          !_isMaintenanceTerminal(item))
        AppActionItem(
          label: l10n.housekeepingCancelRequestAction,
          leadingIcon: Icons.cancel_outlined,
          enabled: !isSaving,
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
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      actions: actions,
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

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
) {
  return showHousekeepingTriageDialog(context, ref, item);
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
    content: AppReportSummaryGrid(
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
  );
}

Future<void> _mutateHousekeeping(
  BuildContext context,
  WidgetRef ref,
  Future<AppFailure?> Function() submit,
) async {
  final AppFailure? failure = await submit();
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
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
  _HousekeepingNextActionKind kind, {
  HousekeepingWorkItem? item,
}) {
  return switch (kind) {
    _HousekeepingNextActionKind.assign => l10n.housekeepingNextActionAssign,
    _HousekeepingNextActionKind.start => l10n.housekeepingNextActionStart,
    _HousekeepingNextActionKind.complete => l10n.housekeepingNextActionComplete,
    _HousekeepingNextActionKind.triage => l10n.housekeepingNextActionTriage,
    _HousekeepingNextActionKind.review => item?.isSchedule == true
        ? l10n.housekeepingNextActionReviewSchedule
        : l10n.housekeepingNextActionView,
    _HousekeepingNextActionKind.none => l10n.housekeepingNextActionNoAction,
  };
}

_HousekeepingNextActionKind _nextActionKind(
  HousekeepingWorkItem item,
  HousekeepingCapabilities capabilities,
) {
  if (item.isSchedule) {
    return _HousekeepingNextActionKind.review;
  }
  if (item.isMaintenanceRequest) {
    if (_isMaintenanceTerminal(item)) {
      return _HousekeepingNextActionKind.none;
    }
    return capabilities.canManage
        ? _HousekeepingNextActionKind.triage
        : _HousekeepingNextActionKind.review;
  }
  if (!item.isTask || item.isTerminal) {
    return _HousekeepingNextActionKind.none;
  }
  final String status = _normalizedStatus(item);
  if (status == 'PENDING' && item.assigneeId == null) {
    return capabilities.canManage
        ? _HousekeepingNextActionKind.assign
        : _HousekeepingNextActionKind.review;
  }
  if (status == 'PENDING') {
    return capabilities.canUpdateTasks
        ? _HousekeepingNextActionKind.start
        : _HousekeepingNextActionKind.review;
  }
  if (status == 'IN_PROGRESS') {
    return capabilities.canUpdateTasks
        ? _HousekeepingNextActionKind.complete
        : _HousekeepingNextActionKind.review;
  }
  return _HousekeepingNextActionKind.review;
}

enum _HousekeepingNextActionKind {
  assign,
  start,
  complete,
  triage,
  review,
  none,
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

bool _notEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

const String _queueFilterKey = 'queue';
const String _statusFilterKey = 'status';
const String _facilityFilterKey = 'facility';
const String _roomFilterKey = 'room';
const String _assigneeFilterKey = 'assignee';
const String _datePresetFilterKey = 'date_preset';
