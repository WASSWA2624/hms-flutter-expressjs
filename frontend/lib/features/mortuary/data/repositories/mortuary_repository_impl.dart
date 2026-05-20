import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/mortuary/data/dtos/mortuary_dtos.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final mortuaryRepositoryProvider = Provider<MortuaryRepository>((ref) {
  return MortuaryRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class MortuaryRepositoryImpl implements MortuaryRepository {
  const MortuaryRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<MortuaryWorkspacePayload>> getWorkspace(
    MortuaryWorkspaceQuery query,
  ) {
    return _apiClient.get<MortuaryWorkspacePayload>(
      ApiEndpoints.collection(HmsApiResource.mortuary),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': query.pageRequest.pageIndex + 1,
        'limit': query.pageRequest.pageSize,
        'panel': query.panel,
        'resource': query.resource,
        'queue': query.queue,
        'search': query.search,
        'status': query.status,
        'identification_status': query.identificationStatus,
        'facility_id': query.facilityId,
        'storage_unit_id': query.storageUnitId,
        'storage_slot_id': query.storageSlotId,
        'date_preset': query.datePreset,
        'id': query.id,
        'action': query.action,
      }),
      decoder: (Object? data) =>
          MortuaryWorkspacePayloadDto.fromResponse(data, query).payload,
    );
  }

  @override
  Future<Result<MortuaryLookupData>> getLookups({
    String? facilityId,
    String? search,
  }) {
    return _apiClient.get<MortuaryLookupData>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.mortuary.path, 'lookups']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
        'search': search,
      }),
      decoder: (Object? data) =>
          MortuaryLookupDataDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<MortuaryWorkspaceItem>> getItem({
    required String resource,
    required String id,
    MortuaryWorkspaceQuery baseQuery = const MortuaryWorkspaceQuery(),
  }) async {
    final Result<MortuaryWorkspacePayload> result = await getWorkspace(
      baseQuery.copyWith(
        resource: resource,
        id: id,
        action: 'view',
        pageRequest: const AppPageRequest(pageSize: 1),
        clearQueue: true,
      ),
    );

    return result.when(
      success: (MortuaryWorkspacePayload payload) {
        final MortuaryWorkspaceItem? item = payload.items.items.firstOrNull;
        if (item == null) {
          return Result<MortuaryWorkspaceItem>.failure(AppFailure.notFound());
        }
        return Result<MortuaryWorkspaceItem>.success(item);
      },
      failure: (AppFailure failure) =>
          Result<MortuaryWorkspaceItem>.failure(failure),
    );
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
