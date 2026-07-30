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
        'view': query.view == LabWorkbenchView.patients ? 'PATIENTS' : 'ORDERS',
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
      decoder: (Object? data) =>
          LabOrderWorkflowDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<List<LabOrderPatientContext>>> searchOrderContextPatients({
    String? search,
    int limit = 8,
  }) {
    return _apiClient.get<List<LabOrderPatientContext>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.lab.path,
        'order-context',
        'patients',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': limit,
        'search': search,
      }),
      decoder: decodeLabOrderContextPatients,
    );
  }

  @override
  Future<Result<LabOrderPatientContextDetail>> loadOrderPatientContext(
    String patientId,
  ) {
    return _apiClient.get<LabOrderPatientContextDetail>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.lab.path,
        'order-context',
        'patients',
        patientId,
      ]),
      decoder: (Object? data) =>
          LabOrderPatientContextDetailDto.fromResponse(data).detail,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listTests({
    String? search,
    String? tenantId,
    bool includeStandardCatalog = false,
    bool includePendingReview = false,
    int limit = 100,
  }) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.collection(HmsApiResource.labTests),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': limit,
        'search': search,
        'tenant_id': tenantId,
        if (includeStandardCatalog) 'include_standard_catalog': 'true',
        if (includePendingReview) 'include_pending_review': 'true',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabTests,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listPanels({
    String? search,
    String? tenantId,
    bool includeStandardCatalog = false,
    int limit = 100,
  }) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.collection(HmsApiResource.labPanels),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': limit,
        'search': search,
        'tenant_id': tenantId,
        if (includeStandardCatalog) 'include_standard_catalog': 'true',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabPanels,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listFacilityLabTests({
    String? tenantId,
    String? facilityId,
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  }) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'tests',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
        'page': page,
        'limit': limit,
        'search': search,
        'offered_only': offeredOnly ? 'true' : 'false',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabTests,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> listFacilityLabPanels({
    String? tenantId,
    String? facilityId,
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  }) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'panels',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
        'page': page,
        'limit': limit,
        'search': search,
        'offered_only': offeredOnly ? 'true' : 'false',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeLabPanels,
    );
  }

  @override
  Future<Result<List<LabCatalogItem>>> searchFacilityLabCatalog({
    required String termType,
    String? tenantId,
    String? facilityId,
    String? query,
    int limit = 25,
  }) {
    return _apiClient.get<List<LabCatalogItem>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'search',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
        'term_type': termType,
        'q': query,
        'limit': limit,
        'offered_only': 'true',
      }),
      decoder: termType == 'LAB_PANEL' ? decodeLabPanels : decodeLabTests,
    );
  }

  @override
  Future<Result<LabCatalogItem>> upsertFacilityLabTestOffering(
    String testId,
    Map<String, Object?> payload, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.put<LabCatalogItem>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'tests',
        testId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        ...payload,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.test),
    );
  }

  @override
  Future<Result<LabCatalogItem>> upsertFacilityLabPanelOffering(
    String panelId,
    Map<String, Object?> payload, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.put<LabCatalogItem>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'panels',
        panelId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        ...payload,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.panel),
    );
  }

  @override
  Future<Result<void>> disableFacilityLabTestOffering(
    String testId,
    String reason, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'tests',
        testId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> disableFacilityLabPanelOffering(
    String panelId,
    String reason, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityLabCatalog.path,
        'panels',
        panelId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: (_) {},
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
  Future<Result<void>> updateOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.labOrders, orderId),
      data: _withoutEmpty(payload, preserveEmptyIterables: true),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteOrder(String orderId, String reason) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.labOrders, orderId),
      data: <String, Object?>{'reason': reason},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<LabCatalogItem>> createLabTest(Map<String, Object?> payload) {
    return _apiClient.post<LabCatalogItem>(
      ApiEndpoints.collection(HmsApiResource.labTests),
      data: _withoutEmpty(payload, preserveEmptyIterables: true),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.test),
    );
  }

  @override
  Future<Result<LabCatalogItem>> createLabPanel(Map<String, Object?> payload) {
    return _apiClient.post<LabCatalogItem>(
      ApiEndpoints.collection(HmsApiResource.labPanels),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.panel),
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> collectOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'orders',
      orderId,
      'collect',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> receiveSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'samples',
      sampleId,
      'receive',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> rejectSample(
    String sampleId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'samples',
      sampleId,
      'reject',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> saveOrderItemResult(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'order-items',
      itemId,
      'save-result',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> saveOrderResults(
    String orderId,
    List<Map<String, Object?>> results,
  ) {
    return _postWorkflow(
      <String>[HmsApiResource.lab.path, 'orders', orderId, 'save-results'],
      <String, Object?>{'results': results},
    );
  }

  @override
  Future<Result<void>> createLabResult(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.labResults),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateLabResult(
    String resultId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.labResults, resultId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteLabResult(String resultId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.labResults, resultId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> rejectOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'order-items',
      itemId,
      'reject',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> reopenOrderItemResult(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'order-items',
      itemId,
      'reopen-result',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> restoreOrderItem(
    String itemId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'order-items',
      itemId,
      'restore',
    ], payload);
  }

  @override
  Future<Result<LabOrderWorkflow>> deleteOrderItems(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'orders',
      orderId,
      'delete-items',
    ], payload);
  }

  @override
  Future<Result<LabCatalogItem>> updateLabTest(
    String testId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<LabCatalogItem>(
      ApiEndpoints.byId(HmsApiResource.labTests, testId),
      data: _withoutEmpty(payload, preserveEmptyIterables: true),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.test),
    );
  }

  @override
  Future<Result<LabCatalogItem>> updateLabPanel(
    String panelId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<LabCatalogItem>(
      ApiEndpoints.byId(HmsApiResource.labPanels, panelId),
      data: _withoutEmpty(payload, preserveEmptyIterables: true),
      decoder: (Object? data) =>
          _decodeCatalogItem(data, LabCatalogItemType.panel),
    );
  }

  @override
  Future<Result<void>> deleteLabTest(String testId, String reason) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.labTests, testId),
      data: <String, Object?>{'reason': reason},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteLabPanel(String panelId, String reason) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.labPanels, panelId),
      data: <String, Object?>{'reason': reason},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<LabOrderWorkflow>> reverseWorkflow(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postWorkflow(<String>[
      HmsApiResource.lab.path,
      'orders',
      orderId,
      'reverse',
    ], payload);
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
      decoder: (Object? data) =>
          LabOrderWorkflowDto.fromResponse(data).toEntity(),
    );
  }

  LabCatalogItem _decodeCatalogItem(Object? data, LabCatalogItemType type) {
    final LabJsonMap response = _expectLabMap(data);
    final LabJsonMap payload = _asLabMap(response['data']).isEmpty
        ? response
        : _asLabMap(response['data']);
    return LabCatalogItemDto(payload, type).toEntity();
  }

  LabJsonMap _expectLabMap(Object? value) {
    if (value is LabJsonMap) {
      return value;
    }
    throw const FormatException('Expected lab response object.');
  }

  LabJsonMap _asLabMap(Object? value) {
    return value is LabJsonMap ? value : <String, Object?>{};
  }

  String? _stageFor(LabQueueScope scope) {
    return switch (scope) {
      LabQueueScope.collection => 'COLLECTION',
      LabQueueScope.processing => 'PROCESSING',
      LabQueueScope.completed => 'COMPLETED',
      LabQueueScope.cancelled => 'CANCELLED',
      LabQueueScope.all || LabQueueScope.critical => null,
    };
  }

  Map<String, Object?> _catalogScopeParams({
    String? tenantId,
    String? facilityId,
  }) {
    return <String, Object?>{
      if (tenantId != null && tenantId.trim().isNotEmpty)
        'tenant_id': tenantId.trim(),
      if (facilityId != null && facilityId.trim().isNotEmpty)
        'facility_id': facilityId.trim(),
    };
  }

  Map<String, Object?> _withoutEmpty(
    Map<String, Object?> payload, {
    bool preserveEmptyIterables = false,
  }) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(
          entry.value,
          preserveEmptyIterables: preserveEmptyIterables,
        ))
          entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value, {required bool preserveEmptyIterables}) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return !preserveEmptyIterables && value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }
}
