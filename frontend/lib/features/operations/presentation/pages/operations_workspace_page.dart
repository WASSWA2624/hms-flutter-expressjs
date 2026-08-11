import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/presentation/controllers/operations_workspace_controller.dart';
import 'package:hosspi_hms/features/operations/presentation/operations_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class OperationsWorkspacePage extends ConsumerWidget {
  const OperationsWorkspacePage({
    super.key,
    this.initialQuery = const OperationsWorkspaceQuery(),
  });

  final OperationsWorkspaceQuery initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OperationsWorkspaceState>> workspace = ref.watch(
      operationsWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<OperationsWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.operationsTitle,
      loadingTitle: l10n.operationsLoadingTitle,
      loadingBody: l10n.operationsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(operationsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OperationsWorkspaceState state) {
        return _OperationsWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _OperationsWorkspaceContent extends ConsumerStatefulWidget {
  const _OperationsWorkspaceContent({
    required this.state,
    this.initialQuery = const OperationsWorkspaceQuery(),
  });

  final OperationsWorkspaceState state;
  final OperationsWorkspaceQuery initialQuery;

  @override
  ConsumerState<_OperationsWorkspaceContent> createState() =>
      _OperationsWorkspaceContentState();
}

class _OperationsWorkspaceContentState
    extends ConsumerState<_OperationsWorkspaceContent> {
  late OperationsDeskSection _section;
  late final TextEditingController _searchController;
  late final TextEditingController _assetsSearchController;
  late final AppListTableColumnVisibilityController<OperationsWorkItem>
  _tableColumnController;
  late final AppListTableColumnVisibilityController<OperationsAsset>
  _assetsColumnController;

  @override
  void initState() {
    super.initState();
    _section = _sectionFromQuery(widget.initialQuery.section);
    _searchController = TextEditingController(text: widget.state.query.search);
    _assetsSearchController = TextEditingController();
    _tableColumnController =
        AppListTableColumnVisibilityController<OperationsWorkItem>();
    _assetsColumnController =
        AppListTableColumnVisibilityController<OperationsAsset>();
    _scheduleDeepLink(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _OperationsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialQuery.signature != widget.initialQuery.signature) {
      _section = _sectionFromQuery(widget.initialQuery.section);
      _scheduleDeepLink(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _assetsSearchController.dispose();
    _tableColumnController.dispose();
    _assetsColumnController.dispose();
    super.dispose();
  }

  static OperationsDeskSection _sectionFromQuery(String value) {
    return switch (value.trim().toLowerCase()) {
      'open' => OperationsDeskSection.open,
      'in-progress' => OperationsDeskSection.inProgress,
      'completed' => OperationsDeskSection.completed,
      'assets' => OperationsDeskSection.assets,
      _ => OperationsDeskSection.allRequests,
    };
  }

  static String _sectionToQueryValue(OperationsDeskSection section) {
    return switch (section) {
      OperationsDeskSection.allRequests => 'all',
      OperationsDeskSection.open => 'open',
      OperationsDeskSection.inProgress => 'in-progress',
      OperationsDeskSection.completed => 'completed',
      OperationsDeskSection.assets => 'assets',
    };
  }

  void _updateUrlForSection(OperationsDeskSection section) {
    if (!mounted) return;
    final String tab = _sectionToQueryValue(section);
    final String location = AppRoutes.operations.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _scheduleDeepLink(OperationsWorkspaceQuery query) {
    if (!query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLink(query));
    });
  }

  Future<void> _applyDeepLink(OperationsWorkspaceQuery query) async {
    if (!query.hasRouteTargeting) {
      return;
    }
    // Apply section filters only when the URL targets a tab (avoid a redundant
    // clearFilters race on requestId-only deep links).
    if (query.section.trim().isNotEmpty) {
      await _awaitSectionFilter(_section);
      if (!mounted) {
        return;
      }
    }
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      await controller.applySearch(query.search);
      if (!mounted) {
        return;
      }
    }

    final String requestId = query.requestId.trim();
    if (requestId.isEmpty) {
      return;
    }

    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final bool canMutate = canMutateOperations(policy);
    OperationsWorkItem? item = _findWorkItem(
      _operationsStateFromAsync(
            ref.read(operationsWorkspaceControllerProvider),
          ) ??
          widget.state,
      requestId,
    );
    if (item == null) {
      _searchController.text = requestId;
      await controller.applySearch(requestId);
      if (!mounted) {
        return;
      }
      item = _findWorkItem(
        _operationsStateFromAsync(
              ref.read(operationsWorkspaceControllerProvider),
            ) ??
            widget.state,
        requestId,
      );
    }
    if (item != null && mounted) {
      await _openRequestDetailDialog(context, item, canMutate);
    }
  }

  OperationsWorkItem? _findWorkItem(OperationsWorkspaceState state, String id) {
    final String needle = id.trim().toLowerCase();
    if (needle.isEmpty) {
      return null;
    }
    for (final OperationsWorkItem item in state.workItems.items) {
      if (item.id.toLowerCase() == needle ||
          (item.displayId ?? '').toLowerCase() == needle ||
          item.effectiveDisplayId.toLowerCase() == needle) {
        return item;
      }
    }
    return null;
  }

  void _onTabChanged(OperationsDeskSection section) {
    setState(() => _section = section);
    _updateUrlForSection(section);
    unawaited(_awaitSectionFilter(section));
  }

  Future<void> _awaitSectionFilter(OperationsDeskSection section) {
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    return switch (section) {
      OperationsDeskSection.allRequests =>
        controller.clearFilters().then((_) {}),
      OperationsDeskSection.open =>
        controller.applyStatus('OPEN').then((_) {}),
      OperationsDeskSection.inProgress =>
        controller.applyStatus('IN_PROGRESS').then((_) {}),
      OperationsDeskSection.completed =>
        controller.applyStatus('COMPLETED').then((_) {}),
      OperationsDeskSection.assets => Future<void>.value(),
    };
  }

  static IconData _sectionIcon(OperationsDeskSection section) {
    return switch (section) {
      OperationsDeskSection.allRequests => Icons.inventory_2_outlined,
      OperationsDeskSection.open => Icons.pending_actions_outlined,
      OperationsDeskSection.inProgress => Icons.engineering_outlined,
      OperationsDeskSection.completed => Icons.task_alt_outlined,
      OperationsDeskSection.assets => Icons.precision_manufacturing_outlined,
    };
  }

  static String _sectionLabel(
    AppLocalizations l10n,
    OperationsDeskSection section,
  ) {
    return switch (section) {
      OperationsDeskSection.allRequests =>
        l10n.operationsAllRequestsSummaryLabel,
      OperationsDeskSection.open => l10n.operationsOpenSummaryLabel,
      OperationsDeskSection.inProgress => l10n.operationsInProgressSummaryLabel,
      OperationsDeskSection.completed => l10n.operationsCompletedSummaryLabel,
      OperationsDeskSection.assets => l10n.operationsAssetsSummaryLabel,
    };
  }

  static int _sectionCount(
    OperationsWorkspaceState state,
    OperationsDeskSection section,
  ) {
    return switch (section) {
      OperationsDeskSection.allRequests =>
        state.workItems.totalItemCount ?? state.workItems.items.length,
      OperationsDeskSection.open => state.openCount,
      OperationsDeskSection.inProgress => state.inProgressCount,
      OperationsDeskSection.completed =>
        state.completedCount + state.cancelledCount,
      OperationsDeskSection.assets => state.assetCount,
    };
  }

  static AppTabCountTone _sectionCountTone(OperationsDeskSection section) {
    return switch (section) {
      OperationsDeskSection.open ||
      OperationsDeskSection.inProgress => AppTabCountTone.warning,
      OperationsDeskSection.allRequests ||
      OperationsDeskSection.completed ||
      OperationsDeskSection.assets => AppTabCountTone.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final OperationsWorkspaceState state = widget.state;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final OperationsCapabilities capabilities =
        OperationsCapabilities.fromPolicy(policy);
    final List<OperationsDeskSection> visibleSections =
        operationsAllowedSections(policy);
    if (visibleSections.isEmpty) {
      // No authorized sections — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    final bool canShowCurrentSection = visibleSections.contains(_section);
    if (!canShowCurrentSection) {
      final OperationsDeskSection fallback =
          operationsFallbackSection(policy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        setState(() => _section = fallback);
        _updateUrlForSection(fallback);
        unawaited(_awaitSectionFilter(fallback));
      });
    }
    final OperationsDeskSection activeSection = canShowCurrentSection
        ? _section
        : visibleSections.first;
    final bool canMutate = capabilities.canMutate;
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and table.
    final AppFailure? lastFailure = state.lastFailure;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final OperationsDeskSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: activeSection.name,
              onTabTapped: (String tabId) {
                for (final OperationsDeskSection section in visibleSections) {
                  if (section.name == tabId) {
                    _onTabChanged(section);
                    break;
                  }
                }
              },
              primaryAction: _buildPrimaryAction(l10n, state, activeSection),
              secondaryActions: _buildSecondaryActions(
                context,
                l10n,
                state,
                activeSection,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (canShowCurrentSection)
              if (activeSection == OperationsDeskSection.assets)
                _OperationsAssetsPanel(
                  state: state,
                  searchController: _assetsSearchController,
                  columnVisibilityController: _assetsColumnController,
                  onAssetSelected: (OperationsAsset asset) {
                    unawaited(_openAssetDetailDialog(context, asset));
                  },
                )
              else
                _OperationsQueuePanel(
                  state: state,
                  searchController: _searchController,
                  columnVisibilityController: _tableColumnController,
                  canMutate: canMutate,
                  onItemSelected: (OperationsWorkItem item) {
                    unawaited(
                      _openRequestDetailDialog(context, item, canMutate),
                    );
                  },
                  section: activeSection,
                ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPrimaryAction(
    AppLocalizations l10n,
    OperationsWorkspaceState state,
    OperationsDeskSection section,
  ) {
    // Create ∩ via section atom map (AppAccessActionGate omits when denied).
    return AppAccessActionGate(
      requirement: operationsSectionCreateRequirement(section),
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarPrimary(
          label: l10n.operationsCreateRequestAction,
          icon: Icons.add,
          enabled: !state.isMutating,
          onPressed: state.isMutating
              ? null
              : () => _showCreateRequestDialog(context, ref, state),
        );
      },
    );
  }

  List<Widget> _buildSecondaryActions(
    BuildContext context,
    AppLocalizations l10n,
    OperationsWorkspaceState state,
    OperationsDeskSection section,
  ) {
    return <Widget>[
      AppAccessGate(
        requirement: operationsSectionReportRequirement(section),
        child: AppTabToolbarAction(
          label: l10n.operationsOpenReportAction,
          icon: Icons.summarize_outlined,
          enabled: !state.isMutating,
          onPressed: state.isMutating
              ? null
              : () => _showOperationsReportDialog(context, state),
        ),
      ),
    ];
  }

  Future<void> _openRequestDetailDialog(
    BuildContext context,
    OperationsWorkItem item,
    bool canMutate,
  ) async {
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectItem(item);
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailureIfNeeded(context, failure);
      return;
    }

    await showAppDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
          final OperationsWorkspaceState dialogState =
              _operationsStateFromAsync(
                dialogRef.watch(operationsWorkspaceControllerProvider),
              ) ??
              widget.state;
          return AppDialog(
            title: Text(dialogContext.l10n.operationsDetailTitle),
            icon: const Icon(Icons.engineering_outlined),
            scrollable: true,
            maxWidth: 980,
            content: _OperationsDetailPanel(
              state: dialogState,
              canMutate: canMutate,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAssetDetailDialog(
    BuildContext context,
    OperationsAsset asset,
  ) async {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: Text(asset.effectiveLabel),
          icon: const Icon(Icons.precision_manufacturing_outlined),
          scrollable: true,
          maxWidth: 720,
          content: _OperationsAssetDetailPanel(asset: asset),
        );
      },
    );
  }
}

class _OperationsQueuePanel extends ConsumerWidget {
  const _OperationsQueuePanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.canMutate,
    required this.onItemSelected,
    required this.section,
  });

  final OperationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<OperationsWorkItem>
  columnVisibilityController;
  final bool canMutate;
  final ValueChanged<OperationsWorkItem> onItemSelected;
  final OperationsDeskSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<OperationsWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'operations_${section.name}',
      columnWidthStorageKey: 'operations_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      search: AppListTableSearch<OperationsWorkItem>(
        controller: searchController,
        semanticLabel: l10n.operationsSearchLabel,
        hintText: l10n.operationsSearchHint,
        clearLabel: l10n.operationsClearFiltersAction,
        matcher: (OperationsWorkItem item, String query) =>
            _operationsWorkItemMatchesSearch(l10n, item, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.operationsFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.operationsClearFiltersAction,
        searchFieldLabel: l10n.operationsSearchFieldsLabel,
        allFieldsLabel: l10n.operationsAllFilterOption,
        searchFields: _operationsSearchFields(l10n),
        textFilters: _operationsTextFilters(l10n),
        dateFilterLabel: l10n.operationsReportedDateFilterLabel,
        dateFromLabel: l10n.operationsReportedFromLabel,
        dateToLabel: l10n.operationsReportedToLabel,
        datePickerButtonLabel: l10n.operationsPickReportedDateAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        filterGroups: <AppSearchBarFilterGroup>[
          if (section == OperationsDeskSection.allRequests)
            AppSearchBarFilterGroup(
              key: _operationsStatusFilterKey,
              label: l10n.operationsStatusFilterLabel,
              allLabel: l10n.operationsAllFilterOption,
              choices: _statusFilterChoices(l10n),
            ),
          AppSearchBarFilterGroup(
            key: _operationsPriorityFilterKey,
            label: l10n.operationsPriorityFilterLabel,
            allLabel: l10n.operationsAllFilterOption,
            choices: _priorityFilterChoices(l10n),
          ),
        ],
        filterValue: _operationsFilterValue(state.query),
        hasActiveFilters: _hasOperationsFilters(state.query, section),
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final AppFailure? failure = await controller.applyFilters(
            status: _statusForSectionFilter(section, value),
            priority: value.option(_operationsPriorityFilterKey),
            facilityId: value.text(_operationsFacilityFilterKey),
            assetId: value.text(_operationsAssetFilterKey),
            reportedFrom: value.dateFrom,
            reportedTo: value.dateTo,
          );
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
      ),
      itemKeyBuilder: (OperationsWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: onItemSelected,
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<OperationsWorkItem> page) {
        return l10n.operationsPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        );
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(controller.changePage(request));
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.operationsNoRequestsTitle,
        body: l10n.operationsNoRequestsBody,
      ),
      columns: _operationColumns(
        l10n,
        state: state,
        canMutate: canMutate,
      ),
      columnChoices: _operationColumnChoices(l10n),
      mobileItemBuilder: (BuildContext context, OperationsWorkItem item) {
        return AppListTableMobileItem(
          title: _issueLabel(l10n, item),
          caption: item.effectiveDisplayId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(l10n, item.status),
            ),
            AppListTableMobileMeta(
              label: _locationLabel(l10n, item),
              icon: Icons.location_on_outlined,
            ),
            AppListTableMobileMeta(
              label: _priorityLabel(l10n, item.metadata.priority),
              icon: Icons.flag_outlined,
            ),
          ],
          showAvatar: false,
          // Same stage write as the desktop next-action column (sole primary).
          trailing: _OperationsNextActionButton(
            item: item,
            state: state,
            canMutate: canMutate,
          ),
        );
      },
    );
  }
}

