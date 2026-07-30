import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_desk_preferences.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_desk_settings_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabWorkspacePage extends ConsumerWidget {
  const LabWorkspacePage({this.initialQuery, super.key});

  final LabWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<LabWorkspaceState>> state = ref.watch(
      labWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<LabWorkspaceState>(
      value: state,
      loadingTitle: l10n.labLoadingTitle,
      loadingBody: l10n.labLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(labWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, LabWorkspaceState data) {
        return _LabWorkspaceContent(state: data, initialQuery: initialQuery);
      },
    );
  }
}

class _LabWorkspaceContent extends ConsumerStatefulWidget {
  const _LabWorkspaceContent({required this.state, this.initialQuery});

  final LabWorkspaceState state;
  final LabWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_LabWorkspaceContent> createState() =>
      _LabWorkspaceContentState();
}

class _LabWorkspaceContentState extends ConsumerState<_LabWorkspaceContent> {
  static const String _paymentFilterKey = 'payment';
  static const String _statusFilterKey = 'status';
  static const String _queueFilterKey = 'queue';
  static const String _resultFlagFilterKey = 'result_flag';
  static const String _textPatientKey = 'patient';
  static const String _textPatientIdKey = 'patient_id';
  static const String _textTestKey = 'test';
  static const String _textOrderIdKey = 'order_id';

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<LabOrderSummary>
  _tableColumnController;
  late LabDeskSection _section;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  Timer? _searchDebounce;
  String? _appliedRouteSignature;
  bool _syncingFiltersFromTab = false;

  @override
  void initState() {
    super.initState();
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    final LabDeskSection preferred =
        LabDeskPreferences.readDefaultTab(prefs) ?? LabDeskSection.collection;
    _section = preferred;
    _filterValue = _filterValueForSection(preferred);
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<LabOrderSummary>();
    _scheduleRouteQuery(widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final int pageSize = LabDeskPreferences.readPageSize(prefs);
      if (widget.state.query.pageRequest.pageSize != pageSize) {
        unawaited(
          ref
              .read(labWorkspaceControllerProvider.notifier)
              .applyPageSize(pageSize),
        );
      }
      if (widget.initialQuery == null ||
          !widget.initialQuery!.hasRouteTargeting) {
        unawaited(
          ref
              .read(labWorkspaceControllerProvider.notifier)
              .applyScope(_scopeForSection(_section)),
        );
        if (_section != LabDeskSection.collection) {
          _updateUrlForSection(_section);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LabWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final LabWorkspaceState state = widget.state;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canMutate = canWriteLab(policy);
    final List<LabDeskSection> allowedSections = labAllowedSections(policy);
    final LabDeskSection effectiveSection =
        allowedSections.contains(_section)
        ? _section
        : (labFallbackSection(policy) ?? _section);

    if (effectiveSection != _section && allowedSections.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _section == effectiveSection) {
          return;
        }
        _selectSection(effectiveSection, updateUrl: true, applyScope: true);
      });
    }

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (allowedSections.isNotEmpty)
              AppTabStrip(
                tabs: <AppTabItem>[
                  for (final LabDeskSection section in allowedSections)
                    AppTabItem(
                      id: section.name,
                      icon: _sectionIcon(section),
                      label: _sectionLabel(l10n, section),
                      count: section.isFollowUps
                          ? ref.watch(
                              followUpTabCountProvider(
                                const FollowUpWorklistScope(),
                              ),
                            )
                          : _sectionCount(state, section),
                      countTone: _sectionCountTone(section),
                    ),
                ],
                selectedId: effectiveSection.name,
                onTabTapped: (String tabId) {
                  for (final LabDeskSection section in allowedSections) {
                    if (section.name == tabId) {
                      _selectSection(
                        section,
                        updateUrl: true,
                        applyScope: true,
                      );
                      break;
                    }
                  }
                },
              ),
            SizedBox(height: theme.spacing.sm),
            if (allowedSections.isEmpty)
              Expanded(
                child: AppWorkspaceStatePanel.empty(
                  title: l10n.labNoOrdersTitle,
                  body: l10n.labNoOrdersBody,
                  icon: Icons.science_outlined,
                ),
              )
            else if (effectiveSection.isFollowUps)
              Expanded(
                child: FollowUpWorklistPanel(
                  scope: const FollowUpWorklistScope(),
                  storageKeyPrefix: 'lab_follow_ups',
                  readRequirement: LabFollowUpsAtomPermissions.tab,
                  writeRequirement: LabFollowUpsAtomPermissions.write,
                  createAction: _buildCreateSearchAction(
                    l10n,
                    state,
                    section: effectiveSection,
                  ),
                  showAdvancedFilterButton: true,
                  advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                  advancedFilterResetLabel: l10n.opdClearFiltersAction,
                  enableDateFilter: true,
                  dateFilterLabel: l10n.labFollowUpDateFilterLabel,
                  dateFromLabel: l10n.opdDateFromLabel,
                  dateToLabel: l10n.opdDateToLabel,
                  textFilters: _labFollowUpTextFilters(l10n),
                  filterGroups: _labFollowUpFilterGroups(l10n),
                  onSettingsPressed: () => _openLabDeskSettings(
                    context,
                    sectionName: effectiveSection.name,
                  ),
                ),
              )
            else
              Expanded(
                child: _LabWorklistPanel(
                  state: state,
                  canMutate: canMutate,
                  searchController: _searchController,
                  columnVisibilityController: _tableColumnController,
                  filterValue: _filterValue,
                  onFilterChanged: _onFilterChanged,
                  onSearchChanged: _scheduleWorklistSearch,
                  onSearchSubmitted: _submitWorklistSearch,
                  onSearchCleared: _clearWorklistSearch,
                  sectionName: effectiveSection.name,
                  createAction: _buildCreateSearchAction(
                    l10n,
                    state,
                    section: effectiveSection,
                  ),
                  onSettingsPressed: () => _openLabDeskSettings(
                    context,
                    sectionName: effectiveSection.name,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AppSearchBarAction? _buildCreateSearchAction(
    AppLocalizations l10n,
    LabWorkspaceState state, {
    required LabDeskSection section,
  }) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final AccessRequirement requirement = labStripCreateRequirement(section);
    if (!requirement.isAllowed(policy)) {
      return null;
    }
    return AppSearchBarAction(
      icon: Icons.add_circle_outline,
      label: l10n.labCreateAction,
      tooltip: l10n.labCreateAction,
      enabled: !state.isSaving,
      onPressed: state.isSaving
          ? null
          : () => _openCreateLabOrderDialog(context, state),
    );
  }

  Future<void> _openLabDeskSettings(
    BuildContext context, {
    required String sectionName,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final List<AppListTableColumn<LabOrderSummary>> columns =
        <AppListTableColumn<LabOrderSummary>>[
          ..._patientViewWorklistColumns(
            context,
            onNextAction: (_) {},
          ),
          ..._optionalWorklistColumns(context),
        ];
    _tableColumnController.syncColumns(
      columns: _patientViewWorklistColumns(context, onNextAction: (_) {}),
      columnChoices: _optionalWorklistColumns(context),
      storageKey: 'lab_$sectionName',
    );
    final LabDeskSettingsResult? result = await showLabDeskSettingsDialog(
      context: context,
      columns: columns,
      visibleColumnKeys: _tableColumnController.visibleColumnKeys,
      defaultColumnKeys: _tableColumnController.defaultColumnKeys.isEmpty
          ? columns
                .map((AppListTableColumn<LabOrderSummary> column) => column.key)
                .toSet()
          : _tableColumnController.defaultColumnKeys,
      preferences: prefs,
      sectionLabel: (LabDeskSection section) => _sectionLabel(l10n, section),
      allowedDefaultTabs: labAllowedSections(policy),
    );
    if (result == null || !mounted) {
      return;
    }
    _tableColumnController.applyVisibleColumnKeys(
      result.visibleColumnKeys,
      storageKey: 'lab_$sectionName',
    );
    await LabDeskPreferences.writeDefaultTab(prefs, result.defaultTab);
    await LabDeskPreferences.writePageSize(prefs, result.pageSize);
    unawaited(
      ref
          .read(labWorkspaceControllerProvider.notifier)
          .applyPageSize(result.pageSize),
    );
  }

  void _selectSection(
    LabDeskSection section, {
    required bool updateUrl,
    required bool applyScope,
  }) {
    setState(() {
      _section = section;
      _syncingFiltersFromTab = true;
      _filterValue = _filterValueForSection(section);
      _syncingFiltersFromTab = false;
    });
    if (updateUrl) {
      _updateUrlForSection(section);
    }
    if (applyScope && !section.isFollowUps) {
      unawaited(
        ref
            .read(labWorkspaceControllerProvider.notifier)
            .applyScope(_scopeForSection(section)),
      );
    }
  }

  void _onFilterChanged(AppSearchBarFilterValue value) {
    if (_syncingFiltersFromTab) {
      setState(() => _filterValue = value);
      return;
    }
    // Clearing advanced filters resets the desk to All patients.
    final LabDeskSection matched = value.isActive
        ? (_sectionFromFilterValue(value) ?? _section)
        : LabDeskSection.worklist;
    setState(() {
      _filterValue = value.isActive
          ? value
          : _filterValueForSection(LabDeskSection.worklist);
      _section = matched;
    });
    _updateUrlForSection(matched);
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    if (!matched.isFollowUps) {
      unawaited(controller.applyScope(_scopeForSection(matched)));
    }
    unawaited(
      controller.applyDateRange(
        orderedFrom: value.dateFrom,
        orderedTo: value.dateTo,
      ),
    );
  }

  AppSearchBarFilterValue _filterValueForSection(LabDeskSection section) {
    final String queue = switch (section) {
      LabDeskSection.worklist => 'all',
      LabDeskSection.collection => 'pending',
      LabDeskSection.critical => 'critical',
      LabDeskSection.completed => 'completed_today',
      LabDeskSection.followUps => 'follow_ups',
    };
    return AppSearchBarFilterValue(
      options: <String, String>{_queueFilterKey: queue},
    );
  }

  LabDeskSection? _sectionFromFilterValue(AppSearchBarFilterValue value) {
    final String? queue = value.option(_queueFilterKey)?.trim().toLowerCase();
    return switch (queue) {
      'all' => LabDeskSection.worklist,
      'pending' || 'collection' || 'awaiting-results' =>
        LabDeskSection.collection,
      'critical' => LabDeskSection.critical,
      'completed_today' || 'completed' => LabDeskSection.completed,
      'follow_ups' || 'follow-ups' => LabDeskSection.followUps,
      _ => null,
    };
  }

  void _scheduleWorklistSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final LabWorkspaceState current = widget.state;
      if (current.query.search == value.trim()) {
        return;
      }
      unawaited(
        ref.read(labWorkspaceControllerProvider.notifier).applySearch(value),
      );
    });
  }

  void _submitWorklistSearch(String value) {
    _searchDebounce?.cancel();
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applySearch(value),
    );
  }

