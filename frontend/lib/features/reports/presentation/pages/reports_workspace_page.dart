import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/controllers/reports_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class ReportsWorkspacePage extends ConsumerWidget {
  const ReportsWorkspacePage({super.key});

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
        return _ReportsWorkspaceContent(state: data);
      },
    );
  }
}

class _ReportsWorkspaceContent extends ConsumerStatefulWidget {
  const _ReportsWorkspaceContent({required this.state});

  final ReportsWorkspaceState state;

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
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return AppWorkspace(
      title: l10n.reportsTitle,
      leadingIcon: AppRouteIcons.reports,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.reportsSavingStatus
            : l10n.reportsLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.analytics_outlined,
      ),
      compactSummaryCards: true,
      secondaryActions: <Widget>[
        if (_canWriteReports(policy) && state.selectedItem?.canRun == true)
          AppButton.secondary(
            label: l10n.reportsRunAction,
            leadingIcon: Icons.play_arrow_outlined,
            enabled: !state.isSaving,
            onPressed: () => _openRunDialog(context, ref, state),
          ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      summaryCards: _summaryCards(context, state),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _ReportsPrimaryPanel(
            state: state,
            searchController: _searchController,
            reportTableColumns: _reportTableColumns,
            complianceTableColumns: _complianceTableColumns,
          ),
          if (!state.query.panel.isCompliance) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.lg),
            _ReportSchedulesPanel(
              state: state,
              columnVisibilityController: _scheduleTableColumns,
            ),
          ],
        ],
      ),
      detail: _ReportsDetailPanel(state: state, policy: policy),
      activity: _ReportsTimelinePanel(state: state),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    ReportsWorkspaceState state,
  ) {
    final Locale locale = Localizations.localeOf(context);
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final List<ReportsSummaryCard> summary = state.overview.summary;
    final List<Widget> cards = <Widget>[
      for (final ReportsSummaryCard card in summary)
        if (card.value > 0)
          AppWorkspaceSummaryCard(
            label: card.label,
            value: AppFormatters.compactNumber(card.value, locale),
            icon: _summaryIcon(card.id),
            tone: _summaryTone(card.id),
            compact: true,
            onPressed: () {
              final ReportsQueueSummary? queue = state.overview.queueSummaries
                  .where((ReportsQueueSummary item) => item.count > 0)
                  .firstOrNull;
              if (queue != null &&
                  (card.id.contains('run') ||
                      card.id.contains('schedule') ||
                      card.id.contains('kpi'))) {
                controller.applyPanel(queue.panel);
              }
            },
          ),
    ];

    if (cards.isNotEmpty) {
      return cards;
    }

    return <Widget>[
      AppWorkspaceSummaryCard(
        label: context.l10n.reportsPanelCatalog,
        value: AppFormatters.compactNumber(0, locale),
        icon: Icons.article_outlined,
        compact: true,
        onPressed: () => controller.applyPanel(ReportsWorkspacePanel.catalog),
      ),
      AppWorkspaceSummaryCard(
        label: context.l10n.reportsPanelAudit,
        value: AppFormatters.compactNumber(0, locale),
        icon: Icons.manage_search_outlined,
        compact: true,
        onPressed: () => controller.applyPanel(ReportsWorkspacePanel.audit),
      ),
    ];
  }
}

