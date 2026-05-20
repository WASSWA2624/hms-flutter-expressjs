import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class HrWorkspacePage extends ConsumerWidget {
  const HrWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<HrWorkspaceState>> workspace = ref.watch(
      hrWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<HrWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.hrTitle,
      loadingTitle: l10n.hrLoadingTitle,
      loadingBody: l10n.hrLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(hrWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, HrWorkspaceState state) {
        return _HrWorkspaceContent(state: state);
      },
    );
  }
}

class _HrWorkspaceContent extends ConsumerStatefulWidget {
  const _HrWorkspaceContent({required this.state});

  final HrWorkspaceState state;

  @override
  ConsumerState<_HrWorkspaceContent> createState() =>
      _HrWorkspaceContentState();
}

class _HrWorkspaceContentState extends ConsumerState<_HrWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<HrStaffProfile>
  _staffColumnController;
  late final AppListTableColumnVisibilityController<HrWorkItem>
  _queueColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.staffQuery.search,
    );
    _staffColumnController =
        AppListTableColumnVisibilityController<HrStaffProfile>();
    _queueColumnController = AppListTableColumnVisibilityController<HrWorkItem>();
  }

  @override
  void didUpdateWidget(covariant _HrWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.staffQuery.search;
    if (_searchController.text != search) {
      _searchController.text = search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staffColumnController.dispose();
    _queueColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState state = widget.state;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canCreateStaff = accessPolicy.grants(AppPermissions.hrWrite);
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return AppWorkspace(
      title: l10n.hrTitle,
      leadingIcon: AppRouteIcons.hr,
      status: AppWorkspaceStatus(
        label: state.isMutating ? l10n.hrSavingStatus : l10n.hrLiveStatus,
        tone: state.isMutating
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isMutating ? Icons.sync_outlined : Icons.sensors_outlined,
      ),
      primaryAction: canCreateStaff
          ? AppButton.primary(
              label: l10n.hrAddStaffAction,
              leadingIcon: Icons.person_add_alt_1_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showStaffProfileDialog(context, ref),
            )
          : null,
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      compactSummaryCards: true,
      summaryCards: _summaryCards(context, state, controller),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(failure: lastFailure, onRetry: controller.refresh),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _HrStaffDirectory(
            state: state,
            searchController: _searchController,
            columnVisibilityController: _staffColumnController,
            onPageChanged: controller.changeStaffPage,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _HrWorkQueuePanel(
            state: state,
            columnVisibilityController: _queueColumnController,
            onPageChanged: controller.changeWorkItemsPage,
          ),
        ],
      ),
      detail: _HrStaffDetailPanel(state: state),
      activity: _HrActivityPanel(state: state),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    HrWorkspaceState state,
    HrWorkspaceController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceSummary summary = state.overview.summary;

    return <Widget>[
      AppWorkspaceSummaryCard(
        label: l10n.hrTotalStaffSummaryLabel,
        value: summary.totalStaff.toString(),
        icon: Icons.badge_outlined,
        compact: true,
        onPressed: controller.clearStaffFilters,
      ),
      AppWorkspaceSummaryCard(
        label: l10n.hrLeaveRequestsSummaryLabel,
        value: summary.leaveRequests.toString(),
        icon: Icons.event_busy_outlined,
        tone: summary.leaveRequests > 0
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.neutral,
        compact: true,
        onPressed: () => controller.applyQueue(HrQueue.leaveRequests),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.hrRosterDraftsSummaryLabel,
        value: summary.draftRosters.toString(),
        icon: Icons.calendar_month_outlined,
        compact: true,
        onPressed: () => controller.applyQueue(HrQueue.rosterDrafts),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.hrUnassignedShiftsSummaryLabel,
        value: summary.unassignedShifts.toString(),
        icon: Icons.pending_actions_outlined,
        tone: summary.unassignedShifts > 0
            ? AppWorkspaceStatusTone.info
            : AppWorkspaceStatusTone.neutral,
        compact: true,
        onPressed: () => controller.applyQueue(HrQueue.unassignedShifts),
      ),
      AppWorkspaceSummaryCard(
        label: l10n.hrPayrollDraftsSummaryLabel,
        value: summary.payrollDraftRuns.toString(),
        icon: Icons.payments_outlined,
        compact: true,
        onPressed: () => controller.applyQueue(HrQueue.payrollDrafts),
      ),
    ];
  }
}

class _HrStaffDirectory extends ConsumerWidget {
  const _HrStaffDirectory({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onPageChanged,
  });

  final HrWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HrStaffProfile>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.hrStaffDirectoryTitle,
      description: l10n.hrStaffDirectoryDescription,
      child: AppListTable<HrStaffProfile>(
        page: state.staff,
        isLoading: state.isRefreshingStaff,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<HrStaffProfile>(
          controller: searchController,
          semanticLabel: l10n.hrSearchLabel,
          hintText: l10n.hrSearchHint,
          clearLabel: l10n.hrClearFiltersAction,
          matcher: (_, _) => true,
          onSubmitted: controller.applyStaffSearch,
          onClear: () => controller.applyStaffSearch(''),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.hrFiltersLabel,
          advancedFilterTitle: l10n.hrFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.hrClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          enableDateFilter: false,
          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
          textFilters: <AppSearchBarTextFilter>[
            AppSearchBarTextFilter(
              key: _hrPositionFilterKey,
              label: l10n.hrPositionFilterLabel,
              icon: Icons.work_outline,
              textInputAction: TextInputAction.done,
            ),
          ],
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _hrDepartmentFilterKey,
              label: l10n.hrDepartmentFilterLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: _optionChoices(
                state.referenceData.departments,
                Icons.apartment_outlined,
              ),
            ),
            AppSearchBarFilterGroup(
              key: _hrPractitionerFilterKey,
              label: l10n.hrPractitionerTypeFilterLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: _optionChoices(
                state.referenceData.practitionerTypes,
                Icons.medical_information_outlined,
              ),
            ),
          ],
          filterValue: _staffFilterValue(state.staffQuery),
          hasActiveFilters: _hasStaffFilters(state.staffQuery),
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyStaffFilters(
              departmentId: value.option(_hrDepartmentFilterKey),
              practitionerType: value.option(_hrPractitionerFilterKey),
              position: value.text(_hrPositionFilterKey),
            );
          },
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemKeyBuilder: (HrStaffProfile item) => ValueKey<String>(item.id),
        onRowSelected: (HrStaffProfile item) {
          unawaited(controller.selectStaff(item));
        },
        previousPageLabel: l10n.hrPreviousPageLabel,
        nextPageLabel: l10n.hrNextPageLabel,
        pageLabelBuilder: (AppPage<HrStaffProfile> page) {
          return l10n.hrPageLabel(
            page.firstItemNumber,
            page.lastItemNumber,
            page.totalItemCount ?? page.lastItemNumber,
          );
        },
        onPageChanged: onPageChanged,
        emptyBuilder: (BuildContext context) {
          return AppStateView(
            title: l10n.hrNoStaffTitle,
            body: l10n.hrNoStaffBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<HrStaffProfile>>[
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrStaffColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(left.displayName, right.displayName),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return _TwoLineCell(
                title: item.displayName,
                subtitle: _joinDisplay(<String?>[
                  item.staffNumber,
                  item.displayId,
                ]),
              );
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrRolePositionColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(left.assignmentLine, right.assignmentLine),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return _TwoLineCell(
                title: item.position ?? context.l10n.profileUnknownValue,
                subtitle: item.practitionerType == null
                    ? context.l10n.profileUnknownValue
                    : _apiLabel(item.practitionerType),
              );
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrDepartmentColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(left.departmentName, right.departmentName),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return Text(
                _joinDisplay(<String?>[
                  item.departmentName,
                  item.departmentDisplayId,
                ]).ifEmpty(context.l10n.profileUnknownValue),
              );
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrStatusColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(left.status, right.status),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return _StatusBadge(status: item.status);
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrNextActionColumnLabel,
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return Text(_staffNextAction(context, item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, HrStaffProfile item) {
          return _HrStaffListTile(staff: item);
        },
      ),
    );
  }
}