  void _clearWorklistSearch() {
    _searchDebounce?.cancel();
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applySearch(''),
    );
  }

  LabQueueScope _scopeForSection(LabDeskSection section) {
    return switch (section) {
      LabDeskSection.worklist => LabQueueScope.all,
      LabDeskSection.collection => LabQueueScope.collection,
      LabDeskSection.critical => LabQueueScope.critical,
      LabDeskSection.completed => LabQueueScope.completed,
      LabDeskSection.followUps => LabQueueScope.all,
    };
  }

  LabDeskSection? _sectionFromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'worklist':
      case 'all':
        return LabDeskSection.worklist;
      case 'collection':
      case 'sample':
      case 'awaiting-results':
      case 'awaiting_results':
      case 'awaitingresults':
      case 'pending':
      case 'pending-verification':
      case 'pending_verification':
      case 'pendingverification':
      case 'processing':
      case 'in-process':
      case 'verification':
      case 'results':
        // Pending is default; legacy processing / awaiting-results → Pending.
        return LabDeskSection.collection;
      case 'critical':
        return LabDeskSection.critical;
      case 'verified':
      case 'completed':
      case 'completed-today':
      case 'completed_today':
      case 'done':
        return LabDeskSection.completed;
      case 'follow-ups':
      case 'follow_ups':
      case 'followups':
        return LabDeskSection.followUps;
      default:
        return null;
    }
  }

  static String _sectionToQueryValue(LabDeskSection section) {
    return switch (section) {
      LabDeskSection.worklist => 'worklist',
      LabDeskSection.collection => 'pending',
      LabDeskSection.critical => 'critical',
      LabDeskSection.completed => 'completed-today',
      LabDeskSection.followUps => 'follow-ups',
    };
  }

  void _updateUrlForSection(LabDeskSection section) {
    if (!mounted) return;
    final String tab = _sectionToQueryValue(section);
    final String location = AppRoutes.lab.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  String _sectionLabel(AppLocalizations l10n, LabDeskSection section) {
    return switch (section) {
      LabDeskSection.worklist => l10n.labScopeAll,
      LabDeskSection.collection => l10n.labScopeCollection,
      LabDeskSection.critical => l10n.labScopeCritical,
      LabDeskSection.completed => l10n.labScopeCompleted,
      LabDeskSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  static IconData _sectionIcon(LabDeskSection section) {
    return switch (section) {
      LabDeskSection.worklist => Icons.assignment_outlined,
      LabDeskSection.collection => Icons.biotech_outlined,
      LabDeskSection.critical => Icons.priority_high_outlined,
      LabDeskSection.completed => Icons.task_alt_outlined,
      LabDeskSection.followUps => Icons.phone_callback_outlined,
    };
  }

  int? _sectionCount(LabWorkspaceState state, LabDeskSection section) {
    if (section.isFollowUps) {
      return null;
    }
    // Always use patient totals — Lab UI is patient-grouped only.
    const LabWorkbenchView view = LabWorkbenchView.patients;
    return switch (section) {
      LabDeskSection.worklist => state.summary.totalForView(view),
      LabDeskSection.collection => state.summary.collectionForView(view),
      LabDeskSection.critical => state.summary.criticalForView(view),
      LabDeskSection.completed => state.summary.completedForView(view),
      LabDeskSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(LabDeskSection section) {
    return switch (section) {
      LabDeskSection.critical => AppTabCountTone.danger,
      LabDeskSection.collection => AppTabCountTone.warning,
      LabDeskSection.worklist ||
      LabDeskSection.completed ||
      LabDeskSection.followUps => AppTabCountTone.info,
    };
  }

  void _scheduleRouteQuery(LabWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(LabWorkspaceQuery query) async {
    final LabDeskSection? section = _sectionFromQuery(query.section);
    if (section != null) {
      final String canonical = _sectionToQueryValue(section);
      final String incoming = query.section.trim().toLowerCase();
      final bool needsCanonicalUrl =
          incoming.isNotEmpty && incoming != canonical;
      if (section != _section || needsCanonicalUrl) {
        _selectSection(
          section,
          updateUrl: needsCanonicalUrl,
          applyScope: section != _section || !section.isFollowUps,
        );
      }
    }

    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      unawaited(
        ref
            .read(labWorkspaceControllerProvider.notifier)
            .applySearch(query.search),
      );
    }
    if (query.orderId.isEmpty && query.encounterId.isEmpty) {
      return;
    }

    LabOrderSummary? order = _findOrderByQuery(query);
    if (order == null && query.orderId.isNotEmpty) {
      final AppFailure? failure = await ref
          .read(labWorkspaceControllerProvider.notifier)
          .selectOrderById(query.orderId);
      if (!mounted) {
        return;
      }
      _showFailureIfNeeded(context, failure);
      if (failure != null) {
        return;
      }
      order = _readLabState(ref)?.selectedWorkflow?.order;
    }
    if (order == null || !mounted) {
      return;
    }
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final bool canMutate = canWriteLab(policy);
    await _openLabDetailDialog(
      context,
      ref,
      widget.state,
      order,
      canMutate,
    );
  }

  LabOrderSummary? _findOrderByQuery(LabWorkspaceQuery query) {
    for (final LabOrderSummary order in widget.state.worklist.items) {
      if (query.orderId.isNotEmpty &&
          (order.apiId == query.orderId ||
              order.id == query.orderId ||
              order.displayId == query.orderId)) {
        return order;
      }
      if (query.encounterId.isNotEmpty &&
          order.encounterId == query.encounterId) {
        return order;
      }
    }
    return null;
  }
}

class _LabWorklistPanel extends ConsumerWidget {
  const _LabWorklistPanel({
    required this.state,
    required this.canMutate,
    required this.searchController,
    required this.columnVisibilityController,
    required this.filterValue,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.sectionName,
    this.createAction,
    this.onSettingsPressed,
  });

  final LabWorkspaceState state;
  final bool canMutate;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<LabOrderSummary>
  columnVisibilityController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchCleared;
  final String sectionName;
  final AppSearchBarAction? createAction;
  final Future<void> Function()? onSettingsPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    final List<LabOrderSummary> pageItems = state.worklist.items;
    final List<LabOrderSummary> filteredItems = _filterWorklistItems(
      pageItems,
      filterValue,
    );
    final bool clientFiltersActive = _labClientFiltersActive(filterValue);
    final AppPage<LabOrderSummary> displayPage = AppPage<LabOrderSummary>(
      items: filteredItems,
      request: state.worklist.request,
      totalItemCount: clientFiltersActive
          ? filteredItems.length
          : state.worklist.totalItemCount,
    );

    return Stack(
      children: <Widget>[
        AppListTable<LabOrderSummary>(
          page: displayPage,
          columnVisibilityController: columnVisibilityController,
          columnVisibilityStorageKey: 'lab_$sectionName',
          columnWidthStorageKey: 'lab_cw_$sectionName',
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          columnVisibilityTitle: l10n.labDeskSettingsTitle,
          columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
          columnVisibilityResetLabel: l10n.labResetColumnsAction,
          onSettingsPressed: onSettingsPressed,
          search: AppListTableSearch<LabOrderSummary>(
            controller: searchController,
            semanticLabel: l10n.labSearchLabel,
            hintText: l10n.labSearchHint,
            matcher: _labWorklistSearchMatcher(context),
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
            onClear: onSearchCleared,
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
            advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            advancedFilterResetAppliesImmediately: true,
            enableDateFilter: true,
            dateFilterLabel: l10n.labOrderedDateFilterLabel,
            dateFromLabel: l10n.opdDateFromLabel,
            dateToLabel: l10n.opdDateToLabel,
            allFieldsLabel: l10n.opdAllFieldsFilterLabel,
            textFilters: _labWorklistTextFilters(l10n),
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _LabWorkspaceContentState._queueFilterKey,
                label: l10n.labScopeFilterLabel,
                allLabel: l10n.opdAllFieldsFilterLabel,
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(
                    value: 'pending',
                    label: l10n.labScopeCollection,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'critical',
                    label: l10n.labScopeCritical,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'completed_today',
                    label: l10n.labScopeCompleted,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'all',
                    label: l10n.labScopeAll,
                  ),
                ],
              ),
              AppSearchBarFilterGroup(
                key: _LabWorkspaceContentState._paymentFilterKey,
                label: l10n.labPaymentColumnLabel,
                allLabel: l10n.opdAllFieldsFilterLabel,
                choices: _paymentFilterChoices(l10n, pageItems),
              ),
              AppSearchBarFilterGroup(
                key: _LabWorkspaceContentState._statusFilterKey,
                label: l10n.labEntryStatusColumnLabel,
                allLabel: l10n.opdAllFieldsFilterLabel,
                choices: _statusFilterChoices(context, pageItems),
              ),
              AppSearchBarFilterGroup(
                key: _LabWorkspaceContentState._resultFlagFilterKey,
                label: l10n.labResultFlagFilterLabel,
                allLabel: l10n.opdAllFieldsFilterLabel,
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(
                    value: 'critical',
                    label: l10n.labResultFlagCritical,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'abnormal',
                    label: l10n.labResultFlagAbnormal,
                  ),
                  AppSearchBarFilterChoice(
                    value: 'flagged',
                    label: l10n.labResultFlagAnyFlagged,
                  ),
                ],
              ),
            ],
            filterValue: filterValue,
            hasActiveFilters: _labHasActiveAdvancedFilters(filterValue),
            onFilterChanged: onFilterChanged,
            trailingActions: <AppSearchBarAction>[
              ?createAction,
            ],
          ),
          previousPageLabel: l10n.labPreviousPageLabel,
          nextPageLabel: l10n.labNextPageLabel,
          pageLabelBuilder: (AppPage<LabOrderSummary> page) {
            return _pageLabel(context, page);
          },
          onPageChanged: controller.changePage,
          onRowSelected: (LabOrderSummary order) {
            unawaited(
              _openLabDetailDialog(context, ref, state, order, canMutate),
            );
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.labNoPatientsTitle,
            body: l10n.labNoPatientsBody,
            icon: Icons.science_outlined,
          ),
          columns: _patientViewWorklistColumns(
            context,
            onNextAction: (LabOrderSummary order) {
              unawaited(
                _openLabDetailDialog(
                  context,
                  ref,
                  state,
                  order,
                  canMutate,
                ),
              );
            },
          ),
          columnChoices: _optionalWorklistColumns(context),
          mobileItemBuilder: (BuildContext context, LabOrderSummary item) {
            final String? patientId = item.patientId?.trim();
            final AppWorkspaceStatus status = _orderStatus(context, item.status);
            return AppListTableMobileItem(
              title: item.patientDisplayName ?? item.displayTitle,
              caption: patientId?.isNotEmpty == true ? patientId : null,
              meta: <AppListTableMobileMeta>[
                AppListTableMobileMeta(label: status.label, icon: status.icon),
                AppListTableMobileMeta(
                  label: item.isPatientGroup
                      ? (item.testsLabel ?? l10n.profileUnknownValue)
                      : '${item.displayId ?? item.apiId} · ${item.testsLabel ?? l10n.profileUnknownValue}',
                  icon: Icons.science_outlined,
                ),
              ],
            );
          },
        ),
        if (state.isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

bool Function(LabOrderSummary, String) _labWorklistSearchMatcher(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return (LabOrderSummary item, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    if (item.matchesSearch(query)) {
      return true;
    }

    return <String?>[
      labStatusLabel(context, item.status),
      _worklistGlanceStatus(context, item).label,
      _entryStatus(context, item).label,
      _resultStatus(context, item).label,
      _orderIdsCellLabel(item),
      _labBillingGateLabel(context, item),
      _nextActionLabel(context, item),
      clinicalRequestPaymentStatusDisplayLabel(
        l10n,
        item.effectivePaymentStatus,
      ),
      _labOrderEncounterLabel(item),
      _sourceLocationLabel(item),
      item.encounterSourceLabel,
      item.encounterLocationLabel,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  };
}

List<LabOrderSummary> _filterWorklistItems(
  List<LabOrderSummary> items,
  AppSearchBarFilterValue filterValue,
) {
  if (!_labClientFiltersActive(filterValue)) {
    return items;
  }
  final String? payment = filterValue.option(
    _LabWorkspaceContentState._paymentFilterKey,
  );
  final String? status = filterValue.option(
    _LabWorkspaceContentState._statusFilterKey,
  );
  final String? resultFlag = filterValue.option(
    _LabWorkspaceContentState._resultFlagFilterKey,
  );
  final String patient = (filterValue.text(
            _LabWorkspaceContentState._textPatientKey,
          ) ??
          '')
      .trim()
      .toLowerCase();
  final String patientId = (filterValue.text(
            _LabWorkspaceContentState._textPatientIdKey,
          ) ??
          '')
      .trim()
      .toLowerCase();
  final String test = (filterValue.text(
            _LabWorkspaceContentState._textTestKey,
          ) ??
          '')
      .trim()
      .toLowerCase();
  final String orderId = (filterValue.text(
            _LabWorkspaceContentState._textOrderIdKey,
          ) ??
          '')
      .trim()
      .toLowerCase();

  return items
      .where((LabOrderSummary order) {
        if (payment != null && payment.isNotEmpty) {
          final String actual = (order.effectivePaymentStatus ?? 'NOT_BILLED')
              .toUpperCase();
          if (actual != payment.toUpperCase()) {
            return false;
          }
        }
        if (status != null && status.isNotEmpty) {
          if ((order.status ?? '').toUpperCase() != status.toUpperCase()) {
            return false;
          }
        }
        if (resultFlag != null && resultFlag.isNotEmpty) {
          if (!_orderMatchesResultFlag(order, resultFlag)) {
            return false;
          }
        }
        if (patient.isNotEmpty) {
          final String name = (order.patientDisplayName ?? '').toLowerCase();
          if (!name.contains(patient)) {
            return false;
          }
        }
        if (patientId.isNotEmpty) {
          final String id = (order.patientId ?? '').toLowerCase();
          if (!id.contains(patientId)) {
            return false;
          }
        }
        if (test.isNotEmpty) {
          final String tests = (order.testsLabel ?? '').toLowerCase();
          final bool itemMatch = order.items.any((LabOrderItem item) {
            final String haystack = <String?>[
              item.testDisplayName,
              item.testCode,
              item.panelDisplayName,
            ].whereType<String>().join(' ').toLowerCase();
            return haystack.contains(test);
          });
          if (!tests.contains(test) && !itemMatch) {
            return false;
          }
        }
        if (orderId.isNotEmpty) {
          final String haystack = <String?>[
            order.displayId,
            order.id,
            order.apiId,
            ...order.orderDisplayIds,
            ...order.orderIds,
          ].whereType<String>().join(' ').toLowerCase();
          if (!haystack.contains(orderId)) {
            return false;
          }
        }
        return true;
      })
      .toList(growable: false);
}

bool _labClientFiltersActive(AppSearchBarFilterValue filterValue) {
  return filterValue.option(_LabWorkspaceContentState._paymentFilterKey) !=
          null ||
      filterValue.option(_LabWorkspaceContentState._statusFilterKey) != null ||
      filterValue.option(_LabWorkspaceContentState._resultFlagFilterKey) !=
          null ||
      (filterValue.text(_LabWorkspaceContentState._textPatientKey)?.trim().isNotEmpty ??
          false) ||
      (filterValue
              .text(_LabWorkspaceContentState._textPatientIdKey)
              ?.trim()
              .isNotEmpty ??
          false) ||
      (filterValue.text(_LabWorkspaceContentState._textTestKey)?.trim().isNotEmpty ??
          false) ||
      (filterValue
              .text(_LabWorkspaceContentState._textOrderIdKey)
              ?.trim()
              .isNotEmpty ??
          false);
}

bool _labHasActiveAdvancedFilters(AppSearchBarFilterValue filterValue) {
  return _labClientFiltersActive(filterValue) ||
      filterValue.dateFrom != null ||
      filterValue.dateTo != null;
}

bool _orderMatchesResultFlag(LabOrderSummary order, String flag) {
  final String normalized = flag.trim().toLowerCase();
  final bool hasCritical = order.items.any((LabOrderItem item) {
    final String status = (item.effectiveResultStatus ?? '').toUpperCase();
    return status == 'CRITICAL';
  });
  final bool hasAbnormal = order.items.any((LabOrderItem item) {
    final String status = (item.effectiveResultStatus ?? '').toUpperCase();
    return status == 'ABNORMAL';
  });
  return switch (normalized) {
    'critical' => hasCritical,
    'abnormal' => hasAbnormal,
    'flagged' => hasCritical || hasAbnormal || order.hasCriticalResult,
    _ => true,
  };
}

List<AppSearchBarTextFilter> _labWorklistTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _LabWorkspaceContentState._textPatientKey,
      label: l10n.labPatientFilterLabel,
      hintText: l10n.labPatientFilterLabel,
      icon: Icons.person_search_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _LabWorkspaceContentState._textPatientIdKey,
      label: l10n.labPatientIdFilterLabel,
      icon: Icons.badge_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _LabWorkspaceContentState._textTestKey,
      label: l10n.labTestFilterLabel,
      icon: Icons.science_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _LabWorkspaceContentState._textOrderIdKey,
      label: l10n.labOrderIdFilterLabel,
      icon: Icons.tag_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

List<AppSearchBarTextFilter> _labFollowUpTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: 'patient',
      label: l10n.labPatientFilterLabel,
      icon: Icons.person_search_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: 'patient_id',
      label: l10n.labPatientIdFilterLabel,
      icon: Icons.badge_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: 'phone',
      label: l10n.patientsPhoneLabel,
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    ),
  ];
}

List<AppSearchBarFilterGroup> _labFollowUpFilterGroups(AppLocalizations l10n) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: 'follow_up_status',
      label: l10n.labFollowUpStatusFilterLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'pending',
          label: l10n.labFollowUpStatusPending,
        ),
        AppSearchBarFilterChoice(
          value: 'completed',
          label: l10n.labFollowUpStatusCompleted,
        ),
      ],
    ),
  ];
}