class _ReportsPrimaryPanel extends ConsumerWidget {
  const _ReportsPrimaryPanel({
    required this.state,
    required this.searchController,
    required this.reportTableColumns,
    required this.complianceTableColumns,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  reportTableColumns;
  final AppListTableColumnVisibilityController<ComplianceLogItem>
  complianceTableColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportsWorkspacePanel panel = state.query.panel;
    if (panel.isCompliance) {
      return _ComplianceLogPanel(
        state: state,
        searchController: searchController,
        columnVisibilityController: complianceTableColumns,
      );
    }

    return _ReportItemsPanel(
      state: state,
      searchController: searchController,
      columnVisibilityController: reportTableColumns,
    );
  }
}

class _ReportItemsPanel extends ConsumerWidget {
  const _ReportItemsPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: _panelLabel(l10n, state.query.panel),
      description: l10n.reportsWorklistDescription,
      child: AppListTable<ReportsWorkspaceItem>(
        page: state.overview.items,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: _reportSearch(context, state, searchController, controller),
        itemKeyBuilder: (ReportsWorkspaceItem item) =>
            ValueKey<String>(item.id),
        onRowSelected: controller.selectItem,
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
        columns: _reportColumns(context),
        mobileItemBuilder: (BuildContext context, ReportsWorkspaceItem item) {
          return _ReportMobileTile(item: item);
        },
      ),
    );
  }

  AppListTableSearch<ReportsWorkspaceItem> _reportSearch(
    BuildContext context,
    ReportsWorkspaceState state,
    TextEditingController searchController,
    ReportsWorkspaceController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    return AppListTableSearch<ReportsWorkspaceItem>(
      controller: searchController,
      semanticLabel: l10n.reportsSearchLabel,
      hintText: l10n.reportsSearchHint,
      clearLabel: l10n.reportsClearSearchLabel,
      matcher: (_, _) => true,
      onSubmitted: controller.applySearch,
      onClear: () => controller.applySearch(''),
      showAdvancedFilterButton: true,
      advancedFilterButtonLabel: l10n.reportsFiltersLabel,
      advancedFilterTitle: l10n.reportsFiltersLabel,
      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
      advancedFilterResetLabel: l10n.opdClearFiltersAction,
      advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
          choices: _panelChoices(l10n),
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
          choices: _lookupChoices(state.overview.lookups.datasets),
        ),
      ],
      filterValue: _reportFilterValue(state.query),
      hasActiveFilters: _hasReportFilters(state.query),
      onFilterChanged: (AppSearchBarFilterValue value) {
        final ReportsWorkspacePanel panel = ReportsWorkspacePanel.fromServer(
          value.option(_panelFilterKey),
        );
        if (panel != state.query.panel) {
          controller.applyPanel(panel);
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
  });

  final ReportsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ComplianceLogItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: _panelLabel(l10n, state.query.panel),
      description: l10n.reportsComplianceDescription,
      child: AppListTable<ComplianceLogItem>(
        page: state.complianceLogs,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<ComplianceLogItem>(
          controller: searchController,
          semanticLabel: l10n.reportsSearchLabel,
          hintText: l10n.reportsComplianceSearchHint,
          clearLabel: l10n.reportsClearSearchLabel,
          matcher: (_, _) => true,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.reportsFiltersLabel,
          advancedFilterTitle: l10n.reportsFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
              choices: _panelChoices(l10n),
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
              controller.applyPanel(panel);
              return;
            }
            controller.applyStatus(value.option(_statusFilterKey));
          },
        ),
        itemKeyBuilder: (ComplianceLogItem item) => ValueKey<String>(item.id),
        onRowSelected: controller.selectComplianceLog,
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
        columns: _complianceColumns(context),
        mobileItemBuilder: (BuildContext context, ComplianceLogItem item) {
          return _ComplianceMobileTile(item: item);
        },
      ),
    );
  }
}

class _ReportSchedulesPanel extends ConsumerWidget {
  const _ReportSchedulesPanel({
    required this.state,
    required this.columnVisibilityController,
  });

  final ReportsWorkspaceState state;
  final AppListTableColumnVisibilityController<ReportsWorkspaceItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.reportsSchedulesTitle,
      description: l10n.reportsSchedulesDescription,
      child: AppListTable<ReportsWorkspaceItem>(
        page: state.overview.schedules,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        itemKeyBuilder: (ReportsWorkspaceItem item) =>
            ValueKey<String>(item.id),
        onRowSelected: controller.selectItem,
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
        columns: _scheduleColumns(context),
        mobileItemBuilder: (BuildContext context, ReportsWorkspaceItem item) {
          return _ReportMobileTile(item: item);
        },
      ),
    );
  }
}

class _ReportsDetailPanel extends ConsumerWidget {
  const _ReportsDetailPanel({required this.state, required this.policy});

  final ReportsWorkspaceState state;
  final AppAccessPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.query.panel.isCompliance) {
      final ComplianceLogItem? item = state.selectedComplianceLog;
      if (item == null) {
        return _NoSelectionPanel(
          title: context.l10n.reportsComplianceDetailTitle,
          body: context.l10n.reportsNoComplianceSelectionBody,
        );
      }
      return _ComplianceDetailPanel(
        item: item,
        canExport: _canExportEvidence(policy),
      );
    }

    final ReportsWorkspaceItem? item = state.selectedItem;
    if (item == null) {
      return _NoSelectionPanel(
        title: context.l10n.reportsPreviewTitle,
        body: context.l10n.reportsNoSelectionBody,
      );
    }

    return _ReportDetailPanel(
      item: item,
      canWrite: _canWriteReports(policy),
      canExport: _canExportEvidence(policy),
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

    return AppWorkspaceDetailPanel(
      title: l10n.reportsPreviewTitle,
      actions: <Widget>[
        if (canWrite && item.canRun)
          AppReportActionButton.preview(
            label: l10n.reportsRunAction,
            enabled: !isSaving,
            onPressed: () => _openRunDialog(context, ref, state),
          ),
        if (canWrite && item.canSchedule)
          AppReportActionButton.export(
            label: l10n.reportsScheduleAction,
            enabled: !isSaving,
            icon: Icons.schedule_outlined,
            onPressed: () => _openScheduleDialog(context, ref, item, state),
          ),
        if (canWrite && item.canRetry)
          AppReportActionButton.preview(
            label: l10n.reportsRetryAction,
            enabled: !isSaving,
            icon: Icons.replay_outlined,
            onPressed: () => _openRetryDialog(context, ref, state),
          ),
        if (canWrite && item.canCancel)
          AppReportActionButton(
            label: l10n.reportsCancelRunAction,
            kind: AppReportActionKind.preview,
            icon: Icons.cancel_outlined,
            enabled: !isSaving,
            onPressed: () => _confirmCancelRun(context, ref),
          ),
        if (canExport && item.downloadAvailable)
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
      ],
      child: AppReportPreviewPanel(
        title: item.title,
        selectable: true,
        child: _ReportPreviewBody(item: item),
      ),
    );
  }
}

