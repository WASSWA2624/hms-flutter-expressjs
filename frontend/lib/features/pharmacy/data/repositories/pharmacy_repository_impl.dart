import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<Result<AppPage<PharmacyDrug>>> searchDrugs(PharmacyDrugQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PharmacyDrug>>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.pharmacy.path, 'drugs']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'stock_status': query.stockStatus,
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
    return _apiClient.get<PharmacyInventoryWorkbench>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.pharmacy.path,
        'inventory',
        'stock',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'low_stock_only': query.lowStockOnly ? true : null,
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
        final List<PharmacyInventoryStock> stocks = _list(payload['stocks'])
            .map(PharmacyInventoryStockDto.new)
            .map((PharmacyInventoryStockDto dto) => dto.toEntity())
            .where((PharmacyInventoryStock item) => item.id.isNotEmpty)
            .toList(growable: false);
        return PharmacyInventoryWorkbench(
          summary: const PharmacyInventoryStockSummary(),
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
  Future<Result<PharmacyDrug>> updateDrug(
    String drugId,
    PharmacyDrugUpdateInput input,
  ) {
    return _apiClient.put<PharmacyDrug>(
      ApiEndpoints.byId(HmsApiResource.drugs, drugId),
      data: _withoutEmpty(input.toJson()),
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
        HmsApiResource.facilityPharmacyCatalog.path,
        'drugs',
        drugId,
      ]),
      data: _withoutEmpty(input.toJson()),
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

List<PharmacyJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <PharmacyJsonMap>[];
  }
  return value.whereType<PharmacyJsonMap>().toList(growable: false);
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
