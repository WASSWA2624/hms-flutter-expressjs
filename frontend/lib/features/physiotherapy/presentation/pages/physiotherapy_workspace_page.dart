import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const AccessRequirement _therapyReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
    AppPermissions.billingRead,
  ],
);

const AccessRequirement _therapyWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
  ],
);

class PhysiotherapyWorkspacePage extends ConsumerStatefulWidget {
  const PhysiotherapyWorkspacePage({super.key});

  @override
  ConsumerState<PhysiotherapyWorkspacePage> createState() =>
      _PhysiotherapyWorkspacePageState();
}

class _PhysiotherapyWorkspacePageState
    extends ConsumerState<PhysiotherapyWorkspacePage> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<TherapyWorkItem>
  _columnVisibilityController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<TherapyWorkItem>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );
    final asyncState = ref.watch(physiotherapyWorkspaceControllerProvider);

    return AsyncStateScaffold<PhysiotherapyWorkspaceState>(
      value: asyncState,
      loadingTitle: l10n.physiotherapyLoadingTitle,
      loadingBody: l10n.physiotherapyLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        controller.refresh();
      },
      dataBuilder: (BuildContext context, PhysiotherapyWorkspaceState state) {
        if (_searchController.text != state.query.search) {
          _searchController.text = state.query.search;
        }
        return _PhysiotherapyWorkspace(
          state: state,
          searchController: _searchController,
          columnVisibilityController: _columnVisibilityController,
        );
      },
    );
  }
}

