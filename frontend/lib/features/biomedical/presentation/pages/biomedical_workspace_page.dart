import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class BiomedicalWorkspacePage extends ConsumerWidget {
  const BiomedicalWorkspacePage({this.initialQuery, super.key});

  final BiomedicalRouteQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<BiomedicalWorkspaceState>> state = ref.watch(
      biomedicalWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<BiomedicalWorkspaceState>(
      value: state,
      loadingTitle: l10n.biomedicalLoadingTitle,
      loadingBody: l10n.biomedicalLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(biomedicalWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, BiomedicalWorkspaceState data) {
        return _BiomedicalWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _BiomedicalWorkspaceContent extends ConsumerStatefulWidget {
  const _BiomedicalWorkspaceContent({required this.state, this.initialQuery});

  final BiomedicalWorkspaceState state;
  final BiomedicalRouteQuery? initialQuery;

  @override
  ConsumerState<_BiomedicalWorkspaceContent> createState() =>
      _BiomedicalWorkspaceContentState();
}

class _BiomedicalWorkspaceContentState
    extends ConsumerState<_BiomedicalWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.biomedWrite,
      AppPermissions.operationsWrite,
    ],
    activeModules: <String>['biomedical-engineering-suite'],
  );
  static const AccessRequirement _printRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.evidenceExport],
    anyPermissions: <AppPermission>[
      AppPermissions.biomedRead,
      AppPermissions.biomedWrite,
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    ],
    activeModules: <String>['biomedical-engineering-suite'],
  );

  late final TextEditingController _searchController;
  late AppListTableColumnVisibilityController<BiomedicalAsset>
  _tableColumnController;
  String _currentPanel = BiomedicalPanels.registry;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BiomedicalAsset>();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _BiomedicalWorkspaceContent oldWidget) {
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
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _scheduleRouteQuery(BiomedicalRouteQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLink(query));
    });
  }

  Future<void> _applyDeepLink(BiomedicalRouteQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final String? panel = _panelFromQuery(query.panel);
    if (panel != null) {
      _switchPanel(panel);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }
  }

  String? _panelFromQuery(String raw) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final String panel in BiomedicalPanels.values) {
      if (panel == normalized) {
        return panel;
      }
    }
    return null;
  }

  void _switchPanel(String panel) {
    if (panel == _currentPanel) {
      return;
    }
    final BiomedicalWorkspaceController controller = ref.read(
      biomedicalWorkspaceControllerProvider.notifier,
    );
    _tableColumnController.dispose();
    setState(() {
      _currentPanel = panel;
      _tableColumnController =
          AppListTableColumnVisibilityController<BiomedicalAsset>();
    });
    unawaited(controller.applyPanel(panel));
  }

  void _updateUrlForPanel(String panel) {
    if (!mounted) {
      return;
    }
    final String location = AppRoutes.biomedical.location(
      queryParameters: <String, String>{
        if (panel != BiomedicalPanels.registry) 'panel': panel,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final BiomedicalWorkspaceState state = widget.state;
    final BiomedicalWorkspaceController controller = ref.read(
      biomedicalWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = _writeRequirement.isAllowed(accessPolicy);
    final bool canPrint = _printRequirement.isAllowed(accessPolicy);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final String panel in BiomedicalPanels.values)
                  AppTabItem(
                    id: panel,
                    icon: _panelIcon(panel),
                    label: _panelLabel(l10n, panel),
                    count:
                        panel == BiomedicalPanels.registry &&
                            state.workbench.summary.totalEquipment > 0
                        ? state.workbench.summary.totalEquipment
                        : null,
                  ),
              ],
              selectedId: _currentPanel,
              onTabTapped: (String tabId) {
                _switchPanel(tabId);
                _updateUrlForPanel(tabId);
              },
              primaryAction: _primaryActionWidget(l10n, state, controller),
              secondaryActions: _secondaryActionsForPanel(
                context,
                l10n,
                state,
                controller,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppListTable<BiomedicalAsset>(
              page: state.workbench.assets,
              isLoading: state.isRefreshing,
              columnVisibilityController: _tableColumnController,
              columnVisibilityStorageKey: 'biomedical_$_currentPanel',
              columnWidthStorageKey: 'biomedical_cw_$_currentPanel',
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle: l10n.commonTableSettingsTitle,
              search: AppListTableSearch<BiomedicalAsset>(
                controller: _searchController,
                semanticLabel: l10n.biomedicalSearchLabel,
                hintText: l10n.biomedicalSearchHint,
                matcher: (BiomedicalAsset item, String query) =>
                    _matchesBiomedicalSearch(item, query, l10n),
                onSubmitted: controller.applySearch,
                onClear: () => controller.applySearch(''),
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                filterGroups: <AppSearchBarFilterGroup>[
                  AppSearchBarFilterGroup(
                    key: _statusFilterKey,
                    label: l10n.biomedicalStatusFilterLabel,
                    choices: _lookupChoices(
                      state.workbench.lookups.statuses,
                      fallbackValues: _fallbackStatuses,
                    ),
                  ),
                  AppSearchBarFilterGroup(
                    key: _priorityFilterKey,
                    label: l10n.biomedicalPriorityFilterLabel,
                    choices: _lookupChoices(
                      state.workbench.lookups.priorities,
                      fallbackValues: _fallbackPriorities,
                    ),
                  ),
                  AppSearchBarFilterGroup(
                    key: _facilityFilterKey,
                    label: l10n.biomedicalFacilityFilterLabel,
                    choices: _lookupChoices(state.workbench.lookups.facilities),
                  ),
                  AppSearchBarFilterGroup(
                    key: _datePresetFilterKey,
                    label: l10n.biomedicalDatePresetFilterLabel,
                    choices: _datePresetChoices(l10n),
                  ),
                ],
                filterValue: _filterValue(state.query),
                hasActiveFilters: state.query.hasActiveFilters,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  unawaited(
                    controller.applyFilters(
                      panel: _currentPanel,
                      status: value.option(_statusFilterKey),
                      priority: value.option(_priorityFilterKey),
                      facilityId: value.option(_facilityFilterKey),
                      datePreset: value.option(_datePresetFilterKey),
                    ),
                  );
                },
              ),
              previousPageLabel: l10n.biomedicalPreviousPageLabel,
              nextPageLabel: l10n.biomedicalNextPageLabel,
              pageLabelBuilder: (AppPage<BiomedicalAsset> page) {
                return l10n.biomedicalPageLabel(
                  page.firstItemNumber,
                  page.lastItemNumber,
                  page.totalItemCount ?? page.items.length,
                );
              },
              onPageChanged: controller.changePage,
              onRowSelected: (BiomedicalAsset asset) {
                unawaited(
                  _openAssetDetailDialog(context, asset, canWrite, canPrint),
                );
              },
              itemKeyBuilder: (BiomedicalAsset item) =>
                  ValueKey<String>('${item.resource}:${item.displayId}'),
              emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                title: l10n.biomedicalNoAssetsTitle,
                body: l10n.biomedicalNoAssetsBody,
                icon: Icons.medical_services_outlined,
              ),
              mobileItemBuilder: (BuildContext context, BiomedicalAsset item) {
                final String? panelField =
                    _mobilePanelFieldLabel(context, _currentPanel, item);
                return AppListTableMobileItem(
                  title: item.displayTitle,
                  caption: item.displaySubtitle,
                  meta: <AppListTableMobileMeta>[
                    AppListTableMobileMeta(
                      label: _labelForCode(
                        item.status,
                        fallback: context.l10n.biomedicalNotAvailableLabel,
                      ),
                    ),
                    if (panelField != null)
                      AppListTableMobileMeta(
                        label: panelField,
                        icon: _mobilePanelFieldIcon(_currentPanel),
                      ),
                  ],
                  showAvatar: false,
                );
              },
              columns: _defaultColumnsForPanel(
                l10n,
                canWrite: canWrite,
                canPrint: canPrint,
                state: state,
                onOpenDetail: (BiomedicalAsset asset) => unawaited(
                  _openAssetDetailDialog(context, asset, canWrite, canPrint),
                ),
              ),
              columnChoices: _columnChoicesForPanel(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _primaryActionWidget(
    AppLocalizations l10n,
    BiomedicalWorkspaceState state,
    BiomedicalWorkspaceController controller,
  ) {
    if (_currentPanel == BiomedicalPanels.support ||
        _currentPanel == BiomedicalPanels.analytics) {
      return AppTabToolbarPrimary(
        label: l10n.commonRefreshActionLabel,
        icon: Icons.refresh,
        isLoading: state.isRefreshing,
        enabled: !state.isRefreshing,
        onPressed: state.isRefreshing
            ? null
            : () async {
                final AppFailure? failure = await controller.refresh();
                if (!mounted) {
                  return;
                }
                _showFailureIfNeeded(context, failure);
              },
      );
    }

    final _PanelAction? action = _primaryActionForPanel(l10n, _currentPanel);
    if (action == null) {
      return null;
    }
    return AppAccessActionGate(
      requirement: _writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarPrimary(
          label: action.label,
          icon: action.icon,
          enabled: isAllowed && !state.isMutating,
          onPressed: isAllowed && !state.isMutating
              ? () => unawaited(
                  _openActionDialog(context, ref, state, action.kind),
                )
              : null,
        );
      },
    );
  }

  List<Widget> _secondaryActionsForPanel(
    BuildContext context,
    AppLocalizations l10n,
    BiomedicalWorkspaceState state,
    BiomedicalWorkspaceController controller,
  ) {
    final List<Widget> actions = <Widget>[];
    final BiomedicalSummary summary = state.workbench.summary;

    void addQueueAction({
      required int count,
      required String label,
      required IconData icon,
      required String queue,
    }) {
      if (count <= 0) {
        return;
      }
      actions.add(
        AppTabToolbarAction(
          label: label,
          icon: icon,
          semanticLabel: label,
          tooltip: label,
          onPressed: () => _applyQueue(controller, state, queue),
        ),
      );
    }

    addQueueAction(
      count: summary.overduePm,
      label: l10n.biomedicalOverduePmSummaryLabel,
      icon: Icons.event_busy_outlined,
      queue: BiomedicalQueues.overduePm,
    );
    addQueueAction(
      count: summary.openWorkOrders,
      label: l10n.biomedicalOpenWorkOrdersSummaryLabel,
      icon: Icons.build_outlined,
      queue: BiomedicalQueues.openWorkOrders,
    );
    addQueueAction(
      count: summary.criticalDowntime,
      label: l10n.biomedicalCriticalDowntimeSummaryLabel,
      icon: Icons.power_settings_new_outlined,
      queue: BiomedicalQueues.criticalDowntime,
    );
    addQueueAction(
      count: summary.activeRecalls,
      label: l10n.biomedicalActiveRecallsSummaryLabel,
      icon: Icons.campaign_outlined,
      queue: BiomedicalQueues.recallActions,
    );

    if (_currentPanel == BiomedicalPanels.registry ||
        _currentPanel == BiomedicalPanels.support) {
      actions.add(
        AppAccessActionGate(
          requirement: _writeRequirement,
          builder: (BuildContext gateContext, bool isAllowed) {
            return AppTabToolbarAction(
              label: l10n.biomedicalReportFaultAction,
              icon: Icons.report_problem_outlined,
              semanticLabel: l10n.biomedicalReportFaultAction,
              tooltip: l10n.biomedicalReportFaultAction,
              enabled: isAllowed && !state.isMutating,
              onPressed: isAllowed && !state.isMutating
                  ? () => unawaited(
                      _openActionDialog(
                        context,
                        ref,
                        state,
                        _BiomedicalActionKind.fault,
                      ),
                    )
                  : null,
            );
          },
        ),
      );
    }

    if (_currentPanel != BiomedicalPanels.support &&
        _currentPanel != BiomedicalPanels.analytics) {
      actions.add(_refreshSecondaryAction(context, l10n, state, controller));
    }

    return actions;
  }

  AppTabToolbarAction _refreshSecondaryAction(
    BuildContext context,
    AppLocalizations l10n,
    BiomedicalWorkspaceState state,
    BiomedicalWorkspaceController controller,
  ) {
    return AppTabToolbarAction(
      label: l10n.commonRefreshActionLabel,
      icon: Icons.refresh,
      semanticLabel: l10n.commonRefreshActionLabel,
      tooltip: l10n.commonRefreshActionLabel,
      enabled: !state.isRefreshing,
      isLoading: state.isRefreshing,
      onPressed: state.isRefreshing
          ? null
          : () async {
              final AppFailure? failure = await controller.refresh();
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
    );
  }

  List<AppListTableColumn<BiomedicalAsset>> _defaultColumnsForPanel(
    AppLocalizations l10n, {
    required bool canWrite,
    required bool canPrint,
    required BiomedicalWorkspaceState state,
    required void Function(BiomedicalAsset asset) onOpenDetail,
  }) {
    final AppListTableColumn<BiomedicalAsset> nextAction = _nextActionColumn(
      l10n,
      canWrite: canWrite,
      state: state,
      onOpenDetail: onOpenDetail,
    );
    return switch (_currentPanel) {
      BiomedicalPanels.registry => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _locationColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.overview => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _riskColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.preventive => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _nextDueColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.workOrders => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _riskColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.compliance => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _nextDueColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.support => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _locationColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      BiomedicalPanels.analytics => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _locationColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
      _ => <AppListTableColumn<BiomedicalAsset>>[
        _assetTagColumn(l10n),
        _equipmentColumn(l10n),
        _statusColumn(l10n),
        nextAction,
      ],
    };
  }

  List<AppListTableColumn<BiomedicalAsset>> _columnChoicesForPanel(
    AppLocalizations l10n,
  ) {
    return switch (_currentPanel) {
      BiomedicalPanels.registry => <AppListTableColumn<BiomedicalAsset>>[
        _categoryColumn(l10n),
        _riskColumn(l10n),
        _ownerColumn(l10n),
      ],
      BiomedicalPanels.overview => <AppListTableColumn<BiomedicalAsset>>[
        _ownerColumn(l10n),
      ],
      BiomedicalPanels.preventive => <AppListTableColumn<BiomedicalAsset>>[
        _ownerColumn(l10n),
      ],
      BiomedicalPanels.workOrders => <AppListTableColumn<BiomedicalAsset>>[
        _ownerColumn(l10n),
      ],
      BiomedicalPanels.compliance => <AppListTableColumn<BiomedicalAsset>>[
        _categoryColumn(l10n),
      ],
      BiomedicalPanels.support => <AppListTableColumn<BiomedicalAsset>>[
        _categoryColumn(l10n),
      ],
      BiomedicalPanels.analytics =>
        const <AppListTableColumn<BiomedicalAsset>>[],
      _ => const <AppListTableColumn<BiomedicalAsset>>[],
    };
  }

  AppListTableColumn<BiomedicalAsset> _assetTagColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'asset_tag',
      label: l10n.biomedicalAssetTagColumnLabel,
      sortComparator: (BiomedicalAsset left, BiomedicalAsset right) =>
          appListTableCompareText(left.displayId, right.displayId),
      cellBuilder: (_, BiomedicalAsset item) {
        return AppCopyableIdentifier(value: item.displayId);
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _equipmentColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'equipment',
      label: l10n.biomedicalEquipmentColumnLabel,
      sortComparator: (BiomedicalAsset left, BiomedicalAsset right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (_, BiomedicalAsset item) {
        return AppListItemText(
          title: item.displayTitle,
          subtitle: _dash(item.displaySubtitle, l10n),
        );
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _categoryColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'category',
      label: l10n.biomedicalCategoryColumnLabel,
      cellBuilder: (_, BiomedicalAsset item) {
        return Text(_dash(item.categoryLabel, l10n));
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _locationColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'location',
      label: l10n.biomedicalLocationColumnLabel,
      cellBuilder: (_, BiomedicalAsset item) {
        return Text(_dash(item.facilityLabel, l10n));
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _riskColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'risk',
      label: l10n.biomedicalRiskColumnLabel,
      cellBuilder: (_, BiomedicalAsset item) {
        return _statusBadge(
          _labelForCode(
            item.priority,
            fallback: l10n.biomedicalNotAvailableLabel,
          ),
          _toneForPriority(item.priority),
        );
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _statusColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'status',
      label: l10n.biomedicalStatusColumnLabel,
      alwaysVisible: true,
      cellBuilder: (_, BiomedicalAsset item) {
        return _statusBadge(
          _labelForCode(
            item.status,
            fallback: l10n.biomedicalNotAvailableLabel,
          ),
          _toneForStatus(item.status),
        );
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _ownerColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'owner',
      label: l10n.biomedicalOwnerColumnLabel,
      cellBuilder: (_, BiomedicalAsset item) {
        return Text(_dash(item.engineerLabel ?? item.facilityLabel, l10n));
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _nextActionColumn(
    AppLocalizations l10n, {
    required bool canWrite,
    required BiomedicalWorkspaceState state,
    required void Function(BiomedicalAsset asset) onOpenDetail,
  }) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'next_action',
      label: l10n.biomedicalNextActionColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, BiomedicalAsset item) {
        return _BiomedicalNextActionCell(
          asset: item,
          canWrite: canWrite,
          state: state,
          onOpenDetail: () => onOpenDetail(item),
        );
      },
    );
  }

  AppListTableColumn<BiomedicalAsset> _nextDueColumn(AppLocalizations l10n) {
    return AppListTableColumn<BiomedicalAsset>(
      id: 'next_due',
      label: l10n.biomedicalNextDueLabel,
      cellBuilder: (BuildContext context, BiomedicalAsset item) {
        return Text(
          _formatDate(context, item.nextDueAt) ??
              l10n.biomedicalNotAvailableLabel,
        );
      },
    );
  }

  static _PanelAction? _primaryActionForPanel(
    AppLocalizations l10n,
    String panel,
  ) {
    return switch (panel) {
      BiomedicalPanels.registry => _PanelAction(
        label: l10n.biomedicalRegisterAssetAction,
        icon: Icons.add_box_outlined,
        kind: _BiomedicalActionKind.asset,
      ),
      BiomedicalPanels.overview || BiomedicalPanels.workOrders => _PanelAction(
        label: l10n.biomedicalCreateWorkOrderAction,
        icon: Icons.build_outlined,
        kind: _BiomedicalActionKind.workOrder,
      ),
      BiomedicalPanels.preventive => _PanelAction(
        label: l10n.biomedicalScheduleMaintenanceAction,
        icon: Icons.event_repeat_outlined,
        kind: _BiomedicalActionKind.maintenance,
      ),
      BiomedicalPanels.compliance => _PanelAction(
        label: l10n.biomedicalRecordCalibrationAction,
        icon: Icons.speed_outlined,
        kind: _BiomedicalActionKind.calibration,
      ),
      _ => null,
    };
  }

  static IconData _panelIcon(String panel) {
    return switch (panel) {
      BiomedicalPanels.registry => Icons.medical_services_outlined,
      BiomedicalPanels.overview => Icons.dashboard_outlined,
      BiomedicalPanels.preventive => Icons.event_repeat_outlined,
      BiomedicalPanels.workOrders => Icons.build_outlined,
      BiomedicalPanels.compliance => Icons.fact_check_outlined,
      BiomedicalPanels.support => Icons.support_agent_outlined,
      BiomedicalPanels.analytics => Icons.analytics_outlined,
      _ => Icons.medical_services_outlined,
    };
  }

  static String _panelLabel(AppLocalizations l10n, String panel) {
    return switch (panel) {
      BiomedicalPanels.registry => l10n.biomedicalPanelRegistry,
      BiomedicalPanels.overview => l10n.biomedicalPanelOverview,
      BiomedicalPanels.preventive => l10n.biomedicalPanelPreventive,
      BiomedicalPanels.workOrders => l10n.biomedicalPanelWorkOrders,
      BiomedicalPanels.compliance => l10n.biomedicalPanelCompliance,
      BiomedicalPanels.support => l10n.biomedicalPanelSupport,
      BiomedicalPanels.analytics => l10n.biomedicalPanelAnalytics,
      _ => panel,
    };
  }

  void _applyQueue(
    BiomedicalWorkspaceController controller,
    BiomedicalWorkspaceState state,
    String queue,
  ) {
    for (final BiomedicalQueueSummary summary in state.workbench.queues) {
      if (summary.queue == queue) {
        final String? panel = summary.panel;
        if (panel != null &&
            panel.isNotEmpty &&
            panel != _currentPanel &&
            BiomedicalPanels.values.contains(panel)) {
          _tableColumnController.dispose();
          setState(() {
            _currentPanel = panel;
            _tableColumnController =
                AppListTableColumnVisibilityController<BiomedicalAsset>();
          });
          _updateUrlForPanel(panel);
        }
        unawaited(controller.applyQueue(summary));
        return;
      }
    }
  }

  Future<void> _openAssetDetailDialog(
    BuildContext context,
    BiomedicalAsset asset,
    bool canWrite,
    bool canPrint,
  ) async {
    ref.read(biomedicalWorkspaceControllerProvider.notifier).selectAsset(asset);
    await showAppDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
          final BiomedicalWorkspaceState dialogState =
              _biomedicalStateFromAsync(
                dialogRef.watch(biomedicalWorkspaceControllerProvider),
              ) ??
              widget.state;
          return AppDialog(
            title: Text(dialogContext.l10n.biomedicalDetailTitle),
            icon: const Icon(Icons.biotech_outlined),
            scrollable: true,
            maxWidth: 980,
            content: _BiomedicalDetailPanel(
              state: dialogState,
              canWrite: canWrite,
              canPrint: canPrint,
            ),
          );
        },
      ),
    );
  }
}

@immutable
final class _PanelAction {
  const _PanelAction({
    required this.label,
    required this.icon,
    required this.kind,
  });

  final String label;
  final IconData icon;
  final _BiomedicalActionKind kind;
}

class _BiomedicalDetailPanel extends ConsumerWidget {
  const _BiomedicalDetailPanel({
    required this.state,
    required this.canWrite,
    required this.canPrint,
  });

  final BiomedicalWorkspaceState state;
  final bool canWrite;
  final bool canPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final BiomedicalAsset? asset = state.selectedAsset;
    if (asset == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.biomedicalDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.biomedicalNoSelectionTitle,
          body: l10n.biomedicalNoSelectionBody,
          icon: Icons.medical_services_outlined,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.biomedicalDetailTitle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppPatientDetails(
              semanticLabel: l10n.biomedicalDetailTitle,
              patientName: asset.displayTitle,
              patientNumber: asset.displayId,
              patientNumberLabel: l10n.biomedicalAssetTagLabel,
              ageLabel: asset.displaySubtitle,
              showAvatar: false,
              status: AppWorkspaceStatus(
                label: _labelForCode(
                  asset.priority,
                  fallback: l10n.biomedicalNotAvailableLabel,
                ),
                tone: _toneForPriority(asset.priority),
              ),
              expandedFields: <AppWorkspacePatientContextField>[
                AppWorkspacePatientContextField(
                  label: l10n.biomedicalAssetTagLabel,
                  value: asset.displayId,
                  copyable: true,
                ),
                AppWorkspacePatientContextField(
                  label: l10n.biomedicalFacilityLabel,
                  value: _dash(asset.facilityLabel, l10n),
                ),
                AppWorkspacePatientContextField(
                  label: l10n.biomedicalCategoryLabel,
                  value: _dash(asset.categoryLabel, l10n),
                ),
                AppWorkspacePatientContextField(
                  label: l10n.biomedicalOwnerLabel,
                  value: _dash(asset.engineerLabel, l10n),
                ),
              ],
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            _DetailActions(
              state: state,
              asset: asset,
              canWrite: canWrite,
              canPrint: canPrint,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppSectionPanel(
              title: l10n.biomedicalRegistrySectionTitle,
              leadingIcon: Icons.badge_outlined,
              children: <Widget>[
                AppInfoTileGrid(
                  items: <AppInfoTileData>[
                    AppInfoTileData(
                      label: l10n.biomedicalAssetTagLabel,
                      value: asset.displayId,
                      icon: Icons.tag_outlined,
                      copyable: true,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalEquipmentLabel,
                      value: asset.effectiveEquipmentLabel,
                      icon: Icons.medical_services_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalResourceLabel,
                      value: _labelForResource(l10n, asset.resource),
                      icon: Icons.dataset_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalTargetPathLabel,
                      value: asset.targetPath,
                      icon: Icons.link_outlined,
                      copyable: true,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppSectionPanel(
              title: l10n.biomedicalReadinessSectionTitle,
              leadingIcon: Icons.health_and_safety_outlined,
              children: <Widget>[
                AppInfoTileGrid(
                  items: <AppInfoTileData>[
                    AppInfoTileData(
                      label: l10n.biomedicalStatusLabel,
                      value: _labelForCode(asset.status),
                      icon: Icons.verified_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalPriorityLabel,
                      value: _labelForCode(asset.priority),
                      icon: Icons.priority_high_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalNextDueLabel,
                      value: _formatDate(context, asset.nextDueAt),
                      icon: Icons.event_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.biomedicalLastUpdatedLabel,
                      value: _formatDateTime(context, asset.timelineAt),
                      icon: Icons.update_outlined,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            _RelatedSection(
              title: l10n.biomedicalMaintenanceSectionTitle,
              icon: Icons.build_outlined,
              statuses: <AppWorkspaceStatus>[
                AppWorkspaceStatus(
                  label: l10n.biomedicalScheduleMaintenanceAction,
                  tone: AppWorkspaceStatusTone.info,
                ),
                AppWorkspaceStatus(
                  label: l10n.biomedicalCreateWorkOrderAction,
                  tone: AppWorkspaceStatusTone.warning,
                ),
              ],
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            _RelatedSection(
              title: l10n.biomedicalComplianceSectionTitle,
              icon: Icons.fact_check_outlined,
              statuses: <AppWorkspaceStatus>[
                AppWorkspaceStatus(
                  label: l10n.biomedicalRecordCalibrationAction,
                  tone: AppWorkspaceStatusTone.info,
                ),
                AppWorkspaceStatus(
                  label: l10n.biomedicalRecordSafetyTestAction,
                  tone: AppWorkspaceStatusTone.success,
                ),
                AppWorkspaceStatus(
                  label: l10n.biomedicalLogIncidentAction,
                  tone: AppWorkspaceStatusTone.warning,
                ),
              ],
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            _RelatedSection(
              title: l10n.biomedicalLifecycleSectionTitle,
              icon: Icons.sync_alt_outlined,
              statuses: <AppWorkspaceStatus>[
                AppWorkspaceStatus(
                  label: l10n.biomedicalTransferLocationAction,
                  tone: AppWorkspaceStatusTone.info,
                ),
                AppWorkspaceStatus(
                  label: l10n.biomedicalDisposeTransferAction,
                  tone: AppWorkspaceStatusTone.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailActions extends ConsumerWidget {
  const _DetailActions({
    required this.state,
    required this.asset,
    required this.canWrite,
    required this.canPrint,
  });

  final BiomedicalWorkspaceState state;
  final BiomedicalAsset asset;
  final bool canWrite;
  final bool canPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      extraActions: <Widget>[
        if (canWrite && asset.isRegistryAsset)
          AppButton.secondary(
            label: l10n.biomedicalEditAssetAction,
            leadingIcon: Icons.edit_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.asset,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalTransferLocationAction,
            leadingIcon: Icons.location_on_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.transfer,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalScheduleMaintenanceAction,
            leadingIcon: Icons.event_repeat_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.maintenance,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: asset.resource == BiomedicalResources.workOrders
                ? l10n.biomedicalUpdateWorkOrderAction
                : l10n.biomedicalCreateWorkOrderAction,
            leadingIcon: Icons.build_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.workOrder,
                asset: asset,
              ),
            ),
          ),
        if (canWrite && asset.resource == BiomedicalResources.workOrders)
          AppButton.secondary(
            label: l10n.biomedicalStartWorkOrderAction,
            leadingIcon: Icons.play_arrow_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.startWorkOrder,
                asset: asset,
              ),
            ),
          ),
        if (canWrite && asset.resource == BiomedicalResources.workOrders)
          AppButton.secondary(
            label: l10n.biomedicalReturnToServiceAction,
            leadingIcon: Icons.verified_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.returnToService,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalRecordCalibrationAction,
            leadingIcon: Icons.speed_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.calibration,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalRecordSafetyTestAction,
            leadingIcon: Icons.fact_check_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.safety,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalReportDowntimeAction,
            leadingIcon: Icons.power_settings_new_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.downtime,
                asset: asset,
              ),
            ),
          ),
        if (canWrite && asset.resource == BiomedicalResources.downtimeLogs)
          AppButton.secondary(
            label: l10n.biomedicalCloseDowntimeAction,
            leadingIcon: Icons.done_all_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.closeDowntime,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalLogIncidentAction,
            leadingIcon: Icons.warning_amber_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.incident,
                asset: asset,
              ),
            ),
          ),
        if (canWrite && asset.resource == BiomedicalResources.recallNotices)
          AppButton.secondary(
            label: l10n.biomedicalAcknowledgeRecallAction,
            leadingIcon: Icons.campaign_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.recall,
                asset: asset,
              ),
            ),
          ),
        if (canWrite)
          AppButton.secondary(
            label: l10n.biomedicalDisposeTransferAction,
            leadingIcon: Icons.move_down_outlined,
            isLoading: state.isMutating,
            onPressed: () => unawaited(
              _openActionDialog(
                context,
                ref,
                state,
                _BiomedicalActionKind.disposal,
                asset: asset,
              ),
            ),
          ),
        AppReportActionButton.preview(
          label: l10n.biomedicalPrintReportAction,
          onPressed: () => unawaited(
            _openActionDialog(
              context,
              ref,
              state,
              _BiomedicalActionKind.report,
              asset: asset,
            ),
          ),
        ),
        AppReportActionButton.print(
          label: l10n.reportsPrintAction,
          enabled: canPrint,
          onPressed: canPrint
              ? () => unawaited(_printBiomedicalReport(context, ref, asset))
              : null,
        ),
      ],
    );
  }
}

Future<void> _printBiomedicalReport(
  BuildContext context,
  WidgetRef ref,
  BiomedicalAsset asset,
) async {
  final AppLocalizations l10n = context.l10n;
  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: '${l10n.biomedicalPrintReportDialogTitle} - ${asset.displayId}',
    subtitle: asset.displayTitle,
    contextReference: PrintFormContextReference(
      label: l10n.biomedicalAssetTagLabel,
      value: asset.displayId,
    ),
    bodyHtml: _biomedicalReportHtml(context, asset),
    footerNote: l10n.biomedicalPrintReportBody,
  );
}

String _biomedicalReportHtml(BuildContext context, BiomedicalAsset asset) {
  final AppLocalizations l10n = context.l10n;
  final String registryHtml =
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.biomedicalAssetTagLabel,
          value: asset.displayId,
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalEquipmentLabel,
          value: asset.displayTitle,
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalCategoryLabel,
          value: _dash(asset.categoryLabel, l10n),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalStatusLabel,
          value: _labelForCode(
            asset.status,
            fallback: l10n.biomedicalNotAvailableLabel,
          ),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalPriorityLabel,
          value: _labelForCode(
            asset.priority,
            fallback: l10n.biomedicalNotAvailableLabel,
          ),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalFacilityLabel,
          value: _dash(asset.facilityLabel, l10n),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalOwnerLabel,
          value: _dash(asset.engineerLabel, l10n),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalNextDueLabel,
          value:
              _formatDate(context, asset.nextDueAt) ??
              l10n.biomedicalNotAvailableLabel,
        ),
      ]);
  final String lifecycleHtml =
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.biomedicalResourceLabel,
          value: _labelForResource(l10n, asset.resource),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalNextActionColumnLabel,
          value: _nextActionLabel(l10n, asset),
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalLastUpdatedLabel,
          value:
              _formatDateTime(context, asset.timelineAt) ??
              l10n.biomedicalNotAvailableLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.biomedicalTargetPathLabel,
          value: _dash(asset.targetPath, l10n),
        ),
      ]);

  return <String>[
    PrintFormTemplate.section(
      title: l10n.biomedicalRegistrySectionTitle,
      bodyHtml: registryHtml,
    ),
    PrintFormTemplate.section(
      title: l10n.biomedicalLifecycleSectionTitle,
      bodyHtml: lifecycleHtml,
    ),
  ].join();
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({
    required this.title,
    required this.icon,
    required this.statuses,
  });

  final String title;
  final IconData icon;
  final List<AppWorkspaceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: icon,
      children: <Widget>[
        Wrap(
          spacing: Theme.of(context).spacing.xs,
          runSpacing: Theme.of(context).spacing.xs,
          children: <Widget>[
            for (final AppWorkspaceStatus status in statuses)
              AppWorkspaceStatusBadge(status: status),
          ],
        ),
      ],
    );
  }
}


String? _mobilePanelFieldLabel(
  BuildContext context,
  String panel,
  BiomedicalAsset asset,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (panel) {
    BiomedicalPanels.registry ||
    BiomedicalPanels.support ||
    BiomedicalPanels.analytics => _dash(asset.facilityLabel, l10n),
    BiomedicalPanels.overview || BiomedicalPanels.workOrders => _labelForCode(
      asset.priority,
      fallback: l10n.biomedicalNotAvailableLabel,
    ),
    BiomedicalPanels.preventive || BiomedicalPanels.compliance =>
      _formatDate(context, asset.nextDueAt) ?? l10n.biomedicalNotAvailableLabel,
    _ => null,
  };
}

IconData _mobilePanelFieldIcon(String panel) {
  return switch (panel) {
    BiomedicalPanels.registry ||
    BiomedicalPanels.support ||
    BiomedicalPanels.analytics => Icons.location_on_outlined,
    BiomedicalPanels.overview ||
    BiomedicalPanels.workOrders => Icons.warning_amber_outlined,
    BiomedicalPanels.preventive ||
    BiomedicalPanels.compliance => Icons.event_outlined,
    _ => Icons.info_outline,
  };
}

class _BiomedicalNextActionCell extends ConsumerWidget {
  const _BiomedicalNextActionCell({
    required this.asset,
    required this.canWrite,
    required this.state,
    required this.onOpenDetail,
    this.compact = false,
  });

  final BiomedicalAsset asset;
  final bool canWrite;
  final BiomedicalWorkspaceState state;
  final VoidCallback onOpenDetail;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String label = _nextActionLabel(l10n, asset);
    final _BiomedicalActionKind? actionKind = _nextActionKindForAsset(asset);
    final bool hasWriteAction = actionKind != null && canWrite;

    void onPressed() {
      if (hasWriteAction) {
        unawaited(
          _openActionDialog(context, ref, state, actionKind, asset: asset),
        );
        return;
      }
      onOpenDetail();
    }

    if (compact) {
      return _BiomedicalCompactNextActionButton(
        label: label,
        onPressed: onPressed,
      );
    }

    if (hasWriteAction) {
      return AppAccessActionGate(
        requirement: _BiomedicalWorkspaceContentState._writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppButton.tertiary(
            label: label,
            enabled: isAllowed && !state.isMutating,
            onPressed: isAllowed && !state.isMutating ? onPressed : null,
          );
        },
      );
    }

    return AppButton.tertiary(
      label: label,
      enabled: !state.isMutating,
      onPressed: !state.isMutating ? onPressed : null,
    );
  }
}