class _HrStaffDetailPanel extends ConsumerWidget {
  const _HrStaffDetailPanel({required this.state});

  final HrWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrStaffDetail? selected = state.selectedStaff;
    if (selected == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.hrStaffDetailTitle,
        child: AppStateView(
          title: l10n.hrNoStaffSelectedTitle,
          body: l10n.hrNoStaffSelectedBody,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.hrStaffDetailTitle,
      description: selected.profile.effectiveId,
      actions: <Widget>[
        AppIconButton(
          icon: Icons.edit_outlined,
          semanticLabel: l10n.hrEditStaffAction,
          tooltip: l10n.hrEditStaffAction,
          onPressed: state.isMutating
              ? null
              : () => _showStaffProfileDialog(context, ref, selected.profile),
        ),
      ],
      child: state.isRefreshingDetail
          ? const Center(child: CircularProgressIndicator())
          : _HrStaffDetailBody(state: state, detail: selected),
    );
  }
}

class _HrStaffDetailBody extends ConsumerWidget {
  const _HrStaffDetailBody({required this.state, required this.detail});

  final HrWorkspaceState state;
  final HrStaffDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HrStaffProfile profile = detail.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.hrStaffNumberLabel,
              value: profile.staffNumber ?? profile.displayId,
              icon: Icons.badge_outlined,
            ),
            AppInfoTileData(
              label: l10n.hrStaffNameLabel,
              value: profile.displayName,
              icon: Icons.person_outline,
            ),
            AppInfoTileData(
              label: l10n.hrPositionLabel,
              value: profile.position,
              icon: Icons.work_outline,
            ),
            AppInfoTileData(
              label: l10n.hrDepartmentLabel,
              value: profile.departmentName ?? profile.departmentDisplayId,
              icon: Icons.apartment_outlined,
            ),
            AppInfoTileData(
              label: l10n.hrPractitionerTypeLabel,
              value: _apiLabel(profile.practitionerType),
              icon: Icons.medical_information_outlined,
            ),
            AppInfoTileData(
              label: l10n.hrHireDateLabel,
              value: _formatDate(context, profile.hireDate),
              icon: Icons.event_available_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppActionSection(
          title: l10n.hrStaffActionsTitle,
          minItemWidth: 180,
          permissionActions: _staffActions(context, ref, state, detail),
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrAssignmentsSectionTitle,
          icon: Icons.account_tree_outlined,
          emptyText: l10n.hrNoAssignmentsLabel,
          rows: <_RecordLine>[
            for (final HrStaffAssignment assignment in detail.assignments)
              _RecordLine(
                title: _joinDisplay(<String?>[
                  assignment.departmentId,
                  assignment.unitId,
                ]).ifEmpty(l10n.hrAssignmentLabel),
                subtitle: _dateRange(context, assignment.startDate, assignment.endDate),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrLeaveSectionTitle,
          icon: Icons.event_busy_outlined,
          emptyText: l10n.hrNoLeaveLabel,
          rows: <_RecordLine>[
            for (final HrStaffLeave leave in detail.leaves)
              _RecordLine(
                title: _apiLabel(leave.status).ifEmpty(l10n.hrLeaveLabel),
                subtitle: _dateRange(context, leave.startDate, leave.endDate),
                trailing: leave.reason,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrAvailabilitySectionTitle,
          icon: Icons.schedule_outlined,
          emptyText: l10n.hrNoAvailabilityLabel,
          rows: <_RecordLine>[
            for (final HrStaffAvailability availability in detail.availabilities)
              _RecordLine(
                title: _dayLabel(l10n, availability.dayOfWeek),
                subtitle: _joinDisplay(<String?>[
                  availability.startTime,
                  availability.endTime,
                  _apiLabel(availability.preference),
                ]),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrShiftsSectionTitle,
          icon: Icons.calendar_view_week_outlined,
          emptyText: l10n.hrNoShiftsLabel,
          rows: <_RecordLine>[
            for (final HrShiftAssignment assignment in detail.shiftAssignments)
              _RecordLine(
                title: assignment.shiftId ?? l10n.hrShiftLabel,
                subtitle: _formatDateTime(context, assignment.assignedAt),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _HrReportPanel(state: state, detail: detail),
      ],
    );
  }

  List<AppPermissionActionItem> _staffActions(
    BuildContext context,
    WidgetRef ref,
    HrWorkspaceState state,
    HrStaffDetail detail,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = !state.isMutating;
    return <AppPermissionActionItem>[
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrAssignDepartmentAction,
        icon: Icons.account_tree_outlined,
        enabled: enabled,
        onPressed: () => _showAssignmentDialog(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrAssignPositionAction,
        icon: Icons.work_outline,
        enabled: enabled,
        onPressed: () => _showPositionDialog(context, ref, detail.profile),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrRecordAvailabilityAction,
        icon: Icons.schedule_outlined,
        enabled: enabled,
        onPressed: () => _showAvailabilityDialog(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrRequestLeaveAction,
        icon: Icons.event_busy_outlined,
        enabled: enabled,
        onPressed: () => _showLeaveDialog(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrAssignShiftAction,
        icon: Icons.calendar_view_week_outlined,
        enabled: enabled,
        onPressed: () => _showShiftAssignmentDialog(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrSwapShiftAction,
        icon: Icons.swap_horiz_outlined,
        enabled: enabled,
        onPressed: () => _showShiftSwapDialog(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _payrollRequirement,
        label: l10n.hrRunPayrollAction,
        icon: Icons.payments_outlined,
        enabled: enabled,
        onPressed: () => _showPayrollRunDialog(context, ref, detail.profile),
      ),
    ];
  }
}

class _HrWorkQueuePanel extends ConsumerWidget {
  const _HrWorkQueuePanel({
    required this.state,
    required this.columnVisibilityController,
    required this.onPageChanged,
  });

  final HrWorkspaceState state;
  final AppListTableColumnVisibilityController<HrWorkItem>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.hrWorkQueuesTitle,
      description: _queueLabel(l10n, state.workItemsQuery.queue),
      actions: <Widget>[
        AppIconButton(
          icon: Icons.event_busy_outlined,
          semanticLabel: _queueLabel(l10n, HrQueue.leaveRequests),
          tooltip: _queueLabel(l10n, HrQueue.leaveRequests),
          onPressed: state.workItemsQuery.queue == HrQueue.leaveRequests
              ? null
              : () => controller.applyQueue(HrQueue.leaveRequests),
        ),
        AppIconButton(
          icon: Icons.swap_horiz_outlined,
          semanticLabel: _queueLabel(l10n, HrQueue.swapRequests),
          tooltip: _queueLabel(l10n, HrQueue.swapRequests),
          onPressed: state.workItemsQuery.queue == HrQueue.swapRequests
              ? null
              : () => controller.applyQueue(HrQueue.swapRequests),
        ),
        AppIconButton(
          icon: Icons.calendar_month_outlined,
          semanticLabel: _queueLabel(l10n, HrQueue.rosterDrafts),
          tooltip: _queueLabel(l10n, HrQueue.rosterDrafts),
          onPressed: state.workItemsQuery.queue == HrQueue.rosterDrafts
              ? null
              : () => controller.applyQueue(HrQueue.rosterDrafts),
        ),
        AppIconButton(
          icon: Icons.pending_actions_outlined,
          semanticLabel: _queueLabel(l10n, HrQueue.unassignedShifts),
          tooltip: _queueLabel(l10n, HrQueue.unassignedShifts),
          onPressed: state.workItemsQuery.queue == HrQueue.unassignedShifts
              ? null
              : () => controller.applyQueue(HrQueue.unassignedShifts),
        ),
        AppIconButton(
          icon: Icons.payments_outlined,
          semanticLabel: _queueLabel(l10n, HrQueue.payrollDrafts),
          tooltip: _queueLabel(l10n, HrQueue.payrollDrafts),
          onPressed: state.workItemsQuery.queue == HrQueue.payrollDrafts
              ? null
              : () => controller.applyQueue(HrQueue.payrollDrafts),
        ),
      ],
      child: AppListTable<HrWorkItem>(
        page: state.workItems,
        isLoading: state.isRefreshingWorkItems,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemKeyBuilder: (HrWorkItem item) => ValueKey<String>(item.id),
        onRowSelected: (HrWorkItem item) => _showWorkItemDialog(context, ref, item),
        previousPageLabel: l10n.hrPreviousQueuePageLabel,
        nextPageLabel: l10n.hrNextQueuePageLabel,
        pageLabelBuilder: (AppPage<HrWorkItem> page) {
          return l10n.hrPageLabel(
            page.firstItemNumber,
            page.lastItemNumber,
            page.totalItemCount ?? page.lastItemNumber,
          );
        },
        onPageChanged: onPageChanged,
        emptyBuilder: (BuildContext context) {
          return AppStateView(
            title: l10n.hrNoQueueItemsTitle,
            body: l10n.hrNoQueueItemsBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<HrWorkItem>>[
          AppListTableColumn<HrWorkItem>(
            label: l10n.hrQueueItemColumnLabel,
            cellBuilder: (BuildContext context, HrWorkItem item) {
              return _TwoLineCell(
                title: _workItemTitle(context, item),
                subtitle: item.effectiveId,
              );
            },
          ),
          AppListTableColumn<HrWorkItem>(
            label: l10n.hrQueueColumnLabel,
            sortComparator: (HrWorkItem left, HrWorkItem right) =>
                appListTableCompareText(left.queue.value, right.queue.value),
            cellBuilder: (BuildContext context, HrWorkItem item) {
              return Text(_queueLabel(context.l10n, item.queue));
            },
          ),
          AppListTableColumn<HrWorkItem>(
            label: l10n.hrStatusColumnLabel,
            sortComparator: (HrWorkItem left, HrWorkItem right) =>
                appListTableCompareText(left.status, right.status),
            cellBuilder: (BuildContext context, HrWorkItem item) {
              return _StatusBadge(status: item.status);
            },
          ),
          AppListTableColumn<HrWorkItem>(
            label: l10n.hrPeriodColumnLabel,
            sortComparator: (HrWorkItem left, HrWorkItem right) =>
                appListTableCompareDateTime(left.startAt, right.startAt),
            cellBuilder: (BuildContext context, HrWorkItem item) {
              return Text(_workItemPeriod(context, item));
            },
          ),
          AppListTableColumn<HrWorkItem>(
            label: l10n.hrNextActionColumnLabel,
            cellBuilder: (BuildContext context, HrWorkItem item) {
              return Text(_workItemNextAction(context, item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, HrWorkItem item) {
          return _HrWorkItemTile(item: item);
        },
      ),
    );
  }
}

class _HrReportPanel extends StatelessWidget {
  const _HrReportPanel({required this.state, required this.detail});

  final HrWorkspaceState state;
  final HrStaffDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceSummary summary = state.overview.summary;

    return AppSectionPanel(
      title: l10n.hrReportsSectionTitle,
      leadingIcon: Icons.assessment_outlined,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: l10n.hrStaffListReportLabel,
              value: summary.totalStaff.toString(),
              icon: Icons.badge_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.hrLeaveReportLabel,
              value: summary.leaveRequests.toString(),
              icon: Icons.event_busy_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.hrRosterReportLabel,
              value: summary.draftRosters.toString(),
              icon: Icons.calendar_month_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.hrPayrollReportLabel,
              value: summary.payrollDraftRuns.toString(),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        AppReportActionButton.preview(
          label: l10n.hrPreviewStaffProfileReportAction,
          onPressed: () => _showReportPreview(context, detail),
        ),
      ],
    );
  }
}

class _HrActivityPanel extends StatelessWidget {
  const _HrActivityPanel({required this.state});

  final HrWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<HrTimelineItem> items = state.overview.timeline.take(6).toList();

    return AppWorkspaceActivityFeed(
      title: l10n.hrActivityTitle,
      description: l10n.hrActivityDescription,
      emptyTitle: l10n.hrNoActivityTitle,
      emptyBody: l10n.hrNoActivityBody,
      items: <AppWorkspaceActivityItem>[
        for (final HrTimelineItem item in items)
          AppWorkspaceActivityItem(
            title: _joinDisplay(<String?>[
              _apiLabel(item.type),
              item.id,
            ]).ifEmpty(item.id),
            subtitle: _joinDisplay(<String?>[
              _apiLabel(item.action),
              _apiLabel(item.status),
              _formatDateTime(context, item.at),
            ]),
            icon: _activityIcon(item.type),
            tone: _statusTone(item.status),
          ),
      ],
    );
  }
}

class _SmallRecordSection extends StatelessWidget {
  const _SmallRecordSection({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<_RecordLine> rows;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: icon,
      density: AppContentPanelDensity.compact,
      children: rows.isEmpty
          ? <Widget>[Text(emptyText)]
          : <Widget>[
              for (final _RecordLine row in rows)
                _RecordLineTile(line: row),
            ],
    );
  }
}

@immutable
final class _RecordLine {
  const _RecordLine({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final String? trailing;
}

class _RecordLineTile extends StatelessWidget {
  const _RecordLineTile({required this.line});

  final _RecordLine line;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _TwoLineCell(title: line.title, subtitle: line.subtitle),
          ),
          if ((line.trailing ?? '').trim().isNotEmpty) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Flexible(child: Text(line.trailing!)),
          ],
        ],
      ),
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
        if ((subtitle ?? '').trim().isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
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
        label: _apiLabel(status).ifEmpty(context.l10n.profileUnknownValue),
        tone: _statusTone(status),
      ),
    );
  }
}

class _HrStaffListTile extends StatelessWidget {
  const _HrStaffListTile({required this.staff});

  final HrStaffProfile staff;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _TwoLineCell(
              title: staff.displayName,
              subtitle: _joinDisplay(<String?>[
                staff.staffNumber,
                staff.position,
                staff.departmentName ?? staff.departmentDisplayId,
              ]),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(_staffNextAction(context, staff), maxLines: 2),
          Semantics(label: l10n.hrStaffColumnLabel, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _HrWorkItemTile extends StatelessWidget {
  const _HrWorkItemTile({required this.item});

  final HrWorkItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _TwoLineCell(
              title: _workItemTitle(context, item),
              subtitle: _joinDisplay(<String?>[
                _queueLabel(context.l10n, item.queue),
                _workItemPeriod(context, item),
              ]),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          _StatusBadge(status: item.status),
        ],
      ),
    );
  }
}

Future<void> _showStaffProfileDialog(
  BuildContext context,
  WidgetRef ref, [
  HrStaffProfile? staff,
]) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(staff == null ? l10n.hrAddStaffDialogTitle : l10n.hrEditStaffDialogTitle),
      icon: const Icon(Icons.badge_outlined),
      scrollable: true,
      content: _StaffProfileForm(
        staff: staff,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      ),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }

  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = staff == null
      ? await controller.createStaffProfile(payload)
      : await controller.updateSelectedStaffProfile(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showPositionDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrAssignPositionDialogTitle),
      icon: const Icon(Icons.work_outline),
      content: _PositionForm(staff: staff),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .updateSelectedStaffProfile(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showAssignmentDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrAssignDepartmentDialogTitle),
      icon: const Icon(Icons.account_tree_outlined),
      content: _AssignmentForm(
        referenceData: state?.referenceData ?? const HrReferenceData(),
      ),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createAssignment(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showAvailabilityDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrAvailabilityDialogTitle),
      icon: const Icon(Icons.schedule_outlined),
      content: const _AvailabilityForm(),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createAvailability(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showLeaveDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrLeaveDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      content: const _LeaveForm(),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createLeave(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showShiftAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrAssignShiftDialogTitle),
      icon: const Icon(Icons.calendar_view_week_outlined),
      content: const _ShiftAssignmentForm(),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createShiftAssignment(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showShiftSwapDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrSwapShiftDialogTitle),
      icon: const Icon(Icons.swap_horiz_outlined),
      content: _ShiftSwapForm(
        referenceData: state?.referenceData ?? const HrReferenceData(),
      ),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createShiftSwapRequest(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showPayrollRunDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrPayrollRunDialogTitle),
      icon: const Icon(Icons.payments_outlined),
      content: _PayrollRunForm(staff: staff),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .createPayrollRun(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showWorkItemDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(_workItemTitle(context, item)),
      icon: Icon(_queueIcon(item.queue)),
      scrollable: true,
      maxWidth: 640,
      content: _WorkItemActions(item: item),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ),
  );
}

class _WorkItemActions extends ConsumerWidget {
  const _WorkItemActions({required this.item});

  final HrWorkItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = _readHrState(ref);
    final bool enabled = state?.isMutating != true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.hrQueueColumnLabel,
              value: _queueLabel(l10n, item.queue),
              icon: _queueIcon(item.queue),
            ),
            AppInfoTileData(
              label: l10n.hrStatusColumnLabel,
              value: _apiLabel(item.status),
              icon: Icons.radio_button_checked,
            ),
            AppInfoTileData(
              label: l10n.hrPeriodColumnLabel,
              value: _workItemPeriod(context, item),
              icon: Icons.date_range_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppPermissionActionList(
          minItemWidth: 180,
          actions: _workItemActions(context, ref, item, enabled),
        ),
      ],
    );
  }

  List<AppPermissionActionItem> _workItemActions(
    BuildContext context,
    WidgetRef ref,
    HrWorkItem item,
    bool enabled,
  ) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    return switch (item.queue) {
      HrQueue.leaveRequests => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _hrWriteRequirement,
          label: l10n.hrApproveLeaveAction,
          icon: Icons.check_circle_outline,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrApproveLeaveDialogTitle,
            submitLabel: l10n.hrApproveLeaveAction,
            requiredReason: false,
            onSubmit: (String? reason) =>
                controller.approveLeave(item, reason: reason),
          ),
        ),
        AppPermissionActionItem(
          requirement: _hrWriteRequirement,
          label: l10n.hrRejectLeaveAction,
          icon: Icons.cancel_outlined,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrRejectLeaveDialogTitle,
            submitLabel: l10n.hrRejectLeaveAction,
            requiredReason: true,
            onSubmit: (String? reason) =>
                controller.rejectLeave(item, reason: reason ?? ''),
          ),
        ),
      ],
      HrQueue.swapRequests => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _rosterApproveRequirement,
          label: l10n.hrApproveSwapAction,
          icon: Icons.check_circle_outline,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrApproveSwapDialogTitle,
            submitLabel: l10n.hrApproveSwapAction,
            requiredReason: false,
            onSubmit: (String? reason) =>
                controller.approveSwap(item, reason: reason),
          ),
        ),
        AppPermissionActionItem(
          requirement: _rosterApproveRequirement,
          label: l10n.hrRejectSwapAction,
          icon: Icons.cancel_outlined,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrRejectSwapDialogTitle,
            submitLabel: l10n.hrRejectSwapAction,
            requiredReason: true,
            onSubmit: (String? reason) =>
                controller.rejectSwap(item, reason: reason ?? ''),
          ),
        ),
      ],
      HrQueue.rosterDrafts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _rosterWriteRequirement,
          label: l10n.hrGenerateRosterAction,
          icon: Icons.auto_awesome_outlined,
          enabled: enabled,
          onPressed: () => _submitSimple(
            context,
            controller.generateRoster(item),
          ),
        ),
        AppPermissionActionItem(
          requirement: _rosterPublishRequirement,
          label: l10n.hrPublishRosterAction,
          icon: Icons.publish_outlined,
          enabled: enabled,
          onPressed: () => _showRosterPublishDialog(context, controller, item),
        ),
      ],
      HrQueue.unassignedShifts || HrQueue.overdueShifts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _rosterWriteRequirement,
          label: l10n.hrOverrideShiftAction,
          icon: Icons.manage_accounts_outlined,
          enabled: enabled,
          onPressed: () => _showOverrideShiftDialog(context, ref, item),
        ),
      ],
      HrQueue.payrollDrafts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _payrollRequirement,
          label: l10n.hrProcessPayrollAction,
          icon: Icons.price_check_outlined,
          enabled: enabled,
          onPressed: () => _showProcessPayrollDialog(context, controller, item),
        ),
      ],
    };
  }
}