class _PhysiotherapyWorkspace extends ConsumerWidget {
  const _PhysiotherapyWorkspace({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PhysiotherapyWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<TherapyWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );

    return Scaffold(
      body: AppWorkspace(
        title: l10n.physiotherapyTitle,
        leadingIcon: Icons.accessibility_new_outlined,
        status: AppWorkspaceStatus(
          label: state.isSaving
              ? l10n.physiotherapySavingStatus
              : l10n.physiotherapyLiveStatus,
          tone: state.isSaving
              ? AppWorkspaceStatusTone.warning
              : AppWorkspaceStatusTone.success,
          icon: state.isSaving ? Icons.sync : Icons.check_circle_outline,
        ),
        secondaryActions: <Widget>[
          AppButton.secondary(
            label: l10n.commonRefreshActionLabel,
            leadingIcon: Icons.refresh,
            isLoading: state.isRefreshing,
            onPressed: () {
              controller.refresh();
            },
          ),
        ],
        summaryCards: _summaryCards(context, controller),
        body: _buildWorklist(context, ref, controller),
        detail: _buildDetail(context, ref, controller),
      ),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
  ) {
    final l10n = context.l10n;
    return <Widget>[
      _summaryCard(
        label: l10n.physiotherapyReferralsSummaryLabel,
        value: state.referralsCount,
        icon: Icons.assignment_outlined,
        tone: AppWorkspaceStatusTone.info,
        scope: PhysiotherapyQueueScope.referrals,
        controller: controller,
      ),
      _summaryCard(
        label: l10n.physiotherapyTodaySummaryLabel,
        value: state.todayCount,
        icon: Icons.today_outlined,
        tone: AppWorkspaceStatusTone.success,
        scope: PhysiotherapyQueueScope.today,
        controller: controller,
      ),
      _summaryCard(
        label: l10n.physiotherapyMissedSummaryLabel,
        value: state.missedCount,
        icon: Icons.event_busy_outlined,
        tone: AppWorkspaceStatusTone.error,
        scope: PhysiotherapyQueueScope.missed,
        controller: controller,
      ),
      _summaryCard(
        label: l10n.physiotherapyActivePlansSummaryLabel,
        value: state.activePlansCount,
        icon: Icons.fact_check_outlined,
        tone: AppWorkspaceStatusTone.neutral,
        scope: PhysiotherapyQueueScope.activePlans,
        controller: controller,
      ),
      _summaryCard(
        label: l10n.physiotherapyFollowUpDueSummaryLabel,
        value: state.followUpDueCount,
        icon: Icons.notification_important_outlined,
        tone: AppWorkspaceStatusTone.warning,
        scope: PhysiotherapyQueueScope.followUpDue,
        controller: controller,
      ),
      _summaryCard(
        label: l10n.physiotherapyCompletedSummaryLabel,
        value: state.completedCount,
        icon: Icons.task_alt_outlined,
        tone: AppWorkspaceStatusTone.success,
        scope: PhysiotherapyQueueScope.completed,
        controller: controller,
      ),
    ];
  }

  Widget _summaryCard({
    required String label,
    required int value,
    required IconData icon,
    required AppWorkspaceStatusTone tone,
    required PhysiotherapyQueueScope scope,
    required PhysiotherapyWorkspaceController controller,
  }) {
    return AppWorkspaceSummaryCard(
      label: label,
      value: value.toString(),
      icon: icon,
      tone: tone,
      onPressed: () {
        controller.applyScope(scope);
      },
    );
  }

  Widget _buildWorklist(
    BuildContext context,
    WidgetRef ref,
    PhysiotherapyWorkspaceController controller,
  ) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final AppSearchBarFilterValue filterValue = _filterValueFromQuery(
      state.query,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.physiotherapyWorklistTitle,
      description: l10n.physiotherapyWorklistDescription,
      child: AppListTable<TherapyWorkItem>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        title: l10n.physiotherapyWorklistTitle,
        description: l10n.physiotherapyWorklistDescription,
        columns: _columns(context, locale),
        columnChoices: _optionalColumns(context, locale),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.physiotherapyTableColumnsTitle,
        columnVisibilityApplyLabel: l10n.physiotherapyApplyColumnsAction,
        columnVisibilityResetLabel: l10n.physiotherapyResetColumnsAction,
        columnVisibilityCancelLabel: l10n.commonCancelActionLabel,
        itemKeyBuilder: (TherapyWorkItem item) => ValueKey<String>(item.id),
        onRowSelected: controller.selectWorkItem,
        onPageChanged: controller.changePage,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<TherapyWorkItem> page) => l10n.opdPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        ),
        emptyBuilder: (BuildContext context) => AppWorkspaceStatePanel.empty(
          title: l10n.physiotherapyNoWorkTitle,
          body: l10n.physiotherapyNoWorkBody,
          minHeight: 220,
        ),
        mobileItemBuilder: (BuildContext context, TherapyWorkItem item) {
          return _TherapyWorklistMobileItem(item: item);
        },
        search: AppListTableSearch<TherapyWorkItem>(
          controller: searchController,
          semanticLabel: l10n.physiotherapySearchLabel,
          hintText: l10n.physiotherapySearchHint,
          clearLabel: l10n.opdClearFiltersAction,
          matcher: (TherapyWorkItem item, String query) =>
              item.matchesSearch(query, field: state.query.filters.searchField),
          onSubmitted: controller.applySearch,
          onClear: () {
            controller.applySearch('');
          },
          isLoading: state.isRefreshing,
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.physiotherapyFiltersLabel,
          advancedFilterTitle: l10n.physiotherapyFiltersLabel,
          advancedFilterApplyLabel: l10n.physiotherapyApplyFiltersAction,
          advancedFilterResetLabel: l10n.physiotherapyClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          searchFields: _searchFields(l10n),
          searchFieldLabel: l10n.physiotherapySearchFieldLabel,
          allFieldsLabel: l10n.physiotherapyAllFieldsLabel,
          dateFilterLabel: l10n.physiotherapyDateFilterLabel,
          dateFromLabel: l10n.physiotherapyDateFromLabel,
          dateToLabel: l10n.physiotherapyDateToLabel,
          datePickerButtonLabel: l10n.patientsDatePickerAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          currentDate: DateTime.now(),
          filterGroups: _filterGroups(l10n),
          textFilters: <AppSearchBarTextFilter>[
            AppSearchBarTextFilter(
              key: 'therapist',
              label: l10n.physiotherapyTherapistFilterLabel,
              hintText: l10n.physiotherapyTherapistFilterHint,
              icon: Icons.person_search_outlined,
            ),
          ],
          filterValue: filterValue,
          hasActiveFilters: state.query.hasActiveFilters,
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyWorklistFilters(
              search: searchController.text,
              scope: _scopeFromFilterValue(value) ?? state.query.scope,
              filters: _filtersFromValue(value),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    PhysiotherapyWorkspaceController controller,
  ) {
    final l10n = context.l10n;
    if (state.isRefreshingDetail) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.physiotherapyDetailLoadingTitle,
        body: l10n.physiotherapyDetailLoadingBody,
      );
    }
    final PhysiotherapyDetail? detail = state.selectedDetail;
    if (detail == null) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.physiotherapyNoSelectionTitle,
        body: l10n.physiotherapyNoSelectionBody,
      );
    }

    final TherapyWorkItem item = detail.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: item.displayTitle,
          patientNumber: _value(item.patientPublicId ?? item.patientId, l10n),
          patientNumberLabel: l10n.physiotherapyPatientNumberLabel,
          demographics: item.displaySubtitle,
          status: _workspaceStatusForStatus(l10n, item.status),
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.physiotherapyEncounterLabel,
              value: _value(item.encounterPublicId ?? item.encounterId, l10n),
              icon: Icons.medical_information_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.physiotherapySessionLabel,
              value: _formatDateTime(context, item.sessionAt, l10n),
              icon: Icons.event_available_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.physiotherapyTherapistLabel,
              value: _value(item.therapistName, l10n),
              icon: Icons.badge_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.physiotherapyBillingAuthorizationLabel,
              value: _billingLabel(l10n, item.billingStatus),
              icon: Icons.price_check_outlined,
              tone: AppWorkspaceStatusTone.warning,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _ActionsPanel(
          detail: detail,
          isSaving: state.isSaving,
          onActionFailure: (AppFailure failure) {
            _showFailure(context, failure);
          },
          onActionSaved: () {
            _showSaved(context);
          },
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _OverviewPanel(detail: detail),
        SizedBox(height: Theme.of(context).spacing.md),
        _RecordsPanel(
          title: l10n.physiotherapySessionsPanelTitle,
          emptyLabel: l10n.physiotherapyNoRecordsLabel,
          records: detail.sessionHistory,
          icon: Icons.directions_walk_outlined,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _RecordsPanel(
          title: l10n.physiotherapyPlanPanelTitle,
          emptyLabel: l10n.physiotherapyNoRecordsLabel,
          records: detail.carePlans,
          icon: Icons.fact_check_outlined,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _RecordsPanel(
          title: l10n.physiotherapyProgressNotesPanelTitle,
          emptyLabel: l10n.physiotherapyNoRecordsLabel,
          records: detail.progressNotes,
          icon: Icons.notes_outlined,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _RecordsPanel(
          title: l10n.physiotherapyFollowUpPanelTitle,
          emptyLabel: l10n.physiotherapyNoRecordsLabel,
          records: detail.followUps,
          icon: Icons.notification_add_outlined,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _BackendGapsPanel(detail: detail),
      ],
    );
  }

  List<AppListTableColumn<TherapyWorkItem>> _columns(
    BuildContext context,
    Locale locale,
  ) {
    final l10n = context.l10n;
    return <AppListTableColumn<TherapyWorkItem>>[
      AppListTableColumn<TherapyWorkItem>(
        id: 'patient',
        label: l10n.physiotherapyPatientColumnLabel,
        sortComparator: (TherapyWorkItem left, TherapyWorkItem right) =>
            appListTableCompareText(left.displayTitle, right.displayTitle),
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            AppListItemText(
              title: item.displayTitle,
              subtitle: item.displaySubtitle,
              subtitleMaxLines: 2,
            ),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'source',
        label: l10n.physiotherapySourceColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            AppListItemText(
              title: _sourceLabel(l10n, item.source),
              subtitle: item.sourceTitle ?? item.referralReason,
              subtitleMaxLines: 2,
            ),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'session',
        label: l10n.physiotherapySessionColumnLabel,
        sortComparator: (TherapyWorkItem left, TherapyWorkItem right) =>
            appListTableCompareDateTime(left.sessionAt, right.sessionAt),
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            Text(_formatDateTime(context, item.sessionAt, l10n)),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'status',
        label: l10n.physiotherapyStatusColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            AppWorkspaceStatusBadge(
              status: _workspaceStatusForStatus(l10n, item.status),
            ),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'next',
        label: l10n.physiotherapyNextActionColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            Text(_nextActionLabel(l10n, item.status)),
      ),
    ];
  }

  List<AppListTableColumn<TherapyWorkItem>> _optionalColumns(
    BuildContext context,
    Locale locale,
  ) {
    final l10n = context.l10n;
    return <AppListTableColumn<TherapyWorkItem>>[
      AppListTableColumn<TherapyWorkItem>(
        id: 'plan',
        label: l10n.physiotherapyPlanColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) => Text(
          _value(item.plan, l10n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'attendance',
        label: l10n.physiotherapyAttendanceColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            Text(_attendanceLabel(l10n, item.attendanceStatus)),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'billing',
        label: l10n.physiotherapyBillingColumnLabel,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            Text(_billingLabel(l10n, item.billingStatus)),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'therapist',
        label: l10n.physiotherapyTherapistColumnLabel,
        sortComparator: (TherapyWorkItem left, TherapyWorkItem right) =>
            appListTableCompareText(left.therapistName, right.therapistName),
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            Text(_value(item.therapistName, l10n)),
      ),
    ];
  }
}

class _TherapyWorklistMobileItem extends StatelessWidget {
  const _TherapyWorklistMobileItem({required this.item});

  final TherapyWorkItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppListItemRow(
      title: item.displayTitle,
      subtitle: item.displaySubtitle,
      leadingIcon: Icons.accessibility_new_outlined,
      trailing: AppWorkspaceStatusBadge(
        status: _workspaceStatusForStatus(l10n, item.status),
      ),
      details: <Widget>[
        AppInlineMetaText(
          icon: Icons.event_available_outlined,
          label: _formatDateTime(context, item.sessionAt, l10n),
        ),
        AppInlineMetaText(
          icon: Icons.route_outlined,
          label: _nextActionLabel(l10n, item.status),
        ),
      ],
    );
  }
}

class _ActionsPanel extends ConsumerWidget {
  const _ActionsPanel({
    required this.detail,
    required this.isSaving,
    required this.onActionFailure,
    required this.onActionSaved,
  });

  final PhysiotherapyDetail detail;
  final bool isSaving;
  final ValueChanged<AppFailure> onActionFailure;
  final VoidCallback onActionSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );
    final TherapyWorkItem item = detail.item;

    return AppWorkspaceDetailPanel(
      title: l10n.physiotherapyActionsTitle,
      child: AppPermissionActionList(
        minItemWidth: 180,
        actions: <AppPermissionActionItem>[
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyAcceptReferralAction,
            icon: Icons.assignment_turned_in_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final String? note = await showAppDialog<String>(
                      context: context,
                      builder: (_) => _TextActionDialog(
                        title: l10n.physiotherapyAcceptReferralDialogTitle,
                        label: l10n.physiotherapyNoteFieldLabel,
                        submitLabel: l10n.physiotherapySaveAction,
                        initialValue: item.referralReason,
                        maxLines: 4,
                      ),
                    );
                    if (note == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(context, controller.acceptReferral(note));
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyScheduleSessionAction,
            icon: Icons.event_available_outlined,
            enabled: item.apiPatientId != null,
            isLoading: isSaving,
            onPressed: isSaving || item.apiPatientId == null
                ? null
                : () async {
                    final _SchedulePayload? payload =
                        await showAppDialog<_SchedulePayload>(
                          context: context,
                          builder: (_) => _ScheduleSessionDialog(
                            title: l10n.physiotherapyScheduleSessionDialogTitle,
                          ),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.scheduleSession(
                        startAt: payload.startAt,
                        endAt: payload.endAt,
                        reason: payload.reason,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyRecordAssessmentAction,
            icon: Icons.assignment_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final _AssessmentPayload? payload =
                        await showAppDialog<_AssessmentPayload>(
                          context: context,
                          builder: (_) => const _AssessmentDialog(),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.recordAssessment(
                        assessment: payload.assessment,
                        goals: payload.goals,
                        plan: payload.plan,
                        instructions: payload.instructions,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyRecordSessionAction,
            icon: Icons.directions_walk_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final _SessionPayload? payload =
                        await showAppDialog<_SessionPayload>(
                          context: context,
                          builder: (_) => const _SessionDialog(),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.recordSession(
                        note: payload.note,
                        attendanceStatus: payload.attendanceStatus,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyMarkAttendanceAction,
            icon: Icons.fact_check_outlined,
            enabled: item.hasAppointment,
            isLoading: isSaving,
            onPressed: isSaving || !item.hasAppointment
                ? null
                : () async {
                    final _AttendancePayload? payload =
                        await showAppDialog<_AttendancePayload>(
                          context: context,
                          builder: (_) => const _AttendanceDialog(),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.markAttendance(
                        status: payload.status,
                        note: payload.note,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyUpdatePlanAction,
            icon: Icons.playlist_add_check_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final _PlanPayload? payload =
                        await showAppDialog<_PlanPayload>(
                          context: context,
                          builder: (_) => _PlanDialog(initialPlan: item.plan),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.updatePlan(
                        plan: payload.plan,
                        startDate: payload.startDate,
                        endDate: payload.endDate,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyAddProgressNoteAction,
            icon: Icons.note_add_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final String? note = await showAppDialog<String>(
                      context: context,
                      builder: (_) => _TextActionDialog(
                        title: l10n.physiotherapyAddProgressNoteDialogTitle,
                        label: l10n.physiotherapyNoteFieldLabel,
                        submitLabel: l10n.physiotherapySaveAction,
                        maxLines: 5,
                        required: true,
                      ),
                    );
                    if (note == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(context, controller.addProgressNote(note));
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyScheduleFollowUpAction,
            icon: Icons.notification_add_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final _FollowUpPayload? payload =
                        await showAppDialog<_FollowUpPayload>(
                          context: context,
                          builder: (_) => const _FollowUpDialog(),
                        );
                    if (payload == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      controller.scheduleFollowUp(
                        scheduledAt: payload.scheduledAt,
                        notes: payload.notes,
                      ),
                    );
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyWriteRequirement,
            label: l10n.physiotherapyCloseEpisodeAction,
            icon: Icons.task_alt_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final String? summary = await showAppDialog<String>(
                      context: context,
                      builder: (_) => _TextActionDialog(
                        title: l10n.physiotherapyCloseEpisodeDialogTitle,
                        label: l10n.physiotherapySummaryFieldLabel,
                        submitLabel: l10n.physiotherapySaveAction,
                        maxLines: 5,
                        required: true,
                      ),
                    );
                    if (summary == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await _runAction(context, controller.closeEpisode(summary));
                  },
          ),
          AppPermissionActionItem(
            requirement: _therapyReadRequirement,
            label: l10n.physiotherapyPrintInstructionsAction,
            icon: Icons.print_outlined,
            onPressed: () {
              _printInstructions(context, ref, detail);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<AppFailure?> action,
  ) async {
    final AppFailure? failure = await action;
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      onActionFailure(failure);
      return;
    }
    onActionSaved();
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.detail});

  final PhysiotherapyDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TherapyWorkItem item = detail.item;
    return AppWorkspaceDetailPanel(
      title: l10n.physiotherapyReferralPanelTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InfoRow(
            label: l10n.physiotherapySourceLabel,
            value: _sourceLabel(l10n, item.source),
          ),
          _InfoRow(
            label: l10n.physiotherapyStatusLabel,
            value: _statusLabel(l10n, item.status),
          ),
          _InfoRow(
            label: l10n.physiotherapyAttendanceLabel,
            value: _attendanceLabel(l10n, item.attendanceStatus),
          ),
          _InfoRow(
            label: l10n.physiotherapyPlanLabel,
            value: _value(item.plan, l10n),
          ),
          _InfoRow(
            label: l10n.physiotherapyGoalLabel,
            value: _value(item.goals, l10n),
          ),
          _InfoRow(
            label: l10n.physiotherapyInstructionsLabel,
            value: _value(item.instructions, l10n),
          ),
          _InfoRow(
            label: l10n.physiotherapyBillingAuthorizationLabel,
            value: _billingLabel(l10n, item.billingStatus),
          ),
        ],
      ),
    );
  }
}

class _RecordsPanel extends StatelessWidget {
  const _RecordsPanel({
    required this.title,
    required this.emptyLabel,
    required this.records,
    required this.icon,
  });

  final String title;
  final String emptyLabel;
  final List<PhysiotherapyRecord> records;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: title,
      child: records.isEmpty
          ? Text(emptyLabel)
          : Column(
              children: <Widget>[
                for (final PhysiotherapyRecord record in records)
                  AppListItemRow(
                    title: record.displayTitle,
                    subtitle: record.displaySubtitle,
                    leadingIcon: icon,
                    details: <Widget>[
                      AppInlineMetaText(
                        icon: Icons.schedule_outlined,
                        label: _formatDateTime(
                          context,
                          record.activityAt,
                          l10n,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _BackendGapsPanel extends StatelessWidget {
  const _BackendGapsPanel({required this.detail});

  final PhysiotherapyDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.physiotherapyBackendGapsPanelTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.physiotherapyBackendGapBody),
          SizedBox(height: Theme.of(context).spacing.sm),
          for (final String code in detail.backendGaps)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline),
                  SizedBox(width: Theme.of(context).spacing.sm),
                  Expanded(child: Text(_backendGapLabel(l10n, code))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TextActionDialog extends StatefulWidget {
  const _TextActionDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    this.initialValue,
    this.maxLines = 3,
    this.required = false,
  });

  final String title;
  final String label;
  final String submitLabel;
  final String? initialValue;
  final int maxLines;
  final bool required;

  @override
  State<_TextActionDialog> createState() => _TextActionDialogState();
}

class _TextActionDialogState extends State<_TextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _controller,
            labelText: widget.label,
            minLines: 3,
            maxLines: widget.maxLines,
            isRequired: widget.required,
            validator: widget.required
                ? AppValidators.requiredText(l10n.validationRequired)
                : null,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.save_outlined,
          onPressed: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(_controller.text.trim());
          },
        ),
      ],
    );
  }
}

class _ScheduleSessionDialog extends StatefulWidget {
  const _ScheduleSessionDialog({required this.title});

  final String title;

  @override
  State<_ScheduleSessionDialog> createState() => _ScheduleSessionDialogState();
}

class _ScheduleSessionDialogState extends State<_ScheduleSessionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now().add(const Duration(hours: 1));
    final DateTime end = now.add(const Duration(minutes: 45));
    _startDate = now;
    _startTime = TimeOfDay.fromDateTime(now);
    _endDate = end;
    _endTime = TimeOfDay.fromDateTime(end);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppResponsiveFieldRow.two(
            left: AppDateField(
              value: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.physiotherapyStartDateFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (DateTime? value) {
                if (value != null) {
                  setState(() => _startDate = value);
                }
              },
            ),
            right: AppTimeField(
              value: _startTime,
              pickerButtonLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              labelText: l10n.physiotherapyStartTimeFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (TimeOfDay? value) {
                if (value != null) {
                  setState(() => _startTime = value);
                }
              },
            ),
          ),
          AppResponsiveFieldRow.two(
            left: AppDateField(
              value: _endDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.physiotherapyEndDateFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (DateTime? value) {
                if (value != null) {
                  setState(() => _endDate = value);
                }
              },
            ),
            right: AppTimeField(
              value: _endTime,
              pickerButtonLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              labelText: l10n.physiotherapyEndTimeFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (TimeOfDay? value) {
                if (value != null) {
                  setState(() => _endTime = value);
                }
              },
            ),
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.physiotherapyReasonFieldLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        AppButton.primary(
          label: l10n.physiotherapySaveAction,
          leadingIcon: Icons.save_outlined,
          onPressed: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            final DateTime startAt = _combineDateTime(_startDate, _startTime);
            DateTime endAt = _combineDateTime(_endDate, _endTime);
            if (!endAt.isAfter(startAt)) {
              endAt = startAt.add(const Duration(minutes: 45));
            }
            Navigator.of(context).pop(
              _SchedulePayload(
                startAt: startAt,
                endAt: endAt,
                reason: _reasonController.text.trim(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AssessmentDialog extends StatefulWidget {
  const _AssessmentDialog();

  @override
  State<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends State<_AssessmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _assessmentController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void dispose() {
    _assessmentController.dispose();
    _goalsController.dispose();
    _planController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.physiotherapyRecordAssessmentDialogTitle),
      icon: const Icon(Icons.assignment_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _assessmentController,
            labelText: l10n.physiotherapyAssessmentFieldLabel,
            minLines: 3,
            maxLines: 5,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _goalsController,
            labelText: l10n.physiotherapyGoalsFieldLabel,
            minLines: 2,
            maxLines: 4,
          ),
          AppTextField(
            controller: _planController,
            labelText: l10n.physiotherapyPlanFieldLabel,
            minLines: 3,
            maxLines: 5,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _instructionsController,
            labelText: l10n.physiotherapyInstructionsFieldLabel,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.physiotherapySaveAction,
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            _AssessmentPayload(
              assessment: _assessmentController.text.trim(),
              goals: _goalsController.text.trim(),
              plan: _planController.text.trim(),
              instructions: _instructionsController.text.trim(),
            ),
          );
        },
      ),
    );
  }
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog();

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();
  String? _attendanceStatus = 'COMPLETED';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.physiotherapyRecordSessionDialogTitle),
      icon: const Icon(Icons.directions_walk_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _attendanceStatus,
            options: _attendanceOptions(l10n),
            labelText: l10n.physiotherapyAttendanceStatusFieldLabel,
            isRequired: true,
            validator: AppValidators.requiredValue(l10n.validationRequired),
            onChanged: (String? value) {
              setState(() => _attendanceStatus = value);
            },
          ),
          AppTextField(
            controller: _noteController,
            labelText: l10n.physiotherapySessionNoteFieldLabel,
            minLines: 3,
            maxLines: 6,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.physiotherapySaveAction,
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            _SessionPayload(
              note: _noteController.text.trim(),
              attendanceStatus: _attendanceStatus,
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceDialog extends StatefulWidget {
  const _AttendanceDialog();

  @override
  State<_AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<_AttendanceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();
  String? _status = 'COMPLETED';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.physiotherapyMarkAttendanceDialogTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _status,
            options: _attendanceOptions(l10n),
            labelText: l10n.physiotherapyAttendanceStatusFieldLabel,
            isRequired: true,
            validator: AppValidators.requiredValue(l10n.validationRequired),
            onChanged: (String? value) {
              setState(() => _status = value);
            },
          ),
          AppTextField(
            controller: _noteController,
            labelText: l10n.physiotherapyNoteFieldLabel,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.physiotherapySaveAction,
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            _AttendancePayload(
              status: _status ?? 'COMPLETED',
              note: _noteController.text.trim(),
            ),
          );
        },
      ),
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.initialPlan});

  final String? initialPlan;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _planController;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController(text: widget.initialPlan ?? '');
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.physiotherapyUpdatePlanDialogTitle),
      icon: const Icon(Icons.playlist_add_check_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _planController,
            labelText: l10n.physiotherapyPlanFieldLabel,
            minLines: 4,
            maxLines: 8,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppResponsiveFieldRow.two(
            left: AppDateField(
              value: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.physiotherapyStartDateFieldLabel,
              onChanged: (DateTime? value) {
                setState(() => _startDate = value);
              },
            ),
            right: AppDateField(
              value: _endDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.physiotherapyEndDateFieldLabel,
              onChanged: (DateTime? value) {
                setState(() => _endDate = value);
              },
            ),
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.physiotherapySaveAction,
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            _PlanPayload(
              plan: _planController.text.trim(),
              startDate: _startDate,
              endDate: _endDate,
            ),
          );
        },
      ),
    );
  }
}

class _FollowUpDialog extends StatefulWidget {
  const _FollowUpDialog();

  @override
  State<_FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<_FollowUpDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final DateTime initial = DateTime.now().add(const Duration(days: 7));
    _date = initial;
    _time = TimeOfDay.fromDateTime(initial);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.physiotherapyScheduleFollowUpDialogTitle),
      icon: const Icon(Icons.notification_add_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppResponsiveFieldRow.two(
            left: AppDateField(
              value: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              currentDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.physiotherapyDateFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (DateTime? value) {
                if (value != null) {
                  setState(() => _date = value);
                }
              },
            ),
            right: AppTimeField(
              value: _time,
              pickerButtonLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              labelText: l10n.physiotherapyTimeFieldLabel,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (TimeOfDay? value) {
                if (value != null) {
                  setState(() => _time = value);
                }
              },
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.physiotherapyNoteFieldLabel,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.physiotherapySaveAction,
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(
            _FollowUpPayload(
              scheduledAt: _combineDateTime(_date, _time),
              notes: _notesController.text.trim(),
            ),
          );
        },
      ),
    );
  }
}

List<Widget> _dialogActions(
  BuildContext context, {
  required String submitLabel,
  required VoidCallback onSubmit,
}) {
  final l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      onPressed: () {
        Navigator.of(context).pop();
      },
    ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: Icons.save_outlined,
      onPressed: onSubmit,
    ),
  ];
}

List<AppSearchBarFieldChoice> _searchFields(AppLocalizations l10n) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: 'patient',
      label: l10n.physiotherapyPatientColumnLabel,
      icon: Icons.person_search_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'encounter',
      label: l10n.physiotherapyEncounterLabel,
      icon: Icons.medical_information_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'source',
      label: l10n.physiotherapySourceLabel,
      icon: Icons.assignment_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'status',
      label: l10n.physiotherapyStatusLabel,
      icon: Icons.fact_check_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'therapist',
      label: l10n.physiotherapyTherapistLabel,
      icon: Icons.badge_outlined,
    ),
  ];
}