List<AppSearchBarFilterChoice> _paymentFilterChoices(
  AppLocalizations l10n,
  List<LabOrderSummary> items,
) {
  final Set<String> seen = <String>{};
  final List<AppSearchBarFilterChoice> choices = <AppSearchBarFilterChoice>[];
  for (final LabOrderSummary order in items) {
    final String value = (order.effectivePaymentStatus ?? 'NOT_BILLED')
        .toUpperCase();
    if (!seen.add(value)) {
      continue;
    }
    choices.add(
      AppSearchBarFilterChoice(
        value: value,
        label: clinicalRequestPaymentStatusDisplayLabel(l10n, value),
      ),
    );
  }
  choices.sort(
    (AppSearchBarFilterChoice a, AppSearchBarFilterChoice b) =>
        a.label.compareTo(b.label),
  );
  return choices;
}

List<AppSearchBarFilterChoice> _statusFilterChoices(
  BuildContext context,
  List<LabOrderSummary> items,
) {
  final Set<String> seen = <String>{};
  final List<AppSearchBarFilterChoice> choices = <AppSearchBarFilterChoice>[];
  for (final LabOrderSummary order in items) {
    final String? raw = order.status?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }
    final String value = raw.toUpperCase();
    if (!seen.add(value)) {
      continue;
    }
    choices.add(
      AppSearchBarFilterChoice(
        value: value,
        label: _worklistStatusFilterLabel(context, value),
      ),
    );
  }
  choices.sort(
    (AppSearchBarFilterChoice a, AppSearchBarFilterChoice b) =>
        a.label.compareTo(b.label),
  );
  return choices;
}

