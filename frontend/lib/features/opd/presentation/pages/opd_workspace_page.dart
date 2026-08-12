import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/opd_access.dart';
import 'package:hosspi_hms/features/opd/presentation/widgets/opd_workspace_print_helpers.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

class OpdWorkspacePage extends ConsumerWidget {
  const OpdWorkspacePage({this.initialQuery, super.key});

  final OpdWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> state = ref.watch(
      opdWorkspaceControllerProvider,
    );

    return AppAccessGate(
      requirement: opdWorkspaceReadRequirement,
      deniedBuilder: (_, _) => AppStateScaffold(
        variant: AppStateViewVariant.forbidden,
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
      ),
      child: AsyncStateScaffold<OpdWorkspaceState>(
        value: state,
        loadingTitle: l10n.opdLoadingTitle,
        loadingBody: l10n.opdLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        scrollable: false,
        onRetry: () {
          ref.read(opdWorkspaceControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, OpdWorkspaceState data) {
          return _OpdWorkspaceContent(state: data, initialQuery: initialQuery);
        },
      ),
    );
  }
}

class _OpdWorkspaceContent extends ConsumerStatefulWidget {
  const _OpdWorkspaceContent({required this.state, this.initialQuery});

  final OpdWorkspaceState state;
  final OpdWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_OpdWorkspaceContent> createState() =>
      _OpdWorkspaceContentState();
}

class _OpdWorkspaceContentState extends ConsumerState<_OpdWorkspaceContent> {
  final ValueNotifier<_OpdTableFilter> _filterNotifier =
      ValueNotifier<_OpdTableFilter>(const _OpdTableFilter());
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<_OpdTableItem>
  _tableColumnController;
  final ValueNotifier<AppPageRequest> _tablePageNotifier =
      ValueNotifier<AppPageRequest>(const AppPageRequest(pageSize: 12));
  late OpdWorkspaceSection _section;
  String? _appliedRouteSignature;
  /// When Follow-ups is active and search/filters narrow the list, badge uses
  /// this membership length; `null` means use [followUpTabCountProvider].
  int? _followUpsNarrowedCount;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tableColumnController =
        AppListTableColumnVisibilityController<_OpdTableItem>();
    _section = widget.initialQuery?.section ?? OpdWorkspaceSection.all;
    _searchController.addListener(_resetTablePage);
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _OpdWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_resetTablePage)
      ..dispose();
    _tableColumnController.dispose();
    _filterNotifier.dispose();
    _tablePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final OpdWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<OpdWorkspaceSection> visibleSections = opdAllowedSections(
      accessPolicy,
    );
    if (visibleSections.isEmpty) {
      return AppStateView(
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
        variant: AppStateViewVariant.forbidden,
      );
    }
    if (!visibleSections.contains(_section)) {
      final OpdWorkspaceSection fallback =
          opdFallbackSection(accessPolicy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        _handleTabChanged(fallback);
      });
    }
    final List<_OpdTableItem> allItems = _tableItems(context, state);

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: ValueListenableBuilder<_OpdTableFilter>(
        valueListenable: _filterNotifier,
        builder: (BuildContext context, _OpdTableFilter filter, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTabStrip(
                tabs: <AppTabItem>[
                  for (final OpdWorkspaceSection section in visibleSections)
                    AppTabItem(
                      id: section.name,
                      icon: _opdSectionIcon(section),
                      label: _opdSectionLabel(l10n, section),
                      count: section == OpdWorkspaceSection.followUps
                          ? (_section == OpdWorkspaceSection.followUps &&
                                    _followUpsNarrowedCount != null
                                ? _followUpsNarrowedCount
                                : ref.watch(
                                    followUpTabCountProvider(
                                      const FollowUpWorklistScope(
                                        encounterType: 'OPD',
                                      ),
                                    ),
                                  ))
                          : _opdSectionCount(
                              state,
                              section,
                              allItems,
                              activeSection: _section,
                              filter: filter,
                            ),
                      countTone: _opdSectionCountTone(section),
                    ),
                ],
                selectedId: _section.name,
                onTabTapped: (String tabId) {
                  for (final OpdWorkspaceSection section in visibleSections) {
                    if (section.name == tabId) {
                      _handleTabChanged(section);
                      break;
                    }
                  }
                },
              ),
              SizedBox(height: theme.spacing.sm),
              Expanded(
                child: ValueListenableBuilder<AppPageRequest>(
                  valueListenable: _tablePageNotifier,
                  builder:
                      (
                        BuildContext context,
                        AppPageRequest tablePageRequest,
                        _,
                      ) {
                        return _OpdWorkspaceBody(
                          state: state,
                          section: _section,
                          filter: filter,
                          searchController: _searchController,
                          columnVisibilityController: _tableColumnController,
                          pageRequest: tablePageRequest,
                          onPageChanged: _setTablePage,
                          onFilterChanged: _setFilter,
                          onFollowUpsNarrowedCountChanged:
                              (int? narrowedCount) {
                                if (_followUpsNarrowedCount == narrowedCount) {
                                  return;
                                }
                                setState(() {
                                  _followUpsNarrowedCount = narrowedCount;
                                });
                              },
                        );
                      },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _setFilter(_OpdTableFilter filter) {
    if (_filterNotifier.value == filter) {
      return;
    }
    _filterNotifier.value = filter;
    _tablePageNotifier.value = _tablePageNotifier.value.first();
  }

  void _handleTabChanged(OpdWorkspaceSection section) {
    if (section == _section) {
      return;
    }
    setState(() {
      _section = section;
      _followUpsNarrowedCount = null;
    });
    _updateUrlForSection(section);
    _setFilter(const _OpdTableFilter());
    _searchController.clear();
  }

  void _updateUrlForSection(OpdWorkspaceSection section) {
    if (!mounted) {
      return;
    }
    final String tab = _opdSectionQueryValue(section);
    final String location = AppRoutes.opd.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    syncWorkspaceLocation(context, location);
  }

  void _setTablePage(AppPageRequest request) {
    if (_tablePageNotifier.value == request) {
      return;
    }
    _tablePageNotifier.value = request;
  }

  void _resetTablePage() {
    final AppPageRequest firstPage = _tablePageNotifier.value.first();
    if (_tablePageNotifier.value != firstPage) {
      _tablePageNotifier.value = firstPage;
    }
  }

  void _scheduleRouteQuery(OpdWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(OpdWorkspaceQuery query) async {
    if (query.section != OpdWorkspaceSection.all && query.section != _section) {
      setState(() => _section = query.section);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }
    if (query.search.isNotEmpty || query.panel.isNotEmpty) {
      final _OpdTableFilter panelFilter = _opdFilterForPanel(query.panel);
      _setFilter(panelFilter.copyWith(search: query.search));
    }
    if (query.flowId.isNotEmpty) {
      await _openFlowById(query.flowId, panel: query.panel);
    }
  }

  Future<void> _openFlowById(String identifier, {String panel = ''}) async {
    final OpdFlowSummary? flow = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .resolveFlowById(identifier);
    if (!mounted || flow == null) {
      return;
    }

    final OpdBoardNextActionKind? panelKind = opdBoardNextActionKindFromPanel(
      panel,
    );
    if (panelKind != null && panelKind != OpdBoardNextActionKind.none) {
      final AccessRequirement? panelRequirement = opdFocusedPanelRequirement(
        panel,
      );
      final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
      if (panelRequirement != null && !panelRequirement.isAllowed(policy)) {
        return;
      }
      final bool? changed = await runOpdBoardNextAction(
        context: context,
        ref: ref,
        flow: flow,
        kind: panelKind,
      );
      if (changed == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      }
      return;
    }

    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final AccessRequirement detailRequirement = switch (_section) {
      OpdWorkspaceSection.active => OpdActiveAtomPermissions.detail,
      OpdWorkspaceSection.arrivals => OpdArrivalsAtomPermissions.detail,
      OpdWorkspaceSection.followUps => OpdFollowUpsAtomPermissions.detail,
      OpdWorkspaceSection.queue => OpdQueueAtomPermissions.detail,
      OpdWorkspaceSection.triage => OpdTriageAtomPermissions.detail,
      OpdWorkspaceSection.all => OpdAllAtomPermissions.detail,
    };
    if (!detailRequirement.isAllowed(policy)) {
      return;
    }

    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: flow,
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _OpdWorkspaceBody extends StatefulWidget {
  const _OpdWorkspaceBody({
    required this.state,
    required this.section,
    required this.filter,
    required this.searchController,
    required this.columnVisibilityController,
    required this.pageRequest,
    required this.onPageChanged,
    required this.onFilterChanged,
    this.onFollowUpsNarrowedCountChanged,
  });

  final OpdWorkspaceState state;
  final OpdWorkspaceSection section;
  final _OpdTableFilter filter;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<_OpdTableItem>
  columnVisibilityController;
  final AppPageRequest pageRequest;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;
  final ValueChanged<int?>? onFollowUpsNarrowedCountChanged;

  @override
  State<_OpdWorkspaceBody> createState() => _OpdWorkspaceBodyState();
}

class _OpdWorkspaceBodyState extends State<_OpdWorkspaceBody> {
  List<_OpdTableItem>? _cachedAllItems;
  OpdWorkspaceState? _cachedState;

  List<_OpdTableItem> _getAllItems(BuildContext context) {
    if (!identical(_cachedState, widget.state) || _cachedAllItems == null) {
      _cachedAllItems = _tableItems(context, widget.state);
      _cachedState = widget.state;
    }
    return _cachedAllItems!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section == OpdWorkspaceSection.followUps) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AppLocalizations l10n = context.l10n;
          final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
          return FollowUpWorklistPanel(
            scope: const FollowUpWorklistScope(encounterType: 'OPD'),
            storageKeyPrefix: 'opd_follow_ups',
            readRequirement: OpdFollowUpsAtomPermissions.tab,
            writeRequirement: OpdFollowUpsAtomPermissions.write,
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
            advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            advancedFilterCloseLabel: l10n.commonCloseActionLabel,
            enableDateFilter: true,
            dateFilterLabel: l10n.opdArrivalDateFilterLabel,
            dateFromLabel: l10n.opdDateFromLabel,
            dateToLabel: l10n.opdDateToLabel,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: 'follow_up_status',
                label: l10n.receptionStatusLabel,
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(
                    value: 'pending',
                    label: l10n.patientsActiveWorkStatusAppointmentScheduled,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'completed',
                    label: l10n.opdCompletedFlowSummaryLabel,
                  ),
                ],
              ),
            ],
            canExport: canExportOpdWorkspace(policy),
            enablePrint: true,
            canPrint: canPrintOpdWorkspace(policy),
            printLabel: l10n.commonPrintActionLabel,
            onPrint: (entries) => _printOpdFollowUpsList(
              context,
              ref,
              entries: entries,
              l10n: l10n,
            ),
            onNarrowedCountChanged: widget.onFollowUpsNarrowedCountChanged,
          );
        },
      );
    }
    final List<_OpdTableItem> allItems = _getAllItems(context);
    final String? sectionCategory = _opdSectionCategory(widget.section);
    final List<_OpdTableItem> sectionItems = sectionCategory == null
        ? allItems
        : allItems
              .where((_OpdTableItem item) => item.category == sectionCategory)
              .toList(growable: false);
    final List<_OpdTableItem> items = sectionItems
        .where((_OpdTableItem item) => widget.filter.matches(item))
        .toList(growable: false);

    return _OpdMainTable(
      state: widget.state,
      section: widget.section,
      page: _tablePage(items, widget.pageRequest),
      searchController: widget.searchController,
      columnVisibilityController: widget.columnVisibilityController,
      filter: widget.filter,
      filterItems: sectionItems,
      statuses: _tableStatuses(sectionItems),
      onPageChanged: widget.onPageChanged,
      onFilterChanged: widget.onFilterChanged,
      isLoading:
          widget.state.isRefreshingAppointments ||
          widget.state.isRefreshingQueue ||
          widget.state.isRefreshingFlows ||
          widget.state.isRefreshingTriageQueue,
    );
  }
}

