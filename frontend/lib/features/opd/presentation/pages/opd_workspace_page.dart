import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const IconData startOpdEncounterIcon = Icons.person_add_alt_1_outlined;

const AccessRequirement startOpdEncounterPermissionRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.patientWrite,
        AppPermissions.clinicalWrite,
        AppPermissions.billingWrite,
        AppPermissions.operationsWrite,
        AppPermissions.emergencyWrite,
      ],
      activeModules: <String>['scheduling-queue'],
    );

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
        requirement: startOpdEncounterPermissionRequirement,
        builder: (BuildContext context, bool isAllowed) {
          if (iconOnly) {
            return AppIconButton(
              icon: startOpdEncounterIcon,
              semanticLabel: l10n.opdStartWalkInAction,
              tooltip: l10n.opdStartEncounterTooltip,
              enabled: isAllowed,
              onPressed: () {
                _openStartOpdEncounterDialog(context, ref);
              },
            );
          }

          return AppButton.primary(
            label: l10n.opdStartWalkInAction,
            leadingIcon: startOpdEncounterIcon,
            enabled: isAllowed,
            onPressed: () {
              _openStartOpdEncounterDialog(context, ref);
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

  Future<void> _openStartOpdEncounterDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartOpdEncounterDialog(
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

  String get categoryKey {
    final OpdFlowSummary? activeFlow = flow;
    final OpdQueueEntry? activeQueue = queueEntry;
    final OpdAppointment? activeAppointment = appointment;
    return activeFlow?.patientId ??
        activeFlow?.patientIdentifier ??
        activeQueue?.patientId ??
        activeQueue?.patientIdentifier ??
        activeAppointment?.patientId ??
        activeAppointment?.patientIdentifier ??
        id;
  }

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
  final Map<String, _OpdTableItem> activeItemsByPatient =
      <String, _OpdTableItem>{};
  final List<_OpdTableItem> items = <_OpdTableItem>[];

  void upsertActiveFlowItem(_OpdTableItem item) {
    final String key = item.categoryKey;
    final _OpdTableItem? existing = activeItemsByPatient[key];
    if (existing == null || _preferOpdTableItem(item, existing)) {
      activeItemsByPatient[key] = item;
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

  final Set<String> usedPatientKeys = activeItemsByPatient.keys.toSet();
  items.addAll(activeItemsByPatient.values);

  for (final OpdQueueEntry entry in state.queueEntries.items) {
    if (_isCompletedStatus(entry.status)) {
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
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
  }

  for (final OpdAppointment appointment in state.appointments.items) {
    if (_isCompletedStatus(appointment.status)) {
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
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
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
  final String status = _flowBillingStatusLabel(context, flow);
  final bool isPaid = _flowBillingState(flow) == _opdBillingStatePaid;
  final num? billingAmount = isPaid
      ? flow.consultationPaidAmount
      : flow.consultationFee;
  final String? amount = _moneyLabel(
    context,
    billingAmount,
    flow.consultationCurrency,
  );
  return _joinDisplay(<String?>[status, amount]);
}

String _flowBillingStatusLabel(BuildContext context, OpdFlowSummary flow) {
  return _billingStateLabel(context, _flowBillingState(flow));
}

String _flowBillingState(OpdFlowSummary flow) {
  final String stage = (flow.stage ?? '').toUpperCase();
  final String paymentStatus = (flow.consultationPaymentStatus ?? '')
      .trim()
      .toUpperCase();
  final num? paidAmount = flow.consultationPaidAmount;
  final num? fee = flow.consultationFee;
  final bool paymentCoversFee =
      paidAmount != null &&
      paidAmount > 0 &&
      (fee == null || fee <= 0 || paidAmount >= fee);
  if (flow.consultationPaid ||
      paymentStatus == 'PAID' ||
      paymentStatus == 'CLEARED' ||
      (paymentStatus == 'COMPLETED' && paymentCoversFee)) {
    return _opdBillingStatePaid;
  }
  if (flow.consultationPaymentRequired ||
      stage == 'WAITING_CONSULTATION_PAYMENT') {
    return _opdBillingStateRequired;
  }
  return _opdBillingStateNotRequired;
}

String _billingStateLabel(BuildContext context, String value) {
  return switch (value) {
    _opdBillingStatePaid => context.l10n.opdPaymentPaidLabel,
    _opdBillingStateRequired => context.l10n.opdPaymentRequiredLabel,
    _opdBillingStateNotRequired => context.l10n.opdPaymentNotRequiredLabel,
    _ => context.l10n.profileUnknownValue,
  };
}

AppWorkspaceStatusTone _flowBillingTone(OpdFlowSummary flow) {
  return _billingStateTone(_flowBillingState(flow));
}

String _queueBillingLabel(BuildContext context, OpdQueueEntry entry) {
  final String status = (entry.paymentStatus ?? '').trim();
  final String billingState = _queueBillingState(entry);
  final num? billingAmount = billingState == _opdBillingStatePaid
      ? entry.amountPaid
      : entry.amountToPay;
  final String? amount = _moneyLabel(context, billingAmount, entry.currency);
  if (status.isEmpty) {
    return amount ?? context.l10n.profileUnknownValue;
  }
  return _joinDisplay(<String?>[_apiLabel(status), amount]);
}

String _queueBillingState(OpdQueueEntry entry) {
  final String status = (entry.paymentStatus ?? '').toUpperCase();
  if (entry.amountPaid != null && entry.amountPaid! > 0 && status.isEmpty) {
    return _opdBillingStatePaid;
  }
  if (entry.amountToPay != null && entry.amountToPay! > 0 && status.isEmpty) {
    return _opdBillingStateRequired;
  }
  return switch (status) {
    'PAID' ||
    'COMPLETED' ||
    'COVERED' ||
    'WAIVED' ||
    'CLEARED' => _opdBillingStatePaid,
    'PENDING' ||
    'PENDING_PAYMENT' ||
    'INVOICE_CREATED' ||
    'PARTIAL' => _opdBillingStateRequired,
    'NOT_REQUIRED' || 'NO_CHARGE' => _opdBillingStateNotRequired,
    _ => _opdBillingStateUnknown,
  };
}

AppWorkspaceStatusTone _queueBillingTone(OpdQueueEntry entry) {
  final String status = (entry.paymentStatus ?? '').toUpperCase();
  if (status == 'FAILED' || status == 'VOID' || status == 'CANCELLED') {
    return AppWorkspaceStatusTone.error;
  }
  return _billingStateTone(_queueBillingState(entry));
}

AppWorkspaceStatusTone _billingStateTone(String value) {
  return switch (value) {
    _opdBillingStatePaid => AppWorkspaceStatusTone.success,
    _opdBillingStateRequired => AppWorkspaceStatusTone.warning,
    _opdBillingStateNotRequired => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String? _moneyLabel(BuildContext context, num? amount, String? currency) {
  if (amount == null || amount == 0) {
    return null;
  }
  return AppFormatters.currency(
    amount,
    Localizations.localeOf(context),
    currencyCode: currency,
  );
}

String _currencyAmountInput(num? amount) {
  if (amount == null) {
    return '';
  }
  if (amount is int || amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toString();
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
            ValueKey<String>('${item.category}-${item.id}'),
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

enum _OpdVitalIndicatorState { normal, abnormal, critical }

int _abnormalVitalCount(
  OpdFlowDetail? detail,
  List<OpdClinicalAlertThreshold> thresholds,
) {
  if (detail == null) {
    return 0;
  }
  return detail.vitalMeasurements
      .where(
        (OpdVitalSign vital) =>
            _vitalIndicatorState(
              vital,
              thresholds,
              detail.clinicalAlertDetails,
            ) !=
            _OpdVitalIndicatorState.normal,
      )
      .length;
}

_OpdVitalIndicatorState _vitalIndicatorState(
  OpdVitalSign vital,
  List<OpdClinicalAlertThreshold> thresholds,
  List<OpdClinicalAlert> alerts,
) {
  final bool hasCriticalAlert = alerts.any(
    (OpdClinicalAlert alert) =>
        alert.vitalSignId == vital.id &&
        (alert.status ?? '').toUpperCase() != 'RESOLVED' &&
        (alert.severity ?? '').toUpperCase() == 'CRITICAL',
  );
  if (hasCriticalAlert) {
    return _OpdVitalIndicatorState.critical;
  }

  var state = _OpdVitalIndicatorState.normal;
  for (final OpdVitalComponentValue component in vital.componentValues) {
    final OpdClinicalAlertThreshold? threshold = _matchingThreshold(
      component,
      thresholds,
    );
    if (threshold == null) {
      continue;
    }

    final _OpdVitalIndicatorState next = _stateForThreshold(
      component.value,
      threshold,
    );
    if (next == _OpdVitalIndicatorState.critical) {
      return next;
    }
    if (next == _OpdVitalIndicatorState.abnormal) {
      state = next;
    }
  }

  if (state == _OpdVitalIndicatorState.normal) {
    final bool hasOpenAlert = alerts.any(
      (OpdClinicalAlert alert) =>
          alert.vitalSignId == vital.id &&
          (alert.status ?? '').toUpperCase() != 'RESOLVED',
    );
    if (hasOpenAlert) {
      return _OpdVitalIndicatorState.abnormal;
    }
  }

  return state;
}

OpdClinicalAlertThreshold? _matchingThreshold(
  OpdVitalComponentValue component,
  List<OpdClinicalAlertThreshold> thresholds,
) {
  for (final String ageBand in const <String>['ADULT', '']) {
    for (final OpdClinicalAlertThreshold threshold in thresholds) {
      if (!threshold.isActive) {
        continue;
      }
      if (threshold.vitalType != component.vitalType ||
          threshold.component != component.component) {
        continue;
      }
      if (ageBand.isNotEmpty && threshold.ageBand != ageBand) {
        continue;
      }
      return threshold;
    }
  }
  return null;
}

_OpdVitalIndicatorState _stateForThreshold(
  num value,
  OpdClinicalAlertThreshold threshold,
) {
  final num? criticalLow = threshold.criticalLow;
  final num? criticalHigh = threshold.criticalHigh;
  final num? normalMin = threshold.normalMin;
  final num? normalMax = threshold.normalMax;

  if (criticalLow != null && value < criticalLow) {
    return _OpdVitalIndicatorState.critical;
  }
  if (criticalHigh != null && value > criticalHigh) {
    return _OpdVitalIndicatorState.critical;
  }
  if (normalMin != null && value < normalMin) {
    return _OpdVitalIndicatorState.abnormal;
  }
  if (normalMax != null && value > normalMax) {
    return _OpdVitalIndicatorState.abnormal;
  }
  return _OpdVitalIndicatorState.normal;
}

AppWorkspaceStatusTone _alertTone(String? severity) {
  return switch ((severity ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'MEDIUM' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
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

enum _WalkInPatientMode { existing, appointment, newPatient }

class _WalkInModeSelector extends StatelessWidget {
  const _WalkInModeSelector({
    required this.value,
    required this.enabled,
    required this.existingLabel,
    required this.appointmentLabel,
    required this.newPatientLabel,
    required this.onChanged,
  });

  final _WalkInPatientMode value;
  final bool enabled;
  final String existingLabel;
  final String appointmentLabel;
  final String newPatientLabel;
  final ValueChanged<_WalkInPatientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SegmentedButton<_WalkInPatientMode>(
      expandedInsets: EdgeInsets.zero,
      segments: <ButtonSegment<_WalkInPatientMode>>[
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.existing,
          label: _WalkInTabLabel(existingLabel),
          icon: const Icon(Icons.badge_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.appointment,
          label: _WalkInTabLabel(appointmentLabel),
          icon: const Icon(Icons.event_available_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.newPatient,
          label: _WalkInTabLabel(newPatientLabel),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
      selected: <_WalkInPatientMode>{value},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(theme.spacing.none, 44)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
      ),
      onSelectionChanged: enabled
          ? (Set<_WalkInPatientMode> selected) => onChanged(selected.first)
          : null,
    );
  }
}

class _WalkInTabLabel extends StatelessWidget {
  const _WalkInTabLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

typedef OpdPayloadSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

class StartOpdEncounterDialog extends ConsumerStatefulWidget {
  const StartOpdEncounterDialog({
    required this.providerSchedules,
    required this.appointments,
    this.activeFlows = const <OpdFlowSummary>[],
    this.source,
    this.initialPatientId,
    this.initialPatient,
    this.initialAppointmentId,
    this.initialAppointment,
    this.defaultArrivalMode = 'WALK_IN',
    this.defaultProviderId,
    this.onSuccess,
    this.onExistingActiveEncounter,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAppointment> appointments;
  final List<OpdFlowSummary> activeFlows;
  final String? source;
  final String? initialPatientId;
  final Patient? initialPatient;
  final String? initialAppointmentId;
  final OpdAppointment? initialAppointment;
  final String defaultArrivalMode;
  final String? defaultProviderId;
  final VoidCallback? onSuccess;
  final ValueChanged<OpdFlowSummary>? onExistingActiveEncounter;
  final OpdPayloadSubmit onSubmit;

  @override
  ConsumerState<StartOpdEncounterDialog> createState() =>
      _StartOpdEncounterDialogState();
}

class _StartOpdEncounterDialogState
    extends ConsumerState<StartOpdEncounterDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _newPatientFirstNameController;
  late final TextEditingController _newPatientLastNameController;
  late final TextEditingController _feeController;
  late final TextEditingController _notesController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  bool _isResolvingActiveEncounter = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  OpdFlowSummary? _activeEncounter;
  String? _newPatientGender;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  bool _requireConsultationPayment = true;
  bool _isSaving = false;
  AppFailure? _failure;
  int _activeEncounterLookupToken = 0;
  bool _appliedInitialContext = false;

  @override
  void initState() {
    super.initState();
    _newPatientFirstNameController = TextEditingController();
    _newPatientLastNameController = TextEditingController();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _patientOptions = <Patient>[
      if (widget.initialPatient != null) widget.initialPatient!,
    ];
    _appointmentOptions = _eligibleAppointmentOptions(<OpdAppointment>[
      ...widget.appointments,
      if (widget.initialAppointment != null) widget.initialAppointment!,
    ]);
    _patientId = _initialPatientApiId();
    _appointmentId = _initialAppointmentApiId();
    _providerId =
        widget.defaultProviderId ?? widget.initialAppointment?.providerUserId;
    _arrivalMode =
        widget.defaultArrivalMode.toUpperCase() == 'ONLINE_APPOINTMENT'
        ? 'WALK_IN'
        : widget.defaultArrivalMode.toUpperCase();
    if (_appointmentId != null) {
      _patientMode = _WalkInPatientMode.appointment;
      _arrivalMode = 'ONLINE_APPOINTMENT';
    } else if (_patientId != null) {
      _patientMode = _WalkInPatientMode.existing;
    }
    unawaited(_loadPatientOptions());
    unawaited(_loadAppointmentOptions());
    unawaited(_loadProviderOptions());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyInitialContext();
        _refreshActiveEncounterForSelection();
      }
    });
  }

  @override
  void dispose() {
    _newPatientFirstNameController.dispose();
    _newPatientLastNameController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _initialPatientApiId() {
    return _firstNonEmptyText(<String?>[
      widget.initialPatient?.publicId,
      widget.initialPatient?.id,
      widget.initialPatientId,
    ]);
  }

  String? _initialAppointmentApiId() {
    return _firstNonEmptyText(<String?>[
      widget.initialAppointment?.publicId,
      widget.initialAppointment?.id,
      widget.initialAppointmentId,
    ]);
  }

  void _applyInitialContext({bool force = false}) {
    if (_appliedInitialContext && !force) {
      return;
    }
    if (widget.initialPatient == null &&
        !_isNonEmpty(widget.initialPatientId) &&
        widget.initialAppointment == null &&
        !_isNonEmpty(widget.initialAppointmentId)) {
      _appliedInitialContext = true;
      return;
    }

    final OpdAppointment? appointment = _appointmentByApiId(_appointmentId);
    if (appointment != null) {
      setState(() {
        _appliedInitialContext = true;
        _patientMode = _WalkInPatientMode.appointment;
        _appointmentId = appointment.apiId;
        _providerId = appointment.providerUserId ?? _providerId;
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _requireConsultationPayment = true;
        _applyProviderDefaultsToState(_providerId);
      });
      return;
    }

    final Patient? patient = _patientByApiId(_patientId);
    if (patient == null && !_isNonEmpty(_patientId)) {
      _appliedInitialContext = true;
      return;
    }

    final List<OpdAppointment> patientAppointments =
        _eligibleAppointmentsForPatient(patient);
    setState(() {
      _appliedInitialContext = true;
      if (patientAppointments.isEmpty) {
        _patientMode = _WalkInPatientMode.existing;
        _patientId =
            _firstNonEmptyText(<String?>[patient?.publicId, patient?.id]) ??
            _patientId;
        return;
      }

      _patientMode = _WalkInPatientMode.appointment;
      _arrivalMode = 'ONLINE_APPOINTMENT';
      _requireConsultationPayment = true;
      if (patientAppointments.length == 1) {
        final OpdAppointment match = patientAppointments.single;
        _appointmentId = match.apiId;
        _providerId = match.providerUserId ?? _providerId;
        _applyProviderDefaultsToState(_providerId);
      } else {
        _appointmentId = null;
      }
    });
  }

  List<OpdAppointment> _eligibleAppointmentsForPatient(Patient? patient) {
    final Set<String> patientKeys =
        <String?>[
              patient?.id,
              patient?.publicId,
              patient?.effectiveIdentifier,
              widget.initialPatientId,
            ]
            .whereType<String>()
            .map((String value) => value.trim().toUpperCase())
            .where((String value) => value.isNotEmpty)
            .toSet();
    final Set<String> phoneKeys = <String?>[patient?.primaryPhone]
        .whereType<String>()
        .map((String value) => value.trim().toUpperCase())
        .where((String value) => value.isNotEmpty)
        .toSet();

    return _appointmentOptions
        .where((OpdAppointment appointment) {
          final Set<String> appointmentPatientKeys =
              <String?>[appointment.patientId, appointment.patientIdentifier]
                  .whereType<String>()
                  .map((String value) => value.trim().toUpperCase())
                  .where((String value) => value.isNotEmpty)
                  .toSet();
          final bool matchesPatient =
              patientKeys.isNotEmpty &&
              appointmentPatientKeys.any(patientKeys.contains);
          final bool matchesPhone =
              phoneKeys.isNotEmpty &&
              phoneKeys.contains(
                (appointment.patientPhone ?? '').trim().toUpperCase(),
              );
          return matchesPatient || matchesPhone;
        })
        .toList(growable: false);
  }

  List<Patient> _mergePatients(Iterable<Patient> patients) {
    final Map<String, Patient> byId = <String, Patient>{};
    for (final Patient patient in patients) {
      final String key =
          _firstNonEmptyText(<String?>[patient.publicId, patient.id]) ?? '';
      if (key.isEmpty) {
        continue;
      }
      byId[key] = patient;
    }
    return byId.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool hasActiveEncounter = _activeEncounter != null;

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(startOpdEncounterIcon),
      scrollable: true,
      maxWidth: 880,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: <Widget>[
          AppSectionPanel(
            title: l10n.opdPatientSectionTitle,
            density: AppContentPanelDensity.compact,
            children: <Widget>[
              _WalkInModeSelector(
                value: _patientMode,
                enabled: !_isSaving,
                existingLabel: l10n.opdExistingPatientModeLabel,
                appointmentLabel: l10n.opdAppointmentPatientModeLabel,
                newPatientLabel: l10n.opdNewPatientModeLabel,
                onChanged: _setPatientMode,
              ),
              _patientModeContent(l10n),
              _activeEncounterNotice(l10n),
            ],
          ),
          AppResponsiveFieldRow.two(
            left: _routingSection(l10n),
            right: _billingSection(l10n),
            breakpoint: 760,
            gap: AppResponsiveFieldRowGap.form,
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
          label: hasActiveEncounter
              ? l10n.opdOpenActiveEncounterAction
              : l10n.opdStartEncounterAction,
          leadingIcon: hasActiveEncounter
              ? Icons.open_in_new_outlined
              : Icons.play_arrow_outlined,
          enabled: !_isResolvingActiveEncounter || _activeEncounter != null,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _routingSection(AppLocalizations l10n) {
    return AppSectionPanel(
      title: l10n.opdRoutingSectionTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (_patientMode != _WalkInPatientMode.appointment)
          AppSelectField<String>.searchable(
            value: _arrivalMode,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdArrivalModeLabel),
            semanticLabel: _opdRequiredFieldLabel(
              l10n,
              l10n.opdArrivalModeLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _arrivalMode = value ?? 'WALK_IN';
                _requireConsultationPayment = _arrivalMode != 'EMERGENCY';
              });
            },
            options: _statusOptions(_arrivalModeOptions),
          ),
        if (_arrivalMode == 'EMERGENCY' &&
            _patientMode != _WalkInPatientMode.appointment)
          AppResponsiveFieldRow(
            gap: AppResponsiveFieldRowGap.form,
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _emergencySeverity,
                labelText: _opdRequiredFieldLabel(
                  l10n,
                  l10n.opdEmergencySeverityLabel,
                ),
                semanticLabel: _opdRequiredFieldLabel(
                  l10n,
                  l10n.opdEmergencySeverityLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _emergencySeverity = value ?? _emergencySeverity;
                  });
                },
                options: _statusOptions(_emergencySeverityOptions),
              ),
              AppTriageUrgencyField(
                value: _triageLevel,
                labelText: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                semanticLabel: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _triageLevel = value;
                  });
                },
                options: _triageLevelFieldOptions(),
              ),
            ],
          ),
        _ProviderSelectField(
          value: _providerId,
          providers: _providerOptionsForDialog(),
          schedules: widget.providerSchedules,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdSearchProviderLabel),
          helperText: l10n.opdSearchProviderHelper,
          emptyHelperText: l10n.opdNoProvidersHelper,
          enabled: !_isSaving,
          isLoading: _isLoadingProviders,
          onChanged: (String? value) {
            setState(() {
              _providerId = value;
              _applyProviderDefaultsToState(value);
            });
          },
        ),
      ],
    );
  }

  Widget _billingSection(AppLocalizations l10n) {
    return AppSectionPanel(
      title: l10n.opdBillingSectionTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        AppCurrencyAmountField(
          amountController: _feeController,
          currency: _currency,
          amountLabelText: _opdOptionalFieldLabel(
            l10n,
            l10n.opdConsultationFeeLabel,
          ),
          currencyLabelText: _opdRequiredFieldLabel(
            l10n,
            l10n.opdCurrencyLabel,
          ),
          enabled: !_isSaving,
          onCurrencyChanged: (String? value) {
            setState(() {
              _currency = value ?? appDefaultCurrencyCode;
            });
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
          enabled: !_isSaving,
          maxLines: 3,
        ),
        AppSwitchField(
          title: l10n.opdPaymentRequiredLabel,
          value: _requireConsultationPayment,
          enabled: !_isSaving,
          secondary: const Icon(Icons.payments_outlined),
          onChanged: (bool value) {
            setState(() {
              _requireConsultationPayment = value;
            });
          },
        ),
      ],
    );
  }

  Widget _activeEncounterNotice(AppLocalizations l10n) {
    if (_patientMode == _WalkInPatientMode.newPatient) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final OpdFlowSummary? flow = _activeEncounter;
    if (_isResolvingActiveEncounter && flow == null) {
      return Padding(
        padding: EdgeInsets.only(top: theme.spacing.md),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                l10n.opdActiveEncounterCheckingLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (flow == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.28),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  Text(
                    l10n.opdActiveEncounterFoundTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: _apiLabel(flow.stage ?? flow.status ?? ''),
                      tone: AppWorkspaceStatusTone.warning,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.opdActiveEncounterFoundBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Wrap(
                spacing: theme.spacing.lg,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  _ActiveEncounterDetail(
                    label: l10n.clinicalEncounterNumberLabel,
                    value: flow.apiId,
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdStageLabel,
                    value: _apiLabel(flow.stage ?? flow.status ?? ''),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdVisitTypeColumnLabel,
                    value: _apiLabel(
                      _firstNonEmptyText(<String?>[
                            flow.arrivalMode,
                            flow.encounterType,
                          ]) ??
                          '',
                    ),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdProviderColumnLabel,
                    value: flow.providerDisplayName ?? l10n.profileUnknownValue,
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdPayerBillingColumnLabel,
                    value: _flowBillingLabel(context, flow),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdTimeColumnLabel,
                    value: _formatDateTime(context, flow.startedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(_payload());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      final OpdFlowSummary? activeEncounter = _activeEncounter;
      if (activeEncounter != null) {
        widget.onExistingActiveEncounter?.call(activeEncounter);
      }
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  void _setPatientMode(_WalkInPatientMode mode) {
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.appointment) {
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _requireConsultationPayment = true;
      } else if (_arrivalMode == 'ONLINE_APPOINTMENT') {
        _arrivalMode = 'WALK_IN';
        _requireConsultationPayment = true;
      }
    });
    _refreshActiveEncounterForSelection();
  }

  Widget _patientModeContent(AppLocalizations l10n) {
    return switch (_patientMode) {
      _WalkInPatientMode.existing => AppSelectField<String>.searchable(
        value: _patientId,
        options: _patientOptions
            .map(_patientSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        semanticLabel: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        isLoading: _isLoadingPatients,
        enabled: !_isSaving,
        onChanged: _selectExistingPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.existing || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.appointment => AppSelectField<String>.searchable(
        value: _appointmentId,
        options: _appointmentOptions
            .map(_appointmentSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        helperText: l10n.opdAppointmentPatientHelper,
        semanticLabel: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        isLoading: _isLoadingAppointments,
        enabled: !_isSaving,
        onChanged: _selectAppointmentPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.appointment || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.newPatient => AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          AppResponsiveFieldRow.two(
            left: AppTextField(
              controller: _newPatientFirstNameController,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdFirstNameLabel),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdFirstNameLabel,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            right: AppTextField(
              controller: _newPatientLastNameController,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdLastNameLabel),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdLastNameLabel,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ),
          AppGenderField(
            value: _newPatientGender,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdGenderLabel),
            semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdGenderLabel),
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            includeUnknown: false,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _newPatientGender = value;
              });
            },
          ),
        ],
      ),
    };
  }

  void _selectExistingPatient(String? value) {
    final Patient? patient = _patientByApiId(value);
    setState(() {
      _patientId = value;
    });
    _resolveActiveEncounterForPatient(
      patientId: patient?.id,
      patientPublicId: patient?.publicId ?? value,
      patientIdentifier: patient?.effectiveIdentifier,
      patientPhone: patient?.primaryPhone,
    );
  }

  void _selectAppointmentPatient(String? value) {
    final OpdAppointment? appointment = _appointmentByApiId(value);
    final Patient? contextPatient = _patientByApiId(_patientId);
    setState(() {
      _appointmentId = value;
      _providerId = appointment?.providerUserId ?? _providerId;
      _arrivalMode = 'ONLINE_APPOINTMENT';
      _requireConsultationPayment = true;
      _applyProviderDefaultsToState(_providerId);
    });
    _resolveActiveEncounterForPatient(
      patientId: appointment?.patientId ?? contextPatient?.id,
      patientPublicId:
          appointment?.patientIdentifier ??
          contextPatient?.publicId ??
          _patientId,
      patientIdentifier:
          appointment?.patientIdentifier ?? contextPatient?.effectiveIdentifier,
      patientPhone: appointment?.patientPhone ?? contextPatient?.primaryPhone,
      appointmentId: appointment?.apiId,
    );
  }

  void _refreshActiveEncounterForSelection() {
    if (_patientMode == _WalkInPatientMode.existing) {
      _selectExistingPatient(_patientId);
      return;
    }
    if (_patientMode == _WalkInPatientMode.appointment) {
      _selectAppointmentPatient(_appointmentId);
      return;
    }

    _activeEncounterLookupToken++;
    setState(() {
      _activeEncounter = null;
      _isResolvingActiveEncounter = false;
    });
  }

  void _resolveActiveEncounterForPatient({
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) {
    final int token = ++_activeEncounterLookupToken;
    final OpdFlowSummary? localMatch = _findActiveEncounterForPatient(
      flows: widget.activeFlows,
      patientId: patientId,
      patientPublicId: patientPublicId,
      patientIdentifier: patientIdentifier,
      patientPhone: patientPhone,
      appointmentId: appointmentId,
    );
    final String? search = _firstNonEmptyText(<String?>[
      patientPublicId,
      patientIdentifier,
      patientPhone,
      patientId,
      appointmentId,
    ]);

    setState(() {
      _isResolvingActiveEncounter = _isNonEmpty(search);
      _applyActiveEncounterToState(localMatch);
    });

    if (!_isNonEmpty(search)) {
      setState(() {
        _isResolvingActiveEncounter = false;
      });
      return;
    }

    unawaited(
      _loadActiveEncounterMatch(
        token: token,
        search: search!,
        localMatch: localMatch,
        patientId: patientId,
        patientPublicId: patientPublicId,
        patientIdentifier: patientIdentifier,
        patientPhone: patientPhone,
        appointmentId: appointmentId,
      ),
    );
  }

  Future<void> _loadActiveEncounterMatch({
    required int token,
    required String search,
    required OpdFlowSummary? localMatch,
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) async {
    final Result<AppPage<OpdFlowSummary>> result = await ref
        .read(opdRepositoryProvider)
        .listOpdFlows(
          OpdFlowQuery(
            search: search,
            pageRequest: const AppPageRequest(pageSize: 25),
          ),
        );
    if (!mounted || token != _activeEncounterLookupToken) {
      return;
    }

    result.when(
      success: (AppPage<OpdFlowSummary> page) {
        final OpdFlowSummary? remoteMatch = _findActiveEncounterForPatient(
          flows: <OpdFlowSummary>[...page.items, ...widget.activeFlows],
          patientId: patientId,
          patientPublicId: patientPublicId,
          patientIdentifier: patientIdentifier,
          patientPhone: patientPhone,
          appointmentId: appointmentId,
        );
        setState(() {
          _isResolvingActiveEncounter = false;
          _applyActiveEncounterToState(remoteMatch ?? localMatch);
        });
      },
      failure: (_) {
        setState(() {
          _isResolvingActiveEncounter = false;
          _applyActiveEncounterToState(localMatch);
        });
      },
    );
  }

  void _applyActiveEncounterToState(OpdFlowSummary? flow) {
    _activeEncounter = flow;
    if (flow == null) {
      return;
    }

    final String encounterType = (flow.encounterType ?? '').toUpperCase();
    final String arrivalMode = (flow.arrivalMode ?? '').toUpperCase();
    if (_patientMode != _WalkInPatientMode.appointment) {
      if (encounterType == 'EMERGENCY' || arrivalMode == 'EMERGENCY') {
        _arrivalMode = 'EMERGENCY';
      } else if (_isNonEmpty(flow.arrivalMode) &&
          arrivalMode != 'ONLINE_APPOINTMENT') {
        _arrivalMode = flow.arrivalMode!;
      }
    }
    if (_isNonEmpty(flow.providerUserId)) {
      _providerId = flow.providerUserId;
    }
    final num? billingAmount =
        flow.consultationFee ?? flow.consultationPaidAmount;
    if (billingAmount != null) {
      _feeController.text = _currencyAmountInput(billingAmount);
    }
    if (_isNonEmpty(flow.consultationCurrency)) {
      _currency = flow.consultationCurrency!.trim().toUpperCase();
    }
    _requireConsultationPayment = flow.consultationPaymentRequired;
    if (_isNonEmpty(flow.triageLevel)) {
      _triageLevel = flow.triageLevel;
    }
  }

  OpdFlowSummary? _findActiveEncounterForPatient({
    required Iterable<OpdFlowSummary> flows,
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) {
    final Set<String> patientKeys =
        <String?>[patientId, patientPublicId, patientIdentifier]
            .whereType<String>()
            .map((String value) => value.trim().toUpperCase())
            .where((String value) => value.isNotEmpty)
            .toSet();
    final Set<String> phoneKeys = <String?>[patientPhone]
        .whereType<String>()
        .map((String value) => value.trim().toUpperCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final String normalizedAppointmentId =
        appointmentId?.trim().toUpperCase() ?? '';
    final List<OpdFlowSummary> matches = flows
        .where((OpdFlowSummary flow) {
          if (flow.isTerminal ||
              _isCompletedStatus(flow.status ?? flow.stage)) {
            return false;
          }
          if (normalizedAppointmentId.isNotEmpty &&
              (flow.appointmentId ?? '').trim().toUpperCase() ==
                  normalizedAppointmentId) {
            return true;
          }
          final bool hasPatientKeyMatch =
              patientKeys.contains(
                (flow.patientId ?? '').trim().toUpperCase(),
              ) ||
              patientKeys.contains(
                (flow.patientIdentifier ?? '').trim().toUpperCase(),
              );
          if (patientKeys.isNotEmpty) {
            return hasPatientKeyMatch;
          }
          return phoneKeys.contains(
            (flow.patientPhone ?? '').trim().toUpperCase(),
          );
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      return null;
    }
    matches.sort((OpdFlowSummary left, OpdFlowSummary right) {
      return _activeEncounterTime(right).compareTo(_activeEncounterTime(left));
    });
    return matches.first;
  }

  int _activeEncounterTime(OpdFlowSummary flow) {
    return (flow.startedAt ?? flow.queuedAt)?.millisecondsSinceEpoch ?? 0;
  }

  void _applyProviderDefaultsToState(
    String? providerId, {
    bool overwrite = false,
  }) {
    final OpdProviderOption? provider = _providerOptionById(providerId);
    if (provider == null) {
      return;
    }
    if (provider.consultationFee != null &&
        (overwrite || _feeController.text.trim().isEmpty)) {
      _feeController.text = _currencyAmountInput(provider.consultationFee);
    }
    if (_isNonEmpty(provider.consultationCurrency) &&
        (overwrite || _currency == appDefaultCurrencyCode)) {
      _currency = provider.consultationCurrency!.trim().toUpperCase();
    }
  }

  Map<String, Object?> _newPatientRegistrationPayload() {
    return <String, Object?>{
      'first_name': _newPatientFirstNameController.text.trim(),
      'last_name': _newPatientLastNameController.text.trim(),
      'gender': _newPatientGender,
    };
  }

  Future<void> _loadPatientOptions() async {
    setState(() {
      _isLoadingPatients = true;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
        .listPatients(
          const PatientListQuery(
            isActive: true,
            pageRequest: AppPageRequest(pageSize: 50),
          ),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _patientOptions = _mergePatients(<Patient>[
            ..._patientOptions,
            ...page.items,
          ]);
          _isLoadingPatients = false;
        });
        _applyInitialContext(force: true);
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingPatients = false;
        });
      },
    );
  }

  Future<void> _loadAppointmentOptions() async {
    setState(() {
      _isLoadingAppointments = true;
    });
    final Result<AppPage<OpdAppointment>> result = await ref
        .read(opdRepositoryProvider)
        .listAppointments(
          const OpdAppointmentQuery(pageRequest: AppPageRequest(pageSize: 50)),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<OpdAppointment> page) {
        setState(() {
          _appointmentOptions = _eligibleAppointmentOptions(<OpdAppointment>[
            ..._appointmentOptions,
            ...page.items,
          ]);
          _isLoadingAppointments = false;
        });
        _applyInitialContext(force: true);
        _refreshActiveEncounterForSelection();
      },
      failure: (_) {
        setState(() {
          _isLoadingAppointments = false;
        });
      },
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
          _applyProviderDefaultsToState(_providerId);
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  List<OpdProviderOption> _providerOptionsForDialog() {
    final Map<String, OpdProviderOption> options = <String, OpdProviderOption>{
      for (final OpdProviderOption provider in _providerOptions)
        provider.id: provider,
    };

    for (final OpdAppointment appointment in _appointmentOptions) {
      final String? id = appointment.providerUserId;
      if (!_isNonEmpty(id) || options.containsKey(id)) {
        continue;
      }
      options[id!] = OpdProviderOption(
        id: id,
        displayName: appointment.providerDisplayName,
        facilityId: appointment.facilityId,
      );
    }

    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final String? activeProviderId = activeEncounter?.providerUserId;
    if (_isNonEmpty(activeProviderId) &&
        !options.containsKey(activeProviderId)) {
      options[activeProviderId!] = OpdProviderOption(
        id: activeProviderId,
        displayName: activeEncounter?.providerDisplayName,
        facilityId: activeEncounter?.facilityId,
      );
    }

    return options.values.toList(growable: false);
  }

  Map<String, Object?> _payload() {
    final String notes = _notesController.text.trim();
    final String consultationFee = normalizeCurrencyAmount(_feeController.text);
    final String arrivalMode = _patientMode == _WalkInPatientMode.appointment
        ? 'ONLINE_APPOINTMENT'
        : _arrivalMode;
    final bool hasConsultationFee = consultationFee.isNotEmpty;
    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final bool canReuseOpenEncounter =
        _patientMode != _WalkInPatientMode.newPatient;

    return <String, Object?>{
      if (activeEncounter != null)
        'existing_encounter_id': activeEncounter.apiId,
      if (_patientMode == _WalkInPatientMode.appointment)
        'appointment_id': _appointmentId
      else if (_patientMode == _WalkInPatientMode.newPatient)
        'patient_registration': _newPatientRegistrationPayload()
      else
        'patient_id': _patientId,
      'provider_user_id': _providerId,
      'arrival_mode': arrivalMode,
      if (arrivalMode == 'EMERGENCY')
        'emergency': <String, Object?>{
          'severity': _emergencySeverity,
          'triage_level': _triageLevel,
          'notes': notes,
        },
      'consultation_fee': consultationFee,
      'currency': _currency,
      'require_consultation_payment': _requireConsultationPayment,
      if (canReuseOpenEncounter) 'reuse_open_encounter': true,
      'create_consultation_invoice':
          hasConsultationFee || _requireConsultationPayment,
      'notes': notes,
    };
  }

  OpdAppointment? _appointmentByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdAppointment appointment in _appointmentOptions) {
      if (appointment.publicId == value || appointment.id == value) {
        return appointment;
      }
    }
    return null;
  }

  Patient? _patientByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final Patient patient in _patientOptions) {
      if (patient.publicId == value || patient.id == value) {
        return patient;
      }
    }
    return null;
  }

  OpdProviderOption? _providerOptionById(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdProviderOption provider in _providerOptionsForDialog()) {
      if (provider.id == value) {
        return provider;
      }
    }
    return null;
  }
}

class _ActiveEncounterDetail extends StatelessWidget {
  const _ActiveEncounterDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.xs / 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

const AccessRequirement _opdReceptionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientWrite,
    AppPermissions.operationsWrite,
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdTriageRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdDoctorRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdBillingRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.billingWrite,
    AppPermissions.patientWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

class FlowActionsDialog extends ConsumerStatefulWidget {
  const FlowActionsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<FlowActionsDialog> createState() => _FlowActionsDialogState();
}

class _FlowActionsDialogState extends ConsumerState<FlowActionsDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .selectFlow(widget.flow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Result<OpdWorkspaceState>? workspaceResult = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdWorkspaceState? workspaceState = workspaceResult?.when(
      success: (OpdWorkspaceState state) => state,
      failure: (_) => null,
    );
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;

    return AppDialog(
      title: Text(flow.displayTitle),
      icon: const Icon(Icons.medical_services_outlined),
      maxWidth: 860,
      scrollable: true,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (detail == null) const LinearProgressIndicator(),
          _actionGrid(context, flow, detail),
          _OpdFlowContextPanel(flow: flow),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Widget _actionGrid(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail,
  ) {
    final l10n = context.l10n;
    final String stage = _normalizedStage(flow.stage);
    final bool terminal = flow.isTerminal;
    final bool consultationPaid = detail?.consultationPaid ?? false;
    final bool consultationPaymentRequired =
        detail?.consultationPaymentRequired ??
        stage == 'WAITING_CONSULTATION_PAYMENT';
    final bool canPay =
        !terminal &&
        !consultationPaid &&
        (stage == 'WAITING_CONSULTATION_PAYMENT' ||
            consultationPaymentRequired);

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (canPay)
        AppPermissionActionItem(
          requirement: _opdBillingRequirement,
          label: l10n.opdPayConsultationAction,
          icon: Icons.payments_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () =>
              _openNested(context, ConsultationPaymentDialog(flow: flow)),
        ),
      if (!terminal && _canRecordVitals(stage))
        AppPermissionActionItem(
          requirement: _opdTriageRequirement,
          label: l10n.opdRecordVitalsAction,
          icon: Icons.monitor_heart_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(context, RecordVitalsDialog(flow: flow)),
        ),
      if (!terminal &&
          (_canAssignDoctor(stage) || stage == 'WAITING_DOCTOR_ASSIGNMENT'))
        AppPermissionActionItem(
          requirement: _opdReceptionRequirement,
          label: l10n.opdAssignDoctorAction,
          icon: Icons.assignment_ind_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(context, AssignDoctorDialog(flow: flow)),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.opdDoctorReviewAction,
          icon: Icons.edit_note_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(context, DoctorReviewDialog(flow: flow)),
        ),
      if (!terminal && _canDispose(stage))
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.opdDispositionAction,
          icon: Icons.task_alt_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(
            context,
            OpdDispositionDialog(
              flow: flow,
              hasPharmacyOrder:
                  detail?.pharmacyOrders.isNotEmpty ??
                  stage == 'PHARMACY_REQUESTED',
            ),
          ),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_ASSIGNMENT')
        AppPermissionActionItem(
          requirement: _opdTriageRequirement,
          label: l10n.opdRouteDecisionLabel,
          icon: Icons.alt_route_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () =>
              _openNested(context, RoutingDecisionDialog(flow: flow)),
        ),
      AppPermissionActionItem(
        requirement: _opdDoctorRequirement,
        label: l10n.opdCorrectStageAction,
        icon: Icons.sync_alt_outlined,
        fullWidth: true,
        hideWhenDenied: true,
        onPressed: () => _openNested(context, CorrectStageDialog(flow: flow)),
      ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.clinicalAddDiagnosisAction,
          icon: Icons.rule_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openDiagnosisDialog(context, flow),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.clinicalRequestLabAction,
          icon: Icons.science_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openLabOrderDialog(context, flow),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.clinicalRequestRadiologyAction,
          icon: Icons.biotech_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openRadiologyOrderDialog(context, flow),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.clinicalPrescribeAction,
          icon: Icons.medication_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openPrescriptionDialog(context, flow),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.clinicalRequestProcedureAction,
          icon: Icons.healing_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openProcedureDialog(context, flow),
        ),
      if (!terminal && (stage == 'WAITING_DOCTOR_REVIEW' || _canDispose(stage)))
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.opdReferAction,
          icon: Icons.alt_route_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(context, ReferralDialog(flow: flow)),
        ),
      if (!terminal && (stage == 'WAITING_DOCTOR_REVIEW' || _canDispose(stage)))
        AppPermissionActionItem(
          requirement: _opdDoctorRequirement,
          label: l10n.opdFollowUpAction,
          icon: Icons.event_repeat_outlined,
          fullWidth: true,
          hideWhenDenied: true,
          onPressed: () => _openNested(context, FollowUpDialog(flow: flow)),
        ),
      AppPermissionActionItem(
        requirement: _opdTriageRequirement,
        label: l10n.opdPrintSummaryAction,
        icon: Icons.print_outlined,
        fullWidth: true,
        hideWhenDenied: true,
        onPressed: () => _openNested(
          context,
          PrintOpdSummaryDialog(flow: flow, detail: detail),
          closeParentOnChange: false,
        ),
      ),
    ];

    return AppActionSection(
      title: l10n.opdActionsColumnLabel,
      minItemWidth: 170,
      maxColumns: 4,
      permissionActions: actions,
    );
  }

  Future<void> _openNested(
    BuildContext context,
    Widget dialog, {
    bool closeParentOnChange = true,
  }) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (changed == true && closeParentOnChange && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<ClinicalActionReferenceData?> _loadClinicalReferenceData(
    BuildContext context,
  ) async {
    final Result<ClinicalActionReferenceData> result = await ref
        .read(clinicalRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return null;
    }
    return result.when(
      success: (ClinicalActionReferenceData value) => value,
      failure: (AppFailure failure) {
        _showFailureIfNeeded(context, failure);
        return null;
      },
    );
  }

  Future<void> _openDiagnosisDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    await _openNested(
      context,
      ClinicalDiagnosisActionDialog(
        onSearchClinicalTerms:
            ({int? limit, String? query, required String termType}) {
              return repository.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 20,
              );
            },
        onSubmit:
            ({
              required String diagnosisType,
              required String description,
              String? code,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': description,
                    'diagnoses': <Map<String, Object?>>[
                      <String, Object?>{
                        'diagnosis_type': diagnosisType,
                        'code': code,
                        'description': description,
                      },
                    ],
                  });
            },
      ),
    );
  }

  Future<void> _openProcedureDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    await _openNested(
      context,
      ClinicalProcedureActionDialog(
        onSearchClinicalTerms:
            ({int? limit, String? query, required String termType}) {
              return repository.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 20,
              );
            },
        onSubmit:
            ({
              required List<ClinicalActionCatalogOption> procedures,
              DateTime? performedAt,
            }) {
              final String performedAtIso = (performedAt ?? DateTime.now())
                  .toUtc()
                  .toIso8601String();
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': context.l10n.clinicalRequestProcedureAction,
                    'procedures': <Map<String, Object?>>[
                      for (final ClinicalActionCatalogOption procedure
                          in procedures)
                        <String, Object?>{
                          'code': procedure.code,
                          'description':
                              procedure.name ?? procedure.displayTitle,
                          'performed_at': performedAtIso,
                        },
                    ],
                  });
            },
      ),
    );
  }

  Future<void> _openLabOrderDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalRequestLabAction;
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    await _openNested(
      context,
      ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': actionLabel,
                    'lab_requests': <Map<String, Object?>>[
                      for (final String id in labTestIds)
                        <String, Object?>{
                          'lab_test_id': id,
                          'status': 'ORDERED',
                        },
                      for (final String id in labPanelIds)
                        <String, Object?>{
                          'lab_panel_id': id,
                          'status': 'ORDERED',
                        },
                    ],
                  });
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return Future<AppFailure?>.value(AppFailure.validation());
            },
      ),
    );
  }

  Future<void> _openRadiologyOrderDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalRequestRadiologyAction;
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    await _openNested(
      context,
      ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        onSubmit: ({required List<ClinicalActionRadiologyRequest> requests}) {
          return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
            flow,
            <String, Object?>{
              'note': actionLabel,
              'radiology_requests': <Map<String, Object?>>[
                for (final ClinicalActionRadiologyRequest request in requests)
                  <String, Object?>{
                    'radiology_test_id': request.radiologyTestId,
                    'clinical_note': request.clinicalNote,
                    'status': 'ORDERED',
                    'request_details': <String, Object?>{
                      'body_region': request.bodyRegion,
                      'laterality': request.laterality,
                      'priority': request.priority,
                    },
                  },
              ],
            },
          );
        },
      ),
    );
  }

  Future<void> _openPrescriptionDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalPrescribeAction;
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    await _openNested(
      context,
      ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: ({required List<Map<String, Object?>> items}) {
          return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
            flow,
            <String, Object?>{
              'note': actionLabel,
              'medications': <Map<String, Object?>>[
                for (final Map<String, Object?> item in items)
                  <String, Object?>{...item, 'status': 'ACTIVE'},
              ],
            },
          );
        },
      ),
    );
  }
}

