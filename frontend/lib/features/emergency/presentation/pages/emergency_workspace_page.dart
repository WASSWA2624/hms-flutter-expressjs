import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<EmergencyCaseSummary>();
    _currentTab =
        _tabFromScopeValue(widget.initialQuery.scope) ??
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

    final EmergencyBoardTab? scopeTab = _tabFromScopeValue(query.scope);
    if (scopeTab != null) {
      setState(() => _currentTab = scopeTab);
      await controller.applyScope(_boardScopeForTab(scopeTab));
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
        _readEmergencyState(ref) ?? widget.state;
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
    await _openEmergencyDetailDialog(
      context,
      ref,
      state,
      target,
      _writeRequirement,
    );
  }

  @override
  void didUpdateWidget(covariant _EmergencyWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
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
    final EmergencyWorkspaceState state = widget.state;
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );

    final List<EmergencyCaseSummary> rows = _buildRows(state);

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
                      for (final EmergencyBoardTab tab
                          in EmergencyBoardTab.values)
                        AppTabItem(
                          id: tab.name,
                          icon: _tabIcon(tab),
                          label: '${_tabLabel(tab)} (${_tabCount(state, tab)})',
                        ),
                    ],
                    selectedId: _currentTab.name,
                    onTabTapped: (String tabId) {
                      for (final EmergencyBoardTab tab
                          in EmergencyBoardTab.values) {
                        if (tab.name == tabId) {
                          setState(() => _currentTab = tab);
                          _updateUrlForTab(tab);
                          controller.applyScope(_boardScopeForTab(tab));
                          break;
                        }
                      }
                    },
                  ),
                ),
                if (_currentTab != EmergencyBoardTab.closed) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  AppAccessActionGate(
                    requirement: _writeRequirement,
                    builder: (BuildContext context, bool isAllowed) {
                      return AppButton.primary(
                        label: EmergencyText.quickArrival,
                        leadingIcon: Icons.add_circle_outline,
                        enabled: isAllowed,
                        onPressed: () => _openQuickArrivalDialog(context),
                      );
                    },
                  ),
                ],
              ],
            ),
            SizedBox(height: theme.spacing.md),
            AppListTable<EmergencyCaseSummary>(
              items: rows,
              columns: _columnsForTab(_currentTab),
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: 'emergency_${_currentTab.name}',
              columnWidthStorageKey: 'emergency_cw_${_currentTab.name}',
              columnVisibilityLabel:
                  context.l10n.commonTableSettingsActionLabel,
              isLoading: state.isRefreshingBoard,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              search: AppListTableSearch<EmergencyCaseSummary>(
                controller: _searchController,
                semanticLabel: 'Search emergency cases',
                hintText: EmergencyText.searchHint,
                matcher: (EmergencyCaseSummary item, String query) =>
                    item.matchesSearch(query),
                onSubmitted: controller.applySearch,
                onClear: () => controller.applySearch(''),
              ),
              onRowSelected: (EmergencyCaseSummary summary) {
                unawaited(
                  _openEmergencyDetailDialog(
                    context,
                    ref,
                    state,
                    summary,
                    _writeRequirement,
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
              mobileItemBuilder: _mobileItemBuilder,
            ),
          ],
        ),
      ),
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

  List<AppListTableColumn<EmergencyCaseSummary>> _columnsForTab(
    EmergencyBoardTab tab,
  ) {
    switch (tab) {
      case EmergencyBoardTab.active:
      case EmergencyBoardTab.critical:
      case EmergencyBoardTab.all:
        return <AppListTableColumn<EmergencyCaseSummary>>[
          _patientColumn(),
          _priorityColumn(),
          _arrivalColumn(),
          _responseColumn(),
          _locationColumn(),
          _nextActionColumn(),
        ];
      case EmergencyBoardTab.ambulance:
        return <AppListTableColumn<EmergencyCaseSummary>>[
          _patientColumn(),
          _priorityColumn(),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'dispatch_status',
            label: EmergencyText.dispatchStatus,
            sortComparator:
                (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
                    appListTableCompareText(
                      left.latestDispatch?.status,
                      right.latestDispatch?.status,
                    ),
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              final String? status = item.latestDispatch?.status;
              if (status == null || status.isEmpty) {
                return const SizedBox.shrink();
              }
              return AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: apiLabel(status),
                  tone: ambulanceTone(status),
                ),
              );
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'ambulance',
            label: EmergencyText.ambulance,
            sortComparator:
                (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
                    appListTableCompareText(
                      left.latestDispatch?.ambulanceLabel,
                      right.latestDispatch?.ambulanceLabel,
                    ),
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(
                item.latestDispatch?.ambulanceLabel ??
                    item.activeTrip?.ambulanceLabel ??
                    '',
              );
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'trip_status',
            label: 'Trip status',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              final EmergencyAmbulanceTrip? trip = item.activeTrip;
              if (trip == null) {
                return const Text('No trip');
              }
              return AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: trip.isActive ? 'In transit' : 'Complete',
                  tone: trip.isActive
                      ? AppWorkspaceStatusTone.warning
                      : AppWorkspaceStatusTone.success,
                ),
              );
            },
          ),
          _arrivalColumn(),
        ];
      case EmergencyBoardTab.handoff:
        return <AppListTableColumn<EmergencyCaseSummary>>[
          _patientColumn(),
          _priorityColumn(),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'triage_level',
            label: EmergencyText.triage,
            sortComparator:
                (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
                    appListTableCompareText(
                      left.triageLevel,
                      right.triageLevel,
                    ),
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return AppWorkspaceStatusBadge(
                status: triageStatus(item.triageLevel),
              );
            },
          ),
          _responseColumn(),
          _nextActionColumn(),
        ];
      case EmergencyBoardTab.closed:
        return <AppListTableColumn<EmergencyCaseSummary>>[
          _patientColumn(),
          _priorityColumn(),
          _arrivalColumn(),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'handoff_destination',
            label: EmergencyText.handoffDestination,
            sortComparator:
                (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
                    appListTableCompareText(
                      left.handoff?.destination,
                      right.handoff?.destination,
                    ),
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(apiLabel(item.handoff?.destination ?? ''));
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            id: 'closed_at',
            label: 'Closed at',
            sortComparator:
                (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
                    appListTableCompareDateTime(
                      left.updatedAt,
                      right.updatedAt,
                    ),
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(dateTimeLabel(context, item.updatedAt));
            },
          ),
        ];
    }
  }

  AppListTableColumn<EmergencyCaseSummary> _patientColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'patient',
      label: EmergencyText.patient,
      alwaysVisible: true,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return EmergencyCaseCell(item: item);
      },
    );
  }

  AppListTableColumn<EmergencyCaseSummary> _priorityColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'priority',
      label: EmergencyText.priority,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareText(left.severity, right.severity),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return AppWorkspaceStatusBadge(status: severityStatus(item));
      },
    );
  }

  AppListTableColumn<EmergencyCaseSummary> _arrivalColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'arrival',
      label: EmergencyText.arrival,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareDateTime(left.createdAt, right.createdAt),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return Text(dateTimeLabel(context, item.createdAt));
      },
    );
  }

  AppListTableColumn<EmergencyCaseSummary> _responseColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'response',
      label: EmergencyText.response,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareText(left.responseStatus, right.responseStatus),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return AppWorkspaceStatusBadge(status: responseStatus(item));
      },
    );
  }

  AppListTableColumn<EmergencyCaseSummary> _locationColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'location',
      label: EmergencyText.location,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareText(left.currentLocation, right.currentLocation),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return Text(item.currentLocation);
      },
    );
  }

  AppListTableColumn<EmergencyCaseSummary> _nextActionColumn() {
    return AppListTableColumn<EmergencyCaseSummary>(
      id: 'next_action',
      label: EmergencyText.next,
      alwaysVisible: true,
      sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
          appListTableCompareText(left.nextAction, right.nextAction),
      cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
        return WorkflowActionButton(
          encounterId: item.id,
          patientId: item.patientId,
          stage: item.status,
          nextStep: emergencyNextStepCode(item),
          sourceModule: 'emergency',
          compact: true,
        );
      },
    );
  }

  Widget _mobileItemBuilder(BuildContext context, EmergencyCaseSummary item) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          EmergencyCaseCell(item: item),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              AppWorkspaceStatusBadge(status: severityStatus(item)),
              AppWorkspaceStatusBadge(status: responseStatus(item)),
              Text(
                joinDisplay(<String?>[
                  item.currentLocation,
                  dateTimeLabel(context, item.createdAt),
                ]),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _openQuickArrivalDialog(BuildContext context) async {
    final EmergencyQuickArrivalInput? input =
        await showAppDialog<EmergencyQuickArrivalInput>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const QuickArrivalDialog(),
        );
    if (input == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await ref
        .read(emergencyWorkspaceControllerProvider.notifier)
        .createQuickArrival(input);
    if (context.mounted) {
      showFailureIfNeeded(context, failure, successMessage: 'Arrival opened');
    }
  }

  static String _tabLabel(EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.active => 'Active cases',
      EmergencyBoardTab.critical => EmergencyText.critical,
      EmergencyBoardTab.ambulance => EmergencyText.ambulance,
      EmergencyBoardTab.handoff => 'Handoff ready',
      EmergencyBoardTab.closed => EmergencyText.closed,
      EmergencyBoardTab.all => EmergencyText.all,
    };
  }

  static IconData _tabIcon(EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.active => Icons.emergency_outlined,
      EmergencyBoardTab.critical => Icons.priority_high_outlined,
      EmergencyBoardTab.ambulance => Icons.airport_shuttle_outlined,
      EmergencyBoardTab.handoff => Icons.output_outlined,
      EmergencyBoardTab.closed => Icons.check_circle_outlined,
      EmergencyBoardTab.all => Icons.inventory_2_outlined,
    };
  }

  static EmergencyBoardScope _boardScopeForTab(EmergencyBoardTab tab) {
    return switch (tab) {
      EmergencyBoardTab.active => EmergencyBoardScope.active,
      EmergencyBoardTab.critical => EmergencyBoardScope.critical,
      EmergencyBoardTab.ambulance => EmergencyBoardScope.ambulance,
      EmergencyBoardTab.handoff => EmergencyBoardScope.handoff,
      EmergencyBoardTab.closed => EmergencyBoardScope.closed,
      EmergencyBoardTab.all => EmergencyBoardScope.all,
    };
  }

  static EmergencyBoardTab? _tabFromScopeValue(String value) {
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
}

Future<void> _openEmergencyDetailDialog(
  BuildContext context,
  WidgetRef ref,
  EmergencyWorkspaceState fallbackState,
  EmergencyCaseSummary summary,
  AccessRequirement writeRequirement,
) async {
  final EmergencyWorkspaceController controller = ref.read(
    emergencyWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectCase(summary);
  if (context.mounted) {
    showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final EmergencyWorkspaceState state =
      _readEmergencyState(ref) ?? fallbackState;
  if (state.selectedDetail == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.emergencyCaseDialogTitle),
      icon: const Icon(Icons.emergency_outlined),
      scrollable: true,
      maxWidth: 980,
      content: EmergencyDetailPanel(
        state: state,
        writeRequirement: writeRequirement,
        isDialog: true,
      ),
    ),
  );
}

EmergencyWorkspaceState? _readEmergencyState(WidgetRef ref) {
  return ref
      .read(emergencyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (EmergencyWorkspaceState state) => state,
        failure: (_) => null,
      );
}