class _OperationsAssetsPanel extends StatefulWidget {
  const _OperationsAssetsPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onAssetSelected,
  });

  final OperationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<OperationsAsset>
  columnVisibilityController;
  final ValueChanged<OperationsAsset> onAssetSelected;

  @override
  State<_OperationsAssetsPanel> createState() => _OperationsAssetsPanelState();
}

class _OperationsAssetsPanelState extends State<_OperationsAssetsPanel> {
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  List<OperationsAsset> get _filteredAssets {
    final String query = widget.searchController.text.trim();
    final String? status = _filterValue.option(_operationsAssetStatusFilterKey);
    return widget.state.assets.items
        .where((OperationsAsset asset) {
          if (status != null &&
              status.isNotEmpty &&
              (asset.status ?? '').trim().toUpperCase() != status) {
            return false;
          }
          return _assetMatchesSearch(context.l10n, asset, query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<OperationsAsset> items = _filteredAssets;
    return AppListTable<OperationsAsset>(
      items: items,
      isLoading: widget.state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: widget.columnVisibilityController,
      columnVisibilityStorageKey: 'operations_assets',
      columnWidthStorageKey: 'operations_cw_assets',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      search: AppListTableSearch<OperationsAsset>(
        controller: widget.searchController,
        semanticLabel: l10n.operationsSearchLabel,
        hintText: l10n.operationsSearchHint,
        clearLabel: l10n.operationsClearFiltersAction,
        matcher: (OperationsAsset asset, String query) =>
            _assetMatchesSearch(l10n, asset, query),
        onChanged: (_) => setState(() {}),
        onClear: () => setState(() {}),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.operationsFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.operationsClearFiltersAction,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _operationsAssetStatusFilterKey,
            label: l10n.operationsStatusFilterLabel,
            allLabel: l10n.operationsAllFilterOption,
            choices: _statusFilterChoices(l10n),
          ),
        ],
        filterValue: _filterValue,
        hasActiveFilters:
            _filterValue.option(_operationsAssetStatusFilterKey) != null,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _filterValue = value);
        },
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.operationsNoAssetsTitle,
        body: l10n.operationsNoAssetsBody,
      ),
      itemKeyBuilder: (OperationsAsset asset) => ValueKey<String>(asset.id),
      onRowSelected: widget.onAssetSelected,
      columns: <AppListTableColumn<OperationsAsset>>[
        AppListTableColumn<OperationsAsset>(
          id: 'asset_name',
          label: l10n.operationsAssetNameColumnLabel,
          alwaysVisible: true,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return _CopyableSubtitleCell(
              title: asset.effectiveLabel,
              identifier: asset.effectiveDisplayId,
            );
          },
        ),
        AppListTableColumn<OperationsAsset>(
          id: 'asset_tag',
          label: l10n.operationsAssetTagColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return Text(_display(asset.assetTag, l10n.operationsUnknownValue));
          },
        ),
        AppListTableColumn<OperationsAsset>(
          id: 'asset_status',
          label: l10n.operationsStatusColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return _OperationStatusBadge(status: asset.status);
          },
        ),
        AppListTableColumn<OperationsAsset>(
          id: 'asset_location',
          label: l10n.operationsLocationColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return Text(
              _display(
                asset.facilityLabel,
                asset.facilityId ?? l10n.operationsUnknownValue,
              ),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, OperationsAsset asset) {
        return AppListTableMobileItem(
          title: asset.effectiveLabel,
          caption: asset.effectiveDisplayId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(l10n, asset.status),
            ),
            AppListTableMobileMeta(
              label: _display(
                asset.facilityLabel,
                asset.facilityId ?? l10n.operationsUnknownValue,
              ),
              icon: Icons.location_on_outlined,
            ),
            if ((asset.assetTag ?? '').isNotEmpty)
              AppListTableMobileMeta(
                label: asset.assetTag!,
                icon: Icons.tag_outlined,
              ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

class _OperationsAssetDetailPanel extends StatelessWidget {
  const _OperationsAssetDetailPanel({required this.asset});

  final OperationsAsset asset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCollapsibleSection(
      title: asset.effectiveLabel,
      description: asset.effectiveDisplayId,
      child: AppInfoTileGrid(
        maxColumns: 2,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.operationsAssetNameColumnLabel,
            value: asset.effectiveLabel,
            icon: Icons.precision_manufacturing_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsAssetTagColumnLabel,
            value: _display(asset.assetTag, l10n.operationsUnknownValue),
            icon: Icons.sell_outlined,
            copyable: _hasValue(asset.assetTag),
          ),
          AppInfoTileData(
            label: l10n.operationsStatusColumnLabel,
            value: _statusLabel(l10n, asset.status),
            icon: Icons.fact_check_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsLocationColumnLabel,
            value: _display(
              asset.facilityLabel,
              asset.facilityId ?? l10n.operationsUnknownValue,
            ),
            icon: Icons.location_on_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsRequestColumnLabel,
            value: asset.effectiveDisplayId,
            icon: Icons.confirmation_number_outlined,
            copyable: true,
          ),
        ],
      ),
    );
  }
}

