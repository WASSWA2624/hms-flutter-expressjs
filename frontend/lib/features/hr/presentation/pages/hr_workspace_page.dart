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
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_actions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_overview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

part 'hr_workspace_dialog_actions.dart';

class HrWorkspacePage extends ConsumerWidget {
  const HrWorkspacePage({super.key, this.initialQuery});

  /// Deep-link targeting parsed from the `/hr` route query string.
  final HrWorkspaceQuery? initialQuery;

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
        return _HrWorkspaceContent(state: state, initialQuery: initialQuery);
      },
    );
  }
}

class _HrWorkspaceContent extends ConsumerStatefulWidget {
  const _HrWorkspaceContent({required this.state, this.initialQuery});

  final HrWorkspaceState state;
  final HrWorkspaceQuery? initialQuery;

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

  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.staffQuery.search,
    );
    _staffColumnController =
        AppListTableColumnVisibilityController<HrStaffProfile>();
    _queueColumnController =
        AppListTableColumnVisibilityController<HrWorkItem>();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final HrWorkspaceQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(HrWorkspaceQuery query) async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    final String? focusStaffId = query.focusStaffId?.trim();
    if (focusStaffId != null && focusStaffId.isNotEmpty) {
      final AppFailure? failure = await controller.selectStaffByDisplayId(
        focusStaffId,
      );
      if (!mounted) {
        return;
      }
      if (failure != null) {
        _showMutationResult(context, failure);
        return;
      }
      final HrWorkspaceState? state = _hrStateFromAsync(
        ref.read(hrWorkspaceControllerProvider),
      );
      if (state?.selectedStaff == null) {
        return;
      }
      await showHrStaffDetailDialog(context, ref);
      return;
    }

    final HrQueue? queue = query.queue;
    if (queue != null) {
      await applyHrQueueAndShow(context, ref, queue);
      return;
    }

    final String search = query.search.trim();
    if (search.isNotEmpty) {
      await controller.applyStaffSearch(search);
    }
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
    ref.listen<AsyncValue<Result<HrWorkspaceState>>>(
      hrWorkspaceControllerProvider,
      (AsyncValue<Result<HrWorkspaceState>>? previous,
          AsyncValue<Result<HrWorkspaceState>> next) {
        final HrWorkspaceState? nextState = _hrStateFromAsync(next);
        if (nextState?.openStaffDetailAfterOnboarding != true) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          ref
              .read(hrWorkspaceControllerProvider.notifier)
              .clearOpenStaffDetailAfterOnboarding();
          await showHrStaffDetailDialog(context, ref);
        });
      },
    );

    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState state = widget.state;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return AppWorkspace(
      title: l10n.hrTitle,
      leadingIcon: AppRouteIcons.hr,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: _summaryNotifications(context, state, controller),
        secondary: <Widget>[
          AppButton.secondary(
            label: l10n.hrAddStaffAction,
            leadingIcon: Icons.person_add_outlined,
            semanticLabel: l10n.hrAddStaffAction,
            tooltip: l10n.hrAddStaffDialogTitle,
            onPressed: state.isRefreshing
                ? null
                : () => showHrStaffOnboardingDialog(context, ref),
          ),
          AppButton.secondary(
            label: l10n.hrWorkQueuesTitle,
            leadingIcon: Icons.pending_actions_outlined,
            semanticLabel: l10n.hrWorkQueuesTitle,
            tooltip: l10n.hrWorkQueuesTitle,
            onPressed: state.isRefreshing
                ? null
                : () => showHrWorkQueueDialog(
                    context,
                    ref,
                    columnVisibilityController: _queueColumnController,
                  ),
          ),
          AppButton.secondary(
            label: l10n.hrManageAccessAction,
            leadingIcon: Icons.manage_accounts_outlined,
            semanticLabel: l10n.hrManageAccessAction,
            tooltip: l10n.hrManageAccessAction,
            onPressed: state.isRefreshing
                ? null
                : () => showHrAccessWorkspaceDialog(context, ref),
          ),
          AppButton.secondary(
            label: l10n.hrManageScheduleTemplatesTitle,
            leadingIcon: Icons.view_week_outlined,
            semanticLabel: l10n.hrManageScheduleTemplatesTitle,
            tooltip: l10n.hrManageScheduleTemplatesTitle,
            onPressed: state.isRefreshing
                ? null
                : () => showHrManageScheduleTemplatesDialog(context, ref),
          ),
          AppButton.secondary(
            label: l10n.hrActivityTitle,
            leadingIcon: Icons.timeline_outlined,
            semanticLabel: l10n.hrActivityTitle,
            tooltip: l10n.hrActivityTitle,
            onPressed: state.isRefreshing
                ? null
                : () => _showActivityDialog(context),
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted && failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.failureMessage(failure))),
            );
          }
        },
        isRefreshing: state.isRefreshing,
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
          _HrStaffDirectory(
            state: state,
            searchController: _searchController,
            columnVisibilityController: _staffColumnController,
            onPageChanged: controller.changeStaffPage,
            onStaffSelected: (HrStaffProfile item) {
              unawaited(_openStaffDetailDialog(context, item));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openStaffDetailDialog(
    BuildContext context,
    HrStaffProfile staff,
  ) async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectStaff(staff);
    if (failure != null || !context.mounted) {
      if (context.mounted) {
        _showMutationResult(context, failure ?? AppFailure.validation());
      }
      return;
    }

    await showHrStaffDetailDialog(context, ref);
  }

  Future<void> _showActivityDialog(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.hrActivityTitle),
        icon: const Icon(Icons.timeline_outlined),
        scrollable: true,
        maxWidth: 720,
        content: Consumer(
          builder: (BuildContext context, WidgetRef dialogRef, _) {
            final HrWorkspaceState dialogState =
                _hrStateFromAsync(
                  dialogRef.watch(hrWorkspaceControllerProvider),
                ) ??
                widget.state;
            return _HrActivityPanel(state: dialogState);
          },
        ),
      ),
    );
  }

  List<AppWorkspaceSummaryNotification> _summaryNotifications(
    BuildContext context,
    HrWorkspaceState state,
    HrWorkspaceController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceSummary summary = state.overview.summary;

    return <AppWorkspaceSummaryNotification>[
      AppWorkspaceSummaryNotification(
        label: l10n.hrLeaveRequestsSummaryLabel,
        count: summary.leaveRequests,
        icon: Icons.event_busy_outlined,
        tone: summary.leaveRequests > 0
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.neutral,
        onSelected: () {
          unawaited(applyHrQueueAndShow(context, ref, HrQueue.leaveRequests));
        },
      ),
      AppWorkspaceSummaryNotification(
        label: l10n.hrRosterDraftsSummaryLabel,
        count: summary.draftRosters,
        icon: Icons.calendar_month_outlined,
        onSelected: () {
          unawaited(applyHrQueueAndShow(context, ref, HrQueue.rosterDrafts));
        },
      ),
      AppWorkspaceSummaryNotification(
        label: l10n.hrUnassignedShiftsSummaryLabel,
        count: summary.unassignedShifts,
        icon: Icons.pending_actions_outlined,
        tone: summary.unassignedShifts > 0
            ? AppWorkspaceStatusTone.info
            : AppWorkspaceStatusTone.neutral,
        onSelected: () {
          unawaited(
            applyHrQueueAndShow(context, ref, HrQueue.unassignedShifts),
          );
        },
      ),
      AppWorkspaceSummaryNotification(
        label: l10n.hrPayrollDraftsSummaryLabel,
        count: summary.payrollDraftRuns,
        icon: Icons.payments_outlined,
        onSelected: () {
          unawaited(applyHrQueueAndShow(context, ref, HrQueue.payrollDrafts));
        },
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
    required this.onStaffSelected,
    this.statusFilter,
  });

  final HrWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HrStaffProfile>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<HrStaffProfile> onStaffSelected;
  final String? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final String? normalizedStatusFilter = statusFilter?.trim().toUpperCase();
    final AppPage<HrStaffProfile> staffPage = normalizedStatusFilter == null
        ? state.staff
        : AppPage<HrStaffProfile>(
            items: state.staff.items
                .where(
                  (HrStaffProfile profile) =>
                      (profile.status ?? 'ACTIVE').toUpperCase() ==
                      normalizedStatusFilter,
                )
                .toList(growable: false),
            request: state.staff.request,
            totalItemCount: state.staff.totalItemCount,
          );

    return AppWorkspaceDetailPanel(
      title: l10n.hrStaffDirectoryTitle,
      description: l10n.hrStaffDirectoryDescription,
      child: AppListTable<HrStaffProfile>(
        page: staffPage,
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
        onRowSelected: onStaffSelected,
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
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.hrNoStaffTitle,
          body: l10n.hrNoStaffBody,
        ),
        columns: <AppListTableColumn<HrStaffProfile>>[
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrStaffColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(left.displayName, right.displayName),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return _CopyableIdentifierCell(
                title: item.displayName,
                identifier: item.staffNumber ?? item.displayId,
              );
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrRolePositionColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(
                  left.assignmentLine,
                  right.assignmentLine,
                ),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return _TwoLineCell(
                title: item.position ?? context.l10n.profileUnknownValue,
                subtitle: item.practitionerType == null
                    ? null
                    : _apiLabel(context, item.practitionerType),
              );
            },
          ),
          AppListTableColumn<HrStaffProfile>(
            label: l10n.hrDepartmentColumnLabel,
            sortComparator: (HrStaffProfile left, HrStaffProfile right) =>
                appListTableCompareText(
                  left.departmentName,
                  right.departmentName,
                ),
            cellBuilder: (BuildContext context, HrStaffProfile item) {
              return Text(
                (item.departmentName ?? '').trim().isNotEmpty
                    ? item.departmentName!
                    : context.l10n.profileUnknownValue,
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
              return AppButton.tertiary(
                label: _staffNextAction(context, item),
                onPressed: () => onStaffSelected(item),
              );
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
      title: selected.profile.displayName,
      description: selected.profile.effectiveId,
      actions: <Widget>[
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.edit_outlined,
          label: l10n.hrEditStaffAction,
          semanticLabel: l10n.hrEditStaffAction,
          tooltip: l10n.hrEditStaffAction,
          onPressed: state.isMutating
              ? null
              : () => showHrStaffOnboardingDialog(
                  context,
                  ref,
                  staff: selected.profile,
                ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.isRefreshingDetail)
            const LinearProgressIndicator(minHeight: 2),
          _HrStaffDetailBody(state: state, detail: selected),
        ],
      ),
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
        HrStaffDetailOverview(profile: profile),
        if (detail.accessSummary != null &&
            detail.accessSummary!.userRoles.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _SmallRecordSection(
            title: l10n.hrRolesSectionTitle,
            icon: Icons.admin_panel_settings_outlined,
            emptyText: l10n.hrNoRolesLabel,
            rows: <_RecordLine>[
              for (final HrUserRole role in detail.accessSummary!.userRoles)
                _RecordLine(
                  title:
                      role.roleName ??
                      role.roleId ??
                      l10n.hrRolePositionColumnLabel,
                  subtitle: _joinDisplay(<String?>[
                    role.facilityName,
                    role.facilityDisplayId,
                  ]),
                  trailing: l10n.hrRevokeRoleAction,
                  onTrailingTap: state.isMutating
                      ? null
                      : () async {
                          final HrWorkspaceController controller = ref.read(
                            hrWorkspaceControllerProvider.notifier,
                          );
                          final AppFailure? failure = await controller
                              .revokeUserRole(role);
                          if (context.mounted) {
                            showHrMutationSnackBar(context, failure);
                          }
                        },
                ),
            ],
          ),
        ],
        SizedBox(height: theme.spacing.md),
        HrStaffDetailActions(
          state: state,
          detail: detail,
          onAssignDepartment: _showAssignmentDialog,
          onAssignPosition: _showPositionDialog,
          onRecordAvailability: _showAvailabilityDialog,
          onAssignShift: _showShiftAssignmentDialog,
          onSwapShift: _showShiftSwapDialog,
          onRequestLeave: _showLeaveDialog,
          onCompensation: _showCompensationDialog,
          onRunPayroll: _showPayrollRunDialog,
          onAssignRole: showHrAssignRoleDialog,
          onModuleAccess: (BuildContext context, HrStaffDetail staffDetail) {
            showHrModuleAccessDialog(context, ref, staffDetail.accessSummary);
          },
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
                  assignment.departmentName ?? assignment.departmentDisplayId,
                  assignment.departmentId,
                  if (assignment.isPrimary) l10n.hrPrimaryAssignmentLabel,
                ]).ifEmpty(l10n.hrAssignmentLabel),
                subtitle: _dateRange(
                  context,
                  assignment.startDate,
                  assignment.endDate,
                ),
                trailing: assignment.isActive && !state.isMutating
                    ? l10n.hrEndAssignmentAction
                    : null,
                onTrailingTap: assignment.isActive && !state.isMutating
                    ? () => showHrEndAssignmentDialog(context, ref, assignment)
                    : null,
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
                title: _apiLabel(
                  context,
                  leave.status,
                ).ifEmpty(l10n.hrLeaveLabel),
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
            for (final HrStaffAvailability availability
                in detail.availabilities)
              _RecordLine(
                title: _dayLabel(l10n, availability.dayOfWeek),
                subtitle: _joinDisplay(<String?>[
                  _availabilitySlotSummary(availability),
                  _apiLabel(
                    context,
                    availability.status ?? availability.preference,
                  ),
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
        _SmallRecordSection(
          title: l10n.hrCompensationSectionTitle,
          icon: Icons.price_change_outlined,
          emptyText: l10n.hrNoCompensationLabel,
          rows: <_RecordLine>[
            for (final HrStaffCompensation compensation in detail.compensations)
              _RecordLine(
                title: _joinDisplay(<String?>[
                  _apiLabel(context, compensation.payType),
                  compensation.rate?.toString(),
                  compensation.currency,
                ]).ifEmpty(l10n.hrCompensationLabel),
                subtitle: _dateRange(
                  context,
                  compensation.effectiveFrom,
                  compensation.effectiveTo,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HrWorkQueuePanel extends ConsumerWidget {
  const _HrWorkQueuePanel({
    required this.columnVisibilityController,
    required this.onPageChanged,
  });

  final AppListTableColumnVisibilityController<HrWorkItem>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _HrWorkQueueSwitcherRow(),
        SizedBox(height: Theme.of(context).spacing.md),
        _HrWorkQueueTable(
          columnVisibilityController: columnVisibilityController,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _HrWorkQueueSwitcherRow extends ConsumerWidget {
  const _HrWorkQueueSwitcherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({HrQueue queue, bool isRefreshing}) queueState = ref.watch(
      hrWorkspaceControllerProvider.select((
        AsyncValue<Result<HrWorkspaceState>> async,
      ) {
        final HrWorkspaceState? state = _hrStateFromAsync(async);
        return (
          queue: state?.workItemsQuery.queue ?? HrQueue.leaveRequests,
          isRefreshing: state?.isRefreshingWorkItems ?? false,
        );
      }),
    );

    return HrQueueSwitcher(
      selectedQueue: queueState.queue,
      enabled: !queueState.isRefreshing,
    );
  }
}

class _HrWorkQueueTable extends ConsumerWidget {
  const _HrWorkQueueTable({
    required this.columnVisibilityController,
    required this.onPageChanged,
  });

  final AppListTableColumnVisibilityController<HrWorkItem>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = _hrStateFromAsync(
      ref.watch(hrWorkspaceControllerProvider),
    );
    if (state == null) {
      return const SizedBox.shrink();
    }

    return AppListTable<HrWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshingWorkItems,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemKeyBuilder: (HrWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: (HrWorkItem item) =>
          _showWorkItemDialog(context, ref, item),
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
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrNoQueueItemsTitle,
        body: l10n.hrNoQueueItemsBody,
      ),
      columns: <AppListTableColumn<HrWorkItem>>[
        AppListTableColumn<HrWorkItem>(
          label: l10n.hrQueueItemColumnLabel,
          cellBuilder: (BuildContext context, HrWorkItem item) {
            return _CopyableIdentifierCell(
              title: _workItemTitle(context, item),
              identifier: item.effectiveId,
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

    return AppWorkspaceActivityList(
      description: l10n.hrActivityDescription,
      emptyTitle: l10n.hrNoActivityTitle,
      emptyBody: l10n.hrNoActivityBody,
      items: <AppWorkspaceActivityItem>[
        for (final HrTimelineItem item in items)
          AppWorkspaceActivityItem(
            title: _joinDisplay(<String?>[
              _apiLabel(context, item.type),
              item.id,
            ]).ifEmpty(item.id),
            subtitle: _joinDisplay(<String?>[
              _apiLabel(context, item.action),
              _apiLabel(context, item.status),
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
              for (final _RecordLine row in rows) _RecordLineTile(line: row),
            ],
    );
  }
}

@immutable
final class _RecordLine {
  const _RecordLine({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTrailingTap;
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
            if (line.onTrailingTap != null)
              AppButton.secondary(
                label: line.trailing!,
                onPressed: line.onTrailingTap,
              )
            else
              Flexible(child: Text(line.trailing!)),
          ],
        ],
      ),
    );
  }
}

class _CopyableIdentifierCell extends StatelessWidget {
  const _CopyableIdentifierCell({
    required this.title,
    this.identifier,
    this.subtitle,
  });

  final String title;
  final String? identifier;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if ((identifier ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppCopyableIdentifier(
            value: identifier,
            textStyle: theme.textTheme.bodySmall,
          ),
        ],
        if ((subtitle ?? '').trim().isNotEmpty)
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
        label: _apiLabel(
          context,
          status,
        ).ifEmpty(context.l10n.profileUnknownValue),
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
            child: _CopyableIdentifierCell(
              title: staff.displayName,
              identifier: staff.staffNumber ?? staff.displayId,
              subtitle: _joinDisplay(<String?>[
                staff.position,
                staff.departmentName ?? staff.departmentDisplayId,
              ]),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(_staffNextAction(context, staff), maxLines: 2),
          Semantics(
            label: l10n.hrStaffColumnLabel,
            child: const SizedBox.shrink(),
          ),
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

Future<void> _showPositionDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_PositionFieldsState> fieldsKey =
      GlobalKey<_PositionFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignPositionDialogTitle),
    icon: const Icon(Icons.work_outline),
    submitLabel: l10n.hrAssignPositionAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _PositionFields(
        key: fieldsKey,
        staff: staff,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      );
    },
    onSubmit: () => controller.updateSelectedStaffProfile(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showAssignmentDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_AssignmentFieldsState> fieldsKey =
      GlobalKey<_AssignmentFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignDepartmentDialogTitle),
    icon: const Icon(Icons.account_tree_outlined),
    submitLabel: l10n.hrAssignDepartmentAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _AssignmentFields(
        key: fieldsKey,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      );
    },
    onSubmit: () => controller.createAssignment(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showAvailabilityDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_AvailabilityFieldsState> fieldsKey =
      GlobalKey<_AvailabilityFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAvailabilityDialogTitle),
    icon: const Icon(Icons.schedule_outlined),
    submitLabel: l10n.hrRecordAvailabilityAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _AvailabilityFields(key: fieldsKey);
    },
    onSubmit: () => controller.createAvailability(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showLeaveDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_LeaveFieldsState> fieldsKey = GlobalKey<_LeaveFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrLeaveDialogTitle),
    icon: const Icon(Icons.event_busy_outlined),
    submitLabel: l10n.hrRequestLeaveAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _LeaveFields(key: fieldsKey);
    },
    onSubmit: () => controller.createLeave(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showShiftAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_ShiftAssignmentFieldsState> fieldsKey =
      GlobalKey<_ShiftAssignmentFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignShiftDialogTitle),
    icon: const Icon(Icons.calendar_view_week_outlined),
    submitLabel: l10n.hrAssignShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _ShiftAssignmentFields(
        key: fieldsKey,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      );
    },
    onSubmit: () => controller.createShiftAssignment(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showShiftSwapDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_ShiftSwapFieldsState> fieldsKey =
      GlobalKey<_ShiftSwapFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrSwapShiftDialogTitle),
    icon: const Icon(Icons.swap_horiz_outlined),
    submitLabel: l10n.hrSwapShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _ShiftSwapFields(
        key: fieldsKey,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      );
    },
    onSubmit: () => controller.createShiftSwapRequest(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showPayrollRunDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_PayrollRunFieldsState> fieldsKey =
      GlobalKey<_PayrollRunFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrPayrollRunDialogTitle),
    icon: const Icon(Icons.payments_outlined),
    submitLabel: l10n.hrRunPayrollAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _PayrollRunFields(key: fieldsKey, staff: staff);
    },
    onSubmit: () => controller.createPayrollRun(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showCompensationDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_CompensationFieldsState> fieldsKey =
      GlobalKey<_CompensationFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCompensationDialogTitle),
    icon: const Icon(Icons.price_change_outlined),
    submitLabel: l10n.hrCompensationAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _CompensationFields(key: fieldsKey, staff: staff);
    },
    onSubmit: () => controller.updateSelectedStaffProfile(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showWorkItemDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(_workItemTitle(context, item)),
      icon: Icon(_queueIcon(item.queue)),
      scrollable: true,
      maxWidth: 640,
      content: _WorkItemActions(item: item),
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
              label: l10n.hrQueueItemColumnLabel,
              value: item.effectiveId,
              icon: Icons.confirmation_number_outlined,
              copyable: true,
            ),
            AppInfoTileData(
              label: l10n.hrQueueColumnLabel,
              value: _queueLabel(l10n, item.queue),
              icon: _queueIcon(item.queue),
            ),
            AppInfoTileData(
              label: l10n.hrStatusColumnLabel,
              value: _apiLabel(context, item.status),
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
          label: l10n.hrPreviewRosterAction,
          icon: Icons.visibility_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewRosterDialog(context, ref, item),
        ),
        AppPermissionActionItem(
          requirement: _rosterWriteRequirement,
          label: l10n.hrGenerateRosterAction,
          icon: Icons.auto_awesome_outlined,
          enabled: enabled,
          onPressed: () =>
              _submitSimple(context, controller.generateRoster(item)),
        ),
        AppPermissionActionItem(
          requirement: _rosterPublishRequirement,
          label: l10n.hrPublishRosterAction,
          icon: Icons.publish_outlined,
          enabled: enabled,
          onPressed: () => _showRosterPublishDialog(context, controller, item),
        ),
      ],
      HrQueue.unassignedShifts ||
      HrQueue.overdueShifts => <AppPermissionActionItem>[
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
          label: l10n.hrPreviewPayrollAction,
          icon: Icons.receipt_long_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewPayrollDialog(context, ref, item),
        ),
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
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<_ReasonFieldsState> fieldsKey =
      GlobalKey<_ReasonFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(title),
    icon: const Icon(Icons.notes_outlined),
    submitLabel: submitLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _ReasonFields(key: fieldsKey, requiredReason: requiredReason);
    },
    onSubmit: () => onSubmit(fieldsKey.currentState?.reason),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showRosterPublishDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<_RosterPublishFieldsState> fieldsKey =
      GlobalKey<_RosterPublishFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrPublishRosterDialogTitle),
    icon: const Icon(Icons.publish_outlined),
    submitLabel: l10n.hrPublishRosterAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.publish_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _RosterPublishFields(key: fieldsKey);
    },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.publishRoster(
        item,
        notifyStaff: payload['notify_staff'] == true,
        allowPartialPublish: payload['allow_partial_publish'] == true,
        publishNote: payload['publish_note']?.toString(),
      );
    },
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showOverrideShiftDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_OverrideShiftFieldsState> fieldsKey =
      GlobalKey<_OverrideShiftFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrOverrideShiftDialogTitle),
    icon: const Icon(Icons.manage_accounts_outlined),
    submitLabel: l10n.hrOverrideShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _OverrideShiftFields(
        key: fieldsKey,
        referenceData: state?.referenceData ?? const HrReferenceData(),
      );
    },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.overrideShift(
        item,
        staffProfileId: payload['staff_profile_id']?.toString() ?? '',
        reason: payload['reason']?.toString() ?? '',
      );
    },
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showProcessPayrollDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<_ProcessPayrollFieldsState> fieldsKey =
      GlobalKey<_ProcessPayrollFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrProcessPayrollDialogTitle),
    icon: const Icon(Icons.price_check_outlined),
    submitLabel: l10n.hrProcessPayrollAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.price_check_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return _ProcessPayrollFields(key: fieldsKey);
    },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.processPayrollRun(
        item,
        replaceExistingItems: payload['replace_existing_items'] == true,
        notes: payload['notes']?.toString(),
      );
    },
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
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

