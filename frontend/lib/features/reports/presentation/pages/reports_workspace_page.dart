import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/controllers/reports_workspace_controller.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_overview_dashboard.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_overview_shortcut_dialogs.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_domain_reporting_groups.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_workspace_table_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

@immutable
final class ReportsWorkspacePageQuery {
  const ReportsWorkspacePageQuery({this.dataset});

  factory ReportsWorkspacePageQuery.fromUri(Uri uri) {
    final String? dataset = uri.queryParameters['dataset']?.trim();
    return ReportsWorkspacePageQuery(
      dataset: (dataset == null || dataset.isEmpty) ? null : dataset,
    );
  }

  final String? dataset;
}

class ReportsWorkspacePage extends ConsumerWidget {
  const ReportsWorkspacePage({this.initialQuery, super.key});

  final ReportsWorkspacePageQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<ReportsWorkspaceState>> state = ref.watch(
      reportsWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<ReportsWorkspaceState>(
      value: state,
      appBarTitle: l10n.reportsTitle,
      loadingTitle: l10n.reportsLoadingTitle,
      loadingBody: l10n.reportsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(reportsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, ReportsWorkspaceState data) {
        return _ReportsWorkspaceContent(
          state: data,
          initialDataset: initialQuery?.dataset,
        );
      },
    );
  }
}

class _ReportsWorkspaceContent extends ConsumerStatefulWidget {
  const _ReportsWorkspaceContent({
    required this.state,
    this.initialDataset,
  });

  final ReportsWorkspaceState state;
  final String? initialDataset;

  @override
  ConsumerState<_ReportsWorkspaceContent> createState() =>
      _ReportsWorkspaceContentState();
}

class _ReportsWorkspaceContentState
    extends ConsumerState<_ReportsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  _reportTableColumns;
  late final AppListTableColumnVisibilityController<ComplianceLogItem>
  _complianceTableColumns;
  late final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  _scheduleTableColumns;
  bool _appliedInitialDataset = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _reportTableColumns =
        AppListTableColumnVisibilityController<ReportsWorkspaceItem>();
    _complianceTableColumns =
        AppListTableColumnVisibilityController<ComplianceLogItem>();
    _scheduleTableColumns =
        AppListTableColumnVisibilityController<ReportsWorkspaceItem>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialDatasetIfNeeded();
    });
  }

  void _applyInitialDatasetIfNeeded() {
    if (_appliedInitialDataset || !mounted) {
      return;
    }
    final String? dataset = widget.initialDataset?.trim();
    if (dataset == null || dataset.isEmpty) {
      return;
    }
    final ReportsWorkspaceState state = widget.state;
    if (state.query.dataset == dataset) {
      _appliedInitialDataset = true;
      return;
    }
    _appliedInitialDataset = true;
    unawaited(
      ref.read(reportsWorkspaceControllerProvider.notifier).applyDataset(dataset),
    );
  }

  @override
  void didUpdateWidget(covariant _ReportsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reportTableColumns.dispose();
    _complianceTableColumns.dispose();
    _scheduleTableColumns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceState state = widget.state;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and content.
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }
    final bool canReadCatalog = canReadReportsCatalog(policy);
    final List<ReportsWorkspacePanel> allowedPanels = reportsAllowedPanels(
      policy,
    );

    _ensureAuthorizedPanel(controller, state, allowedPanels);

    final bool showDomainReportingOverview =
        (ReportsPharmacyDomainGroups.shouldShow(policy) ||
            ReportsDomainReportingGroups.shouldShow(policy)) &&
        state.query.panel == ReportsWorkspacePanel.overview;

    final bool showSchedules =
        canReadCatalog &&
        !state.query.panel.isCompliance &&
        !showDomainReportingOverview;
    final bool showTimeline =
        canReadCatalog &&
        !state.query.panel.isCompliance &&
        !showDomainReportingOverview &&
        state.overview.timeline.isNotEmpty;

    return AppWorkspace(
      title: l10n.reportsTitle,
      leadingIcon: AppRouteIcons.reports,
      showHeader: !showDomainReportingOverview,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (allowedPanels.isNotEmpty &&
              allowedPanels.contains(state.query.panel))
            _ReportsPrimaryPanel(
              state: state,
              searchController: _searchController,
              reportTableColumns: _reportTableColumns,
              complianceTableColumns: _complianceTableColumns,
              policy: policy,
              allowedPanels: allowedPanels,
            ),
          if (showSchedules) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.lg),
            _ReportSchedulesPanel(
              state: state,
              columnVisibilityController: _scheduleTableColumns,
              policy: policy,
            ),
          ],
        ],
      ),
      activity: showTimeline ? _ReportsTimelinePanel(state: state) : null,
    );
  }

  void _ensureAuthorizedPanel(
    ReportsWorkspaceController controller,
    ReportsWorkspaceState state,
    List<ReportsWorkspacePanel> allowedPanels,
  ) {
    if (allowedPanels.isEmpty) {
      return;
    }
    if (allowedPanels.contains(state.query.panel)) {
      return;
    }
    final ReportsWorkspacePanel fallback = allowedPanels.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      controller.applyPanel(fallback);
    });
  }
}

