import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_department_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assignment_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_availability_calendar.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_leave_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_wizard_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_record_availability_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_request_leave_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_shift_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_actions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_offboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
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
  late HrDeskSection _section;

  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _section =
        HrDeskSection.fromQuery(widget.initialQuery?.section ?? '') ??
        HrDeskSection.fromQueue(widget.initialQuery?.queue) ??
        HrDeskSection.staffDirectory;
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
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(HrWorkspaceQuery query) async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    final HrDeskSection? sectionFromRoute =
        HrDeskSection.fromQuery(query.section) ??
        HrDeskSection.fromQueue(query.queue);
    if (sectionFromRoute != null && sectionFromRoute != _section) {
      setState(() => _section = sectionFromRoute);
    }

    final String? focusStaffId = query.focusStaffId?.trim();
    if (focusStaffId != null && focusStaffId.isNotEmpty) {
      setState(() => _section = HrDeskSection.staffDirectory);
      final AppFailure? failure = await controller.selectStaffByDisplayId(
        focusStaffId,
      );
      if (!mounted) {
        return;
      }
      if (failure != null) {
        showHrMutationSnackBar(context, failure);
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
      // Map queue deep-links onto the matching tab and load inline (no dialog).
      final AppFailure? failure = await controller.applyQueue(queue);
      if (!mounted) {
        return;
      }
      if (failure != null) {
        showHrMutationSnackBar(context, failure);
      }
      return;
    }

    if (sectionFromRoute != null) {
      _loadDataForSection(sectionFromRoute);
    }

    final String search = query.search.trim();
    if (search.isNotEmpty) {
      await controller.applyStaffSearch(search);
    }
  }

  void _loadDataForSection(HrDeskSection section) {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final HrQueue? targetQueue = switch (section) {
      HrDeskSection.leaveRequests => HrQueue.leaveRequests,
      HrDeskSection.shiftRoster => HrQueue.rosterDrafts,
      HrDeskSection.payroll => HrQueue.payrollDrafts,
      HrDeskSection.staffDirectory || HrDeskSection.access => null,
    };
    if (targetQueue != null) {
      unawaited(controller.applyQueue(targetQueue));
    }
  }

  void _updateUrlForSection(HrDeskSection section) {
    if (!mounted) {
      return;
    }
    final String tab = section.routeQueryValue;
    final String location = AppRoutes.hr.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
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
      (
        AsyncValue<Result<HrWorkspaceState>>? previous,
        AsyncValue<Result<HrWorkspaceState>> next,
      ) {
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
    final ThemeData theme = Theme.of(context);
    final HrWorkspaceState state = widget.state;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
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
                      for (final HrDeskSection section in HrDeskSection.values)
                        AppTabItem(
                          id: section.name,
                          icon: _sectionIcon(section),
                          label:
                              '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                        ),
                    ],
                    selectedId: _section.name,
                    onTabTapped: (String tabId) {
                      for (final HrDeskSection section
                          in HrDeskSection.values) {
                        if (section.name == tabId) {
                          setState(() => _section = section);
                          _updateUrlForSection(section);
                          _loadDataForSection(section);
                          break;
                        }
                      }
                    },
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                _buildPrimaryActionButton(l10n, state),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            _SecondaryActionsRow(
              state: state,
              controller: controller,
              onActivityPressed: () => _showActivityDialog(context),
            ),
            SizedBox(height: theme.spacing.md),
            if (lastFailure != null) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            _buildTabBody(state, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    AppLocalizations l10n,
    HrWorkspaceState state,
  ) {
    return switch (_section) {
      HrDeskSection.staffDirectory => AppButton.primary(
        label: l10n.hrAddStaffAction,
        leadingIcon: Icons.person_add_outlined,
        onPressed: state.isRefreshing
            ? null
            : () => showHrStaffOnboardingDialog(context, ref),
      ),
      HrDeskSection.leaveRequests => AppButton.primary(
        label: l10n.hrRequestLeaveAction,
        leadingIcon: Icons.event_busy_outlined,
        onPressed: state.isRefreshing
            ? null
            : () => showHrRequestLeaveDialog(context, ref),
      ),
      HrDeskSection.shiftRoster => AppButton.primary(
        label: l10n.hrShiftTemplateAction,
        leadingIcon: Icons.view_week_outlined,
        onPressed: state.isRefreshing
            ? null
            : () => showHrManageScheduleTemplatesDialog(context, ref),
      ),
      HrDeskSection.payroll => AppButton.primary(
        label: l10n.hrRunPayrollAction,
        leadingIcon: Icons.payments_outlined,
        onPressed: state.isRefreshing
            ? null
            : () {
                final HrStaffProfile? staff =
                    state.selectedStaff?.profile ??
                    (state.staff.items.isNotEmpty
                        ? state.staff.items.first
                        : null);
                if (staff == null) {
                  return;
                }
                unawaited(showHrPayrollWizardDialog(context, ref, staff));
              },
      ),
      HrDeskSection.access => AppButton.primary(
        label: l10n.hrManageAccessAction,
        leadingIcon: Icons.manage_accounts_outlined,
        onPressed: state.isRefreshing
            ? null
            : () => showHrAccessWorkspaceDialog(context),
      ),
    };
  }

  Widget _buildTabBody(
    HrWorkspaceState state,
    HrWorkspaceController controller,
  ) {
    return switch (_section) {
      HrDeskSection.staffDirectory => _HrStaffDirectory(
        state: state,
        searchController: _searchController,
        columnVisibilityController: _staffColumnController,
        onPageChanged: controller.changeStaffPage,
        onStaffSelected: (HrStaffProfile item) {
          unawaited(_openStaffDetailDialog(context, item));
        },
      ),
      HrDeskSection.leaveRequests => _HrWorkQueueTable(
        columnVisibilityController: _queueColumnController,
        onPageChanged: controller.changeWorkItemsPage,
      ),
      HrDeskSection.shiftRoster => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _HrWorkQueueSwitcherRow(),
          SizedBox(height: Theme.of(context).spacing.md),
          _HrWorkQueueTable(
            columnVisibilityController: _queueColumnController,
            onPageChanged: controller.changeWorkItemsPage,
          ),
        ],
      ),
      HrDeskSection.payroll => _HrWorkQueueTable(
        columnVisibilityController: _queueColumnController,
        onPageChanged: controller.changeWorkItemsPage,
      ),
      HrDeskSection.access => const HrAccessWorkspacePanel(embedded: true),
    };
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
        showHrMutationSnackBar(context, failure ?? AppFailure.validation());
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
}

