import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';

void main() {
  test('fetches workspace using the settings-workspace endpoint and query', () async {
    final apiClient = _FakeApiClient(_workspacePayload());
    final repository = SettingsWorkspaceRepositoryImpl(apiClient: apiClient);

    final result = await repository.getWorkspace(
      const SettingsWorkspaceQuery(
        tenantId: 'TEN-1',
        facilityId: 'FAC-1',
        search: 'role',
        actionableOnly: true,
      ),
    );

    result.when(
      success: (workspace) {
        expect(workspace.context.tenantName, 'Acme Health');
      },
      failure: (_) => fail('Expected workspace success.'),
    );
    expect(apiClient.lastEndpoint?.path, '/api/v1/settings-workspace/workspace');
    expect(apiClient.lastQueryParameters, <String, Object?>{
      'tenant_id': 'TEN-1',
      'facility_id': 'FAC-1',
      'search': 'role',
      'actionable_only': true,
    });
  });

  test('fetches reference data from settings-workspace reference endpoint', () async {
    final apiClient = _FakeApiClient(<String, Object?>{
      'state': 'tenant_context_required',
      'tenants': <Map<String, Object?>>[
        <String, Object?>{'id': 'TEN-1', 'label': 'Acme Health'},
      ],
    });
    final repository = SettingsWorkspaceRepositoryImpl(apiClient: apiClient);

    final result = await repository.getReferenceData(const SettingsWorkspaceQuery());

    result.when(
      success: (referenceData) {
        expect(referenceData.state, SettingsWorkspaceStatus.tenantContextRequired);
        expect(referenceData.tenants.single.id, 'TEN-1');
      },
      failure: (_) => fail('Expected reference-data success.'),
    );
    expect(apiClient.lastEndpoint?.path, '/api/v1/settings-workspace/reference-data');
  });
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.response);

  final Object? response;
  Uri? lastEndpoint;
  Map<String, Object?>? lastQueryParameters;

  @override
  Uri get baseUri => Uri.parse('https://example.test');

  @override
  Future<ApiResult<T>> get<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    lastEndpoint = endpoint;
    lastQueryParameters = queryParameters;
    return Result<T>.success(decoder(response));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _workspacePayload() {
  return <String, Object?>{
    'state': 'ready',
    'context': <String, Object?>{
      'state': 'ready',
      'tenant_name': 'Acme Health',
    },
    'checklist': <String, Object?>{
      'completed_count': 0,
      'total_count': 0,
      'items': <Map<String, Object?>>[],
    },
    'module_groups': <Map<String, Object?>>[],
    'summary_cards': <Map<String, Object?>>[],
    'quick_actions': <Map<String, Object?>>[],
    'stats': <String, Object?>{},
    'permissions': <String, Object?>{},
  };
}
