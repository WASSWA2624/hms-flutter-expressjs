import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';

class OpdWorkspacePage extends ConsumerWidget {
  const OpdWorkspacePage({this.initialQuery, super.key});

  final OpdWorkspaceQuery? initialQuery;

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
        return _OpdWorkspaceContent(state: data, initialQuery: initialQuery);
      },
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
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tableColumnController =
        AppListTableColumnVisibilityController<_OpdTableItem>(
          storageKey: 'opd.worklist',
        );
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
    final OpdWorkspaceState state = widget.state;
    final OpdWorkspaceController controller = ref.read(
      opdWorkspaceControllerProvider.notifier,
    );
    return AppWorkspace(
      title: l10n.opdTitle,
      leadingIcon: AppRouteIcons.opd,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: _opdBackendSummaryNotifications(
          context,
          state.summaryCounts,
        ),
        primary: AppAccessActionGate(
          requirement: opdEncounterPermissionRequirement,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.primary(
              label: l10n.opdStartWalkInAction,
              leadingIcon: opdEncounterIcon,
              semanticLabel: l10n.opdStartWalkInAction,
              tooltip: l10n.opdStartEncounterTooltip,
              enabled: isAllowed,
              onPressed: () {
                _openOpdEncounterDialog(context, ref);
              },
            );
          },
        ),
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing:
            state.isRefreshingAppointments ||
            state.isRefreshingQueue ||
            state.isRefreshingFlows ||
            state.isRefreshingTriageQueue,
      ),

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
                    columnVisibilityController: _tableColumnController,
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

  List<AppWorkspaceSummaryNotification> _opdBackendSummaryNotifications(
    BuildContext context,
    OpdFlowAggregateCounts counts,
  ) {
    final List<AppWorkspaceSummaryNotification> notifications =
        <AppWorkspaceSummaryNotification>[];

    void addCard(
      String key,
      int value,
      IconData icon, {
      AppWorkspaceStatusTone? tone,
      _OpdTableFilter filter = const _OpdTableFilter(),
    }) {
      if (value <= 0) {
        return;
      }
      notifications.add(
        AppWorkspaceSummaryNotification(
          label: opdSummaryCountLabel(context.l10n, key),
          count: value,
          icon: icon,
          tone: tone ?? AppWorkspaceStatusTone.neutral,
          onSelected: () => _applySummaryFilter(filter),
        ),
      );
    }

    addCard('all_patients', counts.allPatients, Icons.groups_outlined);
    addCard(
      'all_opd_patients',
      counts.allOpdPatients,
      Icons.local_hospital_outlined,
    );
    addCard(
      'active_opd',
      counts.activeOpd,
      Icons.medical_services_outlined,
      tone: AppWorkspaceStatusTone.success,
      filter: const _OpdTableFilter(category: _opdCategoryActiveFlow),
    );
    addCard(
      'vitals_needed',
      counts.vitalsNeeded,
      Icons.monitor_heart_outlined,
      tone: AppWorkspaceStatusTone.warning,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{'VITALS_NEEDED', 'WAITING_VITALS'},
      ),
    );
    addCard(
      'doctor_needed',
      counts.doctorNeeded,
      Icons.assignment_ind_outlined,
      tone: AppWorkspaceStatusTone.warning,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{'DOCTOR_NEEDED', 'WAITING_DOCTOR_ASSIGNMENT'},
      ),
    );
    addCard(
      'with_doctor',
      counts.withDoctor,
      Icons.medical_services_outlined,
      tone: AppWorkspaceStatusTone.info,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{'WITH_DOCTOR', 'WAITING_DOCTOR_REVIEW'},
      ),
    );
    addCard(
      'lab_pending',
      counts.labPending,
      Icons.science_outlined,
      tone: AppWorkspaceStatusTone.info,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{
          'LAB_PENDING',
          'SAMPLE_PENDING',
          'IN_LAB',
          'LAB_REQUESTED',
          'LAB_AND_RADIOLOGY_REQUESTED',
        },
      ),
    );
    addCard(
      'imaging_pending',
      counts.imagingPending,
      Icons.biotech_outlined,
      tone: AppWorkspaceStatusTone.info,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{
          'IMAGING_PENDING',
          'REPORT_PENDING',
          'RADIOLOGY_REQUESTED',
          'LAB_AND_RADIOLOGY_REQUESTED',
        },
      ),
    );
    addCard(
      'pharmacy_pending',
      counts.pharmacyPending,
      Icons.medication_outlined,
      tone: AppWorkspaceStatusTone.warning,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{'PHARMACY_PENDING', 'PHARMACY_REQUESTED'},
      ),
    );
    addCard(
      'decision_needed',
      counts.decisionNeeded,
      Icons.task_alt_outlined,
      tone: AppWorkspaceStatusTone.info,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{
          'DECISION_NEEDED',
          'RESULTS_READY',
          'REPORT_READY',
          'MEDICINES_DISPENSED',
          'WAITING_DISPOSITION',
        },
      ),
    );
    addCard(
      'admission_pending',
      counts.admissionPending,
      Icons.bed_outlined,
      tone: AppWorkspaceStatusTone.warning,
      filter: const _OpdTableFilter(
        category: _opdCategoryActiveFlow,
        statuses: <String>{'ADMISSION_PENDING'},
      ),
    );

    return notifications;
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
    OpdFlowSummary? activeEncounterToOpen;
    final OpdEncounterDialogResult? result = await showOpdEncounterDialog(
      context: context,
      dialog: OpdEncounterDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        activeFlows: <OpdFlowSummary>[
          ...widget.state.flows.items,
          ...widget.state.triageQueue.items,
        ],
        source: 'opd_workspace',
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .submitOpdEncounter(payload);
        },
        onExistingActiveEncounter: (OpdFlowSummary flow) {
          activeEncounterToOpen = flow;
        },
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    final OpdFlowSummary? existingFlow = activeEncounterToOpen;
    if (existingFlow != null) {
      final bool? changed = await showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FlowActionsDialog(flow: existingFlow),
      );
      if (changed == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
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
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }
    if (query.search.isNotEmpty || query.panel.isNotEmpty) {
      final _OpdTableFilter panelFilter = _opdFilterForPanel(query.panel);
      _setFilter(panelFilter.copyWith(search: query.search));
    }
    if (query.flowId.isNotEmpty) {
      await _openFlowById(query.flowId);
    }
  }

  Future<void> _openFlowById(String identifier) async {
    final OpdFlowSummary? flow = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .resolveFlowById(identifier);
    if (!mounted || flow == null) {
      return;
    }
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FlowActionsDialog(flow: flow),
    );
    if (changed == true && mounted) {
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
    required this.columnVisibilityController,
    required this.pageRequest,
    required this.onPageChanged,
    required this.onFilterChanged,
  });

  final OpdWorkspaceState state;
  final _OpdTableFilter filter;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<_OpdTableItem>
  columnVisibilityController;
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
      state: state,
      page: _tablePage(items, pageRequest),
      searchController: searchController,
      columnVisibilityController: columnVisibilityController,
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
      nextStep: context.l10n.opdStartWalkInAction,
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
      nextStep: context.l10n.opdStartWalkInAction,
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
    'SUPER_ADMIN' ||
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