AppPage<_OpdTableItem> _tablePage(
  List<_OpdTableItem> items,
  AppPageRequest request,
) {
  final int total = items.length;
  final int start = request.offset.clamp(0, total).toInt();
  final int end = (start + request.pageSize).clamp(start, total).toInt();

  return AppPage<_OpdTableItem>(
    items: items.sublist(start, end),
    request: request,
    totalItemCount: total,
  );
}

List<String> _tableStatuses(List<_OpdTableItem> items) {
  return items
      .map((_OpdTableItem item) => item.status)
      .whereType<String>()
      .where((String value) => value.trim().isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
}

List<AppSelectOption<String>> _categoryFilterOptions(BuildContext context) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllCategoriesOption,
    ),
    AppSelectOption<String>(
      value: _opdCategoryArrival,
      label: l10n.opdArrivalsSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryQueue,
      label: l10n.opdQueueSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryTriage,
      label: l10n.opdWorkflowTriageTitle,
    ),
    AppSelectOption<String>(
      value: _opdCategoryActiveFlow,
      label: l10n.opdActiveFlowSummaryLabel,
    ),
  ];
}

List<AppSelectOption<String>> _triageScopeFilterOptions(BuildContext context) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllTriageScopesOption,
    ),
    AppSelectOption<String>(
      value: _triageScopeWaiting,
      label: l10n.opdTriageScopeWaiting,
    ),
    AppSelectOption<String>(
      value: _triageScopeUrgent,
      label: l10n.opdTriageScopeUrgent,
    ),
    AppSelectOption<String>(
      value: _triageScopeEmergency,
      label: l10n.opdTriageScopeEmergency,
    ),
    AppSelectOption<String>(
      value: _triageScopeRoutine,
      label: l10n.opdTriageScopeRoutine,
    ),
    AppSelectOption<String>(
      value: _triageScopeServiceOnly,
      label: l10n.opdTriageScopeServiceOnly,
    ),
  ];
}

@immutable
final class _OpdTableFilter {
  const _OpdTableFilter({
    this.search = '',
    this.searchField,
    this.dateFrom,
    this.dateTo,
    this.datePreset,
    this.category,
    this.status,
    this.statuses = const <String>{},
    this.triageScope,
    this.visitType,
    this.queue,
    this.provider,
    this.billingState,
    this.nextAction,
  });

  final String search;
  final String? searchField;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? datePreset;
  final String? category;
  final String? status;
  final Set<String> statuses;
  final String? triageScope;
  final String? visitType;
  final String? queue;
  final String? provider;
  final String? billingState;
  final String? nextAction;

  bool get isActive =>
      search.trim().isNotEmpty ||
      _isNonEmpty(searchField) ||
      dateFrom != null ||
      dateTo != null ||
      _isNonEmpty(datePreset) ||
      _isNonEmpty(category) ||
      _isNonEmpty(status) ||
      statuses.isNotEmpty ||
      _isNonEmpty(triageScope) ||
      _isNonEmpty(visitType) ||
      _isNonEmpty(queue) ||
      _isNonEmpty(provider) ||
      _isNonEmpty(billingState) ||
      _isNonEmpty(nextAction);

  bool get hasAdvancedFilters =>
      _isNonEmpty(searchField) ||
      dateFrom != null ||
      dateTo != null ||
      _isNonEmpty(datePreset) ||
      _isNonEmpty(category) ||
      _isNonEmpty(status) ||
      statuses.isNotEmpty ||
      _isNonEmpty(triageScope) ||
      _isNonEmpty(visitType) ||
      _isNonEmpty(queue) ||
      _isNonEmpty(provider) ||
      _isNonEmpty(billingState) ||
      _isNonEmpty(nextAction);

  AppSearchBarFilterValue toSearchBarValue() {
    return AppSearchBarFilterValue(
      field: searchField,
      dateFrom: dateFrom,
      dateTo: dateTo,
      options: <String, String>{
        if (_isNonEmpty(category)) _opdFilterKeyCategory: category!,
        if (_isNonEmpty(datePreset))
          _opdFilterKeyArrivalDatePreset: datePreset!,
        if (_isNonEmpty(status)) _opdFilterKeyStatus: status!,
        if (_isNonEmpty(triageScope)) _opdFilterKeyTriageScope: triageScope!,
        if (_isNonEmpty(visitType)) _opdFilterKeyVisitType: visitType!,
        if (_isNonEmpty(queue)) _opdFilterKeyQueue: queue!,
        if (_isNonEmpty(provider)) _opdFilterKeyProvider: provider!,
        if (_isNonEmpty(billingState)) _opdFilterKeyBilling: billingState!,
        if (_isNonEmpty(nextAction)) _opdFilterKeyNextAction: nextAction!,
      },
    );
  }

  static _OpdTableFilter fromSearchBarValue(
    AppSearchBarFilterValue value, {
    String search = '',
  }) {
    return _OpdTableFilter(
      search: search,
      searchField: value.field,
      dateFrom: value.dateFrom,
      dateTo: value.dateTo,
      datePreset: value.option(_opdFilterKeyArrivalDatePreset),
      category: value.option(_opdFilterKeyCategory),
      status: value.option(_opdFilterKeyStatus),
      triageScope: value.option(_opdFilterKeyTriageScope),
      visitType: value.option(_opdFilterKeyVisitType),
      queue: value.option(_opdFilterKeyQueue),
      provider: value.option(_opdFilterKeyProvider),
      billingState: value.option(_opdFilterKeyBilling),
      nextAction: value.option(_opdFilterKeyNextAction),
    );
  }

  _OpdTableFilter copyWith({
    String? search,
    String? searchField,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? datePreset,
    String? category,
    String? status,
    Set<String>? statuses,
    String? triageScope,
    String? visitType,
    String? queue,
    String? provider,
    String? billingState,
    String? nextAction,
    bool clearSearch = false,
    bool clearSearchField = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearDatePreset = false,
    bool clearCategory = false,
    bool clearStatus = false,
    bool clearStatuses = false,
    bool clearTriageScope = false,
    bool clearVisitType = false,
    bool clearQueue = false,
    bool clearProvider = false,
    bool clearBillingState = false,
    bool clearNextAction = false,
  }) {
    return _OpdTableFilter(
      search: clearSearch ? '' : search ?? this.search,
      searchField: clearSearchField ? null : searchField ?? this.searchField,
      dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
      datePreset: clearDatePreset ? null : datePreset ?? this.datePreset,
      category: clearCategory ? null : category ?? this.category,
      status: clearStatus ? null : status ?? this.status,
      statuses: clearStatuses ? const <String>{} : statuses ?? this.statuses,
      triageScope: clearTriageScope ? null : triageScope ?? this.triageScope,
      visitType: clearVisitType ? null : visitType ?? this.visitType,
      queue: clearQueue ? null : queue ?? this.queue,
      provider: clearProvider ? null : provider ?? this.provider,
      billingState: clearBillingState
          ? null
          : billingState ?? this.billingState,
      nextAction: clearNextAction ? null : nextAction ?? this.nextAction,
    );
  }

  bool matches(_OpdTableItem item) {
    if (!item.matches(search, field: searchField)) {
      return false;
    }
    if (!_matchesDateRange(item.time, dateFrom: dateFrom, dateTo: dateTo)) {
      return false;
    }
    final _OpdDateRange? presetRange = _datePresetRange(datePreset);
    if (presetRange != null &&
        !_matchesDateRange(
          item.time,
          dateFrom: presetRange.from,
          dateTo: presetRange.to,
        )) {
      return false;
    }
    if (_isNonEmpty(category) && item.category != category) {
      return false;
    }
    if (_isNonEmpty(status) && item.status != status) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(item.status)) {
      return false;
    }
    if (_isNonEmpty(triageScope) && !_matchesTriageScope(item, triageScope!)) {
      return false;
    }
    if (_isNonEmpty(visitType) && item.visitType != visitType) {
      return false;
    }
    if (_isNonEmpty(queue) && item.queue != queue) {
      return false;
    }
    if (_isNonEmpty(provider) && item.provider != provider) {
      return false;
    }
    if (_isNonEmpty(billingState) && item.billingState != billingState) {
      return false;
    }
    if (_isNonEmpty(nextAction) && _nextActionFilterValue(item) != nextAction) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is _OpdTableFilter &&
        other.search == search &&
        other.searchField == searchField &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.datePreset == datePreset &&
        other.category == category &&
        other.status == status &&
        setEquals(other.statuses, statuses) &&
        other.triageScope == triageScope &&
        other.visitType == visitType &&
        other.queue == queue &&
        other.provider == provider &&
        other.billingState == billingState &&
        other.nextAction == nextAction;
  }

  @override
  int get hashCode => Object.hash(
    search,
    searchField,
    dateFrom,
    dateTo,
    datePreset,
    category,
    status,
    Object.hashAllUnordered(statuses),
    triageScope,
    visitType,
    queue,
    provider,
    billingState,
    nextAction,
  );
}

List<AppSearchBarFilterGroup> _opdTableFilterGroups(
  BuildContext context,
  List<_OpdTableItem> items,
  List<String> statuses,
) {
  final l10n = context.l10n;
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _opdFilterKeyArrivalDatePreset,
      label: l10n.opdArrivalRangeFilterLabel,
      allLabel: l10n.opdAnyArrivalDateOption,
      choices: _arrivalDatePresetFilterChoices(context),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyCategory,
      label: l10n.opdCategoryFilterLabel,
      allLabel: l10n.opdAllCategoriesOption,
      choices: _categoryFilterOptions(context)
          .where(
            (AppSelectOption<String> option) => option.value != _opdFilterAll,
          )
          .map(
            (AppSelectOption<String> option) => AppSearchBarFilterChoice(
              value: option.value,
              label: option.label,
            ),
          )
          .toList(growable: false),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyVisitType,
      label: l10n.opdVisitTypeFilterLabel,
      allLabel: l10n.opdAllVisitTypesOption,
      choices: _textFilterChoices(
        items.map((_OpdTableItem item) => item.visitType),
      ),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyQueue,
      label: l10n.opdQueueFilterLabel,
      allLabel: l10n.opdAllQueuesOption,
      choices: _textFilterChoices(
        items.map((_OpdTableItem item) => item.queue),
      ),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyStatus,
      label: l10n.opdStatusFilterLabel,
      allLabel: l10n.opdAllStatusesOption,
      choices: statuses
          .map(
            (String status) => AppSearchBarFilterChoice(
              value: status,
              label: opdStageDisplayLabel(context.l10n, status),
            ),
          )
          .toList(growable: false),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyProvider,
      label: l10n.opdProviderFilterLabel,
      allLabel: l10n.opdAllProvidersOption,
      choices: _textFilterChoices(
        items.map((_OpdTableItem item) => item.provider),
      ),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyBilling,
      label: l10n.opdBillingFilterLabel,
      allLabel: l10n.opdAllBillingStatesOption,
      choices: _billingFilterChoices(context, items),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyNextAction,
      label: l10n.opdNextActionFilterLabel,
      allLabel: l10n.opdAllNextActionsOption,
      choices: _nextActionFilterChoices(context, items),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyTriageScope,
      label: l10n.opdTriageScopeFilterLabel,
      allLabel: l10n.opdAllTriageScopesOption,
      choices: _triageScopeFilterOptions(context)
          .where(
            (AppSelectOption<String> option) => option.value != _opdFilterAll,
          )
          .map(
            (AppSelectOption<String> option) => AppSearchBarFilterChoice(
              value: option.value,
              label: option.label,
            ),
          )
          .toList(growable: false),
    ),
  ];
}

