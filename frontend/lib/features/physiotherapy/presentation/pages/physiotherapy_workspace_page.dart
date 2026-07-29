import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/physiotherapy_access.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const String _physiotherapyFollowUpsWorklistTabId = 'followUpsWorklist';

class PhysiotherapyWorkspacePage extends ConsumerStatefulWidget {
  const PhysiotherapyWorkspacePage({this.initialQuery, super.key});

  final PhysiotherapyWorkspaceQuery? initialQuery;

  @override
  ConsumerState<PhysiotherapyWorkspacePage> createState() =>
      _PhysiotherapyWorkspacePageState();
}

class _PhysiotherapyWorkspacePageState
    extends ConsumerState<PhysiotherapyWorkspacePage> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<TherapyWorkItem>
  _columnVisibilityController;
  late PhysiotherapyQueueScope _section;
  bool _showFollowUpWorklist = false;
  String? _pendingSearchControllerText;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    if (_isFollowUpsWorklistQuery(widget.initialQuery?.section)) {
      _showFollowUpWorklist = true;
      _section = PhysiotherapyQueueScope.referrals;
    } else {
      _section =
          _sectionFromQuery(widget.initialQuery) ??
          PhysiotherapyQueueScope.referrals;
    }
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<TherapyWorkItem>();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant PhysiotherapyWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(PhysiotherapyWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(PhysiotherapyWorkspaceQuery query) async {
    // Wait for the initial workspace load so applyScope can update query.scope.
    await ref.read(physiotherapyWorkspaceControllerProvider.future);
    if (!mounted) return;

    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );

    final PhysiotherapyQueueScope? section = _sectionFromQuery(query);
    if (_isFollowUpsWorklistQuery(query.section)) {
      if (!_showFollowUpWorklist) {
        setState(() => _showFollowUpWorklist = true);
      }
      return;
    }
    if (section != null) {
      if (section != _section) {
        setState(() => _section = section);
      }
      await controller.applyScope(section);
    }

    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      await controller.applySearch(query.search);
      return;
    }
    if (query.encounterId.isNotEmpty || query.sessionId.isNotEmpty) {
      final String term = query.encounterId.isNotEmpty
          ? query.encounterId
          : query.sessionId;
      _searchController.text = term;
      await controller.applySearch(term);
    }
  }

  void _updateUrlForSection({
    PhysiotherapyQueueScope? scope,
    bool followUpWorklist = false,
  }) {
    if (!mounted) return;
    final Map<String, String> params = <String, String>{
      'section': followUpWorklist
          ? 'follow-ups'
          : _sectionToQueryValue(scope ?? _section),
    };
    if (_searchController.text.trim().isNotEmpty) {
      params['search'] = _searchController.text.trim();
    }
    final String location = AppRoutes.physiotherapy.location(
      queryParameters: params,
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _onTabChanged(PhysiotherapyQueueScope scope) {
    setState(() {
      _section = scope;
      _showFollowUpWorklist = false;
    });
    ref
        .read(physiotherapyWorkspaceControllerProvider.notifier)
        .applyScope(scope);
    _updateUrlForSection(scope: scope);
  }

  void _onFollowUpWorklistTabSelected() {
    setState(() => _showFollowUpWorklist = true);
    _updateUrlForSection(followUpWorklist: true);
  }

  static bool _isFollowUpsWorklistQuery(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'follow-ups' || 'follow_ups' || 'followups' => true,
      _ => false,
    };
  }

  static PhysiotherapyQueueScope? _sectionFromQuery(
    PhysiotherapyWorkspaceQuery? query,
  ) {
    if (query == null || query.section.isEmpty) return null;
    return _sectionFromQueryValue(query.section);
  }

  static PhysiotherapyQueueScope? _sectionFromQueryValue(String value) {
    return switch (value) {
      'referrals' => PhysiotherapyQueueScope.referrals,
      'today' => PhysiotherapyQueueScope.today,
      'active-plans' || 'active_plans' => PhysiotherapyQueueScope.activePlans,
      'follow-up' ||
      'follow_up' ||
      'follow-up-due' => PhysiotherapyQueueScope.followUpDue,
      'missed' => PhysiotherapyQueueScope.missed,
      'completed' => PhysiotherapyQueueScope.completed,
      _ => null,
    };
  }

  static String _sectionToQueryValue(PhysiotherapyQueueScope section) {
    return switch (section) {
      PhysiotherapyQueueScope.referrals => 'referrals',
      PhysiotherapyQueueScope.today => 'today',
      PhysiotherapyQueueScope.activePlans => 'active-plans',
      PhysiotherapyQueueScope.followUpDue => 'follow-up',
      PhysiotherapyQueueScope.missed => 'missed',
      PhysiotherapyQueueScope.completed => 'completed',
      PhysiotherapyQueueScope.all => 'referrals',
    };
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
        _syncSearchControllerAfterBuild(state.query.search);
        return _PhysiotherapyWorkspace(
          state: state,
          section: _section,
          showFollowUpWorklist: _showFollowUpWorklist,
          onTabChanged: _onTabChanged,
          onFollowUpWorklistTabSelected: _onFollowUpWorklistTabSelected,
          searchController: _searchController,
          columnVisibilityController: _columnVisibilityController,
        );
      },
    );
  }

  void _syncSearchControllerAfterBuild(String search) {
    if (_searchController.text == search ||
        _pendingSearchControllerText == search) {
      return;
    }

    _pendingSearchControllerText = search;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingSearchControllerText != search) {
        return;
      }
      _pendingSearchControllerText = null;
      if (_searchController.text == search) {
        return;
      }
      _searchController.value = _searchController.value.copyWith(
        text: search,
        selection: TextSelection.collapsed(offset: search.length),
        composing: TextRange.empty,
      );
    });
  }
}