List<AppSearchBarFilterGroup> _filterGroups(AppLocalizations l10n) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: 'scope',
      label: l10n.physiotherapyQueueFilterLabel,
      allLabel: l10n.physiotherapyFilterAll,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.referrals.name,
          label: l10n.physiotherapyScopeReferrals,
          icon: Icons.assignment_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.today.name,
          label: l10n.physiotherapyScopeToday,
          icon: Icons.today_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.missed.name,
          label: l10n.physiotherapyScopeMissed,
          icon: Icons.event_busy_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.activePlans.name,
          label: l10n.physiotherapyScopeActivePlans,
          icon: Icons.fact_check_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.followUpDue.name,
          label: l10n.physiotherapyScopeFollowUpDue,
          icon: Icons.notification_important_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.completed.name,
          label: l10n.physiotherapyScopeCompleted,
          icon: Icons.task_alt_outlined,
        ),
        AppSearchBarFilterChoice(
          value: PhysiotherapyQueueScope.all.name,
          label: l10n.physiotherapyScopeAll,
          icon: Icons.all_inbox_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'source',
      label: l10n.physiotherapySourceLabel,
      allLabel: l10n.physiotherapyFilterAll,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'REFERRAL',
          label: l10n.physiotherapySourceReferral,
          icon: Icons.assignment_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'APPOINTMENT',
          label: l10n.physiotherapySourceAppointment,
          icon: Icons.event_available_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'CARE_PLAN',
          label: l10n.physiotherapySourceCarePlan,
          icon: Icons.fact_check_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'PROCEDURE',
          label: l10n.physiotherapySourceProcedure,
          icon: Icons.directions_walk_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'status',
      label: l10n.physiotherapyStatusLabel,
      allLabel: l10n.physiotherapyFilterAll,
      choices: <AppSearchBarFilterChoice>[
        for (final String value in <String>[
          'REFERRAL',
          'ACCEPTED',
          'ASSESSMENT',
          'TODAY',
          'IN_TREATMENT',
          'ACTIVE_PLAN',
          'FOLLOW_UP_DUE',
          'MISSED',
          'COMPLETED',
        ])
          AppSearchBarFilterChoice(
            value: value,
            label: _statusLabel(l10n, value),
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'attendance',
      label: l10n.physiotherapyAttendanceLabel,
      allLabel: l10n.physiotherapyFilterAll,
      choices: <AppSearchBarFilterChoice>[
        for (final AppSelectOption<String> option in _attendanceOptions(l10n))
          AppSearchBarFilterChoice(value: option.value, label: option.label),
      ],
    ),
  ];
}