class _OpdFlowContextPanel extends StatelessWidget {
  const _OpdFlowContextPanel({required this.flow});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String? patientId = _firstNonEmptyText(<String?>[
      flow.patientIdentifier,
      flow.patientId,
    ]);
    final String encounterId = flow.apiId;

    return AppSectionPanel(
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        Wrap(
          spacing: Theme.of(context).spacing.sm,
          runSpacing: Theme.of(context).spacing.sm,
          children: <Widget>[
            if (patientId != null)
              AppButton.secondary(
                label: 'Copy patient ID',
                leadingIcon: Icons.copy_outlined,
                onPressed: () => _copyTextToClipboard(
                  context,
                  patientId,
                  l10n.clinicalPatientIdCopiedMessage,
                ),
              ),
            AppButton.secondary(
              label: 'Copy encounter ID',
              leadingIcon: Icons.copy_outlined,
              onPressed: () => _copyTextToClipboard(
                context,
                encounterId,
                'Encounter ID copied.',
              ),
            ),
          ],
        ),
        AppInfoTileGrid(
          minItemWidth: 130,
          borderedTiles: false,
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.opdStageLabel,
              value: _apiLabel(flow.stage ?? ''),
            ),
            AppInfoTileData(
              label: l10n.opdNextStepColumnLabel,
              value: _apiLabel(flow.nextStep ?? ''),
            ),
            AppInfoTileData(
              label: l10n.opdPaymentStatusLabel,
              value: _flowBillingStatusLabel(context, flow),
            ),
            AppInfoTileData(
              label: l10n.opdProviderColumnLabel,
              value: flow.providerDisplayName,
            ),
          ],
        ),
      ],
    );
  }
}

