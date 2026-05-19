import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final labWorkspaceControllerProvider =
    AsyncNotifierProvider<LabWorkspaceController, Result<LabWorkspaceState>>(
      LabWorkspaceController.new,
    );

final class LabWorkspaceController
    extends AsyncNotifier<Result<LabWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);

  LabRepository get _repository => ref.read(labRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<LabWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.lab,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<LabWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshCatalogs: true);
  }

  Future<AppFailure?> applySearch(String value) async {
    final LabWorkspaceState? current = _currentState;
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
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyScope(LabQueueScope scope) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          scope: scope,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final LabWorkspaceState? current = _currentState;
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
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> selectOrder(LabOrderSummary order) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<LabOrderWorkflow> result = await _repository.loadOrderWorkflow(
      order.apiId,
    );
    return result.when(
      success: (LabOrderWorkflow workflow) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              worklist: _replaceOrder(latest.worklist, workflow.order),
              isRefreshingDetail: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createOrder(Map<String, Object?> payload) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.createOrder(payload);
    return result.when(
      success: (_) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false));
        }
        return _refreshWorkbench(showLoading: false);
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> collectSelected(Map<String, Object?> payload) {
    final LabOrderWorkflow? selected = _currentState?.selectedWorkflow;
    if (selected == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return _mutateWorkflow(
      () => _repository.collectOrder(selected.order.apiId, payload),
    );
  }

  Future<AppFailure?> receiveSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.receiveSample(sampleId, payload));
  }

  Future<AppFailure?> rejectSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.rejectSample(sampleId, payload));
  }

  Future<AppFailure?> releaseOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.releaseOrderItem(itemId, payload));
  }

  Future<AppFailure?> reverseSelected(Map<String, Object?> payload) {
    final LabOrderWorkflow? selected = _currentState?.selectedWorkflow;
    if (selected == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return _mutateWorkflow(
      () => _repository.reverseWorkflow(selected.order.apiId, payload),
    );
  }

  Future<AppFailure?> createQcLog(Map<String, Object?> payload) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.createQcLog(payload);
    return result.when(
      success: (_) async {
        final List<LabQcLog> qcLogs = await _qcLogs();
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(qcLogs: qcLogs, isSaving: false));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<Result<LabWorkspaceState>> _loadInitialState() async {
    const LabWorkbenchQuery query = LabWorkbenchQuery();
    final Result<LabWorkbenchBundle> workbenchResult = await _repository
        .loadWorkbench(query);

    final LabWorkbenchBundle? workbench = _successOrNull(workbenchResult);
    if (workbench == null) {
      return Result<LabWorkspaceState>.failure(
        _failureOrNull(workbenchResult)!,
      );
    }

    final _LabReferenceData referenceData = await _referenceData();
    LabOrderWorkflow? selectedWorkflow;
    if (workbench.worklist.items.isNotEmpty) {
      final Result<LabOrderWorkflow> detailResult = await _repository
          .loadOrderWorkflow(workbench.worklist.items.first.apiId);
      selectedWorkflow = _successOrNull(detailResult);
    }

    return Result<LabWorkspaceState>.success(
      LabWorkspaceState(
        query: query,
        summary: workbench.summary,
        worklist: workbench.worklist,
        catalogTests: referenceData.tests,
        catalogPanels: referenceData.panels,
        qcLogs: referenceData.qcLogs,
        selectedWorkflow: selectedWorkflow,
      ),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshCatalogs = false,
  }) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedWorkflow != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshWorkbench(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      if (refreshCatalogs) {
        final _LabReferenceData referenceData = await _referenceData();
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              catalogTests: referenceData.tests,
              catalogPanels: referenceData.panels,
              qcLogs: referenceData.qcLogs,
            ),
          );
        }
      }

      final LabOrderWorkflow? selected = _currentState?.selectedWorkflow;
      if (selected != null) {
        final Result<LabOrderWorkflow> detailResult = await _repository
            .loadOrderWorkflow(selected.order.apiId);
        detailResult.when(
          success: (LabOrderWorkflow workflow) {
            final LabWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  selectedWorkflow: workflow,
                  worklist: _replaceOrder(latest.worklist, workflow.order),
                ),
              );
            }
          },
          failure: (_) {},
        );
      }

      return null;
    } finally {
      final LabWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorkbench({required bool showLoading}) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<LabWorkbenchBundle> result = await _repository.loadWorkbench(
      current.query,
    );
    return result.when(
      success: (LabWorkbenchBundle bundle) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          final LabOrderWorkflow? selected = _selectedAfterRefresh(
            bundle.worklist,
            latest.selectedWorkflow,
          );
          _emit(
            latest.copyWith(
              summary: bundle.summary,
              worklist: bundle.worklist,
              selectedWorkflow: selected,
              isRefreshing: false,
              clearSelectedWorkflow:
                  latest.selectedWorkflow != null && selected == null,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateWorkflow(
    Future<Result<LabOrderWorkflow>> Function() submit,
  ) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<LabOrderWorkflow> result = await submit();
    return result.when(
      success: (LabOrderWorkflow workflow) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              worklist: _replaceOrder(latest.worklist, workflow.order),
              isSaving: false,
            ),
          );
        }
        unawaited(_refreshWorkbench(showLoading: false));
        return null;
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<_LabReferenceData> _referenceData() async {
    final List<LabCatalogItem> tests = await _tests();
    final List<LabCatalogItem> panels = await _panels();
    final List<LabQcLog> qcLogs = await _qcLogs();
    return _LabReferenceData(tests: tests, panels: panels, qcLogs: qcLogs);
  }

  Future<List<LabCatalogItem>> _tests() async {
    final Result<List<LabCatalogItem>> result = await _repository.listTests();
    return result.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (_) => const <LabCatalogItem>[],
    );
  }

  Future<List<LabCatalogItem>> _panels() async {
    final Result<List<LabCatalogItem>> result = await _repository.listPanels();
    return result.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (_) => const <LabCatalogItem>[],
    );
  }

  Future<List<LabQcLog>> _qcLogs() async {
    final Result<List<LabQcLog>> result = await _repository.listQcLogs();
    return result.when(
      success: (List<LabQcLog> value) => value,
      failure: (_) => const <LabQcLog>[],
    );
  }

  LabOrderWorkflow? _selectedAfterRefresh(
    AppPage<LabOrderSummary> page,
    LabOrderWorkflow? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final LabOrderSummary order in page.items) {
      if (_isSameOrder(order, selected.order)) {
        return selected.copyWithSummary(order);
      }
    }
    return selected;
  }

  AppPage<LabOrderSummary> _replaceOrder(
    AppPage<LabOrderSummary> page,
    LabOrderSummary replacement,
  ) {
    var replaced = false;
    final List<LabOrderSummary> items = <LabOrderSummary>[];
    for (final LabOrderSummary item in page.items) {
      if (_isSameOrder(item, replacement)) {
        if (!replaced) {
          items.add(replacement);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<LabOrderSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null || replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameOrder(LabOrderSummary left, LabOrderSummary right) {
    return left.id == right.id ||
        left.apiId == right.apiId ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  LabWorkspaceState? get _currentState {
    final Result<LabWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<LabWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(LabWorkspaceState nextState) {
    state = AsyncData<Result<LabWorkspaceState>>(
      Result<LabWorkspaceState>.success(nextState),
    );
  }
}

extension on LabOrderWorkflow {
  LabOrderWorkflow copyWithSummary(LabOrderSummary order) {
    return LabOrderWorkflow(
      order: order,
      results: results,
      timeline: timeline,
      nextActions: nextActions,
    );
  }
}

final class _LabReferenceData {
  const _LabReferenceData({
    required this.tests,
    required this.panels,
    required this.qcLogs,
  });

  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> panels;
  final List<LabQcLog> qcLogs;
}