AppSearchBarFilterValue _filterValueFromQuery(
  PhysiotherapyWorklistQuery query,
) {
  return AppSearchBarFilterValue(
    field: query.filters.searchField,
    dateFrom: query.filters.dateFrom,
    dateTo: query.filters.dateTo,
    texts: <String, String>{
      if ((query.filters.therapist ?? '').trim().isNotEmpty)
        'therapist': query.filters.therapist!.trim(),
    },
    options: <String, String>{
      'scope': query.scope.name,
      if ((query.filters.source ?? '').trim().isNotEmpty)
        'source': query.filters.source!.trim(),
      if ((query.filters.status ?? '').trim().isNotEmpty)
        'status': query.filters.status!.trim(),
      if ((query.filters.attendance ?? '').trim().isNotEmpty)
        'attendance': query.filters.attendance!.trim(),
    },
  );
}

PhysiotherapyWorklistFilters _filtersFromValue(AppSearchBarFilterValue value) {
  return PhysiotherapyWorklistFilters(
    searchField: value.field,
    source: value.option('source'),
    status: value.option('status'),
    attendance: value.option('attendance'),
    therapist: value.text('therapist'),
    dateFrom: value.dateFrom,
    dateTo: value.dateTo,
  );
}

PhysiotherapyQueueScope? _scopeFromFilterValue(AppSearchBarFilterValue value) {
  final String? scopeName = value.option('scope');
  if (scopeName == null) {
    return null;
  }
  for (final PhysiotherapyQueueScope scope in PhysiotherapyQueueScope.values) {
    if (scope.name == scopeName) {
      return scope;
    }
  }
  return null;
}