class _OpdWorkflowStatusSummary extends StatelessWidget {
  const _OpdWorkflowStatusSummary({required this.flow, required this.detail});

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<AppInfoTileData> items = <AppInfoTileData>[
      AppInfoTileData(
        label: l10n.opdArrivalModeLabel,
        value: _flowVisitTypeLabel(context, flow),
      ),
      AppInfoTileData(
        label: l10n.opdStageLabel,
        value: _apiLabel(flow.stage ?? ''),
      ),
      AppInfoTileData(
        label: l10n.opdQueueSummaryLabel,
        value: _flowQueueLabel(context, flow),
      ),
      AppInfoTileData(
        label: l10n.opdWaitingTimeColumnLabel,
        value: _flowWaitLabel(context, flow),
      ),
      AppInfoTileData(
        label: l10n.opdNextStepColumnLabel,
        value: _apiLabel(flow.nextStep ?? ''),
      ),
      AppInfoTileData(
        label: l10n.opdPaymentStatusLabel,
        value: detail == null
            ? l10n.profileUnknownValue
            : detail!.consultationPaid
            ? l10n.opdPaymentPaidLabel
            : detail!.consultationPaymentRequired
            ? l10n.opdPaymentRequiredLabel
            : l10n.opdPaymentNotRequiredLabel,
      ),
      AppInfoTileData(
        label: l10n.opdProviderColumnLabel,
        value: flow.providerDisplayName ?? l10n.profileUnknownValue,
      ),
      AppInfoTileData(
        label: l10n.opdTriageLevelLabel,
        value: _apiLabel(flow.triageLevel ?? ''),
      ),
      AppInfoTileData(
        label: l10n.opdRouteDecisionLabel,
        value: _apiLabel(flow.lastRouteTo ?? ''),
      ),
      if (_isNonEmpty(flow.chiefComplaint))
        AppInfoTileData(
          label: l10n.opdChiefComplaintLabel,
          value: flow.chiefComplaint!,
        ),
    ];