class _PositionFields extends StatefulWidget {
  const _PositionFields({
    required this.staff,
    required this.referenceData,
    super.key,
  });

  final HrStaffProfile staff;
  final HrReferenceData referenceData;

  @override
  State<_PositionFields> createState() => _PositionFieldsState();
}

class _PositionFieldsState extends State<_PositionFields> {
  late final TextEditingController _newPositionController;
  String? _position;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _newPositionController = TextEditingController();
    _position = (widget.staff.position ?? '').trim().isEmpty
        ? null
        : widget.staff.position!.trim();
  }

  @override
  void dispose() {
    _newPositionController.dispose();
    super.dispose();
  }

  /// Existing positions keyed by their human name so a selection submits the
  /// position label (the `position` column is a free-text name, not an id).
  List<AppSelectOption<String>> _positionOptions() {
    final Map<String, String> byLabel = <String, String>{};
    for (final HrOption option in widget.referenceData.staffPositions) {
      final String label = option.label.trim().isEmpty
          ? option.value.trim()
          : option.label.trim();
      if (label.isNotEmpty) {
        byLabel[label] = label;
      }
    }
    final String? current = _position;
    if (current != null && current.isNotEmpty) {
      byLabel.putIfAbsent(current, () => current);
    }
    return <AppSelectOption<String>>[
      for (final String label in byLabel.keys)
        AppSelectOption<String>(value: label, label: label),
    ];
  }

  Map<String, Object?> toPayload() {
    final String position = _isAddingNew
        ? _newPositionController.text.trim()
        : (_position ?? '').trim();
    return <String, Object?>{'position': position};
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        if (_isAddingNew)
          AppTextField(
            controller: _newPositionController,
            labelText: l10n.hrNewPositionLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrNewPositionLabel),
            ),
          )
        else
          AppSelectField<String>.searchable(
            value: _position,
            labelText: l10n.hrPositionLabel,
            isRequired: true,
            options: _positionOptions(),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrPositionLabel),
            ),
            onChanged: (String? value) => setState(() => _position = value),
          ),
        AppCheckboxField(
          title: l10n.hrAddNewPositionLabel,
          value: _isAddingNew,
          onChanged: (bool value) => setState(() => _isAddingNew = value),
        ),
      ],
    );
  }
}