class _ReportsPrimaryPanel extends ConsumerWidget {
  const _ReportsPrimaryPanel({
    required this.state,
    required this.searchController,
    required this.reportTableColumns,
    required this.complianceTableColumns,
    required this.policy,
    required this.allowedPanels,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  reportTableColumns;
  final AppListTableColumnVisibilityController<ComplianceLogItem>
  complianceTableColumns;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportsWorkspacePanel panel = state.query.panel;
    if (panel.isCompliance) {
      return _ComplianceLogPanel(
        state: state,
        searchController: searchController,
        columnVisibilityController: complianceTableColumns,
        policy: policy,
        allowedPanels: allowedPanels,
      );
    }

    if (panel == ReportsWorkspacePanel.overview) {
      return _ReportsOverviewPanel(
        state: state,
        searchController: searchController,
        policy: policy,
        allowedPanels: allowedPanels,
      );
    }

    return _ReportItemsPanel(
      state: state,
      searchController: searchController,
      columnVisibilityController: reportTableColumns,
      policy: policy,
      allowedPanels: allowedPanels,
    );
  }
}

class _ReportsOverviewPanel extends ConsumerWidget {
  const _ReportsOverviewPanel({
    required this.state,
    required this.searchController,
    required this.policy,
    required this.allowedPanels,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final ThemeData theme = Theme.of(context);
    final bool showDomainGroups =
        ReportsPharmacyDomainGroups.shouldShow(policy) ||
        ReportsDomainReportingGroups.shouldShow(policy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!showDomainGroups) ...<Widget>[
          Text(
            l10n.reportsPanelOverview,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: theme.spacing.sm),
          AppSearchBar(
            controller: searchController,
            semanticLabel: l10n.reportsSearchLabel,
            hintText: l10n.reportsSearchHint,
            clearLabel: l10n.reportsClearSearchLabel,
            onSubmitted: controller.applySearch,
            onClear: () => controller.applySearch(''),
            enableDateFilter: false,
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
            advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _panelFilterKey,
                label: l10n.reportsPanelFilterLabel,
                allLabel: l10n.reportsPanelOverview,
                choices: _panelChoices(l10n, allowedPanels),
              ),
            ],
            filterValue: AppSearchBarFilterValue.empty,
            hasActiveFilters: false,
            onFilterChanged: (AppSearchBarFilterValue value) {
              final ReportsWorkspacePanel panel =
                  ReportsWorkspacePanel.fromServer(
                    value.option(_panelFilterKey),
                  );
              if (panel != state.query.panel &&
                  allowedPanels.contains(panel)) {
                controller.applyPanel(panel);
              }
            },
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ReportsOverviewDashboard(
          state: state,
          policy: policy,
          allowedPanels: allowedPanels,
          onPharmacyOpenDataset: (String datasetKey) {
            final String title = state.overview.lookups.datasets
                .where((ReportsLookupOption option) => option.id == datasetKey)
                .map((ReportsLookupOption option) => option.label)
                .firstWhere(
                  (String label) => label.isNotEmpty,
                  orElse: () => datasetKey,
                );
            unawaited(
              openReportsOverviewShortcutDialog(
                context: context,
                ref: ref,
                kind: ReportsOverviewShortcutKind.dataset,
                datasetKey: datasetKey,
                title: title,
                onOpenItem: (ReportsWorkspaceItem item) {
                  return openReportDetailDialog(
                    context,
                    ref,
                    state,
                    item,
                    policy,
                  );
                },
              ),
            );
          },
          onPharmacyOpenPanel: (ReportsWorkspacePanel panel) {
            final ReportsOverviewShortcutKind kind =
                panel == ReportsWorkspacePanel.delivery
                ? ReportsOverviewShortcutKind.delivery
                : ReportsOverviewShortcutKind.catalog;
            unawaited(
              openReportsOverviewShortcutDialog(
                context: context,
                ref: ref,
                kind: kind,
                onOpenItem: (ReportsWorkspaceItem item) {
                  return openReportDetailDialog(
                    context,
                    ref,
                    state,
                    item,
                    policy,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReportItemsPanel extends ConsumerWidget {
  const _ReportItemsPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.policy,
    required this.allowedPanels,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  columnVisibilityController;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final bool canWrite = canWriteReports(policy);
    final bool canExport = canExportEvidence(policy);
    final String storageKey = 'reports_items_${state.query.panel.serverValue}';

    return AppCollapsibleSection(
      title: _panelLabel(l10n, state.query.panel),
      child: AppListTable<ReportsWorkspaceItem>(
        page: state.overview.items,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityStorageKey: storageKey,
        columnWidthStorageKey:
            'reports_items_cw_${state.query.panel.serverValue}',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        search: _reportSearch(
          context,
          state,
          searchController,
          controller,
          allowedPanels,
        ),
        itemKeyBuilder: (ReportsWorkspaceItem item) =>
            ValueKey<String>(item.id),
        onRowSelected: (ReportsWorkspaceItem item) {
          unawaited(openReportDetailDialog(context, ref, state, item, policy));
        },
        previousPageLabel: l10n.reportsPreviousPageLabel,
        nextPageLabel: l10n.reportsNextPageLabel,
        pageLabelBuilder: (AppPage<ReportsWorkspaceItem> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.reportsNoItemsTitle,
          body: l10n.reportsNoItemsBody,
          icon: Icons.analytics_outlined,
        ),
        columns: reportItemColumns(
          context,
          ref,
          l10n,
          canWrite: canWrite,
          canExport: canExport,
          isSaving: state.isSaving,
          onNextAction:
              (BuildContext actionContext, WidgetRef actionRef, item) {
                return _handleReportNextAction(
                  actionContext,
                  actionRef,
                  state,
                  item,
                  policy,
                );
              },
        ),
        columnChoices: reportItemColumnChoices(context, l10n),
        mobileItemBuilder: (BuildContext context, ReportsWorkspaceItem item) {
          final String? nextLabel = reportNextActionLabel(
            l10n,
            item,
            canWrite: canWrite,
            canExport: canExport,
          );
          return AppListTableMobileItem(
            title: item.title,
            caption: item.reference,
            meta: <AppListTableMobileMeta>[
              AppListTableMobileMeta(
                label: reportsTableStatus(context, item.status).label,
              ),
              AppListTableMobileMeta(
                label: reportsDateTime(context, item.occurredAt),
                icon: Icons.schedule_outlined,
              ),
            ],
            showAvatar: false,
            trailing: nextLabel == null
                ? null
                : ReportNextActionCell(
                    item: item,
                    canWrite: canWrite,
                    canExport: canExport,
                    isSaving: state.isSaving,
                    onPressed: () => _handleReportNextAction(
                      context,
                      ref,
                      state,
                      item,
                      policy,
                    ),
                  ),
          );
        },
      ),
    );
  }

  AppListTableSearch<ReportsWorkspaceItem> _reportSearch(
    BuildContext context,
    ReportsWorkspaceState state,
    TextEditingController searchController,
    ReportsWorkspaceController controller,
    List<ReportsWorkspacePanel> allowedPanels,
  ) {
    final AppLocalizations l10n = context.l10n;
    return AppListTableSearch<ReportsWorkspaceItem>(
      controller: searchController,
      semanticLabel: l10n.reportsSearchLabel,
      hintText: l10n.reportsSearchHint,
      clearLabel: l10n.reportsClearSearchLabel,
      matcher: (ReportsWorkspaceItem item, String query) {
        return matchesReportItemSearch(context, item, query);
      },
      onSubmitted: controller.applySearch,
      onClear: () => controller.applySearch(''),
      showAdvancedFilterButton: true,
      advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
      advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
      advancedFilterResetLabel: l10n.opdClearFiltersAction,
      dateFilterLabel: l10n.reportsDateFilterLabel,
      dateFromLabel: l10n.reportsDateFromLabel,
      dateToLabel: l10n.reportsDateToLabel,
      datePickerButtonLabel: l10n.reportsDatePickerLabel,
      invalidDateMessage: l10n.reportsInvalidDateMessage,
      filterGroups: <AppSearchBarFilterGroup>[
        AppSearchBarFilterGroup(
          key: _panelFilterKey,
          label: l10n.reportsPanelFilterLabel,
          allLabel: l10n.reportsPanelOverview,
          choices: _panelChoices(l10n, allowedPanels),
        ),
        AppSearchBarFilterGroup(
          key: _statusFilterKey,
          label: l10n.reportsStatusFilterLabel,
          allLabel: l10n.reportsAllStatusesLabel,
          choices: _lookupChoices(state.overview.lookups.statuses),
        ),
        AppSearchBarFilterGroup(
          key: _formatFilterKey,
          label: l10n.reportsFormatFilterLabel,
          allLabel: l10n.reportsAllFormatsLabel,
          choices: _lookupChoices(state.overview.lookups.formats),
        ),
        AppSearchBarFilterGroup(
          key: _datasetFilterKey,
          label: l10n.reportsDatasetFilterLabel,
          allLabel: l10n.reportsAllDatasetsLabel,
          choices: _lookupChoices(
            reportsTailoredDatasets(policy, state.overview.lookups.datasets),
          ),
        ),
      ],
      filterValue: _reportFilterValue(state.query),
      hasActiveFilters: _hasReportFilters(state.query),
      onFilterChanged: (AppSearchBarFilterValue value) {
        final ReportsWorkspacePanel panel = ReportsWorkspacePanel.fromServer(
          value.option(_panelFilterKey),
        );
        if (panel != state.query.panel) {
          if (allowedPanels.contains(panel)) {
            controller.applyPanel(panel);
          }
          return;
        }
        controller.applyReportFilters(
          status: value.option(_statusFilterKey),
          format: value.option(_formatFilterKey),
          dataset: value.option(_datasetFilterKey),
        );
      },
    );
  }
}

class _ComplianceLogPanel extends ConsumerWidget {
  const _ComplianceLogPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.policy,
    required this.allowedPanels,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ComplianceLogItem>
  columnVisibilityController;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final bool canExport = canExportEvidence(policy);
    final String storageKey =
        'reports_compliance_${state.query.panel.serverValue}';

    return AppCollapsibleSection(
      title: _panelLabel(l10n, state.query.panel),
      child: AppListTable<ComplianceLogItem>(
        page: state.complianceLogs,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityStorageKey: storageKey,
        columnWidthStorageKey:
            'reports_compliance_cw_${state.query.panel.serverValue}',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        search: AppListTableSearch<ComplianceLogItem>(
          controller: searchController,
          semanticLabel: l10n.reportsSearchLabel,
          hintText: l10n.reportsComplianceSearchHint,
          clearLabel: l10n.reportsClearSearchLabel,
          matcher: (ComplianceLogItem item, String query) {
            return matchesComplianceLogSearch(context, item, query);
          },
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
          advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          dateFilterLabel: l10n.reportsDateFilterLabel,
          dateFromLabel: l10n.reportsDateFromLabel,
          dateToLabel: l10n.reportsDateToLabel,
          datePickerButtonLabel: l10n.reportsDatePickerLabel,
          invalidDateMessage: l10n.reportsInvalidDateMessage,
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _panelFilterKey,
              label: l10n.reportsPanelFilterLabel,
              allLabel: l10n.reportsPanelAudit,
              choices: _panelChoices(l10n, allowedPanels),
            ),
            AppSearchBarFilterGroup(
              key: _statusFilterKey,
              label: l10n.reportsComplianceTypeFilterLabel,
              allLabel: l10n.reportsAllStatusesLabel,
              choices: _complianceStatusChoices(l10n, state.query.panel),
            ),
          ],
          filterValue: _reportFilterValue(state.query),
          hasActiveFilters: _hasReportFilters(state.query),
          onFilterChanged: (AppSearchBarFilterValue value) {
            final ReportsWorkspacePanel panel =
                ReportsWorkspacePanel.fromServer(value.option(_panelFilterKey));
            if (panel != state.query.panel) {
              if (allowedPanels.contains(panel)) {
                controller.applyPanel(panel);
              }
              return;
            }
            controller.applyStatus(value.option(_statusFilterKey));
          },
        ),
        itemKeyBuilder: (ComplianceLogItem item) => ValueKey<String>(item.id),
        onRowSelected: (ComplianceLogItem item) {
          unawaited(
            openComplianceDetailDialog(context, ref, state, item, policy),
          );
        },
        previousPageLabel: l10n.reportsPreviousPageLabel,
        nextPageLabel: l10n.reportsNextPageLabel,
        pageLabelBuilder: (AppPage<ComplianceLogItem> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.reportsNoComplianceLogsTitle,
          body: l10n.reportsNoComplianceLogsBody,
          icon: Icons.manage_search_outlined,
        ),
        columns: complianceLogColumns(
          context,
          ref,
          l10n,
          canExport: canExport,
          onNextAction:
              (BuildContext actionContext, WidgetRef actionRef, item) {
                return _handleComplianceNextAction(
                  actionContext,
                  actionRef,
                  state,
                  item,
                  policy,
                );
              },
        ),
        columnChoices: complianceLogColumnChoices(context, l10n),
        mobileItemBuilder: (BuildContext context, ComplianceLogItem item) {
          final String? exportLabel = complianceNextActionLabel(
            l10n,
            canExport: canExport,
          );
          return AppListTableMobileItem(
            title: item.title,
            caption: item.recordReference,
            meta: <AppListTableMobileMeta>[
              AppListTableMobileMeta(
                label: reportsTableStatus(
                  context,
                  item.action ?? item.scope ?? item.purpose,
                ).label,
              ),
              AppListTableMobileMeta(
                label: reportsDateTime(context, item.occurredAt),
                icon: Icons.schedule_outlined,
              ),
            ],
            showAvatar: false,
            trailing: exportLabel == null
                ? null
                : ComplianceNextActionCell(
                    label: exportLabel,
                    onPressed: () => _handleComplianceNextAction(
                      context,
                      ref,
                      state,
                      item,
                      policy,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _ReportSchedulesPanel extends ConsumerWidget {
  const _ReportSchedulesPanel({
    required this.state,
    required this.columnVisibilityController,
    required this.policy,
  });

  final ReportsWorkspaceState state;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  columnVisibilityController;
  final AppAccessPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final bool canWrite = canWriteReports(policy);

    return AppCollapsibleSection(
      title: l10n.reportsSchedulesTitle,
      child: AppListTable<ReportsWorkspaceItem>(
        page: state.overview.schedules,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityStorageKey: 'reports_schedules',
        columnWidthStorageKey: 'reports_schedules_cw',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        itemKeyBuilder: (ReportsWorkspaceItem item) =>
            ValueKey<String>(item.id),
        onRowSelected: (ReportsWorkspaceItem item) {
          unawaited(openReportDetailDialog(context, ref, state, item, policy));
        },
        previousPageLabel: l10n.reportsPreviousPageLabel,
        nextPageLabel: l10n.reportsNextPageLabel,
        pageLabelBuilder: (AppPage<ReportsWorkspaceItem> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.reportsNoSchedulesTitle,
          body: l10n.reportsNoSchedulesBody,
          icon: Icons.schedule_outlined,
          minHeight: 180,
        ),
        columns: scheduleColumns(
          context,
          ref,
          l10n,
          canWrite: canWrite,
          canExport: false,
          isSaving: state.isSaving,
          onNextAction:
              (BuildContext actionContext, WidgetRef actionRef, item) {
                return _handleReportNextAction(
                  actionContext,
                  actionRef,
                  state,
                  item,
                  policy,
                );
              },
        ),
        mobileItemBuilder: (BuildContext context, ReportsWorkspaceItem item) {
          final String? nextLabel = reportNextActionLabel(
            l10n,
            item,
            canWrite: canWrite,
            canExport: false,
          );
          return AppListTableMobileItem(
            title: item.title,
            caption: item.reference,
            meta: <AppListTableMobileMeta>[
              AppListTableMobileMeta(
                label: reportsTableStatus(context, item.status).label,
              ),
              AppListTableMobileMeta(
                label: reportsDateTime(context, item.occurredAt),
                icon: Icons.schedule_outlined,
              ),
            ],
            showAvatar: false,
            trailing: nextLabel == null
                ? null
                : ReportNextActionCell(
                    item: item,
                    canWrite: canWrite,
                    canExport: false,
                    isSaving: state.isSaving,
                    onPressed: () => _handleReportNextAction(
                      context,
                      ref,
                      state,
                      item,
                      policy,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _ReportDetailPanel extends ConsumerWidget {
  const _ReportDetailPanel({
    required this.item,
    required this.canWrite,
    required this.canExport,
  });

  final ReportsWorkspaceItem item;
  final bool canWrite;
  final bool canExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceState? state = _currentState(ref);
    final bool isSaving = state?.isSaving ?? false;
    final String? omitNextAction = reportPrimaryNextActionKey(
      item,
      canWrite: canWrite,
      canExport: canExport,
    );

    final List<Widget> actions = <Widget>[
      if (canWrite &&
          item.canRun &&
          omitNextAction != reportNextActionRun)
        AppReportActionButton.preview(
          label: l10n.reportsRunAction,
          enabled: !isSaving,
          onPressed: () => _openRunDialog(context, ref, state),
        ),
      if (canWrite &&
          item.canSchedule &&
          omitNextAction != reportNextActionSchedule)
        AppReportActionButton.export(
          label: l10n.reportsScheduleAction,
          enabled: !isSaving,
          icon: Icons.schedule_outlined,
          onPressed: () => _openScheduleDialog(context, ref, item, state),
        ),
      if (canWrite &&
          item.canRetry &&
          omitNextAction != reportNextActionRetry)
        AppReportActionButton.preview(
          label: l10n.reportsRetryAction,
          enabled: !isSaving,
          icon: Icons.replay_outlined,
          onPressed: () => _openRetryDialog(context, ref, state),
        ),
      if (canWrite &&
          item.canCancel &&
          omitNextAction != reportNextActionCancel)
        AppReportActionButton(
          label: l10n.reportsCancelRunAction,
          kind: AppReportActionKind.preview,
          icon: Icons.cancel_outlined,
          enabled: !isSaving,
          onPressed: () => _confirmCancelRun(context, ref, isDialog: true),
        ),
      if (canExport &&
          item.downloadAvailable &&
          omitNextAction != reportNextActionDownload)
        AppReportActionButton.download(
          label: l10n.reportsDownloadAction,
          enabled: !isSaving,
          onPressed: () => _downloadSelectedRun(context, ref),
        ),
      if (canExport)
        AppReportActionButton.print(
          label: l10n.reportsPrintAction,
          enabled: !isSaving,
          onPressed: () => _printReportItem(context, ref, item),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (actions.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: Theme.of(context).spacing.sm,
            runSpacing: Theme.of(context).spacing.sm,
            children: actions,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        AppReportPreviewPanel(
          title: item.title,
          selectable: true,
          child: _ReportPreviewBody(item: item),
        ),
      ],
    );
  }
}

class _ComplianceDetailPanel extends ConsumerWidget {
  const _ComplianceDetailPanel({
    required this.item,
    required this.canExport,
  });

  final ComplianceLogItem item;
  final bool canExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? omitNextAction = compliancePrimaryNextActionKey(
      canExport: canExport,
    );
    final List<Widget> actions = <Widget>[
      if (canExport)
        AppReportActionButton.print(
          label: l10n.reportsPrintAction,
          onPressed: () => _printComplianceItem(context, ref, item),
        ),
      if (canExport && omitNextAction != complianceNextActionExport)
        AppReportActionButton.export(
          label: l10n.reportsExportEvidenceAction,
          onPressed: () => _confirmExportEvidence(context, ref, item),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (actions.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: Theme.of(context).spacing.sm,
            runSpacing: Theme.of(context).spacing.sm,
            children: actions,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        AppReportPreviewPanel(
          title: item.title,
          selectable: true,
          child: _CompliancePreviewBody(item: item),
        ),
      ],
    );
  }
}

class _ReportPreviewBody extends ConsumerStatefulWidget {
  const _ReportPreviewBody({required this.item});

  final ReportsWorkspaceItem item;

  @override
  ConsumerState<_ReportPreviewBody> createState() => _ReportPreviewBodyState();
}

class _ReportPreviewBodyState extends ConsumerState<_ReportPreviewBody> {
  ReportRunPreview? _preview;
  AppFailure? _previewFailure;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadPreviewIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ReportPreviewBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _loadPreviewIfNeeded();
    }
  }

  Future<void> _loadPreviewIfNeeded() async {
    final ReportsWorkspaceItem item = widget.item;
    final bool isRun =
        item.kind == ReportItemKind.run &&
        (item.status ?? '').toUpperCase() == 'COMPLETED';
    if (!isRun || item.id.trim().isEmpty) {
      setState(() {
        _preview = null;
        _previewFailure = null;
        _loadingPreview = false;
      });
      return;
    }
    setState(() {
      _loadingPreview = true;
      _previewFailure = null;
    });
    final Result<ReportRunPreview> result = await ref
        .read(reportsRepositoryProvider)
        .previewReportRun(item.id);
    if (!mounted) {
      return;
    }
    result.when(
      success: (ReportRunPreview preview) {
        setState(() {
          _preview = preview;
          _loadingPreview = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _previewFailure = failure;
          _loadingPreview = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceItem item = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: l10n.reportsStatusColumnLabel,
              value: _valueOrUnknown(context, _apiLabel(item.status)),
              icon: _statusIcon(item.status),
            ),
            AppReportSummaryItem(
              label: l10n.reportsFormatColumnLabel,
              value: _valueOrUnknown(context, item.format),
              icon: Icons.description_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.reportsReferenceLabel,
              value: _valueOrUnknown(context, item.reference),
              icon: Icons.tag_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _PreviewKeyValueList(
          rows: <_PreviewRow>[
            _PreviewRow(l10n.reportsCategoryLabel, _apiLabel(item.category)),
            _PreviewRow(l10n.reportsDatasetLabel, item.datasetKey),
            _PreviewRow(l10n.reportsOwnerLabel, item.ownerLabel),
            _PreviewRow(l10n.reportsFacilityLabel, item.facilityLabel),
            _PreviewRow(
              l10n.reportsUpdatedColumnLabel,
              _dateTime(context, item.occurredAt),
            ),
            _PreviewRow(l10n.reportsValueLabel, _number(context, item.value)),
            _PreviewRow(l10n.reportsErrorLabel, item.errorMessage),
          ],
        ),
        if (item.description != null &&
            item.description!.isNotEmpty) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          Text(
            item.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_loadingPreview) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          AppLoadingIndicator.compact(
            title: l10n.reportsPreviewLoadingTitle,
            body: l10n.reportsPreviewLoadingBody,
          ),
        ] else if (_previewFailure != null) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          AppFailureStateView(
            failure: _previewFailure!,
            onRetry: _loadPreviewIfNeeded,
          ),
        ] else if (_preview != null) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _ReportSeriesPreview(preview: _preview!),
        ],
      ],
    );
  }
}

class _ReportSeriesPreview extends StatelessWidget {
  const _ReportSeriesPreview({required this.preview});

  final ReportRunPreview preview;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    if (preview.isEmpty) {
      return AppStateView(
        variant: AppStateViewVariant.empty,
        title: l10n.reportsPreviewSeriesTitle,
        body: l10n.reportsPreviewEmptyBody,
      );
    }

    final bool isBilling =
        (preview.datasetKey ?? '').contains('billing_collections');
    final List<DashboardTrendPointData> points = <DashboardTrendPointData>[];
    final List<DashboardDistributionSegmentData> segments =
        <DashboardDistributionSegmentData>[];

    if (isBilling) {
      num collections = 0;
      num expenditures = 0;
      num profit = 0;
      for (final Map<String, Object?> row in preview.rows) {
        final String date = '${row['date'] ?? ''}';
        final num collectionsValue = _previewAsNum(row['collections']);
        points.add(
          DashboardTrendPointData(value: collectionsValue, label: date),
        );
        collections += collectionsValue;
        expenditures += _previewAsNum(row['expenditures']);
        profit += _previewAsNum(row['profit_proxy']);
      }
      if (collections > 0) {
        segments.add(
          DashboardDistributionSegmentData(
            label: l10n.billingAnalyticsCollectionsLabel,
            value: collections,
          ),
        );
      }
      if (expenditures > 0) {
        segments.add(
          DashboardDistributionSegmentData(
            label: l10n.billingAnalyticsExpendituresLabel,
            value: expenditures,
          ),
        );
      }
      if (profit > 0) {
        segments.add(
          DashboardDistributionSegmentData(
            label: l10n.billingAnalyticsProfitProxyLabel,
            value: profit,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.reportsPreviewSeriesTitle, style: theme.textTheme.titleSmall),
        if (preview.subtitle.trim().isNotEmpty)
          Text(
            preview.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (isBilling && points.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          DashboardChartsRow(
            data: DashboardChartsData(
              trend: DashboardTrendChartData(
                title: l10n.billingAnalyticsTrendTitle,
                points: points,
                emptyMessage: l10n.reportsPreviewEmptyBody,
              ),
              distribution: DashboardDistributionChartData(
                title: l10n.billingAnalyticsMixTitle,
                total: segments.fold<num>(
                  0,
                  (num sum, DashboardDistributionSegmentData s) =>
                      sum + s.value,
                ),
                segments: segments,
                emptyMessage: l10n.reportsPreviewEmptyBody,
                totalLabel: l10n.billingAnalyticsMixTotalLabel,
              ),
            ),
            twoColumns: MediaQuery.sizeOf(context).width >= 900,
          ),
        ],
        SizedBox(height: theme.spacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: <DataColumn>[
              for (final String column in preview.columns)
                DataColumn(label: Text(column)),
            ],
            rows: <DataRow>[
              for (final Map<String, Object?> row in preview.rows.take(40))
                DataRow(
                  cells: <DataCell>[
                    for (final String column in preview.columns)
                      DataCell(Text('${row[column] ?? ''}')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

num _previewAsNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}

class _CompliancePreviewBody extends StatelessWidget {
  const _CompliancePreviewBody({required this.item});

  final ComplianceLogItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PreviewKeyValueList(
      rows: <_PreviewRow>[
        _PreviewRow(l10n.reportsUserColumnLabel, item.userLabel),
        _PreviewRow(l10n.reportsPatientLabel, item.patientLabel),
        _PreviewRow(l10n.reportsActionLabel, _apiLabel(item.action)),
        _PreviewRow(l10n.reportsEntityLabel, _apiLabel(item.entity)),
        _PreviewRow(l10n.reportsScopeLabel, _apiLabel(item.scope)),
        _PreviewRow(l10n.reportsPurposeLabel, _apiLabel(item.purpose)),
        _PreviewRow(l10n.reportsLegalBasisLabel, _apiLabel(item.legalBasis)),
        _PreviewRow(l10n.reportsRecordColumnLabel, item.recordReference),
        _PreviewRow(l10n.reportsIpAddressLabel, item.ipAddress),
        _PreviewRow(
          l10n.reportsTimestampColumnLabel,
          _dateTime(context, item.occurredAt),
        ),
        _PreviewRow(l10n.reportsDetailsLabel, item.details),
      ],
    );
  }
}

class _PreviewKeyValueList extends StatelessWidget {
  const _PreviewKeyValueList({required this.rows});

  final List<_PreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<_PreviewRow> visibleRows = rows
        .where(
          (_PreviewRow row) =>
              row.value != null && row.value!.trim().isNotEmpty,
        )
        .toList(growable: false);

    if (visibleRows.isEmpty) {
      return Text(
        context.l10n.profileUnknownValue,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final _PreviewRow row in visibleRows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 118,
                  child: Text(
                    row.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(child: Text(row.value!)),
              ],
            ),
          ),
      ],
    );
  }
}

final class _PreviewRow {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String? value;
}

class _ReportsTimelinePanel extends StatelessWidget {
  const _ReportsTimelinePanel({required this.state});

  final ReportsWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    if (state.query.panel.isCompliance || state.overview.timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceActivityList(
      title: context.l10n.reportsTimelineTitle,
      description: context.l10n.reportsTimelineDescription,
      items: <AppWorkspaceActivityItem>[
        for (final ReportsTimelineItem item in state.overview.timeline.take(6))
          AppWorkspaceActivityItem(
            title: item.title,
            subtitle:
                _joinDisplay(<String?>[
                  _apiLabel(item.subtitle),
                  _dateTime(context, item.occurredAt),
                ]) ??
                context.l10n.profileUnknownValue,
            icon: _resourceIcon(item.resource),
            tone: _statusTone(item.status),
          ),
      ],
    );
  }
}

class _RunReportDialog extends ConsumerStatefulWidget {
  const _RunReportDialog({required this.state, required this.isRetry});

  final ReportsWorkspaceState? state;
  final bool isRetry;

  @override
  ConsumerState<_RunReportDialog> createState() => _RunReportDialogState();
}

class _RunReportDialogState extends ConsumerState<_RunReportDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _format;
  late final TextEditingController _retentionController;
  AppFailure? _failure;
  bool _isSaving = false;
  String _datePreset = 'month';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _format = widget.state?.selectedItem?.format;
    _retentionController = TextEditingController();
  }

  @override
  void dispose() {
    _retentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReportsLookups lookups =
        widget.state?.overview.lookups ?? const ReportsLookups();
    return AppDialog(
      title: Text(
        widget.isRetry
            ? l10n.reportsRetryDialogTitle
            : l10n.reportsRunDialogTitle,
      ),
      icon: Icon(
        widget.isRetry ? Icons.replay_outlined : Icons.play_arrow_outlined,
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>(
              value: _format,
              labelText: l10n.reportsFormatFieldLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final ReportsLookupOption option in lookups.formats)
                  AppSelectOption<String>(
                    value: option.id,
                    label: option.label,
                  ),
              ],
              onChanged: (String? value) => setState(() => _format = value),
            ),
            AppSelectField<String>(
              value: _datePreset,
              labelText: l10n.reportsPeriodFieldLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: 'day',
                  label: l10n.reportsPeriodDay,
                ),
                AppSelectOption<String>(
                  value: 'month',
                  label: l10n.reportsPeriodMonth,
                ),
                AppSelectOption<String>(
                  value: 'year',
                  label: l10n.reportsPeriodYear,
                ),
                AppSelectOption<String>(
                  value: 'custom',
                  label: l10n.reportsPeriodCustom,
                ),
              ],
              onChanged: (String? value) async {
                final String next = value ?? 'month';
                if (next == 'custom') {
                  final DateTimeRange? range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange:
                        _customRange ??
                        DateTimeRange(
                          start: DateTime.now().subtract(
                            const Duration(days: 29),
                          ),
                          end: DateTime.now(),
                        ),
                  );
                  if (range == null) {
                    return;
                  }
                  setState(() {
                    _datePreset = next;
                    _customRange = range;
                  });
                  return;
                }
                setState(() {
                  _datePreset = next;
                  _customRange = null;
                });
              },
            ),
            AppTextField(
              controller: _retentionController,
              labelText: l10n.reportsRetentionDaysFieldLabel,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        isSaving: _isSaving,
        submitLabel: widget.isRetry
            ? l10n.reportsRetryAction
            : l10n.reportsRunAction,
        onSubmit: _submit,
      ),
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
    final ReportRunDraft draft = ReportRunDraft(
      format: _format,
      retentionDays: int.tryParse(_retentionController.text.trim()),
      datePreset: _datePreset,
      from: _datePreset == 'custom' ? _customRange?.start : null,
      to: _datePreset == 'custom' ? _customRange?.end : null,
    );
    final AppFailure? failure = widget.isRetry
        ? await ref
              .read(reportsWorkspaceControllerProvider.notifier)
              .retrySelectedRun(draft)
        : await ref
              .read(reportsWorkspaceControllerProvider.notifier)
              .runSelectedDefinition(draft);
    _finish(failure);
  }

  void _finish(AppFailure? failure) {
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

class _ScheduleReportDialog extends ConsumerStatefulWidget {
  const _ScheduleReportDialog({required this.item, required this.state});

  final ReportsWorkspaceItem item;
  final ReportsWorkspaceState? state;

  @override
  ConsumerState<_ScheduleReportDialog> createState() =>
      _ScheduleReportDialogState();
}

class _ScheduleReportDialogState extends ConsumerState<_ScheduleReportDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  AppTimeValue? _timeOfDay;
  late final TextEditingController _retentionController;
  String _frequency = _dailyFrequency;
  String? _format;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.title);
    _retentionController = TextEditingController();
    _format = widget.item.format;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _retentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReportsLookups lookups =
        widget.state?.overview.lookups ?? const ReportsLookups();
    return AppDialog(
      title: Text(l10n.reportsScheduleDialogTitle),
      icon: const Icon(Icons.schedule_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _nameController,
              labelText: l10n.reportsScheduleNameFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>(
              value: _frequency,
              labelText: l10n.reportsFrequencyFieldLabel,
              enabled: !_isSaving,
              options: _frequencyOptions(l10n, lookups.frequencies),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _frequency = value);
                }
              },
            ),
            AppTimeField(
              value: _timeOfDay,
              labelText: l10n.reportsTimeOfDayFieldLabel,
              hintText: l10n.reportsTimeOfDayHint,
              hourLabelText: l10n.appTimeHourLabel,
              minuteLabelText: l10n.appTimeMinuteLabel,
              pickerButtonLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              enabled: !_isSaving,
              onChanged: (AppTimeValue? value) =>
                  setState(() => _timeOfDay = value),
            ),
            AppSelectField<String>(
              value: _format,
              labelText: l10n.reportsFormatFieldLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final ReportsLookupOption option in lookups.formats)
                  AppSelectOption<String>(
                    value: option.id,
                    label: option.label,
                  ),
              ],
              onChanged: (String? value) => setState(() => _format = value),
            ),
            AppTextField(
              controller: _retentionController,
              labelText: l10n.reportsRetentionDaysFieldLabel,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        isSaving: _isSaving,
        submitLabel: l10n.reportsCreateScheduleAction,
        onSubmit: _submit,
      ),
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
    final ReportScheduleDraft draft = ReportScheduleDraft(
      reportDefinitionId: widget.item.id,
      name: _nameController.text.trim(),
      frequency: _frequency,
      format: _format,
      timeOfDay: _timeOfDay?.format24(),
      timezone: DateTime.now().timeZoneName,
      retentionDays: int.tryParse(_retentionController.text.trim()),
    );
    final AppFailure? failure = await ref
        .read(reportsWorkspaceControllerProvider.notifier)
        .scheduleSelectedDefinition(draft);
    _finish(failure);
  }

  void _finish(AppFailure? failure) {
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

Future<void> openReportDetailDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState state,
  ReportsWorkspaceItem item,
  AppAccessPolicy policy,
) async {
  if (!context.mounted) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool canWrite = canWriteReports(policy);
  final bool canExport = canExportEvidence(policy);
  // Push the dialog before selectItem rebuilds the workspace tree so the
  // calling context stays mounted long enough to open the route.
  final Future<void> dialogFuture = showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsPreviewTitle),
      icon: const Icon(Icons.preview_outlined),
      scrollable: true,
      maxWidth: 960,
      content: _ReportDetailPanel(
        item: item,
        canWrite: canWrite,
        canExport: canExport,
      ),
    ),
  );
  ref.read(reportsWorkspaceControllerProvider.notifier).selectItem(item);
  await dialogFuture;
}

Future<void> openComplianceDetailDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState state,
  ComplianceLogItem item,
  AppAccessPolicy policy,
) async {
  if (!context.mounted) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool canExport = canExportEvidence(policy);
  final Future<void> dialogFuture = showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsComplianceDetailTitle),
      icon: const Icon(Icons.manage_search_outlined),
      scrollable: true,
      maxWidth: 960,
      content: _ComplianceDetailPanel(
        item: item,
        canExport: canExport,
      ),
    ),
  );
  ref
      .read(reportsWorkspaceControllerProvider.notifier)
      .selectComplianceLog(item);
  await dialogFuture;
}

Future<void> _handleReportNextAction(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState state,
  ReportsWorkspaceItem item,
  AppAccessPolicy policy,
) async {
  final ReportsWorkspaceController controller = ref.read(
    reportsWorkspaceControllerProvider.notifier,
  );
  controller.selectItem(item);
  final ReportsWorkspaceState current = _currentState(ref) ?? state;
  final bool canWrite = canWriteReports(policy);
  final bool canExport = canExportEvidence(policy);

  if (item.kind == ReportItemKind.definition && canWrite && item.canRun) {
    await _openRunDialog(context, ref, current);
    return;
  }
  if (item.kind == ReportItemKind.definition && canWrite && item.canSchedule) {
    await _openScheduleDialog(context, ref, item, current);
    return;
  }
  if (item.kind == ReportItemKind.run && canWrite && item.canRetry) {
    await _openRetryDialog(context, ref, current);
    return;
  }
  if (item.kind == ReportItemKind.run && canWrite && item.canCancel) {
    await _confirmCancelRun(context, ref);
    return;
  }
  if (item.kind == ReportItemKind.run && canExport && item.downloadAvailable) {
    await _downloadSelectedRun(context, ref);
    return;
  }
  if (item.isSchedule && canWrite) {
    await _openScheduleDialog(context, ref, item, current);
    return;
  }
  await openReportDetailDialog(context, ref, current, item, policy);
}

Future<void> _handleComplianceNextAction(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState state,
  ComplianceLogItem item,
  AppAccessPolicy policy,
) async {
  ref
      .read(reportsWorkspaceControllerProvider.notifier)
      .selectComplianceLog(item);
  if (!canExportEvidence(policy)) {
    await openComplianceDetailDialog(context, ref, state, item, policy);
    return;
  }
  await _confirmExportEvidence(context, ref, item);
}

Future<void> _openRunDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState? state,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canWriteReports(policy)) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RunReportDialog(state: state, isRetry: false),
    ),
  );
}

Future<void> _openRetryDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState? state,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canWriteReports(policy)) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RunReportDialog(state: state, isRetry: true),
    ),
  );
}