class _SecondaryActionsRow extends ConsumerWidget {
  const _SecondaryActionsRow({
    required this.state,
    required this.controller,
    required this.onActivityPressed,
  });

  final HrWorkspaceState state;
  final HrWorkspaceController controller;
  final VoidCallback onActivityPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      spacing: Theme.of(context).spacing.sm,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        AppButton.tertiary(
          label: l10n.hrActivityTitle,
          leadingIcon: Icons.timeline_outlined,
          onPressed: state.isRefreshing ? null : onActivityPressed,
        ),
        AppWorkspaceRefreshAction(
          label: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing
              ? null
              : () {
                  unawaited(
                    controller.refresh().then((AppFailure? failure) {
                      if (context.mounted && failure != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.failureMessage(failure))),
                        );
                      }
                    }),
                  );
                },
        ),
        AppGlobalHousekeepingRequestAction(
          label: l10n.workspaceGlobalHousekeepingRequestAction,
        ),
        AppGlobalFaultReportAction(
          label: l10n.workspaceGlobalFaultReportAction,
        ),
      ],
    );
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

    return AppListTable<HrStaffProfile>(
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
            return AppCopyableIdentifierCell(
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
            final ThemeData theme = Theme.of(context);
            return AppListItemText(
              title: item.position ?? context.l10n.profileUnknownValue,
              subtitle: item.practitionerType == null
                  ? null
                  : _apiLabel(context, item.practitionerType),
              titleStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
          if (selected.profile.isSeparated)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.md),
              child: _HrSeparationBanner(profile: selected.profile),
            ),
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
    final bool hasLinkedUser =
        (profile.userEmail ?? profile.userDisplayId ?? profile.userId ?? '')
            .trim()
            .isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          semanticLabel: l10n.hrStaffDetailTitle,
          patientName: profile.displayName,
          patientNumber: profile.staffNumber ?? profile.effectiveId,
          patientNumberLabel: l10n.hrStaffNumberLabel,
          showAvatar: false,
          persistExpandPreference: false,
          initiallyExpanded: false,
          compactSupportingText: hrJoinDisplay(<String?>[
            profile.position,
            l10n.hrReferencePractitionerTypeLabel(
              profile.practitionerType,
              fallback: profile.practitionerType,
            ),
          ]),
          status: profile.isSeparated
              ? AppWorkspaceStatus(
                  label: _apiLabel(context, profile.status),
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.person_off_outlined,
                )
              : null,
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.hrPositionLabel,
              value: profile.position ?? '',
              icon: Icons.work_outline,
            ),
            AppWorkspacePatientContextField(
              label: l10n.hrPractitionerTypeLabel,
              value: l10n.hrReferencePractitionerTypeLabel(
                profile.practitionerType,
                fallback: profile.practitionerType,
              ),
              icon: Icons.medical_information_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.hrDepartmentLabel,
              value:
                  profile.departmentName ?? profile.departmentDisplayId ?? '',
              icon: Icons.apartment_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.hrHireDateLabel,
              value: profile.hireDate == null
                  ? ''
                  : AppFormatters.mediumDate(
                      profile.hireDate!,
                      Localizations.localeOf(context),
                    ),
              icon: Icons.calendar_today_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.hrStatusLabel,
              value: _apiLabel(context, profile.status),
              icon: Icons.radio_button_checked,
            ),
            AppWorkspacePatientContextField(
              label: l10n.hrConsultationFeeLabel,
              value: profile.consultationFee == null
                  ? ''
                  : '${profile.consultationFee}'
                        '${profile.consultationCurrency != null ? ' ${profile.consultationCurrency}' : ''}',
              icon: Icons.payments_outlined,
            ),
            if (hasLinkedUser) ...<AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.hrEmailLabel,
                value: profile.userEmail ?? '',
                icon: Icons.email_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrUserIdLabel,
                value: profile.userDisplayId ?? profile.userId ?? '',
                icon: Icons.badge_outlined,
                copyable: true,
              ),
            ],
            if (profile.isSeparated) ...<AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.hrSeparationTypeLabel,
                value: hrSeparationTypeLabel(l10n, profile.separationType),
                icon: Icons.person_off_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrLastWorkingDayLabel,
                value: profile.separationDate == null
                    ? ''
                    : AppFormatters.mediumDate(
                        profile.separationDate!,
                        Localizations.localeOf(context),
                      ),
                icon: Icons.event_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrSeparationNotesLabel,
                value: profile.separationNotes ?? '',
                icon: Icons.notes_outlined,
              ),
            ],
            AppWorkspacePatientContextField(
              label: l10n.hrUpdatedAtLabel,
              value: profile.updatedAt == null
                  ? ''
                  : AppFormatters.dateTime(
                      profile.updatedAt!,
                      Localizations.localeOf(context),
                    ),
              icon: Icons.update_outlined,
            ),
          ],
        ),
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
                  title: l10n.hrReferenceRoleLabel(
                    role.roleName,
                    fallback: role.roleName ?? role.roleId,
                  ),
                  subtitle: hrJoinDisplay(<String?>[
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
          onAssignDepartment: showHrAssignDepartmentDialog,
          onAssignPosition: showHrAssignPositionDialog,
          onRecordAvailability: showHrRecordAvailabilityDialog,
          onAssignShift: _showShiftAssignmentDialog,
          onSwapShift: _showShiftSwapDialog,
          onRequestLeave: (BuildContext context, WidgetRef ref) =>
              showHrRequestLeaveDialog(context, ref),
          onCompensation:
              (BuildContext context, WidgetRef ref, HrStaffProfile staff) =>
                  showHrCompensationDialog(
                    context,
                    ref,
                    staff,
                    detail.compensations,
                  ),
          onRunPayroll:
              (BuildContext context, WidgetRef ref, HrStaffProfile staff) =>
                  showHrPayrollWizardDialog(context, ref, staff),
          onAssignRole: showHrAssignRoleDialog,
          onModuleAccess: (BuildContext context, HrStaffDetail staffDetail) {
            showHrModuleAccessDialog(context, ref, staffDetail.accessSummary);
          },
          onOffboardStaff:
              (BuildContext context, WidgetRef ref, HrStaffDetail d) =>
                  showHrStaffOffboardingDialog(
                    context,
                    ref,
                    d,
                    onOpenPayroll: () =>
                        showHrPayrollWizardDialog(context, ref, d.profile),
                  ),
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrAssignmentsSectionTitle,
          icon: Icons.account_tree_outlined,
          emptyText: l10n.hrNoAssignmentsLabel,
          emptyActionLabel: l10n.hrAssignDepartmentAction,
          onEmptyAction: profile.isSeparated || state.isMutating
              ? null
              : () => showHrAssignDepartmentDialog(context, ref),
          rows: <_RecordLine>[
            for (final HrStaffAssignment assignment in detail.assignments)
              _RecordLine(
                title: hrAssignmentTitle(assignment, l10n),
                subtitle: hrAssignmentSubtitle(context, assignment, l10n),
                badges: <AppWorkspaceStatus>[
                  if (assignment.isPrimary) hrPrimaryAssignmentBadge(l10n),
                  hrAssignmentStatusBadge(assignment, l10n),
                ],
                trailing:
                    assignment.isActive &&
                        !state.isMutating &&
                        !profile.isSeparated
                    ? l10n.hrEndAssignmentAction
                    : null,
                showChevron: true,
                onTap: () => showHrAssignmentDetailDialog(
                  context,
                  ref,
                  detail,
                  assignment,
                  isMutating: state.isMutating,
                ),
                onTrailingTap:
                    assignment.isActive &&
                        !state.isMutating &&
                        !profile.isSeparated
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
                title: _leaveSummaryTitle(context, leave),
                subtitle: _leaveSummarySubtitle(context, leave),
                showChevron: true,
                onTap: () => showHrLeaveDetailDialog(context, leave),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.hrAvailabilitySectionTitle,
          leadingIcon: Icons.schedule_outlined,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            HrAvailabilityCalendar(
              availabilities: detail.availabilities,
              leaves: detail.leaves,
              onRecordAvailability: profile.isSeparated || state.isMutating
                  ? null
                  : () => showHrRecordAvailabilityDialog(context, ref),
              onDayTap: (int day) {
                HrStaffAvailability? availability;
                for (final HrStaffAvailability item in detail.availabilities) {
                  if (item.dayOfWeek == day) {
                    availability = item;
                    break;
                  }
                }
                showHrAvailabilityDaySheet(
                  context,
                  dayOfWeek: day,
                  availability: availability,
                  onEdit: () => showHrRecordAvailabilityDialog(context, ref),
                  onAddSlot: () => showHrRecordAvailabilityDialog(context, ref),
                );
              },
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrShiftsSectionTitle,
          icon: Icons.calendar_view_week_outlined,
          emptyText: l10n.hrNoShiftsLabel,
          emptyActionLabel: l10n.hrAssignShiftAction,
          onEmptyAction: profile.isSeparated || state.isMutating
              ? null
              : () => _showShiftAssignmentDialog(context, ref),
          rows: <_RecordLine>[
            for (final HrShiftAssignment assignment in detail.shiftAssignments)
              _RecordLine(
                title: hrShiftAssignmentTitle(
                  assignment,
                  state.referenceData,
                  l10n,
                ),
                subtitle: hrShiftAssignmentSubtitle(context, assignment, l10n),
                showChevron: true,
                onTap: () => showHrShiftDetailDialog(
                  context,
                  assignment,
                  state.referenceData,
                  actionsEnabled: !profile.isSeparated && !state.isMutating,
                  onSwap: () => _showShiftSwapDialog(context, ref),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _SmallRecordSection(
          title: l10n.hrCompensationSectionTitle,
          icon: Icons.price_change_outlined,
          emptyText: l10n.hrNoCompensationLabel,
          emptyActionLabel: l10n.hrCompensationAction,
          onEmptyAction: profile.isSeparated || state.isMutating
              ? null
              : () => showHrCompensationDialog(
                  context,
                  ref,
                  profile,
                  detail.compensations,
                ),
          rows: <_RecordLine>[
            for (final HrStaffCompensation compensation
                in detail.compensations.where(
                  (HrStaffCompensation row) => row.isActive,
                ))
              _RecordLine(
                title: hrCompensationRowTitle(context, compensation),
                subtitle: hrDateRange(
                  context,
                  compensation.effectiveFrom,
                  compensation.effectiveTo,
                ),
                showChevron: true,
                onTap: () => showHrCompensationDetailDialog(
                  context,
                  compensation,
                  () => showHrCompensationDialog(
                    context,
                    ref,
                    profile,
                    detail.compensations,
                    focusPayType: compensation.payType,
                  ),
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
            return AppCopyableIdentifierCell(
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
            return Text(hrQueueLabel(context.l10n, item.queue));
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
            title: hrJoinDisplay(<String?>[
              _apiLabel(context, item.type),
              item.id,
            ]).ifEmpty(item.id),
            subtitle: hrJoinDisplay(<String?>[
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
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<_RecordLine> rows;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppSectionPanel(
      title: title,
      leadingIcon: icon,
      density: AppContentPanelDensity.compact,
      children: rows.isEmpty
          ? <Widget>[
              Text(emptyText),
              if (onEmptyAction != null &&
                  (emptyActionLabel ?? '').trim().isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                AppButton.secondary(
                  label: emptyActionLabel!,
                  onPressed: onEmptyAction,
                ),
              ],
            ]
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
    this.onTap,
    this.badges = const <AppWorkspaceStatus>[],
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;
  final List<AppWorkspaceStatus> badges;
  final bool showChevron;
}

class _RecordLineTile extends StatelessWidget {
  const _RecordLineTile({required this.line});

  final _RecordLine line;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppListItemText(
                  title: line.title,
                  subtitle: line.subtitle,
                  titleStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (line.badges.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      for (final AppWorkspaceStatus badge in line.badges)
                        AppWorkspaceStatusBadge(status: badge),
                    ],
                  ),
                ],
              ],
            ),
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
          if (line.showChevron) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (line.onTap == null) {
      return content;
    }

    return InkWell(
      onTap: line.onTap,
      borderRadius: BorderRadius.circular(theme.radius.sm),
      child: content,
    );
  }
}

class _HrSeparationBanner extends StatelessWidget {
  const _HrSeparationBanner({required this.profile});

  final HrStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String separationType = hrSeparationTypeLabel(
      l10n,
      profile.separationType,
    );
    final String lastDay = profile.separationDate == null
        ? l10n.profileUnknownValue
        : AppFormatters.shortDate(
            profile.separationDate!,
            Localizations.localeOf(context),
          );

    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.person_off_outlined, color: theme.colorScheme.error),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                l10n.hrSeparationBannerMessage(separationType, lastDay),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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
            child: AppCopyableIdentifierCell(
              title: staff.displayName,
              identifier: staff.staffNumber ?? staff.displayId,
              subtitle: hrJoinDisplay(<String?>[
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
            child: AppListItemText(
              title: _workItemTitle(context, item),
              subtitle: hrJoinDisplay(<String?>[
                hrQueueLabel(context.l10n, item.queue),
                _workItemPeriod(context, item),
              ]),
              titleStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          _StatusBadge(status: item.status),
        ],
      ),
    );
  }
}

Future<void> _showShiftAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<HrShiftAssignmentFieldsState> fieldsKey =
      GlobalKey<HrShiftAssignmentFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignShiftDialogTitle),
    icon: const Icon(Icons.calendar_view_week_outlined),
    submitLabel: l10n.hrAssignShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrShiftAssignmentFields(
            key: fieldsKey,
            referenceData: state?.referenceData ?? const HrReferenceData(),
          );
        },
    onSubmit: () => controller.createShiftAssignment(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showShiftSwapDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<HrShiftSwapFieldsState> fieldsKey =
      GlobalKey<HrShiftSwapFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrSwapShiftDialogTitle),
    icon: const Icon(Icons.swap_horiz_outlined),
    submitLabel: l10n.hrSwapShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrShiftSwapFields(
            key: fieldsKey,
            referenceData: state?.referenceData ?? const HrReferenceData(),
          );
        },
    onSubmit: () => controller.createShiftSwapRequest(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
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
      icon: Icon(hrQueueIcon(item.queue)),
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
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
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
              value: hrQueueLabel(l10n, item.queue),
              icon: hrQueueIcon(item.queue),
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
          requirement: hrWriteRequirement,
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
          requirement: hrWriteRequirement,
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
          requirement: hrRosterApproveRequirement,
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
          requirement: hrRosterApproveRequirement,
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
          requirement: hrRosterWriteRequirement,
          label: l10n.hrPreviewRosterAction,
          icon: Icons.visibility_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewRosterDialog(context, ref, item),
        ),
        AppPermissionActionItem(
          requirement: hrRosterWriteRequirement,
          label: l10n.hrGenerateRosterAction,
          icon: Icons.auto_awesome_outlined,
          enabled: enabled,
          onPressed: () =>
              _submitSimple(context, controller.generateRoster(item)),
        ),
        AppPermissionActionItem(
          requirement: hrRosterPublishRequirement,
          label: l10n.hrPublishRosterAction,
          icon: Icons.publish_outlined,
          enabled: enabled,
          onPressed: () => _showRosterPublishDialog(context, controller, item),
        ),
      ],
      HrQueue.unassignedShifts ||
      HrQueue.overdueShifts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: hrRosterWriteRequirement,
          label: l10n.hrOverrideShiftAction,
          icon: Icons.manage_accounts_outlined,
          enabled: enabled,
          onPressed: () => _showOverrideShiftDialog(context, ref, item),
        ),
      ],
      HrQueue.payrollDrafts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: hrPayrollRequirement,
          label: l10n.hrPreviewPayrollAction,
          icon: Icons.receipt_long_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewPayrollDialog(context, ref, item),
        ),
        AppPermissionActionItem(
          requirement: hrPayrollRequirement,
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
  final GlobalKey<HrReasonFieldsState> fieldsKey =
      GlobalKey<HrReasonFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(title),
    icon: const Icon(Icons.notes_outlined),
    submitLabel: submitLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrReasonFields(key: fieldsKey, requiredReason: requiredReason);
        },
    onSubmit: () => onSubmit(fieldsKey.currentState?.reason),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showRosterPublishDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<HrRosterPublishFieldsState> fieldsKey =
      GlobalKey<HrRosterPublishFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrPublishRosterDialogTitle),
    icon: const Icon(Icons.publish_outlined),
    submitLabel: l10n.hrPublishRosterAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.publish_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrRosterPublishFields(key: fieldsKey);
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
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showOverrideShiftDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<HrOverrideShiftFieldsState> fieldsKey =
      GlobalKey<HrOverrideShiftFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrOverrideShiftDialogTitle),
    icon: const Icon(Icons.manage_accounts_outlined),
    submitLabel: l10n.hrOverrideShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrOverrideShiftFields(
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
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showProcessPayrollDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<HrProcessPayrollFieldsState> fieldsKey =
      GlobalKey<HrProcessPayrollFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrProcessPayrollDialogTitle),
    icon: const Icon(Icons.price_check_outlined),
    submitLabel: l10n.hrProcessPayrollAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.price_check_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrProcessPayrollFields(key: fieldsKey);
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
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _submitSimple(
  BuildContext context,
  Future<AppFailure?> mutation,
) async {
  final AppFailure? failure = await mutation;
  if (context.mounted) {
    showHrMutationSnackBar(context, failure);
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

String _sectionLabel(AppLocalizations l10n, HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => l10n.hrTitle,
    HrDeskSection.leaveRequests => l10n.hrLeaveRequestsSummaryLabel,
    HrDeskSection.shiftRoster => l10n.hrShiftsSectionTitle,
    HrDeskSection.payroll => l10n.hrPayrollDraftsSummaryLabel,
    HrDeskSection.access => l10n.hrManageAccessAction,
  };
}

IconData _sectionIcon(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => Icons.people_outlined,
    HrDeskSection.leaveRequests => Icons.event_busy_outlined,
    HrDeskSection.shiftRoster => Icons.calendar_view_week_outlined,
    HrDeskSection.payroll => Icons.payments_outlined,
    HrDeskSection.access => Icons.manage_accounts_outlined,
  };
}

int _sectionCount(HrWorkspaceState state, HrDeskSection section) {
  final HrWorkspaceSummary summary = state.overview.summary;
  return switch (section) {
    HrDeskSection.staffDirectory =>
      state.staff.totalItemCount ?? state.staff.items.length,
    HrDeskSection.leaveRequests => summary.leaveRequests,
    HrDeskSection.shiftRoster =>
      summary.draftRosters + summary.unassignedShifts + summary.overdueShifts,
    HrDeskSection.payroll => summary.payrollDraftRuns,
    HrDeskSection.access => 0,
  };
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
    HrQueue.leaveRequests => hrJoinDisplay(<String?>[
      item.leaveType == null ? null : _apiLabel(context, item.leaveType),
      item.staffName,
      item.staffNumber,
    ]).ifEmpty(l10n.hrLeaveRequestTitle),
    HrQueue.swapRequests => hrJoinDisplay(<String?>[
      item.shiftType == null ? null : _apiLabel(context, item.shiftType),
      item.shiftId,
      item.staffNumber,
    ]).ifEmpty(l10n.hrSwapRequestTitle),
    HrQueue.rosterDrafts => hrJoinDisplay(<String?>[
      item.periodLabel,
      item.rosterId,
    ]).ifEmpty(l10n.hrRosterDraftTitle),
    HrQueue.unassignedShifts || HrQueue.overdueShifts => hrJoinDisplay(
      <String?>[
        item.shiftType == null ? null : _apiLabel(context, item.shiftType),
        item.shiftId,
      ],
    ).ifEmpty(l10n.hrShiftQueueTitle),
    HrQueue.payrollDrafts => hrJoinDisplay(<String?>[
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
  return hrDateRange(
    context,
    item.startAt,
    item.endAt,
  ).ifEmpty(context.l10n.profileUnknownValue);
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
  final String leaveType = l10n.hrReferenceLeaveTypeLabel(
    normalized,
    fallback: '',
  );
  if (leaveType.isNotEmpty && leaveType != normalized) {
    return leaveType;
  }
  final String halfDayPeriod = l10n.hrReferenceLeaveHalfDayPeriodLabel(
    normalized,
    fallback: '',
  );
  if (halfDayPeriod.isNotEmpty && halfDayPeriod != normalized) {
    return halfDayPeriod;
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

String _leaveSummaryTitle(BuildContext context, HrStaffLeave leave) {
  final AppLocalizations l10n = context.l10n;
  final String leaveType = _apiLabel(
    context,
    leave.leaveType,
  ).ifEmpty(l10n.hrLeaveLabel);
  final String status = _apiLabel(context, leave.status);
  if (status.isEmpty) {
    return leaveType;
  }
  return '$leaveType · $status';
}

String _leaveSummarySubtitle(BuildContext context, HrStaffLeave leave) {
  final AppLocalizations l10n = context.l10n;
  final List<String> parts = <String>[
    hrDateRange(context, leave.startDate, leave.endDate),
    if (leave.isHalfDay)
      l10n.hrLeaveHalfDaySummary(
        _apiLabel(
          context,
          leave.halfDayPeriod,
        ).ifEmpty(l10n.hrLeaveHalfDayLabel),
      ),
    if ((leave.coveringStaffName ?? '').trim().isNotEmpty)
      l10n.hrCoveringStaffSummary(leave.coveringStaffName!),
  ].where((String part) => part.trim().isNotEmpty).toList(growable: false);
  return parts.join(' · ');
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

const String _hrPositionFilterKey = 'position';
const String _hrDepartmentFilterKey = 'department';
const String _hrPractitionerFilterKey = 'practitioner';

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
