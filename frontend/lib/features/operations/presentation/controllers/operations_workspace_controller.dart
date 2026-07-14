import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final operationsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      OperationsWorkspaceController,
      Result<OperationsWorkspaceState>
    >(OperationsWorkspaceController.new);

final class OperationsWorkspaceController
    extends AsyncNotifier<Result<OperationsWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 15);

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<OperationsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.operations,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isMutating ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<OperationsWorkspaceState> result =
        await runWorkspaceInitialLoad(ref, _loadInitialState);
    _startAdaptivePolling();
    return result;
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isMutating ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.operations,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.operations,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, plan: WorkspaceRefreshPlan.full);
  }

  Future<AppFailure?> applySearch(String value) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshRequests(showLoading: true);
  }

  Future<AppFailure?> applyStatus(String? status) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          status: status,
          clearStatus: status == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshRequests(showLoading: true);
  }

  Future<AppFailure?> applyFilters({
    String? status,
    String? priority,
    String? facilityId,
    String? assetId,
    DateTime? reportedFrom,
    DateTime? reportedTo,
  }) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          status: status,
          priority: priority,
          facilityId: facilityId,
          assetId: assetId,
          reportedFrom: reportedFrom,
          reportedTo: reportedTo,
          clearStatus: status == null,
          clearPriority: priority == null,
          clearFacilityId: facilityId == null,
          clearAssetId: assetId == null,
          clearReportedFrom: reportedFrom == null,
          clearReportedTo: reportedTo == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshRequests(showLoading: true);
  }

  Future<AppFailure?> clearFilters() async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: OperationsWorkItemQuery(
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshRequests(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshRequests(showLoading: true);
  }

  Future<AppFailure?> selectItem(OperationsWorkItem item) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<OperationsWorkItem> result = await _repository.getRequest(
      item.effectiveDisplayId,
    );
    return result.when(
      success: (OperationsWorkItem detail) async {
        final AppPage<OperationsServiceLog> logs = await _serviceLogsFor(
          detail,
        );
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedItem: detail,
              workItems: _replaceWorkItem(latest.workItems, detail),
              serviceLogs: logs,
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createRequest(OperationsRequestDraft draft) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<OperationsWorkItem> result = await _repository.createRequest(
      draft,
    );
    return result.when(
      success: (OperationsWorkItem item) async {
        final AppPage<OperationsServiceLog> logs = await _serviceLogsFor(item);
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              workItems: _replaceWorkItem(latest.workItems, item),
              selectedItem: item,
              serviceLogs: logs,
              isMutating: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> assignSelected(OperationsTriageDraft draft) {
    return _mutateSelected(
      (OperationsWorkItem item) =>
          _repository.triageRequest(item.effectiveDisplayId, draft),
    );
  }

  Future<AppFailure?> updateSelectedStatus(OperationsStatusUpdateDraft draft) {
    return _mutateSelected(
      (OperationsWorkItem item) => _repository.updateRequestStatus(item, draft),
    );
  }

  Future<AppFailure?> appendSelectedNote(OperationsRequestNoteDraft draft) {
    return _mutateSelected(
      (OperationsWorkItem item) => _repository.appendRequestNote(item, draft),
    );
  }

  Future<AppFailure?> addServiceLog(OperationsServiceLogDraft draft) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<OperationsServiceLog> result = await _repository.addServiceLog(
      draft,
    );
    return result.when(
      success: (OperationsServiceLog log) async {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              serviceLogs: _insertServiceLog(latest.serviceLogs, log),
              isMutating: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<Result<OperationsWorkspaceState>> _loadInitialState() async {
    const OperationsWorkItemQuery query = OperationsWorkItemQuery();
    final Result<AppPage<OperationsWorkItem>> workItemsResult =
        await _repository.listRequests(query);

    return workItemsResult.when(
      success: (AppPage<OperationsWorkItem> workItems) async {
        AppFailure? nonBlockingFailure;
        AppPage<OperationsAsset> assets = _emptyAssets();
        final Result<AppPage<OperationsAsset>> assetsResult = await _repository
            .listAssets(const OperationsAssetQuery());
        assetsResult.when(
          success: (AppPage<OperationsAsset> value) {
            assets = value;
          },
          failure: (AppFailure failure) {
            nonBlockingFailure = failure;
          },
        );

        return Result<OperationsWorkspaceState>.success(
          OperationsWorkspaceState(
            query: query,
            workItems: workItems,
            assets: assets,
            serviceLogs: _emptyServiceLogs(),
            lastFailure: nonBlockingFailure,
          ),
        );
      },
      failure: (AppFailure failure) {
        return Result<OperationsWorkspaceState>.failure(failure);
      },
    );
  }

  void _startAdaptivePolling() {
    installWorkspaceAdaptivePolling(
      ref: ref,
      polling: _adaptivePolling,
      intervalWhenDisconnected: _syncInterval,
      disconnectProfile: WorkspaceRefreshProfile.operations,
      syncOnDisconnect: (WorkspaceRefreshPlan plan) =>
          _syncVisibleData(plan: plan),
    );
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final OperationsWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshRequests = workspacePlanRefreshesPrimaryList(plan);
    final bool refreshDetail = plan.selectedDetail;
    final bool refreshAssets =
        plan.referenceData || plan.context || plan.catalogs;
    if (!refreshRequests && !refreshDetail && !refreshAssets) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedItem != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      if (refreshAssets) {
        await _refreshAssets();
      }

      if (refreshRequests) {
        final AppFailure? failure = await _refreshRequests(
          showLoading: showLoading,
        );
        if (failure != null) {
          return failure;
        }
      }

      if (refreshDetail) {
        final OperationsWorkItem? selected = _currentState?.selectedItem;
        if (selected != null) {
          await selectItem(selected);
        }
      }

      return null;
    } finally {
      final OperationsWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isMutating ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
    }
  }

  Future<AppFailure?> _refreshAssets() async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<OperationsAsset>> result = await _repository
        .listAssets(const OperationsAssetQuery());
    return result.when(
      success: (AppPage<OperationsAsset> assets) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(assets: assets));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshRequests({required bool showLoading}) async {
    final OperationsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<OperationsWorkItem>> result = await _repository
        .listRequests(current.query);
    return result.when(
      success: (AppPage<OperationsWorkItem> page) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              workItems: page,
              selectedItem: _selectedAfterRefresh(page, latest.selectedItem),
              isRefreshing: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<OperationsWorkItem>> Function(OperationsWorkItem item) submit,
  ) async {
    final OperationsWorkspaceState? current = _currentState;
    final OperationsWorkItem? selected = current?.selectedItem;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<OperationsWorkItem> result = await submit(selected);
    return result.when(
      success: (OperationsWorkItem item) async {
        final AppPage<OperationsServiceLog> logs = await _serviceLogsFor(item);
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedItem: item,
              workItems: _replaceWorkItem(latest.workItems, item),
              serviceLogs: logs,
              isMutating: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OperationsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppPage<OperationsServiceLog>> _serviceLogsFor(
    OperationsWorkItem item,
  ) async {
    final String? assetId = item.assetId;
    if (assetId == null || assetId.trim().isEmpty) {
      return _emptyServiceLogs();
    }

    final Result<AppPage<OperationsServiceLog>> result = await _repository
        .listServiceLogs(OperationsServiceLogQuery(assetId: assetId));
    return result.when(
      success: (AppPage<OperationsServiceLog> logs) => logs,
      failure: (_) => _emptyServiceLogs(),
    );
  }

  OperationsWorkItem? _selectedAfterRefresh(
    AppPage<OperationsWorkItem> page,
    OperationsWorkItem? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final OperationsWorkItem item in page.items) {
      if (_isSameWorkItem(item, selected)) {
        return item;
      }
    }
    return selected;
  }

  AppPage<OperationsWorkItem> _replaceWorkItem(
    AppPage<OperationsWorkItem> page,
    OperationsWorkItem replacement,
  ) {
    var replaced = false;
    final List<OperationsWorkItem> items = page.items
        .map((OperationsWorkItem item) {
          if (_isSameWorkItem(item, replacement)) {
            replaced = true;
            return replacement;
          }
          return item;
        })
        .toList(growable: true);

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<OperationsWorkItem>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  AppPage<OperationsServiceLog> _insertServiceLog(
    AppPage<OperationsServiceLog> page,
    OperationsServiceLog log,
  ) {
    final List<OperationsServiceLog> items = <OperationsServiceLog>[
      log,
      ...page.items.where((OperationsServiceLog item) => item.id != log.id),
    ];

    return AppPage<OperationsServiceLog>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameWorkItem(OperationsWorkItem left, OperationsWorkItem right) {
    return left.id == right.id ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  OperationsWorkspaceState? get _currentState {
    final Result<OperationsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<OperationsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(OperationsWorkspaceState nextState) {
    state = AsyncData<Result<OperationsWorkspaceState>>(
      Result<OperationsWorkspaceState>.success(nextState),
    );
  }
}

AppPage<OperationsAsset> _emptyAssets() {
  return const AppPage<OperationsAsset>(
    items: <OperationsAsset>[],
    request: AppPageRequest(pageSize: 50),
    totalItemCount: 0,
  );
}

AppPage<OperationsServiceLog> _emptyServiceLogs() {
  return const AppPage<OperationsServiceLog>(
    items: <OperationsServiceLog>[],
    request: AppPageRequest(pageSize: 10),
    totalItemCount: 0,
  );
}