Future<void> _openScheduleDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceItem item,
  ReportsWorkspaceState? state,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canWriteReports(policy)) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleReportDialog(item: item, state: state),
    ),
  );
}

Future<void> _confirmCancelRun(
  BuildContext context,
  WidgetRef ref, {
  bool isDialog = false,
}) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canWriteReports(policy)) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsCancelRunDialogTitle),
      icon: const Icon(Icons.cancel_outlined),
      content: Text(l10n.reportsCancelRunDialogBody),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.reportsCancelRunAction,
          leadingIcon: Icons.cancel_outlined,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  final AppFailure? failure = await ref
      .read(reportsWorkspaceControllerProvider.notifier)
      .cancelSelectedRun();
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    if (failure == null && isDialog && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

Future<void> _confirmExportEvidence(
  BuildContext context,
  WidgetRef ref,
  ComplianceLogItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canExportEvidence(policy)) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsExportEvidenceDialogTitle),
      icon: const Icon(Icons.ios_share_outlined),
      content: Text(l10n.reportsExportEvidenceDialogBody),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.reportsExportEvidenceAction,
          leadingIcon: Icons.ios_share_outlined,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _printComplianceItem(context, ref, item);
  }
}

Future<void> _downloadSelectedRun(BuildContext context, WidgetRef ref) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canExportEvidence(policy)) {
    return;
  }
  final AppFailure? failure = await ref
      .read(reportsWorkspaceControllerProvider.notifier)
      .downloadSelectedRun();
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    _showFailureIfNeeded(context, failure);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.reportsDownloadRequestedMessage)),
  );
}