class _AssignmentFields extends StatefulWidget {
  const _AssignmentFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<_AssignmentFields> createState() => _AssignmentFieldsState();
}

class _AssignmentFieldsState extends State<_AssignmentFields> {
  final TextEditingController _unitController = TextEditingController();
  String? _departmentId;
  String? _unitId;
  String? _roomId;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'department_id': _departmentId,
      'unit_id': widget.referenceData.units.isEmpty
          ? _unitController.text.trim()
          : _unitId,
      'room_id': _roomId,
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
        if (widget.referenceData.units.isEmpty)
          AppTextField(
            controller: _unitController,
            labelText: l10n.hrUnitIdLabel,
          )
        else
          AppSelectField<String>.searchable(
            value: _unitId,
            labelText: l10n.hrUnitIdLabel,
            options: _scopedOptions(
              widget.referenceData.units,
              departmentId: _departmentId,
            ),
            onChanged: (String? value) => setState(() => _unitId = value),
          ),
        AppSelectField<String>.searchable(
          value: _roomId,
          labelText: l10n.hrRoomLabel,
          options: _scopedOptions(
            widget.referenceData.rooms,
            departmentId: _departmentId,
          ),
          onChanged: (String? value) => setState(() => _roomId = value),
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
      ],
    );
  }
}