List<AppSelectOption<String>> _attendanceOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'SCHEDULED',
      label: l10n.physiotherapyAttendanceScheduled,
    ),
    AppSelectOption<String>(
      value: 'CONFIRMED',
      label: l10n.physiotherapyAttendanceConfirmed,
    ),
    AppSelectOption<String>(
      value: 'IN_PROGRESS',
      label: l10n.physiotherapyAttendanceInProgress,
    ),
    AppSelectOption<String>(
      value: 'COMPLETED',
      label: l10n.physiotherapyAttendanceCompleted,
    ),
    AppSelectOption<String>(
      value: 'CANCELLED',
      label: l10n.physiotherapyAttendanceCancelled,
    ),
    AppSelectOption<String>(
      value: 'NO_SHOW',
      label: l10n.physiotherapyAttendanceNoShow,
    ),
  ];
}

AppWorkspaceStatus _workspaceStatusForStatus(
  AppLocalizations l10n,
  String status,
) {
  final String normalized = status.toUpperCase();
  return AppWorkspaceStatus(
    label: _statusLabel(l10n, normalized),
    tone: switch (normalized) {
      'MISSED' => AppWorkspaceStatusTone.error,
      'FOLLOW_UP_DUE' => AppWorkspaceStatusTone.warning,
      'TODAY' => AppWorkspaceStatusTone.info,
      'ACTIVE_PLAN' || 'COMPLETED' => AppWorkspaceStatusTone.success,
      _ => AppWorkspaceStatusTone.neutral,
    },
    icon: switch (normalized) {
      'MISSED' => Icons.event_busy_outlined,
      'FOLLOW_UP_DUE' => Icons.notification_important_outlined,
      'TODAY' => Icons.today_outlined,
      'ACTIVE_PLAN' => Icons.fact_check_outlined,
      'COMPLETED' => Icons.task_alt_outlined,
      _ => Icons.assignment_outlined,
    },
  );
}