Future<void> _printReportItem(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canExportEvidence(policy)) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  await PrintDocumentTemplates.registry(
    ref: ref,
    context: context,
    title: item.title,
    subtitle: l10n.reportsPrintSubtitle,
    recordReference: PrintFormContextReference(
      label: l10n.reportsReferenceLabel,
      value: _valueOrUnknown(context, item.reference),
    ),
    bodyHtml: _reportItemHtml(context, item),
    footerNote: l10n.reportsPrintFooter,
  );
}

Future<void> _printComplianceItem(
  BuildContext context,
  WidgetRef ref,
  ComplianceLogItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!canExportEvidence(policy)) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  await PrintDocumentTemplates.registry(
    ref: ref,
    context: context,
    title: item.title,
    subtitle: l10n.reportsEvidenceSubtitle,
    recordReference: PrintFormContextReference(
      label: l10n.reportsReferenceLabel,
      value: item.id,
    ),
    bodyHtml: _complianceItemHtml(context, item),
    footerNote: l10n.reportsEvidenceFooter,
  );
}

String _reportItemHtml(BuildContext context, ReportsWorkspaceItem item) {
  final AppLocalizations l10n = context.l10n;
  return PrintFormTemplate.section(
    title: l10n.reportsPreviewTitle,
    bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: l10n.reportsNameColumnLabel,
        value: item.title,
      ),
      PrintFormMetadataItem(
        label: l10n.reportsStatusColumnLabel,
        value: _valueOrUnknown(context, _apiLabel(item.status)),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsFormatColumnLabel,
        value: _valueOrUnknown(context, item.format),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsDatasetLabel,
        value: _valueOrUnknown(context, item.datasetKey),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsOwnerLabel,
        value: _valueOrUnknown(context, item.ownerLabel),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsFacilityLabel,
        value: _valueOrUnknown(context, item.facilityLabel),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsUpdatedColumnLabel,
        value: _dateTime(context, item.occurredAt),
      ),
    ]),
  );
}