bool _assetMatchesSearch(
  AppLocalizations l10n,
  OperationsAsset asset,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  return _assetSearchHaystack(l10n, asset).contains(needle);
}

String _assetSearchHaystack(AppLocalizations l10n, OperationsAsset asset) {
  return '${asset.name} ${asset.assetTag} ${asset.facilityLabel} '
          '${asset.facilityId} ${_statusLabel(l10n, asset.status)} '
          '${asset.effectiveDisplayId} ${asset.effectiveLabel}'
      .toLowerCase();
}

bool _operationsWorkItemMatchesSearch(
  AppLocalizations l10n,
  OperationsWorkItem item,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final String? dueAt = item.dueAt?.toIso8601String();
  return <String>[
    _issueLabel(l10n, item),
    item.effectiveDisplayId,
    item.displayId ?? '',
    _categoryLabel(l10n, item.metadata.category),
    item.assetLabel ?? '',
    item.assetId ?? '',
    _priorityLabel(l10n, item.metadata.priority),
    _locationLabel(l10n, item),
    item.facilityLabel ?? '',
    item.facilityId ?? '',
    _statusLabel(l10n, item.status),
    _display(item.metadata.assignee, ''),
    _nextActionLabel(l10n, item),
    ?dueAt,
  ].any((String value) => value.toLowerCase().contains(normalized));
}