List<AppSearchBarFieldChoice> _opdTableSearchFields(BuildContext context) {
  final l10n = context.l10n;
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: _opdSearchFieldPatient,
      label: l10n.opdPatientColumnLabel,
      icon: Icons.person_search_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldPatientId,
      label: l10n.patientsPatientNumberColumnLabel,
      icon: Icons.badge_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldEncounter,
      label: l10n.opdEncounterIdLabel,
      icon: Icons.tag_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldPhone,
      label: l10n.patientsPhoneLabel,
      icon: Icons.call_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldProvider,
      label: l10n.opdProviderColumnLabel,
      icon: Icons.assignment_ind_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldQueue,
      label: l10n.opdQueueFilterLabel,
      icon: Icons.queue_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldStatus,
      label: l10n.opdStatusFilterLabel,
      icon: Icons.fact_check_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldVisitType,
      label: l10n.opdVisitTypeFilterLabel,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldBilling,
      label: l10n.opdBillingFilterLabel,
      icon: Icons.payments_outlined,
    ),
    AppSearchBarFieldChoice(
      field: _opdSearchFieldNextAction,
      label: l10n.opdNextActionFilterLabel,
      icon: Icons.next_plan_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _arrivalDatePresetFilterChoices(
  BuildContext context,
) {
  final l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: _opdDatePresetToday,
      label: l10n.opdDatePresetToday,
      icon: Icons.today_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _opdDatePresetYesterday,
      label: l10n.opdDatePresetYesterday,
      icon: Icons.history_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _opdDatePresetLast7Days,
      label: l10n.opdDatePresetLast7Days,
      icon: Icons.date_range_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _opdDatePresetLast30Days,
      label: l10n.opdDatePresetLast30Days,
      icon: Icons.calendar_month_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _textFilterChoices(Iterable<String?> values) {
  final List<String> unique =
      values
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();

  return <AppSearchBarFilterChoice>[
    for (final String value in unique)
      AppSearchBarFilterChoice(value: value, label: value),
  ];
}

List<AppSearchBarFilterChoice> _billingFilterChoices(
  BuildContext context,
  List<_OpdTableItem> items,
) {
  final Set<String> present = items
      .map((_OpdTableItem item) => item.billingState)
      .where((String value) => value.trim().isNotEmpty)
      .toSet();
  final List<String> ordered = <String>[
    _opdBillingStateRequired,
    _opdBillingStatePaid,
    _opdBillingStateNotRequired,
    _opdBillingStateUnknown,
  ];

  return <AppSearchBarFilterChoice>[
    for (final String value in ordered)
      if (present.contains(value))
        AppSearchBarFilterChoice(
          value: value,
          label: _billingStateLabel(context, value),
        ),
  ];
}

List<AppSearchBarFilterChoice> _nextActionFilterChoices(
  BuildContext context,
  List<_OpdTableItem> items,
) {
  final List<String> unique =
      items
          .map(_nextActionFilterValue)
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort(
          (String left, String right) => opdNextStepDisplayLabel(
            context.l10n,
            left,
          ).compareTo(opdNextStepDisplayLabel(context.l10n, right)),
        );

  return <AppSearchBarFilterChoice>[
    for (final String value in unique)
      AppSearchBarFilterChoice(
        value: value,
        label: opdNextStepDisplayLabel(context.l10n, value),
      ),
  ];
}

@immutable
final class _OpdTableItem {
  const _OpdTableItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    this.patientNumber,
    this.patientName,
    this.arrivalMode,
    this.encounterId,
    this.visitType,
    this.queue,
    this.provider,
    this.ownerRole,
    this.facility,
    this.billing,
    this.billingState = _opdBillingStateUnknown,
    this.billingTone = AppWorkspaceStatusTone.neutral,
    this.nextStep,
    this.time,
    this.urgencyRank = _defaultUrgencyRank,
    this.appointment,
    this.queueEntry,
    this.flow,
  });

  final String id;
  final String title;
  final String category;
  final String? status;
  final String? patientNumber;
  final String? patientName;
  final String? arrivalMode;
  final String? encounterId;
  final String? visitType;
  final String? queue;
  final String? provider;
  final String? ownerRole;
  final String? facility;
  final String? billing;
  final String billingState;
  final AppWorkspaceStatusTone billingTone;
  final String? nextStep;
  final DateTime? time;
  final int urgencyRank;
  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;

  String get stableKey {
    final OpdFlowSummary? activeFlow = flow;
    final OpdQueueEntry? activeQueue = queueEntry;
    final OpdAppointment? activeAppointment = appointment;
    return activeFlow?.id ??
        activeFlow?.publicId ??
        activeQueue?.id ??
        activeQueue?.publicId ??
        activeAppointment?.id ??
        activeAppointment?.publicId ??
        id;
  }

  String get categoryKey => stableKey;

  bool matches(String search, {String? field}) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return _searchValuesForField(field).whereType<String>().any(
      (String value) => _searchValueMatches(value, needle),
    );
  }

  Iterable<String?> _searchValuesForField(String? field) {
    return switch (field) {
      _opdSearchFieldPatient => <String?>[
        patientName,
        title,
        appointment?.patientDisplayName,
        queueEntry?.patientDisplayName,
        flow?.patientDisplayName,
      ],
      _opdSearchFieldPatientId => <String?>[
        patientNumber,
        appointment?.patientId,
        appointment?.patientIdentifier,
        queueEntry?.patientId,
        queueEntry?.patientIdentifier,
        flow?.patientId,
        flow?.patientIdentifier,
      ],
      _opdSearchFieldEncounter => <String?>[
        encounterId,
        flow?.publicId,
        flow?.id,
      ],
      _opdSearchFieldPhone => <String?>[
        appointment?.patientPhone,
        queueEntry?.patientPhone,
        flow?.patientPhone,
      ],
      _opdSearchFieldProvider => <String?>[provider, ownerRole],
      _opdSearchFieldQueue => <String?>[category, queue, flow?.lastRouteTo],
      _opdSearchFieldStatus => <String?>[status, flow?.stage, flow?.status],
      _opdSearchFieldVisitType => <String?>[
        visitType,
        arrivalMode,
        flow?.arrivalMode,
      ],
      _opdSearchFieldBilling => <String?>[billing, billingState],
      _opdSearchFieldNextAction => <String?>[nextStep, status],
      _ => <String?>[
        id,
        title,
        patientName,
        patientNumber,
        arrivalMode,
        encounterId,
        category,
        status,
        visitType,
        queue,
        provider,
        ownerRole,
        facility,
        billing,
        billingState,
        nextStep,
        appointment?.patientId,
        appointment?.patientIdentifier,
        appointment?.patientPhone,
        appointment?.reason,
        queueEntry?.patientId,
        queueEntry?.patientIdentifier,
        queueEntry?.patientPhone,
        queueEntry?.appointmentReason,
        flow?.patientId,
        flow?.patientIdentifier,
        flow?.patientPhone,
        flow?.arrivalMode,
        flow?.publicId,
        flow?.stage,
        flow?.status,
        flow?.lastRouteTo,
      ],
    };
  }
}