class _AvailabilityFields extends StatefulWidget {
  const _AvailabilityFields({super.key});

  @override
  State<_AvailabilityFields> createState() => _AvailabilityFieldsState();
}

class _AvailabilityFieldsState extends State<_AvailabilityFields> {
  final List<_AvailabilitySlotDraft> _slots = <_AvailabilitySlotDraft>[
    _AvailabilitySlotDraft(),
  ];
  int? _dayOfWeek = 1;
  String? _preference = 'AVAILABLE';
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;

  @override
  void dispose() {
    for (final _AvailabilitySlotDraft slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    final List<Map<String, Object?>> slots = <Map<String, Object?>>[
      for (final _AvailabilitySlotDraft slot in _slots)
        if (slot.start.trim().isNotEmpty && slot.end.trim().isNotEmpty)
          <String, Object?>{
            'start_time': slot.start.trim(),
            'end_time': slot.end.trim(),
          },
    ];
    return <String, Object?>{
      'day_of_week': _dayOfWeek,
      'start_time': slots.isEmpty ? null : slots.first['start_time'],
      'end_time': slots.isEmpty ? null : slots.first['end_time'],
      'time_slots': slots,
      'preference': _preference,
      'status': _preference,
      'effective_from': _datePayload(_effectiveFrom),
      'effective_to': _datePayload(_effectiveTo),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppSelectField<int>(
          value: _dayOfWeek,
          labelText: l10n.hrDayOfWeekLabel,
          isRequired: true,
          options: <AppSelectOption<int>>[
            for (var index = 0; index < 7; index += 1)
              AppSelectOption<int>(value: index, label: _dayLabel(l10n, index)),
          ],
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrDayOfWeekLabel),
          ),
          onChanged: (int? value) => setState(() => _dayOfWeek = value),
        ),
        for (var index = 0; index < _slots.length; index += 1)
          _AvailabilitySlotFields(
            slot: _slots[index],
            canRemove: _slots.length > 1,
            onRemove: () {
              setState(() {
                final _AvailabilitySlotDraft removed = _slots.removeAt(index);
                removed.dispose();
              });
            },
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.secondary(
            label: l10n.hrAddAvailabilitySlotAction,
            leadingIcon: Icons.add,
            onPressed: () =>
                setState(() => _slots.add(_AvailabilitySlotDraft())),
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
          onChanged: (DateTime? value) =>
              setState(() => _effectiveFrom = value),
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
      ],
    );
  }
}