String _statusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'REFERRAL' => l10n.physiotherapyStatusReferral,
    'ACCEPTED' => l10n.physiotherapyStatusAccepted,
    'ASSESSMENT' => l10n.physiotherapyStatusAssessment,
    'TODAY' => l10n.physiotherapyStatusToday,
    'IN_TREATMENT' => l10n.physiotherapyStatusInTreatment,
    'ACTIVE_PLAN' => l10n.physiotherapyStatusActivePlan,
    'FOLLOW_UP_DUE' => l10n.physiotherapyStatusFollowUpDue,
    'MISSED' => l10n.physiotherapyStatusMissed,
    'COMPLETED' || 'CLOSED' => l10n.physiotherapyStatusCompleted,
    _ => l10n.physiotherapyUnknownStatusLabel,
  };
}

String _sourceLabel(AppLocalizations l10n, String? source) {
  return switch ((source ?? '').toUpperCase()) {
    'REFERRAL' => l10n.physiotherapySourceReferral,
    'APPOINTMENT' => l10n.physiotherapySourceAppointment,
    'CARE_PLAN' => l10n.physiotherapySourceCarePlan,
    'PROCEDURE' => l10n.physiotherapySourceProcedure,
    _ => l10n.physiotherapySourceUnknown,
  };
}

String _attendanceLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'SCHEDULED' => l10n.physiotherapyAttendanceScheduled,
    'CONFIRMED' => l10n.physiotherapyAttendanceConfirmed,
    'IN_PROGRESS' => l10n.physiotherapyAttendanceInProgress,
    'COMPLETED' => l10n.physiotherapyAttendanceCompleted,
    'CANCELLED' => l10n.physiotherapyAttendanceCancelled,
    'NO_SHOW' => l10n.physiotherapyAttendanceNoShow,
    _ => l10n.physiotherapyMissingValueLabel,
  };
}

