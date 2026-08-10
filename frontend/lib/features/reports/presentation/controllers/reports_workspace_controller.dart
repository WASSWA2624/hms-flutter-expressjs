import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final reportsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      ReportsWorkspaceController,
      Result<ReportsWorkspaceState>
    >(ReportsWorkspaceController.new);

final class ReportsWorkspaceController
    extends AsyncNotifier<Result<ReportsWorkspaceState>> {
  ReportsRepository get _repository => ref.read(reportsRepositoryProvider);

  AppAccessPolicy get _policy => ref.read(appAccessPolicyProvider);

  @override
  Future<Result<ReportsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.reports,
      includeCrudMutations: true,
      onRefresh: (_) => refresh(),
    );
    return runWorkspaceInitialLoad(ref, () async {
      final ReportsWorkspacePanel? panel = reportsFallbackPanel(_policy);
      if (panel == null) {
        return Result<ReportsWorkspaceState>.success(_emptyWorkspaceState());
      }
      return _loadForQuery(_queryForPanel(panel));
    });
  }

  Future<AppFailure?> refresh() async {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }

    final ReportsWorkspacePanel panel = current.query.panel;
    if (!canAccessReportsPanel(_policy, panel)) {
      final ReportsWorkspacePanel? fallback = reportsFallbackPanel(_policy);
      if (fallback == null) {
        _emit(_emptyWorkspaceState());
        return null;
      }
      return applyPanel(fallback);
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    return _refreshCurrent(
      preferredItemId: current.selectedItem?.id,
      preferredComplianceId: current.selectedComplianceLog?.id,
    );
  }

  Future<AppFailure?> applyPanel(ReportsWorkspacePanel panel) {
    if (!canAccessReportsPanel(_policy, panel)) {
      return Future<AppFailure?>.value(null);
    }
    final ReportsWorkspaceResource resource =
        ReportsWorkspaceResource.defaultForPanel(panel);
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        panel: panel,
        resource: resource,
        pageRequest: current.pageRequest.first(),
        clearStatus: true,
        clearFormat: true,
        clearDataset: true,
        clearTrigger: true,
        clearDatePreset: true,
        clearFrom: true,
        clearTo: true,
      ),
      clearSelections: true,
    );
  }

  Future<AppFailure?> applySearch(String value) {
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        search: value.trim(),
        pageRequest: current.pageRequest.first(),
      ),
      clearSelections: true,
    );
  }

  Future<AppFailure?> applyStatus(String? value) {
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        status: value,
        pageRequest: current.pageRequest.first(),
        clearStatus: value == null || value.trim().isEmpty,
      ),
      clearSelections: true,
    );
  }

  Future<AppFailure?> applyReportFilters({
    String? status,
    String? format,
    String? dataset,
  }) {
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        status: status,
        format: format,
        dataset: dataset,
        pageRequest: current.pageRequest.first(),
        clearStatus: status == null || status.trim().isEmpty,
        clearFormat: format == null || format.trim().isEmpty,
        clearDataset: dataset == null || dataset.trim().isEmpty,
      ),
      clearSelections: true,
    );
  }

  Future<AppFailure?> applyFormat(String? value) {
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        format: value,
        pageRequest: current.pageRequest.first(),
        clearFormat: value == null || value.trim().isEmpty,
      ),
      clearSelections: true,
    );
  }

  Future<AppFailure?> applyDataset(String? value) {
    final String? trimmed = value?.trim();
    final bool hasDataset = trimmed != null && trimmed.isNotEmpty;
    final bool openCatalog =
        hasDataset &&
        canAccessReportsPanel(_policy, ReportsWorkspacePanel.catalog);
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(
        panel: openCatalog ? ReportsWorkspacePanel.catalog : null,
        resource: openCatalog
            ? ReportsWorkspaceResource.reportDefinitions
            : null,
        dataset: trimmed,
        pageRequest: current.pageRequest.first(),
        clearDataset: !hasDataset,
        clearStatus: openCatalog,
        clearFormat: openCatalog,
      ),
      clearSelections: true,
    );
  }

  /// Open Catalog pre-filtered to a domain dataset (Overview / deep-link path).
  Future<AppFailure?> openCatalogDataset(String datasetKey) {
    return applyDataset(datasetKey);
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    return _applyQuery(
      (ReportsWorkspaceQuery current) => current.copyWith(pageRequest: request),
    );
  }

  void selectItem(ReportsWorkspaceItem item) {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedItem: item,
        clearSelectedComplianceLog: true,
        clearLastFailure: true,
      ),
    );
  }

  void selectComplianceLog(ComplianceLogItem item) {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedComplianceLog: item,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
  }

  Future<AppFailure?> runSelectedDefinition(ReportRunDraft draft) {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.canRun) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }

    return _submitAction(
      () => _repository.runReportDefinitionNow(selected.id, draft),
      onSuccessQuery: (ReportsWorkspaceQuery current) => current.copyWith(
        panel: ReportsWorkspacePanel.delivery,
        resource: ReportsWorkspaceResource.reportRuns,
        pageRequest: current.pageRequest.first(),
        clearStatus: true,
      ),
    );
  }

  Future<AppFailure?> retrySelectedRun(ReportRunDraft draft) {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.canRetry) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.retryReportRun(selected.id, draft));
  }

  Future<AppFailure?> cancelSelectedRun() {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.canCancel) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.cancelReportRun(selected.id));
  }

  Future<AppFailure?> scheduleSelectedDefinition(ReportScheduleDraft draft) {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.canSchedule) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.createSchedule(draft));
  }

  Future<AppFailure?> pauseSelectedSchedule() {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.isSchedule) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.pauseSchedule(selected.id));
  }

  Future<AppFailure?> resumeSelectedSchedule() {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null || !selected.isSchedule) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.resumeSchedule(selected.id));
  }

  Future<AppFailure?> downloadSelectedRun() async {
    final ReportsWorkspaceItem? selected = _selectedItem;
    if (selected == null ||
        selected.kind != ReportItemKind.run ||
        !selected.downloadAvailable) {
      return _missingSelectionFailure();
    }

    _setSaving(true);
    final Result<List<int>> result = await _repository.downloadReportRun(
      selected.id,
    );
    return result.when(
      success: (_) {
        _setSaving(false);
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _applyQuery(
    ReportsWorkspaceQuery Function(ReportsWorkspaceQuery current) update, {
    bool clearSelections = false,
  }) async {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: update(current.query),
        isRefreshing: true,
        clearSelectedItem: clearSelections,
        clearSelectedComplianceLog: clearSelections,
        clearLastFailure: true,
      ),
    );
    return _refreshCurrent();
  }

  Future<AppFailure?> _submitAction(
    Future<Result<ReportsWorkspaceItem>> Function() submit, {
    ReportsWorkspaceQuery Function(ReportsWorkspaceQuery current)?
    onSuccessQuery,
  }) async {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<ReportsWorkspaceItem> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (ReportsWorkspaceItem item) async {
        final ReportsWorkspaceState latest = _currentState!;
        final ReportsWorkspaceQuery nextQuery =
            onSuccessQuery?.call(latest.query) ?? latest.query;
        _emit(
          latest.copyWith(
            query: nextQuery,
            overview: _mergeActionItem(latest.overview, item, nextQuery),
            selectedItem: item,
            isRefreshing: false,
            isSaving: false,
            clearSelectedComplianceLog: true,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshCurrent({
    String? preferredItemId,
    String? preferredComplianceId,
  }) async {
    final ReportsWorkspaceState current = _currentState!;
    final ReportsWorkspaceQuery query = current.query;

    final Result<ReportsWorkspaceState> loaded = await _loadForQuery(
      query,
      preferredItemId: preferredItemId,
      preferredComplianceId: preferredComplianceId,
      preserveOverview: query.panel.isCompliance ? current.overview : null,
    );
    return loaded.when(
      success: (ReportsWorkspaceState next) {
        _emit(
          next.copyWith(
            isRefreshing: false,
            isSaving: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshing: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<Result<ReportsWorkspaceState>> _loadForQuery(
    ReportsWorkspaceQuery query, {
    String? preferredItemId,
    String? preferredComplianceId,
    ReportsWorkspaceOverview? preserveOverview,
  }) async {
    if (query.panel.isCompliance) {
      if (!canReadReportsCompliance(_policy)) {
        return Result<ReportsWorkspaceState>.success(_emptyWorkspaceState());
      }
      final Result<AppPage<ComplianceLogItem>> logsResult = await _repository
          .listComplianceLogs(query);
      return logsResult.when(
        success: (AppPage<ComplianceLogItem> logs) {
          return Result<ReportsWorkspaceState>.success(
            ReportsWorkspaceState(
              query: query,
              overview: preserveOverview ?? const ReportsWorkspaceOverview(),
              complianceLogs: logs,
              selectedComplianceLog: _selectComplianceLog(
                logs.items,
                preferredComplianceId,
              ),
            ),
          );
        },
        failure: (AppFailure failure) {
          return Result<ReportsWorkspaceState>.failure(failure);
        },
      );
    }

    if (!canReadReportsCatalog(_policy)) {
      return Result<ReportsWorkspaceState>.success(_emptyWorkspaceState());
    }

    final Result<ReportsWorkspaceOverview> overviewResult =
        await _loadReportingOverview(query);
    return overviewResult.when(
      success: (ReportsWorkspaceOverview overview) {
        return Result<ReportsWorkspaceState>.success(
          ReportsWorkspaceState(
            query: query,
            overview: overview,
            complianceLogs: _emptyCompliancePage(query.pageRequest),
            selectedItem: _selectItem(overview, preferredItemId),
          ),
        );
      },
      failure: (AppFailure failure) {
        return Result<ReportsWorkspaceState>.failure(failure);
      },
    );
  }

  Future<Result<ReportsWorkspaceOverview>> _loadReportingOverview(
    ReportsWorkspaceQuery query,
  ) async {
    final Result<ReportsWorkspaceOverview> overviewResult = await _repository
        .getWorkspace(query);
    return overviewResult.when<Future<Result<ReportsWorkspaceOverview>>>(
      success: (ReportsWorkspaceOverview overview) async {
        final Result<AppPage<ReportsWorkspaceItem>> schedulesResult =
            await _repository.listSchedules(query);
        return schedulesResult.when(
          success: (AppPage<ReportsWorkspaceItem> schedules) {
            return Result<ReportsWorkspaceOverview>.success(
              overview.copyWith(schedules: schedules),
            );
          },
          failure: (AppFailure failure) {
            return Result<ReportsWorkspaceOverview>.failure(failure);
          },
        );
      },
      failure: (AppFailure failure) async {
        return Result<ReportsWorkspaceOverview>.failure(failure);
      },
    );
  }

  ReportsWorkspaceQuery _queryForPanel(ReportsWorkspacePanel panel) {
    return ReportsWorkspaceQuery(
      panel: panel,
      resource: ReportsWorkspaceResource.defaultForPanel(panel),
    );
  }

  ReportsWorkspaceState _emptyWorkspaceState({
    ReportsWorkspaceQuery query = const ReportsWorkspaceQuery(),
  }) {
    return ReportsWorkspaceState(
      query: query,
      overview: const ReportsWorkspaceOverview(),
      complianceLogs: _emptyCompliancePage(query.pageRequest),
    );
  }

  ReportsWorkspaceItem? _selectItem(
    ReportsWorkspaceOverview overview,
    String? preferredId,
  ) {
    final List<ReportsWorkspaceItem> items = <ReportsWorkspaceItem>[
      ...overview.items.items,
      ...overview.schedules.items,
    ];
    if (preferredId != null) {
      for (final ReportsWorkspaceItem item in items) {
        if (item.id == preferredId) {
          return item;
        }
      }
    }
    return overview.items.items.firstOrNull ??
        overview.schedules.items.firstOrNull;
  }

  ComplianceLogItem? _selectComplianceLog(
    List<ComplianceLogItem> items,
    String? preferredId,
  ) {
    if (preferredId != null) {
      for (final ComplianceLogItem item in items) {
        if (item.id == preferredId) {
          return item;
        }
      }
    }
    return items.firstOrNull;
  }

  /// Clears a page-level failure banner (e.g. after an inline dialog handles it).
  void clearLastFailure() {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null || current.lastFailure == null) {
      return;
    }
    _emit(current.copyWith(clearLastFailure: true));
  }

  ReportsWorkspaceState? get _currentState {
    final Result<ReportsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<ReportsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  ReportsWorkspaceItem? get _selectedItem {
    return _currentState?.selectedItem;
  }

  void _setSaving(bool value) {
    final ReportsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(isSaving: value, clearLastFailure: true));
  }

  void _emit(ReportsWorkspaceState nextState) {
    state = AsyncData<Result<ReportsWorkspaceState>>(
      Result<ReportsWorkspaceState>.success(nextState),
    );
  }

  AppFailure _missingSelectionFailure() {
    return AppFailure.validation(validationFields: <String>{'report_id'});
  }
}

AppPage<ComplianceLogItem> _emptyCompliancePage(AppPageRequest request) {
  return AppPage<ComplianceLogItem>(
    items: const <ComplianceLogItem>[],
    request: request,
    totalItemCount: 0,
  );
}

ReportsWorkspaceOverview _mergeActionItem(
  ReportsWorkspaceOverview overview,
  ReportsWorkspaceItem item,
  ReportsWorkspaceQuery query,
) {
  if (item.isSchedule) {
    return overview.copyWith(schedules: _upsertPage(overview.schedules, item));
  }

  if (!_itemBelongsToResource(item, query.resource)) {
    return overview;
  }

  if (overview.items.items.every(
    (ReportsWorkspaceItem existing) =>
        _itemBelongsToResource(existing, query.resource),
  )) {
    return overview.copyWith(items: _upsertPage(overview.items, item));
  }

  return overview.copyWith(
    items: AppPage<ReportsWorkspaceItem>(
      items: <ReportsWorkspaceItem>[item],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
  );
}

AppPage<ReportsWorkspaceItem> _upsertPage(
  AppPage<ReportsWorkspaceItem> page,
  ReportsWorkspaceItem item,
) {
  final bool replaced = page.items.any((ReportsWorkspaceItem existing) {
    return existing.id == item.id;
  });

  final List<ReportsWorkspaceItem> nextItems = replaced
      ? <ReportsWorkspaceItem>[
          for (final ReportsWorkspaceItem existing in page.items)
            existing.id == item.id ? item : existing,
        ]
      : <ReportsWorkspaceItem>[item, ...page.items];
  final int? total = page.totalItemCount;
  return AppPage<ReportsWorkspaceItem>(
    items: nextItems,
    request: page.request,
    totalItemCount: total == null
        ? null
        : (nextItems.length > total ? nextItems.length : total),
  );
}

bool _itemBelongsToResource(
  ReportsWorkspaceItem item,
  ReportsWorkspaceResource resource,
) {
  return switch (resource) {
    ReportsWorkspaceResource.reportDefinitions =>
      item.kind == ReportItemKind.definition,
    ReportsWorkspaceResource.reportRuns => item.kind == ReportItemKind.run,
    ReportsWorkspaceResource.dashboardWidgets =>
      item.kind == ReportItemKind.dashboardWidget,
    ReportsWorkspaceResource.kpiSnapshots =>
      item.kind == ReportItemKind.kpiSnapshot,
    ReportsWorkspaceResource.analyticsEvents =>
      item.kind == ReportItemKind.analyticsEvent,
  };
}
