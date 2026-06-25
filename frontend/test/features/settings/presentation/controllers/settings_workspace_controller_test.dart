import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/controllers/settings_workspace_controller.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  test(
    'loads workspace and reference data when tenant context is required',
    () async {
      final repository = _FakeSettingsWorkspaceRepository(
        workspaceResult: Result<SettingsWorkspace>.success(
          _workspace(SettingsWorkspaceStatus.tenantContextRequired),
        ),
        referenceResult: const Result<SettingsReferenceData>.success(
          SettingsReferenceData(
            state: SettingsWorkspaceStatus.tenantContextRequired,
            tenants: <SettingsReferenceOption>[
              SettingsReferenceOption(id: 'TEN-1', label: 'Acme Health'),
            ],
          ),
        ),
      );
      final container = createTestContainer(
        overrides: <Object?>[
          settingsWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final result = await container.read(
        settingsWorkspaceControllerProvider.future,
      );

      result.when(
        success: (state) {
          expect(
            state.workspace.status,
            SettingsWorkspaceStatus.tenantContextRequired,
          );
          expect(state.referenceData.tenants.single.id, 'TEN-1');
        },
        failure: (_) => fail('Expected success.'),
      );
      expect(repository.workspaceQueries, hasLength(1));
      expect(repository.referenceQueries, hasLength(1));
    },
  );

  test('applies search query and reloads state', () async {
    final repository = _FakeSettingsWorkspaceRepository(
      workspaceResult: Result<SettingsWorkspace>.success(
        _workspace(SettingsWorkspaceStatus.ready),
      ),
      referenceResult: const Result<SettingsReferenceData>.success(
        SettingsReferenceData(),
      ),
    );
    final container = createTestContainer(
      overrides: <Object?>[
        settingsWorkspaceRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await container.read(settingsWorkspaceControllerProvider.future);
    final failure = await container
        .read(settingsWorkspaceControllerProvider.notifier)
        .applySearch(' role ');

    expect(failure, isNull);
    expect(repository.workspaceQueries.last.search, 'role');
  });

  test('surfaces repository failures', () async {
    final repository = _FakeSettingsWorkspaceRepository(
      workspaceResult: const Result<SettingsWorkspace>.failure(
        AppFailure.forbidden(),
      ),
      referenceResult: const Result<SettingsReferenceData>.success(
        SettingsReferenceData(),
      ),
    );
    final container = createTestContainer(
      overrides: <Object?>[
        settingsWorkspaceRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final result = await container.read(
      settingsWorkspaceControllerProvider.future,
    );

    result.when(
      success: (_) => fail('Expected failure.'),
      failure: (failure) =>
          expect(failure.category, AppFailureCategory.forbidden),
    );
  });
}

final class _FakeSettingsWorkspaceRepository
    implements SettingsWorkspaceRepository {
  _FakeSettingsWorkspaceRepository({
    required this.workspaceResult,
    required this.referenceResult,
  });

  final Result<SettingsWorkspace> workspaceResult;
  final Result<SettingsReferenceData> referenceResult;
  final List<SettingsWorkspaceQuery> workspaceQueries =
      <SettingsWorkspaceQuery>[];
  final List<SettingsWorkspaceQuery> referenceQueries =
      <SettingsWorkspaceQuery>[];

  @override
  Future<Result<SettingsWorkspace>> getWorkspace(
    SettingsWorkspaceQuery query,
  ) async {
    workspaceQueries.add(query);
    return workspaceResult;
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) async {
    referenceQueries.add(query);
    return referenceResult;
  }
}

SettingsWorkspace _workspace(SettingsWorkspaceStatus status) {
  return SettingsWorkspace(
    status: status,
    generatedAt: DateTime.utc(2026, 5, 22, 9),
    context: SettingsWorkspaceContext(
      state: status,
      tenantName: status == SettingsWorkspaceStatus.ready
          ? 'Acme Health'
          : null,
      facilityName: status == SettingsWorkspaceStatus.ready
          ? 'Central Hospital'
          : null,
    ),
    summaryCards: const <SettingsSummaryCard>[],
    checklist: const SettingsChecklist(
      completedCount: 0,
      totalCount: 0,
      items: <SettingsChecklistItem>[],
    ),
    quickActions: const <SettingsQuickAction>[],
    moduleGroups: const <SettingsModuleGroup>[],
    referenceData: const SettingsReferenceData(),
    stats: const SettingsWorkspaceStats(
      totalModules: 0,
      configuredModules: 0,
      attentionModules: 0,
      totalRecords: 0,
    ),
    permissions: const SettingsWorkspacePermissions(canWrite: false),
  );
}