String _billingLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'BACKEND_GAP' => l10n.physiotherapyBillingBackendGap,
    _ => l10n.physiotherapyMissingValueLabel,
  };
}

String _nextActionLabel(AppLocalizations l10n, String status) {
  return switch (status.toUpperCase()) {
    'REFERRAL' => l10n.physiotherapyAcceptReferralAction,
    'ACCEPTED' => l10n.physiotherapyRecordAssessmentAction,
    'ASSESSMENT' => l10n.physiotherapyScheduleSessionAction,
    'TODAY' => l10n.physiotherapyRecordSessionAction,
    'IN_TREATMENT' => l10n.physiotherapyRecordSessionAction,
    'ACTIVE_PLAN' => l10n.physiotherapyScheduleFollowUpAction,
    'FOLLOW_UP_DUE' => l10n.physiotherapyScheduleFollowUpAction,
    'MISSED' => l10n.physiotherapyMarkAttendanceAction,
    'COMPLETED' => l10n.physiotherapyPrintInstructionsAction,
    _ => l10n.physiotherapyAcceptReferralAction,
  };
}

String _backendGapLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'PHYSIOTHERAPY_STATUS_ENDPOINT' =>
      l10n.physiotherapyBackendGapStatusEndpoint,
    'BILLING_AUTHORIZATION_ENDPOINT' =>
      l10n.physiotherapyBackendGapBillingEndpoint,
    'PHYSIOTHERAPY_REPORT_ENDPOINT' =>
      l10n.physiotherapyBackendGapReportEndpoint,
    _ => l10n.physiotherapyBackendGapUnknown,
  };
}