final class _AvailabilitySlotDraft {
  _AvailabilitySlotDraft();

  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  String get start => startController.text;
  String get end => endController.text;

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}

class _AvailabilitySlotFields extends StatelessWidget {
  const _AvailabilitySlotFields({
    required this.slot,
    required this.canRemove,
    required this.onRemove,
  });

  final _AvailabilitySlotDraft slot;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AppTextField(
            controller: slot.startController,
            labelText: l10n.hrStartTimeLabel,
            hintText: l10n.hrTimeHint,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrStartTimeLabel),
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: AppTextField(
            controller: slot.endController,
            labelText: l10n.hrEndTimeLabel,
            hintText: l10n.hrTimeHint,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrEndTimeLabel),
            ),
          ),
        ),
        if (canRemove) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.remove_circle_outline,
            label: l10n.hrRemoveAvailabilitySlotAction,
            semanticLabel: l10n.hrRemoveAvailabilitySlotAction,
            tooltip: l10n.hrRemoveAvailabilitySlotAction,
            onPressed: onRemove,
          ),
        ],
      ],
    );
  }
}

class _LeaveFields extends StatefulWidget {
  const _LeaveFields({super.key});

  @override
  State<_LeaveFields> createState() => _LeaveFieldsState();
}

class _LeaveFieldsState extends State<_LeaveFields> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(
    text: '1',
  );
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  /// Inclusive day count between [start] and [end] (1 means same day).
  static int _inclusiveDays(DateTime start, DateTime end) {
    final DateTime from = DateTime(start.year, start.month, start.day);
    final DateTime to = DateTime(end.year, end.month, end.day);
    return to.difference(from).inDays + 1;
  }

  int get _days {
    final int parsed = int.tryParse(_daysController.text.trim()) ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  void _setDaysText(int value) {
    final String text = value.toString();
    if (_daysController.text != text) {
      _daysController.text = text;
    }
  }

  void _onStartChanged(DateTime? value) {
    setState(() {
      _startDate = value;
      if (value != null) {
        // Keep the end date consistent with start + number of days.
        _endDate = DateTime(
          value.year,
          value.month,
          value.day,
        ).add(Duration(days: _days - 1));
      }
    });
  }

  void _onDaysChanged(String _) {
    final DateTime? start = _startDate;
    if (start == null) {
      return;
    }
    setState(() {
      _endDate = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: _days - 1));
    });
  }

  void _onEndChanged(DateTime? value) {
    setState(() {
      _endDate = value;
      final DateTime? start = _startDate;
      if (start != null && value != null) {
        final int days = _inclusiveDays(start, value);
        _setDaysText(days < 1 ? 1 : days);
      }
    });
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
      'reason': _reasonController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
          onChanged: _onStartChanged,
        ),
        AppTextField(
          controller: _daysController,
          labelText: l10n.hrLeaveDaysLabel,
          helperText: l10n.hrLeaveDaysHelper,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: _onDaysChanged,
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
          onChanged: _onEndChanged,
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _ShiftAssignmentFields extends StatefulWidget {
  const _ShiftAssignmentFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<_ShiftAssignmentFields> createState() => _ShiftAssignmentFieldsState();
}

class _ShiftAssignmentFieldsState extends State<_ShiftAssignmentFields> {
  final TextEditingController _shiftController = TextEditingController();
  String? _shiftId;

  @override
  void dispose() {
    _shiftController.dispose();
    super.dispose();
  }

  bool get _hasShiftOptions => widget.referenceData.shiftTemplates.isNotEmpty;

  Map<String, Object?> toPayload() {
    final String shiftId = _hasShiftOptions
        ? (_shiftId ?? '')
        : _shiftController.text.trim();
    return <String, Object?>{
      'shift_id': shiftId,
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        if (_hasShiftOptions)
          AppSelectField<String>.searchable(
            value: _shiftId,
            labelText: l10n.hrSelectShiftLabel,
            hintText: l10n.hrSelectShiftHint,
            isRequired: true,
            options: _selectOptions(widget.referenceData.shiftTemplates),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrSelectShiftLabel),
            ),
            onChanged: (String? value) => setState(() => _shiftId = value),
          )
        else
          AppTextField(
            controller: _shiftController,
            labelText: l10n.hrShiftIdLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrShiftIdLabel),
            ),
          ),
      ],
    );
  }
}