String _opdTableColumnLabel(BuildContext context, _OpdTableColumnId column) {
  final l10n = context.l10n;
  return switch (column) {
    _OpdTableColumnId.patientNumber => l10n.patientsPatientNumberColumnLabel,
    _OpdTableColumnId.patientName => l10n.opdPatientColumnLabel,
    _OpdTableColumnId.arrivalMode => l10n.opdArrivalModeColumnLabel,
    _OpdTableColumnId.visitType => l10n.opdVisitTypeColumnLabel,
    _OpdTableColumnId.queueStatus => l10n.opdQueueStatusColumnLabel,
    _OpdTableColumnId.provider => l10n.opdProviderColumnLabel,
    _OpdTableColumnId.waitingTime => l10n.opdWaitingTimeColumnLabel,
    _OpdTableColumnId.arrivalTime => l10n.opdTimeColumnLabel,
    _OpdTableColumnId.nextStep => l10n.opdNextStepColumnLabel,
    _OpdTableColumnId.encounter => l10n.opdEncounterColumnLabel,
  };
}

AppListTableColumn<_OpdTableItem> _opdDataColumn(
  BuildContext context,
  _OpdTableColumnId column,
) {
  final String label = _opdTableColumnLabel(context, column);

  return AppListTableColumn<_OpdTableItem>(
    id: column.name,
    label: label,
    sortComparator: _opdSortComparator(column),
    cellBuilder: (BuildContext context, _OpdTableItem item) {
      return switch (column) {
        _OpdTableColumnId.patientNumber => Text(
          item.patientNumber ?? context.l10n.profileUnknownValue,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.patientName => Text(
          item.patientName ?? item.title,
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
        _OpdTableColumnId.queueStatus => _QueueStatusCell(item: item),
        _OpdTableColumnId.provider => _ProviderCell(item: item),
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
        _OpdTableColumnId.encounter => _OpdEncounterCell(item: item),
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
      _OpdTableColumnId.patientNumber => appListTableCompareText(
        left.patientNumber,
        right.patientNumber,
      ),
      _OpdTableColumnId.patientName => appListTableCompareText(
        left.patientName ?? left.title,
        right.patientName ?? right.title,
      ),
      _OpdTableColumnId.arrivalMode => appListTableCompareText(
        left.arrivalMode ?? left.flow?.arrivalMode,
        right.arrivalMode ?? right.flow?.arrivalMode,
      ),
      _OpdTableColumnId.visitType => appListTableCompareText(
        left.visitType,
        right.visitType,
      ),
      _OpdTableColumnId.queueStatus => appListTableCompareText(
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
      _OpdTableColumnId.nextStep => appListTableCompareText(
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
  patientNumber,
  patientName,
  arrivalMode,
  visitType,
  queueStatus,
  provider,
  waitingTime,
  arrivalTime,
  nextStep,
  encounter,
}

const int _defaultUrgencyRank = 99;
final DateTime _unknownArrivalTime = DateTime(9999);

const List<_OpdTableColumnId> _defaultOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patientNumber,
  _OpdTableColumnId.patientName,
  _OpdTableColumnId.queueStatus,
  _OpdTableColumnId.nextStep,
  _OpdTableColumnId.provider,
];

const List<_OpdTableColumnId> _availableOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patientNumber,
  _OpdTableColumnId.patientName,
  _OpdTableColumnId.arrivalMode,
  _OpdTableColumnId.waitingTime,
  _OpdTableColumnId.queueStatus,
  _OpdTableColumnId.nextStep,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.encounter,
  _OpdTableColumnId.arrivalTime,
  _OpdTableColumnId.visitType,
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

    return SizedBox(
      width: double.infinity,
      child: AppListTable<_OpdTableItem>(
        page: page,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityStorageKey: 'opd.worklist',
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
          for (final _OpdTableColumnId column in _defaultOpdTableColumns)
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
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OpdPatientActionsDialog(item: item, state: state),
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
      title: item.patientName ?? item.title,
      subtitle: _joinDisplay(<String?>[
        item.patientNumber,
        _arrivalModeLabel(context, item),
        _waitingTimeLabel(context, item),
      ]),
      details: <Widget>[
        AppStatusText(
          label: _queueStatusLabel(context, item),
          tone: item.category == _opdCategoryTriage
              ? appTriageToneForValue(item.status)
              : _stageTone(item.status),
        ),
        Text(
          _nextStepLabel(context, item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _QueueStatusCell extends StatelessWidget {
  const _QueueStatusCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    final String label = _queueStatusLabel(context, item);
    if (item.category == _opdCategoryTriage) {
      return AppStatusText(
        label: label,
        tone: appTriageToneForValue(item.status),
      );
    }
    return AppStatusText(
      label: label,
      tone: _stageTone(item.status ?? item.flow?.stage),
    );
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
  final String statusLabel = _queueStatusLabel(context, item);
  final String? rawNext = item.flow?.displayNextStep ?? item.nextStep;
  if (rawNext == null || rawNext.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }

  final String label = opdNextStepDisplayLabel(context.l10n, rawNext);
  if (label.isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  if (label.toLowerCase() == statusLabel.toLowerCase()) {
    final String? ownerRole = item.ownerRole;
    if (ownerRole != null && ownerRole.trim().isNotEmpty) {
      return ownerRole;
    }
  }
  return label;
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

class _OpdPatientActionsDialog extends ConsumerStatefulWidget {
  const _OpdPatientActionsDialog({required this.item, required this.state});

  final _OpdTableItem item;
  final OpdWorkspaceState state;

  @override
  ConsumerState<_OpdPatientActionsDialog> createState() =>
      _OpdPatientActionsDialogState();
}

class _OpdPatientActionsDialogState
    extends ConsumerState<_OpdPatientActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final OpdFlowSummary? flow = widget.item.flow;
    if (flow != null) {
      return FlowActionsDialog(flow: flow);
    }

    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.item.title),
      icon: const Icon(Icons.medical_services_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 860,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdStatusColumnLabel,
                value: opdStageDisplayLabel(l10n, widget.item.status),
              ),
              AppInfoTileData(
                label: l10n.opdVisitTypeColumnLabel,
                value: widget.item.visitType ?? l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value: widget.item.provider ?? opdUnknownProviderLabel,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: _formatDateTime(context, widget.item.time),
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
          AppActionSection(
            title: l10n.opdActionsColumnLabel,
            minItemWidth: 170,
            maxColumns: 4,
            permissionActions: _actions(context),
          ),
        ],
      ),
    );
  }

  List<AppPermissionActionItem> _actions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdAppointment? appointment = widget.item.appointment;
    final OpdQueueEntry? queueEntry = widget.item.queueEntry;
    final bool terminal = _isCompletedStatus(widget.item.status);
    final String inactiveReason = l10n.opdInactiveEncounterActionReason;
    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[];

    AppPermissionActionItem action({
      required AccessRequirement requirement,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      AppButtonVariant variant = AppButtonVariant.secondary,
      bool enabled = true,
      String? tooltip,
    }) {
      final bool isEnabled = enabled && !_isSaving && onPressed != null;
      return AppPermissionActionItem(
        requirement: requirement,
        label: label,
        icon: icon,
        fullWidth: true,
        variant: variant,
        enabled: isEnabled,
        hideWhenDenied: true,
        tooltip: isEnabled ? null : tooltip ?? inactiveReason,
        onPressed: isEnabled ? onPressed : null,
      );
    }

    if (appointment != null) {
      final String status = (appointment.status ?? '').toUpperCase();
      final bool canCheckIn =
          !terminal && status != 'IN_PROGRESS' && status != 'COMPLETED';
      actions.addAll(<AppPermissionActionItem>[
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdCheckInAction,
          icon: Icons.login_outlined,
          variant: AppButtonVariant.primary,
          enabled: canCheckIn,
          tooltip: terminal ? l10n.opdStatusColumnLabel : null,
          onPressed: _openAppointmentCheckIn,
        ),
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdQueueAction,
          icon: Icons.queue_outlined,
          enabled:
              !terminal &&
              status != 'IN_PROGRESS' &&
              appointment.patientId != null,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .assignAppointmentToQueue(appointment),
          ),
        ),
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdRescheduleAction,
          icon: Icons.edit_calendar_outlined,
          enabled: !terminal,
          onPressed: () => _openNested(
            RescheduleAppointmentDialog(appointment: appointment),
          ),
        ),
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdCancelAction,
          icon: Icons.cancel_outlined,
          enabled: !terminal && status != 'CANCELLED',
          onPressed: () =>
              _openNested(CancelAppointmentDialog(appointment: appointment)),
        ),
      ]);
    }

    if (queueEntry != null) {
      actions.addAll(<AppPermissionActionItem>[
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdStartConsultationAction,
          icon: Icons.play_arrow_outlined,
          variant: AppButtonVariant.primary,
          enabled: !terminal,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .startOpdFromQueue(queueEntry),
          ),
        ),
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdPrioritizeAction,
          icon: Icons.priority_high_outlined,
          enabled: !terminal,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .prioritizeQueueEntry(queueEntry, null),
          ),
        ),
        action(
          requirement: opdFrontDeskActionRequirement,
          label: l10n.opdMoveQueueAction,
          icon: Icons.sync_alt_outlined,
          enabled: !terminal,
          onPressed: () => _openNested(QueueActionsDialog(entry: queueEntry)),
        ),
      ]);
    }

    return actions;
  }

  Future<void> _openAppointmentCheckIn() async {
    final OpdAppointment? appointment = widget.item.appointment;
    if (appointment == null) {
      return;
    }
    OpdFlowSummary? activeEncounterToOpen;
    final OpdEncounterDialogResult? dialogResult = await showOpdEncounterDialog(
      context: context,
      dialog: OpdEncounterDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        activeFlows: <OpdFlowSummary>[
          ...widget.state.flows.items,
          ...widget.state.triageQueue.items,
        ],
        initialAppointment: appointment,
        initialAppointmentId: appointment.apiId,
        defaultArrivalMode: 'ONLINE_APPOINTMENT',
        defaultProviderId: appointment.providerUserId,
        source: 'opd_workspace',
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .submitOpdEncounter(payload);
        },
        onExistingActiveEncounter: (OpdFlowSummary flow) {
          activeEncounterToOpen = flow;
        },
      ),
    );
    if (!mounted || dialogResult == null) {
      return;
    }
    final OpdFlowSummary? activeEncounter = activeEncounterToOpen;
    if (activeEncounter == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (!mounted) {
      return;
    }
    final bool? activeChanged = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FlowActionsDialog(flow: activeEncounter),
    );
    if (mounted) {
      Navigator.of(context).pop(activeChanged == true);
    }
  }

  Future<void> _openNested(Widget dialog) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    if (_isSaving) {
      return;
    }
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