String? _firstNonEmptyValue(Iterable<String?> values) {
  for (final String? value in values) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _resolveOpdPatientName(
  BuildContext context, {
  OpdFlowSummary? flow,
  OpdQueueEntry? queueEntry,
  OpdAppointment? appointment,
}) {
  return _firstNonEmptyValue(<String?>[
        flow?.patientDisplayName,
        queueEntry?.patientDisplayName,
        appointment?.patientDisplayName,
      ]) ??
      context.l10n.profileUnknownValue;
}

String? _resolveOpdPatientNumber({
  OpdFlowSummary? flow,
  OpdQueueEntry? queueEntry,
  OpdAppointment? appointment,
}) {
  return _firstNonEmptyValue(<String?>[
    flow?.patientIdentifier,
    queueEntry?.patientIdentifier,
    appointment?.patientIdentifier,
  ]);
}

String? _resolveOpdArrivalMode({
  OpdFlowSummary? flow,
  OpdQueueEntry? queueEntry,
  OpdAppointment? appointment,
  required String category,
}) {
  if (flow != null) {
    if (_isEmergencyFlow(flow)) {
      return 'EMERGENCY';
    }
    final String? arrivalMode = flow.arrivalMode?.trim();
    if (arrivalMode != null && arrivalMode.isNotEmpty) {
      return arrivalMode;
    }
  }
  if (appointment != null || queueEntry?.appointmentId != null) {
    return 'ONLINE_APPOINTMENT';
  }
  if (category == _opdCategoryArrival) {
    return 'ONLINE_APPOINTMENT';
  }
  return 'WALK_IN';
}

String? _resolveOpdEncounterId(OpdFlowSummary? flow) {
  if (flow == null) {
    return null;
  }
  return _firstNonEmptyValue(<String?>[flow.publicId, flow.id]);
}

List<_OpdTableItem> _tableItems(BuildContext context, OpdWorkspaceState state) {
  final Map<String, _OpdTableItem> activeItemsByFlow =
      <String, _OpdTableItem>{};
  final Set<String> activeVisitQueueKeys = <String>{};
  final Set<String> activeAppointmentKeys = <String>{};
  final List<_OpdTableItem> items = <_OpdTableItem>[];

  void upsertActiveFlowItem(_OpdTableItem item) {
    final OpdFlowSummary? flow = item.flow;
    if (flow != null) {
      activeVisitQueueKeys.addAll(_identityKeys(<String?>[flow.visitQueueId]));
      activeAppointmentKeys.addAll(
        _identityKeys(<String?>[flow.appointmentId]),
      );
    }
    final String key = item.stableKey;
    final _OpdTableItem? existing = activeItemsByFlow[key];
    if (existing == null || _preferOpdTableItem(item, existing)) {
      activeItemsByFlow[key] = item;
    }
  }

  for (final OpdFlowSummary flow in state.triageQueue.items) {
    if (flow.isTerminal || _isCompletedStatus(flow.status ?? flow.stage)) {
      continue;
    }
    final String patientName = _resolveOpdPatientName(context, flow: flow);
    final String? patientNumber = _resolveOpdPatientNumber(flow: flow);
    final String? arrivalMode = _resolveOpdArrivalMode(
      flow: flow,
      category: _opdCategoryTriage,
    );
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: patientName,
      patientName: patientName,
      patientNumber: patientNumber,
      arrivalMode: arrivalMode,
      encounterId: _resolveOpdEncounterId(flow),
      category: _opdCategoryTriage,
      status: flow.triageLevel ?? flow.displayCode ?? flow.stage,
      visitType: _flowVisitTypeLabel(context, flow),
      queue: _flowQueueLabel(context, flow),
      provider: flow.assignedStaffLabel ?? flow.providerDisplayName,
      ownerRole: _flowOwnerRole(context, flow),
      facility: flow.facilityName,
      billing: _flowBillingLabel(context, flow),
      billingState: _flowBillingState(flow),
      billingTone: _flowBillingTone(flow),
      nextStep: flow.displayNextStep ?? _triageNextStep(flow),
      time: flow.queuedAt ?? flow.startedAt,
      urgencyRank: _flowUrgencyRank(flow),
      flow: flow,
    );
    upsertActiveFlowItem(item);
  }

  for (final OpdFlowSummary flow in state.flows.items) {
    if (flow.isTerminal || _isCompletedStatus(flow.status ?? flow.stage)) {
      continue;
    }
    final String patientName = _resolveOpdPatientName(context, flow: flow);
    final String? patientNumber = _resolveOpdPatientNumber(flow: flow);
    final String? arrivalMode = _resolveOpdArrivalMode(
      flow: flow,
      category: _opdCategoryActiveFlow,
    );
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: patientName,
      patientName: patientName,
      patientNumber: patientNumber,
      arrivalMode: arrivalMode,
      encounterId: _resolveOpdEncounterId(flow),
      category: _opdCategoryActiveFlow,
      status: flow.displayCode ?? flow.stage,
      visitType: _flowVisitTypeLabel(context, flow),
      queue: _flowQueueLabel(context, flow),
      provider: flow.assignedStaffLabel ?? flow.providerDisplayName,
      ownerRole: _flowOwnerRole(context, flow),
      facility: flow.facilityName,
      billing: _flowBillingLabel(context, flow),
      billingState: _flowBillingState(flow),
      billingTone: _flowBillingTone(flow),
      nextStep: flow.displayNextStep ?? flow.nextStep,
      time: flow.queuedAt ?? flow.startedAt,
      urgencyRank: _flowUrgencyRank(flow),
      flow: flow,
    );
    upsertActiveFlowItem(item);
  }

  items.addAll(activeItemsByFlow.values);

  for (final OpdQueueEntry entry in state.queueEntries.items) {
    if (_isCompletedStatus(entry.status)) {
      continue;
    }
    if (_hasAnyIdentity(activeVisitQueueKeys, <String?>[
      entry.id,
      entry.publicId,
      entry.apiId,
    ])) {
      continue;
    }
    final String patientName = _resolveOpdPatientName(
      context,
      queueEntry: entry,
    );
    final String? patientNumber = _resolveOpdPatientNumber(queueEntry: entry);
    final String? arrivalMode = _resolveOpdArrivalMode(
      queueEntry: entry,
      category: _opdCategoryQueue,
    );
    final _OpdTableItem item = _OpdTableItem(
      id: entry.id,
      title: patientName,
      patientName: patientName,
      patientNumber: patientNumber,
      arrivalMode: arrivalMode,
      category: _opdCategoryQueue,
      status: entry.status,
      visitType: entry.appointmentId == null
          ? _categoryLabel(context, _opdCategoryQueue)
          : context.l10n.opdAppointmentPatientModeLabel,
      queue: context.l10n.opdQueueSummaryLabel,
      provider: entry.providerDisplayName,
      ownerRole: context.l10n.opdWorkflowReceptionTitle,
      billing: _queueBillingLabel(context, entry),
      // No stage next-action — row select opens the queue hub (sole entry).
      billingState: _queueBillingState(entry),
      billingTone: _queueBillingTone(entry),
      time: entry.queuedAt,
      urgencyRank: _statusUrgencyRank(entry.status),
      queueEntry: entry,
    );
    items.add(item);
  }

  for (final OpdAppointment appointment in state.appointments.items) {
    if (_isCompletedStatus(appointment.status)) {
      continue;
    }
    if (_hasAnyIdentity(activeAppointmentKeys, <String?>[
      appointment.id,
      appointment.publicId,
      appointment.apiId,
    ])) {
      continue;
    }
    final String patientName = _resolveOpdPatientName(
      context,
      appointment: appointment,
    );
    final String? patientNumber = _resolveOpdPatientNumber(
      appointment: appointment,
    );
    final String? arrivalMode = _resolveOpdArrivalMode(
      appointment: appointment,
      category: _opdCategoryArrival,
    );
    final _OpdTableItem item = _OpdTableItem(
      id: appointment.id,
      title: patientName,
      patientName: patientName,
      patientNumber: patientNumber,
      arrivalMode: arrivalMode,
      category: _opdCategoryArrival,
      status: appointment.status,
      visitType: context.l10n.opdAppointmentPatientModeLabel,
      queue: context.l10n.opdArrivalsSummaryLabel,
      provider: appointment.providerDisplayName,
      ownerRole: context.l10n.opdWorkflowReceptionTitle,
      facility: appointment.facilityName,
      billing: context.l10n.profileUnknownValue,
      nextStep: context.l10n.opdCheckInAction,
      time: _appointmentArrivalTime(appointment),
      urgencyRank: _statusUrgencyRank(appointment.status),
      appointment: appointment,
    );
    items.add(item);
  }

  items.sort((_OpdTableItem left, _OpdTableItem right) {
    final int urgencyCompare = left.urgencyRank.compareTo(right.urgencyRank);
    if (urgencyCompare != 0) {
      return urgencyCompare;
    }
    final int timeCompare = (left.time ?? _unknownArrivalTime).compareTo(
      right.time ?? _unknownArrivalTime,
    );
    if (timeCompare != 0) {
      return timeCompare;
    }
    return _categorySort(
      left.category,
    ).compareTo(_categorySort(right.category));
  });
  return items;
}

bool _preferOpdTableItem(_OpdTableItem candidate, _OpdTableItem current) {
  final OpdFlowSummary? candidateFlow = candidate.flow;
  final OpdFlowSummary? currentFlow = current.flow;

  if (candidateFlow != null && currentFlow == null) {
    return true;
  }
  if (candidateFlow == null && currentFlow != null) {
    return false;
  }

  if (candidateFlow != null && currentFlow != null) {
    if (_isSameFlow(candidateFlow, currentFlow)) {
      return _categorySort(candidate.category) <
          _categorySort(current.category);
    }

    final int candidateRank = _flowActionRank(candidateFlow);
    final int currentRank = _flowActionRank(currentFlow);
    if (candidateRank != currentRank) {
      return candidateRank > currentRank;
    }
  }

  if (candidate.urgencyRank != current.urgencyRank) {
    return candidate.urgencyRank < current.urgencyRank;
  }

  final DateTime candidateTime = candidate.time ?? _unknownArrivalTime;
  final DateTime currentTime = current.time ?? _unknownArrivalTime;
  if (candidateTime != currentTime) {
    return candidateTime.isBefore(currentTime);
  }

  return _categorySort(candidate.category) < _categorySort(current.category);
}

Set<String> _identityKeys(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim())
      .whereType<String>()
      .where((String value) => value.isNotEmpty)
      .expand((String value) sync* {
        yield value;
        yield value.toUpperCase();
      })
      .toSet();
}

bool _hasAnyIdentity(Set<String> knownKeys, Iterable<String?> values) {
  return _identityKeys(values).any(knownKeys.contains);
}

int _flowActionRank(OpdFlowSummary flow) {
  final int stageRank = switch ((flow.stage ?? '').toUpperCase()) {
    'WAITING_CONSULTATION_PAYMENT' => 10,
    'WAITING_VITALS' => 20,
    'WAITING_DOCTOR_ASSIGNMENT' => 30,
    'WAITING_DOCTOR_REVIEW' => 40,
    'LAB_REQUESTED' ||
    'RADIOLOGY_REQUESTED' ||
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'PHARMACY_REQUESTED' => 50,
    'WAITING_DISPOSITION' => 60,
    _ => 0,
  };

  final int emergencyRank = _isEmergencyFlow(flow) ? 1000 : 0;
  final int paymentRank = flow.consultationPaid ? 5 : 0;
  return emergencyRank + stageRank + paymentRank;
}

DateTime? _appointmentArrivalTime(OpdAppointment appointment) {
  final String status = (appointment.status ?? '').toUpperCase();
  if (status == 'IN_PROGRESS') {
    return appointment.updatedAt ?? appointment.scheduledStart;
  }
  return appointment.scheduledStart ?? appointment.updatedAt;
}

int _flowUrgencyRank(OpdFlowSummary flow) {
  final int? triageRank = flow.triagePriorityRank;
  if (triageRank != null) {
    return triageRank;
  }
  if (_isEmergencyFlow(flow)) {
    return 0;
  }
  return _statusUrgencyRank(flow.stage ?? flow.status);
}

int _statusUrgencyRank(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' || 'IMMEDIATE' || 'LEVEL_1' || 'EMERGENCY' => 0,
    'URGENT' || 'HIGH' || 'LEVEL_2' => 1,
    'IN_PROGRESS' || 'WAITING_DOCTOR_REVIEW' || 'WAITING_DISPOSITION' => 20,
    'CONFIRMED' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' ||
    'WAITING_CONSULTATION_PAYMENT' => 30,
    _ => _defaultUrgencyRank,
  };
}

bool _matchesTriageScope(_OpdTableItem item, String scope) {
  final String normalized = scope.toUpperCase();
  final OpdFlowSummary? flow = item.flow;
  if (normalized == _triageScopeWaiting) {
    return item.category == _opdCategoryTriage &&
        _isWaitingTriageStage(flow?.stage);
  }
  if (normalized == _triageScopeUrgent) {
    return flow != null && _flowUrgencyRank(flow) <= 1;
  }
  if (normalized == _triageScopeEmergency) {
    return flow != null && _isEmergencyFlow(flow);
  }
  if (normalized == _triageScopeRoutine) {
    return flow != null && _isRoutineTriageFlow(flow);
  }
  if (normalized == _triageScopeServiceOnly) {
    return flow != null && _isServiceOnlyFlow(flow);
  }
  return true;
}

bool _isWaitingTriageStage(String? stage) {
  return switch ((stage ?? '').toUpperCase()) {
    'WAITING_VITALS' || 'WAITING_DOCTOR_ASSIGNMENT' => true,
    _ => false,
  };
}

bool _isEmergencyFlow(OpdFlowSummary flow) {
  return flow.emergencyIndicator ||
      (flow.encounterType ?? '').toUpperCase() == 'EMERGENCY' ||
      (flow.triageLevel ?? '').toUpperCase() == 'LEVEL_1' ||
      (flow.triageLevel ?? '').toUpperCase() == 'IMMEDIATE';
}