Future<void> _submitReason(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required bool requiredReason,
  required Future<AppFailure?> Function(String? reason) onSubmit,
}) async {
  final String? reason = await showAppDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(title),
      icon: const Icon(Icons.notes_outlined),
      content: _ReasonForm(
        submitLabel: submitLabel,
        requiredReason: requiredReason,
      ),
    ),
  );
  if (reason == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await onSubmit(reason);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showRosterPublishDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrPublishRosterDialogTitle),
      icon: const Icon(Icons.publish_outlined),
      content: const _RosterPublishForm(),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await controller.publishRoster(
    item,
    notifyStaff: payload['notify_staff'] == true,
    allowPartialPublish: payload['allow_partial_publish'] == true,
    publishNote: payload['publish_note']?.toString(),
  );
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showOverrideShiftDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrOverrideShiftDialogTitle),
      icon: const Icon(Icons.manage_accounts_outlined),
      content: _OverrideShiftForm(
        referenceData: state?.referenceData ?? const HrReferenceData(),
      ),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .overrideShift(
        item,
        staffProfileId: payload['staff_profile_id']?.toString() ?? '',
        reason: payload['reason']?.toString() ?? '',
      );
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showProcessPayrollDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(l10n.hrProcessPayrollDialogTitle),
      icon: const Icon(Icons.price_check_outlined),
      content: const _ProcessPayrollForm(),
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await controller.processPayrollRun(
    item,
    replaceExistingItems: payload['replace_existing_items'] == true,
    notes: payload['notes']?.toString(),
  );
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _submitSimple(
  BuildContext context,
  Future<AppFailure?> mutation,
) async {
  final AppFailure? failure = await mutation;
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

void _showReportPreview(BuildContext context, HrStaffDetail detail) {
  final AppLocalizations l10n = context.l10n;
  showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrStaffProfileReportTitle),
      icon: const Icon(Icons.assessment_outlined),
      scrollable: true,
      maxWidth: 720,
      content: AppReportPreviewPanel(
        title: l10n.hrStaffProfileReportTitle,
        selectable: true,
        child: Text(
          _joinDisplay(<String?>[
            detail.profile.displayName,
            detail.profile.staffNumber,
            detail.profile.position,
            detail.profile.departmentName ?? detail.profile.departmentDisplayId,
            _apiLabel(detail.profile.practitionerType),
          ]),
        ),
      ),
    ),
  );
}