    return AppTriageSummaryPanel(
      items: items,
      statuses: <AppWorkspaceStatus>[
        if (_isNonEmpty(flow.triageLevel))
          AppWorkspaceStatus(
            label: _apiLabel(flow.triageLevel!),
            tone: appTriageToneForValue(flow.triageLevel),
            icon: appTriageIconForValue(flow.triageLevel),
          ),
      ],
      notesLabel: l10n.opdTriageNotesLabel,
      notes: flow.triageNotes,
      emptyValue: context.l10n.profileUnknownValue,
    );
  }
}

class _OpdVitalIndicatorsPanel extends StatelessWidget {
  const _OpdVitalIndicatorsPanel({
    required this.detail,
    required this.thresholds,
  });

  final OpdFlowDetail? detail;
  final List<OpdClinicalAlertThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final OpdFlowDetail? value = detail;
    if (value == null ||
        (value.vitalMeasurements.isEmpty &&
            value.clinicalAlertDetails.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<OpdVitalSign> vitals = value.vitalMeasurements;
    final List<OpdClinicalAlert> alerts = value.clinicalAlertDetails;
    final int abnormalCount = _abnormalVitalCount(value, thresholds);

    return AppVitalsSummaryPanel(
      title: context.l10n.opdVitalsSummaryLabel,
      status: AppWorkspaceStatus(
        label: _apiLabel(abnormalCount > 0 ? 'ABNORMAL' : 'NORMAL'),
        tone: abnormalCount > 0
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      items: <AppVitalSummaryItem>[
        for (final OpdVitalSign vital in vitals)
          _opdVitalSummaryItem(
            context,
            vital,
            _vitalIndicatorState(vital, thresholds, alerts),
          ),
      ],
      alerts: <AppClinicalAlertSummary>[
        for (final OpdClinicalAlert alert in alerts)
          AppClinicalAlertSummary(
            status: AppWorkspaceStatus(
              label: _joinDisplay(<String?>[
                _apiLabel(alert.severity ?? ''),
                alert.message,
              ]),
              tone: _alertTone(alert.severity),
            ),
            description: alert.message,
          ),
      ],
    );
  }
}

AppVitalSummaryItem _opdVitalSummaryItem(
  BuildContext context,
  OpdVitalSign vital,
  _OpdVitalIndicatorState state,
) {
  return AppVitalSummaryItem(
    label: _apiLabel(vital.vitalType),
    value: vital.displayValue,
    recordedAtLabel: _formatOptionalDateTime(context, vital.recordedAt),
    status: AppWorkspaceStatus(
      label: _apiLabel(state.name.toUpperCase()),
      tone: switch (state) {
        _OpdVitalIndicatorState.critical => AppWorkspaceStatusTone.error,
        _OpdVitalIndicatorState.abnormal => AppWorkspaceStatusTone.warning,
        _OpdVitalIndicatorState.normal => AppWorkspaceStatusTone.success,
      },
    ),
  );
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

String _normalizedStage(String? stage) {
  return (stage ?? '').trim().toUpperCase();
}

bool _canRecordVitals(String stage) {
  return stage == 'WAITING_VITALS' || stage == 'WAITING_DOCTOR_ASSIGNMENT';
}

bool _canAssignDoctor(String stage) {
  return stage == 'WAITING_DOCTOR_ASSIGNMENT' ||
      stage == 'WAITING_DOCTOR_REVIEW';
}

bool _canDispose(String stage) {
  return stage == 'WAITING_DISPOSITION' ||
      stage == 'LAB_REQUESTED' ||
      stage == 'RADIOLOGY_REQUESTED' ||
      stage == 'LAB_AND_RADIOLOGY_REQUESTED' ||
      stage == 'PHARMACY_REQUESTED';
}

class RecordVitalsDialog extends ConsumerStatefulWidget {
  const RecordVitalsDialog({
    required this.flow,
    this.detail,
    this.editing = false,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;
  final bool editing;

  @override
  ConsumerState<RecordVitalsDialog> createState() => _RecordVitalsDialogState();
}

class _RecordVitalsDialogState extends ConsumerState<RecordVitalsDialog> {
  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _symptomsController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _notesController;
  String? _triageLevel;
  String? _painSeverity;
  String? _routeDecision;
  String? _providerId;
  String _bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg;
  String _selectedTemperatureUnit = AppVitalsUnits.temperatureCelsius;
  String _selectedWeightUnit = AppVitalsUnits.weightKilograms;
  String _selectedHeightUnit = AppVitalsUnits.heightCentimeters;
  final Set<String> _riskFlags = <String>{};
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  bool _emergencyIndicator = false;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _chiefComplaintController = TextEditingController(
      text: widget.flow.chiefComplaint ?? '',
    );
    _symptomsController = TextEditingController();
    _allergiesController = TextEditingController();
    _temperatureController = TextEditingController(
      text: _initialVitalValue('TEMPERATURE'),
    );
    _systolicController = TextEditingController(text: _initialSystolicValue());
    _diastolicController = TextEditingController(
      text: _initialDiastolicValue(),
    );
    _heartRateController = TextEditingController(
      text: _initialVitalValue('HEART_RATE'),
    );
    _respiratoryRateController = TextEditingController(
      text: _initialVitalValue('RESPIRATORY_RATE'),
    );
    _oxygenSaturationController = TextEditingController(
      text: _initialVitalValue('OXYGEN_SATURATION'),
    );
    _weightController = TextEditingController(
      text: _initialVitalValue('WEIGHT'),
    );
    _heightController = TextEditingController(
      text: _initialVitalValue('HEIGHT'),
    );
    _notesController = TextEditingController();
    _triageLevel = widget.flow.triageLevel;
    _providerId = widget.flow.providerUserId;
    _bloodPressureUnit = _initialVitalUnit(
      'BLOOD_PRESSURE',
      AppVitalsUnits.bloodPressureMmHg,
    );
    _selectedTemperatureUnit = _initialVitalUnit(
      'TEMPERATURE',
      AppVitalsUnits.temperatureCelsius,
    );
    _selectedWeightUnit = _initialVitalUnit(
      'WEIGHT',
      AppVitalsUnits.weightKilograms,
    );
    _selectedHeightUnit = _initialVitalUnit(
      'HEIGHT',
      AppVitalsUnits.heightCentimeters,
    );
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _allergiesController.dispose();
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool editingVitals = widget.editing && widget.detail != null;
    final String actionLabel = editingVitals
        ? l10n.opdEditVitalsAction
        : l10n.opdRecordVitalsAction;
    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          if (!editingVitals) _triagePrioritySection(context),
          _vitalsSection(context),
          _notesSection(context),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: actionLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _triagePrioritySection(BuildContext context) {
    final l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsTriagePrioritySectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _chiefComplaintController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdChiefComplaintLabel),
          enabled: !_isSaving,
          maxLines: 2,
        ),
        AppTextField(
          controller: _symptomsController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdSymptomsLabel),
          enabled: !_isSaving,
          maxLines: 2,
        ),
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppSelectField<String>.searchable(
              value: _painSeverity,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdPainSeverityLabel,
              ),
              semanticLabel: _opdOptionalFieldLabel(
                l10n,
                l10n.opdPainSeverityLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() => _painSeverity = value);
              },
              options: _painSeverityOptions,
            ),
            AppTextField(
              controller: _allergiesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdAllergiesLabel),
              enabled: !_isSaving,
            ),
          ],
        ),
        AppSwitchField(
          title: l10n.opdEmergencyIndicatorsLabel,
          value: _emergencyIndicator,
          enabled: !_isSaving,
          secondary: const Icon(Icons.emergency_outlined),
          onChanged: (bool value) {
            setState(() {
              _emergencyIndicator = value;
              if (value && _triageLevel == null) {
                _triageLevel = 'LEVEL_1';
              }
              if (value && _routeDecision == null) {
                _routeDecision = 'EMERGENCY';
              }
            });
          },
        ),
        AppTriageRiskFlagSelector(
          title: l10n.opdRiskFlagsLabel,
          options: _triageRiskFlagFieldOptions(l10n),
          selected: _riskFlags,
          enabled: !_isSaving,
          onChanged: _setRiskFlag,
        ),
        AppTriageUrgencyField(
          value: _triageLevel,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          enabled: !_isSaving,
          onChanged: (String? value) => setState(() => _triageLevel = value),
          options: _triageLevelFieldOptions(),
        ),
        AppTriageDecisionField(
          value: _routeDecision ?? _opdNoRouteDecisionValue,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdRouteDecisionLabel),
          semanticLabel: _opdOptionalFieldLabel(
            l10n,
            l10n.opdRouteDecisionLabel,
          ),
          enabled: !_isSaving,
          onChanged: (String? value) {
            setState(() {
              _routeDecision =
                  value == null || value == _opdNoRouteDecisionValue
                  ? null
                  : value;
            });
          },
          options: _routeDecisionOptions(context),
        ),
        if (_routeDecision == 'CONSULTATION')
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
              setState(() => _providerId = value);
            },
          ),
      ],
    );
  }

  Widget _vitalsSection(BuildContext context) {
    final l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsVitalsSectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        Text(
          l10n.opdVitalsAtLeastOneRequiredHelper,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppVitalsForm(
          temperatureController: _temperatureController,
          systolicController: _systolicController,
          diastolicController: _diastolicController,
          heartRateController: _heartRateController,
          respiratoryRateController: _respiratoryRateController,
          oxygenSaturationController: _oxygenSaturationController,
          weightController: _weightController,
          heightController: _heightController,
          bloodPressureLabel: l10n.patientsBloodPressureLabel,
          temperatureLabel: l10n.patientsTemperatureLabel,
          systolicLabel: l10n.patientsSystolicLabel,
          diastolicLabel: l10n.patientsDiastolicLabel,
          heartRateLabel: l10n.patientsHeartRateLabel,
          respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
          oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
          weightLabel: l10n.patientsWeightLabel,
          heightLabel: l10n.patientsHeightLabel,
          unitLabel: l10n.patientsVitalUnitLabel,
          bloodPressureUnit: _bloodPressureUnit,
          temperatureUnit: _selectedTemperatureUnit,
          weightUnit: _selectedWeightUnit,
          heightUnit: _selectedHeightUnit,
          enabled: !_isSaving,
          onBloodPressureUnitChanged: (String? value) {
            setState(() {
              _bloodPressureUnit = value ?? AppVitalsUnits.bloodPressureMmHg;
            });
          },
          onTemperatureUnitChanged: (String? value) {
            setState(() {
              _selectedTemperatureUnit =
                  value ?? AppVitalsUnits.temperatureCelsius;
            });
          },
          onWeightUnitChanged: (String? value) {
            setState(() {
              _selectedWeightUnit = value ?? AppVitalsUnits.weightKilograms;
            });
          },
          onHeightUnitChanged: (String? value) {
            setState(() {
              _selectedHeightUnit = value ?? AppVitalsUnits.heightCentimeters;
            });
          },
        ),
      ],
    );
  }

  Widget _notesSection(BuildContext context) {
    final l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsNotesSectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageNotesLabel),
          enabled: !_isSaving,
          maxLines: 3,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final List<Map<String, Object?>> vitals = _vitalsPayload();
    if (vitals.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    if (!_hasCompleteBloodPressureInput()) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    final bool editingVitals = widget.editing && widget.detail != null;
    if (!editingVitals &&
        _routeDecision == 'CONSULTATION' &&
        !_isNonEmpty(_providerId ?? widget.flow.providerUserId)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final String triageNotes = _triageNotesPayload(context.l10n);
    final AppFailure? failure = editingVitals
        ? await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .updateVitals(widget.detail!, vitals)
        : await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .recordVitals(widget.flow, <String, Object?>{
                'vitals': vitals,
                'triage_level': _triageLevel,
                'triage_priority': _triageLevel,
                'chief_complaint': _chiefComplaintController.text.trim(),
                'emergency': _emergencyIndicator,
                'triage_notes': triageNotes,
              });
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
      return;
    }

    final String? routeDecision = editingVitals ? null : _routeDecision;
    if (_isNonEmpty(routeDecision)) {
      final AppFailure? routeFailure = await ref
          .read(opdWorkspaceControllerProvider.notifier)
          .disposeFlow(
            widget.flow,
            routeDecision!.trim(),
            triageNotes,
            providerUserId: _providerId,
            triageLevel: _triageLevel,
            emergency: _emergencyIndicator,
          );
      if (!mounted) {
        return;
      }
      if (routeFailure != null) {
        setState(() {
          _failure = routeFailure;
          _isSaving = false;
        });
        return;
      }
    }

    Navigator.of(context).pop(true);
  }

  List<Map<String, Object?>> _vitalsPayload() {
    final List<Map<String, Object?>> vitals = <Map<String, Object?>>[];
    void addSimpleVital(
      TextEditingController controller,
      String type,
      String unit,
    ) {
      final String value = normalizeCurrencyAmount(controller.text);
      if (value.isEmpty) {
        return;
      }
      vitals.add(<String, Object?>{
        'vital_type': type,
        'value': value,
        'unit': unit,
      });
    }

    addSimpleVital(
      _temperatureController,
      'TEMPERATURE',
      _selectedTemperatureUnit,
    );
    final String systolic = _systolicController.text.trim();
    final String diastolic = _diastolicController.text.trim();
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      final String systolicValue = _bloodPressurePayloadValue(
        _systolicController,
      );
      final String diastolicValue = _bloodPressurePayloadValue(
        _diastolicController,
      );
      vitals.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'value': '$systolicValue/$diastolicValue',
        'unit': AppVitalsUnits.bloodPressureMmHg,
        'systolic_value': systolicValue,
        'diastolic_value': diastolicValue,
      });
    }
    addSimpleVital(
      _heartRateController,
      'HEART_RATE',
      AppVitalsUnits.heartRate,
    );
    addSimpleVital(
      _respiratoryRateController,
      'RESPIRATORY_RATE',
      AppVitalsUnits.respiratoryRate,
    );
    addSimpleVital(
      _oxygenSaturationController,
      'OXYGEN_SATURATION',
      AppVitalsUnits.oxygenSaturation,
    );
    addSimpleVital(_weightController, 'WEIGHT', _selectedWeightUnit);
    addSimpleVital(_heightController, 'HEIGHT', _selectedHeightUnit);
    return vitals;
  }

  String _initialVitalValue(String type) {
    final OpdVitalSign? vital = _initialVital(type);
    return _formatOpdVitalInput(vital?.value);
  }

  String _initialSystolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.systolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 0) : value;
  }

  String _initialDiastolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.diastolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 1) : value;
  }

  String _initialVitalUnit(String type, String fallback) {
    final String normalized = _initialVital(type)?.unit?.trim() ?? '';
    return switch (normalized) {
      AppVitalsUnits.bloodPressureKpa => AppVitalsUnits.bloodPressureKpa,
      AppVitalsUnits.bloodPressureMmHg => AppVitalsUnits.bloodPressureMmHg,
      AppVitalsUnits.temperatureFahrenheit ||
      'F' => AppVitalsUnits.temperatureFahrenheit,
      AppVitalsUnits.temperatureCelsius ||
      'C' => AppVitalsUnits.temperatureCelsius,
      AppVitalsUnits.weightPounds => AppVitalsUnits.weightPounds,
      AppVitalsUnits.weightKilograms => AppVitalsUnits.weightKilograms,
      AppVitalsUnits.heightMeters => AppVitalsUnits.heightMeters,
      AppVitalsUnits.heightCentimeters => AppVitalsUnits.heightCentimeters,
      _ => fallback,
    };
  }

  String _bloodPressurePayloadValue(TextEditingController controller) {
    final double? value = parseAppVitalInput(controller.text);
    if (value == null) {
      return '';
    }
    final double mmHg = _bloodPressureUnit == AppVitalsUnits.bloodPressureKpa
        ? value / AppVitalsUnits.bloodPressureKpaFactor
        : value;
    return formatAppVitalNumber(mmHg, decimals: 2);
  }

  OpdVitalSign? _initialVital(String type) {
    OpdVitalSign? latest;
    for (final OpdVitalSign vital
        in widget.detail?.vitalMeasurements ?? const <OpdVitalSign>[]) {
      if (vital.vitalType != type) {
        continue;
      }
      if (latest == null) {
        latest = vital;
        continue;
      }
      final DateTime? recordedAt = vital.recordedAt;
      final DateTime? latestRecordedAt = latest.recordedAt;
      if (recordedAt != null &&
          (latestRecordedAt == null || recordedAt.isAfter(latestRecordedAt))) {
        latest = vital;
      }
    }
    return latest;
  }

  String _formatOpdVitalInput(String? value) {
    final num? parsed = value == null ? null : num.tryParse(value.trim());
    if (parsed == null) {
      return value?.trim() ?? '';
    }
    return formatAppVitalNumber(parsed);
  }

  String _formatOpdVitalNumber(num? value) {
    return value == null ? '' : formatAppVitalNumber(value);
  }

  String _legacyBloodPressurePart(String? value, int index) {
    final List<String> parts = (value ?? '').split('/');
    if (parts.length <= index) {
      return '';
    }
    return _formatOpdVitalInput(parts[index]);
  }

  bool _hasCompleteBloodPressureInput() {
    final bool hasSystolic = _systolicController.text.trim().isNotEmpty;
    final bool hasDiastolic = _diastolicController.text.trim().isNotEmpty;
    return hasSystolic == hasDiastolic;
  }

  void _setRiskFlag(String flag, bool selected) {
    setState(() {
      if (selected) {
        _riskFlags.add(flag);
      } else {
        _riskFlags.remove(flag);
      }
    });
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
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  String _triageNotesPayload(AppLocalizations l10n) {
    final List<String> lines = <String>[];
    void add(String label, String value) {
      final String normalized = value.trim();
      if (normalized.isNotEmpty) {
        lines.add('$label: $normalized');
      }
    }

    add(l10n.opdSymptomsLabel, _symptomsController.text);
    add(l10n.opdPainSeverityLabel, _painSeverity ?? '');
    add(l10n.opdAllergiesLabel, _allergiesController.text);
    if (_riskFlags.isNotEmpty) {
      lines.add(
        '${l10n.opdRiskFlagsLabel}: ${_riskFlags.map((String flag) => _riskFlagLabel(l10n, flag)).join(', ')}',
      );
    }
    add(l10n.opdTriageNotesLabel, _notesController.text);
    return lines.join('\n');
  }
}