class _ShiftSwapFields extends StatefulWidget {
  const _ShiftSwapFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<_ShiftSwapFields> createState() => _ShiftSwapFieldsState();
}

class _ShiftSwapFieldsState extends State<_ShiftSwapFields> {
  final TextEditingController _shiftController = TextEditingController();
  String? _shiftId;
  String? _targetStaffId;

  @override
  void dispose() {
    _shiftController.dispose();
    super.dispose();
  }

  bool get _hasShiftOptions => widget.referenceData.shiftTemplates.isNotEmpty;

  Map<String, Object?> toPayload() {
    final String shiftId = _hasShiftOptions
        ? (_shiftId ?? '')
        : _shiftController.text.trim();
    return <String, Object?>{
      'shift_id': shiftId,
      'target_staff_id': _targetStaffId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        if (_hasShiftOptions)
          AppSelectField<String>.searchable(
            value: _shiftId,
            labelText: l10n.hrSelectShiftLabel,
            hintText: l10n.hrSelectShiftHint,
            isRequired: true,
            options: _selectOptions(widget.referenceData.shiftTemplates),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrSelectShiftLabel),
            ),
            onChanged: (String? value) => setState(() => _shiftId = value),
          )
        else
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
      ],
    );
  }
}

class _PayrollRunFields extends StatefulWidget {
  const _PayrollRunFields({required this.staff, super.key});