class _StaffProfileForm extends StatefulWidget {
  const _StaffProfileForm({required this.referenceData, this.staff});

  final HrReferenceData referenceData;
  final HrStaffProfile? staff;

  @override
  State<_StaffProfileForm> createState() => _StaffProfileFormState();
}

class _StaffProfileFormState extends State<_StaffProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tenantController;
  late final TextEditingController _userController;
  late final TextEditingController _staffNumberController;
  late final TextEditingController _positionController;
  late final TextEditingController _feeController;
  late final TextEditingController _currencyController;
  String? _departmentId;
  String? _practitionerType;
  DateTime? _hireDate;

  bool get _isCreate => widget.staff == null;

  @override
  void initState() {
    super.initState();
    final HrStaffProfile? staff = widget.staff;
    _tenantController = TextEditingController(text: staff?.tenantId);
    _userController = TextEditingController(
      text: staff?.userDisplayId ?? staff?.userId,
    );
    _staffNumberController = TextEditingController(text: staff?.staffNumber);
    _positionController = TextEditingController(text: staff?.position);
    _feeController = TextEditingController(text: staff?.consultationFee?.toString());
    _currencyController = TextEditingController(text: staff?.consultationCurrency);
    _departmentId = staff?.departmentDisplayId ?? staff?.departmentId;
    _practitionerType = staff?.practitionerType;
    _hireDate = staff?.hireDate;
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _userController.dispose();
    _staffNumberController.dispose();
    _positionController.dispose();
    _feeController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        if (_isCreate)
          AppTextField(
            controller: _tenantController,
            labelText: l10n.hrTenantIdLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrTenantIdLabel),
            ),
          ),
        if (_isCreate)
          AppTextField(
            controller: _userController,
            labelText: l10n.hrUserIdLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrUserIdLabel),
            ),
          ),
        AppTextField(
          controller: _staffNumberController,
          labelText: l10n.hrStaffNumberLabel,
        ),
        AppTextField(
          controller: _positionController,
          labelText: l10n.hrPositionLabel,
        ),
        AppSelectField<String>.searchable(
          value: _departmentId,
          labelText: l10n.hrDepartmentLabel,
          options: _selectOptions(widget.referenceData.departments),
          onChanged: (String? value) => setState(() => _departmentId = value),
        ),
        AppSelectField<String>(
          value: _practitionerType,
          labelText: l10n.hrPractitionerTypeLabel,
          options: _selectOptions(widget.referenceData.practitionerTypes),
          onChanged: (String? value) {
            setState(() => _practitionerType = value);
          },
        ),
        AppDateField(
          value: _hireDate,
          labelText: l10n.hrHireDateLabel,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _hireDate = value),
        ),
        AppTextField(
          controller: _feeController,
          labelText: l10n.hrConsultationFeeLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        AppTextField(
          controller: _currencyController,
          labelText: l10n.hrConsultationCurrencyLabel,
          textCapitalization: TextCapitalization.characters,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: _isCreate ? l10n.hrCreateStaffAction : l10n.hrSaveStaffAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              if (_isCreate) 'tenant_id': _tenantController.text.trim(),
              if (_isCreate) 'user_id': _userController.text.trim(),
              'staff_number': _staffNumberController.text.trim(),
              'position': _positionController.text.trim(),
              'department_id': _departmentId,
              'practitioner_type': _practitionerType,
              'hire_date': _datePayload(_hireDate),
              'consultation_fee': num.tryParse(_feeController.text.trim()),
              'consultation_currency': _currencyController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _PositionForm extends StatefulWidget {
  const _PositionForm({required this.staff});

  final HrStaffProfile staff;

  @override
  State<_PositionForm> createState() => _PositionFormState();
}

class _PositionFormState extends State<_PositionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _positionController;

  @override
  void initState() {
    super.initState();
    _positionController = TextEditingController(text: widget.staff.position);
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _positionController,
          labelText: l10n.hrPositionLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrPositionLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrAssignPositionAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'position': _positionController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({required this.referenceData});

  final HrReferenceData referenceData;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _unitController = TextEditingController();
  String? _departmentId;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _departmentId,
          labelText: l10n.hrDepartmentLabel,
          isRequired: true,
          options: _selectOptions(widget.referenceData.departments),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrDepartmentLabel),
          ),
          onChanged: (String? value) => setState(() => _departmentId = value),
        ),
        AppTextField(
          controller: _unitController,
          labelText: l10n.hrUnitIdLabel,
        ),
        AppDateField(
          value: _startDate,
          labelText: l10n.hrStartDateLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _startDate = value),
        ),
        AppDateField(
          value: _endDate,
          labelText: l10n.hrEndDateLabel,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrAssignDepartmentAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'department_id': _departmentId,
              'unit_id': _unitController.text.trim(),
              'start_date': _datePayload(_startDate),
              'end_date': _datePayload(_endDate),
            });
          },
        ),
      ],
    );
  }
}