String _riskFlagLabel(AppLocalizations l10n, String flag) {
  return switch (flag) {
    _riskFlagFall => l10n.opdRiskFlagFall,
    _riskFlagPregnancy => l10n.opdRiskFlagPregnancy,
    _riskFlagInfection => l10n.opdRiskFlagInfection,
    _riskFlagAlteredMentalState => l10n.opdRiskFlagAlteredMentalState,
    _riskFlagBleeding => l10n.opdRiskFlagBleeding,
    _ => _apiLabel(flag),
  };
}

IconData _riskFlagIcon(String flag) {
  return switch (flag) {
    _riskFlagFall => Icons.personal_injury_outlined,
    _riskFlagPregnancy => Icons.pregnant_woman_outlined,
    _riskFlagInfection => Icons.coronavirus_outlined,
    _riskFlagAlteredMentalState => Icons.psychology_alt_outlined,
    _riskFlagBleeding => Icons.bloodtype_outlined,
    _ => Icons.warning_amber_outlined,
  };
}

List<AppTriageOption> _routeDecisionOptions(BuildContext context) {
  return <AppTriageOption>[
    AppTriageOption(
      value: _opdNoRouteDecisionValue,
      label: context.l10n.opdNoRouteDecisionLabel,
      tone: AppWorkspaceStatusTone.neutral,
      icon: Icons.remove_circle_outline,
    ),
    ..._triageRouteFieldOptions(),
  ];
}