String _worklistStatusFilterLabel(BuildContext context, String value) {
  final AppLocalizations l10n = context.l10n;
  return switch (value.toUpperCase()) {
    'ORDERED' || 'PENDING' => l10n.labWorklistStatusPendingOrdered,
    'COLLECTED' => l10n.labWorklistStatusPendingCollected,
    'IN_PROCESS' => l10n.labWorklistStatusPendingInProcess,
    'CRITICAL' => l10n.labWorklistStatusReadyCritical,
    'ABNORMAL' => l10n.labWorklistStatusReadyAbnormal,
    'COMPLETED' => l10n.labWorklistStatusCompleted,
    'CANCELLED' => l10n.labWorklistStatusCancelled,
    'REJECTED' || 'REJECTED_SAMPLE' => l10n.labWorklistStatusRejected,
    _ => labStatusLabel(context, value),
  };
}

List<AppListTableColumn<LabOrderSummary>> _patientViewWorklistColumns(
  BuildContext context, {
  required ValueChanged<LabOrderSummary> onNextAction,
}) {
  return <AppListTableColumn<LabOrderSummary>>[
    _patientNameWorklistColumn(context),
    _orderWorklistColumn(context, LabWorkbenchView.patients),
    _testsWorklistColumn(context),
    _labWorkflowStatusColumn(context),
    _labNextActionColumn(context, onNextAction: onNextAction),
  ];
}

