import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class EmergencyWorkspacePage extends ConsumerWidget {
  const EmergencyWorkspacePage({
    super.key,
    this.initialQuery = const EmergencyWorkspaceQuery(),
  });

  final EmergencyWorkspaceQuery initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<EmergencyWorkspaceState>> state = ref.watch(
      emergencyWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<EmergencyWorkspaceState>(
      value: state,
      loadingTitle: 'Loading emergency board',
      loadingBody: 'Loading emergency cases, triage state, and ambulance work.',
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(emergencyWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, EmergencyWorkspaceState data) {
        return _EmergencyWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _EmergencyWorkspaceContent extends ConsumerStatefulWidget {
  const _EmergencyWorkspaceContent({
    required this.state,
    this.initialQuery = const EmergencyWorkspaceQuery(),
  });

  final EmergencyWorkspaceState state;
  final EmergencyWorkspaceQuery initialQuery;

  @override
  ConsumerState<_EmergencyWorkspaceContent> createState() =>
      _EmergencyWorkspaceContentState();
}

class _EmergencyWorkspaceContentState
    extends ConsumerState<_EmergencyWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.emergencyWrite],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<EmergencyCaseSummary>
  _columnVisibilityController;
  late EmergencyBoardTab _currentTab;
  String? _appliedDeepLinkSignature;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialQuery.search.isNotEmpty
          ? widget.initialQuery.search
          : widget.state.query.search,
    );
    _columnVisibilityController =
        AppListTableColumnVisibilityController<EmergencyCaseSummary>();
    _currentTab =
        emergencyTabFromScopeValue(widget.initialQuery.scope) ??
        EmergencyBoardTab.active;
    if (widget.initialQuery.hasRouteTargeting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_applyDeepLink(widget.initialQuery));
      });
    }
  }

  Future<void> _applyDeepLink(EmergencyWorkspaceQuery query) async {
    if (!query.hasRouteTargeting ||
        _appliedDeepLinkSignature == query.signature) {
      return;
    }
    _appliedDeepLinkSignature = query.signature;

    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );

    final EmergencyBoardTab? scopeTab = emergencyTabFromScopeValue(query.scope);
    if (scopeTab != null) {
      setState(() => _currentTab = scopeTab);
      await controller.applyScope(emergencyBoardScopeForTab(scopeTab));
    }

    final String searchTerm = query.caseId.isNotEmpty
        ? query.caseId
        : query.search;
    if (searchTerm.isNotEmpty) {
      if (query.caseId.isNotEmpty) {
        setState(() => _currentTab = EmergencyBoardTab.all);
        await controller.applyScope(EmergencyBoardScope.all);
      }
      await controller.applySearch(searchTerm);
    }

    if (query.caseId.isEmpty || !mounted) {
      return;
    }

    final EmergencyWorkspaceState state =
        readEmergencyState(ref) ?? widget.state;
    EmergencyCaseSummary? target;
    for (final EmergencyCaseSummary item in state.board.items) {
      final String needle = query.caseId.toLowerCase();
      if (item.id.toLowerCase() == needle ||
          (item.displayId ?? '').toLowerCase() == needle) {
        target = item;
        break;
      }
    }
    target ??= EmergencyCaseSummary(id: query.caseId, displayId: query.caseId);

    if (!mounted) {
      return;
    }

    // Panel-focused deep links open the mutation dialog directly (no empty
    // detail shell). Bare case links open detail with the stage next-action
    // omitted so it is not duplicated inside Quick Actions.
    if (query.panel != EmergencyDetailPanelFocus.none) {
      await openEmergencyFocusedAction(
        context,
        ref,
        state,
        target,
        query.panel,
        _writeRequirement,
      );
      return;
    }

    await openEmergencyDetailDialog(
      context,
      ref,
      state,
      target,
      _writeRequirement,
      omitNextActionKind: emergencyBoardNextActionKind(
        target,
        tab: _currentTab,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _EmergencyWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialQuery.signature != widget.initialQuery.signature &&
        widget.initialQuery.hasRouteTargeting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_applyDeepLink(widget.initialQuery));
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final EmergencyWorkspaceState state = widget.state;
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );

    final List<EmergencyCaseSummary> rows = _filteredRows(state);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final EmergencyBoardTab tab in EmergencyBoardTab.values)
                  AppTabItem(
                    id: tab.name,
                    icon: _tabIcon(tab),
                    label: emergencyTabLabel(tab),
                    count: _tabCount(state, tab),
                    countTone: _tabCountTone(tab),
                  ),
              ],
              selectedId: _currentTab.name,
              onTabTapped: (String tabId) {
                for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
                  if (tab.name == tabId) {
                    setState(() {
                      _currentTab = tab;
                      _filterValue = AppSearchBarFilterValue.empty;
                    });
                    _updateUrlForTab(tab);
                    controller.applyScope(emergencyBoardScopeForTab(tab));
                    break;
                  }
                }
              },
              primaryAction: _buildPrimaryAction(context),
            ),
            SizedBox(height: theme.spacing.sm),
            AppListTable<EmergencyCaseSummary>(
              items: rows,
              columns: emergencyDefaultColumnsForTab(
                context,
                _currentTab,
                writeRequirement: _writeRequirement,
              ),
              columnChoices: emergencyColumnChoicesForTab(
                context,
                _currentTab,
                writeRequirement: _writeRequirement,
              ),
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: 'emergency_${_currentTab.name}',
              columnWidthStorageKey: 'emergency_cw_${_currentTab.name}',
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle: l10n.emergencyTableSettingsTitle,
              isLoading: state.isRefreshingBoard,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              search: AppListTableSearch<EmergencyCaseSummary>(
                controller: _searchController,
                semanticLabel: l10n.emergencySearchSemanticLabel,
                hintText: l10n.emergencySearchHint,
                clearLabel: l10n.emergencyClearSearchAction,
                matcher: emergencyTableSearchMatcher,
                onSubmitted: controller.applySearch,
                onClear: () => controller.applySearch(''),
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.emergencyFiltersLabel,
                advancedFilterTitle: l10n.emergencyAdvancedFiltersTitle,
                advancedFilterApplyLabel: l10n.emergencyApplyFiltersAction,
                advancedFilterResetLabel: l10n.emergencyResetFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.emergencyAllFieldsFilterLabel,
                filterGroups: emergencyFilterGroupsForTab(
                  l10n,
                  _currentTab,
                  _buildRows(state),
                ),
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
              ),
              onRowSelected: (EmergencyCaseSummary summary) {
                unawaited(
                  openEmergencyDetailDialog(
                    context,
                    ref,
                    state,
                    summary,
                    _writeRequirement,
                    omitNextActionKind: emergencyBoardNextActionKind(
                      summary,
                      tab: _currentTab,
                    ),
                  ),
                );
              },
              rowColorBuilder: rowColor,
              emptyBuilder: (_) => const AppWorkspaceStatePanel.state(
                variant: AppStateViewVariant.empty,
                title: 'No emergency cases',
                body:
                    'Emergency arrivals and ambulance calls will appear here.',
                icon: Icons.emergency_outlined,
              ),
              mobileItemBuilder:
                  (BuildContext context, EmergencyCaseSummary item) {
                    return emergencyMobileListItem(
                      context,
                      ref,
                      item,
                      tab: _currentTab,
                      writeRequirement: _writeRequirement,
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPrimaryAction(BuildContext context) {
    if (!emergencyShowsQuickArrival(_currentTab)) {
      return null;
    }
    return AppAccessActionGate(
      requirement: _writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarPrimary(
          label: context.l10n.emergencyQuickArrivalAction,
          icon: Icons.add_circle_outline,
          enabled: isAllowed,
          onPressed: () => _openQuickArrivalDialog(context),
        );
      },
    );
  }

  List<EmergencyCaseSummary> _filteredRows(EmergencyWorkspaceState state) {
    return emergencyApplyClientFilters(
      _buildRows(state),
      _filterValue,
      _currentTab,
    );
  }

  List<EmergencyCaseSummary> _buildRows(EmergencyWorkspaceState state) {
    final List<EmergencyCaseSummary> items = state.board.items;
    switch (_currentTab) {
      case EmergencyBoardTab.active:
        return items
            .where((EmergencyCaseSummary item) => item.isOpen)
            .toList(growable: false);
      case EmergencyBoardTab.critical:
        return items
            .where(
              (EmergencyCaseSummary item) => item.isOpen && item.isCritical,
            )
            .toList(growable: false);
      case EmergencyBoardTab.ambulance:
        return items
            .where((EmergencyCaseSummary item) => item.hasAmbulanceActivity)
            .toList(growable: false);
      case EmergencyBoardTab.handoff:
        return items
            .where((EmergencyCaseSummary item) => item.isReadyForHandoff)
            .toList(growable: false);
      case EmergencyBoardTab.closed:
        return items
            .where((EmergencyCaseSummary item) => !item.isOpen)
            .toList(growable: false);
      case EmergencyBoardTab.all:
        return items.toList(growable: false);
    }
  }

  void _updateUrlForTab(EmergencyBoardTab tab) {
    if (!mounted) {
      return;
    }
    final String location = AppRoutes.emergency.location(
      queryParameters: <String, String>{'scope': tab.name},
    );
    GoRouter.of(context).replace<void>(location);
  }

  int _tabCount(EmergencyWorkspaceState state, EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.active => state.activeCount,
      EmergencyBoardTab.critical => state.criticalCount,
      EmergencyBoardTab.ambulance => state.ambulanceCount,
      EmergencyBoardTab.handoff => state.handoffCount,
      EmergencyBoardTab.closed => state.closedCount,
      EmergencyBoardTab.all => state.allCount,
    };
  }

  static AppTabCountTone _tabCountTone(EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.critical ||
      EmergencyBoardTab.closed => AppTabCountTone.danger,
      EmergencyBoardTab.active ||
      EmergencyBoardTab.ambulance ||
      EmergencyBoardTab.handoff => AppTabCountTone.warning,
      EmergencyBoardTab.all => AppTabCountTone.info,
    };
  }

  Future<void> _openQuickArrivalDialog(BuildContext context) async {
    final bool? saved = await showEmergencyQuickArrivalDialog(
      context: context,
      onSubmit: (EmergencyQuickArrivalInput input) {
        return ref
            .read(emergencyWorkspaceControllerProvider.notifier)
            .createQuickArrival(input);
      },
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: context.l10n.emergencyQuickArrivalOpenedMessage,
      );
    }
  }

  static IconData _tabIcon(EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.active => Icons.emergency_outlined,
      EmergencyBoardTab.critical => Icons.priority_high_outlined,
      EmergencyBoardTab.ambulance => Icons.airport_shuttle_outlined,
      EmergencyBoardTab.handoff => AppActionIcons.handoff,
      EmergencyBoardTab.closed => Icons.check_circle_outlined,
      EmergencyBoardTab.all => Icons.inventory_2_outlined,
    };
  }
}