final List<AppSelectOption<String>> _painSeverityOptions =
    List<AppSelectOption<String>>.unmodifiable(<AppSelectOption<String>>[
      for (int value = 0; value <= 10; value += 1)
        AppSelectOption<String>(value: '$value', label: value.toString()),
    ]);

class DoctorReviewDialog extends ConsumerStatefulWidget {
  const DoctorReviewDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<DoctorReviewDialog> createState() => _DoctorReviewDialogState();
}

class _DoctorReviewDialogState extends ConsumerState<DoctorReviewDialog> {
  late final TextEditingController _noteController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Result<OpdWorkspaceState>? workspaceResult = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdWorkspaceState? workspaceState = workspaceResult?.when(
      success: (OpdWorkspaceState state) => state,
      failure: (_) => null,
    );
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;

    return AppDialog(
      title: Text(l10n.opdDoctorReviewAction),
      icon: const Icon(Icons.edit_note_outlined),
      maxWidth: 760,
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          _OpdWorkflowStatusSummary(flow: flow, detail: detail),
          _OpdVitalIndicatorsPanel(
            detail: detail,
            thresholds:
                workspaceState?.clinicalAlertThresholds ??
                const <OpdClinicalAlertThreshold>[],
          ),
          AppTextField(
            controller: _noteController,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdClinicalNoteLabel),
            enabled: !_isSaving,
            maxLines: 4,
            validator: AppValidators.requiredText(l10n.validationRequired),
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
          label: l10n.opdDoctorReviewAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_isNonEmpty(_noteController.text)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .doctorReview(widget.flow, <String, Object?>{
          'note': _noteController.text.trim(),
        });
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

class PrintOpdSummaryDialog extends ConsumerWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    required this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String summary = _printSummary(context);
    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppReportPreviewPanel(
        selectable: true,
        child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary));
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
        ),
        AppReportActionButton.print(
          label: l10n.opdPrintAction,
          onPressed: () async {
            await printFormTemplateDocument(
              ref: ref,
              context: context,
              title: l10n.opdPrintSummaryAction,
              subtitle: flow.displayTitle,
              metadata: <PrintFormMetadataItem>[
                PrintFormMetadataItem(
                  label: l10n.patientsIdentifierLabel,
                  value: flow.patientIdentifier ?? '',
                ),
                PrintFormMetadataItem(
                  label: l10n.opdStageLabel,
                  value: _apiLabel(flow.stage ?? ''),
                ),
                PrintFormMetadataItem(
                  label: l10n.opdNextStepColumnLabel,
                  value: _apiLabel(flow.nextStep ?? ''),
                ),
                PrintFormMetadataItem(
                  label: l10n.opdPaymentStatusLabel,
                  value: detail == null
                      ? l10n.profileUnknownValue
                      : detail!.consultationPaid
                      ? l10n.opdPaymentPaidLabel
                      : detail!.consultationPaymentRequired
                      ? l10n.opdPaymentRequiredLabel
                      : l10n.opdPaymentNotRequiredLabel,
                ),
              ],
              bodyHtml:
                  '<div class="print-template-note">${printHtmlEscape(summary)}</div>',
            );
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  String _printSummary(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<String> lines = <String>[
      flow.displayTitle,
      _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        flow.providerDisplayName,
      ]),
      '${l10n.opdStageLabel}: ${_apiLabel(flow.stage ?? '')}',
      '${l10n.opdNextStepColumnLabel}: ${_apiLabel(flow.nextStep ?? '')}',
      '${l10n.opdTriageLevelLabel}: ${_apiLabel(flow.triageLevel ?? '')}',
      '${l10n.opdRouteDecisionLabel}: ${_apiLabel(flow.lastRouteTo ?? '')}',
      if (_isNonEmpty(flow.chiefComplaint))
        '${l10n.opdChiefComplaintLabel}: ${flow.chiefComplaint}',
      if (_isNonEmpty(flow.triageNotes))
        '${l10n.opdTriageNotesLabel}: ${flow.triageNotes}',
      '${l10n.opdPaymentStatusLabel}: ${value == null
          ? l10n.profileUnknownValue
          : value.consultationPaid
          ? l10n.opdPaymentPaidLabel
          : value.consultationPaymentRequired
          ? l10n.opdPaymentRequiredLabel
          : l10n.opdPaymentNotRequiredLabel}',
      '${l10n.opdVitalsSummaryLabel}: ${value?.vitalSigns.length ?? 0}',
      '${l10n.opdClinicalNotesSummaryLabel}: ${value?.clinicalNotes.length ?? 0}',
      '${l10n.opdServicesSummaryLabel}: ${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      if (value != null && value.vitalSigns.isNotEmpty) '',
      if (value != null && value.vitalSigns.isNotEmpty)
        l10n.opdVitalsSummaryLabel,
      if (value != null)
        for (final OpdRelatedRecord vital in value.vitalSigns)
          _joinDisplay(<String?>[vital.title, vital.subtitle]),
      if (value != null && value.timeline.isNotEmpty) '',
      if (value != null && value.timeline.isNotEmpty) l10n.opdTimelineTitle,
      if (value != null)
        for (final OpdTimelineItem item in value.timeline)
          _joinDisplay(<String?>[
            _apiLabel(item.action),
            _apiLabel(item.stage ?? ''),
            item.notes,
          ]),
    ];
    return lines.where((String line) => line.trim().isNotEmpty).join('\n');
  }
}