class _AvailabilityForm extends StatefulWidget {
  const _AvailabilityForm();

  @override
  State<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends State<_AvailabilityForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  int? _dayOfWeek = 1;
  String? _preference = 'AVAILABLE';
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<int>(
          value: _dayOfWeek,
          labelText: l10n.hrDayOfWeekLabel,
          isRequired: true,
          options: <AppSelectOption<int>>[
            for (var index = 0; index < 7; index += 1)
              AppSelectOption<int>(
                value: index,
                label: _dayLabel(l10n, index),
              ),
          ],
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrDayOfWeekLabel),
          ),
          onChanged: (int? value) => setState(() => _dayOfWeek = value),
        ),
        AppTextField(
          controller: _startController,
          labelText: l10n.hrStartTimeLabel,
          hintText: l10n.hrTimeHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrStartTimeLabel),
          ),
        ),
        AppTextField(
          controller: _endController,
          labelText: l10n.hrEndTimeLabel,
          hintText: l10n.hrTimeHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrEndTimeLabel),
          ),
        ),
        AppSelectField<String>(
          value: _preference,
          labelText: l10n.hrAvailabilityPreferenceLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'PREFERRED',
              label: l10n.hrAvailabilityPreferred,
            ),
            AppSelectOption<String>(
              value: 'AVAILABLE',
              label: l10n.hrAvailabilityAvailable,
            ),
            AppSelectOption<String>(
              value: 'UNAVAILABLE',
              label: l10n.hrAvailabilityUnavailable,
            ),
          ],
          onChanged: (String? value) => setState(() => _preference = value),
        ),
        AppDateField(
          value: _effectiveFrom,
          labelText: l10n.hrEffectiveFromLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _effectiveFrom = value),
        ),
        AppDateField(
          value: _effectiveTo,
          labelText: l10n.hrEffectiveToLabel,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _effectiveTo = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrRecordAvailabilityAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'day_of_week': _dayOfWeek,
              'start_time': _startController.text.trim(),
              'end_time': _endController.text.trim(),
              'preference': _preference,
              'effective_from': _datePayload(_effectiveFrom),
              'effective_to': _datePayload(_effectiveTo),
            });
          },
        ),
      ],
    );
  }
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm();

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppDateField(
          value: _startDate,
          labelText: l10n.hrStartDateLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _startDate = value),
        ),
        AppDateField(
          value: _endDate,
          labelText: l10n.hrEndDateLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrRequestLeaveAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'start_date': _datePayload(_startDate),
              'end_date': _datePayload(_endDate),
              'reason': _reasonController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _ShiftAssignmentForm extends StatefulWidget {
  const _ShiftAssignmentForm();

  @override
  State<_ShiftAssignmentForm> createState() => _ShiftAssignmentFormState();
}

class _ShiftAssignmentFormState extends State<_ShiftAssignmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _shiftController = TextEditingController();

  @override
  void dispose() {
    _shiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _shiftController,
          labelText: l10n.hrShiftIdLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrShiftIdLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrAssignShiftAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'shift_id': _shiftController.text.trim(),
              'assigned_at': DateTime.now().toUtc().toIso8601String(),
            });
          },
        ),
      ],
    );
  }
}