class _BiomedicalCompactNextActionButton extends StatelessWidget {
  const _BiomedicalCompactNextActionButton({
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.arrow_forward_outlined,
                    size: 14,
                    color: primaryColor,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
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
    );
  }
}

enum _BiomedicalActionKind {
  asset,
  transfer,
  maintenance,
  workOrder,
  startWorkOrder,
  returnToService,
  calibration,
  safety,
  downtime,
  closeDowntime,
  incident,
  recall,
  disposal,
  fault,
  report,
}

BiomedicalWorkspaceState? _biomedicalStateFromAsync(
  AsyncValue<Result<BiomedicalWorkspaceState>> asyncState,
) {
  return switch (asyncState.asData?.value) {
    ResultSuccess<BiomedicalWorkspaceState>(value: final value) => value,
    _ => null,
  };
}

Future<void> _openActionDialog(
  BuildContext context,
  WidgetRef ref,
  BiomedicalWorkspaceState state,
  _BiomedicalActionKind kind, {
  BiomedicalAsset? asset,
}) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BiomedicalActionDialog(
      state: state,
      kind: kind,
      asset: asset,
      tenantId: policy.tenantId,
    ),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.biomedicalSavedMessage)),
    );
  }
}

class _BiomedicalActionDialog extends ConsumerStatefulWidget {
  const _BiomedicalActionDialog({
    required this.state,
    required this.kind,
    required this.tenantId,
    this.asset,
  });