class _PhysiotherapyWorkspace extends ConsumerWidget {
  const _PhysiotherapyWorkspace({
    required this.state,
    required this.section,
    required this.showFollowUpWorklist,
    required this.onTabChanged,
    required this.onFollowUpWorklistTabSelected,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PhysiotherapyWorkspaceState state;
  final PhysiotherapyQueueScope section;
  final bool showFollowUpWorklist;
  final ValueChanged<PhysiotherapyQueueScope> onTabChanged;
  final VoidCallback onFollowUpWorklistTabSelected;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<TherapyWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final List<PhysiotherapyQueueScope> visibleScopes =
        physiotherapyAllowedScopes(policy);
    final bool canViewFollowUps = canViewPhysiotherapyFollowUps(policy);
    if (visibleScopes.isEmpty && !canViewFollowUps) {
      return const SizedBox.shrink();
    }
    if (showFollowUpWorklist && !canViewFollowUps) {
      if (visibleScopes.isNotEmpty) {
        final PhysiotherapyQueueScope fallback =
            physiotherapyFallbackScope(policy) ?? visibleScopes.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onTabChanged(fallback);
        });
      }
    } else if (!showFollowUpWorklist &&
        visibleScopes.isNotEmpty &&
        !visibleScopes.contains(section)) {
      final PhysiotherapyQueueScope fallback =
          physiotherapyFallbackScope(policy) ?? visibleScopes.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onTabChanged(fallback);
      });
    }

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTabStrip(
            tabs: <AppTabItem>[
              for (final PhysiotherapyQueueScope scope in visibleScopes)
                AppTabItem(
                  id: scope.name,
                  icon: _sectionIcon(scope),
                  label: _sectionLabel(l10n, scope),
                  count: _sectionCount(state, scope),
                  countTone: _sectionCountTone(scope),
                ),
              if (canViewFollowUps)
                AppTabItem(
                  id: _physiotherapyFollowUpsWorklistTabId,
                  icon: Icons.phone_callback_outlined,
                  label: l10n.opdFollowUpsTitle,
                  count: ref.watch(
                    followUpTabCountProvider(const FollowUpWorklistScope()),
                  ),
                ),
            ],
            selectedId: showFollowUpWorklist && canViewFollowUps
                ? _physiotherapyFollowUpsWorklistTabId
                : section.name,
            onTabTapped: (String tabId) {
              if (tabId == _physiotherapyFollowUpsWorklistTabId) {
                onFollowUpWorklistTabSelected();
                return;
              }
              for (final PhysiotherapyQueueScope scope in visibleScopes) {
                if (scope.name == tabId) {
                  onTabChanged(scope);
                  break;
                }
              }
            },
          ),
          SizedBox(height: theme.spacing.sm),
          if (showFollowUpWorklist && canViewFollowUps)
            const FollowUpWorklistPanel(
              scope: FollowUpWorklistScope(),
              storageKeyPrefix: 'physiotherapy_follow_ups',
              readRequirement: PhysiotherapyFollowUpsAtomPermissions.tab,
              writeRequirement: PhysiotherapyFollowUpsAtomPermissions.write,
            )
          else
            _buildWorklist(context, ref, controller, policy),
        ],
      ),
    );
  }

  static IconData _sectionIcon(PhysiotherapyQueueScope scope) {
    return switch (scope) {
      PhysiotherapyQueueScope.referrals => Icons.assignment_outlined,
      PhysiotherapyQueueScope.today => Icons.today_outlined,
      PhysiotherapyQueueScope.activePlans => Icons.fact_check_outlined,
      PhysiotherapyQueueScope.followUpDue =>
        Icons.notification_important_outlined,
      PhysiotherapyQueueScope.missed => Icons.event_busy_outlined,
      PhysiotherapyQueueScope.completed => Icons.task_alt_outlined,
      PhysiotherapyQueueScope.all => Icons.all_inbox_outlined,
    };
  }

  static String _sectionLabel(
    AppLocalizations l10n,
    PhysiotherapyQueueScope scope,
  ) {
    return switch (scope) {
      PhysiotherapyQueueScope.referrals =>
        l10n.physiotherapyReferralsSummaryLabel,
      PhysiotherapyQueueScope.today => l10n.physiotherapyTodaySummaryLabel,
      PhysiotherapyQueueScope.activePlans =>
        l10n.physiotherapyActivePlansSummaryLabel,
      PhysiotherapyQueueScope.followUpDue =>
        l10n.physiotherapyFollowUpDueSummaryLabel,
      PhysiotherapyQueueScope.missed => l10n.physiotherapyMissedSummaryLabel,
      PhysiotherapyQueueScope.completed =>
        l10n.physiotherapyCompletedSummaryLabel,
      PhysiotherapyQueueScope.all => l10n.physiotherapyScopeAll,
    };
  }

  static int _sectionCount(
    PhysiotherapyWorkspaceState state,
    PhysiotherapyQueueScope scope,
  ) {
    return switch (scope) {
      PhysiotherapyQueueScope.referrals => state.referralsCount,
      PhysiotherapyQueueScope.today => state.todayCount,
      PhysiotherapyQueueScope.activePlans => state.activePlansCount,
      PhysiotherapyQueueScope.followUpDue => state.followUpDueCount,
      PhysiotherapyQueueScope.missed => state.missedCount,
      PhysiotherapyQueueScope.completed => state.completedCount,
      PhysiotherapyQueueScope.all => state.worklist.items.length,
    };
  }

  static AppTabCountTone _sectionCountTone(PhysiotherapyQueueScope scope) {
    return switch (scope) {
      PhysiotherapyQueueScope.missed => AppTabCountTone.danger,
      PhysiotherapyQueueScope.referrals ||
      PhysiotherapyQueueScope.activePlans ||
      PhysiotherapyQueueScope.followUpDue => AppTabCountTone.warning,
      PhysiotherapyQueueScope.today ||
      PhysiotherapyQueueScope.completed ||
      PhysiotherapyQueueScope.all => AppTabCountTone.info,
    };
  }

  Future<void> _openScheduleSession(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
    AppLocalizations l10n,
  ) async {
    final _SchedulePayload? payload = await showAppDialog<_SchedulePayload>(
      context: context,
      builder: (_) => _ScheduleSessionDialog(
        title: l10n.physiotherapyScheduleSessionDialogTitle,
      ),
    );
    if (payload == null || !context.mounted) return;
    final AppFailure? failure = await controller.scheduleSession(
      startAt: payload.startAt,
      endAt: payload.endAt,
      reason: payload.reason,
    );
    if (!context.mounted) return;
    if (failure != null) _showFailure(context, failure);
  }

  Future<void> _openRecordSession(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
  ) async {
    final _SessionPayload? payload = await showAppDialog<_SessionPayload>(
      context: context,
      builder: (_) => const _SessionDialog(),
    );
    if (payload == null || !context.mounted) return;
    final AppFailure? failure = await controller.recordSession(
      note: payload.note,
      attendanceStatus: payload.attendanceStatus,
    );
    if (!context.mounted) return;
    if (failure != null) {
      _showFailure(context, failure);
      return;
    }
    _showSaved(context);
  }

  Future<void> _openScheduleFollowUp(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
    AppLocalizations l10n,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFollowUpActionDialog(
        title: l10n.physiotherapyScheduleFollowUpDialogTitle,
        submitLabel: l10n.physiotherapySaveAction,
        icon: const Icon(Icons.notification_add_outlined),
        dateLabel: l10n.physiotherapyDateFieldLabel,
        timeLabel: l10n.physiotherapyTimeFieldLabel,
        notesLabel: l10n.physiotherapyNoteFieldLabel,
        datePickerButtonLabel: l10n.patientsDatePickerAction,
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        onSubmit: ({required DateTime scheduledAt, required String notes}) {
          return controller.scheduleFollowUp(
            scheduledAt: scheduledAt,
            notes: notes,
          );
        },
      ),
    );
    if (saved == true && context.mounted) _showSaved(context);
  }

  Future<void> _openMarkAttendance(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
  ) async {
    final _AttendancePayload? payload = await showAppDialog<_AttendancePayload>(
      context: context,
      builder: (_) => const _AttendanceDialog(),
    );
    if (payload == null || !context.mounted) return;
    final AppFailure? failure = await controller.markAttendance(
      status: payload.status,
      note: payload.note,
    );
    if (!context.mounted) return;
    if (failure != null) _showFailure(context, failure);
  }

  Future<void> _runTherapyNextAction(
    BuildContext context,
    WidgetRef ref,
    TherapyWorkItem item,
  ) async {
    final PhysiotherapyWorkspaceController controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectWorkItem(item);
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailure(context, failure);
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final PhysiotherapyWorkspaceState? workspaceState = ref
        .read(physiotherapyWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (PhysiotherapyWorkspaceState state) => state,
          failure: (_) => null,
        );
    if (workspaceState == null) {
      return;
    }

    switch (item.status.toUpperCase()) {
      case 'REFERRAL':
        await _openAcceptReferral(context, controller, l10n, item);
      case 'ACCEPTED':
        await _openRecordAssessment(context, controller);
      case 'ASSESSMENT':
        if (item.apiPatientId != null) {
          await _openScheduleSession(context, controller, l10n);
        }
      case 'TODAY':
      case 'IN_TREATMENT':
        await _openRecordSession(context, controller);
      case 'ACTIVE_PLAN':
      case 'FOLLOW_UP_DUE':
        await _openScheduleFollowUp(context, controller, l10n);
      case 'MISSED':
        if (item.hasAppointment) {
          await _openMarkAttendance(context, controller);
        }
      case 'COMPLETED':
        final PhysiotherapyDetail? detail = workspaceState.selectedDetail;
        if (detail != null) {
          await _printInstructions(context, ref, detail);
        }
      default:
        await _openAcceptReferral(context, controller, l10n, item);
    }
  }

  Future<void> _openAcceptReferral(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
    AppLocalizations l10n,
    TherapyWorkItem item,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: l10n.physiotherapyAcceptReferralDialogTitle,
        label: l10n.physiotherapyNoteFieldLabel,
        submitLabel: l10n.physiotherapySaveAction,
        initialValue: item.referralReason,
        minLines: 3,
        maxLines: 4,
        isRequired: false,
        onSubmit: controller.acceptReferral,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openRecordAssessment(
    BuildContext context,
    PhysiotherapyWorkspaceController controller,
  ) async {
    final _AssessmentPayload? payload = await showAppDialog<_AssessmentPayload>(
      context: context,
      builder: (_) => const _AssessmentDialog(),
    );
    if (payload == null || !context.mounted) {
      return;
    }
    final AppFailure? failure = await controller.recordAssessment(
      assessment: payload.assessment,
      goals: payload.goals,
      plan: payload.plan,
      instructions: payload.instructions,
    );
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailure(context, failure);
      return;
    }
    _showSaved(context);
  }

  Widget _buildWorklist(
    BuildContext context,
    WidgetRef ref,
    PhysiotherapyWorkspaceController controller,
    AppAccessPolicy policy,
  ) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final AppSearchBarFilterValue filterValue = _filterValueFromQuery(
      state.query,
      section,
    );

    return AppListTable<TherapyWorkItem>(
      page: state.worklist,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columns: _columns(context, locale, ref),
      columnChoices: _optionalColumns(context, locale, policy),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'physiotherapy_${section.name}',
      columnWidthStorageKey: 'physiotherapy_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.physiotherapyApplyColumnsAction,
      columnVisibilityResetLabel: l10n.physiotherapyResetColumnsAction,
      itemKeyBuilder: (TherapyWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: (TherapyWorkItem item) {
        unawaited(_openTherapyDetailDialog(context, ref, controller, item));
      },
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
        final l10n = context.l10n;
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: item.displaySubtitle,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _sourceLabel(l10n, item.source),
            ),
            AppListTableMobileMeta(
              label: _formatDateTime(context, item.sessionAt, l10n),
              icon: AppActionIcons.calendar,
            ),
            AppListTableMobileMeta(
              label: _workspaceStatusForStatus(l10n, item.status).label,
            ),
            if (_billingColumnAllowed(policy, section) &&
                item.billingStatus.trim().isNotEmpty)
              AppListTableMobileMeta(
                label: _billingLabel(l10n, item.billingStatus),
                icon: Icons.price_check_outlined,
              ),
          ],
          trailing: TherapyNextActionButton(
            item: item,
            onPressed: () => _runTherapyNextAction(context, ref, item),
          ),
        );
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
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.physiotherapyApplyFiltersAction,
        advancedFilterResetLabel: l10n.physiotherapyClearFiltersAction,
        searchFields: _searchFields(l10n),
        searchFieldLabel: l10n.physiotherapySearchFieldLabel,
        allFieldsLabel: l10n.physiotherapyAllFieldsLabel,
        dateFilterLabel: l10n.physiotherapyDateFilterLabel,
        dateFromLabel: l10n.physiotherapyDateFromLabel,
        dateToLabel: l10n.physiotherapyDateToLabel,
        datePickerButtonLabel: l10n.patientsDatePickerAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        currentDate: DateTime.now(),
        filterGroups: _filterGroups(l10n, section),
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: 'therapist',
            label: l10n.physiotherapyTherapistFilterLabel,
            hintText: l10n.physiotherapyTherapistFilterHint,
            icon: Icons.person_search_outlined,
          ),
        ],
        filterValue: filterValue,
        hasActiveFilters: state.query.filters.isActive ||
            state.query.search.trim().isNotEmpty,
        onFilterChanged: (AppSearchBarFilterValue value) {
          controller.applyWorklistFilters(
            search: searchController.text,
            scope: section,
            filters: _filtersFromValue(value, section),
          );
        },
      ),
    );
  }

  Future<void> _openTherapyDetailDialog(
    BuildContext context,
    WidgetRef ref,
    PhysiotherapyWorkspaceController controller,
    TherapyWorkItem item,
  ) async {
    final AppFailure? failure = await controller.selectWorkItem(item);
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailure(context, failure);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
          final PhysiotherapyWorkspaceState? dialogState = dialogRef
              .watch(physiotherapyWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (PhysiotherapyWorkspaceState state) => state,
                failure: (_) => null,
              );
          return AppDialog(
            title: Text(item.displayTitle),
            icon: const Icon(Icons.accessibility_new_outlined),
            scrollable: true,
            maxWidth: 980,
            content: dialogState == null
                ? AppWorkspaceStatePanel.loading(
                    title: dialogContext.l10n.physiotherapyDetailLoadingTitle,
                    body: dialogContext.l10n.physiotherapyDetailLoadingBody,
                  )
                : _buildDetail(
                    dialogContext,
                    dialogRef,
                    dialogRef.read(
                      physiotherapyWorkspaceControllerProvider.notifier,
                    ),
                    dialogState,
                    omitNextActionKind: therapyResolveNextActionKind(item),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    PhysiotherapyWorkspaceController controller,
    PhysiotherapyWorkspaceState detailState, {
    TherapyNextActionKind? omitNextActionKind,
  }) {
    final l10n = context.l10n;
    if (detailState.isRefreshingDetail) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.physiotherapyDetailLoadingTitle,
        body: l10n.physiotherapyDetailLoadingBody,
      );
    }
    final PhysiotherapyDetail? detail = detailState.selectedDetail;
    if (detail == null) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.physiotherapyNoSelectionTitle,
        body: l10n.physiotherapyNoSelectionBody,
      );
    }

    final TherapyWorkItem item = detail.item;
    final TherapyNextActionKind omit =
        omitNextActionKind ?? therapyResolveNextActionKind(item);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    // Detail may open from any tab; billing chip uses shared billing ∩ helper
    // (identical to Completed/ActivePlans [billingChip]).
    final bool showBilling = canViewPhysiotherapyBilling(policy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: item.displayTitle,
          patientNumber: _value(item.patientPublicId, l10n),
          patientNumberLabel: l10n.physiotherapyPatientNumberLabel,
          ageLabel: item.displaySubtitle,
          showAvatar: false,
          status: _workspaceStatusForStatus(l10n, item.status),
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.physiotherapyEncounterLabel,
              value: item.encounterPublicId ?? '',
              icon: Icons.medical_information_outlined,
              copyable: true,
              copyTooltip: l10n.opdCopyEncounterIdAction,
              copiedMessage: l10n.opdEncounterIdCopiedMessage,
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
            if (showBilling)
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
          isSaving: detailState.isSaving,
          omitNextActionKind: omit,
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
        if (detail.hasUnavailableWorkflows) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _UnavailableWorkflowsPanel(detail: detail),
        ],
      ],
    );
  }

  List<AppListTableColumn<TherapyWorkItem>> _columns(
    BuildContext context,
    Locale locale,
    WidgetRef ref,
  ) {
    final l10n = context.l10n;
    return <AppListTableColumn<TherapyWorkItem>>[
      AppListTableColumn<TherapyWorkItem>(
        id: 'patient',
        label: l10n.physiotherapyPatientColumnLabel,
        alwaysVisible: true,
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
        alwaysVisible: true,
        cellBuilder: (BuildContext context, TherapyWorkItem item) =>
            AppWorkspaceStatusBadge(
              status: _workspaceStatusForStatus(l10n, item.status),
            ),
      ),
      AppListTableColumn<TherapyWorkItem>(
        id: 'next_action',
        label: l10n.physiotherapyNextActionColumnLabel,
        alwaysVisible: true,
        sortComparator: (TherapyWorkItem left, TherapyWorkItem right) =>
            appListTableCompareText(
              therapyNextActionLabel(l10n, left.status),
              therapyNextActionLabel(l10n, right.status),
            ),
        cellBuilder: (BuildContext context, TherapyWorkItem item) {
          return TherapyNextActionButton(
            item: item,
            onPressed: () => _runTherapyNextAction(context, ref, item),
          );
        },
      ),
    ];
  }

  List<AppListTableColumn<TherapyWorkItem>> _optionalColumns(
    BuildContext context,
    Locale locale,
    AppAccessPolicy policy,
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
      if (_billingColumnAllowed(policy, section))
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


class _ActionsPanel extends ConsumerWidget {
  const _ActionsPanel({
    required this.detail,
    required this.isSaving,
    required this.omitNextActionKind,
    required this.onActionFailure,
    required this.onActionSaved,
  });

  final PhysiotherapyDetail detail;
  final bool isSaving;
  final TherapyNextActionKind omitNextActionKind;
  final ValueChanged<AppFailure> onActionFailure;
  final VoidCallback onActionSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(
      physiotherapyWorkspaceControllerProvider.notifier,
    );
    final TherapyWorkItem item = detail.item;
    final TherapyNextActionKind omit = omitNextActionKind;
    final bool canSchedule = item.apiPatientId != null;
    final bool canMarkAttendance = item.hasAppointment;

    return AppQuickActions(
      title: l10n.physiotherapyActionsTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      permissionActions: <AppPermissionActionItem>[
        if (omit != TherapyNextActionKind.acceptReferral)
          AppPermissionActionItem(
            requirement: PhysiotherapyReferralsAtomPermissions.acceptReferral,
            label: l10n.physiotherapyAcceptReferralAction,
            icon: Icons.assignment_turned_in_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    await _openFreeTextAction(
                      context,
                      title: l10n.physiotherapyAcceptReferralDialogTitle,
                      label: l10n.physiotherapyNoteFieldLabel,
                      submitLabel: l10n.physiotherapySaveAction,
                      initialValue: item.referralReason,
                      maxLines: 4,
                      isRequired: false,
                      onSubmit: controller.acceptReferral,
                    );
                  },
          ),
        if (omit != TherapyNextActionKind.scheduleSession && canSchedule)
          AppPermissionActionItem(
            requirement: physiotherapyWorkspaceWriteRequirement,
            label: l10n.physiotherapyScheduleSessionAction,
            icon: Icons.event_available_outlined,
            isLoading: isSaving,
            onPressed: isSaving
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
        if (omit != TherapyNextActionKind.recordAssessment)
          AppPermissionActionItem(
            requirement: physiotherapyWorkspaceWriteRequirement,
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
        if (omit != TherapyNextActionKind.recordSession)
          AppPermissionActionItem(
            requirement: PhysiotherapyTodayAtomPermissions.recordSession,
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
        if (omit != TherapyNextActionKind.markAttendance && canMarkAttendance)
          AppPermissionActionItem(
            requirement: PhysiotherapyMissedAtomPermissions.markAttendance,
            label: l10n.physiotherapyMarkAttendanceAction,
            icon: Icons.fact_check_outlined,
            isLoading: isSaving,
            onPressed: isSaving
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
          requirement: physiotherapyWorkspaceWriteRequirement,
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
          requirement: physiotherapyWorkspaceWriteRequirement,
          label: l10n.physiotherapyAddProgressNoteAction,
          icon: Icons.note_add_outlined,
          isLoading: isSaving,
          onPressed: isSaving
              ? null
              : () async {
                  await _openFreeTextAction(
                    context,
                    title: l10n.physiotherapyAddProgressNoteDialogTitle,
                    label: l10n.physiotherapyNoteFieldLabel,
                    submitLabel: l10n.physiotherapySaveAction,
                    onSubmit: controller.addProgressNote,
                  );
                },
        ),
        if (omit != TherapyNextActionKind.scheduleFollowUp)
          AppPermissionActionItem(
            // Active plans / Follow-up due share Schedule follow-up (identical
            // write ∩); Follow-up due atom map is the inventory gate here.
            requirement:
                PhysiotherapyFollowUpDueAtomPermissions.scheduleFollowUp,
            label: l10n.physiotherapyScheduleFollowUpAction,
            icon: Icons.notification_add_outlined,
            isLoading: isSaving,
            onPressed: isSaving
                ? null
                : () async {
                    final bool? saved = await showAppDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ClinicalFollowUpActionDialog(
                        title: l10n.physiotherapyScheduleFollowUpDialogTitle,
                        submitLabel: l10n.physiotherapySaveAction,
                        icon: const Icon(Icons.notification_add_outlined),
                        dateLabel: l10n.physiotherapyDateFieldLabel,
                        timeLabel: l10n.physiotherapyTimeFieldLabel,
                        notesLabel: l10n.physiotherapyNoteFieldLabel,
                        datePickerButtonLabel: l10n.patientsDatePickerAction,
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 3),
                        ),
                        onSubmit:
                            ({
                              required DateTime scheduledAt,
                              required String notes,
                            }) {
                              return controller.scheduleFollowUp(
                                scheduledAt: scheduledAt,
                                notes: notes,
                              );
                            },
                      ),
                    );
                    if (saved == true && context.mounted) {
                      onActionSaved();
                    }
                  },
          ),
        AppPermissionActionItem(
          requirement: physiotherapyWorkspaceWriteRequirement,
          label: l10n.physiotherapyCloseEpisodeAction,
          icon: Icons.task_alt_outlined,
          isLoading: isSaving,
          onPressed: isSaving
              ? null
              : () async {
                  await _openFreeTextAction(
                    context,
                    title: l10n.physiotherapyCloseEpisodeDialogTitle,
                    label: l10n.physiotherapySummaryFieldLabel,
                    submitLabel: l10n.physiotherapySaveAction,
                    onSubmit: controller.closeEpisode,
                  );
                },
        ),
        if (omit != TherapyNextActionKind.printInstructions)
          AppPermissionActionItem(
            // Print is read ∪ — Completed owns row next-action; Today/others ≡.
            requirement:
                PhysiotherapyCompletedAtomPermissions.printInstructions,
            label: l10n.physiotherapyPrintInstructionsAction,
            icon: Icons.print_outlined,
            onPressed: () {
              _printInstructions(context, ref, detail);
            },
          ),
      ],
    );
  }

  Future<void> _openFreeTextAction(
    BuildContext context, {
    required String title,
    required String label,
    required String submitLabel,
    required Future<AppFailure?> Function(String value) onSubmit,
    String? initialValue,
    int maxLines = 5,
    bool isRequired = true,
  }) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: title,
        label: label,
        submitLabel: submitLabel,
        initialValue: initialValue,
        minLines: 3,
        maxLines: maxLines,
        isRequired: isRequired,
        onSubmit: onSubmit,
      ),
    );
    if (saved == true && context.mounted) {
      onActionSaved();
    }
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