class _OperationsDetailPanel extends ConsumerWidget {
  const _OperationsDetailPanel({required this.state, required this.canMutate});

  final OperationsWorkspaceState state;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkItem? item = state.selectedItem;
    if (item == null) {
      return AppCollapsibleSection(
        title: l10n.operationsDetailTitle,
        child: AppStateView(
          title: l10n.operationsNoSelectionTitle,
          body: l10n.operationsNoSelectionBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.isRefreshingDetail)
          const LinearProgressIndicator(minHeight: 2),
        _OperationsDetailBody(state: state, item: item, canMutate: canMutate),
      ],
    );
  }
}

class _OperationsDetailBody extends ConsumerWidget {
  const _OperationsDetailBody({
    required this.state,
    required this.item,
    required this.canMutate,
  });

  final OperationsWorkspaceState state;
  final OperationsWorkItem item;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[
      AppInfoTileGrid(
        maxColumns: 2,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.operationsRequestColumnLabel,
            value: item.effectiveDisplayId,
            icon: Icons.confirmation_number_outlined,
            copyable: true,
          ),
          AppInfoTileData(
            label: l10n.operationsStatusColumnLabel,
            value: _statusLabel(l10n, item.status),
            icon: Icons.fact_check_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsPriorityColumnLabel,
            value: _priorityLabel(l10n, item.metadata.priority),
            icon: Icons.priority_high_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsCategoryLabel,
            value: _categoryLabel(l10n, item.metadata.category),
            icon: Icons.category_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsAssigneeColumnLabel,
            value: _display(
              item.metadata.assignee,
              l10n.operationsUnassignedValue,
            ),
            icon: Icons.assignment_ind_outlined,
          ),
          if (_hasValue(item.assetId))
            AppInfoTileData(
              label: l10n.operationsAssetFilterLabel,
              value: item.assetId,
              icon: Icons.precision_manufacturing_outlined,
              copyable: true,
            ),
          AppInfoTileData(
            label: l10n.operationsLocationColumnLabel,
            value: _locationLabel(l10n, item),
            icon: Icons.location_on_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsDueColumnLabel,
            value: _formatDateTimeOrFallback(
              context,
              item.dueAt,
              l10n.operationsNoDueTimeValue,
            ),
            icon: Icons.timer_outlined,
          ),
        ],
      ),
      AppCollapsibleSection(
        title: l10n.operationsIssueTitle,
        titleIcon: Icons.report_problem_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_issueLabel(l10n, item)),
            if (_display(item.metadata.notes, '').isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                item.metadata.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (canMutate) _OperationsActionPanel(item: item, state: state),
      _ServiceLogsPanel(logs: state.serviceLogs),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index += 1) ...<Widget>[
          children[index],
          if (index < children.length - 1) SizedBox(height: theme.spacing.md),
        ],
      ],
    );
  }
}

class _OperationsActionPanel extends ConsumerWidget {
  const _OperationsActionPanel({required this.item, required this.state});

  final OperationsWorkItem item;
  final OperationsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    final _OperationsNextActionKind nextKind = _nextActionKind(
      item,
      canMutate: true,
    );

    final List<AppActionItem> actions = <AppActionItem>[
      if (!item.isTerminal && nextKind != _OperationsNextActionKind.assign)
        AppActionItem(
          label: l10n.operationsAssignAction,
          leadingIcon: Icons.assignment_ind_outlined,
          enabled: !state.isMutating,
          onPressed: () => _showAssignDialog(context, ref),
        ),
      if (nextKind != _OperationsNextActionKind.updateStatus)
        AppActionItem(
          label: l10n.operationsUpdateStatusAction,
          leadingIcon: Icons.fact_check_outlined,
          enabled: !state.isMutating,
          onPressed: () => _showStatusDialog(context, ref, item),
        ),
      if (_hasValue(item.assetId) &&
          nextKind != _OperationsNextActionKind.serviceLog)
        AppActionItem(
          label: l10n.operationsAddServiceLogAction,
          leadingIcon: Icons.build_outlined,
          enabled: !state.isMutating,
          onPressed: () => _showServiceLogDialog(context, ref, state),
        ),
      if (!item.isTerminal)
        AppActionItem(
          label: l10n.operationsPartsVendorAction,
          leadingIcon: Icons.local_shipping_outlined,
          enabled: !state.isMutating,
          onPressed: () => _showNoteDialog(
            context,
            title: l10n.operationsPartsVendorAction,
            fieldLabel: l10n.operationsPartsVendorNoteLabel,
            submitLabel: l10n.operationsSaveNoteAction,
            kind: _noteKindPartsVendor,
            controller: controller,
          ),
        ),
      AppActionItem(
        label: l10n.operationsSafetyNoteAction,
        leadingIcon: Icons.health_and_safety_outlined,
        enabled: !state.isMutating,
        onPressed: () => _showNoteDialog(
          context,
          title: l10n.operationsSafetyNoteAction,
          fieldLabel: l10n.operationsSafetyNoteLabel,
          submitLabel: l10n.operationsSaveNoteAction,
          kind: _noteKindSafety,
          controller: controller,
        ),
      ),
      AppActionItem(
        label: l10n.operationsEvidenceNoteAction,
        leadingIcon: Icons.attach_file_outlined,
        enabled: !state.isMutating,
        onPressed: () => _showNoteDialog(
          context,
          title: l10n.operationsEvidenceNoteAction,
          fieldLabel: l10n.operationsEvidenceNoteLabel,
          submitLabel: l10n.operationsSaveNoteAction,
          kind: _noteKindEvidence,
          controller: controller,
        ),
      ),
      AppActionItem(
        label: l10n.operationsHandoverNoteAction,
        leadingIcon: Icons.swap_horiz_outlined,
        enabled: !state.isMutating,
        onPressed: () => _showNoteDialog(
          context,
          title: l10n.operationsHandoverNoteAction,
          fieldLabel: l10n.operationsHandoverNoteLabel,
          submitLabel: l10n.operationsSaveNoteAction,
          kind: _noteKindHandover,
          controller: controller,
        ),
      ),
      if (nextKind != _OperationsNextActionKind.closeout)
        AppActionItem(
          label: l10n.operationsCloseoutNoteAction,
          leadingIcon: Icons.verified_outlined,
          enabled: !state.isMutating,
          onPressed: () => _showNoteDialog(
            context,
            title: l10n.operationsCloseoutNoteAction,
            fieldLabel: l10n.operationsCloseoutNoteLabel,
            submitLabel: l10n.operationsSaveNoteAction,
            kind: _noteKindCloseout,
            controller: controller,
          ),
        ),
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppQuickActions(
      title: l10n.operationsActionsTitle,
      leadingIcon: Icons.handyman_outlined,
      actions: actions,
    );
  }
}

