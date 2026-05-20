import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final biomedicalWorkspaceControllerProvider =
    AsyncNotifierProvider<
      BiomedicalWorkspaceController,
      Result<BiomedicalWorkspaceState>
    >(BiomedicalWorkspaceController.new);

final class BiomedicalWorkspaceController
    extends AsyncNotifier<Result<BiomedicalWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 15);

  BiomedicalRepository get _repository =>
      ref.read(biomedicalRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<BiomedicalWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.biomedical,
      onRefresh: (_) => _syncVisibleData(),
    );
    final Result<BiomedicalWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true);
  }

  Future<AppFailure?> applySearch(String value) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        search: value.trim(),
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyPanel(String panel) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        panel: panel,
        clearQueue: true,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyQueue(BiomedicalQueueSummary queue) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        panel: queue.panel,
        resource: queue.resource,
        queue: queue.queue,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyStatus(String? status) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        status: status,
        clearStatus: status == null,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyPriority(String? priority) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        priority: priority,
        clearPriority: priority == null,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyFacility(String? facilityId) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        facilityId: facilityId,
        clearFacility: facilityId == null,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyDatePreset(String? datePreset) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        datePreset: datePreset,
        clearDatePreset: datePreset == null,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyFilters({
    required String panel,
    String? status,
    String? priority,
    String? facilityId,
    String? datePreset,
  }) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(
        panel: panel,
        status: status,
        priority: priority,
        facilityId: facilityId,
        datePreset: datePreset,
        clearQueue: true,
        clearStatus: status == null,
        clearPriority: priority == null,
        clearFacility: facilityId == null,
        clearDatePreset: datePreset == null,
        pageRequest: query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> clearFilters() {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) =>
          BiomedicalWorkspaceQuery(pageRequest: query.pageRequest.first()),
    );
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    return _applyQuery(
      (BiomedicalWorkspaceQuery query) => query.copyWith(pageRequest: request),
    );
  }

  void selectAsset(BiomedicalAsset asset) {
    final BiomedicalWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(selectedAsset: asset, clearLastFailure: true));
  }

  Future<AppFailure?> saveAsset(
    Map<String, Object?> payload, {
    BiomedicalAsset? existing,
  }) {
    if (existing == null) {
      return _mutate(
        () =>
            _repository.createResource(BiomedicalResources.registries, payload),
      );
    }

    return _mutate(
      () => _repository.updateResource(
        BiomedicalResources.registries,
        existing.displayId,
        payload,
      ),
    );
  }

  Future<AppFailure?> transferLocation(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.locationHistories,
        payload,
      ),
    );
  }

  Future<AppFailure?> scheduleMaintenance(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.maintenancePlans,
        payload,
      ),
    );
  }

  Future<AppFailure?> saveWorkOrder(
    Map<String, Object?> payload, {
    BiomedicalAsset? existing,
  }) {
    if (existing != null &&
        existing.resource == BiomedicalResources.workOrders) {
      return _mutate(
        () => _repository.updateResource(
          BiomedicalResources.workOrders,
          existing.displayId,
          payload,
        ),
      );
    }

    return _mutate(
      () => _repository.createResource(BiomedicalResources.workOrders, payload),
    );
  }

  Future<AppFailure?> startWorkOrder(
    BiomedicalAsset asset,
    Map<String, Object?> payload,
  ) {
    return _mutate(() => _repository.startWorkOrder(asset.displayId, payload));
  }

  Future<AppFailure?> returnToService(
    BiomedicalAsset asset,
    Map<String, Object?> payload,
  ) {
    return _mutate(() => _repository.returnToService(asset.displayId, payload));
  }

  Future<AppFailure?> recordCalibration(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.calibrationLogs,
        payload,
      ),
    );
  }

  Future<AppFailure?> recordSafetyTest(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.safetyTestLogs,
        payload,
      ),
    );
  }

  Future<AppFailure?> reportDowntime(Map<String, Object?> payload) {
    return _mutate(
      () =>
          _repository.createResource(BiomedicalResources.downtimeLogs, payload),
    );
  }

  Future<AppFailure?> closeDowntime(
    BiomedicalAsset asset,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.updateResource(
        BiomedicalResources.downtimeLogs,
        asset.displayId,
        payload,
      ),
    );
  }

  Future<AppFailure?> logIncident(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.incidentReports,
        payload,
      ),
    );
  }

  Future<AppFailure?> acknowledgeRecall(
    BiomedicalAsset asset,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.updateResource(
        BiomedicalResources.recallNotices,
        asset.displayId,
        payload,
      ),
    );
  }

  Future<AppFailure?> disposeOrTransfer(Map<String, Object?> payload) {
    return _mutate(
      () => _repository.createResource(
        BiomedicalResources.disposalTransfers,
        payload,
      ),
    );
  }

  Future<AppFailure?> createFaultReport(Map<String, Object?> payload) {
    return _mutate(() => _repository.createFaultReport(payload));
  }

  Future<Result<BiomedicalWorkspaceState>> _loadInitialState() async {
    const BiomedicalWorkspaceQuery query = BiomedicalWorkspaceQuery();
    final Result<BiomedicalWorkbench> result = await _repository.getWorkspace(
      query,
    );

    return result.when(
      success: (BiomedicalWorkbench workbench) {
        return Result<BiomedicalWorkspaceState>.success(
          BiomedicalWorkspaceState(
            workbench: workbench,
            query: query,
            selectedAsset: workbench.assets.items.isEmpty
                ? null
                : workbench.assets.items.first,
          ),
        );
      },
      failure: (AppFailure failure) {
        return Result<BiomedicalWorkspaceState>.failure(failure);
      },
    );
  }

  Future<AppFailure?> _applyQuery(
    BiomedicalWorkspaceQuery Function(BiomedicalWorkspaceQuery query) transform,
  ) async {
    final BiomedicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: transform(current.query),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({bool showLoading = false}) async {
    final BiomedicalWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    }

    try {
      return await _refreshWorkbench(showLoading: showLoading);
    } finally {
      final BiomedicalWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorkbench({required bool showLoading}) async {
    final BiomedicalWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<BiomedicalWorkbench> result = await _repository.getWorkspace(
      current.query,
    );
    return result.when(
      success: (BiomedicalWorkbench workbench) {
        final BiomedicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              workbench: workbench,
              selectedAsset: _selectedAfterRefresh(
                workbench.assets,
                latest.selectedAsset,
              ),
              clearSelectedAsset: workbench.assets.items.isEmpty,
              isRefreshing: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final BiomedicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutate(
    Future<Result<BiomedicalMutationResult>> Function() submit,
  ) async {
    final BiomedicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<BiomedicalMutationResult> result = await submit();
    return result.when(
      success: (BiomedicalMutationResult mutation) async {
        final BiomedicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          final BiomedicalAsset? replacement = mutation.asset;
          _emit(
            latest.copyWith(
              workbench: replacement == null
                  ? latest.workbench
                  : BiomedicalWorkbench(
                      summary: latest.workbench.summary,
                      queues: latest.workbench.queues,
                      panels: latest.workbench.panels,
                      lookups: latest.workbench.lookups,
                      assets: _replaceAsset(
                        latest.workbench.assets,
                        replacement,
                      ),
                      spotlight: latest.workbench.spotlight,
                    ),
              selectedAsset: replacement ?? latest.selectedAsset,
              isMutating: false,
            ),
          );
        }
        await _refreshWorkbench(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) {
        final BiomedicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  BiomedicalAsset? _selectedAfterRefresh(
    AppPage<BiomedicalAsset> page,
    BiomedicalAsset? selected,
  ) {
    if (page.items.isEmpty) {
      return null;
    }
    if (selected == null) {
      return page.items.first;
    }
    for (final BiomedicalAsset asset in page.items) {
      if (_isSameAsset(asset, selected)) {
        return asset;
      }
    }
    return selected;
  }

  AppPage<BiomedicalAsset> _replaceAsset(
    AppPage<BiomedicalAsset> page,
    BiomedicalAsset replacement,
  ) {
    var replaced = false;
    final List<BiomedicalAsset> items = page.items
        .map((BiomedicalAsset item) {
          if (_isSameAsset(item, replacement)) {
            replaced = true;
            return replacement;
          }
          return item;
        })
        .toList(growable: true);

    if (!replaced && page.request.pageIndex == 0) {
      items.insert(0, replacement);
    }

    return AppPage<BiomedicalAsset>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameAsset(BiomedicalAsset left, BiomedicalAsset right) {
    return left.id == right.id ||
        left.displayId == right.displayId ||
        (left.humanFriendlyId != null &&
            left.humanFriendlyId == right.humanFriendlyId);
  }

  BiomedicalWorkspaceState? get _currentState {
    final Result<BiomedicalWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<BiomedicalWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(BiomedicalWorkspaceState nextState) {
    state = AsyncData<Result<BiomedicalWorkspaceState>>(
      Result<BiomedicalWorkspaceState>.success(nextState),
    );
  }
}