  final HrStaffProfile staff;

  @override
  State<_PayrollRunFields> createState() => _PayrollRunFieldsState();
}

class _PayrollRunFieldsState extends State<_PayrollRunFields> {
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

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'tenant_id': _tenantController.text.trim(),
      'period_start': _datePayload(_periodStart),
      'period_end': _datePayload(_periodEnd),
      'status': 'DRAFT',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
      ],
    );
  }
}

class _CompensationFields extends StatefulWidget {
  const _CompensationFields({required this.staff, super.key});

  final HrStaffProfile staff;

  @override
  State<_CompensationFields> createState() => _CompensationFieldsState();
}

class _CompensationFieldsState extends State<_CompensationFields> {
  late final TextEditingController _currencyController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _monthlyRateController;
  late final TextEditingController _procedureRateController;
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;

  @override
  void initState() {
    super.initState();
    final String currency = widget.staff.compensations.isNotEmpty
        ? widget.staff.compensations.first.currency ?? ''
        : widget.staff.consultationCurrency ?? '';
    _currencyController = TextEditingController(
      text: currency.trim().isEmpty ? 'USD' : currency,
    );
    _hourlyRateController = TextEditingController(
      text:
          _rateFor('PER_HOUR')?.toString() ??
          widget.staff.consultationFee?.toString() ??
          '',
    );
    _monthlyRateController = TextEditingController(
      text: _rateFor('PER_MONTH')?.toString() ?? '',
    );
    _procedureRateController = TextEditingController(
      text: _rateFor('PER_PROCEDURE')?.toString() ?? '',
    );
    if (widget.staff.compensations.isNotEmpty) {
      _effectiveFrom = widget.staff.compensations.first.effectiveFrom;
      _effectiveTo = widget.staff.compensations.first.effectiveTo;
    }
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _hourlyRateController.dispose();
    _monthlyRateController.dispose();
    _procedureRateController.dispose();
    super.dispose();
  }

  num? _rateFor(String payType) {
    for (final HrStaffCompensation compensation in widget.staff.compensations) {
      if ((compensation.payType ?? '').toUpperCase() == payType) {
        return compensation.rate;
      }
    }
    return null;
  }