String _complianceItemHtml(BuildContext context, ComplianceLogItem item) {
  final AppLocalizations l10n = context.l10n;
  return PrintFormTemplate.section(
    title: l10n.reportsComplianceDetailTitle,
    bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: l10n.reportsEventColumnLabel,
        value: item.title,
      ),
      PrintFormMetadataItem(
        label: l10n.reportsUserColumnLabel,
        value: _valueOrUnknown(context, item.userLabel),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsPatientLabel,
        value: _valueOrUnknown(context, item.patientLabel),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsActionLabel,
        value: _valueOrUnknown(context, _apiLabel(item.action)),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsRecordColumnLabel,
        value: _valueOrUnknown(context, item.recordReference),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsTimestampColumnLabel,
        value: _dateTime(context, item.occurredAt),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsDetailsLabel,
        value: _valueOrUnknown(context, item.details),
      ),
    ]),
  );
}

List<Widget> _dialogActions(
  BuildContext context, {
  required bool isSaving,
  required String submitLabel,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.close(
      leadingIcon: AppActionIcons.cancel,
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: isSaving ? null : onSubmit,
    ),
  ];
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> result,
) async {
  final bool? saved = await result;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.reportsSavedMessage)));
  }
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

ReportsWorkspaceState? _currentState(WidgetRef ref) {
  final Result<ReportsWorkspaceState>? result = ref
      .read(reportsWorkspaceControllerProvider)
      .asData
      ?.value;
  return switch (result) {
    ResultSuccess<ReportsWorkspaceState>(value: final value) => value,
    _ => null,
  };
}