/// Tab label used by [AppTabStrip] for the Emergency board.
String emergencyTabLabel(EmergencyBoardTab tab) {
  return switch (tab) {
    EmergencyBoardTab.active => EmergencyText.activeCases,
    EmergencyBoardTab.critical => EmergencyText.critical,
    EmergencyBoardTab.ambulance => EmergencyText.ambulance,
    EmergencyBoardTab.handoff => EmergencyText.handoffReady,
    EmergencyBoardTab.closed => EmergencyText.closed,
    EmergencyBoardTab.all => EmergencyText.all,
  };
}

/// Whether the tab toolbar shows Quick arrival as the primary action.
bool emergencyShowsQuickArrival(EmergencyBoardTab tab) {
  return tab != EmergencyBoardTab.closed;
}

/// Maps a board tab to the repository / controller scope value.
EmergencyBoardScope emergencyBoardScopeForTab(EmergencyBoardTab tab) {
  return switch (tab) {
    EmergencyBoardTab.active => EmergencyBoardScope.active,
    EmergencyBoardTab.critical => EmergencyBoardScope.critical,
    EmergencyBoardTab.ambulance => EmergencyBoardScope.ambulance,
    EmergencyBoardTab.handoff => EmergencyBoardScope.handoff,
    EmergencyBoardTab.closed => EmergencyBoardScope.closed,
    EmergencyBoardTab.all => EmergencyBoardScope.all,
  };
}

