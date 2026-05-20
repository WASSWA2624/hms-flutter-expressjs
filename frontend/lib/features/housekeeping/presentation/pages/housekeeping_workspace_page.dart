import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
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
  const HousekeepingWorkspacePage({super.key});

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
        return _HousekeepingWorkspaceContent(state: state);
      },
    );
  }
}

class _HousekeepingWorkspaceContent extends ConsumerStatefulWidget {
  const _HousekeepingWorkspaceContent({required this.state});

  final HousekeepingWorkspaceState state;

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<HousekeepingWorkItem>();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final HousekeepingWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final _HousekeepingCapabilities capabilities = _capabilities(accessPolicy);
    final controller = ref.read(housekeepingWorkspaceControllerProvider.notifier);
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return AppWorkspace(
      title: l10n.housekeepingTitle,
      leadingIcon: AppRouteIcons.housekeeping,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.housekeepingSavingStatus
            : l10n.housekeepingLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.cleaning_services,
      ),
      primaryAction: AppButton.primary(
        label: l10n.housekeepingCreateTaskAction,
        leadingIcon: Icons.add_task_outlined,
        enabled: capabilities.canManage && !state.isSaving,
        onPressed: capabilities.canManage
            ? () => _showTaskDialog(context, ref, state)
            : null,
      ),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.housekeepingCreateScheduleAction,
          leadingIcon: Icons.event_repeat_outlined,
          enabled: capabilities.canManage && !state.isSaving,
          onPressed: capabilities.canManage
              ? () => _showScheduleDialog(context, ref, state)
              : null,
        ),
        AppButton.secondary(
          label: l10n.housekeepingRequestMaintenanceAction,
          leadingIcon: Icons.build_circle_outlined,
          enabled: capabilities.canUpdateTasks && !state.isSaving,
          onPressed: capabilities.canUpdateTasks
              ? () => _showMaintenanceRequestDialog(context, ref, state)
              : null,
        ),
        AppReportActionButton.preview(
          label: l10n.housekeepingReportSummaryAction,
          enabled: capabilities.canReport,
          onPressed: capabilities.canReport
              ? () => _showReportPreviewDialog(context, state)
              : null,
        ),
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
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
          _HousekeepingWorklistPanel(
            state: state,
            capabilities: capabilities,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _BackendGapPanel(gaps: state.backendGaps),
        ],
      ),
      detail: _HousekeepingDetailPanel(
        state: state,
        capabilities: capabilities,
      ),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    HousekeepingWorkspaceState state,
  ) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final controller = ref.read(housekeepingWorkspaceControllerProvider.notifier);

    return <Widget>[
      AppWorkspaceSummaryCard(
        label: l10n.housekeepingPendingTasksSummaryLabel,
        value: AppFormatters.compactNumber(
          state.overview.summaryValue('pending_tasks'),
          locale,
        ),
        icon: Icons.cleaning_services_outlined,
        tone: AppWorkspaceStatusTone.warning,
        compact: true,
        onPressed: () => controller.applyFilters(
          resource: HousekeepingResource.tasks,
          status: 'PENDING',
          queue: HousekeepingQueue.all,
        ),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.housekeepingCompletedTodaySummaryLabel,
        value: AppFormatters.compactNumber(
          state.overview.summaryValue('completed_today'),
          locale,
        ),
        icon: Icons.task_alt_outlined,
        tone: AppWorkspaceStatusTone.success,
        compact: true,
        onPressed: () => controller.applyFilters(
          resource: HousekeepingResource.tasks,
          status: 'COMPLETED',
          datePreset: HousekeepingDatePreset.today,
          queue: HousekeepingQueue.all,
        ),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.housekeepingOpenRequestsSummaryLabel,
        value: AppFormatters.compactNumber(
          state.overview.summaryValue('open_requests'),
          locale,
        ),
        icon: Icons.build_circle_outlined,
        tone: AppWorkspaceStatusTone.info,
        compact: true,
        onPressed: () => controller.applyFilters(
          resource: HousekeepingResource.maintenanceRequests,
          queue: HousekeepingQueue.openRequests,
        ),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.housekeepingOverdueRequestsSummaryLabel,
        value: AppFormatters.compactNumber(
          state.overview.summaryValue('overdue_requests'),
          locale,
        ),
        icon: Icons.warning_amber_outlined,
        tone: AppWorkspaceStatusTone.error,
        compact: true,
        onPressed: () => controller.applyFilters(
          resource: HousekeepingResource.maintenanceRequests,
          queue: HousekeepingQueue.overdueRequests,
        ),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.housekeepingAssetsSummaryLabel,
        value: AppFormatters.compactNumber(
          state.overview.summaryValue('total_assets'),
          locale,
        ),
        icon: Icons.inventory_2_outlined,
        compact: true,
      ),
    ];
  }
}

