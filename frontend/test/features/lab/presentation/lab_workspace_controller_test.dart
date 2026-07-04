import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabCatalogItem _catalogTest = LabCatalogItem(
  id: 'LBT0000001',
  type: LabCatalogItemType.test,
  name: 'CBC',
);

LabWorkbenchBundle _emptyWorkbench() {
  return const LabWorkbenchBundle(
    summary: LabWorkbenchSummary(),
    worklist: AppPage<LabOrderSummary>(
      items: <LabOrderSummary>[],
      request: AppPageRequest(),
      totalItemCount: 0,
    ),
  );
}

void main() {
  late _MockLabRepository repository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
  });

  setUp(() {
    repository = _MockLabRepository();
    when(
      () => repository.loadWorkbench(any()),
    ).thenAnswer(
      (_) async => Result<LabWorkbenchBundle>.success(_emptyWorkbench()),
    );
    when(
      () => repository.listQcLogs(search: any(named: 'search')),
    ).thenAnswer(
      (_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]),
    );
    when(
      () => repository.listFacilityLabTests(
        tenantId: any(named: 'tenantId'),
        facilityId: any(named: 'facilityId'),
        search: any(named: 'search'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        offeredOnly: any(named: 'offeredOnly'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<LabCatalogItem>>.success(
        <LabCatalogItem>[_catalogTest],
      ),
    );
    when(
      () => repository.listFacilityLabPanels(
        tenantId: any(named: 'tenantId'),
        facilityId: any(named: 'facilityId'),
        search: any(named: 'search'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        offeredOnly: any(named: 'offeredOnly'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<LabCatalogItem>>.success(
        <LabCatalogItem>[],
      ),
    );
  });

  test(
    'loadFacilityCatalogConfig requests catalog pages within backend limit',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          labRepositoryProvider.overrideWithValue(repository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.unauthenticated(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(labWorkspaceControllerProvider.future);

      final LabWorkspaceController controller =
          container.read(labWorkspaceControllerProvider.notifier);
      await controller.loadFacilityCatalogConfig(
        const LabCatalogScope(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ),
      );

      verify(
        () => repository.listFacilityLabTests(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
          offeredOnly: true,
        ),
      ).called(1);
      verify(
        () => repository.listFacilityLabPanels(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
          offeredOnly: true,
        ),
      ).called(1);

      final LabWorkspaceState state =
          (container.read(labWorkspaceControllerProvider).value
                  as ResultSuccess<LabWorkspaceState>)
              .value;
      expect(state.catalogTests, const <LabCatalogItem>[_catalogTest]);
      expect(state.catalogScope?.tenantId, 'TEN0000001');
      expect(state.catalogScope?.facilityId, 'FAC0000001');
    },
  );

  test(
    'searchPlatformLabCatalogForOffering requests full platform catalog',
    () async {
      when(
        () => repository.listFacilityLabTests(
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
          search: any(named: 'search'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<LabCatalogItem>>.success(
          <LabCatalogItem>[_catalogTest],
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          labRepositoryProvider.overrideWithValue(repository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.unauthenticated(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(labWorkspaceControllerProvider.future);

      final LabWorkspaceController controller =
          container.read(labWorkspaceControllerProvider.notifier);
      await controller.loadFacilityCatalogConfig(
        const LabCatalogScope(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ),
      );

      final Result<List<LabCatalogItem>> result =
          await controller.searchPlatformLabCatalogForOffering(
        type: LabCatalogItemType.test,
        scope: const LabCatalogScope(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ),
        query: 'LFT',
      );

      expect(result, isA<ResultSuccess<List<LabCatalogItem>>>());
      verify(
        () => repository.listFacilityLabTests(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
          search: 'LFT',
          limit: 25,
        ),
      ).called(1);
    },
  );
}