class _ShiftSwapForm extends StatefulWidget {
  const _ShiftSwapForm({required this.referenceData});

  final HrReferenceData referenceData;

  @override
  State<_ShiftSwapForm> createState() => _ShiftSwapFormState();
}

class _ShiftSwapFormState extends State<_ShiftSwapForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _shiftController = TextEditingController();
  String? _targetStaffId;

  @override
  void dispose() {
    _shiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _shiftController,
          labelText: l10n.hrShiftIdLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrShiftIdLabel),
          ),
        ),
        AppSelectField<String>.searchable(
          value: _targetStaffId,
          labelText: l10n.hrTargetStaffLabel,
          options: _selectOptions(widget.referenceData.staffProfiles),
          onChanged: (String? value) => setState(() => _targetStaffId = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrSwapShiftAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'shift_id': _shiftController.text.trim(),
              'target_staff_id': _targetStaffId,
            });
          },
        ),
      ],
    );
  }
}

class _PayrollRunForm extends StatefulWidget {
  const _PayrollRunForm({required this.staff});

  final HrStaffProfile staff;

  @override
  State<_PayrollRunForm> createState() => _PayrollRunFormState();
}

class _PayrollRunFormState extends State<_PayrollRunForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tenantController;
  DateTime? _periodStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _periodEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tenantController = TextEditingController(text: widget.staff.tenantId);
  }

  @override
  void dispose() {
    _tenantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _tenantController,
          labelText: l10n.hrTenantIdLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrTenantIdLabel),
          ),
        ),
        AppDateField(
          value: _periodStart,
          labelText: l10n.hrPeriodStartLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _periodStart = value),
        ),
        AppDateField(
          value: _periodEnd,
          labelText: l10n.hrPeriodEndLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _periodEnd = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrRunPayrollAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'tenant_id': _tenantController.text.trim(),
              'period_start': _datePayload(_periodStart),
              'period_end': _datePayload(_periodEnd),
              'status': 'DRAFT',
            });
          },
        ),
      ],
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({
    required this.submitLabel,
    required this.requiredReason,
  });

  final String submitLabel;
  final bool requiredReason;

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
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          isRequired: widget.requiredReason,
          maxLines: 3,
          validator: widget.requiredReason
              ? AppValidators.requiredText(
                  l10n.hrFieldRequiredLabel(l10n.hrReasonLabel),
                )
              : null,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(_reasonController.text.trim());
          },
        ),
      ],
    );
  }
}