/// Resolves a URL `scope` / `board` / `tab` query value to a board tab.
EmergencyBoardTab? emergencyTabFromScopeValue(String value) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
    if (tab.name == normalized) {
      return tab;
    }
  }
  return null;
}

const String emergencySeverityFilterKey = 'severity';
const String emergencyTriageFilterKey = 'triage';
const String emergencyCaseStatusFilterKey = 'case_status';
const String emergencyDispatchStatusFilterKey = 'dispatch_status';
const String emergencyDestinationFilterKey = 'destination';

/// Default visible columns (max five) for an emergency board tab.
List<AppListTableColumn<EmergencyCaseSummary>> emergencyDefaultColumnsForTab(
  BuildContext context,
  EmergencyBoardTab tab, {
  required AccessRequirement writeRequirement,
}) {
  return switch (tab) {
    EmergencyBoardTab.active ||
    EmergencyBoardTab.all => <AppListTableColumn<EmergencyCaseSummary>>[
      emergencyPatientColumn(),
      emergencyPriorityColumn(),
      emergencyLocationColumn(),
      emergencyCaseStatusColumn(context),
      emergencyNextActionColumn(
        context,
        tab: tab,
        writeRequirement: writeRequirement,
      ),
    ],
    EmergencyBoardTab.critical => <AppListTableColumn<EmergencyCaseSummary>>[
      emergencyPatientColumn(),
      emergencyPriorityColumn(),
      emergencyArrivalColumn(),
      emergencyCaseStatusColumn(context),
      emergencyNextActionColumn(
        context,
        tab: tab,
        writeRequirement: writeRequirement,
      ),
    ],
    EmergencyBoardTab.ambulance => <AppListTableColumn<EmergencyCaseSummary>>[
      emergencyPatientColumn(),
      emergencyPriorityColumn(),
      emergencyAmbulanceColumn(),
      emergencyAmbulanceWorkflowStatusColumn(context),
      emergencyNextActionColumn(
        context,
        tab: tab,
        writeRequirement: writeRequirement,
      ),
    ],
    EmergencyBoardTab.handoff => <AppListTableColumn<EmergencyCaseSummary>>[
      emergencyPatientColumn(),
      emergencyPriorityColumn(),
      emergencyTriageColumn(),
      emergencyCaseStatusColumn(context),
      emergencyNextActionColumn(
        context,
        tab: tab,
        writeRequirement: writeRequirement,
      ),
    ],
    EmergencyBoardTab.closed => <AppListTableColumn<EmergencyCaseSummary>>[
      emergencyPatientColumn(),
      emergencyPriorityColumn(),
      emergencyCaseStatusColumn(context),
      emergencyHandoffDestinationColumn(),
      emergencyClosedAtColumn(context),
    ],
  };
}