class _ServiceLogsPanel extends StatelessWidget {
  const _ServiceLogsPanel({required this.logs});

  final AppPage<OperationsServiceLog> logs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    if (logs.items.isEmpty) {
      return AppCollapsibleSection(
        title: l10n.operationsServiceLogsTitle,
        child: AppStateView(
          title: l10n.operationsNoServiceLogsTitle,
          body: l10n.operationsNoServiceLogsBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return AppCollapsibleSection(
      title: l10n.operationsServiceLogsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (
            var index = 0;
            index < logs.items.length;
            index += 1
          ) ...<Widget>[
            _ServiceLogTile(log: logs.items[index]),
            if (index < logs.items.length - 1)
              SizedBox(height: theme.spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ServiceLogTile extends StatelessWidget {
  const _ServiceLogTile({required this.log});

  final OperationsServiceLog log;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppSectionPanel(
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.build_circle_outlined,
      title: _formatDateTimeOrFallback(
        context,
        log.servicedAt ?? log.createdAt,
        l10n.operationsUnknownValue,
      ),
      description: _display(
        log.assetLabel,
        log.assetId ?? l10n.operationsUnknownValue,
      ),
      children: <Widget>[
        AppCopyableIdentifier(
          value: log.effectiveDisplayId,
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        if (_hasValue(log.assetId))
          AppCopyableIdentifier(
            value: log.assetId,
            textStyle: Theme.of(context).textTheme.bodySmall,
          ),
        Text(_display(log.notes, l10n.operationsNoNotesValue)),
      ],
    );
  }
}


class _OperationsNextActionButton extends ConsumerWidget {
  const _OperationsNextActionButton({
    required this.item,
    required this.state,
    required this.canMutate,
  });

  final OperationsWorkItem item;
  final OperationsWorkspaceState state;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final _OperationsNextActionKind kind = _nextActionKind(
      item,
      canMutate: canMutate,
    );
    final OperationsWorkspaceState? workspaceState = _operationsStateFromAsync(
      ref.watch(operationsWorkspaceControllerProvider),
    );
    final bool isMutating = workspaceState?.isMutating ?? false;

    if (kind == _OperationsNextActionKind.none) {
      return Text(
        l10n.operationsNextActionCancelled,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Review-only rows open via row select — no parallel next-action button.
    if (kind == _OperationsNextActionKind.review) {
      return const SizedBox.shrink();
    }

    final String label = _nextActionLabelForKind(l10n, kind, item);
    final IconData icon = _nextActionIcon(kind);
    final bool isNarrow = MediaQuery.sizeOf(context).width < 600;

    return AppButton.secondary(
      label: label,
      icon: icon,
      iconOnly: isNarrow,
      tooltip: label,
      semanticLabel: label,
      enabled: !isMutating,
      onPressed: isMutating
          ? null
          : () => unawaited(_handlePressed(context, ref, kind)),
    );
  }

  Future<void> _handlePressed(
    BuildContext context,
    WidgetRef ref,
    _OperationsNextActionKind kind,
  ) async {
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    // Stage writes only need a selected item — skip the detail fetch shell.
    controller.focusItem(item);
    if (!context.mounted) {
      return;
    }

    final OperationsWorkspaceState workspaceState =
        _operationsStateFromAsync(
          ref.read(operationsWorkspaceControllerProvider),
        ) ??
        state;

    switch (kind) {
      case _OperationsNextActionKind.assign:
        await _showAssignDialog(context, ref);
        return;
      case _OperationsNextActionKind.serviceLog:
        await _showServiceLogDialog(context, ref, workspaceState);
        return;
      case _OperationsNextActionKind.updateStatus:
        await _showStatusDialog(context, ref, item);
        return;
      case _OperationsNextActionKind.closeout:
        await _showNoteDialog(
          context,
          title: context.l10n.operationsCloseoutNoteAction,
          fieldLabel: context.l10n.operationsCloseoutNoteLabel,
          submitLabel: context.l10n.operationsSaveNoteAction,
          kind: _noteKindCloseout,
          controller: controller,
        );
        return;
      case _OperationsNextActionKind.review:
      case _OperationsNextActionKind.none:
        return;
    }
  }
}

class _OperationStatusBadge extends StatelessWidget {
  const _OperationStatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _statusLabel(context.l10n, status),
        tone: _statusTone(status),
        icon: _statusIcon(status),
      ),
    );
  }
}

class _OperationPriorityBadge extends StatelessWidget {
  const _OperationPriorityBadge({required this.priority});

  final String? priority;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _priorityLabel(context.l10n, priority),
        tone: _priorityTone(priority),
        icon: Icons.priority_high_outlined,
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppListItemText(
      title: title,
      subtitle: subtitle,
      titleStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _CopyableSubtitleCell extends StatelessWidget {
  const _CopyableSubtitleCell({
    required this.title,
    required this.identifier,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        AppCopyableIdentifier(
          value: identifier,
          textStyle: theme.textTheme.bodySmall,
        ),
        if ((subtitle ?? '').trim().isNotEmpty)
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _CreateRequestForm extends StatefulWidget {
  const _CreateRequestForm({required this.assets});

  final List<OperationsAsset> assets;

  @override
  State<_CreateRequestForm> createState() => _CreateRequestFormState();
}

class _CreateRequestFormState extends State<_CreateRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _facilityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _category = 'GENERAL_ASSET';
  String _priority = 'NORMAL';
  String? _assetId;

  @override
  void dispose() {
    _facilityController.dispose();
    _locationController.dispose();
    _issueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _category,
          labelText: l10n.operationsCategoryLabel,
          options: _categoryOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _category = value);
            }
          },
        ),
        AppSelectField<String>(
          value: _priority,
          labelText: l10n.operationsPriorityColumnLabel,
          options: _priorityOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _priority = value);
            }
          },
        ),
        AppTextField(
          controller: _facilityController,
          labelText: l10n.operationsFacilityFilterLabel,
          textInputAction: TextInputAction.next,
        ),
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.operationsAssetFilterLabel,
          options: _assetOptions(widget.assets, l10n),
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _locationController,
          labelText: l10n.operationsLocationNoteLabel,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _issueController,
          labelText: l10n.operationsIssueFieldLabel,
          isRequired: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsNotesLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsCreateRequestSubmitAction,
          submitIcon: Icons.add,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsRequestDraft(
        category: _category,
        priority: _priority,
        issue: _issueController.text.trim(),
        facilityId: _facilityController.text.trim(),
        assetId: _assetId,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }
}

class _AssignRequestForm extends StatefulWidget {
  const _AssignRequestForm();

  @override
  State<_AssignRequestForm> createState() => _AssignRequestFormState();
}

class _AssignRequestFormState extends State<_AssignRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _assigneeController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _slaController = TextEditingController();

  @override
  void dispose() {
    _assigneeController.dispose();
    _summaryController.dispose();
    _slaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _assigneeController,
          labelText: l10n.operationsAssigneeFieldLabel,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _slaController,
          labelText: l10n.operationsSlaHoursFieldLabel,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _summaryController,
          labelText: l10n.operationsTriageSummaryFieldLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsAssignSubmitAction,
          submitIcon: Icons.assignment_ind_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsTriageDraft(
        assignedEngineer: _assigneeController.text.trim(),
        triageSummary: _summaryController.text.trim(),
        slaHours: int.tryParse(_slaController.text.trim()),
      ),
    );
  }
}

class _StatusUpdateForm extends StatefulWidget {
  const _StatusUpdateForm({required this.item});