class _RosterPublishForm extends StatefulWidget {
  const _RosterPublishForm();

  @override
  State<_RosterPublishForm> createState() => _RosterPublishFormState();
}

class _RosterPublishFormState extends State<_RosterPublishForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();
  bool _notifyStaff = true;
  bool _allowPartial = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppCheckboxField(
          title: l10n.hrNotifyStaffLabel,
          value: _notifyStaff,
          onChanged: (bool value) => setState(() => _notifyStaff = value),
        ),
        AppCheckboxField(
          title: l10n.hrAllowPartialPublishLabel,
          value: _allowPartial,
          onChanged: (bool value) => setState(() => _allowPartial = value),
        ),
        AppTextField(
          controller: _noteController,
          labelText: l10n.hrPublishNoteLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrPublishRosterAction,
          submitIcon: Icons.publish_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'notify_staff': _notifyStaff,
              'allow_partial_publish': _allowPartial,
              'publish_note': _noteController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _OverrideShiftForm extends StatefulWidget {
  const _OverrideShiftForm({required this.referenceData});

  final HrReferenceData referenceData;

  @override
  State<_OverrideShiftForm> createState() => _OverrideShiftFormState();
}

class _OverrideShiftFormState extends State<_OverrideShiftForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  String? _staffProfileId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _staffProfileId,
          labelText: l10n.hrStaffLabel,
          isRequired: true,
          options: _selectOptions(widget.referenceData.staffProfiles),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrStaffLabel),
          ),
          onChanged: (String? value) => setState(() => _staffProfileId = value),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          isRequired: true,
          maxLines: 3,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrReasonLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrOverrideShiftAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'staff_profile_id': _staffProfileId,
              'reason': _reasonController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _ProcessPayrollForm extends StatefulWidget {
  const _ProcessPayrollForm();

  @override
  State<_ProcessPayrollForm> createState() => _ProcessPayrollFormState();
}

class _ProcessPayrollFormState extends State<_ProcessPayrollForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  bool _replaceExistingItems = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppCheckboxField(
          title: l10n.hrReplacePayrollItemsLabel,
          value: _replaceExistingItems,
          onChanged: (bool value) {
            setState(() => _replaceExistingItems = value);
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.hrNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.hrProcessPayrollAction,
          submitIcon: Icons.price_check_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'replace_existing_items': _replaceExistingItems,
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

HrWorkspaceState? _readHrState(WidgetRef ref) {
  return ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState state) => state, failure: (_) => null);
}

List<AppSelectOption<String>> _selectOptions(List<HrOption> options) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(value: option.value, label: option.label),
  ];
}

List<AppSearchBarFilterChoice> _optionChoices(
  List<HrOption> options,
  IconData icon,
) {
  return <AppSearchBarFilterChoice>[
    for (final HrOption option in options)
      AppSearchBarFilterChoice(
        value: option.value,
        label: option.label,
        icon: icon,
      ),
  ];
}

