import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/lab/data/dtos/lab_dtos.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';

final labRepositoryProvider = Provider<LabRepository>((ref) {
  return LabRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class LabRepositoryImpl implements LabRepository {
  const LabRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<LabWorkbenchBundle>> loadWorkbench(LabWorkbenchQuery query) {
    final request = query.pageRequest;
    return _apiClient.get<LabWorkbenchBundle>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.lab.path, 'workbench']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'stage': _stageFor(query.scope),
        'criticality': query.scope == LabQueueScope.critical
            ? 'CRITICAL'
            : null,
        'sort_by': 'ordered_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          LabWorkbenchDto.fromResponse(data, request).bundle,
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> loadOrderWorkflow(String orderId) {
    return _apiClient.get<LabOrderWorkflow>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.lab.path,
        'orders',
        orderId,
        'workflow',
      ]),
      decoder: (Object? data) => LabOrderWorkflowDto.fromResponse(
        data,
      ).toEntity(),
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listTests({String? search}) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.collection(HmsApiResource.labTests),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 100,
        'search': search,
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabTests,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listPanels({String? search}) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.collection(HmsApiResource.labPanels),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 100,
        'search': search,
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabPanels,
    );
  }

  @override
  Future<Result<List<LabQcLog>>> listQcLogs({String? search}) {
    return _apiClient.get<List<LabQcLog>>(
      ApiEndpoints.collection(HmsApiResource.labQcLogs),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 20,
        'search': search,
        'sort_by': 'logged_at',
        'order': 'desc',
      }),
      decoder: decodeLabQcLogs,
    );
  }

  @override
  Future<Result<void>> createOrder(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.labOrders),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> collectOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'orders', orderId, 'collect'],
      payload,
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> receiveSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'samples', sampleId, 'receive'],
      payload,
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> rejectSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'samples', sampleId, 'reject'],
      payload,
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> releaseOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'order-items', itemId, 'release'],
      payload,
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> reverseWorkflow(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'orders', orderId, 'reverse'],
      payload,
    );
  }

  @override
  Future<Result<void>> createQcLog(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.labQcLogs),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  Future<Result<LabOrderWorkflow>> _postWorkflow(
    List<String> pathSegments,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<LabOrderWorkflow>(
      ApiEndpoints.apiV1(pathSegments),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => LabOrderWorkflowDto.fromResponse(
        data,
      ).toEntity(),
    );
  }

  String? _stageFor(LabQueueScope scope) {
    return switch (scope) {
      LabQueueScope.collection => 'COLLECTION',
      LabQueueScope.processing => 'PROCESSING',
      LabQueueScope.results => 'RESULTS',
      LabQueueScope.completed => 'COMPLETED',
      LabQueueScope.cancelled => 'CANCELLED',
      LabQueueScope.all || LabQueueScope.critical => null,
    };
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }
}