  final OperationsWorkItem item;

  @override
  State<_StatusUpdateForm> createState() => _StatusUpdateFormState();
}

class _StatusUpdateFormState extends State<_StatusUpdateForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late String _status;

  @override
  void initState() {
    super.initState();
    _status =
        operationsMaintenanceStatuses.contains(widget.item.normalizedStatus)
        ? widget.item.normalizedStatus
        : 'OPEN';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _status,
          labelText: l10n.operationsStatusColumnLabel,
          options: _statusOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsStatusNoteLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsUpdateStatusSubmitAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsStatusUpdateDraft(
        status: _status,
        notes: _notesController.text.trim(),
        resolvedAt: _status == 'COMPLETED' ? DateTime.now() : null,
      ),
    );
  }
}

class _ServiceLogForm extends StatefulWidget {
  const _ServiceLogForm({required this.assets, required this.initialAssetId});

  final List<OperationsAsset> assets;
  final String? initialAssetId;

  @override
  State<_ServiceLogForm> createState() => _ServiceLogFormState();
}

class _ServiceLogFormState extends State<_ServiceLogForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late String? _assetId;

  @override
  void initState() {
    super.initState();
    _assetId = widget.initialAssetId;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.operationsAssetFilterLabel,
          isRequired: true,
          options: _assetOptions(widget.assets, l10n),
          validator: (String? value) =>
              _hasValue(value) ? null : l10n.validationRequired,
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsServiceNotesLabel,
          isRequired: true,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsAddServiceLogSubmitAction,
          submitIcon: Icons.build_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey) || !_hasValue(_assetId)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsServiceLogDraft(
        assetId: _assetId!,
        notes: _notesController.text.trim(),
        servicedAt: DateTime.now(),
      ),
    );
  }
}

Future<void> _showCreateRequestDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkspaceState state,
) async {
  // Nested write entry — omit dialog when write ∩ fails (defense beyond
  // AppAccessActionGate on the tab primary).
  if (!canWriteOperations(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final OperationsRequestDraft? draft =
      await showAppDialog<OperationsRequestDraft>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(context.l10n.operationsCreateRequestAction),
          icon: const Icon(Icons.add_task_outlined),
          scrollable: true,
          maxWidth: 720,
          content: _CreateRequestForm(assets: state.assets.items),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .createRequest(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
  final OperationsTriageDraft? draft =
      await showAppDialog<OperationsTriageDraft>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(context.l10n.operationsAssignAction),
          icon: const Icon(Icons.assignment_ind_outlined),
          scrollable: true,
          maxWidth: 640,
          content: const _AssignRequestForm(),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .assignSelected(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showStatusDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkItem item,
) async {
  final OperationsStatusUpdateDraft? draft =
      await showAppDialog<OperationsStatusUpdateDraft>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(context.l10n.operationsUpdateStatusAction),
          icon: const Icon(Icons.fact_check_outlined),
          scrollable: true,
          maxWidth: 640,
          content: _StatusUpdateForm(item: item),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .updateSelectedStatus(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showServiceLogDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkspaceState state,
) async {
  final OperationsServiceLogDraft? draft =
      await showAppDialog<OperationsServiceLogDraft>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(context.l10n.operationsAddServiceLogAction),
          icon: const Icon(Icons.build_outlined),
          scrollable: true,
          maxWidth: 640,
          content: _ServiceLogForm(
            assets: state.assets.items,
            initialAssetId: state.selectedItem?.assetId,
          ),
        ),
      );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .addServiceLog(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showNoteDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String submitLabel,
  required String kind,
  required OperationsWorkspaceController controller,
}) async {
  final String? note = await showAppDialog<String>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(title),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      maxWidth: 640,
      content: _NoteForm(fieldLabel: fieldLabel, submitLabel: submitLabel),
    ),
  );
  if (note == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await controller.appendSelectedNote(
    OperationsRequestNoteDraft(kind: kind, note: note),
  );
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _NoteForm extends StatefulWidget {
  const _NoteForm({required this.fieldLabel, required this.submitLabel});

  final String fieldLabel;
  final String submitLabel;

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _controller,
          labelText: widget.fieldLabel,
          isRequired: true,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (validateAndSaveAppForm(_formKey)) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
        ),
      ],
    );
  }
}

OperationsWorkspaceState? _operationsStateFromAsync(
  AsyncValue<Result<OperationsWorkspaceState>> asyncState,
) {
  return switch (asyncState.asData?.value) {
    ResultSuccess<OperationsWorkspaceState>(value: final value) => value,
    _ => null,
  };
}