class AssignDoctorDialog extends ConsumerStatefulWidget {
  const AssignDoctorDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends ConsumerState<AssignDoctorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdAssignDoctorAction),
      icon: const Icon(Icons.assignment_ind_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdRequiredFieldLabel(
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
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdAssignDoctorAction,
          leadingIcon: Icons.assignment_ind_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? providerId = _providerId;
    if (!_isNonEmpty(providerId)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .assignDoctor(widget.flow, providerId!.trim());
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

class ConsultationPaymentDialog extends ConsumerStatefulWidget {
  const ConsultationPaymentDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ConsultationPaymentDialog> createState() =>
      _ConsultationPaymentDialogState();
}

class _ConsultationPaymentDialogState
    extends ConsumerState<ConsultationPaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String _currency = appDefaultCurrencyCode;
  String _method = 'CASH';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _currencyAmountInput(widget.flow.consultationFee),
    );
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
    _currency =
        widget.flow.consultationCurrency?.trim().toUpperCase() ??
        appDefaultCurrencyCode;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdPayConsultationAction),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppCurrencyAmountField(
              amountController: _amountController,
              currency: _currency,
              amountLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdAmountLabel,
              ),
              currencyLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdCurrencyLabel,
              ),
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
            ),
            AppSelectField<String>(
              value: _method,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdPaymentMethodLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() => _method = value ?? _method);
              },
              options: _statusOptions(_paymentMethods),
            ),
            AppTextField(
              controller: _referenceController,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdTransactionReferenceLabel,
              ),
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _notesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdPayConsultationAction,
          leadingIcon: Icons.payments_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .payConsultation(widget.flow, <String, Object?>{
          'amount': normalizeCurrencyAmount(_amountController.text),
          'currency': _currency,
          'method': _method,
          'status': 'COMPLETED',
          'transaction_ref': _referenceController.text.trim(),
          'notes': _notesController.text.trim(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
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

class CorrectStageDialog extends ConsumerStatefulWidget {
  const CorrectStageDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<CorrectStageDialog> createState() => _CorrectStageDialogState();
}

class _CorrectStageDialogState extends ConsumerState<CorrectStageDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  String _stage = _flowStages.first;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _stage = widget.flow.stage ?? _flowStages.first;
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
      title: Text(l10n.opdCorrectStageAction),
      icon: const Icon(Icons.edit_note_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _stage,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdStageLabel),
              enabled: !_isSaving,
              onChanged: (String? value) =>
                  setState(() => _stage = value ?? _stage),
              options: _flowStageOptions(),
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
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdSaveAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(widget.flow, _stage, _reasonController.text.trim());
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

class ReferralDialog extends ConsumerWidget {
  const ReferralDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClinicalReferralActionDialog(
      onSubmit:
          ({
            required String externalFacilityName,
            required String reason,
            required String notes,
          }) {
            return ref
                .read(opdWorkspaceControllerProvider.notifier)
                .createReferral(
                  flow: flow,
                  externalFacilityName: externalFacilityName,
                  reason: reason,
                  notes: notes,
                );
          },
    );
  }
}

class FollowUpDialog extends ConsumerWidget {
  const FollowUpDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClinicalFollowUpActionDialog(
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .createFollowUp(flow: flow, scheduledAt: scheduledAt, notes: notes);
      },
    );
  }
}