/// Hidden column choices for the table settings modal per tab.
List<AppListTableColumn<EmergencyCaseSummary>> emergencyColumnChoicesForTab(
  BuildContext context,
  EmergencyBoardTab tab, {
  required AccessRequirement writeRequirement,
}) {
  final Set<String> defaultIds =
      emergencyDefaultColumnsForTab(
            context,
            tab,
            writeRequirement: writeRequirement,
          )
          .map((AppListTableColumn<EmergencyCaseSummary> column) => column.id)
          .whereType<String>()
          .toSet();

  final Set<String> allowedIds = switch (tab) {
    EmergencyBoardTab.active || EmergencyBoardTab.all => <String>{
      'arrival',
      'response',
      'triage',
      'facility',
      'dispatch_status',
      'ambulance',
      'handoff_destination',
      'closed_at',
    },
    EmergencyBoardTab.critical => <String>{
      'location',
      'response',
      'triage',
      'facility',
      'dispatch_status',
      'ambulance',
      'handoff_destination',
      'closed_at',
    },
    EmergencyBoardTab.ambulance => <String>{
      'dispatch_status',
      'trip_status',
      'arrival',
      'location',
      'response',
    },
    EmergencyBoardTab.handoff => <String>{
      'response',
      'arrival',
      'location',
      'facility',
    },
    EmergencyBoardTab.closed => <String>{
      'arrival',
      'location',
      'triage',
      'response',
    },
  };

  final List<AppListTableColumn<EmergencyCaseSummary>> allChoices =
      <AppListTableColumn<EmergencyCaseSummary>>[
        emergencyArrivalColumn(),
        emergencyResponseColumn(),
        emergencyTriageColumn(),
        emergencyFacilityColumn(),
        emergencyDispatchStatusColumn(),
        emergencyAmbulanceColumn(),
        emergencyTripStatusColumn(context),
        emergencyHandoffDestinationColumn(),
        emergencyClosedAtColumn(context),
        emergencyLocationColumn(),
      ];

  return <AppListTableColumn<EmergencyCaseSummary>>[
    for (final AppListTableColumn<EmergencyCaseSummary> column in allChoices)
      if (allowedIds.contains(column.id) && !defaultIds.contains(column.id))
        column,
  ];
}

