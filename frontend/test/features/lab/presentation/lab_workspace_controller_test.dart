import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
  code: 'CBC',
);

const LabCatalogItem _offeredTest = LabCatalogItem(
  id: 'LBT0000002',
  type: LabCatalogItemType.test,
  name: 'LFT',
  code: 'LFT',
  isOfferedAtFacility: true,
);

const LabCatalogItem _offeredPanel = LabCatalogItem(
  id: 'LBP0000001',
  type: LabCatalogItemType.panel,
  name: 'Basic metabolic panel',
  code: 'BMP',
  isOfferedAtFacility: true,
  unitPrice: 25000,
  currency: 'UGX',
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
    when(() => repository.loadWorkbench(any())).thenAnswer(
      (_) async => Result<LabWorkbenchBundle>.success(_emptyWorkbench()),
    );
    when(() => repository.listQcLogs(search: any(named: 'search'))).thenAnswer(
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
      (_) async => const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[
        _catalogTest,
      ]),
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
      (_) async =>
          const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[]),
    );
    when(
      () => repository.listTests(
        search: any(named: 'search'),
        tenantId: any(named: 'tenantId'),
        includeStandardCatalog: any(named: 'includeStandardCatalog'),
        includePendingReview: any(named: 'includePendingReview'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[
        _catalogTest,
        _offeredTest,
      ]),
    );
    when(
      () => repository.listPanels(
        search: any(named: 'search'),
        tenantId: any(named: 'tenantId'),
        includeStandardCatalog: any(named: 'includeStandardCatalog'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[]),
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      await controller.loadFacilityCatalogConfig(
        const LabCatalogScope(tenantId: 'TEN0000001', facilityId: 'FAC0000001'),
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
    'loadFacilityCatalogConfig clears catalog when scope is incomplete',
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      await controller.loadFacilityCatalogConfig(
        const LabCatalogScope(tenantId: 'TEN0000001', facilityId: 'FAC0000001'),
      );

      await controller.loadFacilityCatalogConfig(
        const LabCatalogScope(tenantId: 'TEN0000001'),
      );

      final LabWorkspaceState state =
          (container.read(labWorkspaceControllerProvider).value
                  as ResultSuccess<LabWorkspaceState>)
              .value;
      expect(state.catalogTests, isEmpty);
      expect(state.catalogPanels, isEmpty);
      expect(state.isLoadingCatalog, isFalse);
      expect(state.catalogScope?.tenantId, 'TEN0000001');
      expect(state.catalogScope?.facilityId, isNull);
    },
  );

  test(
    'searchPlatformLabCatalogForOffering loads platform catalog and marks offered items',
    () async {
      when(
        () => repository.listFacilityLabTests(
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
          search: any(named: 'search'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          offeredOnly: true,
        ),
      ).thenAnswer(
        (_) async => const Result<List<LabCatalogItem>>.success(
          <LabCatalogItem>[_offeredTest],
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      final Result<List<LabCatalogItem>> result = await controller
          .searchPlatformLabCatalogForOffering(
            type: LabCatalogItemType.test,
            scope: const LabCatalogScope(
              tenantId: 'TEN0000001',
              facilityId: 'FAC0000001',
            ),
            query: 'LFT',
          );

      expect(result, isA<ResultSuccess<List<LabCatalogItem>>>());
      final List<LabCatalogItem> items =
          (result as ResultSuccess<List<LabCatalogItem>>).value;
      expect(items, hasLength(2));
      expect(items.first.isOfferedAtFacility, isFalse);
      expect(items.last.code, 'LFT');
      expect(items.last.isOfferedAtFacility, isTrue);

      verify(
        () => repository.listTests(
          search: 'LFT',
          tenantId: 'TEN0000001',
          includeStandardCatalog: true,
          limit: any<int>(named: 'limit'),
        ),
      ).called(1);
      verify(
        () => repository.listFacilityLabTests(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
          offeredOnly: true,
          limit: any<int>(named: 'limit'),
        ),
      ).called(1);
    },
  );

  test(
    'searchPlatformLabCatalogForOffering returns empty list when scope is incomplete',
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      final Result<List<LabCatalogItem>> result = await controller
          .searchPlatformLabCatalogForOffering(
            type: LabCatalogItemType.test,
            scope: const LabCatalogScope(tenantId: 'TEN0000001'),
          );

      expect(result, isA<ResultSuccess<List<LabCatalogItem>>>());
      expect((result as ResultSuccess<List<LabCatalogItem>>).value, isEmpty);
      verifyNever(
        () => repository.listTests(
          search: any(named: 'search'),
          tenantId: any(named: 'tenantId'),
          includeStandardCatalog: any(named: 'includeStandardCatalog'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );

  test(
    'updateLabPanel appends newly enabled panel to catalog state immediately',
    () async {
      const LabCatalogScope scope = LabCatalogScope(
        tenantId: 'TEN0000001',
        facilityId: 'FAC0000001',
      );
      when(
        () => repository.upsertFacilityLabPanelOffering(
          any(),
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<LabCatalogItem>.success(_offeredPanel),
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      await controller.loadFacilityCatalogConfig(scope);

      final AppFailure? failure = await controller.updateLabPanel(
        'LBP0000001',
        <String, Object?>{
          'is_active': true,
          'unit_price': 25000,
          'currency': 'UGX',
        },
        scope: scope,
      );

      expect(failure, isNull);
      final LabWorkspaceState state =
          (container.read(labWorkspaceControllerProvider).value
                  as ResultSuccess<LabWorkspaceState>)
              .value;
      expect(state.catalogPanels, hasLength(1));
      expect(state.catalogPanels.single.code, 'BMP');
      expect(state.catalogPanels.single.unitPrice, 25000);
    },
  );

  test(
    'updateLabTest replaces existing catalog test after price edit',
    () async {
      const LabCatalogScope scope = LabCatalogScope(
        tenantId: 'TEN0000001',
        facilityId: 'FAC0000001',
      );
      const LabCatalogItem updatedTest = LabCatalogItem(
        id: 'LBT0000001',
        type: LabCatalogItemType.test,
        name: 'CBC',
        code: 'CBC',
        isOfferedAtFacility: true,
        unitPrice: 18000,
        currency: 'UGX',
      );
      when(
        () => repository.upsertFacilityLabTestOffering(
          any(),
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<LabCatalogItem>.success(updatedTest),
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

      final LabWorkspaceController controller = container.read(
        labWorkspaceControllerProvider.notifier,
      );
      await controller.loadFacilityCatalogConfig(scope);

      final AppFailure? failure = await controller.updateLabTest(
        'LBT0000001',
        <String, Object?>{'unit_price': 18000, 'currency': 'UGX'},
        scope: scope,
      );

      expect(failure, isNull);
      final LabWorkspaceState state =
          (container.read(labWorkspaceControllerProvider).value
                  as ResultSuccess<LabWorkspaceState>)
              .value;
      expect(state.catalogTests, hasLength(1));
      expect(state.catalogTests.single.unitPrice, 18000);
      expect(state.catalogTests.single.currency, 'UGX');
    },
  );
}