class AppointmentActionsDialog extends ConsumerStatefulWidget {
  const AppointmentActionsDialog({
    required this.appointment,
    required this.state,
    super.key,
  });

  final OpdAppointment appointment;
  final OpdWorkspaceState state;

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
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
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
            onPressed: _openCheckIn,
          ),
      ],
    );
  }

  Future<void> _openCheckIn() async {
    final OpdEncounterDialogResult? dialogResult = await showOpdEncounterDialog(
      context: context,
      dialog: OpdEncounterDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        activeFlows: <OpdFlowSummary>[
          ...widget.state.flows.items,
          ...widget.state.triageQueue.items,
        ],
        initialAppointment: widget.appointment,
        initialAppointmentId: widget.appointment.apiId,
        defaultArrivalMode: 'ONLINE_APPOINTMENT',
        defaultProviderId: widget.appointment.providerUserId,
        source: 'opd_workspace',
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .submitOpdEncounter(payload);
        },
      ),
    );
    if (!mounted || dialogResult == null) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
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
  late AppTimeValue? _startTime;
  late AppTimeValue? _endTime;
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
    _startTime = AppTimeValue(hour: start.hour, minute: start.minute);
    _endTime = AppTimeValue(hour: end.hour, minute: end.minute);
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
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
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
                  hourLabelText: l10n.appTimeHourLabel,
                  minuteLabelText: l10n.appTimeMinuteLabel,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (AppTimeValue? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (AppTimeValue? value) {
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
                  hourLabelText: l10n.appTimeHourLabel,
                  minuteLabelText: l10n.appTimeMinuteLabel,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (AppTimeValue? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (AppTimeValue? value) {
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

  DateTime? _combineDateAndTime(DateTime? date, AppTimeValue? time) {
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
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
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
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (_successMessage != null)
              AppFormInformationBanner.message(
                message: _successMessage!,
                variant: AppFormInformationVariant.success,
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
          _providerOptions = dedupeOpdProviderOptions(providers);
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
  return opdProviderSelectOptions(providers: providers, schedules: schedules);
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

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];