  final BiomedicalWorkspaceState state;
  final _BiomedicalActionKind kind;
  final BiomedicalAsset? asset;
  final String? tenantId;

  @override
  ConsumerState<_BiomedicalActionDialog> createState() =>
      _BiomedicalActionDialogState();
}

class _BiomedicalActionDialogState
    extends ConsumerState<_BiomedicalActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _serialController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _planNameController;
  late final TextEditingController _maintenanceTypeController;
  late final TextEditingController _frequencyDaysController;
  late final TextEditingController _dateOneController;
  late final TextEditingController _dateTwoController;
  late final TextEditingController _resultController;
  late final TextEditingController _reasonController;
  late final TextEditingController _reportedNameController;
  bool _patientSafetyRisk = false;
  String? _selectedEquipmentId;
  String? _selectedCategoryId;
  String? _selectedFacilityId;
  String? _selectedRoomId;
  String? _selectedEngineerId;
  String? _selectedStatus;
  String? _selectedPriority;
  String? _selectedSeverity;

  @override
  void initState() {
    super.initState();
    final BiomedicalAsset? asset = widget.asset;
    _nameController = TextEditingController(text: asset?.displayTitle ?? '');
    _codeController = TextEditingController(text: asset?.subtitle ?? '');
    _serialController = TextEditingController();
    _titleController = TextEditingController(text: asset?.title ?? '');
    _descriptionController = TextEditingController(text: asset?.subtitle ?? '');
    _notesController = TextEditingController();
    _planNameController = TextEditingController();
    _maintenanceTypeController = TextEditingController();
    _frequencyDaysController = TextEditingController();
    _dateOneController = TextEditingController(text: _defaultDateTimeText());
    _dateTwoController = TextEditingController();
    _resultController = TextEditingController();
    _reasonController = TextEditingController();
    _reportedNameController = TextEditingController();
    _selectedEquipmentId = asset?.effectiveEquipmentId;
    _selectedCategoryId = asset?.categoryId;
    _selectedFacilityId = asset?.facilityId;
    _selectedStatus = asset?.status;
    _selectedPriority = asset?.priority;
    _selectedSeverity = asset?.priority;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _serialController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _planNameController.dispose();
    _maintenanceTypeController.dispose();
    _frequencyDaysController.dispose();
    _dateOneController.dispose();
    _dateTwoController.dispose();
    _resultController.dispose();
    _reasonController.dispose();
    _reportedNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isReport = widget.kind == _BiomedicalActionKind.report;

    return AppDialog(
      title: Text(_dialogTitle(l10n)),
      icon: Icon(_dialogIcon()),
      scrollable: true,
      maxWidth: isReport ? 760 : 640,
      content: isReport ? _buildReportPreview(context) : _buildForm(context),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (!isReport)
          AppButton.primary(
            label: _submitLabel(l10n),
            leadingIcon: Icons.check_outlined,
            isLoading: widget.state.isMutating,
            onPressed: widget.state.isMutating ? null : _submit,
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BiomedicalLookupData lookups = widget.state.workbench.lookups;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        if (_usesEquipmentPicker)
          AppSelectField<String>.searchable(
            value: _selectedEquipmentId,
            labelText: l10n.biomedicalEquipmentLabel,
            options: _selectOptions(lookups.equipment),
            isRequired: true,
            validator: AppValidators.requiredValue<String>(
              l10n.biomedicalFieldRequiredLabel(l10n.biomedicalEquipmentLabel),
            ),
            onChanged: (String? value) {
              setState(() => _selectedEquipmentId = value);
            },
          ),
        if (_showsAssetFields) ...<Widget>[
          AppTextField(
            controller: _nameController,
            labelText: l10n.biomedicalAssetNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.biomedicalFieldRequiredLabel(l10n.biomedicalAssetNameLabel),
            ),
          ),
          AppTextField(
            controller: _codeController,
            labelText: l10n.biomedicalAssetCodeLabel,
          ),
          AppTextField(
            controller: _serialController,
            labelText: l10n.biomedicalSerialNumberLabel,
          ),
          AppSelectField<String>.searchable(
            value: _selectedCategoryId,
            labelText: l10n.biomedicalCategoryLabel,
            options: _selectOptions(lookups.categories),
            onChanged: (String? value) {
              setState(() => _selectedCategoryId = value);
            },
          ),
        ],
        if (_usesFacility)
          AppSelectField<String>.searchable(
            value: _selectedFacilityId,
            labelText: l10n.biomedicalFacilityLabel,
            options: _selectOptions(lookups.facilities),
            onChanged: (String? value) {
              setState(() => _selectedFacilityId = value);
            },
          ),
        if (_usesRoom)
          AppSelectField<String>.searchable(
            value: _selectedRoomId,
            labelText: l10n.biomedicalRoomLabel,
            options: _selectOptions(lookups.rooms),
            onChanged: (String? value) {
              setState(() => _selectedRoomId = value);
            },
          ),
        if (_usesStatus)
          AppSelectField<String>(
            value: _selectedStatus,
            labelText: l10n.biomedicalStatusLabel,
            options: _selectOptions(
              lookups.statuses,
              fallbackValues: _fallbackStatuses,
            ),
            onChanged: (String? value) {
              setState(() => _selectedStatus = value);
            },
          ),
        if (_usesPriority)
          AppSelectField<String>(
            value: _selectedPriority,
            labelText: l10n.biomedicalPriorityLabel,
            options: _selectOptions(
              lookups.priorities,
              fallbackValues: _fallbackPriorities,
            ),
            onChanged: (String? value) {
              setState(() => _selectedPriority = value);
            },
          ),
        if (_usesSeverity)
          AppSelectField<String>(
            value: _selectedSeverity,
            labelText: l10n.biomedicalSeverityLabel,
            options: _valuesToOptions(_fallbackSeverities),
            onChanged: (String? value) {
              setState(() => _selectedSeverity = value);
            },
          ),
        if (_usesEngineer)
          AppSelectField<String>.searchable(
            value: _selectedEngineerId,
            labelText: l10n.biomedicalEngineerLabel,
            options: _selectOptions(lookups.engineers),
            onChanged: (String? value) {
              setState(() => _selectedEngineerId = value);
            },
          ),
        if (_showsWorkOrderTitle)
          AppTextField(
            controller: _titleController,
            labelText: l10n.biomedicalWorkOrderTitleLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.biomedicalFieldRequiredLabel(
                l10n.biomedicalWorkOrderTitleLabel,
              ),
            ),
          ),
        if (_showsPlanFields) ...<Widget>[
          AppTextField(
            controller: _planNameController,
            labelText: l10n.biomedicalPlanNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.biomedicalFieldRequiredLabel(l10n.biomedicalPlanNameLabel),
            ),
          ),
          AppTextField(
            controller: _maintenanceTypeController,
            labelText: l10n.biomedicalMaintenanceTypeLabel,
          ),
          AppTextField(
            controller: _frequencyDaysController,
            labelText: l10n.biomedicalFrequencyDaysLabel,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
        if (_usesDateOne)
          AppTextField(
            controller: _dateOneController,
            labelText: _dateOneLabel(l10n),
            hintText: l10n.biomedicalDateTimeHint,
          ),
        if (_usesDateTwo)
          AppTextField(
            controller: _dateTwoController,
            labelText: _dateTwoLabel(l10n),
            hintText: l10n.biomedicalDateTimeHint,
          ),
        if (_showsResult)
          AppTextField(
            controller: _resultController,
            labelText: l10n.biomedicalResultLabel,
          ),
        if (_showsReason)
          AppTextField(
            controller: _reasonController,
            labelText: l10n.biomedicalReasonLabel,
            minLines: 2,
            maxLines: 4,
          ),
        if (widget.kind == _BiomedicalActionKind.fault)
          AppTextField(
            controller: _reportedNameController,
            labelText: l10n.biomedicalReportedEquipmentNameLabel,
          ),
        if (_showsDescription)
          AppTextField(
            controller: _descriptionController,
            labelText: l10n.biomedicalDescriptionLabel,
            minLines: 3,
            maxLines: 5,
          ),
        if (_showsNotes)
          AppTextField(
            controller: _notesController,
            labelText: l10n.biomedicalNotesLabel,
            minLines: 2,
            maxLines: 4,
          ),
        if (widget.kind == _BiomedicalActionKind.fault)
          AppCheckboxField(
            title: l10n.biomedicalPatientSafetyRiskLabel,
            value: _patientSafetyRisk,
            onChanged: (bool value) {
              setState(() => _patientSafetyRisk = value);
            },
          ),
      ],
    );
  }

  Widget _buildReportPreview(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BiomedicalAsset? asset = widget.asset;
    return AppReportPreviewPanel(
      title: l10n.biomedicalReportsSectionTitle,
      selectable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppReportSummaryGrid(
            records: <AppReportSummaryItem>[
              AppReportSummaryItem(
                label: l10n.biomedicalAssetTagLabel,
                value: asset?.displayId ?? l10n.biomedicalNotAvailableLabel,
                icon: Icons.tag_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.biomedicalStatusLabel,
                value: _labelForCode(
                  asset?.status,
                  fallback: l10n.biomedicalNotAvailableLabel,
                ),
                icon: Icons.verified_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.biomedicalPriorityLabel,
                value: _labelForCode(
                  asset?.priority,
                  fallback: l10n.biomedicalNotAvailableLabel,
                ),
                icon: Icons.priority_high_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.biomedicalFacilityLabel,
                value: asset?.facilityLabel ?? l10n.biomedicalNotAvailableLabel,
                icon: Icons.domain_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Text(
            asset?.displayTitle ?? l10n.biomedicalNotAvailableLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          Text(l10n.biomedicalPrintReportBody),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final BiomedicalWorkspaceController controller = ref.read(
      biomedicalWorkspaceControllerProvider.notifier,
    );
    final Map<String, Object?> payload = _payload();
    final AppFailure? failure = await _submitPayload(controller, payload);
    if (!mounted) {
      return;
    }
    if (failure != null) {
      _showFailureIfNeeded(context, failure);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<AppFailure?> _submitPayload(
    BiomedicalWorkspaceController controller,
    Map<String, Object?> payload,
  ) {
    final BiomedicalAsset? asset = widget.asset;
    return switch (widget.kind) {
      _BiomedicalActionKind.asset => controller.saveAsset(
        payload,
        existing: asset?.isRegistryAsset == true ? asset : null,
      ),
      _BiomedicalActionKind.transfer => controller.transferLocation(payload),
      _BiomedicalActionKind.maintenance => controller.scheduleMaintenance(
        payload,
      ),
      _BiomedicalActionKind.workOrder => controller.saveWorkOrder(
        payload,
        existing: asset,
      ),
      _BiomedicalActionKind.startWorkOrder => controller.startWorkOrder(
        asset!,
        payload,
      ),
      _BiomedicalActionKind.returnToService => controller.returnToService(
        asset!,
        payload,
      ),
      _BiomedicalActionKind.calibration => controller.recordCalibration(
        payload,
      ),
      _BiomedicalActionKind.safety => controller.recordSafetyTest(payload),
      _BiomedicalActionKind.downtime => controller.reportDowntime(payload),
      _BiomedicalActionKind.closeDowntime => controller.closeDowntime(
        asset!,
        payload,
      ),
      _BiomedicalActionKind.incident => controller.logIncident(payload),
      _BiomedicalActionKind.recall => controller.acknowledgeRecall(
        asset!,
        payload,
      ),
      _BiomedicalActionKind.disposal => controller.disposeOrTransfer(payload),
      _BiomedicalActionKind.fault => controller.createFaultReport(payload),
      _BiomedicalActionKind.report => Future<AppFailure?>.value(),
    };
  }

  Map<String, Object?> _payload() {
    final String? tenantId = widget.tenantId;
    final String? equipmentId = _selectedEquipmentId;
    return <String, Object?>{
      'tenant_id': ?tenantId,
      if (_showsAssetFields) ...<String, Object?>{
        'equipment_name': _nameController.text.trim(),
        'equipment_code': _codeController.text.trim(),
        'serial_number': _serialController.text.trim(),
        'equipment_category_id': _selectedCategoryId,
        'category_id': _selectedCategoryId,
        'facility_id': _selectedFacilityId,
        'status': _selectedStatus,
        'criticality_level': _selectedPriority,
      },
      if (_usesEquipmentPicker) 'equipment_registry_id': equipmentId,
      if (_usesEquipmentPicker) 'equipment_id': equipmentId,
      if (_usesFacility) 'facility_id': _selectedFacilityId,
      if (_usesRoom) 'room_id': _selectedRoomId,
      if (_usesStatus) 'status': _selectedStatus,
      if (_usesPriority) 'priority': _selectedPriority,
      if (_usesSeverity) 'severity': _selectedSeverity,
      if (_usesEngineer) 'assigned_engineer_user_id': _selectedEngineerId,
      if (_showsWorkOrderTitle) 'title': _titleController.text.trim(),
      if (_showsPlanFields) ...<String, Object?>{
        'plan_name': _planNameController.text.trim(),
        'maintenance_type': _maintenanceTypeController.text.trim(),
        'frequency_days': int.tryParse(_frequencyDaysController.text.trim()),
        'is_active': true,
      },
      if (_usesDateOne)
        _dateOnePayloadKey: _normalizedDate(_dateOneController.text),
      if (_usesDateTwo)
        _dateTwoPayloadKey: _normalizedDate(_dateTwoController.text),
      if (_showsResult) 'result': _resultController.text.trim(),
      if (_showsReason) 'reason': _reasonController.text.trim(),
      if (_showsDescription) 'description': _descriptionController.text.trim(),
      if (_showsNotes) 'notes': _notesController.text.trim(),
      if (widget.kind == _BiomedicalActionKind.workOrder)
        'issue_source': _reasonController.text.trim(),
      if (widget.kind == _BiomedicalActionKind.returnToService)
        'verification_evidence_manifest': <Map<String, Object?>>[
          <String, Object?>{'kind': 'frontend_attestation'},
        ],
      if (widget.kind == _BiomedicalActionKind.fault) ...<String, Object?>{
        'equipment_id': widget.asset?.effectiveEquipmentId,
        'reported_equipment_name': _reportedNameController.text.trim(),
        'source_scope': 'biomedical',
        'source_route': '/biomedical',
        'symptoms': _reasonController.text.trim(),
        'patient_safety_risk': _patientSafetyRisk,
      },
      if (widget.kind == _BiomedicalActionKind.recall)
        'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
      if (widget.kind == _BiomedicalActionKind.disposal)
        'transfer_type': _reasonController.text.trim(),
    };
  }

  String get _dateOnePayloadKey {
    return switch (widget.kind) {
      _BiomedicalActionKind.maintenance => 'next_due_at',
      _BiomedicalActionKind.calibration => 'calibrated_at',
      _BiomedicalActionKind.safety => 'tested_at',
      _BiomedicalActionKind.downtime => 'started_at',
      _BiomedicalActionKind.closeDowntime => 'ended_at',
      _BiomedicalActionKind.startWorkOrder => 'started_at',
      _BiomedicalActionKind.disposal => 'effective_at',
      _ => 'recorded_at',
    };
  }

  String get _dateTwoPayloadKey {
    return switch (widget.kind) {
      _BiomedicalActionKind.calibration => 'next_due_at',
      _BiomedicalActionKind.safety => 'next_due_at',
      _ => 'ended_at',
    };
  }

  bool get _showsAssetFields => widget.kind == _BiomedicalActionKind.asset;
  bool get _usesEquipmentPicker {
    if (widget.kind == _BiomedicalActionKind.workOrder &&
        widget.asset?.resource == BiomedicalResources.workOrders) {
      return false;
    }
    return switch (widget.kind) {
      _BiomedicalActionKind.transfer ||
      _BiomedicalActionKind.maintenance ||
      _BiomedicalActionKind.workOrder ||
      _BiomedicalActionKind.calibration ||
      _BiomedicalActionKind.safety ||
      _BiomedicalActionKind.downtime ||
      _BiomedicalActionKind.incident ||
      _BiomedicalActionKind.disposal => true,
      _ => false,
    };
  }

  bool get _usesFacility =>
      widget.kind == _BiomedicalActionKind.asset ||
      widget.kind == _BiomedicalActionKind.transfer ||
      widget.kind == _BiomedicalActionKind.fault;
  bool get _usesRoom =>
      widget.kind == _BiomedicalActionKind.transfer ||
      widget.kind == _BiomedicalActionKind.fault;
  bool get _usesStatus =>
      widget.kind == _BiomedicalActionKind.asset ||
      widget.kind == _BiomedicalActionKind.workOrder ||
      widget.kind == _BiomedicalActionKind.recall;
  bool get _usesPriority =>
      widget.kind == _BiomedicalActionKind.asset ||
      widget.kind == _BiomedicalActionKind.workOrder ||
      widget.kind == _BiomedicalActionKind.fault;
  bool get _usesSeverity =>
      widget.kind == _BiomedicalActionKind.incident ||
      widget.kind == _BiomedicalActionKind.fault;
  bool get _usesEngineer => widget.kind == _BiomedicalActionKind.workOrder;
  bool get _showsWorkOrderTitle =>
      widget.kind == _BiomedicalActionKind.workOrder;
  bool get _showsPlanFields => widget.kind == _BiomedicalActionKind.maintenance;
  bool get _usesDateOne =>
      widget.kind != _BiomedicalActionKind.asset &&
      widget.kind != _BiomedicalActionKind.workOrder &&
      widget.kind != _BiomedicalActionKind.fault &&
      widget.kind != _BiomedicalActionKind.incident &&
      widget.kind != _BiomedicalActionKind.recall &&
      widget.kind != _BiomedicalActionKind.report;
  bool get _usesDateTwo =>
      widget.kind == _BiomedicalActionKind.calibration ||
      widget.kind == _BiomedicalActionKind.safety;
  bool get _showsResult =>
      widget.kind == _BiomedicalActionKind.calibration ||
      widget.kind == _BiomedicalActionKind.safety;
  bool get _showsReason =>
      widget.kind == _BiomedicalActionKind.workOrder ||
      widget.kind == _BiomedicalActionKind.downtime ||
      widget.kind == _BiomedicalActionKind.closeDowntime ||
      widget.kind == _BiomedicalActionKind.incident ||
      widget.kind == _BiomedicalActionKind.disposal ||
      widget.kind == _BiomedicalActionKind.fault;
  bool get _showsDescription =>
      widget.kind == _BiomedicalActionKind.workOrder ||
      widget.kind == _BiomedicalActionKind.incident ||
      widget.kind == _BiomedicalActionKind.fault ||
      widget.kind == _BiomedicalActionKind.disposal;
  bool get _showsNotes =>
      widget.kind == _BiomedicalActionKind.transfer ||
      widget.kind == _BiomedicalActionKind.maintenance ||
      widget.kind == _BiomedicalActionKind.startWorkOrder ||
      widget.kind == _BiomedicalActionKind.returnToService ||
      widget.kind == _BiomedicalActionKind.calibration ||
      widget.kind == _BiomedicalActionKind.safety ||
      widget.kind == _BiomedicalActionKind.closeDowntime ||
      widget.kind == _BiomedicalActionKind.recall;

  String _dialogTitle(AppLocalizations l10n) {
    return switch (widget.kind) {
      _BiomedicalActionKind.asset =>
        widget.asset == null
            ? l10n.biomedicalRegisterAssetDialogTitle
            : l10n.biomedicalEditAssetDialogTitle,
      _BiomedicalActionKind.transfer =>
        l10n.biomedicalTransferLocationDialogTitle,
      _BiomedicalActionKind.maintenance =>
        l10n.biomedicalScheduleMaintenanceDialogTitle,
      _BiomedicalActionKind.workOrder =>
        widget.asset?.resource == BiomedicalResources.workOrders
            ? l10n.biomedicalUpdateWorkOrderDialogTitle
            : l10n.biomedicalWorkOrderDialogTitle,
      _BiomedicalActionKind.startWorkOrder =>
        l10n.biomedicalStartWorkOrderDialogTitle,
      _BiomedicalActionKind.returnToService =>
        l10n.biomedicalReturnToServiceDialogTitle,
      _BiomedicalActionKind.calibration =>
        l10n.biomedicalCalibrationDialogTitle,
      _BiomedicalActionKind.safety => l10n.biomedicalSafetyTestDialogTitle,
      _BiomedicalActionKind.downtime => l10n.biomedicalDowntimeDialogTitle,
      _BiomedicalActionKind.closeDowntime =>
        l10n.biomedicalCloseDowntimeDialogTitle,
      _BiomedicalActionKind.incident => l10n.biomedicalIncidentDialogTitle,
      _BiomedicalActionKind.recall => l10n.biomedicalRecallDialogTitle,
      _BiomedicalActionKind.disposal => l10n.biomedicalDisposalDialogTitle,
      _BiomedicalActionKind.fault => l10n.biomedicalFaultDialogTitle,
      _BiomedicalActionKind.report => l10n.biomedicalPrintReportDialogTitle,
    };
  }

  String _submitLabel(AppLocalizations l10n) {
    return switch (widget.kind) {
      _BiomedicalActionKind.asset =>
        widget.asset == null
            ? l10n.biomedicalCreateAction
            : l10n.biomedicalSaveAction,
      _ => l10n.biomedicalSubmitAction,
    };
  }

  String _dateOneLabel(AppLocalizations l10n) {
    return switch (widget.kind) {
      _BiomedicalActionKind.maintenance => l10n.biomedicalNextDueAtLabel,
      _BiomedicalActionKind.calibration => l10n.biomedicalCalibratedAtLabel,
      _BiomedicalActionKind.safety => l10n.biomedicalTestedAtLabel,
      _BiomedicalActionKind.downtime => l10n.biomedicalDowntimeStartedAtLabel,
      _BiomedicalActionKind.closeDowntime =>
        l10n.biomedicalDowntimeEndedAtLabel,
      _BiomedicalActionKind.startWorkOrder => l10n.biomedicalStartedAtLabel,
      _BiomedicalActionKind.disposal => l10n.biomedicalEffectiveAtLabel,
      _ => l10n.biomedicalRecordedAtLabel,
    };
  }

  String _dateTwoLabel(AppLocalizations l10n) {
    return switch (widget.kind) {
      _BiomedicalActionKind.calibration => l10n.biomedicalNextDueAtLabel,
      _BiomedicalActionKind.safety => l10n.biomedicalNextDueAtLabel,
      _ => l10n.biomedicalDowntimeEndedAtLabel,
    };
  }

  IconData _dialogIcon() {
    return switch (widget.kind) {
      _BiomedicalActionKind.asset => Icons.medical_services_outlined,
      _BiomedicalActionKind.transfer => Icons.location_on_outlined,
      _BiomedicalActionKind.maintenance => Icons.event_repeat_outlined,
      _BiomedicalActionKind.workOrder => Icons.build_outlined,
      _BiomedicalActionKind.startWorkOrder => Icons.play_arrow_outlined,
      _BiomedicalActionKind.returnToService => Icons.verified_outlined,
      _BiomedicalActionKind.calibration => Icons.speed_outlined,
      _BiomedicalActionKind.safety => Icons.fact_check_outlined,
      _BiomedicalActionKind.downtime => Icons.power_settings_new_outlined,
      _BiomedicalActionKind.closeDowntime => Icons.done_all_outlined,
      _BiomedicalActionKind.incident => Icons.warning_amber_outlined,
      _BiomedicalActionKind.recall => Icons.campaign_outlined,
      _BiomedicalActionKind.disposal => Icons.move_down_outlined,
      _BiomedicalActionKind.fault => Icons.report_problem_outlined,
      _BiomedicalActionKind.report => Icons.description_outlined,
    };
  }
}

const String _statusFilterKey = 'status';
const String _priorityFilterKey = 'priority';
const String _facilityFilterKey = 'facility';
const String _datePresetFilterKey = 'date_preset';

const List<String> _fallbackStatuses = <String>[
  'ACTIVE',
  'INACTIVE',
  'OPEN',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'RETURNED_TO_SERVICE',
];

const List<String> _fallbackPriorities = <String>[
  'LOW',
  'NORMAL',
  'HIGH',
  'CRITICAL',
];

const List<String> _fallbackSeverities = <String>[
  'LOW',
  'MEDIUM',
  'HIGH',
  'CRITICAL',
];

List<AppSearchBarFilterChoice> _datePresetChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: BiomedicalDatePresets.today,
      label: l10n.biomedicalDatePresetToday,
    ),
    AppSearchBarFilterChoice(
      value: BiomedicalDatePresets.next7Days,
      label: l10n.biomedicalDatePresetNext7Days,
    ),
    AppSearchBarFilterChoice(
      value: BiomedicalDatePresets.overdue,
      label: l10n.biomedicalDatePresetOverdue,
    ),
    AppSearchBarFilterChoice(
      value: BiomedicalDatePresets.thisMonth,
      label: l10n.biomedicalDatePresetThisMonth,
    ),
  ];
}

AppSearchBarFilterValue _filterValue(BiomedicalWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.status != null) _statusFilterKey: query.status!,
      if (query.priority != null) _priorityFilterKey: query.priority!,
      if (query.facilityId != null) _facilityFilterKey: query.facilityId!,
      if (query.datePreset != null) _datePresetFilterKey: query.datePreset!,
    },
  );
}