bool _isRoutineTriageFlow(OpdFlowSummary flow) {
  return switch ((flow.triageLevel ?? '').toUpperCase()) {
    'LEVEL_3' ||
    'LEVEL_4' ||
    'LEVEL_5' ||
    'LESS_URGENT' ||
    'NON_URGENT' => true,
    _ =>
      !_isEmergencyFlow(flow) &&
          !_isServiceOnlyFlow(flow) &&
          _isWaitingTriageStage(flow.stage),
  };
}

bool _isServiceOnlyFlow(OpdFlowSummary flow) {
  final String stage = (flow.stage ?? '').toUpperCase();
  final String route = (flow.lastRouteTo ?? '').toUpperCase();
  return _serviceOnlyStages.contains(stage) ||
      _serviceOnlyRoutes.contains(route);
}

String _triageNextStep(OpdFlowSummary flow) {
  final String route = flow.lastRouteTo ?? '';
  if (route.isNotEmpty) {
    return route;
  }
  return flow.nextStep ?? flow.stage ?? '';
}

String? _flowVisitTypeLabel(BuildContext context, OpdFlowSummary flow) {
  if (_isEmergencyFlow(flow)) {
    return context.l10n.opdTriageScopeEmergency;
  }
  final String arrivalMode = _apiLabel(flow.arrivalMode ?? '');
  if (arrivalMode.isNotEmpty) {
    return arrivalMode;
  }
  final String encounterType = _apiLabel(flow.encounterType ?? '');
  return encounterType.isEmpty ? null : encounterType;
}

String _flowQueueLabel(BuildContext context, OpdFlowSummary flow) {
  final String route = _apiLabel(flow.lastRouteTo ?? '');
  if (route.isNotEmpty && !_isCompletedStatus(flow.stage)) {
    return route;
  }

  final String stage = opdStageDisplayLabel(
    context.l10n,
    flow.displayCode ?? flow.stage,
  );
  return stage.isEmpty ? context.l10n.profileUnknownValue : stage;
}

String _flowBillingLabel(BuildContext context, OpdFlowSummary flow) {
  return opdFlowBillingDisplay(context, flow).label;
}

String _flowBillingState(OpdFlowSummary flow) {
  return opdBillingStateFilterValue(opdFlowBillingState(flow));
}

String _billingStateLabel(BuildContext context, String value) {
  return opdBillingStateLabel(
    context.l10n,
    opdBillingStateFromFilterValue(value),
  );
}

AppWorkspaceStatusTone _flowBillingTone(OpdFlowSummary flow) {
  return opdBillingTone(opdFlowBillingState(flow));
}

String _flowOwnerRole(BuildContext context, OpdFlowSummary flow) {
  final String? assignedRole = flow.assignedStaffRole;
  if (_isNonEmpty(assignedRole)) {
    return _staffRoleLabel(context, assignedRole!);
  }
  return opdResponsibleRoleForStage(
    context.l10n,
    flow.displayCode ?? flow.stage,
  );
}

String _staffRoleLabel(BuildContext context, String role) {
  final AppLocalizations l10n = context.l10n;
  return switch (role.trim().toUpperCase()) {
    'PLATFORM_ADMIN' ||
    'TENANT_ADMIN' ||
    'FACILITY_ADMIN' => l10n.navigationSetupLabel,
    'RECEPTIONIST' => l10n.opdWorkflowReceptionTitle,
    'BILLING' => l10n.navigationBillingLabel,
    'NURSE' => l10n.navigationNursingLabel,
    'DOCTOR' => l10n.opdWorkflowDoctorTitle,
    'LAB_TECH' => l10n.navigationLabLabel,
    'RADIOLOGY_TECH' => l10n.navigationRadiologyLabel,
    'PHARMACIST' => l10n.navigationPharmacyLabel,
    'OPERATIONS' => l10n.navigationOperationsLabel,
    _ => AppDisplay.apiLabel(role),
  };
}

String _queueBillingLabel(BuildContext context, OpdQueueEntry entry) {
  return opdQueueBillingDisplay(context, entry).label;
}

String _queueBillingState(OpdQueueEntry entry) {
  return opdBillingStateFilterValue(opdQueueBillingState(entry));
}

AppWorkspaceStatusTone _queueBillingTone(OpdQueueEntry entry) {
  final String status = (entry.paymentStatus ?? '').toUpperCase();
  if (status == 'FAILED' || status == 'VOID' || status == 'CANCELLED') {
    return AppWorkspaceStatusTone.error;
  }
  return opdBillingTone(opdQueueBillingState(entry));
}

String? _nextActionFilterValue(_OpdTableItem item) {
  final String? nextStep = item.nextStep;
  if (_isNonEmpty(nextStep)) {
    return nextStep;
  }
  return item.status;
}

_OpdDateRange? _datePresetRange(String? preset) {
  final DateTime today = DateUtils.dateOnly(DateTime.now());
  return switch (preset) {
    _opdDatePresetToday => _OpdDateRange(from: today, to: today),
    _opdDatePresetYesterday => _OpdDateRange(
      from: today.subtract(const Duration(days: 1)),
      to: today.subtract(const Duration(days: 1)),
    ),
    _opdDatePresetLast7Days => _OpdDateRange(
      from: today.subtract(const Duration(days: 6)),
      to: today,
    ),
    _opdDatePresetLast30Days => _OpdDateRange(
      from: today.subtract(const Duration(days: 29)),
      to: today,
    ),
    _ => null,
  };
}

bool _matchesDateRange(
  DateTime? value, {
  required DateTime? dateFrom,
  required DateTime? dateTo,
}) {
  if (dateFrom == null && dateTo == null) {
    return true;
  }
  if (value == null) {
    return false;
  }

  final DateTime date = DateUtils.dateOnly(value.toLocal());
  final DateTime? from = dateFrom == null
      ? null
      : DateUtils.dateOnly(dateFrom.toLocal());
  final DateTime? to = dateTo == null
      ? null
      : DateUtils.dateOnly(dateTo.toLocal());

  if (from != null && date.isBefore(from)) {
    return false;
  }
  if (to != null && date.isAfter(to)) {
    return false;
  }
  return true;
}

bool _searchValueMatches(String value, String needle) {
  final String normalizedValue = value.toLowerCase();
  if (normalizedValue.contains(needle)) {
    return true;
  }
  return _apiLabel(value).toLowerCase().contains(needle);
}

final class _OpdDateRange {
  const _OpdDateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

String _formatShortDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  if (minutes < 60) {
    return '${minutes}m';
  }
  final int hours = duration.inHours;
  final int remainingMinutes = minutes.remainder(60);
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainingMinutes}m';
}

String _arrivalModeLabel(BuildContext context, _OpdTableItem item) {
  final String label = opdArrivalModeDisplayLabel(
    context.l10n,
    item.arrivalMode ?? item.flow?.arrivalMode,
  );
  return label.isEmpty ? context.l10n.profileUnknownValue : label;
}

String _queueStatusLabel(BuildContext context, _OpdTableItem item) {
  if (item.category == _opdCategoryTriage) {
    final String label = triageLevelDisplayLabel(context.l10n, item.status);
    return label.isEmpty ? context.l10n.profileUnknownValue : label;
  }

  final OpdFlowSummary? flow = item.flow;
  if (flow != null) {
    final String label = opdStatusDisplayLabel(context.l10n, flow);
    return label.isEmpty ? context.l10n.profileUnknownValue : label;
  }

  final String label = opdStageDisplayLabel(context.l10n, item.status);
  return label.isEmpty ? context.l10n.profileUnknownValue : label;
}

String _opdTableColumnStorageId(_OpdTableColumnId column) {
  return switch (column) {
    _OpdTableColumnId.patient => 'patient',
    _OpdTableColumnId.category => 'category',
    _OpdTableColumnId.arrivalMode => 'arrival_mode',
    _OpdTableColumnId.visitType => 'visit_type',
    _OpdTableColumnId.status => 'status',
    _OpdTableColumnId.provider => 'provider',
    _OpdTableColumnId.waitingTime => 'waiting_time',
    _OpdTableColumnId.arrivalTime => 'arrival_time',
    _OpdTableColumnId.nextAction => 'next_action',
    _OpdTableColumnId.encounter => 'encounter',
  };
}

String _opdTableColumnLabel(BuildContext context, _OpdTableColumnId column) {
  final l10n = context.l10n;
  return switch (column) {
    _OpdTableColumnId.patient => l10n.opdPatientColumnLabel,
    _OpdTableColumnId.category => l10n.opdCategoryFilterLabel,
    _OpdTableColumnId.arrivalMode => l10n.opdArrivalModeColumnLabel,
    _OpdTableColumnId.visitType => l10n.opdVisitTypeColumnLabel,
    _OpdTableColumnId.status => l10n.opdStatusColumnLabel,
    _OpdTableColumnId.provider => l10n.opdProviderColumnLabel,
    _OpdTableColumnId.waitingTime => l10n.opdWaitingTimeColumnLabel,
    _OpdTableColumnId.arrivalTime => l10n.opdTimeColumnLabel,
    _OpdTableColumnId.nextAction => l10n.opdNextActionColumnLabel,
    _OpdTableColumnId.encounter => l10n.opdEncounterColumnLabel,
  };
}

Widget _opdStatusBadge(BuildContext context, _OpdTableItem item) {
  return AppWorkspaceStatusBadge(
    status: AppWorkspaceStatus(
      label: _queueStatusLabel(context, item),
      tone: item.category == _opdCategoryTriage
          ? appTriageToneForValue(item.status)
          : _stageTone(item.status ?? item.flow?.stage),
    ),
  );
}

