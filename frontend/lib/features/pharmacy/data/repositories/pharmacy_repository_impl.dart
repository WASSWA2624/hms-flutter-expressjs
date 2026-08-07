import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/pharmacy/data/dtos/pharmacy_dtos.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) {
  return PharmacyRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class PharmacyRepositoryImpl implements PharmacyRepository {
  const PharmacyRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<PharmacyWorkbench>> loadWorkbench(
    PharmacyWorkbenchQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<PharmacyWorkbench>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.pharmacy.path, 'workbench']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'panel': 'orders',
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'status': query.status,
        'location': query.location,
        'pending_payment': query.pendingPayment == true ? true : null,
        'payment_cleared': query.pendingPayment == false ? true : null,
        'open_orders': query.openOrders == true ? true : null,
        'today_only': query.todayOnly == true ? true : null,
        'partial_stock': query.partialStock == true ? true : null,
        'urgent': query.urgent == true ? true : null,
        'priority': query.priority,
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': 'ordered_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          PharmacyWorkbenchDto.fromResponse(data, request).workbench,
    );
  }

  @override
  Future<Result<PharmacyOrderWorkflow>> loadOrderWorkflow(String orderId) {
    return _apiClient.get<PharmacyOrderWorkflow>(
      _pharmacyOrderEndpoint(orderId, 'workflow'),
      decoder: (Object? data) =>
          PharmacyOrderWorkflowDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> createPharmacyOrder(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<PharmacyMutationResult>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.pharmacy.path, 'orders']),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<PharmacyDrug>>> searchDrugs(PharmacyDrugQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PharmacyDrug>>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.pharmacy.path, 'drugs']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'name': query.name,
        'code': query.code,
        'form': query.form,
        'strength': query.strength,
        'stock_status': query.stockStatus,
        'facility_id': query.facilityId,
        'storage_room_id': query.storageRoomId,
        'storage_shelf_id': query.storageShelfId,
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          PharmacyDrugPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PharmacyInventoryWorkbench>> getInventoryStock(
    PharmacyInventoryStockQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    final String baseSearch = query.search.trim();
    final String nameSearch = (query.itemName ?? '').trim();
    final String skuSearch = (query.sku ?? '').trim();
    final String combinedSearch = <String>[
      if (baseSearch.isNotEmpty) baseSearch,
      if (nameSearch.isNotEmpty) nameSearch,
      if (skuSearch.isNotEmpty) skuSearch,
    ].join(' ');
    return _apiClient.get<PharmacyInventoryWorkbench>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'inventory',
        'stock',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': combinedSearch.isEmpty ? null : combinedSearch,
        'facility_id': query.facilityId,
        'inventory_item_id': query.inventoryItemId,
        'low_stock_only': query.lowStockOnly ? true : null,
        'stock_status': query.stockStatus,
        'expiring_within_days': query.expiringWithinDays,
        'expired_only': query.expiredOnly ? true : null,
        'storage_room_id': query.storageRoomId,
        'storage_shelf_id': query.storageShelfId,
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          PharmacyInventoryWorkbenchDto.fromResponse(data, request).workbench,
    );
  }

  @override
  Future<Result<PharmacyInventoryWorkbench>> adjustInventoryStock(
    PharmacyInventoryAdjustInput input,
  ) {
    return _apiClient.post<PharmacyInventoryWorkbench>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'inventory',
        'adjust',
      ]),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        final PharmacyJsonMap payload = _map(response['data']);
        final PharmacyInventoryStockSummary summary =
            PharmacyInventoryStockSummaryDto(
              _map(payload['stock_summary']),
            ).toEntity();
        final PharmacyInventoryStock? stock = _map(payload['stock']).isEmpty
            ? null
            : PharmacyInventoryStockDto(_map(payload['stock'])).toEntity();
        final List<PharmacyInventoryStock> stocks = stock == null
            ? const <PharmacyInventoryStock>[]
            : <PharmacyInventoryStock>[stock];
        return PharmacyInventoryWorkbench(
          summary: summary,
          stocks: AppPage<PharmacyInventoryStock>(
            items: stocks,
            request: const AppPageRequest(pageSize: 10),
            totalItemCount: stocks.length,
          ),
        );
      },
    );
  }

  @override
  Future<Result<PharmacyDrug>> createDrug(PharmacyDrugInput input) {
    if (input.hasStockSetup) {
      return setupDrug(input);
    }
    return _apiClient.post<PharmacyDrug>(
      ApiEndpoints.collection(HmsApiResource.drugs),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyDrugDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyDrug>> setupDrug(PharmacyDrugInput input) {
    return _apiClient.post<PharmacyDrug>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'drugs',
        'setup',
      ]),
      data: _withoutEmpty(input.toSetupJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyDrugDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyDrug>> updateDrug(
    String drugId,
    PharmacyDrugUpdateInput input,
  ) {
    final Map<String, Object?> payload = _withoutEmpty(input.toJson());
    if (input.clearSupplierId || input.supplierId != null) {
      payload['supplier_id'] = input.clearSupplierId ? null : input.supplierId;
    }
    return _apiClient.put<PharmacyDrug>(
      ApiEndpoints.byId(HmsApiResource.drugs, drugId),
      data: payload,
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyDrugDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyDrug>> upsertFacilityOffering(
    String drugId,
    PharmacyFacilityOfferingInput input,
  ) {
    return _apiClient.put<PharmacyDrug>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'drugs',
        drugId,
        'facility-offering',
      ]),
      data: <String, Object?>{
        if (input.unitPrice != null) 'unit_price': input.unitPrice,
        if (input.isActive != null) 'is_active': input.isActive,
        if (input.currency != null) 'currency': input.currency,
        if (input.facilityId != null) 'facility_id': input.facilityId,
        // Always include shelf so location updates are not stripped.
        'default_storage_shelf_id': input.defaultStorageShelfId,
      },
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyDrugDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> deleteDrug(String drugId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.drugs, drugId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<AppPage<PharmacyFormularyItem>>> listFormularyItems(
    PharmacyFormularyQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PharmacyFormularyItem>>(
      ApiEndpoints.collection(HmsApiResource.formularyItems),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'name': query.name,
        'code': query.code,
        'form': query.form,
        'strength': query.strength,
        'is_active': query.isActive,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          PharmacyFormularyItemPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PharmacyFormularyItem>> createFormularyItem(
    PharmacyFormularyItemInput input,
  ) {
    return _apiClient.post<PharmacyFormularyItem>(
      ApiEndpoints.collection(HmsApiResource.formularyItems),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyFormularyItemDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyFormularyItem>> updateFormularyItem(
    String formularyItemId, {
    bool? isActive,
  }) {
    return _apiClient.put<PharmacyFormularyItem>(
      ApiEndpoints.byId(HmsApiResource.formularyItems, formularyItemId),
      data: _withoutEmpty(<String, Object?>{'is_active': ?isActive}),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyFormularyItemDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> deleteFormularyItem(String formularyItemId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.formularyItems, formularyItemId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<PharmacyOrderWorkflow>> recordOrderBilling(
    String orderId,
    Map<String, Object?> billing,
  ) {
    return _apiClient.post<PharmacyOrderWorkflow>(
      _pharmacyOrderEndpoint(orderId, 'record-billing'),
      data: <String, Object?>{'billing': billing},
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity().workflow,
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> prepareDispense({
    required String orderId,
    required List<PharmacyDispenseLineInput> items,
    String? dispenseBatchRef,
    String? statement,
    String? reason,
  }) {
    return _apiClient.post<PharmacyMutationResult>(
      _pharmacyOrderEndpoint(orderId, 'prepare-dispense'),
      data: _withoutEmpty(<String, Object?>{
        'dispense_batch_ref': dispenseBatchRef,
        'statement': statement,
        'reason': reason,
        // Complete stock deduction and status rollup in one step so Dispense
        // matches partial/full dispense expectations without a second user.
        'finalize': true,
        'items': items
            .map((PharmacyDispenseLineInput item) {
              return _withoutEmpty(item.toJson());
            })
            .toList(growable: false),
      }),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> attestDispense({
    required String orderId,
    required String dispenseBatchRef,
    String? statement,
    String? reason,
    DateTime? attestedAt,
  }) {
    return _apiClient.post<PharmacyMutationResult>(
      _pharmacyOrderEndpoint(orderId, 'attest-dispense'),
      data: _withoutEmpty(<String, Object?>{
        'dispense_batch_ref': dispenseBatchRef,
        'statement': statement,
        'reason': reason,
        'attested_at': attestedAt?.toUtc().toIso8601String(),
      }),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> cancelOrder({
    required String orderId,
    required String reason,
    String? notes,
  }) {
    return _apiClient.post<PharmacyMutationResult>(
      _pharmacyOrderEndpoint(orderId, 'cancel'),
      data: _withoutEmpty(<String, Object?>{'reason': reason, 'notes': notes}),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> cancelOrderItem({
    required String orderId,
    required String itemId,
    required String reason,
    String? notes,
  }) {
    return _apiClient.post<PharmacyMutationResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'orders',
        orderId,
        'items',
        itemId,
        'cancel',
      ]),
      data: _withoutEmpty(<String, Object?>{'reason': reason, 'notes': notes}),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PharmacyMutationResult>> returnDispense({
    required String orderId,
    required List<PharmacyReturnLineInput> items,
    String? reason,
    String? notes,
  }) {
    return _apiClient.post<PharmacyMutationResult>(
      _pharmacyOrderEndpoint(orderId, 'return'),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'notes': notes,
        'items': items
            .map((PharmacyReturnLineInput item) {
              return _withoutEmpty(item.toJson());
            })
            .toList(growable: false),
      }),
      decoder: (Object? data) =>
          PharmacyMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  Uri _pharmacyOrderEndpoint(String orderId, String action) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.pharmacy.path,
      'orders',
      orderId,
      action,
    ]);
  }

  @override
  Future<Result<PharmacyStorageLayout>> loadStorageLayout({
    bool includeInactive = false,
    bool includeDeleted = false,
    String? facilityId,
  }) {
    return _apiClient.get<PharmacyStorageLayout>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'layout',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'include_inactive': includeInactive ? true : null,
        'include_deleted': includeDeleted ? true : null,
        'facility_id': facilityId,
      }),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageLayoutDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyStorageRoomSimilarityResult>>
  checkStorageRoomSimilarity({
    required String name,
    String? code,
    String? facilityId,
    String? excludeRoomId,
  }) {
    return _apiClient.post<PharmacyStorageRoomSimilarityResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        'similarity-check',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'name': name,
        'code': code,
        'facility_id': facilityId,
        'exclude_room_id': excludeRoomId,
      }),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        final PharmacyJsonMap payload = _map(response['data']);
        final List<PharmacyStorageRoomSimilarityMatch> matches =
            _list(payload['matches']).map((Object? raw) {
              final PharmacyJsonMap match = _map(raw);
              final PharmacyJsonMap roomJson = _map(match['room']);
              final List<PharmacyStorageRoomFieldComparison> comparisons =
                  _list(match['field_comparisons']).map((Object? entry) {
                    final PharmacyJsonMap comparison = _map(entry);
                    return PharmacyStorageRoomFieldComparison(
                      field: _string(comparison['field']) ?? '',
                      inputValue: _string(comparison['input_value']),
                      candidateValue: _string(comparison['candidate_value']),
                      score: _int(comparison['score']),
                      status: _string(comparison['status']),
                    );
                  }).toList(growable: false);
              return PharmacyStorageRoomSimilarityMatch(
                room: PharmacyStorageRoomDto(roomJson).toEntity(),
                score: _int(match['score']) ?? 0,
                isExact: _bool(match['is_exact']),
                exactNameConflict: _bool(match['exact_name_conflict']),
                exactCodeConflict: _bool(match['exact_code_conflict']),
                nameScore: _int(match['name_score']),
                codeScore: _int(match['code_score']),
                fieldComparisons: comparisons,
              );
            }).toList(growable: false);
        return PharmacyStorageRoomSimilarityResult(
          exactNameConflict: _bool(payload['exact_name_conflict']),
          exactCodeConflict: _bool(payload['exact_code_conflict']),
          closestScore: _int(payload['closest_score']) ?? 0,
          matches: matches,
        );
      },
    );
  }

  @override
  Future<Result<PharmacyStorageShelfSimilarityResult>>
  checkStorageShelfSimilarity({
    required String roomId,
    required String label,
    String? shelfCode,
    String? excludeShelfId,
  }) {
    return _apiClient.post<PharmacyStorageShelfSimilarityResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
        'shelves',
        'similarity-check',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'label': label,
        'shelf_code': shelfCode,
        'exclude_shelf_id': excludeShelfId,
      }),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        final PharmacyJsonMap payload = _map(response['data']);
        final List<PharmacyStorageShelfSimilarityMatch> matches =
            _list(payload['matches']).map((Object? raw) {
              final PharmacyJsonMap match = _map(raw);
              final PharmacyJsonMap shelfJson = _map(match['shelf']);
              final List<PharmacyStorageShelfFieldComparison> comparisons =
                  _list(match['field_comparisons']).map((Object? entry) {
                    final PharmacyJsonMap comparison = _map(entry);
                    return PharmacyStorageShelfFieldComparison(
                      field: _string(comparison['field']) ?? '',
                      inputValue: _string(comparison['input_value']),
                      candidateValue: _string(comparison['candidate_value']),
                      score: _int(comparison['score']),
                      status: _string(comparison['status']),
                    );
                  }).toList(growable: false);
              return PharmacyStorageShelfSimilarityMatch(
                shelf: PharmacyStorageShelfDto(shelfJson).toEntity(),
                score: _int(match['score']) ?? 0,
                isExact: _bool(match['is_exact']),
                exactLabelConflict: _bool(match['exact_label_conflict']),
                exactCodeConflict: _bool(match['exact_code_conflict']),
                labelScore: _int(match['label_score']),
                codeScore: _int(match['code_score']),
                fieldComparisons: comparisons,
              );
            }).toList(growable: false);
        return PharmacyStorageShelfSimilarityResult(
          exactLabelConflict: _bool(payload['exact_label_conflict']),
          exactCodeConflict: _bool(payload['exact_code_conflict']),
          closestScore: _int(payload['closest_score']) ?? 0,
          matches: matches,
        );
      },
    );
  }

  @override
  Future<Result<PharmacyDrugSimilarityResult>> checkDrugSimilarity({
    required String genericName,
    String? name,
    String? brandName,
    String? code,
    String? form,
    String? strength,
    String? tenantId,
    String? excludeDrugId,
  }) {
    return _apiClient.post<PharmacyDrugSimilarityResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'drugs',
        'similarity-check',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'generic_name': genericName,
        'name': name ?? genericName,
        'brand_name': brandName,
        'code': code,
        'form': form,
        'strength': strength,
        'tenant_id': tenantId,
        'exclude_drug_id': excludeDrugId,
      }),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        final PharmacyJsonMap payload = _map(response['data']);
        final List<PharmacyDrugSimilarityMatch> matches =
            _list(payload['matches']).map((Object? raw) {
              final PharmacyJsonMap match = _map(raw);
              final PharmacyJsonMap drugJson = _map(match['drug']);
              final List<PharmacyDrugFieldComparison> comparisons =
                  _list(match['field_comparisons']).map((Object? entry) {
                    final PharmacyJsonMap comparison = _map(entry);
                    return PharmacyDrugFieldComparison(
                      field: _string(comparison['field']) ?? '',
                      inputValue: _string(comparison['input_value']),
                      candidateValue: _string(comparison['candidate_value']),
                      score: _int(comparison['score']),
                      status: _string(comparison['status']),
                    );
                  }).toList(growable: false);
              return PharmacyDrugSimilarityMatch(
                drug: PharmacyDrugDto(drugJson).toEntity(),
                score: _int(match['score']) ?? 0,
                isExact: _bool(match['is_exact']),
                exactIdentityConflict: _bool(match['exact_identity_conflict']),
                exactCodeConflict: _bool(match['exact_code_conflict']),
                genericScore: _int(match['generic_score']),
                brandScore: _int(match['brand_score']),
                codeScore: _int(match['code_score']),
                formScore: _int(match['form_score']),
                strengthScore: _int(match['strength_score']),
                fieldComparisons: comparisons,
              );
            }).toList(growable: false);
        return PharmacyDrugSimilarityResult(
          exactIdentityConflict: _bool(payload['exact_identity_conflict']),
          exactCodeConflict: _bool(payload['exact_code_conflict']),
          closestScore: _int(payload['closest_score']) ?? 0,
          matches: matches,
        );
      },
    );
  }

  @override
  Future<Result<PharmacyStorageRoom>> createStorageRoom(
    PharmacyStorageRoomInput input,
  ) {
    return _apiClient.post<PharmacyStorageRoom>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
      ]),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageRoomDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyStorageRoom>> updateStorageRoom(
    String roomId,
    PharmacyStorageRoomUpdateInput input,
  ) {
    return _apiClient.put<PharmacyStorageRoom>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
      ]),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageRoomDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyStorageShelf>> createStorageShelf(
    String roomId,
    PharmacyStorageShelfInput input,
  ) {
    return _apiClient.post<PharmacyStorageShelf>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
        'shelves',
      ]),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageShelfDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<PharmacyStorageShelf>> updateStorageShelf(
    String shelfId,
    PharmacyStorageShelfUpdateInput input,
  ) {
    return _apiClient.put<PharmacyStorageShelf>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'shelves',
        shelfId,
      ]),
      data: _withoutEmpty(input.toJson()),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageShelfDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> deleteStorageRoom(String roomId) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
      ]),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<PharmacyStorageRoom>> restoreStorageRoom(String roomId) {
    return _apiClient.post<PharmacyStorageRoom>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
        'restore',
      ]),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        return PharmacyStorageRoomDto(_map(response['data'])).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> permanentDeleteStorageRoom(String roomId) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'rooms',
        roomId,
        'permanent',
      ]),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteStorageShelf(String shelfId) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'storage',
        'shelves',
        shelfId,
      ]),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<AppPage<PharmacySupplier>>> listSuppliers(
    PharmacySupplierQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PharmacySupplier>>(
      ApiEndpoints.collection(HmsApiResource.suppliers),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          PharmacySupplierPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PharmacySupplierSimilarityResult>> checkSupplierSimilarity({
    required String name,
    String? contactEmail,
    String? phone,
    String? location,
    String? tenantId,
    String? excludeSupplierId,
  }) {
    return _apiClient.post<PharmacySupplierSimilarityResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.suppliers.path,
        'similarity-check',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'name': name,
        'contact_email': contactEmail,
        'phone': phone,
        'location': location,
        'tenant_id': tenantId,
        'exclude_supplier_id': excludeSupplierId,
      }),
      decoder: (Object? data) {
        final PharmacyJsonMap response = _expectMap(data);
        final PharmacyJsonMap payload = _map(response['data']);
        final List<PharmacySupplierSimilarityMatch> matches =
            _list(payload['matches']).map((Object? raw) {
              final PharmacyJsonMap match = _map(raw);
              final PharmacyJsonMap supplierJson = _map(match['supplier']);
              final List<PharmacySupplierFieldComparison> comparisons =
                  _list(match['field_comparisons']).map((Object? entry) {
                    final PharmacyJsonMap comparison = _map(entry);
                    return PharmacySupplierFieldComparison(
                      field: _string(comparison['field']) ?? '',
                      inputValue: _string(comparison['input_value']),
                      candidateValue: _string(comparison['candidate_value']),
                      score: _int(comparison['score']),
                      status: _string(comparison['status']),
                    );
                  }).toList(growable: false);
              return PharmacySupplierSimilarityMatch(
                supplier: PharmacySupplierDto(supplierJson).toEntity(),
                score: _int(match['score']) ?? 0,
                isExact: _bool(match['is_exact']),
                exactNameConflict: _bool(match['exact_name_conflict']),
                exactEmailConflict: _bool(match['exact_email_conflict']),
                exactPhoneConflict: _bool(match['exact_phone_conflict']),
                nameScore: _int(match['name_score']),
                emailScore: _int(match['email_score']),
                phoneScore: _int(match['phone_score']),
                locationScore: _int(match['location_score']),
                fieldComparisons: comparisons,
              );
            }).toList(growable: false);
        return PharmacySupplierSimilarityResult(
          exactNameConflict: _bool(payload['exact_name_conflict']),
          exactEmailConflict: _bool(payload['exact_email_conflict']),
          exactPhoneConflict: _bool(payload['exact_phone_conflict']),
          closestScore: _int(payload['closest_score']) ?? 0,
          matches: matches,
        );
      },
    );
  }

  @override
  Future<Result<PharmacySupplier>> createSupplier(PharmacySupplierInput input) {
    return _apiClient
        .post<PharmacySupplier>(
          ApiEndpoints.collection(HmsApiResource.suppliers),
          data: _withoutEmpty(input.toJson()),
          decoder: (Object? data) {
            final PharmacyJsonMap response = _expectMap(data);
            return PharmacySupplierDto(_map(response['data'])).toEntity();
          },
        )
        .then((Result<PharmacySupplier> created) async {
          return created.when(
            success: (PharmacySupplier supplier) async {
              final String? location = input.location?.trim();
              if (location == null || location.isEmpty) {
                return Result<PharmacySupplier>.success(supplier);
              }
              final Result<PharmacySupplier> withLocation =
                  await _syncSupplierLocation(
                    supplier: supplier,
                    location: location,
                    tenantId: input.tenantId,
                  );
              return withLocation;
            },
            failure: (AppFailure failure) async =>
                Result<PharmacySupplier>.failure(failure),
          );
        });
  }

  @override
  Future<Result<PharmacySupplier>> updateSupplier(
    String supplierId,
    PharmacySupplierUpdateInput input,
  ) {
    final Map<String, Object?> payload = <String, Object?>{
      if (input.name != null) 'name': input.name!.trim(),
      if (input.clearContactEmail)
        'contact_email': null
      else if (input.contactEmail != null)
        'contact_email': input.contactEmail!.trim().isEmpty
            ? null
            : input.contactEmail!.trim(),
      if (input.clearPhone)
        'phone': null
      else if (input.phone != null)
        'phone': input.phone!.trim().isEmpty ? null : input.phone!.trim(),
    };
    return _apiClient
        .put<PharmacySupplier>(
          ApiEndpoints.byId(HmsApiResource.suppliers, supplierId),
          data: payload,
          decoder: (Object? data) {
            final PharmacyJsonMap response = _expectMap(data);
            return PharmacySupplierDto(_map(response['data'])).toEntity();
          },
        )
        .then((Result<PharmacySupplier> updated) async {
          return updated.when(
            success: (PharmacySupplier supplier) async {
              if (input.location == null) {
                return Result<PharmacySupplier>.success(supplier);
              }
              final String location = input.location!.trim();
              final Result<PharmacySupplier> withLocation =
                  await _syncSupplierLocation(
                    supplier: supplier,
                    location: location,
                    tenantId: supplier.tenantId,
                    clearLocation: location.isEmpty,
                  );
              return withLocation;
            },
            failure: (AppFailure failure) async =>
                Result<PharmacySupplier>.failure(failure),
          );
        });
  }

  @override
  Future<Result<void>> deleteSupplier(String supplierId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.suppliers, supplierId),
      decoder: (_) {},
    );
  }

  Future<Result<PharmacySupplier>> _syncSupplierLocation({
    required PharmacySupplier supplier,
    required String location,
    String? tenantId,
    bool clearLocation = false,
  }) async {
    final String? resolvedTenantId = tenantId ?? supplier.tenantId;
    if (resolvedTenantId == null || resolvedTenantId.isEmpty) {
      return Result<PharmacySupplier>.success(supplier);
    }

    if (clearLocation) {
      final String? addressId = supplier.addressId;
      if (addressId == null || addressId.isEmpty) {
        return Result<PharmacySupplier>.success(
          PharmacySupplier(
            id: supplier.id,
            displayId: supplier.displayId,
            name: supplier.name,
            contactEmail: supplier.contactEmail,
            phone: supplier.phone,
            location: null,
            addressId: null,
            tenantId: supplier.tenantId,
            createdAt: supplier.createdAt,
            updatedAt: supplier.updatedAt,
          ),
        );
      }
      final Result<void> deleted = await _apiClient.delete<void>(
        ApiEndpoints.byId(HmsApiResource.addresses, addressId),
        decoder: (_) {},
      );
      return deleted.when(
        success: (_) => Result<PharmacySupplier>.success(
          PharmacySupplier(
            id: supplier.id,
            displayId: supplier.displayId,
            name: supplier.name,
            contactEmail: supplier.contactEmail,
            phone: supplier.phone,
            location: null,
            addressId: null,
            tenantId: supplier.tenantId,
            createdAt: supplier.createdAt,
            updatedAt: supplier.updatedAt,
          ),
        ),
        failure: Result<PharmacySupplier>.failure,
      );
    }

    if (supplier.addressId != null && supplier.addressId!.isNotEmpty) {
      final Result<PharmacyJsonMap> updated = await _apiClient.put<PharmacyJsonMap>(
        ApiEndpoints.byId(HmsApiResource.addresses, supplier.addressId!),
        data: <String, Object?>{'line1': location},
        decoder: (Object? data) => _map(_expectMap(data)['data']),
      );
      return updated.when(
        success: (PharmacyJsonMap address) => Result<PharmacySupplier>.success(
          PharmacySupplier(
            id: supplier.id,
            displayId: supplier.displayId,
            name: supplier.name,
            contactEmail: supplier.contactEmail,
            phone: supplier.phone,
            location: location,
            addressId: _string(address['id']) ?? supplier.addressId,
            tenantId: supplier.tenantId,
            createdAt: supplier.createdAt,
            updatedAt: supplier.updatedAt,
          ),
        ),
        failure: Result<PharmacySupplier>.failure,
      );
    }

    final Result<PharmacyJsonMap> created = await _apiClient.post<PharmacyJsonMap>(
      ApiEndpoints.collection(HmsApiResource.addresses),
      data: <String, Object?>{
        'tenant_id': resolvedTenantId,
        'address_type': 'OTHER',
        'line1': location,
        'supplier_id': supplier.id,
      },
      decoder: (Object? data) => _map(_expectMap(data)['data']),
    );
    return created.when(
      success: (PharmacyJsonMap address) => Result<PharmacySupplier>.success(
        PharmacySupplier(
          id: supplier.id,
          displayId: supplier.displayId,
          name: supplier.name,
          contactEmail: supplier.contactEmail,
          phone: supplier.phone,
          location: location,
          addressId: _string(address['id']),
          tenantId: supplier.tenantId,
          createdAt: supplier.createdAt,
          updatedAt: supplier.updatedAt,
        ),
      ),
      failure: Result<PharmacySupplier>.failure,
    );
  }
}

PharmacyJsonMap _expectMap(Object? value) {
  if (value is PharmacyJsonMap) {
    return value;
  }
  throw const FormatException('Expected pharmacy response object.');
}

PharmacyJsonMap _map(Object? value) {
  return value is PharmacyJsonMap ? value : <String, Object?>{};
}

List<Object?> _list(Object? value) {
  if (value is! List) {
    return const <Object?>[];
  }
  return value;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (<String>['true', '1', 'yes'].contains(normalized)) {
      return true;
    }
    if (<String>['false', '0', 'no'].contains(normalized)) {
      return false;
    }
  }
  return fallback;
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}