List<AppSearchBarFilterChoice> _lookupChoices(
  List<BiomedicalLookupOption> options, {
  List<String> fallbackValues = const <String>[],
}) {
  if (options.isNotEmpty) {
    return options
        .map(
          (BiomedicalLookupOption option) => AppSearchBarFilterChoice(
            value: option.id,
            label: option.displayLabel,
          ),
        )
        .toList(growable: false);
  }

  return fallbackValues
      .map(
        (String value) =>
            AppSearchBarFilterChoice(value: value, label: _labelForCode(value)),
      )
      .toList(growable: false);
}

List<AppSelectOption<String>> _selectOptions(
  List<BiomedicalLookupOption> options, {
  List<String> fallbackValues = const <String>[],
}) {
  if (options.isNotEmpty) {
    return options
        .map(
          (BiomedicalLookupOption option) => AppSelectOption<String>(
            value: option.id,
            label: option.displayLabel,
          ),
        )
        .toList(growable: false);
  }
  return _valuesToOptions(fallbackValues);
}

List<AppSelectOption<String>> _valuesToOptions(List<String> values) {
  return values
      .map(
        (String value) =>
            AppSelectOption<String>(value: value, label: _labelForCode(value)),
      )
      .toList(growable: false);
}

AppWorkspaceStatusBadge _statusBadge(
  String label,
  AppWorkspaceStatusTone tone,
) {
  return AppWorkspaceStatusBadge(
    status: AppWorkspaceStatus(label: label, tone: tone),
  );
}