String _panelLabel(AppLocalizations l10n, ReportsWorkspacePanel panel) {
  return switch (panel) {
    ReportsWorkspacePanel.overview => l10n.reportsPanelOverview,
    ReportsWorkspacePanel.catalog => l10n.reportsPanelCatalog,
    ReportsWorkspacePanel.delivery => l10n.reportsPanelDelivery,
    ReportsWorkspacePanel.dashboards => l10n.reportsPanelDashboards,
    ReportsWorkspacePanel.monitor => l10n.reportsPanelMonitor,
    ReportsWorkspacePanel.activity => l10n.reportsPanelActivity,
    ReportsWorkspacePanel.audit => l10n.reportsPanelAudit,
    ReportsWorkspacePanel.phi => l10n.reportsPanelPhi,
    ReportsWorkspacePanel.processing => l10n.reportsPanelProcessing,
  };
}

List<AppSearchBarFilterChoice> _panelChoices(
  AppLocalizations l10n,
  List<ReportsWorkspacePanel> allowedPanels,
) {
  return <AppSearchBarFilterChoice>[
    for (final ReportsWorkspacePanel panel in allowedPanels)
      AppSearchBarFilterChoice(
        value: panel.serverValue,
        label: _panelLabel(l10n, panel),
        icon: _panelIcon(panel),
      ),
  ];
}