List<AppListTableColumn<LabOrderSummary>> _optionalWorklistColumns(
  BuildContext context,
) {
  return <AppListTableColumn<LabOrderSummary>>[
    _patientIdWorklistColumn(context),
    _encounterWorklistColumn(context),
    _labEncounterWorklistColumn(context),
    _sourceLocationWorklistColumn(context),
    _billingWorklistColumn(context),
    _entryStatusWorklistColumn(context),
    _resultStatusWorklistColumn(context),
  ];
}

AppListTableColumn<LabOrderSummary> _patientNameWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'patient',
    label: l10n.labPatientColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(_patientSortKey(left), _patientSortKey(right)),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      final String? patientId = item.patientId?.trim();
      return AppListItemText(
        title: item.patientDisplayName ?? item.displayTitle,
        subtitle: patientId?.isNotEmpty == true ? patientId : null,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _testsWorklistColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'tests',
    label: l10n.labTestsColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(left.testsLabel, right.testsLabel),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.testsLabel ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _labWorkflowStatusColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'workflow_status',
    label: l10n.labEntryStatusColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _worklistGlanceStatus(context, left).label,
          _worklistGlanceStatus(context, right).label,
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return AppWorkspaceStatusBadge(
        status: _worklistGlanceStatus(context, item),
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _labNextActionColumn(
  BuildContext context, {
  required ValueChanged<LabOrderSummary> onNextAction,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'next_action',
    label: l10n.labNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _nextActionLabel(context, left),
          _nextActionLabel(context, right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labNextActionCell(
        context,
        item,
        onActivate: () => onNextAction(item),
      );
    },
  );
}

Widget _labNextActionCell(
  BuildContext context,
  LabOrderSummary item, {
  required VoidCallback onActivate,
}) {
  final String label = _nextActionLabel(context, item);
  if (!_isLabNextActionActivatable(item)) {
    return _labWorklistTextCell(context, label);
  }
  return _LabCompactNextActionButton(label: label, onPressed: onActivate);
}

bool _isLabNextActionActivatable(LabOrderSummary order) {
  final String status = (order.status ?? '').toUpperCase();
  return status != 'CANCELLED' && status != 'COMPLETED';
}

class _LabCompactNextActionButton extends StatelessWidget {
  const _LabCompactNextActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.xs,
                  vertical: theme.spacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.arrow_forward_outlined,
                      size: 18,
                      color: primaryColor,
                    ),
                    SizedBox(width: theme.spacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

AppListTableColumn<LabOrderSummary> _patientIdWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'patient_id',
    label: l10n.labPatientIdColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(left.patientId, right.patientId),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.patientId ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _encounterWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'encounter',
    label: l10n.labEncounterColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(left.encounterId, right.encounterId),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.encounterId ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _labEncounterWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'lab_encounter',
    label: l10n.labLabEncounterColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _labOrderEncounterLabel(left),
          _labOrderEncounterLabel(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        _labOrderEncounterLabel(item) ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _sourceLocationWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'source_location',
    label: l10n.labSourceLocationColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _sourceLocationLabel(left),
          _sourceLocationLabel(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        _sourceLocationLabel(item) ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _entryStatusWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'entry_status',
    label: l10n.labEntryStatusColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareNumber(
          _enteredResultItemCount(left),
          _enteredResultItemCount(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return AppWorkspaceStatusBadge(status: _entryStatus(context, item));
    },
  );
}

AppListTableColumn<LabOrderSummary> _billingWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'billing',
    label: l10n.labPaymentColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          left.effectivePaymentStatus,
          right.effectivePaymentStatus,
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(context, _labBillingGateLabel(context, item));
    },
  );
}

AppListTableColumn<LabOrderSummary> _resultStatusWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'result_status',
    label: l10n.labResultStatusLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareNumber(
          _completedResultItemCount(left),
          _completedResultItemCount(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return AppWorkspaceStatusBadge(status: _resultStatus(context, item));
    },
  );
}