  Map<String, Object?> toPayload() {
    final String currency = _currencyController.text.trim().toUpperCase();
    final List<Map<String, Object?>> compensations = <Map<String, Object?>>[];
    void addCompensation(String payType, TextEditingController controller) {
      final num? rate = num.tryParse(controller.text.trim());
      if (rate == null) {
        return;
      }
      compensations.add(<String, Object?>{
        'pay_type': payType,
        'rate': rate,
        'currency': currency,
        'effective_from': _datePayload(_effectiveFrom),
        'effective_to': _datePayload(_effectiveTo),
      });
    }

    addCompensation('PER_HOUR', _hourlyRateController);
    addCompensation('PER_MONTH', _monthlyRateController);
    addCompensation('PER_PROCEDURE', _procedureRateController);
    return <String, Object?>{'compensations': compensations};
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: _currencyController,
          labelText: l10n.hrConsultationCurrencyLabel,
          isRequired: true,
          textCapitalization: TextCapitalization.characters,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrConsultationCurrencyLabel),
          ),
        ),
        AppTextField(
          controller: _hourlyRateController,
          labelText: l10n.hrCompensationHourlyRateLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        AppTextField(
          controller: _monthlyRateController,
          labelText: l10n.hrCompensationMonthlyRateLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        AppTextField(
          controller: _procedureRateController,
          labelText: l10n.hrCompensationProcedureRateLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
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
          onChanged: (DateTime? value) =>
              setState(() => _effectiveFrom = value),
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
      ],
    );
  }
}

class _ReasonFields extends StatefulWidget {
  const _ReasonFields({required this.requiredReason, super.key});

  final bool requiredReason;

  @override
  State<_ReasonFields> createState() => _ReasonFieldsState();
}

class _ReasonFieldsState extends State<_ReasonFields> {
  final TextEditingController _reasonController = TextEditingController();

  String get reason => _reasonController.text.trim();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
      ],
    );
  }
}

class _RosterPublishFields extends StatefulWidget {
  const _RosterPublishFields({super.key});

  @override
  State<_RosterPublishFields> createState() => _RosterPublishFieldsState();
}

class _RosterPublishFieldsState extends State<_RosterPublishFields> {
  final TextEditingController _noteController = TextEditingController();
  bool _notifyStaff = true;
  bool _allowPartial = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'notify_staff': _notifyStaff,
      'allow_partial_publish': _allowPartial,
      'publish_note': _noteController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
      ],
    );
  }
}

class _OverrideShiftFields extends StatefulWidget {
  const _OverrideShiftFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<_OverrideShiftFields> createState() => _OverrideShiftFieldsState();
}

class _OverrideShiftFieldsState extends State<_OverrideShiftFields> {
  final TextEditingController _reasonController = TextEditingController();
  String? _staffProfileId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'staff_profile_id': _staffProfileId,
      'reason': _reasonController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
      ],
    );
  }
}

class _ProcessPayrollFields extends StatefulWidget {
  const _ProcessPayrollFields({super.key});

  @override
  State<_ProcessPayrollFields> createState() => _ProcessPayrollFieldsState();
}

class _ProcessPayrollFieldsState extends State<_ProcessPayrollFields> {
  final TextEditingController _notesController = TextEditingController();
  bool _replaceExistingItems = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'replace_existing_items': _replaceExistingItems,
      'notes': _notesController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
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
      ],
    );
  }
}

HrWorkspaceState? _hrStateFromAsync(
  AsyncValue<Result<HrWorkspaceState>> asyncState,
) {
  return asyncState.asData?.value.when(
    success: (HrWorkspaceState state) => state,
    failure: (_) => null,
  );
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

List<AppSelectOption<String>> _scopedOptions(
  List<HrOption> options, {
  String? departmentId,
}) {
  final String selectedDepartment = departmentId?.trim() ?? '';
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      if (selectedDepartment.isEmpty ||
          (option.extra['department_id']?.toString().trim() ?? '').isEmpty ||
          option.extra['department_id'] == selectedDepartment)
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
      if (query.departmentId != null)
        _hrDepartmentFilterKey: query.departmentId!,
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
      item.shiftType == null ? null : _apiLabel(context, item.shiftType),
      item.shiftId,
      item.staffNumber,
    ]).ifEmpty(l10n.hrSwapRequestTitle),
    HrQueue.rosterDrafts => _joinDisplay(<String?>[
      item.periodLabel,
      item.rosterId,
    ]).ifEmpty(l10n.hrRosterDraftTitle),
    HrQueue.unassignedShifts || HrQueue.overdueShifts => _joinDisplay(<String?>[
      item.shiftType == null ? null : _apiLabel(context, item.shiftType),
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
    HrQueue.unassignedShifts ||
    HrQueue.overdueShifts => l10n.hrOverrideShiftAction,
    HrQueue.payrollDrafts => l10n.hrProcessPayrollAction,
  };
}

String _workItemPeriod(BuildContext context, HrWorkItem item) {
  if ((item.periodLabel ?? '').trim().isNotEmpty) {
    return item.periodLabel!;
  }
  return _dateRange(
    context,
    item.startAt,
    item.endAt,
  ).ifEmpty(context.l10n.profileUnknownValue);
}

String _availabilitySlotSummary(HrStaffAvailability availability) {
  if (availability.timeSlots.isNotEmpty) {
    return availability.timeSlots
        .map((HrAvailabilitySlot slot) => '${slot.startTime}-${slot.endTime}')
        .join(', ');
  }
  return _joinDisplay(<String?>[availability.startTime, availability.endTime]);
}

String _queueLabel(AppLocalizations l10n, HrQueue queue) =>
    hrQueueLabel(l10n, queue);

IconData _queueIcon(HrQueue queue) => hrQueueIcon(queue);

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

String _apiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  final AppLocalizations l10n = context.l10n;
  final String practitioner = l10n.hrReferencePractitionerTypeLabel(
    normalized,
    fallback: '',
  );
  if (practitioner.isNotEmpty && practitioner != normalized) {
    return practitioner;
  }
  final String payType = l10n.hrReferenceCompensationPayTypeLabel(
    normalized,
    fallback: '',
  );
  if (payType.isNotEmpty && payType != normalized) {
    return payType;
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
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _dateRange(BuildContext context, DateTime? start, DateTime? end) {
  return _joinDisplay(<String?>[
    _formatDate(context, start),
    _formatDate(context, end),
  ]);
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