AppListTableColumn<_OpdTableItem> _opdDataColumn(
  BuildContext context,
  _OpdTableColumnId column, {
  required OpdWorkspaceState state,
}) {
  final String label = _opdTableColumnLabel(context, column);

  return AppListTableColumn<_OpdTableItem>(
    id: _opdTableColumnStorageId(column),
    label: label,
    alwaysVisible: column == _OpdTableColumnId.nextAction,
    sortComparator: _opdSortComparator(column),
    exportValue: (_OpdTableItem item) =>
        _opdExportCellValue(context, column, item),
    cellBuilder: (BuildContext context, _OpdTableItem item) {
      return switch (column) {
        _OpdTableColumnId.patient => AppListItemText(
          title: item.patientName ?? item.title,
          subtitle: item.patientNumber,
        ),
        _OpdTableColumnId.category => Text(
          _categoryLabel(context, item.category),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.arrivalMode => Text(
          _arrivalModeLabel(context, item),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.visitType => Text(
          item.visitType ?? context.l10n.profileUnknownValue,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.status => _opdStatusBadge(context, item),
        _OpdTableColumnId.provider => _ProviderCell(item: item),
        _OpdTableColumnId.waitingTime => Text(
          _waitingTimeLabel(context, item, now: DateTime.now()),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.arrivalTime => Text(
          _formatDateTime(context, item.time),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.nextAction => _OpdNextActionCell(
          item: item,
          state: state,
        ),
        _OpdTableColumnId.encounter => _OpdEncounterCell(item: item),
      };
    },
    tooltip: label,
  );
}

String _opdExportCellValue(
  BuildContext context,
  _OpdTableColumnId column,
  _OpdTableItem item,
) {
  return switch (column) {
    _OpdTableColumnId.patient => item.patientName ?? item.title,
    _OpdTableColumnId.category => _categoryLabel(context, item.category),
    _OpdTableColumnId.arrivalMode => _arrivalModeLabel(context, item),
    _OpdTableColumnId.visitType =>
      item.visitType ?? context.l10n.profileUnknownValue,
    _OpdTableColumnId.status => _queueStatusLabel(context, item),
    _OpdTableColumnId.provider =>
      item.provider?.trim().isNotEmpty == true
          ? item.provider!.trim()
          : context.l10n.profileUnknownValue,
    _OpdTableColumnId.waitingTime =>
      _waitingTimeLabel(context, item, now: DateTime.now()),
    _OpdTableColumnId.arrivalTime => _formatDateTime(context, item.time),
    _OpdTableColumnId.nextAction => item.nextStep?.trim().isNotEmpty == true
        ? item.nextStep!.trim()
        : '',
    _OpdTableColumnId.encounter =>
      item.encounterId?.trim().isNotEmpty == true
          ? item.encounterId!.trim()
          : context.l10n.profileUnknownValue,
  };
}

AppListTableSortComparator<_OpdTableItem> _opdSortComparator(
  _OpdTableColumnId column,
) {
  return (_OpdTableItem left, _OpdTableItem right) {
    return switch (column) {
      _OpdTableColumnId.patient => appListTableCompareText(
        left.patientName ?? left.title,
        right.patientName ?? right.title,
      ),
      _OpdTableColumnId.category => appListTableCompareText(
        left.category,
        right.category,
      ),
      _OpdTableColumnId.arrivalMode => appListTableCompareText(
        left.arrivalMode ?? left.flow?.arrivalMode,
        right.arrivalMode ?? right.flow?.arrivalMode,
      ),
      _OpdTableColumnId.visitType => appListTableCompareText(
        left.visitType,
        right.visitType,
      ),
      _OpdTableColumnId.status => appListTableCompareText(
        left.status ?? left.queue,
        right.status ?? right.queue,
      ),
      _OpdTableColumnId.provider => appListTableCompareText(
        left.provider,
        right.provider,
      ),
      _OpdTableColumnId.waitingTime => left.urgencyRank.compareTo(
        right.urgencyRank,
      ),
      _OpdTableColumnId.arrivalTime => appListTableCompareDateTime(
        left.time,
        right.time,
      ),
      _OpdTableColumnId.nextAction => appListTableCompareText(
        left.nextStep,
        right.nextStep,
      ),
      _OpdTableColumnId.encounter => appListTableCompareText(
        left.encounterId,
        right.encounterId,
      ),
    };
  };
}

enum _OpdTableColumnId {
  patient,
  category,
  arrivalMode,
  visitType,
  status,
  provider,
  waitingTime,
  arrivalTime,
  nextAction,
  encounter,
}

const int _defaultUrgencyRank = 99;
final DateTime _unknownArrivalTime = DateTime(9999);

const List<_OpdTableColumnId> _defaultOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patient,
  _OpdTableColumnId.category,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.status,
  _OpdTableColumnId.nextAction,
];

String? _opdSectionCategory(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all || OpdWorkspaceSection.followUps => null,
    OpdWorkspaceSection.arrivals => _opdCategoryArrival,
    OpdWorkspaceSection.queue => _opdCategoryQueue,
    OpdWorkspaceSection.triage => _opdCategoryTriage,
    OpdWorkspaceSection.active => _opdCategoryActiveFlow,
  };
}

IconData _opdSectionIcon(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => Icons.dashboard_outlined,
    OpdWorkspaceSection.arrivals => Icons.event_outlined,
    OpdWorkspaceSection.queue => Icons.queue_outlined,
    OpdWorkspaceSection.triage => Icons.monitor_heart_outlined,
    OpdWorkspaceSection.active => Icons.medical_services_outlined,
    OpdWorkspaceSection.followUps => Icons.event_repeat_outlined,
  };
}

String _opdSectionLabel(AppLocalizations l10n, OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => l10n.opdSectionAllLabel,
    OpdWorkspaceSection.arrivals => l10n.opdSectionArrivalsLabel,
    OpdWorkspaceSection.queue => l10n.opdSectionQueueLabel,
    OpdWorkspaceSection.triage => l10n.opdSectionTriageLabel,
    OpdWorkspaceSection.active => l10n.opdSectionActiveLabel,
    OpdWorkspaceSection.followUps => l10n.receptionSectionFollowUps,
  };
}

/// Sibling-count model: dedicated unfiltered scope totals from workspace
/// summary / page totals. Active tab with search/advanced filters uses the
/// filtered membership length for that tab only.
int? _opdSectionCount(
  OpdWorkspaceState state,
  OpdWorkspaceSection section,
  List<_OpdTableItem> allItems, {
  required OpdWorkspaceSection activeSection,
  required _OpdTableFilter filter,
}) {
  if (section == OpdWorkspaceSection.followUps) {
    return null;
  }
  final int scopeTotal = _opdSectionScopeTotal(state, section, allItems);
  if (section != activeSection || !filter.isActive) {
    return scopeTotal;
  }
  final String? sectionCategory = _opdSectionCategory(section);
  final Iterable<_OpdTableItem> sectionItems = sectionCategory == null
      ? allItems
      : allItems.where((_OpdTableItem item) => item.category == sectionCategory);
  return sectionItems.where(filter.matches).length;
}

int _opdSectionScopeTotal(
  OpdWorkspaceState state,
  OpdWorkspaceSection section,
  List<_OpdTableItem> allItems,
) {
  return switch (section) {
    OpdWorkspaceSection.all =>
      state.summaryCounts.allOpdPatients > 0
          ? state.summaryCounts.allOpdPatients
          : allItems.length,
    // Arrivals / Queue / Triage badges must match board membership (same rows
    // the table paints), not raw list `totalItemCount` which can include
    // terminal or out-of-scope records the desk filters out.
    OpdWorkspaceSection.arrivals ||
    OpdWorkspaceSection.queue ||
    OpdWorkspaceSection.triage => _opdBoardSectionMembershipCount(
      allItems,
      section,
    ),
    OpdWorkspaceSection.active =>
      state.summaryCounts.activeOpd > 0
          ? state.summaryCounts.activeOpd
          : _opdBoardSectionMembershipCount(allItems, section),
    OpdWorkspaceSection.followUps => 0,
  };
}

int _opdBoardSectionMembershipCount(
  List<_OpdTableItem> allItems,
  OpdWorkspaceSection section,
) {
  final String? sectionCategory = _opdSectionCategory(section);
  if (sectionCategory == null) {
    return allItems.length;
  }
  return allItems
      .where((_OpdTableItem item) => item.category == sectionCategory)
      .length;
}

AppTabCountTone _opdSectionCountTone(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.arrivals ||
    OpdWorkspaceSection.queue ||
    OpdWorkspaceSection.triage ||
    OpdWorkspaceSection.active => AppTabCountTone.warning,
    OpdWorkspaceSection.all ||
    OpdWorkspaceSection.followUps => AppTabCountTone.info,
  };
}

String _opdSectionQueryValue(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => '',
    OpdWorkspaceSection.arrivals => 'arrivals',
    OpdWorkspaceSection.queue => 'queue',
    OpdWorkspaceSection.triage => 'triage',
    OpdWorkspaceSection.active => 'active',
    OpdWorkspaceSection.followUps => 'follow-ups',
  };
}

({String title, String body}) _opdSectionEmptyCopy(
  AppLocalizations l10n,
  OpdWorkspaceSection section,
) {
  return switch (section) {
    OpdWorkspaceSection.arrivals => (
      title: l10n.opdNoArrivalsTitle,
      body: l10n.opdNoArrivalsBody,
    ),
    OpdWorkspaceSection.queue => (
      title: l10n.opdNoQueueTitle,
      body: l10n.opdNoQueueBody,
    ),
    OpdWorkspaceSection.all ||
    OpdWorkspaceSection.triage ||
    OpdWorkspaceSection.active ||
    OpdWorkspaceSection.followUps => (
      title: l10n.opdNoFlowsTitle,
      body: l10n.opdNoFlowsBody,
    ),
  };
}

List<_OpdTableColumnId> _opdDefaultColumnsForSection(
  OpdWorkspaceSection section,
) {
  return switch (section) {
    OpdWorkspaceSection.all => _defaultOpdTableColumns,
    OpdWorkspaceSection.arrivals => const <_OpdTableColumnId>[
      _OpdTableColumnId.patient,
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.status,
      _OpdTableColumnId.nextAction,
    ],
    OpdWorkspaceSection.queue => const <_OpdTableColumnId>[
      _OpdTableColumnId.patient,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.status,
      // Next action is intentionally not mounted on Queue (`opdBoardShowsNextActionColumn`);
      // Visit type fills the fifth default slot (tables.mdc prefer-5).
      _OpdTableColumnId.visitType,
    ],
    OpdWorkspaceSection.triage => const <_OpdTableColumnId>[
      _OpdTableColumnId.patient,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.status,
      _OpdTableColumnId.nextAction,
    ],
    OpdWorkspaceSection.active ||
    OpdWorkspaceSection.followUps => const <_OpdTableColumnId>[
      _OpdTableColumnId.patient,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.status,
      _OpdTableColumnId.nextAction,
    ],
  };
}

List<_OpdTableColumnId> _opdColumnChoicesForSection(
  OpdWorkspaceSection section,
) {
  final Set<_OpdTableColumnId> defaults = _opdDefaultColumnsForSection(
    section,
  ).toSet();
  final List<_OpdTableColumnId> pool = switch (section) {
    OpdWorkspaceSection.all => const <_OpdTableColumnId>[
      _OpdTableColumnId.arrivalMode,
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.encounter,
    ],
    OpdWorkspaceSection.arrivals => const <_OpdTableColumnId>[
      _OpdTableColumnId.arrivalMode,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.encounter,
      _OpdTableColumnId.category,
    ],
    OpdWorkspaceSection.queue => const <_OpdTableColumnId>[
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.arrivalMode,
      _OpdTableColumnId.encounter,
    ],
    OpdWorkspaceSection.triage => const <_OpdTableColumnId>[
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.arrivalMode,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.encounter,
    ],
    OpdWorkspaceSection.active ||
    OpdWorkspaceSection.followUps => const <_OpdTableColumnId>[
      _OpdTableColumnId.encounter,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.arrivalMode,
    ],
  };
  return pool.where((column) => !defaults.contains(column)).toList();
}

int _categorySort(String category) {
  return switch (category) {
    _opdCategoryTriage => 0,
    _opdCategoryActiveFlow => 1,
    _opdCategoryQueue => 2,
    _opdCategoryArrival => 3,
    _ => 4,
  };
}

bool _isCompletedStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