class _ComplianceDetailPanel extends ConsumerWidget {
  const _ComplianceDetailPanel({required this.item, required this.canExport});

  final ComplianceLogItem item;
  final bool canExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.reportsComplianceDetailTitle,
      actions: <Widget>[
        if (canExport)
          AppReportActionButton.print(
            label: l10n.reportsPrintAction,
            onPressed: () => _printComplianceItem(context, ref, item),
          ),
        if (canExport)
          AppReportActionButton.export(
            label: l10n.reportsExportEvidenceAction,
            onPressed: () => _confirmExportEvidence(context, ref, item),
          ),
      ],
      child: AppReportPreviewPanel(
        title: item.title,
        selectable: true,
        child: _CompliancePreviewBody(item: item),
      ),
    );
  }
}

class _NoSelectionPanel extends StatelessWidget {
  const _NoSelectionPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      child: AppWorkspaceStatePanel.empty(
        title: context.l10n.reportsNoSelectionTitle,
        body: body,
        icon: Icons.preview_outlined,
        minHeight: 260,
      ),
    );
  }
}

class _ReportPreviewBody extends StatelessWidget {
  const _ReportPreviewBody({required this.item});

  final ReportsWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
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
      ],
    );
  }
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
                      fontWeight: FontWeight.w800,
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

class _ReportMobileTile extends StatelessWidget {
  const _ReportMobileTile({required this.item});

  final ReportsWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    return _MobileTile(
      title: item.title,
      subtitle: _joinDisplay(<String?>[
        item.subtitle,
        item.reference,
        _dateTime(context, item.occurredAt),
      ]),
      status: _status(context, item.status),
      icon: _itemIcon(item.kind),
    );
  }
}

class _ComplianceMobileTile extends StatelessWidget {
  const _ComplianceMobileTile({required this.item});

  final ComplianceLogItem item;

  @override
  Widget build(BuildContext context) {
    return _MobileTile(
      title: item.title,
      subtitle: _joinDisplay(<String?>[
        item.subtitle,
        item.recordReference,
        _dateTime(context, item.occurredAt),
      ]),
      status: _status(context, item.action ?? item.scope ?? item.purpose),
      icon: Icons.manage_search_outlined,
    );
  }
}

class _MobileTile extends StatelessWidget {
  const _MobileTile({
    required this.title,
    required this.icon,
    this.subtitle,
    this.status,
  });

  final String title;
  final String? subtitle;
  final AppWorkspaceStatus? status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (status != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(status: status!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
  late final TextEditingController _timeController;
  late final TextEditingController _retentionController;
  String _frequency = _dailyFrequency;
  String? _format;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.title);
    _timeController = TextEditingController();
    _retentionController = TextEditingController();
    _format = widget.item.format;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
            AppTextField(
              controller: _timeController,
              labelText: l10n.reportsTimeOfDayFieldLabel,
              hintText: l10n.reportsTimeOfDayHint,
              enabled: !_isSaving,
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
      timeOfDay: _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim(),
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

List<AppListTableColumn<ReportsWorkspaceItem>> _reportColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<ReportsWorkspaceItem>>[
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsNameColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ReportsWorkspaceItem item) => _TwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: _itemIcon(item.kind),
      ),
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsStatusColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return AppWorkspaceStatusBadge(status: _status(context, item.status));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsReferenceLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.reference, right.reference);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(_valueOrUnknown(context, item.reference));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsOwnerLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.ownerLabel, right.ownerLabel);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(_valueOrUnknown(context, item.ownerLabel));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsUpdatedColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(_dateTime(context, item.occurredAt));
      },
    ),
  ];
}

List<AppListTableColumn<ReportsWorkspaceItem>> _scheduleColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<ReportsWorkspaceItem>>[
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsNameColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ReportsWorkspaceItem item) => _TwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: Icons.schedule_outlined,
      ),
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsStatusColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return AppWorkspaceStatusBadge(status: _status(context, item.status));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsFormatColumnLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(_valueOrUnknown(context, item.format));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      label: l10n.reportsUpdatedColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(_dateTime(context, item.occurredAt));
      },
    ),
  ];
}