class _UnavailableWorkflowsPanel extends StatelessWidget {
  const _UnavailableWorkflowsPanel({required this.detail});

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
          for (final String code in detail.unavailableWorkflows)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline),
                  SizedBox(width: Theme.of(context).spacing.sm),
                  Expanded(child: Text(_unavailableWorkflowLabel(l10n, code))),
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
  late AppTimeValue _startTime;
  late DateTime _endDate;
  late AppTimeValue _endTime;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now().add(const Duration(hours: 1));
    final DateTime end = now.add(const Duration(minutes: 45));
    _startDate = now;
    _startTime = AppTimeValue.fromTimeOfDay(TimeOfDay.fromDateTime(now));
    _endDate = end;
    _endTime = AppTimeValue.fromTimeOfDay(TimeOfDay.fromDateTime(end));
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
              hourLabelText: l10n.appTimeHourLabel,
              minuteLabelText: l10n.appTimeMinuteLabel,
              isRequired: true,
              validator: AppValidators.requiredValue<AppTimeValue>(
                l10n.validationRequired,
              ),
              onChanged: (AppTimeValue? value) {
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
              hourLabelText: l10n.appTimeHourLabel,
              minuteLabelText: l10n.appTimeMinuteLabel,
              isRequired: true,
              validator: AppValidators.requiredValue<AppTimeValue>(
                l10n.validationRequired,
              ),
              onChanged: (AppTimeValue? value) {
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

List<AppSearchBarFilterGroup> _filterGroups(
  AppLocalizations l10n,
  PhysiotherapyQueueScope section,
) {
  return <AppSearchBarFilterGroup>[
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
    if (physiotherapyScopeAllowsStatusFilter(section))
      AppSearchBarFilterGroup(
        key: 'status',
        label: l10n.physiotherapyStatusLabel,
        allLabel: l10n.physiotherapyFilterAll,
        choices: <AppSearchBarFilterChoice>[
          for (final String value in physiotherapyStatusFilterValues(section))
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
  PhysiotherapyQueueScope section,
) {
  final bool includeStatus = physiotherapyScopeAllowsStatusFilter(section);
  return AppSearchBarFilterValue(
    field: query.filters.searchField,
    dateFrom: query.filters.dateFrom,
    dateTo: query.filters.dateTo,
    texts: <String, String>{
      if ((query.filters.therapist ?? '').trim().isNotEmpty)
        'therapist': query.filters.therapist!.trim(),
    },
    options: <String, String>{
      if ((query.filters.source ?? '').trim().isNotEmpty)
        'source': query.filters.source!.trim(),
      if (includeStatus && (query.filters.status ?? '').trim().isNotEmpty)
        'status': query.filters.status!.trim(),
      if ((query.filters.attendance ?? '').trim().isNotEmpty)
        'attendance': query.filters.attendance!.trim(),
    },
  );
}

PhysiotherapyWorklistFilters _filtersFromValue(
  AppSearchBarFilterValue value,
  PhysiotherapyQueueScope section,
) {
  return PhysiotherapyWorklistFilters(
    searchField: value.field,
    source: value.option('source'),
    status: physiotherapyScopeAllowsStatusFilter(section)
        ? value.option('status')
        : null,
    attendance: value.option('attendance'),
    therapist: value.text('therapist'),
    dateFrom: value.dateFrom,
    dateTo: value.dateTo,
  );
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
    'UNAVAILABLE' => l10n.physiotherapyBillingBackendGap,
    _ => l10n.physiotherapyMissingValueLabel,
  };
}

String _unavailableWorkflowLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'THERAPY_STATUS_UNAVAILABLE' => l10n.physiotherapyBackendGapStatusEndpoint,
    'BILLING_AUTHORIZATION_UNAVAILABLE' =>
      l10n.physiotherapyBackendGapBillingEndpoint,
    'THERAPY_REPORT_UNAVAILABLE' => l10n.physiotherapyBackendGapReportEndpoint,
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

/// Billing column / mobile meta — queue tab atom maps reuse
/// [physiotherapyBillingReadRequirement] (∩ `billing:read` + `billing-payments`).
bool _billingColumnAllowed(
  AppAccessPolicy policy,
  PhysiotherapyQueueScope section,
) {
  return switch (section) {
    PhysiotherapyQueueScope.referrals =>
      PhysiotherapyReferralsAtomPermissions.billingColumn.isAllowed(policy),
    PhysiotherapyQueueScope.today =>
      PhysiotherapyTodayAtomPermissions.billingColumn.isAllowed(policy),
    PhysiotherapyQueueScope.completed =>
      PhysiotherapyCompletedAtomPermissions.billingColumn.isAllowed(policy),
    PhysiotherapyQueueScope.activePlans =>
      PhysiotherapyActivePlansAtomPermissions.billingColumn.isAllowed(policy),
    PhysiotherapyQueueScope.followUpDue =>
      PhysiotherapyFollowUpDueAtomPermissions.billingColumn.isAllowed(policy),
    PhysiotherapyQueueScope.missed =>
      PhysiotherapyMissedAtomPermissions.billingColumn.isAllowed(policy),
    _ => canViewPhysiotherapyBilling(policy),
  };
}

DateTime _combineDateTime(DateTime date, AppTimeValue time) {
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
          value: item.encounterPublicId ?? l10n.profileUnknownValue,
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
    patientContext: buildPrintFormPatientContext(
      l10n,
      patientName: item.displayTitle,
      patientId: item.patientId ?? item.patientPublicId,
      encounterId: item.encounterPublicId,
      patientNameLabel: l10n.physiotherapyReportPatientLabel,
      encounterIdLabel: l10n.physiotherapyReportEncounterLabel,
    ),
    bodyHtml: bodyHtml,
    footerNote: l10n.physiotherapyReportFooterNote,
    includeSignatures: true,
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