/// Maps an `/opd?panel=` deep-link value to a worklist filter.
///
/// Accepts hospital-language panel names as well as raw backend stage names so
/// links from other modules (and summary cards) resolve to the right queue.
_OpdTableFilter _opdFilterForPanel(String panel) {
  final String key = panel.trim().toUpperCase();
  if (key.isEmpty) {
    return const _OpdTableFilter();
  }
  return switch (key) {
    'ARRIVALS' ||
    'ARRIVAL' ||
    'APPOINTMENTS' => const _OpdTableFilter(category: _opdCategoryArrival),
    'QUEUE' || 'QUEUED' => const _OpdTableFilter(category: _opdCategoryQueue),
    'TRIAGE' => const _OpdTableFilter(category: _opdCategoryTriage),
    'ACTIVE' ||
    'ACTIVE_FLOW' ||
    'OPD' ||
    'FLOWS' => const _OpdTableFilter(category: _opdCategoryActiveFlow),
    'PAYMENT' ||
    'BILLING' ||
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'PAYMENT_DUE', 'WAITING_CONSULTATION_PAYMENT'},
    ),
    'VITALS' || 'VITALS_NEEDED' || 'WAITING_VITALS' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'VITALS_NEEDED', 'WAITING_VITALS'},
    ),
    'DOCTOR' ||
    'DOCTOR_NEEDED' ||
    'ASSIGNMENT' ||
    'WAITING_DOCTOR_ASSIGNMENT' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'DOCTOR_NEEDED', 'WAITING_DOCTOR_ASSIGNMENT'},
    ),
    'REVIEW' ||
    'WITH_DOCTOR' ||
    'WAITING_DOCTOR_REVIEW' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'WITH_DOCTOR', 'WAITING_DOCTOR_REVIEW'},
    ),
    'LAB' ||
    'LAB_PENDING' ||
    'LAB_REQUESTED' ||
    'LAB_AND_RADIOLOGY_REQUESTED' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{
        'LAB_PENDING',
        'SAMPLE_PENDING',
        'IN_LAB',
        'LAB_REQUESTED',
        'LAB_AND_RADIOLOGY_REQUESTED',
      },
    ),
    'IMAGING' ||
    'RADIOLOGY' ||
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{
        'IMAGING_PENDING',
        'REPORT_PENDING',
        'RADIOLOGY_REQUESTED',
        'LAB_AND_RADIOLOGY_REQUESTED',
      },
    ),
    'PHARMACY' ||
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'PHARMACY_PENDING', 'PHARMACY_REQUESTED'},
    ),
    'DISPOSITION' ||
    'DECISION' ||
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{
        'DECISION_NEEDED',
        'RESULTS_READY',
        'REPORT_READY',
        'MEDICINES_DISPENSED',
        'WAITING_DISPOSITION',
      },
    ),
    'ADMISSION' || 'ADMISSION_PENDING' || 'ADMITTED' => const _OpdTableFilter(
      category: _opdCategoryActiveFlow,
      statuses: <String>{'ADMISSION_PENDING'},
    ),
    _ => const _OpdTableFilter(category: _opdCategoryActiveFlow),
  };
}

class _OpdMainTable extends ConsumerWidget {
  const _OpdMainTable({
    required this.state,
    required this.section,
    required this.page,
    required this.searchController,
    required this.columnVisibilityController,
    required this.filter,
    required this.filterItems,
    required this.statuses,
    required this.onPageChanged,
    required this.onFilterChanged,
    required this.isLoading,
  });

  final OpdWorkspaceState state;
  final OpdWorkspaceSection section;
  final AppPage<_OpdTableItem> page;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<_OpdTableItem>
  columnVisibilityController;
  final _OpdTableFilter filter;
  final List<_OpdTableItem> filterItems;
  final List<String> statuses;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool showNextAction = opdBoardShowsNextActionColumn(policy, section);
    final List<_OpdTableColumnId> defaultColumns = _opdDefaultColumnsForSection(
      section,
    ).where(
      (_OpdTableColumnId column) =>
          showNextAction || column != _OpdTableColumnId.nextAction,
    ).toList(growable: false);
    final List<_OpdTableColumnId> columnChoices = _opdColumnChoicesForSection(
      section,
    ).where(
      (_OpdTableColumnId column) =>
          showNextAction || column != _OpdTableColumnId.nextAction,
    ).toList(growable: false);

    return SizedBox(
      width: double.infinity,
      child: AppListTable<_OpdTableItem>(
        page: page,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityStorageKey: 'opd_${section.name}',
        columnWidthStorageKey: 'opd_cw_${section.name}',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
        exportLabel: l10n.commonTableExportActionLabel,
        exportDialogTitle: l10n.commonTableExportDialogTitle,
        exportCancelLabel: l10n.commonCancelActionLabel,
        exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
        exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
        exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
        exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
        exportSuccessMessage: l10n.commonTableExportSuccessMessage,
        exportFailureMessage: l10n.commonTableExportFailureMessage,
        canExport: canExportOpdWorkspace(policy),
        enablePrint: true,
        canPrint: canPrintOpdWorkspace(policy),
        printLabel: l10n.commonPrintActionLabel,
        onPrint: () => _printOpdWorkspaceList(
          context,
          ref,
          section: section,
          page: page,
          showNextAction: showNextAction,
          l10n: l10n,
        ),
        exportConfig: AppListTableExportConfig<_OpdTableItem>(
          fileNameStem: 'opd_${section.name}',
          dateOf: (_OpdTableItem item) => item.time,
          rowFilter: (_OpdTableItem item, AppSearchBarFilterValue filters) {
            return _OpdTableFilter.fromSearchBarValue(filters).matches(item);
          },
        ),
        isLoading: isLoading,
        emptyBuilder: (_) {
          final ({String title, String body}) empty = _opdSectionEmptyCopy(
            l10n,
            section,
          );
          return AppWorkspaceStatePanel.empty(
            title: empty.title,
            body: empty.body,
            icon: Icons.medical_services_outlined,
          );
        },
        columns: <AppListTableColumn<_OpdTableItem>>[
          for (final _OpdTableColumnId column in defaultColumns)
            _opdDataColumn(context, column, state: state),
        ],
        columnChoices: <AppListTableColumn<_OpdTableItem>>[
          for (final _OpdTableColumnId column in columnChoices)
            _opdDataColumn(context, column, state: state),
        ],
        onRowSelected: (_OpdTableItem item) {
          final AccessRequirement rowSelectRequirement = switch (section) {
            OpdWorkspaceSection.active => OpdActiveAtomPermissions.rowSelect,
            OpdWorkspaceSection.arrivals => OpdArrivalsAtomPermissions.rowSelect,
            OpdWorkspaceSection.queue => OpdQueueAtomPermissions.rowSelect,
            OpdWorkspaceSection.triage => OpdTriageAtomPermissions.rowSelect,
            OpdWorkspaceSection.all => OpdAllAtomPermissions.rowSelect,
            OpdWorkspaceSection.followUps =>
              OpdFollowUpsAtomPermissions.rowSelect,
          };
          if (!rowSelectRequirement.isAllowed(policy)) {
            return;
          }
          unawaited(_openOpdTableItemActions(context, item, state: state));
        },
        onPageChanged: onPageChanged,
        pageLabelBuilder: (AppPage<_OpdTableItem> page) =>
            _opdPageLabel(context, page),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        search: AppListTableSearch<_OpdTableItem>(
          controller: searchController,
          semanticLabel: l10n.opdSearchLabel,
          hintText: l10n.opdSearchHint,
          clearLabel: l10n.opdClearFiltersAction,
          matcher: (_OpdTableItem item, String query) =>
              item.matches(query, field: filter.searchField),
          onChanged: (String value) {
            onFilterChanged(filter.copyWith(search: value));
          },
          onClear: () {
            onFilterChanged(filter.copyWith(clearSearch: true));
          },
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
          advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCloseLabel: l10n.commonCloseActionLabel,
          searchFields: _opdTableSearchFields(context),
          searchFieldLabel: l10n.opdSearchFieldFilterLabel,
          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
          dateFilterLabel: l10n.opdArrivalDateFilterLabel,
          dateFromLabel: l10n.opdDateFromLabel,
          dateToLabel: l10n.opdDateToLabel,
          datePickerButtonLabel: l10n.opdDatePickerButtonLabel,
          invalidDateMessage: l10n.opdInvalidDateMessage,
          firstDate: DateTime(DateTime.now().year - 10),
          lastDate: DateTime(DateTime.now().year + 2, 12, 31),
          currentDate: DateTime.now(),
          filterGroups: _opdTableFilterGroups(context, filterItems, statuses),
          filterValue: filter.toSearchBarValue(),
          onFilterChanged: (AppSearchBarFilterValue value) {
            onFilterChanged(
              _OpdTableFilter.fromSearchBarValue(
                value,
                search: searchController.text,
              ),
            );
          },
          hasActiveFilters: filter.hasAdvancedFilters,
          trailingActions: _startEncounterSearchActions(
            context,
            ref,
            section: section,
            state: state,
          ),
        ),
        mobileItemBuilder: (BuildContext context, _OpdTableItem item) =>
            AppListTableMobileItem(
              title: item.patientName ?? item.title,
              caption: item.patientNumber,
              meta: <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: _arrivalModeLabel(context, item),
                ),
                AppListTableMobileMeta(
                  label: _waitingTimeLabel(context, item, now: DateTime.now()),
                  icon: AppActionIcons.time,
                ),
                AppListTableMobileMeta(
                  label: _queueStatusLabel(context, item),
                ),
              ],
              trailing: showNextAction
                  ? _OpdNextActionCell(item: item, state: state)
                  : null,
            ),
        itemKeyBuilder: (_OpdTableItem item) =>
            ValueKey<String>('opd-${item.stableKey}'),
        rowColorBuilder: _opdTableRowColor,
      ),
    );
  }

  /// Start OPD CTA lives after Print in the search bar (not the tab toolbar).
  List<AppSearchBarAction> _startEncounterSearchActions(
    BuildContext context,
    WidgetRef ref, {
    required OpdWorkspaceSection section,
    required OpdWorkspaceState state,
  }) {
    if (section == OpdWorkspaceSection.followUps) {
      return const <AppSearchBarAction>[];
    }
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!opdStartEncounterRequirementForSection(section).isAllowed(policy)) {
      return const <AppSearchBarAction>[];
    }
    final AppLocalizations l10n = context.l10n;
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: opdEncounterIcon,
        label: l10n.opdStartWalkInAction,
        tooltip: l10n.opdStartEncounterTooltip,
        onPressed: () {
          unawaited(openOpdWorkspaceEncounterFlow(context, ref, state));
        },
      ),
    ];
  }
}

Future<void> _printOpdFollowUpsList(
  BuildContext context,
  WidgetRef ref, {
  required List<ReceptionFollowUpEntry> entries,
  required AppLocalizations l10n,
}) async {
  final Locale locale = Localizations.localeOf(context);
  final List<OpdWorkspacePrintColumn> printColumns =
      <OpdWorkspacePrintColumn>[
        OpdWorkspacePrintColumn(id: 'patient', label: l10n.opdPatientNameLabel),
        OpdWorkspacePrintColumn(
          id: 'phone',
          label: l10n.patientsPhoneIdentifierColumnLabel,
        ),
        OpdWorkspacePrintColumn(id: 'status', label: l10n.receptionStatusLabel),
        OpdWorkspacePrintColumn(id: 'date', label: l10n.opdFollowUpDateLabel),
        OpdWorkspacePrintColumn(id: 'time', label: l10n.opdFollowUpTimeLabel),
        OpdWorkspacePrintColumn(id: 'patient_id', label: l10n.opdPatientIdLabel),
        OpdWorkspacePrintColumn(id: 'email', label: l10n.patientsEmailLabel),
        OpdWorkspacePrintColumn(id: 'notes', label: l10n.opdNotesLabel),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final ReceptionFollowUpEntry entry in entries)
      <String, String>{
        'patient': entry.patientDisplayName?.trim().isNotEmpty == true
            ? entry.patientDisplayName!.trim()
            : l10n.profileUnknownValue,
        'phone': entry.patientPhone?.trim() ?? '',
        'status': opdStageDisplayLabel(l10n, entry.status),
        'date': AppFormatters.shortDate(entry.scheduledAt.toLocal(), locale),
        'time': AppFormatters.time(entry.scheduledAt.toLocal(), locale),
        'patient_id': entry.patientIdentifier,
        'email': entry.patientEmail?.trim() ?? '',
        'notes': entry.notes?.trim() ?? '',
      },
  ];
  await printOpdWorkspaceList(
    ref: ref,
    context: context,
    title: l10n.receptionSectionFollowUps,
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.receptionFollowUpsEmptyTitle,
  );
}