List<AppSearchBarFilterChoice> _lookupChoices(
  List<ReportsLookupOption> options,
) {
  return <AppSearchBarFilterChoice>[
    for (final ReportsLookupOption option in options)
      AppSearchBarFilterChoice(value: option.id, label: option.label),
  ];
}

List<AppSearchBarFilterChoice> _complianceStatusChoices(
  AppLocalizations l10n,
  ReportsWorkspacePanel panel,
) {
  final List<String> values = switch (panel) {
    ReportsWorkspacePanel.phi => <String>[
      'TENANT',
      'FACILITY',
      'DEPARTMENT',
      'PATIENT',
    ],
    ReportsWorkspacePanel.processing => <String>[
      'TREATMENT',
      'BILLING',
      'OPERATIONS',
      'RESEARCH',
      'MARKETING',
    ],
    _ => <String>[
      'CREATE',
      'UPDATE',
      'DELETE',
      'ACCESS',
      'EXPORT',
      'LOGIN',
      'LOGOUT',
    ],
  };
  return <AppSearchBarFilterChoice>[
    for (final String value in values)
      AppSearchBarFilterChoice(value: value, label: _apiLabel(value) ?? value),
  ];
}

AppSearchBarFilterValue _reportFilterValue(ReportsWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      _panelFilterKey: query.panel.serverValue,
      if (query.status != null) _statusFilterKey: query.status!,
      if (query.format != null) _formatFilterKey: query.format!,
      if (query.dataset != null) _datasetFilterKey: query.dataset!,
    },
  );
}