/// Advanced filter groups for the emergency worklist search chrome.
List<AppSearchBarFilterGroup> emergencyFilterGroupsForTab(
  AppLocalizations l10n,
  EmergencyBoardTab tab,
  List<EmergencyCaseSummary> rows,
) {
  final List<AppSearchBarFilterGroup> groups = <AppSearchBarFilterGroup>[];

  switch (tab) {
    case EmergencyBoardTab.active:
    case EmergencyBoardTab.critical:
    case EmergencyBoardTab.all:
      groups.addAll(<AppSearchBarFilterGroup>[
        AppSearchBarFilterGroup(
          key: emergencySeverityFilterKey,
          label: l10n.emergencySeverityFilterLabel,
          allLabel: l10n.emergencyAllFieldsFilterLabel,
          choices: _emergencyDistinctFilterChoices(
            rows,
            (EmergencyCaseSummary item) => item.severity,
            apiLabel,
          ),
        ),
        AppSearchBarFilterGroup(
          key: emergencyTriageFilterKey,
          label: l10n.emergencyTriageFilterLabel,
          allLabel: l10n.emergencyAllFieldsFilterLabel,
          choices: _emergencyDistinctFilterChoices(
            rows,
            (EmergencyCaseSummary item) =>
                item.triageLevel.isEmpty ? 'TRIAGE_PENDING' : item.triageLevel,
            (String value) =>
                value == 'TRIAGE_PENDING' ? 'Triage pending' : apiLabel(value),
          ),
        ),
      ]);
    case EmergencyBoardTab.handoff:
      groups.add(
        AppSearchBarFilterGroup(
          key: emergencyTriageFilterKey,
          label: l10n.emergencyTriageFilterLabel,
          allLabel: l10n.emergencyAllFieldsFilterLabel,
          choices: _emergencyDistinctFilterChoices(
            rows,
            (EmergencyCaseSummary item) =>
                item.triageLevel.isEmpty ? 'TRIAGE_PENDING' : item.triageLevel,
            (String value) =>
                value == 'TRIAGE_PENDING' ? 'Triage pending' : apiLabel(value),
          ),
        ),
      );
    case EmergencyBoardTab.ambulance:
      groups.add(
        AppSearchBarFilterGroup(
          key: emergencyDispatchStatusFilterKey,
          label: l10n.emergencyDispatchStatusFilterLabel,
          allLabel: l10n.emergencyAllFieldsFilterLabel,
          choices: _emergencyDistinctFilterChoices(
            rows,
            (EmergencyCaseSummary item) => item.latestDispatch?.status,
            apiLabel,
          ),
        ),
      );
    case EmergencyBoardTab.closed:
      groups.add(
        AppSearchBarFilterGroup(
          key: emergencyDestinationFilterKey,
          label: l10n.emergencyDestinationFilterLabel,
          allLabel: l10n.emergencyAllFieldsFilterLabel,
          choices: _emergencyDistinctFilterChoices(
            rows,
            (EmergencyCaseSummary item) => item.handoff?.destination,
            apiLabel,
          ),
        ),
      );
  }

  groups.add(
    AppSearchBarFilterGroup(
      key: emergencyCaseStatusFilterKey,
      label: l10n.emergencyCaseStatusFilterLabel,
      allLabel: l10n.emergencyAllFieldsFilterLabel,
      choices: _emergencyDistinctFilterChoices(
        rows,
        (EmergencyCaseSummary item) => item.status,
        apiLabel,
      ),
    ),
  );

  return groups;
}

