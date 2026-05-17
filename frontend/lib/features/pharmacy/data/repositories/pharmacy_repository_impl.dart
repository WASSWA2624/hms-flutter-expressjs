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
        'status': query.filter.backendStatus,
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