bool _hasReportFilters(ReportsWorkspaceQuery query) {
  return query.panel != ReportsWorkspacePanel.overview ||
      query.status != null ||
      query.format != null ||
      query.dataset != null ||
      query.from != null ||
      query.to != null;
}

List<AppSelectOption<String>> _frequencyOptions(
  AppLocalizations l10n,
  List<ReportsLookupOption> options,
) {
  if (options.isNotEmpty) {
    return <AppSelectOption<String>>[
      for (final ReportsLookupOption option in options)
        AppSelectOption<String>(value: option.id, label: option.label),
    ];
  }
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _dailyFrequency,
      label: l10n.reportsFrequencyDaily,
    ),
    AppSelectOption<String>(
      value: 'WEEKLY',
      label: l10n.reportsFrequencyWeekly,
    ),
    AppSelectOption<String>(
      value: 'MONTHLY',
      label: l10n.reportsFrequencyMonthly,
    ),
  ];
}

IconData _panelIcon(ReportsWorkspacePanel panel) {
  return switch (panel) {
    ReportsWorkspacePanel.overview => Icons.space_dashboard_outlined,
    ReportsWorkspacePanel.catalog => Icons.article_outlined,
    ReportsWorkspacePanel.delivery => Icons.outbox_outlined,
    ReportsWorkspacePanel.dashboards => Icons.dashboard_customize_outlined,
    ReportsWorkspacePanel.monitor => Icons.bar_chart_outlined,
    ReportsWorkspacePanel.activity => Icons.insights_outlined,
    ReportsWorkspacePanel.audit => Icons.manage_search_outlined,
    ReportsWorkspacePanel.phi => Icons.privacy_tip_outlined,
    ReportsWorkspacePanel.processing => Icons.policy_outlined,
  };
}

IconData _resourceIcon(ReportsWorkspaceResource? resource) {
  return switch (resource) {
    ReportsWorkspaceResource.reportDefinitions => Icons.article_outlined,
    ReportsWorkspaceResource.reportRuns => Icons.outbox_outlined,
    ReportsWorkspaceResource.dashboardWidgets =>
      Icons.dashboard_customize_outlined,
    ReportsWorkspaceResource.kpiSnapshots => Icons.bar_chart_outlined,
    ReportsWorkspaceResource.analyticsEvents => Icons.insights_outlined,
    null => Icons.analytics_outlined,
  };
}

IconData _statusIcon(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'COMPLETED' ||
    'ACTIVE' ||
    'NORMAL' ||
    'PINNED' => Icons.check_circle_outline,
    'FAILED' || 'CRITICAL' || 'CANCELLED' => Icons.error_outline,
    'QUEUED' ||
    'PROCESSING' ||
    'WARNING' ||
    'PAUSED' => Icons.pending_actions_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'COMPLETED' ||
    'ACTIVE' ||
    'NORMAL' ||
    'PINNED' => AppWorkspaceStatusTone.success,
    'FAILED' || 'CRITICAL' || 'CANCELLED' => AppWorkspaceStatusTone.error,
    'QUEUED' ||
    'PROCESSING' ||
    'WARNING' ||
    'PAUSED' => AppWorkspaceStatusTone.warning,
    'INFO' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _pageLabel<T>(BuildContext context, AppPage<T> page) {
  final int total = page.totalItemCount ?? page.items.length;
  return context.l10n.reportsPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

String _dateTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String? _number(BuildContext context, num? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.decimal(value, Localizations.localeOf(context));
}

String _valueOrUnknown(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? context.l10n.profileUnknownValue : normalized;
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? _apiLabel(String? value) {
  final String normalized =
      value?.trim().replaceAll('_', ' ').toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

const String _panelFilterKey = 'panel';
const String _statusFilterKey = 'status';
const String _formatFilterKey = 'format';
const String _datasetFilterKey = 'dataset';
const String _dailyFrequency = 'DAILY';