Widget _labWorklistTextCell(BuildContext context, String value) {
  final ThemeData theme = Theme.of(context);
  return Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyMedium,
  );
}

String? _labOrderEncounterLabel(LabOrderSummary order) {
  if (order.isPatientGroup) {
    if (order.orderDisplayIds.isNotEmpty) {
      return order.orderDisplayIds.first;
    }
    if (order.orderIds.isNotEmpty) {
      return order.orderIds.first;
    }
  }
  return order.displayId ?? order.apiId;
}

String? _sourceLocationLabel(LabOrderSummary order) {
  return _joinNonEmpty(<String?>[
    order.encounterSourceLabel,
    order.encounterLocationLabel,
  ]);
}

AppListTableColumn<LabOrderSummary> _orderWorklistColumn(
  BuildContext context,
  LabWorkbenchView view,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'orders',
    label: view == LabWorkbenchView.patients
        ? l10n.labOrdersColumnLabel
        : l10n.labOrderColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(_orderSortKey(left), _orderSortKey(right)),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _LabOrderIdentifier(order: item);
    },
  );
}

String _patientSortKey(LabOrderSummary order) {
  final String value = _joinNonEmpty(<String?>[
    order.patientDisplayName,
    order.patientId,
    order.displayTitle,
  ]);
  return value.isNotEmpty ? value : order.id;
}

String _orderSortKey(LabOrderSummary order) {
  if (order.isPatientGroup) {
    final List<String> ids = _orderDisplayIds(order);
    if (ids.isNotEmpty) {
      return ids.first;
    }
  }
  return order.displayId ?? order.apiId;
}

List<String> _orderDisplayIds(LabOrderSummary order) {
  if (order.isPatientGroup) {
    final List<String> ids = order.orderDisplayIds.isNotEmpty
        ? order.orderDisplayIds
        : order.orderIds;
    return ids
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
  }
  final String single = (order.displayId ?? order.apiId).trim();
  return single.isEmpty ? const <String>[] : <String>[single];
}