Future<void> _showOperationsReportDialog(
  BuildContext context,
  OperationsWorkspaceState state,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _OperationsReportDialog(state: state),
  );
}

class _OperationsReportDialog extends StatelessWidget {
  const _OperationsReportDialog({required this.state});

  final OperationsWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.operationsReportTitle),
      icon: const Icon(Icons.summarize_outlined),
      scrollable: true,
      maxWidth: 760,
      content: AppReportSummaryGrid(
        records: <AppReportSummaryItem>[
          AppReportSummaryItem(
            label: l10n.operationsAllRequestsSummaryLabel,
            value:
                '${state.workItems.totalItemCount ?? state.workItems.items.length}',
            icon: Icons.inventory_2_outlined,
          ),
          AppReportSummaryItem(
            label: l10n.operationsOpenSummaryLabel,
            value: '${state.openCount}',
            icon: Icons.pending_actions_outlined,
          ),
          AppReportSummaryItem(
            label: l10n.operationsInProgressSummaryLabel,
            value: '${state.inProgressCount}',
            icon: Icons.engineering_outlined,
          ),
          AppReportSummaryItem(
            label: l10n.operationsAssetsSummaryLabel,
            value: '${state.assetCount}',
            icon: Icons.precision_manufacturing_outlined,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

List<AppListTableColumn<OperationsWorkItem>> _operationColumns(
  AppLocalizations l10n, {
  required OperationsWorkspaceState state,
  required bool canMutate,
}) {
  return <AppListTableColumn<OperationsWorkItem>>[
    AppListTableColumn<OperationsWorkItem>(
      id: 'request',
      label: l10n.operationsRequestColumnLabel,
      alwaysVisible: true,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            _issueLabel(l10n, left),
            _issueLabel(l10n, right),
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _CopyableSubtitleCell(
          title: _issueLabel(l10n, item),
          identifier: item.effectiveDisplayId,
        );
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'area',
      label: l10n.operationsAreaColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            _categoryLabel(l10n, left.metadata.category),
            _categoryLabel(l10n, right.metadata.category),
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        final String category = _categoryLabel(l10n, item.metadata.category);
        if (_hasValue(item.assetId)) {
          return _CopyableSubtitleCell(
            title: category,
            subtitle: item.assetLabel,
            identifier: item.assetId,
          );
        }
        return _TwoLineCell(title: category, subtitle: item.assetLabel);
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'priority',
      label: l10n.operationsPriorityColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            left.normalizedPriority,
            right.normalizedPriority,
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _OperationPriorityBadge(priority: item.metadata.priority);
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'status',
      label: l10n.operationsStatusColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(left.status, right.status),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _OperationStatusBadge(status: item.status);
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'next_action',
      label: l10n.operationsNextActionColumnLabel,
      alwaysVisible: true,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            _nextActionLabel(l10n, left),
            _nextActionLabel(l10n, right),
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _OperationsNextActionButton(
          item: item,
          state: state,
          canMutate: canMutate,
        );
      },
    ),
  ];
}

List<AppListTableColumn<OperationsWorkItem>> _operationColumnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<OperationsWorkItem>>[
    AppListTableColumn<OperationsWorkItem>(
      id: 'location',
      label: l10n.operationsLocationColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            _locationLabel(l10n, left),
            _locationLabel(l10n, right),
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(_locationLabel(l10n, item));
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'assignee',
      label: l10n.operationsAssigneeColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
            left.metadata.assignee,
            right.metadata.assignee,
          ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(
          _display(item.metadata.assignee, l10n.operationsUnassignedValue),
        );
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      id: 'due',
      label: l10n.operationsDueColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareDateTime(left.dueAt, right.dueAt),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(
          _formatDateTimeOrFallback(
            context,
            item.dueAt,
            l10n.operationsNoDueTimeValue,
          ),
        );
      },
    ),
  ];
}

List<AppSearchBarFieldChoice> _operationsSearchFields(AppLocalizations l10n) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: 'request',
      label: l10n.operationsRequestColumnLabel,
      icon: Icons.confirmation_number_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'location',
      label: l10n.operationsLocationColumnLabel,
      icon: Icons.location_on_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'system',
      label: l10n.operationsAreaColumnLabel,
      icon: Icons.category_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'priority',
      label: l10n.operationsPriorityColumnLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'status',
      label: l10n.operationsStatusColumnLabel,
      icon: Icons.fact_check_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'assignee',
      label: l10n.operationsAssigneeColumnLabel,
      icon: Icons.assignment_ind_outlined,
    ),
  ];
}

List<AppSearchBarTextFilter> _operationsTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _operationsFacilityFilterKey,
      label: l10n.operationsFacilityFilterLabel,
      icon: Icons.business_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _operationsAssetFilterKey,
      label: l10n.operationsAssetFilterLabel,
      icon: Icons.precision_manufacturing_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

AppSearchBarFilterValue _operationsFilterValue(OperationsWorkItemQuery query) {
  return AppSearchBarFilterValue(
    dateFrom: query.reportedFrom,
    dateTo: query.reportedTo,
    texts: <String, String>{
      if (_hasValue(query.facilityId))
        _operationsFacilityFilterKey: query.facilityId!,
      if (_hasValue(query.assetId)) _operationsAssetFilterKey: query.assetId!,
    },
    options: <String, String>{
      if (_hasValue(query.status)) _operationsStatusFilterKey: query.status!,
      if (_hasValue(query.priority))
        _operationsPriorityFilterKey: query.priority!,
    },
  );
}

bool _hasOperationsFilters(
  OperationsWorkItemQuery query,
  OperationsDeskSection section,
) {
  final bool statusFromFilters =
      section == OperationsDeskSection.allRequests && _hasValue(query.status);
  return statusFromFilters ||
      _hasValue(query.priority) ||
      _hasValue(query.facilityId) ||
      _hasValue(query.assetId) ||
      query.reportedFrom != null ||
      query.reportedTo != null;
}

String? _statusForSectionFilter(
  OperationsDeskSection section,
  AppSearchBarFilterValue value,
) {
  return switch (section) {
    OperationsDeskSection.open => 'OPEN',
    OperationsDeskSection.inProgress => 'IN_PROGRESS',
    OperationsDeskSection.completed => 'COMPLETED',
    OperationsDeskSection.allRequests ||
    OperationsDeskSection.assets => value.option(_operationsStatusFilterKey),
  };
}

List<AppSearchBarFilterChoice> _statusFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final String status in operationsMaintenanceStatuses)
      AppSearchBarFilterChoice(
        value: status,
        label: _statusLabel(l10n, status),
        icon: _statusIcon(status),
      ),
  ];
}