String _formatDateTime(
  BuildContext context,
  DateTime? value,
  AppLocalizations l10n,
) {
  if (value == null) {
    return l10n.physiotherapyMissingValueLabel;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String _value(String? value, AppLocalizations l10n) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? l10n.physiotherapyMissingValueLabel : normalized;
}

DateTime _combineDateTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

void _showFailure(BuildContext context, AppFailure failure) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.physiotherapySavedMessage)),
  );
}

Future<void> _printInstructions(
  BuildContext context,
  WidgetRef ref,
  PhysiotherapyDetail detail,
) async {
  final l10n = context.l10n;
  final TherapyWorkItem item = detail.item;
  final String bodyHtml = <String>[
    PrintFormTemplate.section(
      title: l10n.physiotherapyReferralPanelTitle,
      bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.physiotherapyReportPatientLabel,
          value: item.displayTitle,
        ),
        PrintFormMetadataItem(
          label: l10n.physiotherapyReportEncounterLabel,
          value: item.encounterPublicId ?? item.encounterId,
        ),
        PrintFormMetadataItem(
          label: l10n.physiotherapyStatusLabel,
          value: _statusLabel(l10n, item.status),
        ),
      ]),
    ),
    PrintFormTemplate.section(
      title: l10n.physiotherapyReportPlanLabel,
      bodyHtml: PrintFormTemplate.unorderedList(<String>[
        ?item.plan,
        ?item.goals,
      ], emptyText: l10n.physiotherapyNoRecordsLabel),
    ),
    PrintFormTemplate.section(
      title: l10n.physiotherapyReportInstructionsLabel,
      bodyHtml: PrintFormTemplate.unorderedList(<String>[
        ?item.instructions,
      ], emptyText: l10n.physiotherapyNoInstructionsLabel),
    ),
    PrintFormTemplate.section(
      title: l10n.physiotherapyReportSessionsLabel,
      bodyHtml: PrintFormTemplate.table(
        headers: <String>[
          l10n.physiotherapySessionColumnLabel,
          l10n.physiotherapyStatusLabel,
          l10n.physiotherapyPlanLabel,
        ],
        rows: detail.sessionHistory
            .map(
              (PhysiotherapyRecord record) => <String>[
                record.displayTitle,
                _attendanceLabel(l10n, record.status),
                record.description ?? '',
              ],
            )
            .toList(growable: false),
        emptyText: l10n.physiotherapyNoRecordsLabel,
      ),
    ),
  ].join();

  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: l10n.physiotherapyInstructionsReportTitle,
    bodyHtml: bodyHtml,
    metadata: <PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: l10n.physiotherapyReportPatientLabel,
        value: item.displayTitle,
      ),
      PrintFormMetadataItem(
        label: l10n.physiotherapyReportEncounterLabel,
        value: item.encounterPublicId ?? item.encounterId,
      ),
    ],
    footerNote: l10n.physiotherapyReportFooterNote,
  );
}

final class _SchedulePayload {
  const _SchedulePayload({
    required this.startAt,
    required this.endAt,
    this.reason,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String? reason;
}

final class _AssessmentPayload {
  const _AssessmentPayload({
    required this.assessment,
    required this.goals,
    required this.plan,
    this.instructions,
  });

  final String assessment;
  final String goals;
  final String plan;
  final String? instructions;
}

final class _SessionPayload {
  const _SessionPayload({required this.note, this.attendanceStatus});

  final String note;
  final String? attendanceStatus;
}

final class _AttendancePayload {
  const _AttendancePayload({required this.status, this.note});

  final String status;
  final String? note;
}

final class _PlanPayload {
  const _PlanPayload({required this.plan, this.startDate, this.endDate});

  final String plan;
  final DateTime? startDate;
  final DateTime? endDate;
}

final class _FollowUpPayload {
  const _FollowUpPayload({required this.scheduledAt, this.notes});

  final DateTime scheduledAt;
  final String? notes;
}