/// Orders column: first lab order ID, or `ID +N` when more than one.
String _orderIdsCellLabel(LabOrderSummary order) {
  final List<String> ids = _orderDisplayIds(order);
  if (ids.isEmpty) {
    return order.apiId;
  }
  if (ids.length == 1) {
    return ids.first;
  }
  return '${ids.first} +${ids.length - 1}';
}

class _LabOrderIdentifier extends StatelessWidget {
  const _LabOrderIdentifier({required this.order});

  final LabOrderSummary order;

  @override
  Widget build(BuildContext context) {
    return _labWorklistTextCell(context, _orderIdsCellLabel(order));
  }
}

Future<void> _openLabDetailDialog(
  BuildContext context,
  WidgetRef ref,
  LabWorkspaceState fallbackState,
  LabOrderSummary order,
  bool canMutate,
) async {
  final LabWorkspaceController controller = ref.read(
    labWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectOrder(order);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final LabWorkspaceState state = _readLabState(ref) ?? fallbackState;
  final bool hasSelection =
      state.selectedWorkflow != null || state.selectedWorkflows.isNotEmpty;
  if (!hasSelection) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => LabResultEntryDialog(
      canMutate: canMutate,
    ),
  );
}

LabWorkspaceState? _readLabState(WidgetRef ref) {
  return ref
      .read(labWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (LabWorkspaceState state) => state, failure: (_) => null);
}


Future<void> _openCreateLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  final LabOrderContextInput? orderContext =
      await showAppDialog<LabOrderContextInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LabOrderContextDialog(worklist: state.worklist.items),
      );
  if (orderContext == null || !context.mounted) {
    return;
  }

  await _openLabOrderActionDialog(context, state, orderContext: orderContext);
}

Future<void> _openAdditionalLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabOrderSummary order,
) async {
  final String? patientId = order.patientId?.trim();
  if (patientId == null || patientId.isEmpty) {
    return;
  }

  await _openLabOrderActionDialog(
    context,
    state,
    orderContext: LabOrderContextInput(
      patientId: patientId,
      patientName: order.patientDisplayName,
      encounterId: order.encounterId,
    ),
  );
}

Future<void> _openLabOrderActionDialog(
  BuildContext context,
  LabWorkspaceState state, {
  required LabOrderContextInput orderContext,
}) async {
  ClinicalActionLabOrderRecord? existingOrder;
  final String? existingOrderId = orderContext.normalizedExistingOrderId;
  if (existingOrderId != null) {
    existingOrder = await _loadExistingLabOrderRecord(
      context,
      state,
      existingOrderId,
    );
    if (existingOrder == null || !context.mounted) {
      return;
    }
  }

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: _clinicalReferenceData(state),
        existingOrder: existingOrder,
        patientContext: ClinicalRequestPatientContext(
          patientName: orderContext.patientName,
          patientId: orderContext.patientId,
          encounterId: orderContext.encounterId,
        ),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return ProviderScope.containerOf(context)
                  .read(clinicalRepositoryProvider)
                  .searchClinicalCatalog(
                    termType: termType,
                    query: query,
                    limit: limit ?? 80,
                    source: source,
                    offeredOnly: true,
                    facilityId: state.catalogScope?.facilityId,
                  );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return _readLabController(context).createOrder(
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                  billing: billing,
                ),
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return _readLabController(context).updateOrder(
                labOrderId,
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                  billing: billing,
                ),
              );
            },
      ),
    ),
  );
}

Future<void> _openEditLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabOrderWorkflow workflow,
) async {
  final LabOrderSummary order = workflow.order;
  final LabOrderContextInput? orderContext =
      await showAppDialog<LabOrderContextInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            LabOrderContextDialog(worklist: state.worklist.items, order: order),
      );
  if (orderContext == null || !context.mounted) {
    return;
  }

  await _openLabOrderActionDialog(context, state, orderContext: orderContext);
}

Future<ClinicalActionLabOrderRecord?> _loadExistingLabOrderRecord(
  BuildContext context,
  LabWorkspaceState fallbackState,
  String orderId,
) async {
  final AppFailure? failure = await _readLabController(
    context,
  ).selectOrderById(orderId);
  if (!context.mounted) {
    return null;
  }
  _showFailureIfNeeded(context, failure);
  if (failure != null) {
    return null;
  }

  final LabOrderWorkflow? workflow = _readLabStateFromContext(
    context,
  )?.selectedWorkflow;
  if (workflow != null && _isSameLabOrder(workflow.order, orderId)) {
    return _clinicalLabOrderRecord(workflow.order);
  }

  final LabOrderSummary? fallbackOrder = _findLabOrderById(
    fallbackState.worklist.items,
    orderId,
  );
  return fallbackOrder == null ? null : _clinicalLabOrderRecord(fallbackOrder);
}

LabOrderSummary? _findLabOrderById(
  Iterable<LabOrderSummary> orders,
  String orderId,
) {
  for (final LabOrderSummary order in orders) {
    if (_isSameLabOrder(order, orderId)) {
      return order;
    }
  }
  return null;
}

bool _isSameLabOrder(LabOrderSummary order, String orderId) {
  final String normalized = orderId.trim().toLowerCase();
  return normalized.isNotEmpty &&
      (<String?>[order.apiId, order.id, order.displayId]
          .whereType<String>()
          .map((String value) => value.trim().toLowerCase())
          .contains(normalized));
}

LabWorkspaceState? _readLabStateFromContext(BuildContext context) {
  return ProviderScope.containerOf(context)
      .read(labWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (LabWorkspaceState state) => state, failure: (_) => null);
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> result,
) async {
  final bool? saved = await result;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
  }
}

LabWorkspaceController _readLabController(BuildContext context) {
  return ProviderScope.containerOf(
    context,
  ).read(labWorkspaceControllerProvider.notifier);
}

ClinicalActionReferenceData _clinicalReferenceData(LabWorkspaceState state) {
  return ClinicalActionReferenceData(
    labTests: state.catalogTests
        .where((LabCatalogItem item) => item.isOfferedAtFacility)
        .map(_clinicalCatalogOptionFromLabItem)
        .toList(growable: false),
    labPanels: state.catalogPanels
        .where((LabCatalogItem item) => item.isOfferedAtFacility)
        .map(_clinicalCatalogOptionFromLabItem)
        .toList(growable: false),
  );
}

