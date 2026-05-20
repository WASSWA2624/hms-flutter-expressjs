import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/biomedical/data/dtos/biomedical_dtos.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final biomedicalRepositoryProvider = Provider<BiomedicalRepository>((ref) {
  return BiomedicalRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class BiomedicalRepositoryImpl implements BiomedicalRepository {
  const BiomedicalRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<BiomedicalWorkbench>> getWorkspace(
    BiomedicalWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<BiomedicalWorkbench>(
      ApiEndpoints.collection(HmsApiResource.biomedical),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'panel': query.panel,
        'resource': query.resource,
        'queue': query.queue,
        'search': query.search,
        'status': query.status,
        'priority': query.priority,
        'facility_id': query.facilityId,
        'equipment_id': query.equipmentId,
        'engineer_id': query.engineerId,
        'date_preset': query.datePreset,
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        return BiomedicalWorkbenchDto.fromResponse(data, request).workbench;
      },
    );
  }

  @override
  Future<Result<BiomedicalLookupData>> getLookups({String? search}) {
    return _apiClient.get<BiomedicalLookupData>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.biomedical.path, 'lookups']),
      queryParameters: _withoutEmpty(<String, Object?>{'search': search}),
      decoder: (Object? data) {
        return BiomedicalLookupDataDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<BiomedicalMutationResult>> createFaultReport(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<BiomedicalMutationResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.biomedical.path,
        'fault-reports',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return BiomedicalMutationResultDto.fromFaultResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<BiomedicalMutationResult>> createResource(
    String resource,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<BiomedicalMutationResult>(
      ApiEndpoints.collection(_resourceFor(resource)),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return BiomedicalMutationResultDto.fromResourceResponse(
          data,
          resource,
        ).toEntity();
      },
    );
  }

  @override
  Future<Result<BiomedicalMutationResult>> updateResource(
    String resource,
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<BiomedicalMutationResult>(
      ApiEndpoints.byId(_resourceFor(resource), id),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return BiomedicalMutationResultDto.fromResourceResponse(
          data,
          resource,
        ).toEntity();
      },
    );
  }

  @override
  Future<Result<BiomedicalMutationResult>> startWorkOrder(
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<BiomedicalMutationResult>(
      ApiEndpoints.nested(
        HmsApiResource.equipmentWorkOrders,
        id,
        <String>['start'],
      ),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return BiomedicalMutationResultDto.fromResourceResponse(
          data,
          BiomedicalResources.workOrders,
        ).toEntity();
      },
    );
  }

  @override
  Future<Result<BiomedicalMutationResult>> returnToService(
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<BiomedicalMutationResult>(
      ApiEndpoints.nested(
        HmsApiResource.equipmentWorkOrders,
        id,
        <String>['return-to-service'],
      ),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return BiomedicalMutationResultDto.fromResourceResponse(
          data,
          BiomedicalResources.workOrders,
        ).toEntity();
      },
    );
  }
}

HmsApiResource _resourceFor(String resource) {
  return switch (resource) {
    BiomedicalResources.categories => HmsApiResource.equipmentCategories,
    BiomedicalResources.registries => HmsApiResource.equipmentRegistries,
    BiomedicalResources.locationHistories =>
      HmsApiResource.equipmentLocationHistories,
    BiomedicalResources.maintenancePlans =>
      HmsApiResource.equipmentMaintenancePlans,
    BiomedicalResources.workOrders => HmsApiResource.equipmentWorkOrders,
    BiomedicalResources.calibrationLogs =>
      HmsApiResource.equipmentCalibrationLogs,
    BiomedicalResources.safetyTestLogs => HmsApiResource.equipmentSafetyTestLogs,
    BiomedicalResources.downtimeLogs => HmsApiResource.equipmentDowntimeLogs,
    BiomedicalResources.spareParts => HmsApiResource.equipmentSpareParts,
    BiomedicalResources.warrantyContracts =>
      HmsApiResource.equipmentWarrantyContracts,
    BiomedicalResources.serviceProviders =>
      HmsApiResource.equipmentServiceProviders,
    BiomedicalResources.incidentReports =>
      HmsApiResource.equipmentIncidentReports,
    BiomedicalResources.recallNotices => HmsApiResource.equipmentRecallNotices,
    BiomedicalResources.utilizationSnapshots =>
      HmsApiResource.equipmentUtilizationSnapshots,
    BiomedicalResources.disposalTransfers =>
      HmsApiResource.equipmentDisposalTransfers,
    _ => HmsApiResource.equipmentRegistries,
  };
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
