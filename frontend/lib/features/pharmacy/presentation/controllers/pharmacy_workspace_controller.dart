import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final pharmacyWorkspaceControllerProvider = AsyncNotifierProvider<
  PharmacyWorkspaceController,
  Result<PharmacyWorkspaceState>
>(PharmacyWorkspaceController.new);

final class PharmacyWorkspaceController
    extends AsyncNotifier<Result<PharmacyWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);

  PharmacyRepository get _repository => ref.read(pharmacyRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<PharmacyWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    final Result<PharmacyWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshDrugs: true);
  }

  Future<AppFailure?> applySearch(String search) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: search.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshingOrders: true,
        clearLastFailure: true,
      ),
    );
    return _refreshOrders(showLoading: true);
  }

  Future<AppFailure?> applyFilter(PharmacyOrderFilter filter) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    if (!filter.isBackendBacked) {
      return AppFailure.validation();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          filter: filter,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshingOrders: true,
        clearLastFailure: true,
      ),
    );
    return _refreshOrders(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshingOrders: true,
        clearLastFailure: true,
      ),
    );
    return _refreshOrders(showLoading: true);
  }

  Future<AppFailure?> selectOrder(PharmacyOrder order) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<PharmacyOrderWorkflow> result = await _repository
        .loadOrderWorkflow(order.id);
    return result.when(
      success: (PharmacyOrderWorkflow workflow) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              workbench: _replaceOrder(latest.workbench, workflow.order),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              isRefreshingDetail: false,
              lastFailure: failure,
            ),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> applyDrugSearch(String search) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        drugQuery: current.drugQuery.copyWith(
          search: search.trim(),
          pageRequest: current.drugQuery.pageRequest.first(),
        ),
        isRefreshingDrugs: true,
        clearLastFailure: true,
      ),
    );
    return _refreshDrugs(showLoading: true);
  }

  Future<AppFailure?> applyDrugStockStatus(String? stockStatus) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        drugQuery: current.drugQuery.copyWith(
          stockStatus: stockStatus,
          clearStockStatus: stockStatus == null,
          pageRequest: current.drugQuery.pageRequest.first(),
        ),
        isRefreshingDrugs: true,
        clearLastFailure: true,
      ),
    );
    return _refreshDrugs(showLoading: true);
  }

  Future<AppFailure?> changeDrugPage(AppPageRequest request) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        drugQuery: current.drugQuery.copyWith(pageRequest: request),
        isRefreshingDrugs: true,
        clearLastFailure: true,
      ),
    );
    return _refreshDrugs(showLoading: true);
  }

  Future<AppFailure?> prepareDispense({
    required List<PharmacyDispenseLineInput> items,
    String? dispenseBatchRef,
    String? statement,
    String? reason,
  }) {
    return _mutateSelected(
      (PharmacyOrderWorkflow workflow) => _repository.prepareDispense(
        orderId: workflow.order.id,
        items: items,
        dispenseBatchRef: dispenseBatchRef,
        statement: statement,
        reason: reason,
      ),
    );
  }

  Future<AppFailure?> attestDispense({
    required String dispenseBatchRef,
    String? statement,
    String? reason,
  }) {
    return _mutateSelected(
      (PharmacyOrderWorkflow workflow) => _repository.attestDispense(
        orderId: workflow.order.id,
        dispenseBatchRef: dispenseBatchRef,
        statement: statement,
        reason: reason,
        attestedAt: DateTime.now(),
      ),
      refreshDrugsAfter: true,
    );
  }

  Future<AppFailure?> cancelOrder({
    required String reason,
    String? notes,
  }) {
    return _mutateSelected(
      (PharmacyOrderWorkflow workflow) => _repository.cancelOrder(
        orderId: workflow.order.id,
        reason: reason,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> returnDispense({
    required List<PharmacyReturnLineInput> items,
    String? reason,
    String? notes,
  }) {
    return _mutateSelected(
      (PharmacyOrderWorkflow workflow) => _repository.returnDispense(
        orderId: workflow.order.id,
        items: items,
        reason: reason,
        notes: notes,
      ),
      refreshDrugsAfter: true,
    );
  }

  Future<Result<PharmacyWorkspaceState>> _loadInitialState() async {
    const PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery();
    const PharmacyDrugQuery drugQuery = PharmacyDrugQuery();
    final Result<PharmacyWorkbench> workbenchResult = await _repository
        .loadWorkbench(query);
    final PharmacyWorkbench? workbench = _successOrNull(workbenchResult);
    if (workbench == null) {
      return Result<PharmacyWorkspaceState>.failure(
        _failureOrNull(workbenchResult)!,
      );
    }

    final AppPage<PharmacyDrug> drugs = await _loadDrugPage(drugQuery);
    return Result<PharmacyWorkspaceState>.success(
      PharmacyWorkspaceState(
        query: query,
        workbench: workbench,
        drugQuery: drugQuery,
        drugs: drugs,
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
    bool refreshDrugs = false,
  }) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshingOrders: true,
          isRefreshingDetail: current.selectedWorkflow != null,
          isRefreshingDrugs: refreshDrugs,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshOrders(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      if (refreshDrugs) {
        await _refreshDrugs(showLoading: showLoading);
      }

      final PharmacyOrderWorkflow? selected = _currentState?.selectedWorkflow;
      if (selected != null) {
        await selectOrder(selected.order);
      }

      return null;
    } finally {
      final PharmacyWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(
            isRefreshingOrders: false,
            isRefreshingDetail: false,
            isRefreshingDrugs: false,
          ),
        );
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshOrders({required bool showLoading}) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<PharmacyWorkbench> result = await _repository.loadWorkbench(
      current.query,
    );
    return result.when(
      success: (PharmacyWorkbench workbench) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          final PharmacyOrderWorkflow? selected =
              _selectedAfterWorkbenchRefresh(
                workbench,
                latest.selectedWorkflow,
              );
          _emit(
            latest.copyWith(
              workbench: workbench,
              selectedWorkflow: selected,
              clearSelectedWorkflow:
                  latest.selectedWorkflow != null && selected == null,
              isRefreshingOrders: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingOrders: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshDrugs({required bool showLoading}) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<PharmacyDrug>> result = await _repository.searchDrugs(
      current.drugQuery,
    );
    return result.when(
      success: (AppPage<PharmacyDrug> drugs) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              drugs: drugs,
              isRefreshingDrugs: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDrugs: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppPage<PharmacyDrug>> _loadDrugPage(PharmacyDrugQuery query) async {
    final Result<AppPage<PharmacyDrug>> result = await _repository.searchDrugs(
      query,
    );
    return result.when(
      success: (AppPage<PharmacyDrug> drugs) => drugs,
      failure: (_) => AppPage<PharmacyDrug>(
        items: const <PharmacyDrug>[],
        request: query.pageRequest,
        totalItemCount: 0,
      ),
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<PharmacyMutationResult>> Function(
      PharmacyOrderWorkflow workflow,
    )
    action, {
    bool refreshDrugsAfter = false,
  }) async {
    final PharmacyWorkspaceState? current = _currentState;
    final PharmacyOrderWorkflow? workflow = current?.selectedWorkflow;
    if (current == null || workflow == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PharmacyMutationResult> result = await action(workflow);
    return result.when(
      success: (PharmacyMutationResult mutation) async {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: mutation.workflow,
              workbench: _replaceOrder(
                latest.workbench.copyWith(
                  summary: mutation.summary ?? latest.workbench.summary,
                ),
                mutation.workflow.order,
              ),
              isSaving: false,
            ),
          );
        }
        unawaited(_refreshOrders(showLoading: false));
        if (refreshDrugsAfter) {
          unawaited(_refreshDrugs(showLoading: false));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  PharmacyOrderWorkflow? _selectedAfterWorkbenchRefresh(
    PharmacyWorkbench workbench,
    PharmacyOrderWorkflow? selected,
  ) {
    if (selected == null) {
      return null;
    }

    for (final PharmacyOrder item in workbench.orders.items) {
      if (_isSameOrder(item, selected.order)) {
        return PharmacyOrderWorkflow(
          order: selected.order.copyWith(
            status: item.status,
            updatedAt: item.updatedAt,
            itemCount: item.itemCount,
            quantityPrescribedTotal: item.quantityPrescribedTotal,
            quantityDispensedTotal: item.quantityDispensedTotal,
            quantityPendingTotal: item.quantityPendingTotal,
            quantityReturnedTotal: item.quantityReturnedTotal,
            quantityRemainingTotal: item.quantityRemainingTotal,
            pendingAttestationBatchCount: item.pendingAttestationBatchCount,
            pendingAttestationBatches: item.pendingAttestationBatches,
          ),
          items: selected.items,
          attestations: selected.attestations,
          timeline: selected.timeline,
          nextActions: selected.nextActions,
        );
      }
    }

    return selected;
  }

  PharmacyWorkbench _replaceOrder(
    PharmacyWorkbench workbench,
    PharmacyOrder order,
  ) {
    var replaced = false;
    final List<PharmacyOrder> items = <PharmacyOrder>[];
    for (final PharmacyOrder item in workbench.orders.items) {
      if (_isSameOrder(item, order)) {
        if (!replaced) {
          items.add(order);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, order);
    }

    return workbench.copyWith(
      orders: AppPage<PharmacyOrder>(
        items: items
            .take(workbench.orders.request.pageSize)
            .toList(growable: false),
        request: workbench.orders.request,
        totalItemCount: workbench.orders.totalItemCount == null || replaced
            ? workbench.orders.totalItemCount
            : workbench.orders.totalItemCount! + 1,
      ),
    );
  }

  bool _isSameOrder(PharmacyOrder left, PharmacyOrder right) {
    return left.id == right.id ||
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

  PharmacyWorkspaceState? get _currentState {
    final Result<PharmacyWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<PharmacyWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(PharmacyWorkspaceState nextState) {
    state = AsyncData<Result<PharmacyWorkspaceState>>(
      Result<PharmacyWorkspaceState>.success(nextState),
    );
  }
}
