import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

class OpdWorkspacePage extends ConsumerWidget {
  const OpdWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> state = ref.watch(
      opdWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<OpdWorkspaceState>(
      value: state,
      loadingTitle: l10n.opdLoadingTitle,
      loadingBody: l10n.opdLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(opdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OpdWorkspaceState data) {
        return _OpdWorkspaceContent(state: data);
      },
    );
  }
}

class _OpdWorkspaceContent extends ConsumerStatefulWidget {
  const _OpdWorkspaceContent({required this.state});

  final OpdWorkspaceState state;

  @override
  ConsumerState<_OpdWorkspaceContent> createState() =>
      _OpdWorkspaceContentState();
}

class _OpdWorkspaceContentState extends ConsumerState<_OpdWorkspaceContent> {
  final ValueNotifier<_OpdTableFilter> _filterNotifier =
      ValueNotifier<_OpdTableFilter>(const _OpdTableFilter());
  late final TextEditingController _searchController;
  final ValueNotifier<AppPageRequest> _tablePageNotifier =
      ValueNotifier<AppPageRequest>(const AppPageRequest(pageSize: 12));

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_resetTablePage);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_resetTablePage)
      ..dispose();
    _filterNotifier.dispose();
    _tablePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdWorkspaceState state = widget.state;
    final OpdWorkspaceController controller = ref.read(
      opdWorkspaceControllerProvider.notifier,
    );
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool iconOnly =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
    final List<_OpdTableItem> tableItems = _tableItems(context, state);

    return AppWorkspace(
      title: l10n.opdTitle,
      leadingIcon: AppRouteIcons.opd,
      compactSummaryCards: true,
      primaryAction: AppAccessActionGate(
        requirement: opdEncounterPermissionRequirement,
        builder: (BuildContext context, bool isAllowed) {
          if (iconOnly) {
            return AppIconButton(
              icon: opdEncounterIcon,
              semanticLabel: l10n.opdStartWalkInAction,
              tooltip: l10n.opdStartEncounterTooltip,
              enabled: isAllowed,
              onPressed: () {
                _openOpdEncounterDialog(context, ref);
              },
            );
          }

          return AppButton.primary(
            label: l10n.opdStartWalkInAction,
            leadingIcon: opdEncounterIcon,
            enabled: isAllowed,
            onPressed: () {
              _openOpdEncounterDialog(context, ref);
            },
          );
        },
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading:
              state.isRefreshingAppointments ||
              state.isRefreshingQueue ||
              state.isRefreshingFlows ||
              state.isRefreshingTriageQueue,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        if (tableItems.isNotEmpty)
          AppWorkspaceSummaryCard(
            label: _OpdSummaryText.allRecords,
            value: AppFormatters.compactNumber(
              tableItems.length,
              Localizations.localeOf(context),
            ),
            icon: Icons.groups_outlined,
            compact: true,
            onPressed: () {
              _applySummaryFilter(const _OpdTableFilter());
            },
          ),
        if (_opdCategoryCount(tableItems, _opdCategoryArrival) > 0)
          AppWorkspaceSummaryCard(
            label: l10n.opdArrivalsSummaryLabel,
            value: AppFormatters.compactNumber(
              _opdCategoryCount(tableItems, _opdCategoryArrival),
              Localizations.localeOf(context),
            ),
            icon: Icons.event_available_outlined,
            tone: _categoryTone(_opdCategoryArrival),
            compact: true,
            onPressed: () {
              _applySummaryFilter(
                const _OpdTableFilter(category: _opdCategoryArrival),
              );
            },
          ),
        if (_opdCategoryCount(tableItems, _opdCategoryQueue) > 0)
          AppWorkspaceSummaryCard(
            label: l10n.opdQueueSummaryLabel,
            value: AppFormatters.compactNumber(
              _opdCategoryCount(tableItems, _opdCategoryQueue),
              Localizations.localeOf(context),
            ),
            icon: Icons.queue_outlined,
            tone: _categoryTone(_opdCategoryQueue),
            compact: true,
            onPressed: () {
              _applySummaryFilter(
                const _OpdTableFilter(category: _opdCategoryQueue),
              );
            },
          ),
        if (_opdCategoryCount(tableItems, _opdCategoryTriage) > 0)
          AppWorkspaceSummaryCard(
            label: l10n.opdWorkflowTriageTitle,
            value: AppFormatters.compactNumber(
              _opdCategoryCount(tableItems, _opdCategoryTriage),
              Localizations.localeOf(context),
            ),
            icon: Icons.monitor_heart_outlined,
            tone: AppWorkspaceStatusTone.warning,
            compact: true,
            onPressed: () {
              _applySummaryFilter(
                const _OpdTableFilter(category: _opdCategoryTriage),
              );
            },
          ),
        if (_opdCategoryCount(tableItems, _opdCategoryActiveFlow) > 0)
          AppWorkspaceSummaryCard(
            label: l10n.opdActiveFlowSummaryLabel,
            value: AppFormatters.compactNumber(
              _opdCategoryCount(tableItems, _opdCategoryActiveFlow),
              Localizations.localeOf(context),
            ),
            icon: Icons.medical_services_outlined,
            tone: _categoryTone(_opdCategoryActiveFlow),
            compact: true,
            onPressed: () {
              _applySummaryFilter(
                const _OpdTableFilter(category: _opdCategoryActiveFlow),
              );
            },
          ),
      ],
      body: ValueListenableBuilder<_OpdTableFilter>(
        valueListenable: _filterNotifier,
        builder: (BuildContext context, _OpdTableFilter filter, _) {
          return ValueListenableBuilder<AppPageRequest>(
            valueListenable: _tablePageNotifier,
            builder:
                (BuildContext context, AppPageRequest tablePageRequest, _) {
                  return _OpdWorkspaceBody(
                    state: state,
                    filter: filter,
                    searchController: _searchController,
                    pageRequest: tablePageRequest,
                    onPageChanged: _setTablePage,
                    onFilterChanged: _setFilter,
                  );
                },
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

  void _applySummaryFilter(_OpdTableFilter filter) {
    if (filter.search.trim().isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    _setFilter(filter);
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

  Future<void> _openOpdEncounterDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OpdEncounterDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        activeFlows: <OpdFlowSummary>[
          ...widget.state.flows.items,
          ...widget.state.triageQueue.items,
        ],
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .startOpdEncounter(payload);
        },
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _OpdWorkspaceBody extends StatelessWidget {
  const _OpdWorkspaceBody({
    required this.state,
    required this.filter,
    required this.searchController,
    required this.pageRequest,
    required this.onPageChanged,
    required this.onFilterChanged,
  });

  final OpdWorkspaceState state;
  final _OpdTableFilter filter;
  final TextEditingController searchController;
  final AppPageRequest pageRequest;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final List<_OpdTableItem> allItems = _tableItems(context, state);
    final List<_OpdTableItem> items = allItems
        .where((_OpdTableItem item) => filter.matches(item))
        .toList(growable: false);

    return _OpdMainTable(
      page: _tablePage(items, pageRequest),
      searchController: searchController,
      filter: filter,
      filterItems: allItems,
      statuses: _tableStatuses(allItems),
      onPageChanged: onPageChanged,
      onFilterChanged: onFilterChanged,
      isLoading:
          state.isRefreshingAppointments ||
          state.isRefreshingQueue ||
          state.isRefreshingFlows ||
          state.isRefreshingTriageQueue,
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
              label: _apiLabel(status),
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
      choices: _nextActionFilterChoices(items),
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
      label: l10n.opdPatientIdLabel,
      icon: Icons.badge_outlined,
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
          (String left, String right) =>
              _apiLabel(left).compareTo(_apiLabel(right)),
        );

  return <AppSearchBarFilterChoice>[
    for (final String value in unique)
      AppSearchBarFilterChoice(value: value, label: _apiLabel(value)),
  ];
}

@immutable
final class _OpdTableItem {
  const _OpdTableItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    this.subtitle,
    this.visitType,
    this.queue,
    this.provider,
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
  final String? subtitle;
  final String? visitType;
  final String? queue;
  final String? provider;
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
        title,
        subtitle,
        appointment?.patientDisplayName,
        queueEntry?.patientDisplayName,
        flow?.patientDisplayName,
      ],
      _opdSearchFieldPatientId => <String?>[
        appointment?.patientId,
        appointment?.patientIdentifier,
        queueEntry?.patientId,
        queueEntry?.patientIdentifier,
        flow?.patientId,
        flow?.patientIdentifier,
      ],
      _opdSearchFieldPhone => <String?>[
        appointment?.patientPhone,
        queueEntry?.patientPhone,
        flow?.patientPhone,
      ],
      _opdSearchFieldProvider => <String?>[provider],
      _opdSearchFieldQueue => <String?>[category, queue, flow?.lastRouteTo],
      _opdSearchFieldStatus => <String?>[status, flow?.stage, flow?.status],
      _opdSearchFieldVisitType => <String?>[visitType, flow?.arrivalMode],
      _opdSearchFieldBilling => <String?>[billing, billingState],
      _opdSearchFieldNextAction => <String?>[nextStep, status],
      _ => <String?>[
        id,
        title,
        category,
        status,
        subtitle,
        visitType,
        queue,
        provider,
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
        flow?.stage,
        flow?.status,
        flow?.lastRouteTo,
      ],
    };
  }
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
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: flow.displayTitle,
      category: _opdCategoryTriage,
      status: flow.triageLevel ?? flow.stage,
      visitType: _flowVisitTypeLabel(context, flow),
      queue: _flowQueueLabel(context, flow),
      subtitle: _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        _flowVisitTypeLabel(context, flow),
        _flowWaitLabel(context, flow),
        flow.chiefComplaint,
      ]),
      provider: flow.providerDisplayName,
      facility: flow.facilityName,
      billing: _flowBillingLabel(context, flow),
      billingState: _flowBillingState(flow),
      billingTone: _flowBillingTone(flow),
      nextStep: _triageNextStep(flow),
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
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: flow.displayTitle,
      category: _opdCategoryActiveFlow,
      status: flow.stage,
      visitType: _flowVisitTypeLabel(context, flow),
      queue: _flowQueueLabel(context, flow),
      subtitle: _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        _flowVisitTypeLabel(context, flow),
        _flowWaitLabel(context, flow),
        flow.lastRouteTo == null ? null : _apiLabel(flow.lastRouteTo!),
      ]),
      provider: flow.providerDisplayName,
      facility: flow.facilityName,
      billing: _flowBillingLabel(context, flow),
      billingState: _flowBillingState(flow),
      billingTone: _flowBillingTone(flow),
      nextStep: flow.nextStep,
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
    final _OpdTableItem item = _OpdTableItem(
      id: entry.id,
      title: entry.displayTitle,
      category: _opdCategoryQueue,
      status: entry.status,
      visitType: entry.appointmentId == null
          ? _categoryLabel(context, _opdCategoryQueue)
          : context.l10n.opdAppointmentPatientModeLabel,
      queue: context.l10n.opdQueueSummaryLabel,
      subtitle: _joinDisplay(<String?>[
        entry.patientIdentifier,
        entry.patientPhone,
        entry.appointmentReason,
      ]),
      provider: entry.providerDisplayName,
      billing: _queueBillingLabel(context, entry),
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
    final _OpdTableItem item = _OpdTableItem(
      id: appointment.id,
      title: appointment.displayTitle,
      category: _opdCategoryArrival,
      status: appointment.status,
      visitType: context.l10n.opdAppointmentPatientModeLabel,
      queue: context.l10n.opdArrivalsSummaryLabel,
      subtitle: _joinDisplay(<String?>[
        appointment.patientIdentifier,
        appointment.patientPhone,
        appointment.reason,
      ]),
      provider: appointment.providerDisplayName,
      facility: appointment.facilityName,
      billing: context.l10n.profileUnknownValue,
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

int _opdCategoryCount(List<_OpdTableItem> items, String category) {
  return items.where((_OpdTableItem item) => item.category == category).length;
}

abstract final class _OpdSummaryText {
  static const String allRecords = 'All OPD records';
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

  final String stage = _apiLabel(flow.stage ?? '');
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

String? _flowWaitLabel(BuildContext context, OpdFlowSummary flow) {
  final DateTime? queuedAt = flow.queuedAt ?? flow.startedAt;
  if (queuedAt == null || flow.isTerminal) {
    return null;
  }

  final Duration duration = DateTime.now().difference(queuedAt.toLocal());
  if (duration.isNegative) {
    return null;
  }
  return context.l10n.opdWaitDurationShort(_formatShortDuration(duration));
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

List<_OpdTableColumnId> _normalizeTableColumns(
  List<_OpdTableColumnId> columns,
) {
  final List<_OpdTableColumnId> normalized = <_OpdTableColumnId>[];
  for (final _OpdTableColumnId column in columns) {
    if (_availableOpdTableColumns.contains(column) &&
        !normalized.contains(column)) {
      normalized.add(column);
    }
    if (normalized.length == _maxOpdTableColumns) {
      break;
    }
  }

  for (final _OpdTableColumnId column in _defaultOpdTableColumns) {
    if (normalized.length == _maxOpdTableColumns) {
      break;
    }
    if (!normalized.contains(column)) {
      normalized.add(column);
    }
  }

  return normalized;
}

String _opdTableColumnLabel(BuildContext context, _OpdTableColumnId column) {
  final l10n = context.l10n;
  return switch (column) {
    _OpdTableColumnId.patient => l10n.opdPatientColumnLabel,
    _OpdTableColumnId.visitType => l10n.opdVisitTypeColumnLabel,
    _OpdTableColumnId.queueStatus => l10n.opdQueueStatusColumnLabel,
    _OpdTableColumnId.provider => l10n.opdProviderColumnLabel,
    _OpdTableColumnId.payerBilling => l10n.opdPayerBillingColumnLabel,
    _OpdTableColumnId.waitingTime => l10n.opdWaitingTimeColumnLabel,
    _OpdTableColumnId.arrivalTime => l10n.opdTimeColumnLabel,
    _OpdTableColumnId.nextStep => l10n.opdNextStepColumnLabel,
  };
}

AppListTableColumn<_OpdTableItem> _opdDataColumn(
  BuildContext context,
  _OpdTableColumnId column,
) {
  final String label = _opdTableColumnLabel(context, column);

  return AppListTableColumn<_OpdTableItem>(
    label: label,
    sortComparator: _opdSortComparator(column),
    cellBuilder: (BuildContext context, _OpdTableItem item) {
      return switch (column) {
        _OpdTableColumnId.patient => AppListItemText(
          title: item.title,
          subtitle: item.subtitle,
        ),
        _OpdTableColumnId.visitType => Text(
          item.visitType ?? context.l10n.profileUnknownValue,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.queueStatus => _QueueStatusCell(item: item),
        _OpdTableColumnId.provider => _ProviderCell(item: item),
        _OpdTableColumnId.payerBilling => AppStatusText(
          label: item.billing ?? context.l10n.profileUnknownValue,
          tone: item.billingTone,
        ),
        _OpdTableColumnId.waitingTime => Text(
          _waitingTimeLabel(context, item),
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
        _OpdTableColumnId.nextStep => Text(
          _nextStepLabel(context, item),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      };
    },
    tooltip: label,
  );
}

AppListTableSortComparator<_OpdTableItem> _opdSortComparator(
  _OpdTableColumnId column,
) {
  return (_OpdTableItem left, _OpdTableItem right) {
    return switch (column) {
      _OpdTableColumnId.patient => appListTableCompareText(
        left.title,
        right.title,
      ),
      _OpdTableColumnId.visitType => appListTableCompareText(
        left.visitType,
        right.visitType,
      ),
      _OpdTableColumnId.queueStatus => appListTableCompareText(
        _joinDisplay(<String?>[left.queue, left.status]),
        _joinDisplay(<String?>[right.queue, right.status]),
      ),
      _OpdTableColumnId.provider => appListTableCompareText(
        left.provider,
        right.provider,
      ),
      _OpdTableColumnId.payerBilling => appListTableCompareText(
        left.billing,
        right.billing,
      ),
      _OpdTableColumnId.waitingTime => left.urgencyRank.compareTo(
        right.urgencyRank,
      ),
      _OpdTableColumnId.arrivalTime => appListTableCompareDateTime(
        left.time,
        right.time,
      ),
      _OpdTableColumnId.nextStep => appListTableCompareText(
        left.nextStep,
        right.nextStep,
      ),
    };
  };
}

enum _OpdTableColumnId {
  patient,
  visitType,
  queueStatus,
  provider,
  payerBilling,
  waitingTime,
  arrivalTime,
  nextStep,
}

const int _maxOpdTableColumns = 5;
const int _defaultUrgencyRank = 99;
final DateTime _unknownArrivalTime = DateTime(9999);

const List<_OpdTableColumnId> _defaultOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patient,
  _OpdTableColumnId.visitType,
  _OpdTableColumnId.queueStatus,
  _OpdTableColumnId.payerBilling,
  _OpdTableColumnId.waitingTime,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.arrivalTime,
  _OpdTableColumnId.nextStep,
];

const List<_OpdTableColumnId> _availableOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patient,
  _OpdTableColumnId.visitType,
  _OpdTableColumnId.queueStatus,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.payerBilling,
  _OpdTableColumnId.waitingTime,
  _OpdTableColumnId.arrivalTime,
  _OpdTableColumnId.nextStep,
];

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

class _OpdMainTable extends ConsumerWidget {
  const _OpdMainTable({
    required this.page,
    required this.searchController,
    required this.filter,
    required this.filterItems,
    required this.statuses,
    required this.onPageChanged,
    required this.onFilterChanged,
    required this.isLoading,
  });

  final AppPage<_OpdTableItem> page;
  final TextEditingController searchController;
  final _OpdTableFilter filter;
  final List<_OpdTableItem> filterItems;
  final List<String> statuses;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final List<_OpdTableColumnId> visibleColumns = _normalizeTableColumns(
      _defaultOpdTableColumns,
    );

    return SizedBox(
      width: double.infinity,
      child: AppListTable<_OpdTableItem>(
        page: page,
        title: l10n.opdFlowsTitle,
        description: l10n.opdTableDescription,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        isLoading: isLoading,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.opdNoFlowsTitle,
          body: l10n.opdNoFlowsBody,
          icon: Icons.medical_services_outlined,
          minHeight: 260,
        ),
        columns: <AppListTableColumn<_OpdTableItem>>[
          for (final _OpdTableColumnId column in visibleColumns)
            _opdDataColumn(context, column),
        ],
        columnChoices: <AppListTableColumn<_OpdTableItem>>[
          for (final _OpdTableColumnId column in _availableOpdTableColumns)
            _opdDataColumn(context, column),
        ],
        onRowSelected: (_OpdTableItem item) =>
            _openTableItemActions(context, item),
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
          advancedFilterButtonLabel: l10n.opdFilterAction,
          advancedFilterTitle: l10n.opdFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
        ),
        mobileItemBuilder: (_, _OpdTableItem item) =>
            _OpdTableMobileRow(item: item),
        itemKeyBuilder: (_OpdTableItem item) =>
            ValueKey<String>('opd-${item.stableKey}'),
        rowColorBuilder: _opdTableRowColor,
      ),
    );
  }

  Future<void> _openTableItemActions(
    BuildContext context,
    _OpdTableItem item,
  ) async {
    final OpdAppointment? appointment = item.appointment;
    final OpdQueueEntry? queueEntry = item.queueEntry;
    final OpdFlowSummary? flow = item.flow;

    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        if (appointment != null) {
          return AppointmentActionsDialog(appointment: appointment);
        }
        if (queueEntry != null) {
          return QueueActionsDialog(entry: queueEntry);
        }
        return FlowActionsDialog(flow: flow!);
      },
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

class _OpdTableMobileRow extends StatelessWidget {
  const _OpdTableMobileRow({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    return AppListItemRow(
      title: item.title,
      subtitle: _joinDisplay(<String?>[
        item.subtitle,
        item.visitType,
        item.queue,
        _apiLabel(item.status ?? ''),
        item.billing,
        _waitingTimeLabel(context, item),
        item.provider,
        _nextStepLabel(context, item),
        _formatDateTime(context, item.time),
      ]),
      subtitleMaxLines: 3,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _QueueStatusCell extends StatelessWidget {
  const _QueueStatusCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    final String queue = item.queue ?? context.l10n.profileUnknownValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          queue,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.category == _opdCategoryTriage)
          _opdTriageStatusText(context, item.status)
        else
          _opdStatusText(context, item.status),
      ],
    );
  }
}

Widget _opdStatusText(BuildContext context, String? value) {
  final String label = _apiLabel(value ?? '');
  return AppStatusText(
    label: label.isEmpty ? context.l10n.profileUnknownValue : label,
    tone: _stageTone(value),
  );
}

Widget _opdTriageStatusText(BuildContext context, String? value) {
  final String label = _apiLabel(value ?? '');
  return AppStatusText(
    label: label.isEmpty ? context.l10n.profileUnknownValue : label,
    tone: appTriageToneForValue(value),
  );
}

class _ProviderCell extends StatelessWidget {
  const _ProviderCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    return AppListItemText(
      title: item.provider ?? context.l10n.profileUnknownValue,
      subtitle: item.facility,
    );
  }
}

String _waitingTimeLabel(BuildContext context, _OpdTableItem item) {
  final DateTime? time = item.time;
  if (time == null || _isCompletedStatus(item.status)) {
    return context.l10n.profileUnknownValue;
  }

  final Duration duration = DateTime.now().difference(time.toLocal());
  if (duration.isNegative) {
    return context.l10n.profileUnknownValue;
  }
  return _formatShortDuration(duration);
}

String _nextStepLabel(BuildContext context, _OpdTableItem item) {
  final String label = _apiLabel(item.nextStep ?? item.status ?? '');
  return label.isEmpty ? context.l10n.profileUnknownValue : label;
}

String _opdRequiredFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldRequiredLabel(label);
}

String _opdOptionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
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

AppWorkspaceStatusTone _categoryTone(String category) {
  return switch (category) {
    _opdCategoryArrival => AppWorkspaceStatusTone.info,
    _opdCategoryQueue => AppWorkspaceStatusTone.warning,
    _opdCategoryTriage => AppWorkspaceStatusTone.warning,
    _opdCategoryActiveFlow => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.providers,
    required this.schedules,
    required this.labelText,
    required this.helperText,
    required this.emptyHelperText,
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> options = _providerSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    return AppSelectField<String>.searchable(
      value: value,
      options: options,
      labelText: labelText,
      helperText: options.isEmpty && !isLoading ? emptyHelperText : helperText,
      semanticLabel: labelText,
      enabled: enabled,
      isLoading: isLoading,
      onChanged: onChanged,
    );
  }
}

class AppointmentActionsDialog extends ConsumerStatefulWidget {
  const AppointmentActionsDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<AppointmentActionsDialog> createState() =>
      _AppointmentActionsDialogState();
}

class _AppointmentActionsDialogState
    extends ConsumerState<AppointmentActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String status = (widget.appointment.status ?? '').toUpperCase();
    final bool terminal = _isCompletedStatus(status);
    final bool canQueue =
        !terminal &&
        status != 'IN_PROGRESS' &&
        widget.appointment.patientId != null;
    final bool canCheckIn =
        !terminal && status != 'IN_PROGRESS' && status != 'COMPLETED';
    final bool canReschedule = !terminal;
    final bool canCancel = !terminal && status != 'CANCELLED';

    return AppDialog(
      title: Text(widget.appointment.displayTitle),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdStatusColumnLabel,
                value: _apiLabel(widget.appointment.status ?? ''),
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: _formatDateTime(
                  context,
                  widget.appointment.scheduledStart,
                ),
              ),
              AppInfoTileData(
                label: l10n.opdReasonLabel,
                value: widget.appointment.reason ?? l10n.profileUnknownValue,
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (canQueue)
          AppButton.secondary(
            label: l10n.opdQueueAction,
            leadingIcon: Icons.queue_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .assignAppointmentToQueue(widget.appointment),
            ),
          ),
        if (canReschedule)
          AppButton.secondary(
            label: l10n.opdRescheduleAction,
            leadingIcon: Icons.edit_calendar_outlined,
            enabled: !_isSaving,
            onPressed: _openReschedule,
          ),
        if (canCancel)
          AppButton.secondary(
            label: l10n.opdCancelAction,
            leadingIcon: Icons.cancel_outlined,
            isLoading: _isSaving,
            onPressed: _openCancel,
          ),
        if (canCheckIn)
          AppButton.primary(
            label: l10n.opdCheckInAction,
            leadingIcon: Icons.login_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .checkInAppointment(widget.appointment),
            ),
          ),
      ],
    );
  }

  Future<void> _openReschedule() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RescheduleAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCancel() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class RescheduleAppointmentDialog extends ConsumerStatefulWidget {
  const RescheduleAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends ConsumerState<RescheduleAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime? _date;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime start =
        widget.appointment.scheduledStart?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    final DateTime end =
        widget.appointment.scheduledEnd?.toLocal() ??
        start.add(const Duration(minutes: 30));
    _date = DateTime(start.year, start.month, start.day);
    _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(Icons.edit_calendar_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppDateField(
              value: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.patientsAppointmentDateLabel,
              ),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              enabled: !_isSaving,
              isRequired: true,
              validator: (DateTime? value) =>
                  value == null ? l10n.validationRequired : null,
              onChanged: (DateTime? value) {
                setState(() => _date = value);
              },
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTimeField(
                  value: _startTime,
                  labelText: _opdRequiredFieldLabel(
                    l10n,
                    l10n.opdAppointmentStartLabel,
                  ),
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (TimeOfDay? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (TimeOfDay? value) {
                    setState(() => _startTime = value);
                  },
                ),
                AppTimeField(
                  value: _endTime,
                  labelText: _opdRequiredFieldLabel(
                    l10n,
                    l10n.opdAppointmentEndLabel,
                  ),
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (TimeOfDay? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (TimeOfDay? value) {
                    setState(() => _endTime = value);
                  },
                ),
              ],
            ),
            AppButton.secondary(
              label: l10n.opdCancelAction,
              leadingIcon: Icons.cancel_outlined,
              enabled: !_isSaving,
              onPressed: _cancelPatient,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdRescheduleAction,
          leadingIcon: Icons.edit_calendar_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _cancelPatient() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, null);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final DateTime? start = _combineDateAndTime(_date, _startTime);
    final DateTime? end = _combineDateAndTime(_date, _endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      setState(() {
        _failure = AppFailure.validation();
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .rescheduleAppointment(widget.appointment, start, end);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class CancelAppointmentDialog extends ConsumerStatefulWidget {
  const CancelAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<CancelAppointmentDialog> {
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
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
      title: Text(l10n.opdCancelAction),
      icon: const Icon(Icons.cancel_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _reasonController,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdCancellationReasonLabel,
            ),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdCancelAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, _reasonController.text.trim());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class QueueActionsDialog extends ConsumerStatefulWidget {
  const QueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  ConsumerState<QueueActionsDialog> createState() => _QueueActionsDialogState();
}

class _QueueActionsDialogState extends ConsumerState<QueueActionsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _status;
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _status = widget.entry.status;
    _providerId = widget.entry.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool terminal = _isCompletedStatus(widget.entry.status);

    return AppDialog(
      title: Text(widget.entry.displayTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      maxWidth: 680,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (_successMessage != null)
              AppMessagePanel(
                message: _successMessage!,
                tone: AppWorkspaceStatusTone.success,
              ),
            AppTriageSummaryPanel(
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.opdQueueStatusLabel,
                  value: _apiLabel(_status ?? widget.entry.status ?? ''),
                ),
                AppInfoTileData(
                  label: l10n.opdProviderColumnLabel,
                  value:
                      widget.entry.providerDisplayName ??
                      l10n.profileUnknownValue,
                ),
                AppInfoTileData(
                  label: l10n.opdTimeColumnLabel,
                  value: _formatDateTime(context, widget.entry.queuedAt),
                ),
              ],
              emptyValue: l10n.profileUnknownValue,
            ),
            AppSelectField<String>(
              value: _status,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdQueueStatusLabel),
              enabled: !terminal && !_isSaving,
              onChanged: (String? value) => setState(() => _status = value),
              options: _statusOptions(_queueStatuses),
            ),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
              enabled: !_isSaving,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
            AppTextField(
              controller: _reasonController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdReasonLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdPrioritizeAction,
            leadingIcon: Icons.priority_high_outlined,
            isLoading: _isSaving,
            onPressed: () => _runInModal(
              action: () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .prioritizeQueueEntry(
                    widget.entry,
                    _reasonController.text.trim(),
                  ),
              successMessage: l10n.opdSavedMessage,
              successStatus: 'CONFIRMED',
            ),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdMoveQueueAction,
            leadingIcon: Icons.sync_alt_outlined,
            isLoading: _isSaving,
            onPressed: _submitMove,
          ),
        if (!terminal)
          AppButton.primary(
            label: l10n.opdStartConsultationAction,
            leadingIcon: Icons.play_arrow_outlined,
            isLoading: _isSaving,
            onPressed: () => _runInModal(
              action: () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .startOpdFromQueue(widget.entry),
              successMessage: l10n.opdStartConsultationAction,
              successStatus: 'IN_PROGRESS',
            ),
          ),
      ],
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submitMove() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _runInModal(
      action: () => ref
          .read(opdWorkspaceControllerProvider.notifier)
          .moveQueueEntry(widget.entry, <String, Object?>{
            'status': _status,
            'provider_user_id': _providerId,
          }),
      successMessage: context.l10n.opdSavedMessage,
      successStatus: _status,
    );
  }

  Future<void> _runInModal({
    required Future<AppFailure?> Function() action,
    required String successMessage,
    String? successStatus,
  }) async {
    setState(() {
      _isSaving = true;
      _failure = null;
      _successMessage = null;
    });
    final AppFailure? failure = await action();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      setState(() {
        _successMessage = successMessage;
        _status = successStatus ?? _status;
        _isSaving = false;
      });
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppSelectOption<String>> _providerSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
}) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};

  for (final OpdProviderOption provider in providers) {
    final String value = provider.id;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        provider.displayTitle,
        provider.positionTitle,
        provider.practitionerType,
        provider.staffProfileId,
        value,
      ]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: provider.displayTitle,
        subtitle: _joinDisplay(<String?>[
          provider.positionTitle,
          provider.practitionerType,
          provider.staffProfileId,
        ]),
      ),
    );
  }

  for (final OpdProviderSchedule schedule in schedules) {
    final String value = schedule.providerApiId;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        schedule.providerDisplayName,
        value,
        schedule.facilityName,
      ]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: schedule.providerDisplayName ?? value,
        subtitle: schedule.facilityName,
      ),
    );
  }

  return options.values.toList(growable: false);
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

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values, separator: ' | ');
}

AppWorkspaceStatusTone _stageTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' || 'DISCHARGED' || 'ADMITTED' => AppWorkspaceStatusTone.success,
    'NORMAL' || 'ROUTINE' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'NO_SHOW' => AppWorkspaceStatusTone.error,
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'ABNORMAL' || 'SERVICE_ONLY' => AppWorkspaceStatusTone.warning,
    'WAITING_CONSULTATION_PAYMENT' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
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

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];