List<AppSearchBarFilterChoice> _priorityFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final String priority in operationsRequestPriorities)
      AppSearchBarFilterChoice(
        value: priority,
        label: _priorityLabel(l10n, priority),
        icon: Icons.priority_high_outlined,
      ),
  ];
}

List<AppSelectOption<String>> _statusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String status in operationsMaintenanceStatuses)
      AppSelectOption<String>(value: status, label: _statusLabel(l10n, status)),
  ];
}

List<AppSelectOption<String>> _priorityOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String priority in operationsRequestPriorities)
      AppSelectOption<String>(
        value: priority,
        label: _priorityLabel(l10n, priority),
      ),
  ];
}

List<AppSelectOption<String>> _categoryOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String category in operationsRequestCategories)
      AppSelectOption<String>(
        value: category,
        label: _categoryLabel(l10n, category),
      ),
  ];
}

List<AppSelectOption<String>> _assetOptions(
  List<OperationsAsset> assets,
  AppLocalizations l10n,
) {
  if (assets.isEmpty) {
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: '',
        label: l10n.operationsNoConfiguredAssetsOption,
        enabled: false,
      ),
    ];
  }

  return <AppSelectOption<String>>[
    for (final OperationsAsset asset in assets)
      AppSelectOption<String>(
        value: asset.effectiveDisplayId,
        label: asset.effectiveLabel,
      ),
  ];
}

String _statusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => l10n.operationsStatusOpen,
    'IN_PROGRESS' => l10n.operationsStatusInProgress,
    'COMPLETED' => l10n.operationsStatusCompleted,
    'CANCELLED' => l10n.operationsStatusCancelled,
    _ => l10n.operationsUnknownValue,
  };
}

String _priorityLabel(AppLocalizations l10n, String? priority) {
  return switch ((priority ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'URGENT' => l10n.operationsPriorityUrgent,
    'HIGH' => l10n.operationsPriorityHigh,
    'NORMAL' => l10n.operationsPriorityNormal,
    'LOW' => l10n.operationsPriorityLow,
    _ => l10n.operationsPriorityNormal,
  };
}

String _categoryLabel(AppLocalizations l10n, String? category) {
  return switch ((category ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'ELECTRICAL' => l10n.operationsCategoryElectrical,
    'PLUMBING' => l10n.operationsCategoryPlumbing,
    'WATER' => l10n.operationsCategoryWater,
    'POWER_BACKUP' => l10n.operationsCategoryPowerBackup,
    'HVAC' => l10n.operationsCategoryHvac,
    'GENERAL_ASSET' => l10n.operationsCategoryGeneralAsset,
    'SAFETY' => l10n.operationsCategorySafety,
    'OTHER' => l10n.operationsCategoryOther,
    _ => _display(category, l10n.operationsCategoryOther),
  };
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _priorityTone(String? priority) {
  return switch ((priority ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'URGENT' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.info,
  };
}

IconData _statusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => Icons.pending_actions_outlined,
    'IN_PROGRESS' => Icons.engineering_outlined,
    'COMPLETED' => Icons.task_alt_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

enum _OperationsNextActionKind {
  assign,
  serviceLog,
  updateStatus,
  closeout,
  review,
  none,
}

IconData _nextActionIcon(_OperationsNextActionKind kind) {
  return switch (kind) {
    _OperationsNextActionKind.assign => Icons.assignment_ind_outlined,
    _OperationsNextActionKind.serviceLog => Icons.build_outlined,
    _OperationsNextActionKind.updateStatus => Icons.fact_check_outlined,
    _OperationsNextActionKind.closeout => Icons.verified_outlined,
    _OperationsNextActionKind.review => Icons.visibility_outlined,
    _OperationsNextActionKind.none => Icons.block_outlined,
  };
}

_OperationsNextActionKind _nextActionKind(
  OperationsWorkItem item, {
  required bool canMutate,
}) {
  if (!canMutate) {
    return item.normalizedStatus == 'CANCELLED'
        ? _OperationsNextActionKind.none
        : _OperationsNextActionKind.review;
  }
  return switch (item.normalizedStatus) {
    'OPEN' => _OperationsNextActionKind.assign,
    'IN_PROGRESS' => _hasValue(item.assetId)
        ? _OperationsNextActionKind.serviceLog
        : _OperationsNextActionKind.updateStatus,
    'COMPLETED' => _OperationsNextActionKind.closeout,
    'CANCELLED' => _OperationsNextActionKind.none,
    _ => _OperationsNextActionKind.review,
  };
}

String _nextActionLabelForKind(
  AppLocalizations l10n,
  _OperationsNextActionKind kind,
  OperationsWorkItem item,
) {
  return switch (kind) {
    _OperationsNextActionKind.assign => l10n.operationsNextActionAssign,
    _OperationsNextActionKind.serviceLog => l10n.operationsNextActionServiceLog,
    _OperationsNextActionKind.updateStatus =>
      l10n.operationsNextActionUpdateStatus,
    _OperationsNextActionKind.closeout => l10n.operationsNextActionCloseout,
    _OperationsNextActionKind.review => l10n.operationsNextActionReview,
    _OperationsNextActionKind.none => l10n.operationsNextActionCancelled,
  };
}

String _nextActionLabel(
  AppLocalizations l10n,
  OperationsWorkItem item, {
  bool canMutate = true,
}) {
  return _nextActionLabelForKind(
    l10n,
    _nextActionKind(item, canMutate: canMutate),
    item,
  );
}

String _issueLabel(AppLocalizations l10n, OperationsWorkItem item) {
  return _display(
    item.metadata.issue,
    item.description ?? l10n.operationsUnknownValue,
  );
}

String _locationLabel(AppLocalizations l10n, OperationsWorkItem item) {
  return _joinDisplay(<String>[
    _display(item.metadata.location, ''),
    _display(item.facilityLabel, item.facilityId ?? ''),
  ]).ifEmpty(l10n.operationsUnknownValue);
}

String _formatDateTimeOrFallback(
  BuildContext context,
  DateTime? value,
  String fallback,
) {
  return value == null
      ? fallback
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _display(String? value, String fallback) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

String _joinDisplay(Iterable<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

bool _hasValue(String? value) {
  return value != null && value.trim().isNotEmpty;
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? context.l10n.operationsSavedMessage
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const String _operationsStatusFilterKey = 'status';
const String _operationsAssetStatusFilterKey = 'asset_status';
const String _operationsPriorityFilterKey = 'priority';
const String _operationsFacilityFilterKey = 'facility';
const String _operationsAssetFilterKey = 'asset';
const String _noteKindPartsVendor = 'PARTS_VENDOR';
const String _noteKindSafety = 'SAFETY';
const String _noteKindEvidence = 'EVIDENCE';
const String _noteKindHandover = 'HANDOVER';
const String _noteKindCloseout = 'CLOSEOUT';

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