class _HousekeepingWorklistPanel extends ConsumerWidget {
  const _HousekeepingWorklistPanel({
    required this.state,
    required this.capabilities,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final HousekeepingWorkspaceState state;
  final _HousekeepingCapabilities capabilities;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HousekeepingWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(housekeepingWorkspaceControllerProvider.notifier);

    return AppWorkspaceDetailPanel(
      title: _resourceLabel(l10n, state.query.resource),
      description: l10n.housekeepingWorklistDescription,
      child: AppListTable<HousekeepingWorkItem>(
        page: state.items,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
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
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          enableDateFilter: false,
          filterGroups: _filterGroups(l10n, state),
          filterValue: _filterValue(state.query),
          hasActiveFilters: _hasActiveFilters(state.query),
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyFilters(
              resource: _resourceFromFilter(value.option(_resourceFilterKey)),
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
        itemKeyBuilder: (HousekeepingWorkItem item) => ValueKey<String>(
          '${item.resource.serverValue}:${item.id}',
        ),
        onRowSelected: controller.selectItem,
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
        emptyBuilder: (BuildContext context) {
          return AppStateView(
            title: l10n.housekeepingEmptyQueueTitle,
            body: l10n.housekeepingEmptyQueueBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<HousekeepingWorkItem>>[
          AppListTableColumn<HousekeepingWorkItem>(
            label: l10n.housekeepingTaskColumnLabel,
            sortComparator:
                (HousekeepingWorkItem left, HousekeepingWorkItem right) {
                  return appListTableCompareText(left.title, right.title);
                },
            cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
              return AppListItemText(
                title: item.title,
                subtitle: item.effectiveDisplayId,
              );
            },
          ),
          AppListTableColumn<HousekeepingWorkItem>(
            label: l10n.housekeepingLocationColumnLabel,
            sortComparator:
                (HousekeepingWorkItem left, HousekeepingWorkItem right) {
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
            sortComparator:
                (HousekeepingWorkItem left, HousekeepingWorkItem right) {
                  return appListTableCompareText(
                    left.assigneeLabel,
                    right.assigneeLabel,
                  );
                },
            cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
              return Text(item.assigneeLabel ?? l10n.housekeepingUnassigned);
            },
          ),
          AppListTableColumn<HousekeepingWorkItem>(
            label: l10n.housekeepingDueColumnLabel,
            sortComparator:
                (HousekeepingWorkItem left, HousekeepingWorkItem right) {
                  return appListTableCompareDateTime(
                    _primaryDate(left),
                    _primaryDate(right),
                  );
                },
            cellBuilder: (BuildContext context, HousekeepingWorkItem item) {
              return Text(_dateTimeLabel(context, _primaryDate(item)));
            },
          ),
          AppListTableColumn<HousekeepingWorkItem>(
            label: l10n.housekeepingStatusColumnLabel,
            sortComparator:
                (HousekeepingWorkItem left, HousekeepingWorkItem right) {
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
        ],
        mobileItemBuilder: (BuildContext context, HousekeepingWorkItem item) {
          return AppListItemRow(
            title: item.title,
            subtitle: _joinDisplay(<String?>[
              item.effectiveDisplayId,
              _locationLabel(l10n, item),
            ]),
            leadingIcon: _resourceIcon(item.resource),
            trailing: _HousekeepingStatusBadge(item: item),
            details: <Widget>[
              AppInlineMetaText(
                icon: Icons.person_outline,
                label: item.assigneeLabel ?? l10n.housekeepingUnassigned,
              ),
              AppInlineMetaText(
                icon: Icons.schedule_outlined,
                label: _dateTimeLabel(context, _primaryDate(item)),
              ),
            ],
          );
        },
      ),
    );
  }
}

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

class _BackendGapPanel extends StatelessWidget {
  const _BackendGapPanel({required this.gaps});

  final List<HousekeepingBackendGap> gaps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppWorkspaceDetailPanel(
      title: l10n.housekeepingBackendGapsTitle,
      description: l10n.housekeepingBackendGapsBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final HousekeepingBackendGap gap in gaps) ...<Widget>[
            AppInfoTile(
              label: gap.title,
              value: gap.body,
              icon: Icons.info_outline,
              maxLines: 4,
            ),
            if (gap != gaps.last) SizedBox(height: theme.spacing.sm),
          ],
        ],
      ),
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
  State<_MaintenanceRequestForm> createState() => _MaintenanceRequestFormState();
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
          options: const <AppSelectOption<String>>[
            AppSelectOption<String>(value: 'OPEN', label: 'Open'),
            AppSelectOption<String>(
              value: 'IN_PROGRESS',
              label: 'In progress',
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

List<AppSearchBarFilterGroup> _filterGroups(
  AppLocalizations l10n,
  HousekeepingWorkspaceState state,
) {
  final HousekeepingLookups lookups = state.overview.lookups;
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _resourceFilterKey,
      label: l10n.housekeepingResourceFilterLabel,
      allLabel: l10n.housekeepingResourceTasks,
      choices: <AppSearchBarFilterChoice>[
        for (final HousekeepingResource resource in HousekeepingResource.values)
          AppSearchBarFilterChoice(
            value: resource.name,
            label: _resourceLabel(l10n, resource),
            icon: _resourceIcon(resource),
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: _queueFilterKey,
      label: l10n.housekeepingQueueFilterLabel,
      allLabel: l10n.housekeepingQueueAll,
      choices: <AppSearchBarFilterChoice>[
        for (final HousekeepingQueue queue in HousekeepingQueue.values)
          if (queue != HousekeepingQueue.all)
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
        for (final String status in _statusChoicesFor(state.query.resource))
          AppSearchBarFilterChoice(
            value: status,
            label: _statusLabelForResource(l10n, state.query.resource, status),
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
      if (query.resource != HousekeepingResource.tasks)
        _resourceFilterKey: query.resource.name,
      if (query.queue != HousekeepingQueue.all) _queueFilterKey: query.queue.name,
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
  return query.resource != HousekeepingResource.tasks ||
      query.queue != HousekeepingQueue.all ||
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

String _resourceLabel(AppLocalizations l10n, HousekeepingResource resource) {
  return switch (resource) {
    HousekeepingResource.tasks => l10n.housekeepingResourceTasks,
    HousekeepingResource.schedules => l10n.housekeepingResourceSchedules,
    HousekeepingResource.maintenanceRequests =>
      l10n.housekeepingResourceMaintenanceRequests,
  };
}

String _queueLabel(AppLocalizations l10n, HousekeepingQueue queue) {
  return switch (queue) {
    HousekeepingQueue.all => l10n.housekeepingQueueAll,
    HousekeepingQueue.today => l10n.housekeepingQueueToday,
    HousekeepingQueue.overdueTasks => l10n.housekeepingQueueOverdueTasks,
    HousekeepingQueue.openRequests => l10n.housekeepingQueueOpenRequests,
    HousekeepingQueue.overdueRequests =>
      l10n.housekeepingQueueOverdueRequests,
  };
}

String _datePresetLabel(
  AppLocalizations l10n,
  HousekeepingDatePreset preset,
) {
  return switch (preset) {
    HousekeepingDatePreset.all => l10n.housekeepingDateAll,
    HousekeepingDatePreset.today => l10n.housekeepingDateToday,
    HousekeepingDatePreset.nextSevenDays => l10n.housekeepingDateNextSevenDays,
    HousekeepingDatePreset.overdue => l10n.housekeepingDateOverdue,
    HousekeepingDatePreset.thisMonth => l10n.housekeepingDateThisMonth,
  };
}

String _statusLabel(AppLocalizations l10n, HousekeepingWorkItem item) {
  return _statusLabelForResource(
    l10n,
    item.resource,
    item.status,
  );
}

String _statusLabelForResource(
  AppLocalizations l10n,
  HousekeepingResource resource,
  String? status,
) {
  return switch (resource) {
    HousekeepingResource.tasks => _taskStatusLabel(l10n, status),
    HousekeepingResource.schedules => l10n.housekeepingStatusScheduled,
    HousekeepingResource.maintenanceRequests =>
      _maintenanceStatusLabel(l10n, status),
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

HousekeepingResource? _resourceFromFilter(String? value) {
  if (value == null) {
    return null;
  }
  for (final HousekeepingResource resource in HousekeepingResource.values) {
    if (resource.name == value) {
      return resource;
    }
  }
  return null;
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

bool _notEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

const String _resourceFilterKey = 'resource';
const String _queueFilterKey = 'queue';
const String _statusFilterKey = 'status';
const String _facilityFilterKey = 'facility';
const String _roomFilterKey = 'room';
const String _assigneeFilterKey = 'assignee';
const String _datePresetFilterKey = 'date_preset';