ClinicalActionCatalogOption _clinicalCatalogOptionFromLabItem(
  LabCatalogItem item,
) {
  return ClinicalActionCatalogOption(
    id: item.id,
    publicId: item.apiId,
    name: item.name,
    code: item.code,
    category: item.category,
    secondaryText: item.specimenType ?? item.description,
    unitPrice: item.unitPrice,
    currency: item.currency,
    childIds: item.panelItems
        .map((LabPanelItem panelItem) => panelItem.labTestId)
        .whereType<String>()
        .toList(growable: false),
    childCodes: item.panelItems
        .map((LabPanelItem panelItem) => panelItem.testCode)
        .whereType<String>()
        .toList(growable: false),
  );
}

ClinicalActionLabOrderRecord _clinicalLabOrderRecord(LabOrderSummary order) {
  return ClinicalActionLabOrderRecord(
    id: order.apiId,
    labOrderItems: order.items
        .map(
          (LabOrderItem item) => ClinicalActionLabOrderItem(
            id: item.apiId,
            status: item.status,
            resultStatus: item.resultStatus,
            labTestId: item.labTestId,
            testDisplayName: item.testDisplayName,
            testCode: item.testCode,
            category: item.category,
            specimenType: item.specimenType,
            unit: item.unit,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
        )
        .toList(growable: false),
  );
}

List<Widget> _dialogActions(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

String _formatCatalogUnitPrice(
  BuildContext context,
  LabCatalogItem item,
  AppLocalizations l10n,
) {
  final num? price = item.unitPrice;
  if (price == null) {
    return l10n.clinicalRequestPriceNotSetLabel;
  }
  return AppFormatters.currency(
    price.toDouble(),
    Localizations.localeOf(context),
    currencyCode: item.currency ?? appDefaultCurrencyCode,
  );
}

Widget _catalogItemNameCell(String label, {double maxWidth = 280}) {
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Tooltip(
      message: label,
      child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

String _joinNonEmpty(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}

List<String> _uniqueNonEmpty(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      continue;
    }
    final String key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  result.sort(
    (String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return result;
}

String _resultKindLabel(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'NUMERIC' => l10n.labResultKindNumeric,
    'QUALITATIVE' => l10n.labResultKindQualitative,
    'TEXT' => l10n.labResultKindText,
    _ => value?.trim().isNotEmpty == true ? value! : '—',
  };
}

String _unitRangeSummary(BuildContext context, LabCatalogItem item) {
  final int rangeCount = item.referenceRangeCount > 0
      ? item.referenceRangeCount
      : item.referenceRanges.length;
  final String summary = _joinNonEmpty(<String?>[
    item.unit,
    if (rangeCount > 0)
      context.l10n.labReferenceRangeCount(rangeCount)
    else
      item.referenceRange,
  ]);
  return summary.isEmpty ? context.l10n.profileUnknownValue : summary;
}

String _pageLabel(BuildContext context, AppPage<LabOrderSummary> page) {
  final int total = page.totalItemCount ?? page.items.length;
  return context.l10n.labPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

AppWorkspaceStatus _orderStatus(BuildContext context, String? value) {
  return labStatusBadge(context, value);
}

/// At-a-glance Status column: phase + detail (e.g. Pending - Ordered).
AppWorkspaceStatus _worklistGlanceStatus(
  BuildContext context,
  LabOrderSummary order,
) {
  return labWorklistGlanceStatus(context, order);
}

AppWorkspaceStatus _entryStatus(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  final int activeItems = _activeResultItemCount(order);
  final int enteredItems = _enteredResultItemCount(order);

  if ((order.status ?? '').toUpperCase() == 'CANCELLED') {
    return AppWorkspaceStatus(
      label: l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (activeItems > 0 && order.completedItemCount >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.task_alt_outlined,
    );
  }
  if (activeItems > 0 && enteredItems >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusFilled,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.fact_check_outlined,
    );
  }
  if (enteredItems > 0 || order.inProcessItemCount > 0) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyEntered,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: l10n.labStatusOrdered,
    icon: Icons.assignment_outlined,
  );
}

AppWorkspaceStatus _resultStatus(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  final int activeItems = _activeResultItemCount(order);
  final int enteredItems = _enteredResultItemCount(order);

  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if ((order.status ?? '').toUpperCase() == 'CANCELLED' ||
      order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: order.hasRejectedItem
          ? l10n.labStatusRejected
          : l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (activeItems > 0 && order.completedItemCount >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  if (activeItems > 0 && enteredItems >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusFilled,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.fact_check_outlined,
    );
  }
  if (enteredItems > 0 || order.inProcessItemCount > 0) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyFilled,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: l10n.labStatusOrdered,
    icon: Icons.radio_button_unchecked,
  );
}

int _activeResultItemCount(LabOrderSummary order) {
  final int active = order.itemCount - order.rejectedItemCount;
  return active < 0 ? 0 : active;
}

int _enteredResultItemCount(LabOrderSummary order) {
  final int enteredFromItems = order.items
      .where((LabOrderItem item) => !item.isRejected && item.hasResult)
      .length;
  final int statusCount = order.completedItemCount + order.inProcessItemCount;
  return enteredFromItems > statusCount ? enteredFromItems : statusCount;
}

int _completedResultItemCount(LabOrderSummary order) {
  return order.completedItemCount;
}

String _labBillingGateLabel(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  if (!order.hasBillingGate) {
    return l10n.clinicalRequestPaymentNotBilledLabel;
  }
  return clinicalRequestPaymentStatusDisplayLabel(
    l10n,
    order.effectivePaymentStatus,
  );
}

String _nextActionLabel(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  if ((order.status ?? '').toUpperCase() == 'CANCELLED') {
    return l10n.labNextActionCancelled;
  }
  final bool awaitPayment =
      order.hasBillingGate && !order.isPaymentSatisfied;
  // Incomplete orders stay on Enter result; escalate only when entry is done.
  if (order.enterableItemCount > 0) {
    return awaitPayment
        ? l10n.labWorkflowNextAwaitPayment
        : l10n.labNextActionEnterResult;
  }
  if (order.hasCriticalResult) {
    return l10n.labNextActionReviewCritical;
  }
  final String status = (order.status ?? '').toUpperCase();
  return switch (status) {
    'ORDERED' || 'COLLECTED' => awaitPayment
        ? l10n.labWorkflowNextAwaitPayment
        : l10n.labNextActionEnterResult,
    'IN_PROCESS' => awaitPayment
        ? l10n.labWorkflowNextAwaitPayment
        : l10n.labNextActionEnterResult,
    'COMPLETED' => l10n.labNextActionCompleted,
    _ => l10n.labNextActionWatch,
  };
}
