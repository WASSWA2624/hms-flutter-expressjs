import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/settings/data/dtos/settings_workspace_dtos.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';

final settingsWorkspaceRepositoryProvider =
    Provider<SettingsWorkspaceRepository>((ref) {
      return SettingsWorkspaceRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class SettingsWorkspaceRepositoryImpl
    implements SettingsWorkspaceRepository {
  const SettingsWorkspaceRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<SettingsWorkspace>> getWorkspace(SettingsWorkspaceQuery query) {
    return _apiClient.get<SettingsWorkspace>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.settingsWorkspace.path,
        'workspace',
      ]),
      queryParameters: _queryParameters(query),
      decoder: (Object? data) =>
          SettingsWorkspaceDto.fromResponse(data).workspace,
    );
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) {
    return _apiClient.get<SettingsReferenceData>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.settingsWorkspace.path,
        'reference-data',
      ]),
      queryParameters: _queryParameters(query),
      decoder: (Object? data) =>
          SettingsReferenceDataDto.fromResponse(data).referenceData,
    );
  }
}

Map<String, Object?> _queryParameters(SettingsWorkspaceQuery query) {
  return <String, Object?>{
    if (_hasText(query.tenantId)) 'tenant_id': query.tenantId,
    if (_hasText(query.facilityId)) 'facility_id': query.facilityId,
    if (_hasText(query.group)) 'group': query.group,
    if (query.state != null) 'state': query.state!.serverValue,
    if (_hasText(query.search)) 'search': query.search.trim(),
    if (query.actionableOnly) 'actionable_only': true,
  };
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
