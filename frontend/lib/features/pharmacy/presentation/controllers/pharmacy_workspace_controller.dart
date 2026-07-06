import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final pharmacyWorkspaceControllerProvider =
    AsyncNotifierProvider<
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
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.pharmacyWorkspace,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<PharmacyWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh({
    bool refreshCatalog = true,
    bool refreshInventory = true,
  }) {
    return _syncVisibleData(
      showLoading: true,
      refreshDrugs: refreshCatalog,
      refreshFormulary: refreshCatalog,
      refreshInventory: refreshInventory || refreshCatalog,
    );
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

    _emit(
      current.copyWith(
        query: PharmacyWorkbenchQuery.fromChip(filter).copyWith(
          search: current.query.search,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshingOrders: true,
        clearLastFailure: true,
      ),
    );
    return _refreshOrders(showLoading: true);
  }

  Future<AppFailure?> applyAdvancedFilters(PharmacyWorkbenchQuery query) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: query.copyWith(
          search: current.query.search,
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
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
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

  Future<AppFailure?> applyDrugStorageFilter({
    String? storageRoomId,
    String? storageShelfId,
    bool clearStorageRoomId = false,
    bool clearStorageShelfId = false,
  }) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        drugQuery: current.drugQuery.copyWith(
          storageRoomId: storageRoomId,
          storageShelfId: storageShelfId,
          clearStorageRoomId: clearStorageRoomId,
          clearStorageShelfId: clearStorageShelfId,
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

  Future<AppFailure?> applyFormularySearch(String search) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        formularyQuery: current.formularyQuery.copyWith(
          search: search.trim(),
          pageRequest: current.formularyQuery.pageRequest.first(),
        ),
        isRefreshingFormulary: true,
        clearLastFailure: true,
      ),
    );
    return _refreshFormulary(showLoading: true);
  }

  Future<AppFailure?> changeFormularyPage(AppPageRequest request) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        formularyQuery: current.formularyQuery.copyWith(pageRequest: request),
        isRefreshingFormulary: true,
        clearLastFailure: true,
      ),
    );
    return _refreshFormulary(showLoading: true);
  }

  Future<AppFailure?> applyInventorySearch(String search) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: current.inventoryQuery.copyWith(
          search: search.trim(),
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> applyInventoryLowStockOnly(bool lowStockOnly) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: current.inventoryQuery.copyWith(
          lowStockOnly: lowStockOnly,
          clearStockStatus: !lowStockOnly,
          clearExpiringWithinDays: true,
          expiredOnly: false,
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> applyInventoryFilter(PharmacyInventoryFilter filter) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        catalogTab: PharmacyCatalogTab.inventory,
        inventoryQuery: PharmacyInventoryStockQuery.forFilter(filter).copyWith(
          search: current.inventoryQuery.search,
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> applyInventoryStockStatus(String? stockStatus) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: current.inventoryQuery.copyWith(
          stockStatus: stockStatus,
          clearStockStatus: stockStatus == null,
          lowStockOnly: false,
          clearExpiringWithinDays: true,
          expiredOnly: false,
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> clearInventoryFilters() async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: PharmacyInventoryStockQuery(
          search: current.inventoryQuery.search,
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> applyInventoryStorageFilter({
    String? storageRoomId,
    String? storageShelfId,
    bool clearStorageRoomId = false,
    bool clearStorageShelfId = false,
  }) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: current.inventoryQuery.copyWith(
          storageRoomId: storageRoomId,
          storageShelfId: storageShelfId,
          clearStorageRoomId: clearStorageRoomId,
          clearStorageShelfId: clearStorageShelfId,
          pageRequest: current.inventoryQuery.pageRequest.first(),
        ),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  Future<AppFailure?> changeInventoryPage(AppPageRequest request) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        inventoryQuery: current.inventoryQuery.copyWith(pageRequest: request),
        isRefreshingInventory: true,
        clearLastFailure: true,
      ),
    );
    return _refreshInventory(showLoading: true);
  }

  void setCatalogTab(PharmacyCatalogTab tab) {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null || current.catalogTab == tab) {
      return;
    }
    _emit(current.copyWith(catalogTab: tab));
    _refreshCatalogTabData(tab, current);
  }

  void prepareCatalogTab(PharmacyCatalogTab tab) {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    if (current.catalogTab != tab) {
      _emit(current.copyWith(catalogTab: tab));
    }
    _refreshCatalogTabData(tab, current);
  }

  void _refreshCatalogTabData(
    PharmacyCatalogTab tab,
    PharmacyWorkspaceState current,
  ) {
    if (tab == PharmacyCatalogTab.formulary &&
        current.formularyItems.items.isEmpty) {
      unawaited(_refreshFormulary(showLoading: true));
    }
    if (tab == PharmacyCatalogTab.inventory &&
        current.inventoryWorkbench.stocks.items.isEmpty) {
      unawaited(_refreshInventory(showLoading: true));
    }
    if (tab == PharmacyCatalogTab.storage) {
      unawaited(_refreshStorageLayout(showLoading: true));
    }
  }

  Future<void> _refreshStorageLayout({bool showLoading = false}) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    if (showLoading) {
      _emit(current.copyWith(isRefreshingStorage: true));
    }
    final Result<PharmacyStorageLayout> result =
        await _repository.loadStorageLayout(
      includeInactive: true,
      facilityId: resolveFacilityId(),
    );
    final PharmacyWorkspaceState? latest = _currentState;
    if (latest == null) {
      return;
    }
    result.when(
      success: (PharmacyStorageLayout layout) {
        _emit(
          latest.copyWith(
            storageLayout: layout,
            isRefreshingStorage: false,
          ),
        );
      },
      failure: (_) {
        _emit(latest.copyWith(isRefreshingStorage: false));
      },
    );
  }

  Future<AppFailure?> createStorageRoom(PharmacyStorageRoomInput input) async {
    final Result<PharmacyStorageRoom> result =
        await _repository.createStorageRoom(input);
    return result.when(
      success: (_) async {
        await _refreshStorageLayout();
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> updateStorageRoom(
    String roomId,
    PharmacyStorageRoomUpdateInput input,
  ) async {
    final Result<PharmacyStorageRoom> result =
        await _repository.updateStorageRoom(roomId, input);
    return result.when(
      success: (_) async {
        await _refreshStorageLayout();
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> createStorageShelf(
    String roomId,
    PharmacyStorageShelfInput input,
  ) async {
    final Result<PharmacyStorageShelf> result =
        await _repository.createStorageShelf(roomId, input);
    return result.when(
      success: (_) async {
        await _refreshStorageLayout();
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> updateStorageShelf(
    String shelfId,
    PharmacyStorageShelfUpdateInput input,
  ) async {
    final Result<PharmacyStorageShelf> result =
        await _repository.updateStorageShelf(shelfId, input);
    return result.when(
      success: (_) async {
        await _refreshStorageLayout();
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> createDrug(
    PharmacyDrugInput input, {
    PharmacyFacilityOfferingInput? facilityOffering,
  }) async {
    final Result<PharmacyDrug> result = await _repository.createDrug(input);
    return result.when(
      success: (PharmacyDrug drug) async {
        if (facilityOffering != null) {
          final Result<PharmacyDrug> offeringResult =
              await _repository.upsertFacilityOffering(
            drug.id,
            PharmacyFacilityOfferingInput(
              unitPrice: facilityOffering.unitPrice,
              currency: facilityOffering.currency,
              isActive: facilityOffering.isActive,
              facilityId:
                  facilityOffering.facilityId ?? input.facilityId ?? resolveFacilityId(),
              defaultStorageShelfId:
                  facilityOffering.defaultStorageShelfId ?? input.storageShelfId,
            ),
          );
          final AppFailure? offeringFailure = offeringResult.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
          if (offeringFailure != null) {
            return offeringFailure;
          }
        } else if (input.storageShelfId != null) {
          final String? facilityId = input.facilityId ?? resolveFacilityId();
          if (facilityId != null) {
            final Result<PharmacyDrug> offeringResult =
                await _repository.upsertFacilityOffering(
              drug.id,
              PharmacyFacilityOfferingInput(
                unitPrice: 0,
                isActive: false,
                facilityId: facilityId,
                defaultStorageShelfId: input.storageShelfId,
              ),
            );
            final AppFailure? offeringFailure = offeringResult.when(
              success: (_) => null,
              failure: (AppFailure failure) => failure,
            );
            if (offeringFailure != null) {
              return offeringFailure;
            }
          }
        }
        await _refreshDrugs(showLoading: false);
        if (input.hasStockSetup) {
          await _refreshInventory(showLoading: false);
        }
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> updateDrug(
    String drugId,
    PharmacyDrugUpdateInput input, {
    PharmacyFacilityOfferingInput? facilityOffering,
  }) async {
    final Result<PharmacyDrug> result = await _repository.updateDrug(
      drugId,
      input,
    );
    return result.when(
      success: (_) async {
        if (facilityOffering != null) {
          final Result<PharmacyDrug> offeringResult =
              await _repository.upsertFacilityOffering(
            drugId,
            facilityOffering,
          );
          final AppFailure? offeringFailure = offeringResult.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
          if (offeringFailure != null) {
            return offeringFailure;
          }
        }
        await _refreshDrugs(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> upsertFacilityOffering(
    String drugId,
    PharmacyFacilityOfferingInput input,
  ) async {
    final Result<PharmacyDrug> result = await _repository.upsertFacilityOffering(
      drugId,
      input,
    );
    return result.when(
      success: (_) async {
        await _refreshDrugs(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> deleteDrug(String drugId) async {
    final Result<void> result = await _repository.deleteDrug(drugId);
    return result.when(
      success: (_) async {
        await _refreshDrugs(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> createFormularyItem(
    PharmacyFormularyItemInput input,
  ) async {
    final Result<PharmacyFormularyItem> result = await _repository
        .createFormularyItem(input);
    return result.when(
      success: (_) async {
        await _refreshFormulary(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> updateFormularyItem(
    String formularyItemId, {
    bool? isActive,
  }) async {
    final Result<PharmacyFormularyItem> result = await _repository
        .updateFormularyItem(formularyItemId, isActive: isActive);
    return result.when(
      success: (_) async {
        await _refreshFormulary(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> adjustInventoryStock(
    PharmacyInventoryAdjustInput input,
  ) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PharmacyInventoryWorkbench> result = await _repository
        .adjustInventoryStock(input);
    return result.when(
      success: (_) async {
        final AppFailure? failure = await _refreshInventory(showLoading: false);
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false));
        }
        return failure;
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

  Future<AppFailure?> recordOrderBilling(Map<String, Object?> billing) async {
    final PharmacyWorkspaceState? current = _currentState;
    final PharmacyOrderWorkflow? workflow = current?.selectedWorkflow;
    if (current == null || workflow == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PharmacyOrderWorkflow> result = await _repository
        .recordOrderBilling(workflow.order.id, billing);
    return result.when(
      success: (PharmacyOrderWorkflow updated) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: updated,
              workbench: _replaceOrder(latest.workbench, updated.order),
              isSaving: false,
            ),
          );
        }
        unawaited(_refreshOrders(showLoading: false));
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

  String? resolveTenantId() {
    final SessionState sessionState = ref.read(sessionStateProvider);
    return sessionState.session?.user?.tenantId;
  }

  String? resolveFacilityId() {
    final SessionState sessionState = ref.read(sessionStateProvider);
    return sessionState.session?.user?.facilityId;
  }

  PharmacyDrugQuery _scopedDrugQuery(PharmacyDrugQuery query) {
    final String? facilityId = resolveFacilityId();
    if (facilityId == null || query.facilityId != null) {
      return query;
    }
    return query.copyWith(facilityId: facilityId);
  }

  PharmacyInventoryStockQuery _scopedInventoryQuery(
    PharmacyInventoryStockQuery query,
  ) {
    final String? facilityId = resolveFacilityId();
    if (facilityId == null || query.facilityId != null) {
      return query;
    }
    return query.copyWith(facilityId: facilityId);
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

  Future<AppFailure?> cancelOrder({required String reason, String? notes}) {
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
    final String? facilityId = resolveFacilityId();
    final PharmacyDrugQuery drugQuery = PharmacyDrugQuery(facilityId: facilityId);
    const PharmacyFormularyQuery formularyQuery = PharmacyFormularyQuery();
    final PharmacyInventoryStockQuery inventoryQuery =
        PharmacyInventoryStockQuery(facilityId: facilityId);
    final Result<PharmacyWorkbench> workbenchResult = await _repository
        .loadWorkbench(query);
    final PharmacyWorkbench? workbench = _successOrNull(workbenchResult);
    if (workbench == null) {
      return Result<PharmacyWorkspaceState>.failure(
        _failureOrNull(workbenchResult)!,
      );
    }

    final List<Future<Object?>> initialLoads = <Future<Object?>>[
      _loadDrugPage(drugQuery),
      _repository.getInventoryStock(inventoryQuery).then(
        (Result<PharmacyInventoryWorkbench> result) => result.when(
          success: (PharmacyInventoryWorkbench value) => value,
          failure: (_) => null,
        ),
      ),
      _repository.loadStorageLayout(facilityId: facilityId).then(
        (Result<PharmacyStorageLayout> result) => result.when(
          success: (PharmacyStorageLayout value) => value,
          failure: (_) => null,
        ),
      ),
    ];
    final List<Object?> loadResults = await Future.wait(initialLoads);
    final AppPage<PharmacyDrug> drugs = loadResults[0]! as AppPage<PharmacyDrug>;
    final PharmacyInventoryWorkbench inventoryWorkbench =
        loadResults[1] as PharmacyInventoryWorkbench? ??
        PharmacyInventoryWorkbench(
          summary: const PharmacyInventoryStockSummary(),
          stocks: AppPage<PharmacyInventoryStock>(
            items: const <PharmacyInventoryStock>[],
            request: inventoryQuery.pageRequest,
            totalItemCount: 0,
          ),
        );
    final PharmacyStorageLayout storageLayout =
        loadResults[2] as PharmacyStorageLayout? ?? const PharmacyStorageLayout();
    return Result<PharmacyWorkspaceState>.success(
      PharmacyWorkspaceState(
        query: query,
        workbench: workbench,
        drugQuery: drugQuery,
        drugs: drugs,
        formularyQuery: formularyQuery,
        formularyItems: AppPage<PharmacyFormularyItem>(
          items: const <PharmacyFormularyItem>[],
          request: formularyQuery.pageRequest,
          totalItemCount: 0,
        ),
        inventoryQuery: inventoryQuery,
        inventoryWorkbench: inventoryWorkbench,
        storageLayout: storageLayout,
      ),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData(refreshInventory: true));
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshDrugs = false,
    bool refreshFormulary = false,
    bool refreshInventory = false,
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
          isRefreshingFormulary: refreshFormulary,
          isRefreshingInventory: refreshInventory,
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
      if (refreshFormulary) {
        await _refreshFormulary(showLoading: showLoading);
      }
      if (refreshInventory) {
        await _refreshInventory(showLoading: showLoading);
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
            isRefreshingFormulary: false,
            isRefreshingInventory: false,
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
      _scopedDrugQuery(current.drugQuery),
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

  Future<AppFailure?> _refreshFormulary({required bool showLoading}) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<PharmacyFormularyItem>> result = await _repository
        .listFormularyItems(current.formularyQuery);
    return result.when(
      success: (AppPage<PharmacyFormularyItem> items) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              formularyItems: items,
              isRefreshingFormulary: false,
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
            latest.copyWith(isRefreshingFormulary: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshInventory({required bool showLoading}) async {
    final PharmacyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<PharmacyInventoryWorkbench> result = await _repository
        .getInventoryStock(_scopedInventoryQuery(current.inventoryQuery));
    return result.when(
      success: (PharmacyInventoryWorkbench workbench) {
        final PharmacyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              inventoryWorkbench: workbench,
              isRefreshingInventory: false,
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
            latest.copyWith(isRefreshingInventory: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppPage<PharmacyDrug>> _loadDrugPage(PharmacyDrugQuery query) async {
    final Result<AppPage<PharmacyDrug>> result = await _repository.searchDrugs(
      _scopedDrugQuery(query),
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
            paymentStatus: item.paymentStatus,
            billing: item.billing,
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
