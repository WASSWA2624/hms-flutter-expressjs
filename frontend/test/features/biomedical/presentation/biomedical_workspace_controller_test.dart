import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BiomedicalWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('BiomedicalWorkspaceController', () {
    test('loads the workspace and selects the first asset', () async {
      final _MockBiomedicalRepository repository = _MockBiomedicalRepository();
      _stubWorkspace(repository);

      final ProviderContainer container = ProviderContainer(
        overrides: [biomedicalRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<BiomedicalWorkspaceState> result = await container.read(
        biomedicalWorkspaceControllerProvider.future,
      );

      final BiomedicalWorkspaceState state = result.when(
        success: (BiomedicalWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );

      expect(state.workbench.summary.totalEquipment, 1);
      expect(state.selectedAsset?.displayId, 'EQ-001');
      verify(() => repository.getWorkspace(any())).called(1);
    });

    test('registers an asset and refreshes visible workspace data', () async {
      final _MockBiomedicalRepository repository = _MockBiomedicalRepository();
      _stubWorkspace(repository);
      when(
        () => repository.createResource(
          BiomedicalResources.registries,
          any<Map<String, Object?>>(),
        ),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(
            asset: BiomedicalAsset(
              id: 'EQ-002',
              humanFriendlyId: 'EQ-002',
              resource: BiomedicalResources.registries,
              title: 'Infusion pump',
            ),
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [biomedicalRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(biomedicalWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(biomedicalWorkspaceControllerProvider.notifier)
          .saveAsset(<String, Object?>{
            'tenant_id': 'tenant-1',
            'equipment_name': 'Infusion pump',
          });

      expect(failure, isNull);
      verify(
        () => repository.createResource(
          BiomedicalResources.registries,
          any<Map<String, Object?>>(),
        ),
      ).called(1);
      verify(
        () => repository.getWorkspace(any()),
      ).called(greaterThanOrEqualTo(2));
    });
  });
}

void _stubWorkspace(_MockBiomedicalRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(totalEquipment: 1),
        queues: const <BiomedicalQueueSummary>[
          BiomedicalQueueSummary(
            queue: BiomedicalQueues.openWorkOrders,
            count: 1,
            panel: BiomedicalPanels.workOrders,
            resource: BiomedicalResources.workOrders,
          ),
        ],
        panels: const <BiomedicalPanelSummary>[],
        lookups: BiomedicalLookupData.empty,
        assets: AppPage<BiomedicalAsset>(
          items: const <BiomedicalAsset>[
            BiomedicalAsset(
              id: 'EQ-001',
              humanFriendlyId: 'EQ-001',
              resource: BiomedicalResources.registries,
              title: 'Defibrillator',
              status: 'ACTIVE',
            ),
          ],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
  });
}