List<AppListTableColumn<ComplianceLogItem>> _complianceColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<ComplianceLogItem>>[
    AppListTableColumn<ComplianceLogItem>(
      label: l10n.reportsEventColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ComplianceLogItem item) => _TwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: Icons.manage_search_outlined,
      ),
    ),
    AppListTableColumn<ComplianceLogItem>(
      label: l10n.reportsUserColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(left.userLabel, right.userLabel);
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(_valueOrUnknown(context, item.userLabel));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      label: l10n.reportsRecordColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(
          left.recordReference,
          right.recordReference,
        );
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(_valueOrUnknown(context, item.recordReference));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      label: l10n.reportsTimestampColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(_dateTime(context, item.occurredAt));
      },
    ),
  ];
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.xs),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _openRunDialog(
  BuildContext context,
  WidgetRef ref,
  ReportsWorkspaceState? state,
) async {
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
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleReportDialog(item: item, state: state),
    ),
  );
}

Future<void> _confirmCancelRun(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsCancelRunDialogTitle),
      icon: const Icon(Icons.cancel_outlined),
      content: Text(l10n.reportsCancelRunDialogBody),
      actions: <Widget>[
        AppButton.tertiary(
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
  }
}

Future<void> _confirmExportEvidence(
  BuildContext context,
  WidgetRef ref,
  ComplianceLogItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.reportsExportEvidenceDialogTitle),
      icon: const Icon(Icons.ios_share_outlined),
      content: Text(l10n.reportsExportEvidenceDialogBody),
      actions: <Widget>[
        AppButton.tertiary(
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
  final AppLocalizations l10n = context.l10n;
  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: item.title,
    subtitle: l10n.reportsPrintSubtitle,
    bodyHtml: _reportItemHtml(context, item),
    metadata: <PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: l10n.reportsReferenceLabel,
        value: _valueOrUnknown(context, item.reference),
      ),
      PrintFormMetadataItem(
        label: l10n.reportsGeneratedByLabel,
        value: l10n.appTitle,
      ),
    ],
    footerNote: l10n.reportsPrintFooter,
  );
}

Future<void> _printComplianceItem(
  BuildContext context,
  WidgetRef ref,
  ComplianceLogItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: item.title,
    subtitle: l10n.reportsEvidenceSubtitle,
    bodyHtml: _complianceItemHtml(context, item),
    metadata: <PrintFormMetadataItem>[
      PrintFormMetadataItem(label: l10n.reportsReferenceLabel, value: item.id),
      PrintFormMetadataItem(
        label: l10n.reportsGeneratedByLabel,
        value: l10n.appTitle,
      ),
    ],
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
    AppButton.tertiary(
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

bool _canWriteReports(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.reportsWrite,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
}

bool _canExportEvidence(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.evidenceExport,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
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

List<AppSearchBarFilterChoice> _panelChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final ReportsWorkspacePanel panel in ReportsWorkspacePanel.values)
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

IconData _summaryIcon(String id) {
  if (id.contains('definition')) return Icons.article_outlined;
  if (id.contains('schedule')) return Icons.schedule_outlined;
  if (id.contains('widget')) return Icons.dashboard_customize_outlined;
  if (id.contains('kpi')) return Icons.bar_chart_outlined;
  if (id.contains('activity')) return Icons.insights_outlined;
  return Icons.pending_actions_outlined;
}

AppWorkspaceStatusTone _summaryTone(String id) {
  if (id.contains('critical') || id.contains('failed')) {
    return AppWorkspaceStatusTone.error;
  }
  if (id.contains('queued') || id.contains('due')) {
    return AppWorkspaceStatusTone.warning;
  }
  if (id.contains('definition') || id.contains('widget')) {
    return AppWorkspaceStatusTone.info;
  }
  return AppWorkspaceStatusTone.neutral;
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

IconData _itemIcon(ReportItemKind kind) {
  return switch (kind) {
    ReportItemKind.definition => Icons.article_outlined,
    ReportItemKind.run => Icons.outbox_outlined,
    ReportItemKind.schedule => Icons.schedule_outlined,
    ReportItemKind.dashboardWidget => Icons.dashboard_customize_outlined,
    ReportItemKind.kpiSnapshot => Icons.bar_chart_outlined,
    ReportItemKind.analyticsEvent => Icons.insights_outlined,
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

AppWorkspaceStatus _status(BuildContext context, String? value) {
  return AppWorkspaceStatus(
    label: _valueOrUnknown(context, _apiLabel(value)),
    tone: _statusTone(value),
    icon: _statusIcon(value),
  );
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