List<AppSearchBarFilterChoice> _emergencyDistinctFilterChoices(
  List<EmergencyCaseSummary> rows,
  String? Function(EmergencyCaseSummary item) valueForItem,
  String Function(String value) labelForValue,
) {
  final Set<String> seen = <String>{};
  final List<AppSearchBarFilterChoice> choices = <AppSearchBarFilterChoice>[];
  for (final EmergencyCaseSummary item in rows) {
    final String? raw = valueForItem(item)?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }
    final String key = raw.toUpperCase();
    if (!seen.add(key)) {
      continue;
    }
    choices.add(
      AppSearchBarFilterChoice(value: key, label: labelForValue(raw)),
    );
  }
  choices.sort(
    (AppSearchBarFilterChoice left, AppSearchBarFilterChoice right) =>
        left.label.compareTo(right.label),
  );
  return choices;
}

/// Applies client-side advanced filters to tab-scoped emergency rows.
List<EmergencyCaseSummary> emergencyApplyClientFilters(
  List<EmergencyCaseSummary> rows,
  AppSearchBarFilterValue filterValue,
  EmergencyBoardTab tab,
) {
  if (!filterValue.isActive) {
    return rows;
  }

  List<EmergencyCaseSummary> filtered = rows;

  final String? severity = filterValue.option(emergencySeverityFilterKey);
  if (severity != null && severity.isNotEmpty) {
    filtered = <EmergencyCaseSummary>[
      for (final EmergencyCaseSummary item in filtered)
        if ((item.severity ?? '').toUpperCase() == severity) item,
    ];
  }

  final String? triage = filterValue.option(emergencyTriageFilterKey);
  if (triage != null && triage.isNotEmpty) {
    filtered = <EmergencyCaseSummary>[
      for (final EmergencyCaseSummary item in filtered)
        if (triage == 'TRIAGE_PENDING'
            ? item.triageLevel.isEmpty
            : item.triageLevel.toUpperCase() == triage)
          item,
    ];
  }

  final String? dispatchStatus = filterValue.option(
    emergencyDispatchStatusFilterKey,
  );
  if (dispatchStatus != null && dispatchStatus.isNotEmpty) {
    filtered = <EmergencyCaseSummary>[
      for (final EmergencyCaseSummary item in filtered)
        if ((item.latestDispatch?.status ?? '').toUpperCase() == dispatchStatus)
          item,
    ];
  }

  final String? destination = filterValue.option(emergencyDestinationFilterKey);
  if (destination != null && destination.isNotEmpty) {
    filtered = <EmergencyCaseSummary>[
      for (final EmergencyCaseSummary item in filtered)
        if ((item.handoff?.destination ?? '').toUpperCase() == destination)
          item,
    ];
  }

  final String? selectedCaseStatus = filterValue.option(
    emergencyCaseStatusFilterKey,
  );
  if (selectedCaseStatus != null && selectedCaseStatus.isNotEmpty) {
    filtered = <EmergencyCaseSummary>[
      for (final EmergencyCaseSummary item in filtered)
        if ((item.status ?? '').toUpperCase() == selectedCaseStatus) item,
    ];
  }

  return filtered;
}