AppSearchBarFilterValue _staffFilterValue(HrStaffQuery query) {
  return AppSearchBarFilterValue(
    texts: <String, String>{
      if (query.position != null) _hrPositionFilterKey: query.position!,
    },
    options: <String, String>{
      if (query.departmentId != null) _hrDepartmentFilterKey: query.departmentId!,
      if (query.practitionerType != null)
        _hrPractitionerFilterKey: query.practitionerType!,
    },
  );
}

bool _hasStaffFilters(HrStaffQuery query) {
  return query.departmentId != null ||
      query.position != null ||
      query.practitionerType != null;
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.hrSavedMessage : l10n.failureMessage(failure),
      ),
    ),
  );
}

String _staffNextAction(BuildContext context, HrStaffProfile staff) {
  final AppLocalizations l10n = context.l10n;
  if ((staff.departmentId ?? staff.departmentDisplayId ?? '').trim().isEmpty) {
    return l10n.hrNextActionAssignDepartment;
  }
  if ((staff.position ?? '').trim().isEmpty) {
    return l10n.hrNextActionAssignPosition;
  }
  return l10n.hrNextActionReviewProfile;
}

String _workItemTitle(BuildContext context, HrWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.queue) {
    HrQueue.leaveRequests => _joinDisplay(<String?>[
      item.staffName,
      item.staffNumber,
      item.reason,
    ]).ifEmpty(l10n.hrLeaveRequestTitle),
    HrQueue.swapRequests => _joinDisplay(<String?>[
      item.shiftType == null ? null : _apiLabel(item.shiftType),
      item.shiftId,
      item.staffNumber,
    ]).ifEmpty(l10n.hrSwapRequestTitle),
    HrQueue.rosterDrafts => _joinDisplay(<String?>[
      item.periodLabel,
      item.rosterId,
    ]).ifEmpty(l10n.hrRosterDraftTitle),
    HrQueue.unassignedShifts || HrQueue.overdueShifts =>
      _joinDisplay(<String?>[
        item.shiftType == null ? null : _apiLabel(item.shiftType),
        item.shiftId,
      ]).ifEmpty(l10n.hrShiftQueueTitle),
    HrQueue.payrollDrafts => _joinDisplay(<String?>[
      item.periodLabel,
      item.payrollRunId ?? item.displayId,
    ]).ifEmpty(l10n.hrPayrollDraftTitle),
  };
}

String _workItemNextAction(BuildContext context, HrWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.queue) {
    HrQueue.leaveRequests => l10n.hrApproveLeaveAction,
    HrQueue.swapRequests => l10n.hrApproveSwapAction,
    HrQueue.rosterDrafts => l10n.hrPublishRosterAction,
    HrQueue.unassignedShifts || HrQueue.overdueShifts =>
      l10n.hrOverrideShiftAction,
    HrQueue.payrollDrafts => l10n.hrProcessPayrollAction,
  };
}

String _workItemPeriod(BuildContext context, HrWorkItem item) {
  if ((item.periodLabel ?? '').trim().isNotEmpty) {
    return item.periodLabel!;
  }
  return _dateRange(context, item.startAt, item.endAt).ifEmpty(
    context.l10n.profileUnknownValue,
  );
}

String _queueLabel(AppLocalizations l10n, HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => l10n.hrQueueLeaveRequests,
    HrQueue.swapRequests => l10n.hrQueueSwapRequests,
    HrQueue.rosterDrafts => l10n.hrQueueRosterDrafts,
    HrQueue.unassignedShifts => l10n.hrQueueUnassignedShifts,
    HrQueue.payrollDrafts => l10n.hrQueuePayrollDrafts,
    HrQueue.overdueShifts => l10n.hrQueueOverdueShifts,
  };
}

IconData _queueIcon(HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => Icons.event_busy_outlined,
    HrQueue.swapRequests => Icons.swap_horiz_outlined,
    HrQueue.rosterDrafts => Icons.calendar_month_outlined,
    HrQueue.unassignedShifts => Icons.pending_actions_outlined,
    HrQueue.payrollDrafts => Icons.payments_outlined,
    HrQueue.overdueShifts => Icons.warning_amber_outlined,
  };
}

IconData _activityIcon(String? type) {
  return switch ((type ?? '').trim().toUpperCase()) {
    'LEAVE' => Icons.event_busy_outlined,
    'SWAP' => Icons.swap_horiz_outlined,
    'ROSTER' => Icons.calendar_month_outlined,
    'PAYROLL' => Icons.payments_outlined,
    'SHIFT' => Icons.calendar_view_week_outlined,
    _ => Icons.history_outlined,
  };
}

String _dayLabel(AppLocalizations l10n, int? day) {
  return switch (day) {
    0 => l10n.hrSundayLabel,
    1 => l10n.hrMondayLabel,
    2 => l10n.hrTuesdayLabel,
    3 => l10n.hrWednesdayLabel,
    4 => l10n.hrThursdayLabel,
    5 => l10n.hrFridayLabel,
    6 => l10n.hrSaturdayLabel,
    _ => l10n.profileUnknownValue,
  };
}

String _apiLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ACTIVE' ||
    'APPROVED' ||
    'COMPLETED' ||
    'PUBLISHED' ||
    'PROCESSED' ||
    'PAID' => AppWorkspaceStatusTone.success,
    'REQUESTED' ||
    'DRAFT' ||
    'SCHEDULED' ||
    'PENDING' => AppWorkspaceStatusTone.warning,
    'REJECTED' ||
    'CANCELLED' ||
    'SUSPENDED' ||
    'INACTIVE' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _formatDate(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.date(value, Localizations.localeOf(context));
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _dateRange(BuildContext context, DateTime? start, DateTime? end) {
  return _joinDisplay(<String?>[_formatDate(context, start), _formatDate(context, end)]);
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day).toUtc().toIso8601String();
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

const String _hrPositionFilterKey = 'position';
const String _hrDepartmentFilterKey = 'department';
const String _hrPractitionerFilterKey = 'practitioner';

const AccessRequirement _hrWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _rosterWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterWrite,
  ],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _rosterApproveRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterApprove,
  ],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _rosterPublishRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterPublish,
  ],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _payrollRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  anyPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>['hr-rosters'],
);

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