AppWorkspaceStatusTone _toneForStatus(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return switch (normalized) {
    'ACTIVE' ||
    'COMPLETED' ||
    'RETURNED_TO_SERVICE' ||
    'PASS' => AppWorkspaceStatusTone.success,
    'OPEN' || 'IN_PROGRESS' || 'PENDING' => AppWorkspaceStatusTone.info,
    'OVERDUE' ||
    'DUE' ||
    'RECALL' ||
    'WARNING' => AppWorkspaceStatusTone.warning,
    'INACTIVE' ||
    'CANCELLED' ||
    'FAILED' ||
    'DOWN' ||
    'CRITICAL' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _toneForPriority(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return switch (normalized) {
    'CRITICAL' || 'HIGH' => AppWorkspaceStatusTone.error,
    'MEDIUM' || 'NORMAL' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _nextActionLabel(AppLocalizations l10n, BiomedicalAsset asset) {
  if (asset.resource == BiomedicalResources.maintenancePlans) {
    return l10n.biomedicalNextActionMaintain;
  }
  if (asset.resource == BiomedicalResources.calibrationLogs ||
      asset.resource == BiomedicalResources.safetyTestLogs) {
    return l10n.biomedicalNextActionCalibrate;
  }
  if (asset.resource == BiomedicalResources.downtimeLogs ||
      asset.status?.toUpperCase() == 'DOWN') {
    return l10n.biomedicalNextActionReturnService;
  }
  if (asset.resource == BiomedicalResources.recallNotices) {
    return l10n.biomedicalNextActionReviewRecall;
  }
  if (asset.resource == BiomedicalResources.workOrders) {
    final String status = asset.status?.trim().toUpperCase() ?? '';
    if (status == 'IN_PROGRESS') {
      return l10n.biomedicalNextActionReturnService;
    }
    return l10n.biomedicalNextActionWorkOrder;
  }
  return l10n.biomedicalNextActionReview;
}

_BiomedicalActionKind? _nextActionKindForAsset(BiomedicalAsset asset) {
  if (asset.resource == BiomedicalResources.maintenancePlans) {
    return _BiomedicalActionKind.maintenance;
  }
  if (asset.resource == BiomedicalResources.calibrationLogs) {
    return _BiomedicalActionKind.calibration;
  }
  if (asset.resource == BiomedicalResources.safetyTestLogs) {
    return _BiomedicalActionKind.safety;
  }
  if (asset.resource == BiomedicalResources.downtimeLogs) {
    return _BiomedicalActionKind.closeDowntime;
  }
  if (asset.status?.trim().toUpperCase() == 'DOWN') {
    return _BiomedicalActionKind.returnToService;
  }
  if (asset.resource == BiomedicalResources.recallNotices) {
    return _BiomedicalActionKind.recall;
  }
  if (asset.resource == BiomedicalResources.workOrders) {
    final String status = asset.status?.trim().toUpperCase() ?? '';
    if (status == 'OPEN' || status == 'PENDING') {
      return _BiomedicalActionKind.startWorkOrder;
    }
    if (status == 'IN_PROGRESS') {
      return _BiomedicalActionKind.returnToService;
    }
    return _BiomedicalActionKind.workOrder;
  }
  return null;
}

bool _matchesBiomedicalSearch(
  BiomedicalAsset item,
  String query,
  AppLocalizations l10n,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return <String?>[
    item.displayId,
    item.displayTitle,
    item.displaySubtitle,
    item.categoryLabel,
    item.facilityLabel,
    item.engineerLabel,
    item.status,
    item.priority,
    _labelForCode(item.status),
    _labelForCode(item.priority),
    _formatDateForSearch(item.nextDueAt),
    _nextActionLabel(l10n, item),
    _labelForResource(l10n, item.resource),
  ].whereType<String>().any(
    (String value) => value.toLowerCase().contains(normalized),
  );
}

String? _formatDateForSearch(DateTime? value) {
  if (value == null) {
    return null;
  }
  final DateTime local = value.toLocal();
  return AppFormatters.mediumDate(local, const Locale('en'));
}

String _labelForResource(AppLocalizations l10n, String resource) {
  return switch (resource) {
    BiomedicalResources.registries => l10n.biomedicalPanelRegistry,
    BiomedicalResources.maintenancePlans => l10n.biomedicalPanelPreventive,
    BiomedicalResources.workOrders => l10n.biomedicalPanelWorkOrders,
    BiomedicalResources.calibrationLogs ||
    BiomedicalResources.safetyTestLogs ||
    BiomedicalResources.downtimeLogs ||
    BiomedicalResources.incidentReports ||
    BiomedicalResources.recallNotices => l10n.biomedicalPanelCompliance,
    BiomedicalResources.serviceProviders ||
    BiomedicalResources.warrantyContracts ||
    BiomedicalResources.spareParts => l10n.biomedicalPanelSupport,
    BiomedicalResources.utilizationSnapshots => l10n.biomedicalPanelAnalytics,
    _ => _labelForCode(resource),
  };
}

String _labelForCode(String? value, {String? fallback}) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return fallback ?? '';
  }
  return normalized
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _dash(String? value, AppLocalizations l10n) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? l10n.biomedicalNotAvailableLabel : normalized;
}

String? _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.mediumDate(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String? _formatDateTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String _defaultDateTimeText() {
  return DateTime.now().toLocal().toIso8601String().substring(0, 16);
}

String? _normalizedDate(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc().toIso8601String() ?? normalized;
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${l10n.failureTitle(failure)}: ${l10n.failureMessage(failure)}',
      ),
    ),
  );
}