class RoutingDecisionDialog extends ConsumerStatefulWidget {
  const RoutingDecisionDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<RoutingDecisionDialog> createState() =>
      _RoutingDecisionDialogState();
}

class _RoutingDecisionDialogState extends ConsumerState<RoutingDecisionDialog> {
  late final TextEditingController _notesController;
  String _decision = 'CONSULTATION';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
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
      title: Text(l10n.opdRouteDecisionLabel),
      icon: const Icon(Icons.alt_route_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTriageDecisionField(
            value: _decision,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdRouteDecisionLabel),
            enabled: !_isSaving,
            searchable: false,
            isRequired: true,
            onChanged: (String? value) =>
                setState(() => _decision = value ?? _decision),
            options: _triageRouteFieldOptions(),
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
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
          label: l10n.opdRouteDecisionLabel,
          leadingIcon: Icons.alt_route_outlined,
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
        .disposeFlow(widget.flow, _decision, _notesController.text.trim());
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

class OpdDispositionDialog extends ConsumerWidget {
  const OpdDispositionDialog({
    required this.flow,
    required this.hasPharmacyOrder,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool hasPharmacyOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return ClinicalDispositionActionDialog(
      title: l10n.opdDispositionAction,
      reasonLabel: _opdRequiredFieldLabel(l10n, l10n.opdDecisionLabel),
      notesLabel: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
      submitLabel: l10n.opdDispositionAction,
      initialReason: hasPharmacyOrder ? 'SEND_TO_PHARMACY' : 'DISCHARGE',
      reasons: _opdDispositionOptions(hasPharmacyOrder: hasPharmacyOrder),
      onSubmit: ({required String reason, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .completeDisposition(flow, <String, Object?>{
              'decision': reason,
              'notes': notes,
            });
      },
    );
  }
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppTriageOption> _triageLevelFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageLevelOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageOption> _triageRouteFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageRouteOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageRiskFlagOption> _triageRiskFlagFieldOptions(
  AppLocalizations l10n,
) {
  return <AppTriageRiskFlagOption>[
    for (final String value in _triageRiskFlagOptions)
      AppTriageRiskFlagOption(
        value: value,
        label: _riskFlagLabel(l10n, value),
        icon: _riskFlagIcon(value),
      ),
  ];
}

List<AppSelectOption<String>> _flowStageOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _flowStages)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_flowStageIcon(value)),
      ),
  ];
}

AppSelectOption<String>? _patientSelectOption(Patient patient) {
  final String? value = _firstNonEmptyText(<String?>[
    patient.publicId,
    patient.id,
  ]);
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value!,
    label: _joinDisplay(<String?>[
      patient.effectiveDisplayName,
      patient.effectiveIdentifier,
      patient.primaryPhone,
    ]),
  );
}

AppSelectOption<String>? _appointmentSelectOption(OpdAppointment appointment) {
  final String value = appointment.publicId ?? appointment.id;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value,
    label: _joinDisplay(<String?>[
      appointment.displayTitle,
      appointment.patientIdentifier,
      appointment.patientPhone,
      appointment.providerDisplayName,
      appointment.status,
    ]),
  );
}

List<OpdAppointment> _eligibleAppointmentOptions(
  Iterable<OpdAppointment> appointments,
) {
  final Map<String, OpdAppointment> options = <String, OpdAppointment>{};

  for (final OpdAppointment appointment in appointments) {
    final String value = appointment.publicId ?? appointment.id;
    if (!_isNonEmpty(value) ||
        _isTerminalAppointmentStatus(appointment.status)) {
      continue;
    }

    options[value] = appointment;
  }

  return options.values.toList(growable: false);
}

bool _isTerminalAppointmentStatus(String? status) {
  return switch (status?.toUpperCase()) {
    'CANCELLED' || 'NO_SHOW' || 'COMPLETED' => true,
    _ => false,
  };
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

String? _firstNonEmptyText(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

Future<void> _copyTextToClipboard(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _apiLabel(String value) {
  return AppDisplay.apiLabel(value);
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _formatOptionalDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? null
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

IconData _flowStageIcon(String value) {
  return switch (value.toUpperCase()) {
    'WAITING_CONSULTATION_PAYMENT' => Icons.payments_outlined,
    'WAITING_VITALS' => Icons.monitor_heart_outlined,
    'WAITING_DOCTOR_ASSIGNMENT' => Icons.assignment_ind_outlined,
    'WAITING_DOCTOR_REVIEW' => Icons.medical_services_outlined,
    'LAB_REQUESTED' => Icons.science_outlined,
    'RADIOLOGY_REQUESTED' => Icons.biotech_outlined,
    'LAB_AND_RADIOLOGY_REQUESTED' => Icons.hub_outlined,
    'PHARMACY_REQUESTED' => Icons.local_pharmacy_outlined,
    'WAITING_DISPOSITION' => Icons.task_alt_outlined,
    'ADMITTED' => Icons.bed_outlined,
    'DISCHARGED' => Icons.logout_outlined,
    _ => Icons.sync_alt_outlined,
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
const String _opdNoRouteDecisionValue = 'NO_ROUTE_DECISION';
const String _riskFlagFall = 'FALL_RISK';
const String _riskFlagPregnancy = 'PREGNANCY';
const String _riskFlagInfection = 'INFECTION_RISK';
const String _riskFlagAlteredMentalState = 'ALTERED_MENTAL_STATE';
const String _riskFlagBleeding = 'BLEEDING';

const List<String> _triageRiskFlagOptions = <String>[
  _riskFlagFall,
  _riskFlagPregnancy,
  _riskFlagInfection,
  _riskFlagAlteredMentalState,
  _riskFlagBleeding,
];

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

const List<String> _arrivalModeOptions = <String>['WALK_IN', 'EMERGENCY'];

const List<String> _emergencySeverityOptions = <String>[
  'LOW',
  'MEDIUM',
  'HIGH',
  'CRITICAL',
];

const List<String> _triageLevelOptions = <String>[
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];

const List<String> _flowStages = <String>[
  'WAITING_CONSULTATION_PAYMENT',
  'WAITING_VITALS',
  'WAITING_DOCTOR_ASSIGNMENT',
  'WAITING_DOCTOR_REVIEW',
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
  'WAITING_DISPOSITION',
  'ADMITTED',
  'DISCHARGED',
];

const List<String> _paymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

const List<String> _triageRouteOptions = <String>[
  'CONSULTATION',
  'EMERGENCY',
  'ADMIT',
  'THEATRE',
  'MINOR_PROCEDURE',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'DISCHARGE',
];

List<String> _opdDispositionOptions({required bool hasPharmacyOrder}) {
  return <String>[
    'DISCHARGE',
    if (hasPharmacyOrder) 'SEND_TO_PHARMACY',
    'ADMIT',
  ];
}