Future<void> _printOpdWorkspaceList(
  BuildContext context,
  WidgetRef ref, {
  required OpdWorkspaceSection section,
  required AppPage<_OpdTableItem> page,
  required bool showNextAction,
  required AppLocalizations l10n,
}) async {
  final List<_OpdTableColumnId> columnIds = <_OpdTableColumnId>[
    ..._opdDefaultColumnsForSection(section),
    ..._opdColumnChoicesForSection(section),
  ].where(
    (_OpdTableColumnId column) =>
        showNextAction || column != _OpdTableColumnId.nextAction,
  ).toList(growable: false);
  final List<OpdWorkspacePrintColumn> printColumns = <OpdWorkspacePrintColumn>[
    for (final _OpdTableColumnId column in columnIds)
      OpdWorkspacePrintColumn(
        id: _opdTableColumnStorageId(column),
        label: _opdTableColumnLabel(context, column),
      ),
  ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final _OpdTableItem item in page.items)
      <String, String>{
        for (final _OpdTableColumnId column in columnIds)
          _opdTableColumnStorageId(column):
              _opdExportCellValue(context, column, item),
      },
  ];
  await printOpdWorkspaceList(
    ref: ref,
    context: context,
    title: _opdSectionLabel(l10n, section),
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.opdNoFlowsTitle,
  );
}

Future<void> _openOpdTableItemActions(
  BuildContext context,
  _OpdTableItem item, {
  required OpdWorkspaceState state,
}) async {
  final OpdFlowSummary? flow = item.flow;
  if (flow != null) {
    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: flow,
      printActionLabel: context.l10n.commonPrintActionLabel,
      // Stage next-action already lives on the board row — omit from hub.
      omitNextActionKey: resolveOpdFlowNextActionKey(flow),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
    return;
  }

  final OpdQueueEntry? queueEntry = item.queueEntry;
  if (queueEntry != null) {
    final bool? changed = await showQueueActionsDialog(
      context: context,
      entry: queueEntry,
      actionRequirement: OpdQueueAtomPermissions.write,
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
    return;
  }

  final OpdAppointment? appointment = item.appointment;
  if (appointment != null) {
    final bool? changed = await showOpdAppointmentActionsDialog(
      context: context,
      appointment: appointment,
      workspaceState: state,
      omitPrimaryAction: true,
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

String _opdPageLabel(BuildContext context, AppPage<_OpdTableItem> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }

  final int from = page.request.offset + 1;
  final int to = (page.request.offset + page.items.length).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}


class _OpdNextActionCell extends ConsumerWidget {
  const _OpdNextActionCell({required this.item, required this.state});

  final _OpdTableItem item;
  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OpdFlowSummary? flow = item.flow;
    if (flow != null) {
      final OpdBoardNextActionKind kind = opdBoardNextActionKindForFlow(flow);
      if (kind == OpdBoardNextActionKind.none) {
        return const SizedBox.shrink();
      }
      return OpdBoardNextActionCell(
        kind: kind,
        flow: flow,
        onPressed: () => unawaited(_runFlowNextAction(context, ref, flow, kind)),
      );
    }

    final OpdAppointment? appointment = item.appointment;
    if (appointment != null) {
      final OpdFlowSummary? linkedFlow = findActiveOpdFlowForAppointment(
        appointment: appointment,
        flows: <OpdFlowSummary>[
          ...state.flows.items,
          ...state.triageQueue.items,
        ],
      );
      final OpdAppointmentPrimaryAction primary =
          resolveOpdAppointmentPrimaryAction(
            appointment: appointment,
            linkedFlow: linkedFlow,
          );
      final String? label = opdAppointmentPrimaryActionLabel(
        context.l10n,
        primary,
      );
      if (label == null) {
        return const SizedBox.shrink();
      }
      final OpdBoardNextActionKind kind =
          primary == OpdAppointmentPrimaryAction.continueEncounter
          ? OpdBoardNextActionKind.continueAppointmentEncounter
          : OpdBoardNextActionKind.checkInAppointment;
      return OpdBoardNextActionCell(
        kind: kind,
        labelOverride: label,
        onPressed: () => unawaited(
          _runAppointmentNextAction(context, ref, appointment, primary),
        ),
      );
    }

    // Queue rows: no next-action control — row select is the sole hub entry.
    return const SizedBox.shrink();
  }

  Future<void> _runFlowNextAction(
    BuildContext context,
    WidgetRef ref,
    OpdFlowSummary flow,
    OpdBoardNextActionKind kind,
  ) async {
    final bool? changed = await runOpdBoardNextAction(
      context: context,
      ref: ref,
      flow: flow,
      kind: kind,
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  Future<void> _runAppointmentNextAction(
    BuildContext context,
    WidgetRef ref,
    OpdAppointment appointment,
    OpdAppointmentPrimaryAction primary,
  ) async {
    final bool? changed = await runOpdAppointmentNextAction(
      context: context,
      ref: ref,
      appointment: appointment,
      state: state,
      primaryAction: primary,
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _ProviderCell extends StatelessWidget {
  const _ProviderCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    return Text(
      item.provider ?? opdUnknownProviderLabel,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OpdEncounterCell extends StatelessWidget {
  const _OpdEncounterCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? encounterId = item.encounterId;
    if (encounterId == null || encounterId.trim().isEmpty) {
      return Text(
        l10n.profileUnknownValue,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );
    }
    return AppCopyableIdentifier(
      value: encounterId,
      tooltip: l10n.opdCopyEncounterIdAction,
      copiedMessage: l10n.opdEncounterIdCopiedMessage,
      semanticLabel: l10n.opdEncounterColumnLabel,
    );
  }
}

String _waitingTimeLabel(
  BuildContext context,
  _OpdTableItem item, {
  required DateTime now,
}) {
  final DateTime? time = item.time;
  if (time == null || _isCompletedStatus(item.status)) {
    return context.l10n.profileUnknownValue;
  }

  final Duration duration = now.difference(time.toLocal());
  if (duration.isNegative) {
    return context.l10n.profileUnknownValue;
  }
  return _formatShortDuration(duration);
}

Color _opdTableRowColor(BuildContext context, _OpdTableItem item) {
  final ThemeData theme = Theme.of(context);
  final AppStatusColors statusColors = theme.statusColors;
  final Color color = switch (item.category) {
    _opdCategoryArrival => statusColors.infoContainer,
    _opdCategoryQueue => statusColors.warningContainer,
    _opdCategoryTriage => statusColors.errorContainer,
    _opdCategoryActiveFlow => statusColors.successContainer,
    _ => theme.colorScheme.surfaceContainerHighest,
  };
  return color.withValues(alpha: 0.42);
}

String _categoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    _opdCategoryArrival => l10n.opdArrivalsSummaryLabel,
    _opdCategoryQueue => l10n.opdQueueSummaryLabel,
    _opdCategoryTriage => l10n.opdWorkflowTriageTitle,
    _opdCategoryActiveFlow => l10n.opdActiveFlowSummaryLabel,
    _ => _apiLabel(category),
  };
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _apiLabel(String value) {
  return AppDisplay.apiLabel(value);
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}


AppWorkspaceStatusTone _stageTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'RESULTS_READY' ||
    'REPORT_READY' ||
    'MEDICINES_DISPENSED' => AppWorkspaceStatusTone.success,
    'NORMAL' || 'ROUTINE' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'NO_SHOW' => AppWorkspaceStatusTone.error,
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'ABNORMAL' ||
    'SERVICE_ONLY' ||
    'PAYMENT_DUE' ||
    'VITALS_NEEDED' ||
    'DOCTOR_NEEDED' ||
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' ||
    'ADMISSION_PENDING' => AppWorkspaceStatusTone.warning,
    'WAITING_CONSULTATION_PAYMENT' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'WITH_DOCTOR' ||
    'LAB_PENDING' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' ||
    'IMAGING_PENDING' ||
    'REPORT_PENDING' ||
    'LAB_REQUESTED' ||
    'RADIOLOGY_REQUESTED' ||
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

const String _opdCategoryArrival = 'ARRIVAL';
const String _opdCategoryQueue = 'QUEUE';
const String _opdCategoryTriage = 'TRIAGE';
const String _opdCategoryActiveFlow = 'ACTIVE_FLOW';
const String _opdFilterAll = 'ALL';
const String _opdFilterKeyCategory = 'category';
const String _opdFilterKeyStatus = 'status';
const String _opdFilterKeyTriageScope = 'triage_scope';
const String _opdFilterKeyArrivalDatePreset = 'arrival_date_preset';
const String _opdFilterKeyVisitType = 'visit_type';
const String _opdFilterKeyQueue = 'queue';
const String _opdFilterKeyProvider = 'provider';
const String _opdFilterKeyBilling = 'billing';
const String _opdFilterKeyNextAction = 'next_action';
const String _opdDatePresetToday = 'TODAY';
const String _opdDatePresetYesterday = 'YESTERDAY';
const String _opdDatePresetLast7Days = 'LAST_7_DAYS';
const String _opdDatePresetLast30Days = 'LAST_30_DAYS';
const String _opdSearchFieldPatient = 'patient';
const String _opdSearchFieldPatientId = 'patient_id';
const String _opdSearchFieldEncounter = 'encounter_id';
const String _opdSearchFieldPhone = 'phone';
const String _opdSearchFieldProvider = 'provider';
const String _opdSearchFieldQueue = 'queue';
const String _opdSearchFieldStatus = 'status';
const String _opdSearchFieldVisitType = 'visit_type';
const String _opdSearchFieldBilling = 'billing';
const String _opdSearchFieldNextAction = 'next_action';
const String _opdBillingStatePaid = 'PAID';
const String _opdBillingStateRequired = 'REQUIRED';
const String _opdBillingStateNotRequired = 'NOT_REQUIRED';
const String _opdBillingStateUnknown = 'UNKNOWN';
const String _triageScopeWaiting = 'WAITING';
const String _triageScopeUrgent = 'URGENT';
const String _triageScopeEmergency = 'EMERGENCY';
const String _triageScopeRoutine = 'ROUTINE';
const String _triageScopeServiceOnly = 'SERVICE_ONLY';

const Set<String> _serviceOnlyStages = <String>{
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
};

const Set<String> _serviceOnlyRoutes = <String>{
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'MINOR_PROCEDURE',
};
