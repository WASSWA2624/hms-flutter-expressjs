import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final labWorkspaceControllerProvider =
    AsyncNotifierProvider<LabWorkspaceController, Result<LabWorkspaceState>>(
      LabWorkspaceController.new,
    );

typedef _LabOrderItemResultEntry = ({
  LabOrderItem item,
  Map<String, Object?> payload,
});

typedef _LabOrderItemResultGroup = ({
  LabOrderWorkflow workflow,
  List<_LabOrderItemResultEntry> entries,
});

typedef _LabOrderItemResultPersister =
    Future<Result<void>> Function(
      LabOrderItem item,
      Map<String, Object?> payload,
    );

@immutable
final class LabBatchPersistOutcome {
  const LabBatchPersistOutcome({
    this.savedCount = 0,
    this.skippedCount = 0,
    this.lastFailure,
    this.failedItemIds = const <String>[],
  });

  final int savedCount;
  final int skippedCount;
  final AppFailure? lastFailure;
  final List<String> failedItemIds;

  bool get hasSavedEntries => savedCount > 0;
  bool get hasSkippedEntries => skippedCount > 0;
}

final class LabWorkspaceController
    extends AsyncNotifier<Result<LabWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);

  LabRepository get _repository => ref.read(labRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;
  int _workbenchRefreshSequence = 0;

  @override
  Future<Result<LabWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.lab,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<LabWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    if (result.isSuccess) {
      _startSync();
    }
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() async {
    if (_currentState == null) {
      state = const AsyncLoading<Result<LabWorkspaceState>>();
      final Result<LabWorkspaceState> result = await runWorkspaceInitialLoad(
        ref,
        _loadInitialState,
      );
      state = AsyncData<Result<LabWorkspaceState>>(result);
      if (result.isSuccess) {
        _startSync();
      }
      return _failureOrNull(result);
    }

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

  Future<AppFailure?> applyView(LabWorkbenchView view) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          view: view,
          scope: LabQueueScope.all,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedWorkflow: true,
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

  Future<AppFailure?> selectOrder(LabOrderSummary order) {
    if (order.isPatientGroup) {
      final List<String> orderIds = _workflowIdentifiersFor(order);
      if (orderIds.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return selectOrdersById(orderIds);
    }

    final String? orderId = _workflowIdentifierFor(order);
    if (orderId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return selectOrderById(orderId);
  }

  Future<AppFailure?> selectOrdersById(List<String> orderIds) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final List<String> distinctOrderIds = _distinctNonEmpty(orderIds);
    if (distinctOrderIds.isEmpty) {
      return AppFailure.validation();
    }

    if (distinctOrderIds.length == 1) {
      return selectOrderById(distinctOrderIds.first);
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final List<LabOrderWorkflow> workflows = <LabOrderWorkflow>[];
    AppFailure? failure;
    for (final String orderId in distinctOrderIds) {
      final Result<LabOrderWorkflow> result = await _repository
          .loadOrderWorkflow(orderId);
      result.when(
        success: workflows.add,
        failure: (AppFailure value) => failure ??= value,
      );
    }

    final LabWorkspaceState? latest = _currentState;
    if (latest == null) {
      return failure;
    }

    if (workflows.isEmpty) {
      _emit(latest.copyWith(isRefreshingDetail: false, lastFailure: failure));
      return failure ?? AppFailure.validation();
    }

    _emit(
      latest.copyWith(
        selectedWorkflow: workflows.first,
        selectedWorkflows: workflows,
        worklist: _replaceOrders(latest.worklist, workflows),
        isRefreshingDetail: false,
        lastFailure: failure,
        clearLastFailure: failure == null,
      ),
    );
    return failure;
  }

  Future<AppFailure?> selectOrderById(String orderId) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<LabOrderWorkflow> result = await _repository.loadOrderWorkflow(
      orderId,
    );
    return result.when(
      success: (LabOrderWorkflow workflow) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              selectedWorkflows: <LabOrderWorkflow>[workflow],
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

  Future<AppFailure?> updateOrder(
    String orderId,
    Map<String, Object?> payload,
  ) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.updateOrder(orderId, payload);
    return result.when(
      success: (_) async {
        final Result<LabOrderWorkflow> workflowResult = await _repository
            .loadOrderWorkflow(orderId);
        return workflowResult.when(
          success: (LabOrderWorkflow workflow) async {
            final LabWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  selectedWorkflow: workflow,
                  selectedWorkflows: _replaceSelectedWorkflow(
                    latest.selectedWorkflows,
                    workflow,
                  ),
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

  Future<AppFailure?> deleteOrder(String orderId, String reason) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.deleteOrder(orderId, reason);
    return result.when(
      success: (_) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          final List<LabOrderWorkflow> remainingWorkflows = latest
              .selectedWorkflows
              .where(
                (LabOrderWorkflow workflow) =>
                    !_orderMatchesIdentifier(workflow.order, orderId),
              )
              .toList(growable: false);
          _emit(
            latest.copyWith(
              worklist: _removeOrder(latest.worklist, orderId),
              selectedWorkflow: remainingWorkflows.isEmpty
                  ? null
                  : remainingWorkflows.first,
              selectedWorkflows: remainingWorkflows,
              isSaving: false,
              clearSelectedWorkflow: remainingWorkflows.isEmpty,
            ),
          );
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

  Future<AppFailure?> updateLabPanel(
    String panelId,
    Map<String, Object?> payload,
  ) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<LabCatalogItem> result = await _repository
        .upsertFacilityLabPanelOffering(
          panelId,
          payload,
          tenantId: current.catalogScope?.tenantId,
          facilityId: current.catalogScope?.facilityId,
        );
    return result.when(
      success: (LabCatalogItem updated) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          final List<LabCatalogItem> panels = <LabCatalogItem>[
            for (final LabCatalogItem item in latest.catalogPanels)
              item.id == updated.id ||
                      item.apiId == updated.apiId ||
                      item.apiId == panelId
                  ? updated
                  : item,
          ];
          _emit(latest.copyWith(catalogPanels: panels, isSaving: false));
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

  Future<AppFailure?> deleteLabTest(String testId, String reason) {
    final LabCatalogScope? scope = _currentState?.catalogScope;
    return _disableFacilityCatalogItem(
      () => _repository.disableFacilityLabTestOffering(
        testId,
        reason,
        tenantId: scope?.tenantId,
        facilityId: scope?.facilityId,
      ),
      testId: testId,
    );
  }

  Future<AppFailure?> deleteLabPanel(String panelId, String reason) {
    final LabCatalogScope? scope = _currentState?.catalogScope;
    return _disableFacilityCatalogItem(
      () => _repository.disableFacilityLabPanelOffering(
        panelId,
        reason,
        tenantId: scope?.tenantId,
        facilityId: scope?.facilityId,
      ),
      panelId: panelId,
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
    return verifyOrderItem(itemId, payload);
  }

  Future<AppFailure?> verifyOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.verifyOrderItem(itemId, payload));
  }

  Future<AppFailure?> verifyAllResults(
    String orderId,
    List<Map<String, Object?>> results,
  ) {
    return _mutateWorkflow(
      () => _repository.verifyOrderResults(orderId, results),
    );
  }

  Future<LabBatchPersistOutcome> submitOrderItemResults(
    List<({LabOrderItem item, Map<String, Object?> payload})> entries,
  ) async {
    return _persistOrderItemResultEntries(entries, (
      LabOrderItem item,
      Map<String, Object?> payload,
    ) async {
      final Result<LabOrderWorkflow> result = await _repository.verifyOrderItem(
        item.apiId,
        payload,
      );
      return result.when(
        success: (_) => const Result<void>.success(null),
        failure: Result.failure,
      );
    });
  }

  Future<AppFailure?> saveOrderItemDraft(
    LabOrderItem item,
    Map<String, Object?> payload,
  ) {
    final LabOrderWorkflow? selected = _workflowForItem(item);
    if (selected == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateWorkflow(() async {
      final Result<void> saveResult = await _saveOrderItemDraftResult(
        item,
        payload,
      );

      return saveResult.when(
        success: (_) => _repository.loadOrderWorkflow(selected.order.apiId),
        failure: Result.failure,
      );
    });
  }

  Future<LabBatchPersistOutcome> saveOrderItemDrafts(
    List<({LabOrderItem item, Map<String, Object?> payload})> entries,
  ) async {
    return _persistOrderItemResultEntries(entries, _saveOrderItemDraftResult);
  }

  Future<AppFailure?> submitOrderItemDraft(
    LabOrderItem item,
    Map<String, Object?> payload,
  ) {
    final LabOrderWorkflow? selected = _workflowForItem(item);
    if (selected == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateWorkflow(() async {
      final Result<void> submitResult = await _upsertOrderItemResult(
        item,
        payload,
      );

      return submitResult.when(
        success: (_) => _repository.loadOrderWorkflow(selected.order.apiId),
        failure: Result.failure,
      );
    });
  }

  Future<LabBatchPersistOutcome> submitOrderItemDrafts(
    List<({LabOrderItem item, Map<String, Object?> payload})> entries,
  ) async {
    return _persistOrderItemResultEntries(entries, _upsertOrderItemResult);
  }

  Future<AppFailure?> removeOrderItemDraftResult(LabOrderItem item) {
    final String? resultId = item.resultId;
    final LabOrderWorkflow? selected = _workflowForItem(item);
    if (resultId == null || selected == null || item.isCompleted) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateWorkflow(() async {
      final Result<void> deleteResult = await _repository.deleteLabResult(
        resultId,
      );
      return deleteResult.when(
        success: (_) => _repository.loadOrderWorkflow(selected.order.apiId),
        failure: Result.failure,
      );
    });
  }

  Future<AppFailure?> rejectOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.rejectOrderItem(itemId, payload));
  }

  Future<AppFailure?> reopenOrderItemResult(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(
      () => _repository.reopenOrderItemResult(itemId, payload),
    );
  }

  Future<AppFailure?> restoreOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(() => _repository.restoreOrderItem(itemId, payload));
  }

  Future<AppFailure?> deleteOrderItems(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _mutateWorkflow(
      () => _repository.deleteOrderItems(orderId, payload),
    );
  }

  Future<LabBatchPersistOutcome> _persistOrderItemResultEntries(
    List<_LabOrderItemResultEntry> entries,
    _LabOrderItemResultPersister persist,
  ) async {
    if (entries.isEmpty) {
      return LabBatchPersistOutcome(
        lastFailure: AppFailure.validation(code: 'lab.result.no_entries'),
      );
    }

    final Map<String, _LabOrderItemResultGroup> entriesByOrder =
        <String, _LabOrderItemResultGroup>{};
    final List<String> unresolvedItemIds = <String>[];
    for (final _LabOrderItemResultEntry entry in entries) {
      final LabOrderWorkflow? workflow = _workflowForItem(entry.item);
      if (workflow == null) {
        unresolvedItemIds.add(entry.item.apiId);
        continue;
      }
      entriesByOrder
          .putIfAbsent(
            workflow.order.apiId,
            () => (workflow: workflow, entries: <_LabOrderItemResultEntry>[]),
          )
          .entries
          .add(entry);
    }

    if (entriesByOrder.isEmpty) {
      return LabBatchPersistOutcome(
        skippedCount: unresolvedItemIds.length,
        lastFailure: AppFailure.validation(
          code: 'lab.result.order_not_selected',
        ),
        failedItemIds: unresolvedItemIds,
      );
    }

    var savedCount = 0;
    var skippedCount = unresolvedItemIds.length;
    AppFailure? lastFailure;
    final List<String> failedItemIds = <String>[...unresolvedItemIds];
    for (final _LabOrderItemResultGroup group in entriesByOrder.values) {
      var groupSavedCount = 0;
      for (final _LabOrderItemResultEntry entry in group.entries) {
        final Result<void> result = await persist(entry.item, entry.payload);
        final AppFailure? itemFailure = result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
        if (itemFailure != null) {
          skippedCount += 1;
          failedItemIds.add(entry.item.apiId);
          lastFailure = itemFailure;
          continue;
        }
        groupSavedCount += 1;
        savedCount += 1;
      }
      if (groupSavedCount > 0) {
        final AppFailure? refreshFailure = await _refreshSelectedWorkflow(
          group.workflow.order.apiId,
        );
        if (refreshFailure != null) {
          lastFailure = refreshFailure;
        }
      }
    }
    return LabBatchPersistOutcome(
      savedCount: savedCount,
      skippedCount: skippedCount,
      lastFailure: lastFailure,
      failedItemIds: failedItemIds,
    );
  }

  Future<AppFailure?> _refreshSelectedWorkflow(String orderId) async {
    final Result<LabOrderWorkflow> result = await _repository.loadOrderWorkflow(
      orderId,
    );
    return result.when(
      success: (LabOrderWorkflow workflow) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              selectedWorkflows: _replaceSelectedWorkflow(
                latest.selectedWorkflows.isNotEmpty
                    ? latest.selectedWorkflows
                    : latest.selectedWorkflow == null
                    ? const <LabOrderWorkflow>[]
                    : <LabOrderWorkflow>[latest.selectedWorkflow!],
                workflow,
              ),
              worklist: _replaceOrder(latest.worklist, workflow.order),
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Map<String, Object?> _interpretationPayloadFields(
    Map<String, Object?> payload,
  ) {
    return <String, Object?>{
      if (payload.containsKey('interpretation_override'))
        'interpretation_override': payload['interpretation_override'],
      if (payload.containsKey('reference_range_override'))
        'reference_range_override': payload['reference_range_override'],
      if (payload.containsKey('result_flag_override'))
        'result_flag_override': payload['result_flag_override'],
    };
  }

  Future<Result<void>> _saveOrderItemDraftResult(
    LabOrderItem item,
    Map<String, Object?> payload,
  ) {
    final bool shouldSaveAsPending = !item.isCompleted;
    final Map<String, Object?> draftPayload = <String, Object?>{
      if (shouldSaveAsPending) 'status': 'PENDING',
      if (payload.containsKey('result_value'))
        'result_value': payload['result_value'],
      if (payload.containsKey('result_unit'))
        'result_unit': payload['result_unit'],
      if (payload.containsKey('result_text'))
        'result_text': payload['result_text'],
      ..._interpretationPayloadFields(payload),
    };
    return _upsertOrderItemResult(item, draftPayload);
  }

  Future<Result<void>> _upsertOrderItemResult(
    LabOrderItem item,
    Map<String, Object?> payload,
  ) {
    return item.resultId == null
        ? _repository.createLabResult(<String, Object?>{
            ...payload,
            'lab_order_item_id': item.apiId,
          })
        : _repository.updateLabResult(item.resultId!, payload);
  }

  Future<AppFailure?> updateLabTest(
    String testId,
    Map<String, Object?> payload,
  ) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<LabCatalogItem> result = await _repository
        .upsertFacilityLabTestOffering(
          testId,
          payload,
          tenantId: current.catalogScope?.tenantId,
          facilityId: current.catalogScope?.facilityId,
        );
    return result.when(
      success: (LabCatalogItem updated) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          final List<LabCatalogItem> tests = <LabCatalogItem>[
            for (final LabCatalogItem item in latest.catalogTests)
              item.id == updated.id ||
                      item.apiId == updated.apiId ||
                      item.apiId == testId
                  ? updated
                  : item,
          ];
          _emit(latest.copyWith(catalogTests: tests, isSaving: false));
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

    LabOrderWorkflow? selectedWorkflow;
    List<LabOrderWorkflow> selectedWorkflows = const <LabOrderWorkflow>[];
    if (workbench.worklist.items.isNotEmpty) {
      final String? initialOrderId = _workflowIdentifierFor(
        workbench.worklist.items.first,
      );
      if (initialOrderId != null) {
        final Result<LabOrderWorkflow> detailResult = await _repository
            .loadOrderWorkflow(initialOrderId);
        selectedWorkflow = _successOrNull(detailResult);
        if (selectedWorkflow != null) {
          selectedWorkflows = <LabOrderWorkflow>[selectedWorkflow];
        }
      }
    }

    final List<LabQcLog> qcLogs = await _qcLogs();
    return Result<LabWorkspaceState>.success(
      LabWorkspaceState(
        query: query,
        summary: workbench.summary,
        worklist: workbench.worklist,
        qcLogs: qcLogs,
        selectedWorkflow: selectedWorkflow,
        selectedWorkflows: selectedWorkflows,
      ),
    );
  }

  Future<AppFailure?> loadFacilityCatalogConfig(LabCatalogScope scope) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    if (!scope.isReady) {
      _emit(
        current.copyWith(
          catalogScope: scope,
          catalogTests: const <LabCatalogItem>[],
          catalogPanels: const <LabCatalogItem>[],
          isLoadingCatalog: false,
          clearCatalogLoadFailure: true,
        ),
      );
      return null;
    }

    _emit(
      current.copyWith(
        catalogScope: scope,
        isLoadingCatalog: true,
        clearCatalogLoadFailure: true,
      ),
    );
    final Result<List<LabCatalogItem>> testsResult = await _repository
        .listFacilityLabTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          limit: 200,
        );
    final Result<List<LabCatalogItem>> panelsResult = await _repository
        .listFacilityLabPanels(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          limit: 200,
        );

    AppFailure? failure;
    final List<LabCatalogItem> tests = testsResult.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (AppFailure value) {
        failure ??= value;
        return const <LabCatalogItem>[];
      },
    );
    final List<LabCatalogItem> panels = panelsResult.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (AppFailure value) {
        failure ??= value;
        return const <LabCatalogItem>[];
      },
    );
    final LabWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          catalogTests: tests,
          catalogPanels: panels,
          catalogScope: scope,
          isLoadingCatalog: false,
          catalogLoadFailure: failure,
          clearCatalogLoadFailure: failure == null,
        ),
      );
    }
    return failure;
  }

  Future<Result<List<LabCatalogItem>>> searchFacilityLabCatalog({
    required String termType,
    String? query,
    int limit = 25,
  }) {
    final LabCatalogScope? scope = _currentState?.catalogScope;
    return _repository.searchFacilityLabCatalog(
      termType: termType,
      tenantId: scope?.tenantId,
      facilityId: scope?.facilityId,
      query: query,
      limit: limit,
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
        final List<LabQcLog> qcLogs = await _qcLogs();
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          final bool catalogsLoaded =
              latest.catalogTests.isNotEmpty || latest.catalogPanels.isNotEmpty;
          if (catalogsLoaded) {
            final List<LabCatalogItem> tests = await _facilityTests();
            final List<LabCatalogItem> panels = await _facilityPanels();
            _emit(
              latest.copyWith(
                catalogTests: tests,
                catalogPanels: panels,
                qcLogs: qcLogs,
              ),
            );
          } else {
            _emit(latest.copyWith(qcLogs: qcLogs));
          }
        }
      }

      final List<LabOrderWorkflow> selectedWorkflows =
          _currentSelectedWorkflows();
      if (selectedWorkflows.isNotEmpty) {
        final List<LabOrderWorkflow> refreshed = <LabOrderWorkflow>[];
        for (final LabOrderWorkflow selected in selectedWorkflows) {
          final Result<LabOrderWorkflow> detailResult = await _repository
              .loadOrderWorkflow(selected.order.apiId);
          detailResult.when(success: refreshed.add, failure: (_) {});
        }
        if (refreshed.isNotEmpty) {
          final LabWorkspaceState? latest = _currentState;
          if (latest != null) {
            _emit(
              latest.copyWith(
                selectedWorkflow: refreshed.first,
                selectedWorkflows: refreshed,
                worklist: _replaceOrders(latest.worklist, refreshed),
              ),
            );
          }
        }
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

    final int requestSequence = ++_workbenchRefreshSequence;
    final LabWorkbenchQuery requestedQuery = current.query;
    final Result<LabWorkbenchBundle> result = await _repository.loadWorkbench(
      requestedQuery,
    );
    return result.when(
      success: (LabWorkbenchBundle bundle) {
        final LabWorkspaceState? latest = _currentState;
        if (latest == null ||
            requestSequence != _workbenchRefreshSequence ||
            !_isSameQuery(latest.query, requestedQuery)) {
          return null;
        }

        final LabOrderWorkflow? selected = _selectedAfterRefresh(
          bundle.worklist,
          latest.selectedWorkflow,
        );
        final List<LabOrderWorkflow> selectedWorkflows =
            _selectedWorkflowsAfterRefresh(
              bundle.worklist,
              latest.selectedWorkflows,
            );
        _emit(
          latest.copyWith(
            summary: bundle.summary,
            worklist: bundle.worklist,
            selectedWorkflow: selectedWorkflows.isNotEmpty
                ? selectedWorkflows.first
                : selected,
            selectedWorkflows: selectedWorkflows,
            isRefreshing: false,
            clearSelectedWorkflow:
                latest.selectedWorkflow != null &&
                selected == null &&
                selectedWorkflows.isEmpty,
            clearLastFailure: true,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null &&
            requestSequence == _workbenchRefreshSequence &&
            _isSameQuery(latest.query, requestedQuery)) {
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
              selectedWorkflows: _replaceSelectedWorkflow(
                latest.selectedWorkflows,
                workflow,
              ),
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

  Future<List<LabCatalogItem>> _facilityTests({String? search}) async {
    final LabCatalogScope? scope = _currentState?.catalogScope;
    final Result<List<LabCatalogItem>> result = await _repository
        .listFacilityLabTests(
          tenantId: scope?.tenantId,
          facilityId: scope?.facilityId,
          search: search,
          limit: 200,
        );
    return result.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (_) => const <LabCatalogItem>[],
    );
  }

  Future<List<LabCatalogItem>> _facilityPanels({String? search}) async {
    final LabCatalogScope? scope = _currentState?.catalogScope;
    final Result<List<LabCatalogItem>> result = await _repository
        .listFacilityLabPanels(
          tenantId: scope?.tenantId,
          facilityId: scope?.facilityId,
          search: search,
          limit: 200,
        );
    return result.when(
      success: (List<LabCatalogItem> value) => value,
      failure: (_) => const <LabCatalogItem>[],
    );
  }

  Future<AppFailure?> _disableFacilityCatalogItem(
    Future<Result<void>> Function() submit, {
    String? testId,
    String? panelId,
  }) async {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await submit();
    return result.when(
      success: (_) async {
        final LabWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              catalogTests: testId == null
                  ? latest.catalogTests
                  : latest.catalogTests
                        .map(
                          (LabCatalogItem item) =>
                              item.apiId == testId || item.id == testId
                              ? item.copyWith(isOfferedAtFacility: false)
                              : item,
                        )
                        .toList(growable: false),
              catalogPanels: panelId == null
                  ? latest.catalogPanels
                  : latest.catalogPanels
                        .map(
                          (LabCatalogItem item) =>
                              item.apiId == panelId || item.id == panelId
                              ? item.copyWith(isOfferedAtFacility: false)
                              : item,
                        )
                        .toList(growable: false),
              isSaving: false,
            ),
          );
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

  Future<List<LabQcLog>> _qcLogs() async {
    final Result<List<LabQcLog>> result = await _repository.listQcLogs();
    return result.when(
      success: (List<LabQcLog> value) => value,
      failure: (_) => const <LabQcLog>[],
    );
  }

  List<LabOrderWorkflow> _currentSelectedWorkflows() {
    final LabWorkspaceState? current = _currentState;
    if (current == null) {
      return const <LabOrderWorkflow>[];
    }
    if (current.selectedWorkflows.isNotEmpty) {
      return current.selectedWorkflows;
    }
    final LabOrderWorkflow? selected = current.selectedWorkflow;
    return selected == null
        ? const <LabOrderWorkflow>[]
        : <LabOrderWorkflow>[selected];
  }

  LabOrderWorkflow? _workflowForItem(LabOrderItem item) {
    final List<LabOrderWorkflow> workflows = _currentSelectedWorkflows();
    for (final LabOrderWorkflow workflow in workflows) {
      if (workflow.order.items.any((LabOrderItem orderItem) {
        return orderItem.apiId == item.apiId;
      })) {
        return workflow;
      }
    }
    for (final LabOrderWorkflow workflow in workflows) {
      if (_itemBelongsToOrder(item, workflow.order)) {
        return workflow;
      }
    }
    return workflows.isEmpty ? null : workflows.first;
  }

  bool _itemBelongsToOrder(LabOrderItem item, LabOrderSummary order) {
    final String? labOrderId = item.labOrderId;
    return labOrderId == null ||
        labOrderId == order.id ||
        labOrderId == order.apiId ||
        labOrderId == order.displayId;
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

  List<LabOrderWorkflow> _selectedWorkflowsAfterRefresh(
    AppPage<LabOrderSummary> page,
    List<LabOrderWorkflow> selected,
  ) {
    if (selected.isEmpty) {
      return const <LabOrderWorkflow>[];
    }
    return selected
        .map((LabOrderWorkflow workflow) {
          for (final LabOrderSummary order in page.items) {
            if (_isSameOrder(order, workflow.order)) {
              return workflow.copyWithSummary(order);
            }
          }
          return workflow;
        })
        .toList(growable: false);
  }

  AppPage<LabOrderSummary> _replaceOrders(
    AppPage<LabOrderSummary> page,
    List<LabOrderWorkflow> workflows,
  ) {
    var next = page;
    for (final LabOrderWorkflow workflow in workflows) {
      next = _replaceOrder(next, workflow.order);
    }
    return next;
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

  AppPage<LabOrderSummary> _removeOrder(
    AppPage<LabOrderSummary> page,
    String orderId,
  ) {
    final List<LabOrderSummary> items = page.items
        .where(
          (LabOrderSummary order) =>
              order.id != orderId &&
              order.apiId != orderId &&
              order.displayId != orderId,
        )
        .toList(growable: false);
    return AppPage<LabOrderSummary>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! - (page.items.length - items.length),
    );
  }

  bool _isSameOrder(LabOrderSummary left, LabOrderSummary right) {
    return left.id == right.id ||
        left.apiId == right.apiId ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  bool _orderMatchesIdentifier(LabOrderSummary order, String identifier) {
    return order.id == identifier ||
        order.apiId == identifier ||
        order.displayId == identifier ||
        order.orderIds.contains(identifier) ||
        order.orderDisplayIds.contains(identifier);
  }

  List<LabOrderWorkflow> _replaceSelectedWorkflow(
    List<LabOrderWorkflow> current,
    LabOrderWorkflow workflow,
  ) {
    if (current.isEmpty) {
      return <LabOrderWorkflow>[workflow];
    }

    var replaced = false;
    final List<LabOrderWorkflow> next = <LabOrderWorkflow>[];
    for (final LabOrderWorkflow selected in current) {
      if (_isSameOrder(selected.order, workflow.order)) {
        if (!replaced) {
          next.add(workflow);
          replaced = true;
        }
      } else {
        next.add(selected);
      }
    }
    if (!replaced) {
      next.add(workflow);
    }
    return next;
  }

  bool _isSameQuery(LabWorkbenchQuery left, LabWorkbenchQuery right) {
    return left.search == right.search &&
        left.scope == right.scope &&
        left.view == right.view &&
        left.pageRequest.pageIndex == right.pageRequest.pageIndex &&
        left.pageRequest.pageSize == right.pageRequest.pageSize;
  }

  List<String> _workflowIdentifiersFor(LabOrderSummary order) {
    final List<String> preferred = order.orderDisplayIds.isNotEmpty
        ? order.orderDisplayIds
        : order.orderIds;
    return _distinctNonEmpty(preferred);
  }

  String? _workflowIdentifierFor(LabOrderSummary order) {
    if (order.isPatientGroup) {
      final String? groupedOrderDisplayId = _firstNonEmpty(
        order.orderDisplayIds,
      );
      if (groupedOrderDisplayId != null) {
        return groupedOrderDisplayId;
      }
      final String? groupedOrderId = _firstNonEmpty(order.orderIds);
      if (groupedOrderId != null) {
        return groupedOrderId;
      }
    }
    return _firstNonEmpty(<String?>[order.displayId, order.id]);
  }

  List<String> _distinctNonEmpty(Iterable<String?> values) {
    final Set<String> seen = <String>{};
    final List<String> distinct = <String>[];
    for (final String? value in values) {
      final String? normalized = value?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      distinct.add(normalized);
    }
    return distinct;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final String? value in values) {
      final String? trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
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
    final bool keepDetailedOrder =
        this.order.items.isNotEmpty &&
        (order.items.isEmpty || order.isPatientGroup);
    return LabOrderWorkflow(
      order: keepDetailedOrder ? this.order : order,
      results: results,
      timeline: timeline,
      nextActions: nextActions,
    );
  }
}
